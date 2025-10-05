#' Type consistency linter
#'
#' Checks function calls against type annotations from @typedParam and @typedReturn tags.
#' Works with both local function definitions and installed packages.
#'
#' @return A linter function
#' @export
#' @examples
#' \dontrun{
#' # In .lintr configuration:
#' linters: with_defaults(
#'   type_consistency = rdoc::type_consistency_linter()
#' )
#' }
type_consistency_linter <- function() {
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
    if (length(fn_assigns) > 0 && length(cache$comments) > 0) {
      # Process accumulated comments for this function
      for (fn_assign in fn_assigns) {
        symbol_node <- xml2::xml_find_first(fn_assign, "./expr/SYMBOL")
        if (is.na(symbol_node)) next

        fn_name <- xml2::xml_text(symbol_node)

        # Extract types from accumulated comments
        type_info <- extract_types_from_comment_lines(cache$comments)

        if (!is.null(type_info) && length(type_info) > 0) {
          cache$types[[fn_name]] <- type_info
        }
      }

      # Clear accumulated comments after processing
      cache$comments <- character()
      file_cache[[filename]] <- cache
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
    check_function_calls(xml, all_types, cache$variables, source_expression)
  })
}
