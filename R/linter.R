#' Type consistency linter
#'
#' Checks function calls against type annotations from @typedParam and @typedReturn tags.
#' Works with both local function definitions and installed packages.
#'
#' @typedParam mode {class_character} Type checking mode:
#'   - `"lenient"` (default): Check typed functions only, ignore untyped functions
#'   - `"exported"`: Require types on `@export` functions, internal functions optional
#'   - `"strict"`: Require types on all functions
#' @typedReturn {class_function} A linter function for use with lintr
#' @export
#' @examples
#' \dontrun{
#' # Lenient mode (default) - gradual adoption:
#' linters: with_defaults(
#'   type_consistency = rdoc::type_consistency_linter()
#' )
#'
#' # Exported mode - enforce types on public API:
#' linters: with_defaults(
#'   type_consistency = rdoc::type_consistency_linter(mode = "exported")
#' )
#'
#' # Strict mode - require types everywhere:
#' linters: with_defaults(
#'   type_consistency = rdoc::type_consistency_linter(mode = "strict")
#' )
#' }
type_consistency_linter <- function(mode = c("lenient", "exported", "strict")) {
  # Validate and normalize mode
  mode <- match.arg(mode)
  # Cache for accumulating data across lintr passes
  file_cache <- new.env(parent = emptyenv())

  lintr::Linter(function(source_expression) {
    xml <- source_expression$xml_parsed_content
    if (is.null(xml)) {
      return(list())
    }

    filename <- source_expression$filename %||% "unknown"

    # Initialize cache for this file if needed
    if (!exists(filename, envir = file_cache)) {
      file_cache[[filename]] <- list(
        comments = character(),
        types = list(),
        variables = list(),
        box_modules = list()  # Cache box module types across expressions
      )
    }

    cache <- file_cache[[filename]]

    # Check for comments in this expression
    comments <- xml2::xml_find_all(xml, "//COMMENT")
    syntax_validation_lints <- list()

    if (length(comments) > 0) {
      # Validate syntax and collect lints BEFORE accumulating comments
      comment_texts <- character()
      for (comment_node in comments) {
        comment_text <- xml2::xml_text(comment_node)
        if (grepl("^#'", comment_text)) {
          comment_texts <- c(comment_texts, comment_text)
        }
      }

      if (length(comment_texts) > 0) {
        # Validate syntax and create lints for errors
        syntax_validation_lints <- create_syntax_validation_lints(
          comment_texts,
          comments[sapply(comments, function(n) grepl("^#'", xml2::xml_text(n)))],
          source_expression
        )

        # Accumulate comments for type extraction (invalid tags will be skipped)
        cache$comments <- c(cache$comments, comment_texts)
        file_cache[[filename]] <- cache
      }
    }

    # Check for function definitions
    fn_assigns <- xml2::xml_find_all(xml, "//expr[LEFT_ASSIGN and .//FUNCTION]")
    return_validation_lints <- list()
    strict_mode_lints <- list()

    # Process each function assignment
    for (fn_assign in fn_assigns) {
      symbol_node <- xml2::xml_find_first(fn_assign, "./expr/SYMBOL")
      if (is.na(symbol_node)) next

      fn_name <- xml2::xml_text(symbol_node)
      type_info <- NULL

      # Save comments before clearing for mode checking
      comments_for_mode_check <- cache$comments

      # Extract types from accumulated comments (if any)
      if (length(cache$comments) > 0) {
        type_info <- extract_types_from_comment_lines(cache$comments)

        if (!is.null(type_info) && length(type_info) > 0) {
          cache$types[[fn_name]] <- type_info

          # Validate return type if declared (Phase 7.2)
          if (!is.null(type_info@return)) {
            validation_lints <- validate_return_type(fn_assign, type_info@return@type, source_expression, type_info@params)
            if (length(validation_lints) > 0) {
              return_validation_lints <- c(return_validation_lints, validation_lints)
            }
          }
        }

        # Clear comments after processing this function
        cache$comments <- character()
        file_cache[[filename]] <- cache
      }

      # Mode-based annotation checking (use saved comments)
      if (mode != "lenient") {
        mode_lints <- check_mode_annotations(fn_assign, type_info, source_expression, mode, comments_for_mode_check)
        if (length(mode_lints) > 0) {
          strict_mode_lints <- c(strict_mode_lints, mode_lints)
        }
      }
    }

    # Return syntax validation and return validation lints early if found
    # But continue to function call checking even if we have strict mode lints
    early_lints <- c(syntax_validation_lints, return_validation_lints)
    if (length(early_lints) > 0) {
      return(early_lints)
    }

    # Load package types
    loaded_packages <- find_loaded_packages(source_expression)
    package_types <- load_package_types(loaded_packages)

    # Load box module types (Phase 21.4)
    # Accumulate box module imports across expressions
    new_box_types <- load_box_module_types(xml, filename)
    if (length(new_box_types) > 0) {
      cache$box_modules <- c(cache$box_modules, new_box_types)
      file_cache[[filename]] <- cache
    }

    # Combine local, package, and cached box module types
    all_types <- c(cache$types, package_types, cache$box_modules)

    # Extract and accumulate variable assignments
    # Do this AFTER type extraction so we can infer function return types
    assignments <- extract_variable_assignments(xml)
    for (var_name in names(assignments)) {
      for (assignment in assignments[[var_name]]) {
        # Infer type from the assigned value, passing type registry for function returns
        inferred_type <- infer_argument_type(assignment@value_node, NULL, NULL, all_types)

        # Store in cache with inferred type
        if (!var_name %in% names(cache$variables)) {
          cache$variables[[var_name]] <- list()
        }

        cache$variables[[var_name]][[length(cache$variables[[var_name]]) + 1]] <- variable_assignment(
          line = assignment@line,
          type = inferred_type,
          value_node = NULL  # Node no longer needed after inference
        )
      }
    }
    file_cache[[filename]] <- cache

    # If no types, return strict mode lints only (if any)
    if (length(all_types) == 0) {
      return(strict_mode_lints)
    }

    # Find and check function calls
    call_lints <- check_function_calls(xml, all_types, cache$variables, source_expression, mode)

    # Combine strict mode lints with function call lints
    c(strict_mode_lints, call_lints)
  })
}

#' Create lint objects for invalid type annotation syntax
#'
#' Validates @typedParam and @typedReturn tags in roxygen comments
#' and creates lint objects for any syntax errors found.
#'
#' @param comments Character vector of roxygen comment lines
#' @param comment_nodes XML nodes for the comments (for line numbers)
#' @param source_expression Source expression for creating lints
#' @return List of lint objects
#' @keywords internal
create_syntax_validation_lints <- function(comments, comment_nodes, source_expression) {
  lints <- list()

  for (i in seq_along(comments)) {
    comment_text <- comments[i]
    content <- sub("^#'\\s*", "", comment_text)

    # Check for @typedParam
    if (grepl("^@typedParam\\s+", content)) {
      param_text <- sub("^@typedParam\\s+", "", content)
      result <- tryCatch({
        parse_typed_param_text(param_text)
        NULL  # Success - no lint needed
      }, error = function(e) {
        # Return error info to create lint
        list(
          message = conditionMessage(e),
          line = xml2::xml_attr(comment_nodes[i], "line1"),
          col = xml2::xml_attr(comment_nodes[i], "col1")
        )
      })

      if (!is.null(result)) {
        col_start <- as.integer(result$col)
        # Ensure range doesn't exceed line length
        line_len <- nchar(comment_text) + 1  # +1 for lintr convention
        col_end <- min(col_start + nchar(comment_text), line_len)

        lints <- c(lints, list(lintr::Lint(
          filename = source_expression$filename,
          line_number = as.integer(result$line),
          column_number = col_start,
          type = "error",
          message = result$message,
          line = comment_text,
          ranges = list(c(col_start, col_end))
        )))
      }
    }

    # Check for @typedReturn
    if (grepl("^@typedReturn\\s+", content)) {
      return_text <- sub("^@typedReturn\\s+", "", content)
      result <- tryCatch({
        parse_typed_return_text(return_text)
        NULL  # Success - no lint needed
      }, error = function(e) {
        # Return error info to create lint
        list(
          message = conditionMessage(e),
          line = xml2::xml_attr(comment_nodes[i], "line1"),
          col = xml2::xml_attr(comment_nodes[i], "col1")
        )
      })

      if (!is.null(result)) {
        col_start <- as.integer(result$col)
        # Ensure range doesn't exceed line length
        line_len <- nchar(comment_text) + 1  # +1 for lintr convention
        col_end <- min(col_start + nchar(comment_text), line_len)

        lints <- c(lints, list(lintr::Lint(
          filename = source_expression$filename,
          line_number = as.integer(result$line),
          column_number = col_start,
          type = "error",
          message = result$message,
          line = comment_text,
          ranges = list(c(col_start, col_end))
        )))
      }
    }
  }

  lints
}
