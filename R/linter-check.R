#' Check function calls against type signatures
#'
#' @param xml XML parsed content
#' @param all_types List of all type information
#' @param var_context List of variable assignments
#' @param source_expression Source expression for creating lints
#' @param mode Type checking mode ("lenient", "exported", "strict")
#' @return List of Lint objects
#' @keywords internal
check_function_calls <- function(xml, all_types, var_context, source_expression, mode = "lenient") {
  lints <- list()

  # Find all function calls
  # XPath: Find the outer expr containing a function call
  # Structure: expr > expr > SYMBOL_FUNCTION_CALL
  call_nodes <- xml2::xml_find_all(xml, "//SYMBOL_FUNCTION_CALL/parent::expr/parent::expr")

  for (call_node in call_nodes) {
    call_lints <- check_single_call(call_node, all_types, var_context, source_expression, mode)
    if (length(call_lints) > 0) {
      lints <- c(lints, call_lints)
    }
  }

  lints
}

#' Check a single function call
#'
#' @param call_node XML node of the function call
#' @param all_types List of type information
#' @param var_context List of variable assignments
#' @param source_expression Source expression
#' @param mode Type checking mode ("lenient", "exported", "strict")
#' @return List of Lint objects
#' @keywords internal
check_single_call <- function(call_node, all_types, var_context, source_expression, mode = "lenient") {
  # Get function name
  fn_node <- xml2::xml_find_first(call_node, ".//SYMBOL_FUNCTION_CALL")
  if (is.na(fn_node)) {
    return(list())
  }

  fn_name <- xml2::xml_text(fn_node)

  # Check for property access (e.g., math$double)
  # Structure: expr[expr/OP-DOLLAR/SYMBOL_FUNCTION_CALL]
  fn_parent <- xml2::xml_parent(fn_node)
  has_dollar <- !is.na(xml2::xml_find_first(fn_parent, "./OP-DOLLAR"))

  if (has_dollar) {
    # Get the module/object name before the $
    module_node <- xml2::xml_find_first(fn_parent, "./expr[1]/SYMBOL | ./expr[1]//SYMBOL")
    if (!is.na(module_node)) {
      module_name <- xml2::xml_text(module_node)
      fn_name <- paste0(module_name, "$", fn_name)
    }
  }

  # Check if we have type info for this function
  if (!fn_name %in% names(all_types)) {
    return(list())
  }

  type_info <- all_types[[fn_name]]

  # Get line number of this call for variable lookup
  call_line <- as.integer(xml2::xml_attr(call_node, "line1"))
  if (is.na(call_line)) call_line <- 1L

  # Get arguments - pass all_types as type_registry for return type inference
  args <- extract_arguments(call_node, var_context, call_line, all_types)

  # Check each argument against type signature
  check_arguments(fn_name, args, type_info, call_node, source_expression, mode)
}

#' Check arguments against type signature
#'
#' @param fn_name Function name
#' @param args List of arguments
#' @param type_info Type information for function
#' @param call_node XML node of the call
#' @param source_expression Source expression
#' @param mode Type checking mode ("lenient", "exported", "strict")
#' @return List of Lint objects
#' @keywords internal
check_arguments <- function(fn_name, args, type_info, call_node, source_expression, mode = "lenient") {
  if (is.null(type_info$params)) {
    return(list())
  }

  param_names <- names(type_info$params)
  positional_index <- 1
  lints <- list()

  for (i in seq_along(args)) {
    arg <- args[[i]]

    # Determine which parameter this argument corresponds to
    if (!is.null(arg$name) && !is.na(arg$name)) {
      # Named argument - match by name
      param_name <- arg$name
      if (!param_name %in% param_names) {
        # Unknown parameter, skip
        next
      }
    } else {
      # Positional argument - match by position
      if (positional_index > length(param_names)) {
        break
      }
      param_name <- param_names[positional_index]
      positional_index <- positional_index + 1
    }

    expected_type <- type_info$params[[param_name]]$type
    actual_type <- arg$type

    # Handle unknown types
    if (actual_type == "unknown") {
      # In strict mode, warn about unknown types
      if (mode == "strict") {
        lints[[length(lints) + 1]] <- create_lint(
          args[[i]]$node,
          source_expression,
          sprintf("Cannot verify type of argument '%s' (unknown type) in %s mode", param_name, mode)
        )
      }
      next
    }

    # Check type compatibility
    if (!types_compatible(actual_type, expected_type)) {
      lints[[length(lints) + 1]] <- create_lint(
        args[[i]]$node,
        source_expression,
        sprintf(
          "Argument '%s' expects type '%s' but got '%s'",
          param_name,
          type_to_s7_display(expected_type),
          type_to_s7_display(actual_type)
        )
      )
    }
  }

  lints
}

#' Get a line from a file by line number
#'
#' @param filename Path to the file
#' @param line_number Line number to read
#' @return Character string with the line content, or empty string if not found
#' @keywords internal
get_line_from_file <- function(filename, line_number) {
  if (is.null(filename) || !file.exists(filename)) {
    return("")
  }
  lines <- readLines(filename, warn = FALSE)
  if (line_number > length(lines) || line_number < 1) {
    return("")
  }
  lines[line_number]
}

#' Create a lint object with proper positioning
#'
#' Helper to eliminate duplication in lint creation. Handles:
#' - Extracting line/col from XML node
#' - NA handling with defaults
#' - Line text retrieval
#' - Column clamping to line boundaries
#'
#' @param node XML node for positioning
#' @param source_expression Source expression from lintr
#' @param message Lint message
#' @param fallback_line Fallback line if node has no line info
#' @return lintr::Lint object
#' @keywords internal
create_lint <- function(node, source_expression, message, fallback_line = 1L) {
  # Extract position from XML
  line <- as.integer(xml2::xml_attr(node, "line1"))
  col <- as.integer(xml2::xml_attr(node, "col1"))
  col_end <- as.integer(xml2::xml_attr(node, "col2"))

  # Handle NAs
  if (is.na(line)) line <- fallback_line
  if (is.na(col)) col <- 1L
  if (is.na(col_end)) col_end <- col

  # Get line text and clamp columns
  line_text <- get_line_from_file(source_expression$filename, line)
  max_col <- nchar(line_text) + 1L
  col <- as.integer(min(max(col, 1L), max_col))
  col_end <- as.integer(min(max(col_end, 1L), max_col))

  # Final NA check
  if (is.na(col)) col <- 1L
  if (is.na(col_end)) col_end <- col

  lintr::Lint(
    filename = source_expression$filename,
    line_number = line,
    column_number = col,
    type = "warning",
    message = message,
    line = line_text,
    ranges = list(c(col, col_end))
  )
}

#' Find loaded packages in source
#'
#' @param source_expression Source expression from lintr
#' @return Character vector of package names
#' @keywords internal
find_loaded_packages <- function(source_expression) {
  xml <- source_expression$xml_parsed_content

  if (is.null(xml)) {
    return(character())
  }

  # Find library() and require() calls
  # XPath: find SYMBOL_FUNCTION_CALL nodes with text 'library' or 'require'
  lib_calls <- xml2::xml_find_all(
    xml,
    "//SYMBOL_FUNCTION_CALL[text()='library' or text()='require']"
  )

  packages <- character()

  for (call in lib_calls) {
    # Get the parent expr node, then the grandparent (full call expression)
    parent <- xml2::xml_parent(call)
    grandparent <- xml2::xml_parent(parent)

    # The package name is in a SYMBOL (not SYMBOL_FUNCTION_CALL) or STR_CONST
    # Look for SYMBOL that's not the function name itself
    pkg_node <- xml2::xml_find_first(grandparent, ".//SYMBOL[not(self::SYMBOL_FUNCTION_CALL)] | .//STR_CONST")

    if (!is.na(pkg_node)) {
      pkg_name <- xml2::xml_text(pkg_node)
      # Remove quotes if present
      pkg_name <- gsub("^['\"]|['\"]$", "", pkg_name)
      packages <- c(packages, pkg_name)
    }
  }

  unique(packages)
}

#' Load type metadata from packages
#'
#' @param packages Character vector of package names
#' @return List of type information from packages
#' @keywords internal
load_package_types <- function(packages) {
  all_types <- list()

  for (pkg in packages) {
    # Skip if package not installed
    if (!requireNamespace(pkg, quietly = TRUE)) {
      next
    }

    # Try to load types.rds
    types_file <- system.file("types.rds", package = pkg)

    if (file.exists(types_file)) {
      pkg_types <- readRDS(types_file)

      # Prefix function names with package name to avoid conflicts
      for (fn_name in names(pkg_types)) {
        all_types[[paste0(pkg, "::", fn_name)]] <- pkg_types[[fn_name]]
      }
    }
  }

  all_types
}

#' Check for missing type annotations based on mode
#'
#' @param fn_assign_node XML node of function assignment
#' @param type_info Type information extracted from comments (can be NULL)
#' @param source_expression Source expression
#' @param mode Type checking mode ("lenient", "exported", "strict")
#' @param comments Accumulated roxygen comments for this function
#' @return List of Lint objects
#' @keywords internal
check_mode_annotations <- function(fn_assign_node, type_info, source_expression, mode, comments) {
  # Lenient mode doesn't check for missing annotations
  if (mode == "lenient") {
    return(list())
  }

  # For exported mode, check if function has @export tag
  if (mode == "exported") {
    is_exported <- any(grepl("@export\\b", comments))
    if (!is_exported) {
      return(list())  # Not exported, no requirements
    }
  }

  # If we get here, we need to check annotations (either exported or strict mode)
  check_strict_mode_annotations_impl(fn_assign_node, type_info, source_expression, mode)
}

#' Implementation of annotation checking (internal)
#'
#' @param fn_assign_node XML node of function assignment
#' @param type_info Type information extracted from comments (can be NULL)
#' @param source_expression Source expression
#' @param mode Type checking mode (for error messages)
#' @return List of Lint objects
#' @keywords internal
check_strict_mode_annotations_impl <- function(fn_assign_node, type_info, source_expression, mode) {
  lints <- list()

  # Get function node
  fn_node <- xml2::xml_find_first(fn_assign_node, ".//FUNCTION")
  if (is.na(fn_node)) {
    return(list())
  }

  # Get function name for error messages
  symbol_node <- xml2::xml_find_first(fn_assign_node, "./expr/SYMBOL")
  fn_name <- if (!is.na(symbol_node)) xml2::xml_text(symbol_node) else "function"

  # Extract parameter names from function definition
  # SYMBOL_FORMALS are siblings of FUNCTION node, so search from parent
  fn_expr <- xml2::xml_parent(fn_node)
  param_nodes <- xml2::xml_find_all(fn_expr, ".//SYMBOL_FORMALS")
  param_names <- vapply(param_nodes, xml2::xml_text, character(1))

  # Check each parameter for type annotation
  for (param_name in param_names) {
    # Skip ... parameter (ellipsis)
    if (param_name == "...") {
      next
    }

    # Check if this parameter has a type annotation
    has_annotation <- FALSE
    if (!is.null(type_info) && !is.null(type_info$params)) {
      has_annotation <- param_name %in% names(type_info$params)
    }

    if (!has_annotation) {
      # Find the parameter node for positioning
      param_node <- xml2::xml_find_first(fn_node, sprintf(".//SYMBOL_FORMALS[text()='%s']", param_name))

      # Use function node as fallback
      fallback <- as.integer(xml2::xml_attr(fn_node, "line1"))
      if (is.na(fallback)) fallback <- 1L

      lints[[length(lints) + 1]] <- create_lint(
        param_node,
        source_expression,
        sprintf(
          "Parameter '%s' missing type annotation (%s mode). Add @typedParam %s {type} description",
          param_name, mode, param_name
        ),
        fallback_line = fallback
      )
    }
  }

  # Check for missing @typedReturn
  has_return_annotation <- !is.null(type_info) && !is.null(type_info$return)

  if (!has_return_annotation) {
    lints[[length(lints) + 1]] <- create_lint(
      fn_node,
      source_expression,
      sprintf(
        "Function '%s' missing return type annotation (%s mode). Add @typedReturn {type} description",
        fn_name, mode
      )
    )
  }

  lints
}
