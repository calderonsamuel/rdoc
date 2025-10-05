#' Validate function return type matches declaration
#'
#' @param fn_assign_node XML node of function assignment
#' @param declared_type Declared return type from @typedReturn
#' @param source_expression Source expression for creating lints
#' @return List of Lint objects (empty if validation passes or cannot be performed)
#' @keywords internal
validate_return_type <- function(fn_assign_node, declared_type, source_expression) {
  # Structure: expr[assignment] > expr[var] + LEFT_ASSIGN + expr[function]
  # The expr[function] contains: FUNCTION + OP-LEFT-PAREN + [params] + OP-RIGHT-PAREN + expr[body]

  # Get the expr containing the function (third child of assignment)
  fn_expr <- xml2::xml_find_first(fn_assign_node, "./expr[.//FUNCTION]")
  if (is.na(fn_expr)) {
    return(list())
  }

  # Get all children of the function expr
  # Structure: FUNCTION + OP-LEFT-PAREN + [params] + OP-RIGHT-PAREN + expr[body]
  fn_children <- xml2::xml_children(fn_expr)
  if (length(fn_children) < 4) {
    # Need at least FUNCTION, (, ), and body
    return(list())
  }

  # The body is the last child (always an expr)
  body_node <- fn_children[[length(fn_children)]]
  if (xml2::xml_name(body_node) != "expr") {
    return(list())
  }

  # Try to infer actual return type and get the return expression node
  result <- infer_function_return_type(body_node, return_node = TRUE)
  actual_type <- result$type
  return_expr_node <- result$node

  # Skip if we can't infer (too complex)
  if (actual_type == "unknown" || actual_type == "complex") {
    return(list())
  }

  # Check compatibility
  if (!types_compatible(actual_type, declared_type)) {
    # Get location for lint - use the return expression position if available
    if (!is.null(return_expr_node)) {
      line <- as.integer(xml2::xml_attr(return_expr_node, "line1"))
      col <- as.integer(xml2::xml_attr(return_expr_node, "col1"))
      col_end <- as.integer(xml2::xml_attr(return_expr_node, "col2"))
    } else {
      # Fallback to function assignment
      line <- as.integer(xml2::xml_attr(fn_assign_node, "line1"))
      col <- as.integer(xml2::xml_attr(fn_assign_node, "col1"))
      col_end <- as.integer(xml2::xml_attr(fn_assign_node, "col2"))
    }

    # Handle NA values
    if (is.na(line)) line <- 1L
    if (is.na(col)) col <- 1L
    if (is.na(col_end)) col_end <- col

    # Get line text
    line_text <- get_line_from_file(source_expression$filename, line)

    # Ensure columns are within bounds
    max_col <- nchar(line_text)
    if (max_col > 0) {
      col <- as.integer(min(max(col, 1L), max_col))
      col_end <- as.integer(min(max(col_end, col), max_col))
    } else {
      col <- 1L
      col_end <- 1L
    }

    return(list(lintr::Lint(
      filename = source_expression$filename,
      line_number = line,
      column_number = col,
      type = "warning",
      message = sprintf(
        "Function declares @typedReturn {%s} but returns {%s}",
        declared_type,
        actual_type
      ),
      line = line_text,
      ranges = list(c(col, col_end))
    )))
  }

  list()
}

#' Infer actual return type from function body
#'
#' @param body_node XML node of function body
#' @param return_node Logical, if TRUE returns list(type=..., node=...) instead of just type
#' @return Character string with inferred type or "unknown"/"complex", or list if return_node=TRUE
#' @keywords internal
infer_function_return_type <- function(body_node, return_node = FALSE) {
  # Helper to return result in correct format
  make_result <- function(type, node = NULL) {
    if (return_node) {
      list(type = type, node = node)
    } else {
      type
    }
  }

  # Check for explicit return() call
  return_call <- xml2::xml_find_first(body_node, ".//SYMBOL_FUNCTION_CALL[text()='return']")

  if (!is.na(return_call)) {
    # Check for multiple return statements (complex case - skip)
    all_returns <- xml2::xml_find_all(body_node, ".//SYMBOL_FUNCTION_CALL[text()='return']")
    if (length(all_returns) > 1) {
      return(make_result("complex"))
    }

    # Get the return call expression
    return_expr <- xml2::xml_parent(xml2::xml_parent(return_call))

    # Get the argument to return()
    # Structure: expr > expr[SYMBOL_FUNCTION_CALL] > ... > expr[argument]
    return_args <- xml2::xml_find_all(return_expr, "./expr[position() > 1]")
    if (length(return_args) > 0) {
      # Infer type from the returned expression
      type <- infer_argument_type(return_args[[1]])
      return(make_result(type, return_args[[1]]))
    }
  }

  # Check for control flow (if/else) - complex case
  if_node <- xml2::xml_find_first(body_node, ".//SYMBOL_FUNCTION_CALL[text()='if']")
  if (!is.na(if_node)) {
    return(make_result("complex"))
  }

  # Check for loops - complex case
  loop_nodes <- xml2::xml_find_first(body_node, ".//SYMBOL_FUNCTION_CALL[text()='for' or text()='while']")
  if (!is.na(loop_nodes)) {
    return(make_result("complex"))
  }

  # Simple case: implicit return (last expression)
  # The body itself is the last expression
  body_children <- xml2::xml_children(body_node)

  if (length(body_children) == 0) {
    return(make_result("unknown"))
  }

  # Check if body has braces
  has_braces <- any(sapply(body_children, function(x) xml2::xml_name(x) %in% c("OP-LEFT-BRACE", "OP-RIGHT-BRACE")))

  if (has_braces) {
    # Body structure: { expr1 expr2 ... exprN }
    # Filter out braces to get only expr children
    expr_children <- Filter(function(x) xml2::xml_name(x) == "expr", body_children)

    if (length(expr_children) == 0) {
      return(make_result("unknown"))
    }

    # If body has single expr, infer from it
    if (length(expr_children) == 1) {
      type <- infer_argument_type(expr_children[[1]])
      return(make_result(type, expr_children[[1]]))
    }

    # Multiple expressions - last one is the return value
    # For now, just check the last one if it's a simple literal or constructor
    last_expr <- expr_children[[length(expr_children)]]

    # Only handle simple cases
    has_literal <- length(xml2::xml_find_all(last_expr, ".//STR_CONST | .//NUM_CONST | .//NULL_CONST")) > 0
    has_constructor <- length(xml2::xml_find_all(last_expr, ".//SYMBOL_FUNCTION_CALL[text()='c' or text()='list' or text()='data.frame' or text()='matrix']")) > 0

    if (has_literal || has_constructor) {
      type <- infer_argument_type(last_expr)
      return(make_result(type, last_expr))
    }

    # Too complex, skip
    return(make_result("complex"))
  } else {
    # No braces - body_node itself is the return expression
    # Just infer its type directly
    type <- infer_argument_type(body_node)
    return(make_result(type, body_node))
  }

}
