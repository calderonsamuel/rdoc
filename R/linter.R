#' Type consistency linter
#'
#' Checks function calls against type annotations from @typedParam and @typedReturn tags.
#' Works with both local function definitions and installed packages.
#'
#' @typedParam strict {logical(1)} Enable strict mode (default: FALSE).
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
    if (length(comments) > 0) {
      # Accumulate comments
      for (comment_node in comments) {
        comment_text <- xml2::xml_text(comment_node)
        if (grepl("^#'", comment_text)) {
          cache$comments <- c(cache$comments, comment_text)
        }
      }
      file_cache[[filename]] <- cache
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

    # Return validation and strict mode lints early if found
    combined_lints <- c(return_validation_lints, strict_mode_lints)
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
