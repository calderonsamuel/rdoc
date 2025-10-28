#' Infer type of an argument from its AST node
#'
#' @param arg_node XML node of the argument
#' @param var_context Optional list of variable assignments for lookup
#' @param current_line Optional line number where argument is used (for variable lookup)
#' @param type_registry Optional list of function type signatures for return type lookup
#' @param param_types Optional named list of parameter types (param_name -> type_string)
#' @return Character string with inferred type or "unknown"
#' @keywords internal
infer_argument_type <- function(arg_node, var_context = NULL, current_line = NULL, type_registry = NULL, param_types = list()) {
  # Check for function literals FIRST (before drilling into their bodies)
  # Function literals: function(...) { ... } or \(...) ...
  # Use ./FUNCTION (direct child) not .//FUNCTION (any descendant)
  # This prevents matching FUNCTION inside function arguments like: foo(function() {...})
  fn_keyword <- xml2::xml_find_first(arg_node, "./FUNCTION")
  if (!is.na(fn_keyword)) {
    return("class_function")
  }

  # Check for parenthesized expressions: (expr)
  # Structure: OP-LEFT-PAREN, expr, OP-RIGHT-PAREN
  # Recursively infer the type of the inner expression
  left_paren <- xml2::xml_find_first(arg_node, "./OP-LEFT-PAREN")
  if (!is.na(left_paren)) {
    children <- xml2::xml_children(arg_node)
    expr_children <- Filter(function(x) xml2::xml_name(x) == "expr", children)
    if (length(expr_children) == 1) {
      # Single inner expression - infer its type
      return(infer_argument_type(expr_children[[1]], var_context, current_line, type_registry, param_types))
    }
  }

  # Check for function calls THIRD (before checking their arguments/literals)

  # Check for c() function calls - infer from first arg
  c_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL[text()='c']")
  if (!is.na(c_call)) {
    first_arg <- xml2::xml_find_first(arg_node, ".//expr[SYMBOL_FUNCTION_CALL[text()='c']]/parent::expr/following-sibling::expr[1]")
    if (!is.na(first_arg)) {
      return(infer_argument_type(first_arg, var_context, current_line, type_registry, param_types))
    }
  }

  # Check for known constructor function calls
  for (fn_info in list(
    list(name = "list", type = "class_list"),
    list(name = "data.frame", type = "class_data.frame"),
    list(name = "matrix", type = "matrix"),  # matrix has no S7 class
    list(name = "raw", type = "class_raw"),
    list(name = "new.env", type = "class_environment"),
    list(name = "factor", type = "class_factor")
  )) {
    fn_call <- xml2::xml_find_first(arg_node, sprintf(".//SYMBOL_FUNCTION_CALL[text()='%s']", fn_info$name))
    if (!is.na(fn_call)) {
      return(fn_info$type)
    }
  }

  # Check for Sys.Date() - appears as single SYMBOL_FUNCTION_CALL "Sys.Date"
  sys_date <- xml2::xml_find_first(
    arg_node,
    ".//SYMBOL_FUNCTION_CALL[text()='Sys.Date']"
  )
  if (!is.na(sys_date)) {
    return("class_Date")
  }

  # Check for general function calls with @typedReturn
  # This handles user-defined functions and package functions
  # Must come AFTER specific constructors (c, list, data.frame, matrix) but BEFORE literals
  # IMPORTANT: Always check for function calls first, even without type_registry
  # This prevents falling through to literal inference (e.g., roxygen2::roclet("test") → "test")
  fn_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL")
  if (!is.na(fn_call)) {
    fn_name <- xml2::xml_text(fn_call)

    # Skip constructors we already handled
    if (!fn_name %in% c("c", "list", "data.frame", "matrix", "raw", "new.env", "factor", "Sys.Date")) {
      # Look up function in type registry (if provided)
      if (!is.null(type_registry) && fn_name %in% names(type_registry)) {
        type_info <- type_registry[[fn_name]]
        if (!is.null(type_info@return)) {
          return(type_info@return@type)
        }
      }
      # Function call not in registry (or no registry) - unknown type
      return("unknown")
    }
  }

  # Check for comparison and logical operators (they return class_logical)
  # Comparison: >, >=, <, <=, ==, !=
  comparison_ops <- xml2::xml_find_first(arg_node, ".//GT | .//GE | .//LT | .//LE | .//EQ | .//NE")
  if (!is.na(comparison_ops)) {
    return("class_logical")
  }

  # Logical operators: &, |, ! (AND, OR, NOT)
  logical_ops <- xml2::xml_find_first(arg_node, ".//AND | .//OR | .//OP-EXCLAMATION")
  if (!is.na(logical_ops)) {
    return("class_logical")
  }

  # Check for complex literals BEFORE arithmetic operators
  # Complex literals like 1+2i contain OP-PLUS but should be class_complex, not class_numeric
  num_const_complex <- xml2::xml_find_all(arg_node, ".//NUM_CONST")
  if (length(num_const_complex) > 0) {
    all_texts_complex <- vapply(num_const_complex, xml2::xml_text, character(1))
    if (any(grepl("i$", all_texts_complex, ignore.case = TRUE))) {
      return("class_complex")
    }
  }

  # Arithmetic operators: +, -, *, /, ^
  # MUST come AFTER complex literal check (1+2i has OP-PLUS but is complex, not numeric)
  # Strategy: Infer types of both operands, then apply R's type promotion rules
  arithmetic_ops <- xml2::xml_find_first(arg_node, ".//OP-PLUS | .//OP-MINUS | .//OP-STAR | .//OP-SLASH | .//OP-CARET")
  if (!is.na(arithmetic_ops)) {
    # Check operator type
    operator_name <- xml2::xml_name(arithmetic_ops)

    # Division and exponentiation ALWAYS return double in R
    # Even 4L / 2L returns 2.0, and 2L ^ 3L returns 8.0 (not 2L or 8L)
    if (operator_name %in% c("OP-SLASH", "OP-CARET")) {
      return("class_double")
    }

    # Find left and right operands
    # Structure: expr > expr (left) + OP + expr (right)
    children <- xml2::xml_children(arg_node)
    expr_children <- Filter(function(x) xml2::xml_name(x) == "expr", children)

    if (length(expr_children) >= 2) {
      # Infer types of operands (recursively)
      left_type <- infer_argument_type(expr_children[[1]], var_context, current_line, type_registry, param_types)
      right_type <- infer_argument_type(expr_children[[2]], var_context, current_line, type_registry, param_types)

      # Apply R's type promotion rules for +, -, *:
      # integer + integer = integer
      # double + double = double
      # integer + double = double (promotion to double)
      # anything + unknown = class_numeric (fallback)

      if (left_type == "class_integer" && right_type == "class_integer") {
        return("class_integer")
      } else if (left_type == "class_double" && right_type == "class_double") {
        return("class_double")
      } else if ((left_type == "class_integer" && right_type == "class_double") ||
                 (left_type == "class_double" && right_type == "class_integer")) {
        return("class_double")
      } else if (left_type %in% c("class_integer", "class_double") &&
                 right_type %in% c("class_integer", "class_double")) {
        # Both are numeric types, return more general
        return("class_double")
      }
    }

    # Fallback: if we can't determine specific types, return unknown
    # (This happens when operands are parameters without @typedParam annotations)
    return("unknown")
  }

  # Now check for literals (after ruling out function calls and operators)

  # Check for string constant
  if (length(xml2::xml_find_all(arg_node, ".//STR_CONST")) > 0) {
    return("class_character")
  }

  # Check for NULL
  if (length(xml2::xml_find_all(arg_node, ".//NULL_CONST")) > 0) {
    return("NULL")
  }

  # Check for TRUE/FALSE (they are NUM_CONST with specific text)
  num_const <- xml2::xml_find_all(arg_node, ".//NUM_CONST")
  if (length(num_const) > 0) {
    # Check all NUM_CONST nodes (for complex literals like 1+2i)
    all_texts <- vapply(num_const, xml2::xml_text, character(1))

    # Check for TRUE/FALSE
    if (all_texts[1] %in% c("TRUE", "FALSE")) {
      return("class_logical")
    }

    # Check for complex literal (any NUM_CONST ends with i, like "2i" in "1+2i")
    if (any(grepl("i$", all_texts, ignore.case = TRUE))) {
      return("class_complex")
    }

    # For remaining checks, use first NUM_CONST
    text <- all_texts[1]

    # Check for integer literal (ends with L)
    if (grepl("L$", text)) {
      return("class_integer")
    }
    # Check for double (contains decimal point or scientific notation)
    if (grepl("\\.|e|E", text)) {
      return("class_double")
    }
    # Otherwise double (bare numeric literals in R are doubles, not integers)
    return("class_double")
  }

  # Check for variable reference (SYMBOL)
  symbol_node <- xml2::xml_find_first(arg_node, "./SYMBOL[not(self::SYMBOL_FUNCTION_CALL)]")
  if (!is.na(symbol_node)) {
    var_name <- xml2::xml_text(symbol_node)

    # Check parameter types FIRST (function-scoped, most specific)
    if (var_name %in% names(param_types)) {
      return(param_types[[var_name]])
    }

    # Then check variable assignments (line-scoped)
    if (!is.null(var_context) && !is.null(current_line)) {
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
#' @param param_types Optional named list of parameter types (param_name -> type_string)
#' @return List of call_argument S7 objects
#' @keywords internal
extract_arguments <- function(call_node, var_context = NULL, current_line = NULL, type_registry = NULL, param_types = list()) {
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
          arg_type <- infer_argument_type(value_node, var_context, current_line, type_registry, param_types)
          args[[length(args) + 1]] <- call_argument(
            node = value_node,
            type = arg_type,
            position = as.integer(position),
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
      arg_type <- infer_argument_type(child, var_context, current_line, type_registry, param_types)
      args[[length(args) + 1]] <- call_argument(
        node = child,
        type = arg_type,
        position = as.integer(position),
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
#' S7-FIRST ARCHITECTURE: Resolves type strings to S7 class objects and uses
#' S7's type system for compatibility checking. Falls back to string-based
#' checking only for non-S7 types (data.frame, matrix, etc).
#'
#' @param actual Actual type string (e.g., "integer", "class_integer")
#' @param expected Expected type string
#' @return Logical
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # S7 types (uses S7::class_* compatibility)
#' types_compatible("integer", "numeric")        # TRUE (numeric = integer | double)
#' types_compatible("class_integer", "numeric")  # TRUE (same, normalized)
#'
#' # S7 inheritance (future: custom classes)
#' types_compatible("Child", "Parent")  # TRUE if Child inherits from Parent
#'
#' # Fallback for non-S7 types
#' types_compatible("data.frame", "data.frame")  # TRUE (string match)
#' types_compatible("data.frame", "matrix")      # FALSE
#' }
types_compatible <- function(actual, expected, actual_length = NULL) {
  # Parse type specifications using the proper parser
  # This handles unions correctly (NULL must be first)
  actual_ast <- tryCatch(
    parse_type_syntax(actual),
    error = function(e) NULL
  )
  expected_ast <- tryCatch(
    parse_type_syntax(expected),
    error = function(e) NULL
  )

  # If parsing failed, fall back to old behavior
  if (is.null(actual_ast) || is.null(expected_ast)) {
    actual_parsed <- parse_type_constraints(actual)
    expected_parsed <- parse_type_constraints(expected)
    actual_base <- gsub("\\(.*\\)$", "", actual_parsed$base_type)
    expected_base <- gsub("\\(.*\\)$", "", expected_parsed$base_type)

    # Old string-based compatibility
    actual_s7 <- type_string_to_s7_class(actual_base)
    expected_s7 <- type_string_to_s7_class(expected_base)

    if (!is.null(actual_s7) && !is.null(expected_s7)) {
      return(s7_class_compatible(actual_s7, expected_s7))
    }

    return(string_based_compatible(actual_base, expected_base))
  }

  # Phase 24.1: Check for external types (package::class syntax)
  # External types should use exact string matching (no inheritance checking in Phase 24.1)
  has_external_actual <- if (S7::S7_inherits(actual_ast, type_ref)) {
    !is.null(actual_ast@package)
  } else if (S7::S7_inherits(actual_ast, union_type)) {
    any(sapply(actual_ast@types, function(t) !is.null(t@package)))
  } else {
    FALSE
  }

  has_external_expected <- if (S7::S7_inherits(expected_ast, type_ref)) {
    !is.null(expected_ast@package)
  } else if (S7::S7_inherits(expected_ast, union_type)) {
    any(sapply(expected_ast@types, function(t) !is.null(t@package)))
  } else {
    FALSE
  }

  # If either type is external, use string-based matching (Phase 24.1)
  if (has_external_actual || has_external_expected) {
    # Handle union types specially
    if (S7::S7_inherits(expected_ast, union_type)) {
      # Check if actual matches any member of the union
      actual_full <- ast_to_string(actual_ast)

      for (member in expected_ast@types) {
        member_str <- if (!is.null(member@package)) {
          paste0(member@package, "::", member@base_type)
        } else {
          member@base_type
        }

        if (actual_full == member_str) {
          # Match found, check length constraint
          expected_length <- member@length_constraint
          return(check_length_constraint(actual_length, expected_length))
        }
      }

      # No match in union
      return(FALSE)
    }

    # Both are simple types (not unions)
    actual_full <- ast_to_string(actual_ast)
    expected_full <- ast_to_string(expected_ast)

    # For Phase 24.1: exact match only (no inheritance)
    # Phase 24.2 will add inheritance database lookup here
    if (actual_full != expected_full) {
      return(FALSE)
    }

    # Types match, now check constraints
    expected_length <- if (S7::S7_inherits(expected_ast, type_ref)) {
      expected_ast@length_constraint
    } else {
      NULL
    }

    return(check_length_constraint(actual_length, expected_length))
  }

  # NEW: Convert AST to S7 unions (handles NULL | Type correctly)
  actual_s7 <- tryCatch(
    rdoc_union_to_s7(actual_ast),
    error = function(e) NULL
  )
  expected_s7 <- tryCatch(
    rdoc_union_to_s7(expected_ast),
    error = function(e) NULL
  )

  # If both converted to S7, use S7's compatibility logic
  if (!is.null(actual_s7) || !is.null(expected_s7)) {
    # S7's s7_class_compatible handles unions automatically
    # It walks union members and checks if any match
    if (!s7_class_compatible(actual_s7, expected_s7)) {
      return(FALSE)
    }

    # Base types are compatible, now check constraints
    # Extract constraints from AST
    expected_length <- if (S7::S7_inherits(expected_ast, type_ref)) {
      expected_ast@length_constraint
    } else {
      NULL
    }

    # Check length constraint if specified
    if (!check_length_constraint(actual_length, expected_length)) {
      return(FALSE)
    }

    # Check element type constraint if specified
    # (Currently placeholder - returns TRUE)
    expected_element <- if (S7::S7_inherits(expected_ast, type_ref)) {
      expected_ast@element_type
    } else {
      NULL
    }

    if (!is.null(expected_element)) {
      # For now, just return TRUE (element type checking not fully implemented)
      # TODO: Implement proper element type checking
    }

    return(TRUE)
  }

  # FALLBACK: String-based compatibility for non-S7 types
  # Extract base types for comparison (with package qualification if present)
  actual_base <- if (S7::S7_inherits(actual_ast, type_ref)) {
    if (!is.null(actual_ast@package)) {
      paste0(actual_ast@package, "::", actual_ast@base_type)
    } else {
      actual_ast@base_type
    }
  } else {
    actual  # Shouldn't happen, but be safe
  }

  expected_base <- if (S7::S7_inherits(expected_ast, type_ref)) {
    if (!is.null(expected_ast@package)) {
      paste0(expected_ast@package, "::", expected_ast@base_type)
    } else {
      expected_ast@base_type
    }
  } else {
    expected
  }

  string_based_compatible(actual_base, expected_base)
}
