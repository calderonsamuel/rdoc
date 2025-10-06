#' Type consistency linter
#'
#' Checks function calls against type annotations from @typedParam and @typedReturn tags.
#' Works with both local function definitions and installed packages.
#'
#' @typedParam strict {logical[1]} Enable strict mode (default: FALSE).
#'   In strict mode, missing type annotations are flagged as lints.
#' @typedReturn {function} A linter function for use with lintr
#' @export
#' @examples
#' \dontrun{
#' # In .lintr configuration (lenient mode - default):
#' linters: with_defaults(
#'   type_consistency = rdoc::type_consistency_linter()
#' )
#'
#' # Strict mode - requires all type annotations:
#' linters: with_defaults(
#'   type_consistency = rdoc::type_consistency_linter(strict = TRUE)
#' )
#' }
type_consistency_linter <- function(strict = FALSE) {
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
        variables = list()
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

      # Extract types from accumulated comments (if any)
      if (length(cache$comments) > 0) {
        type_info <- extract_types_from_comment_lines(cache$comments)

        if (!is.null(type_info) && length(type_info) > 0) {
          cache$types[[fn_name]] <- type_info

          # Validate return type if declared (Phase 7.2)
          if (!is.null(type_info$return)) {
            validation_lints <- validate_return_type(fn_assign, type_info$return$type, source_expression)
            if (length(validation_lints) > 0) {
              return_validation_lints <- c(return_validation_lints, validation_lints)
            }
          }
        }

        # Clear comments after processing this function
        cache$comments <- character()
        file_cache[[filename]] <- cache
      }

      # Strict mode: check for missing annotations (even if no comments)
      if (strict) {
        strict_lints <- check_strict_mode_annotations(fn_assign, type_info, source_expression)
        if (length(strict_lints) > 0) {
          strict_mode_lints <- c(strict_mode_lints, strict_lints)
        }
      }
    }

    # Return syntax validation, return validation, and strict mode lints early if found
    combined_lints <- c(syntax_validation_lints, return_validation_lints, strict_mode_lints)
    if (length(combined_lints) > 0) {
      return(combined_lints)
    }

    # Load package types
    loaded_packages <- find_loaded_packages(source_expression)
    package_types <- load_package_types(loaded_packages)

    # Combine local and package types
    all_types <- c(cache$types, package_types)

    # Extract and accumulate variable assignments
    # Do this AFTER type extraction so we can infer function return types
    assignments <- extract_variable_assignments(xml)
    for (var_name in names(assignments)) {
      for (assignment in assignments[[var_name]]) {
        # Infer type from the assigned value, passing type registry for function returns
        inferred_type <- infer_argument_type(assignment$value_node, NULL, NULL, all_types)

        # Store in cache
        if (!var_name %in% names(cache$variables)) {
          cache$variables[[var_name]] <- list()
        }

        cache$variables[[var_name]][[length(cache$variables[[var_name]]) + 1]] <- list(
          line = assignment$line,
          type = inferred_type
        )
      }
    }
    file_cache[[filename]] <- cache

    # If no types, nothing to lint
    if (length(all_types) == 0) {
      return(list())
    }

    # Find and check function calls
    check_function_calls(xml, all_types, cache$variables, source_expression, strict)
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
        lints <- c(lints, list(lintr::Lint(
          filename = source_expression$filename,
          line_number = as.integer(result$line),
          column_number = col_start,
          type = "error",
          message = result$message,
          line = comment_text,
          ranges = list(c(col_start, col_start + nchar(comment_text)))
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
        lints <- c(lints, list(lintr::Lint(
          filename = source_expression$filename,
          line_number = as.integer(result$line),
          column_number = col_start,
          type = "error",
          message = result$message,
          line = comment_text,
          ranges = list(c(col_start, col_start + nchar(comment_text)))
        )))
      }
    }
  }

  lints
}
