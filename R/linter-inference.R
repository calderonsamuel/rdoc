#' Infer type of an argument from its AST node
#'
#' @param arg_node XML node of the argument
#' @param var_context Optional list of variable assignments for lookup
#' @param current_line Optional line number where argument is used (for variable lookup)
#' @param type_registry Optional list of function type signatures for return type lookup
#' @return Character string with inferred type or "unknown"
#' @keywords internal
infer_argument_type <- function(arg_node, var_context = NULL, current_line = NULL, type_registry = NULL) {
  # Check for function calls FIRST (before checking their arguments/literals)

  # Check for c() function calls
  c_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL[text()='c']")
  if (!is.na(c_call)) {
    # Get the first argument to c() to infer type
    first_arg <- xml2::xml_find_first(arg_node, ".//expr[SYMBOL_FUNCTION_CALL[text()='c']]/parent::expr/following-sibling::expr[1]")
    if (!is.na(first_arg)) {
      return(infer_argument_type(first_arg, var_context, current_line, type_registry))
    }
  }

  # Check for list() function calls
  list_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL[text()='list']")
  if (!is.na(list_call)) {
    return("list")
  }

  # Check for data.frame() function calls
  df_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL[text()='data.frame']")
  if (!is.na(df_call)) {
    return("data.frame")
  }

  # Check for matrix() function calls
  matrix_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL[text()='matrix']")
  if (!is.na(matrix_call)) {
    return("matrix")
  }

  # Check for general function calls with @typedReturn
  # This handles user-defined functions and package functions
  # Must come AFTER specific constructors (c, list, data.frame, matrix) but BEFORE literals
  if (!is.null(type_registry)) {
    # Look for any function call
    fn_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL")
    if (!is.na(fn_call)) {
      fn_name <- xml2::xml_text(fn_call)

      # Skip constructors we already handled
      if (!fn_name %in% c("c", "list", "data.frame", "matrix")) {
        # Look up function in type registry
        if (fn_name %in% names(type_registry)) {
          type_info <- type_registry[[fn_name]]
          if (!is.null(type_info$return)) {
            return(type_info$return$type)
          }
        }
      }
    }
  }

  # Check for comparison and logical operators (they return logical)
  # Comparison: >, >=, <, <=, ==, !=
  comparison_ops <- xml2::xml_find_first(arg_node, ".//GT | .//GE | .//LT | .//LE | .//EQ | .//NE")
  if (!is.na(comparison_ops)) {
    return("logical")
  }

  # Logical operators: &, |, ! (AND, OR, NOT)
  logical_ops <- xml2::xml_find_first(arg_node, ".//AND | .//OR | .//OP-EXCLAMATION")
  if (!is.na(logical_ops)) {
    return("logical")
  }

  # Now check for literals (after ruling out function calls and operators)

  # Check for string constant
  if (length(xml2::xml_find_all(arg_node, ".//STR_CONST")) > 0) {
    return("character")
  }

  # Check for NULL
  if (length(xml2::xml_find_all(arg_node, ".//NULL_CONST")) > 0) {
    return("NULL")
  }

  # Check for TRUE/FALSE (they are NUM_CONST with specific text)
  num_const <- xml2::xml_find_all(arg_node, ".//NUM_CONST")
  if (length(num_const) > 0) {
    text <- xml2::xml_text(num_const[1])
    if (text %in% c("TRUE", "FALSE")) {
      return("logical")
    }
    return("numeric")
  }

  # Check for variable reference (SYMBOL)
  symbol_node <- xml2::xml_find_first(arg_node, "./SYMBOL[not(self::SYMBOL_FUNCTION_CALL)]")
  if (!is.na(symbol_node) && !is.null(var_context) && !is.null(current_line)) {
    var_name <- xml2::xml_text(symbol_node)

    # Look up variable in context
    if (var_name %in% names(var_context)) {
      # Find the most recent assignment before current_line
      assignments <- var_context[[var_name]]
      valid_assignments <- Filter(function(a) a$line < current_line, assignments)

      if (length(valid_assignments) > 0) {
        # Get the most recent one (highest line number)
        most_recent <- valid_assignments[[length(valid_assignments)]]
        return(most_recent$type)
      }
    }
  }

  # Otherwise unknown
  "unknown"
}

#' Extract arguments from function call
#'
#' @param call_node XML node of function call
#' @param var_context Optional list of variable assignments for type inference
#' @param current_line Optional line number for variable lookup
#' @param type_registry Optional list of function type signatures for return type lookup
#' @return List of argument information
#' @keywords internal
extract_arguments <- function(call_node, var_context = NULL, current_line = NULL, type_registry = NULL) {
  # The call_node structure is: expr containing:
  #   - expr with SYMBOL_FUNCTION_CALL (the function name)
  #   - OP-LEFT-PAREN
  #   - For named args: SYMBOL_SUB, EQ_SUB, expr (value)
  #   - For positional args: expr (value)
  #   - OP-COMMA between args
  #   - OP-RIGHT-PAREN

  # Get all children
  all_children <- xml2::xml_children(call_node)

  # Skip function name expr and parens
  args <- list()
  i <- 1
  position <- 1

  while (i <= length(all_children)) {
    child <- all_children[[i]]
    child_name <- xml2::xml_name(child)

    # Check if this is a named argument (SYMBOL_SUB)
    if (child_name == "SYMBOL_SUB") {
      arg_name <- xml2::xml_text(child)
      # Skip EQ_SUB
      i <- i + 1
      # Next should be the expr with the value
      i <- i + 1
      if (i <= length(all_children)) {
        value_node <- all_children[[i]]
        if (xml2::xml_name(value_node) == "expr") {
          arg_type <- infer_argument_type(value_node, var_context, current_line, type_registry)
          args[[length(args) + 1]] <- list(
            node = value_node,
            type = arg_type,
            position = position,
            name = arg_name
          )
          position <- position + 1
        }
      }
    } else if (child_name == "expr") {
      # Check if this is the function name (first expr)
      if (length(args) == 0 && position == 1) {
        # This might be the function name, check for SYMBOL_FUNCTION_CALL at THIS level (not nested)
        # Use ./SYMBOL_FUNCTION_CALL (direct child) instead of .//SYMBOL_FUNCTION_CALL (any descendant)
        if (length(xml2::xml_find_all(child, "./SYMBOL_FUNCTION_CALL")) > 0) {
          # Skip function name
          i <- i + 1
          next
        }
      }
      # This is a positional argument
      arg_type <- infer_argument_type(child, var_context, current_line, type_registry)
      args[[length(args) + 1]] <- list(
        node = child,
        type = arg_type,
        position = position,
        name = NULL
      )
      position <- position + 1
    }

    i <- i + 1
  }

  args
}

#' Extract variable assignments from XML AST
#'
#' @param xml XML parsed content
#' @return List of assignments with variable names, line numbers, and value nodes
#' @keywords internal
extract_variable_assignments <- function(xml) {
  assignments <- list()

  # Find LEFT_ASSIGN expressions: var <- value
  left_assigns <- xml2::xml_find_all(xml, "//expr[LEFT_ASSIGN]")

  for (assign_node in left_assigns) {
    # Get variable name (left side)
    var_node <- xml2::xml_find_first(assign_node, "./expr[1]/SYMBOL")
    if (is.na(var_node)) next

    var_name <- xml2::xml_text(var_node)

    # Get assigned value (right side)
    value_node <- xml2::xml_find_first(assign_node, "./expr[2]")
    if (is.na(value_node)) next

    # Get line number
    line <- as.integer(xml2::xml_attr(assign_node, "line1"))
    if (is.na(line)) line <- 1L

    # Store assignment info
    if (!var_name %in% names(assignments)) {
      assignments[[var_name]] <- list()
    }

    assignments[[var_name]][[length(assignments[[var_name]]) + 1]] <- list(
      line = line,
      value_node = value_node
    )
  }

  assignments
}

#' Check if two types are compatible
#'
#' @param actual Actual type
#' @param expected Expected type
#' @return Logical
#' @keywords internal
types_compatible <- function(actual, expected) {
  # Remove length constraints for basic compatibility check
  actual_base <- gsub("\\(.*\\)$", "", actual)
  expected_base <- gsub("\\(.*\\)$", "", expected)

  # Exact match
  if (actual_base == expected_base) {
    return(TRUE)
  }

  # Handle union types in expected
  if (grepl("\\|", expected)) {
    expected_types <- split_union_types(expected)
    expected_bases <- gsub("\\(.*\\)$", "", trimws(expected_types))
    return(actual_base %in% expected_bases)
  }

  # Handle union types in actual
  if (grepl("\\|", actual)) {
    actual_types <- split_union_types(actual)
    actual_bases <- gsub("\\(.*\\)$", "", trimws(actual_types))
    return(expected_base %in% actual_bases)
  }

  # Numeric compatibility
  if (expected_base %in% c("numeric", "double") && actual_base %in% c("numeric", "integer", "double")) {
    return(TRUE)
  }

  FALSE
}
