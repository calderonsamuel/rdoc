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

    # Extract and accumulate variable assignments
    assignments <- extract_variable_assignments(xml)
    for (var_name in names(assignments)) {
      for (assignment in assignments[[var_name]]) {
        # Infer type from the assigned value
        inferred_type <- infer_argument_type(assignment$value_node)

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

    # If no types, nothing to lint
    if (length(all_types) == 0) {
      return(list())
    }

    # Find and check function calls
    check_function_calls(xml, all_types, cache$variables, source_expression)
  })
}

#' Extract types from a vector of comment lines
#'
#' @param comments Character vector of comment lines
#' @return List with params and return type info
#' @keywords internal
extract_types_from_comment_lines <- function(comments) {
  param_types <- list()
  return_type <- NULL

  for (comment_text in comments) {
    content <- sub("^#'\\s*", "", comment_text)

    # Check for @typedParam
    if (grepl("^@typedParam\\s+", content)) {
      param_text <- sub("^@typedParam\\s+", "", content)
      parsed_param <- try(parse_typed_param_text(param_text), silent = TRUE)

      if (!inherits(parsed_param, "try-error")) {
        param_types[[parsed_param$param]] <- list(
          type = parsed_param$type,
          description = parsed_param$description
        )
      }
    }

    # Check for @typedReturn
    if (grepl("^@typedReturn\\s+", content)) {
      return_text <- sub("^@typedReturn\\s+", "", content)
      parsed_return <- try(parse_typed_return_text(return_text), silent = TRUE)

      if (!inherits(parsed_return, "try-error")) {
        return_type <- list(
          type = parsed_return$type,
          description = parsed_return$description
        )
      }
    }
  }

  # Build result
  if (length(param_types) == 0 && is.null(return_type)) {
    return(NULL)
  }

  result <- list()
  if (length(param_types) > 0) {
    result$params <- param_types
  }
  if (!is.null(return_type)) {
    result$return <- return_type
  }

  result
}

#' Extract type signatures from local roxygen comments
#'
#' @param source_expression Source expression from lintr
#' @return List of type information per function
#' @keywords internal
extract_local_types <- function(source_expression) {
  # Try XML first (more commonly available in lintr)
  xml <- source_expression$xml_parsed_content
  if (!is.null(xml)) {
    return(extract_types_from_xml(xml))
  }

  # Fallback to full_parsed_content
  parsed <- source_expression$full_parsed_content

  if (is.null(parsed) || nrow(parsed) == 0) {
    return(list())
  }

  # Find roxygen comment blocks
  # Comments have token "COMMENT" and text starting with "#'"
  comments <- parsed[parsed$token == "COMMENT", , drop = FALSE]

  if (nrow(comments) == 0) {
    return(list())
  }

  # Group comments into blocks and extract type info
  extract_types_from_comments(comments, parsed)
}

#' Extract types from XML
#'
#' @param xml XML parsed content
#' @return List of type information
#' @keywords internal
extract_types_from_xml <- function(xml) {
  types <- list()

  # Find all function assignments
  # Structure: expr > expr[SYMBOL] + LEFT_ASSIGN + expr[FUNCTION]
  # XPath: Find expr that has LEFT_ASSIGN child and contains FUNCTION somewhere
  fn_assigns <- xml2::xml_find_all(xml, "//expr[LEFT_ASSIGN and .//FUNCTION]")

  for (fn_assign in fn_assigns) {
    # Get function name from the first child expr containing SYMBOL
    symbol_node <- xml2::xml_find_first(fn_assign, "./expr/SYMBOL")
    if (is.na(symbol_node)) next

    fn_name <- xml2::xml_text(symbol_node)

    # Find preceding comments (go up to find siblings that are comments)
    # Get the line of this function
    fn_line <- as.integer(xml2::xml_attr(fn_assign, "line1"))

    # Find all COMMENT nodes before this line
    all_comments <- xml2::xml_find_all(xml, "//COMMENT")

    # Collect comments immediately before this function
    relevant_comments <- character()
    for (comment_node in all_comments) {
      comment_line <- as.integer(xml2::xml_attr(comment_node, "line1"))
      if (comment_line < fn_line && comment_line >= fn_line - 10) {  # Within 10 lines
        comment_text <- xml2::xml_text(comment_node)
        if (grepl("^#'", comment_text)) {
          relevant_comments <- c(relevant_comments, comment_text)
        }
      }
    }

    # Parse the comments for type info
    param_types <- list()
    return_type <- NULL

    for (comment_text in relevant_comments) {
      content <- sub("^#'\\s*", "", comment_text)

      # Check for @typedParam
      if (grepl("^@typedParam\\s+", content)) {
        param_text <- sub("^@typedParam\\s+", "", content)
        parsed_param <- try(parse_typed_param_text(param_text), silent = TRUE)

        if (!inherits(parsed_param, "try-error")) {
          param_types[[parsed_param$param]] <- list(
            type = parsed_param$type,
            description = parsed_param$description
          )
        }
      }

      # Check for @typedReturn
      if (grepl("^@typedReturn\\s+", content)) {
        return_text <- sub("^@typedReturn\\s+", "", content)
        parsed_return <- try(parse_typed_return_text(return_text), silent = TRUE)

        if (!inherits(parsed_return, "try-error")) {
          return_type <- list(
            type = parsed_return$type,
            description = parsed_return$description
          )
        }
      }
    }

    # Save if we found type info
    if (length(param_types) > 0 || !is.null(return_type)) {
      result_types <- list()
      if (length(param_types) > 0) {
        result_types$params <- param_types
      }
      if (!is.null(return_type)) {
        result_types$return <- return_type
      }

      types[[fn_name]] <- result_types
    }
  }

  types
}

#' Extract type information from comment blocks
#'
#' @param comments Data frame of comment lines
#' @param parsed Full parsed content
#' @return List of type information
#' @keywords internal
extract_types_from_comments <- function(comments, parsed) {
  types <- list()

  if (nrow(comments) == 0) {
    return(types)
  }

  # Group comments into blocks (consecutive roxygen comments)
  blocks <- list()
  current_block_lines <- integer()
  current_block_text <- character()

  for (i in seq_len(nrow(comments))) {
    line_text <- comments$text[i]
    line_num <- comments$line1[i]

    if (!grepl("^#'", line_text)) {
      next
    }

    # Start new block or continue current
    if (length(current_block_lines) == 0 || line_num == tail(current_block_lines, 1) + 1) {
      current_block_lines <- c(current_block_lines, line_num)
      current_block_text <- c(current_block_text, line_text)
    } else {
      # Save previous block and start new one
      if (length(current_block_lines) > 0) {
        blocks[[length(blocks) + 1]] <- list(
          lines = current_block_lines,
          text = current_block_text
        )
      }
      current_block_lines <- line_num
      current_block_text <- line_text
    }
  }

  # Save last block
  if (length(current_block_lines) > 0) {
    blocks[[length(blocks) + 1]] <- list(
      lines = current_block_lines,
      text = current_block_text
    )
  }

  # Process each block
  for (block in blocks) {
    block_info <- process_comment_block(block, parsed)
    if (!is.null(block_info$fn_name) && length(block_info$types) > 0) {
      types[[block_info$fn_name]] <- block_info$types
    }
  }

  types
}

#' Process a single comment block
#'
#' @param block List with lines and text
#' @param parsed Full parsed content
#' @return List with fn_name and types
#' @keywords internal
process_comment_block <- function(block, parsed) {
  param_types <- list()
  return_type <- NULL
  fn_name <- NULL

  # Extract type information from comments
  for (line_text in block$text) {
    content <- sub("^#'\\s*", "", line_text)

    # Check for @typedParam
    if (grepl("^@typedParam\\s+", content)) {
      param_text <- sub("^@typedParam\\s+", "", content)
      parsed_param <- try(parse_typed_param_text(param_text), silent = TRUE)

      if (!inherits(parsed_param, "try-error")) {
        if (is.null(param_types)) param_types <- list()
        param_types[[parsed_param$param]] <- list(
          type = parsed_param$type,
          description = parsed_param$description
        )
      }
    }

    # Check for @typedReturn
    if (grepl("^@typedReturn\\s+", content)) {
      return_text <- sub("^@typedReturn\\s+", "", content)
      parsed_return <- try(parse_typed_return_text(return_text), silent = TRUE)

      if (!inherits(parsed_return, "try-error")) {
        return_type <- list(
          type = parsed_return$type,
          description = parsed_return$description
        )
      }
    }
  }

  # Find function name - look for SYMBOL followed by LEFT_ASSIGN or EQ_ASSIGN
  # on the line after the comment block
  last_comment_line <- max(block$lines)

  # Look for function definition starting from next line
  fn_lines <- parsed[parsed$line1 >= last_comment_line + 1 &
                      parsed$line1 <= last_comment_line + 3, , drop = FALSE]

  if (nrow(fn_lines) > 0) {
    # Find SYMBOL before assignment or FUNCTION keyword
    symbols <- fn_lines[fn_lines$token == "SYMBOL", , drop = FALSE]
    if (nrow(symbols) > 0) {
      fn_name <- symbols$text[1]
    }
  }

  # Build result
  result_types <- list()
  if (length(param_types) > 0) {
    result_types$params <- param_types
  }
  if (!is.null(return_type)) {
    result_types$return <- return_type
  }

  list(
    fn_name = fn_name,
    types = result_types
  )
}

#' Parse typed param text
#'
#' @param text Text after @typedParam
#' @return List with param, type, description
#' @keywords internal
parse_typed_param_text <- function(text) {
  pattern <- "^(\\S+)\\s+\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(text, regexec(pattern, text))[[1]]

  if (length(matches) != 4) {
    stop("Invalid format")
  }

  list(
    param = matches[2],
    type = matches[3],
    description = matches[4]
  )
}

#' Parse typed return text
#'
#' @param text Text after @typedReturn
#' @return List with type, description
#' @keywords internal
parse_typed_return_text <- function(text) {
  pattern <- "^\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(text, regexec(pattern, text))[[1]]

  if (length(matches) != 3) {
    stop("Invalid format")
  }

  list(
    type = matches[2],
    description = matches[3]
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

#' Check function calls against type signatures
#'
#' @param xml XML parsed content
#' @param all_types List of all type information
#' @param var_context List of variable assignments
#' @param source_expression Source expression for creating lints
#' @return List of Lint objects
#' @keywords internal
check_function_calls <- function(xml, all_types, var_context, source_expression) {
  lints <- list()

  # Find all function calls
  # XPath: Find the outer expr containing a function call
  # Structure: expr > expr > SYMBOL_FUNCTION_CALL
  call_nodes <- xml2::xml_find_all(xml, "//SYMBOL_FUNCTION_CALL/parent::expr/parent::expr")

  for (call_node in call_nodes) {
    call_lints <- check_single_call(call_node, all_types, var_context, source_expression)
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
#' @return List of Lint objects
#' @keywords internal
check_single_call <- function(call_node, all_types, var_context, source_expression) {
  # Get function name
  fn_node <- xml2::xml_find_first(call_node, ".//SYMBOL_FUNCTION_CALL")
  if (is.na(fn_node)) {
    return(list())
  }

  fn_name <- xml2::xml_text(fn_node)

  # Check if we have type info for this function
  if (!fn_name %in% names(all_types)) {
    return(list())
  }

  type_info <- all_types[[fn_name]]

  # Get line number of this call for variable lookup
  call_line <- as.integer(xml2::xml_attr(call_node, "line1"))
  if (is.na(call_line)) call_line <- 1L

  # Get arguments
  args <- extract_arguments(call_node, var_context, call_line)

  # Check each argument against type signature
  check_arguments(fn_name, args, type_info, call_node, source_expression)
}

#' Extract arguments from function call
#'
#' @param call_node XML node of function call
#' @param var_context Optional list of variable assignments for type inference
#' @param current_line Optional line number for variable lookup
#' @return List of argument information
#' @keywords internal
extract_arguments <- function(call_node, var_context = NULL, current_line = NULL) {
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
          arg_type <- infer_argument_type(value_node, var_context, current_line)
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
        # This might be the function name, check for SYMBOL_FUNCTION_CALL
        if (length(xml2::xml_find_all(child, ".//SYMBOL_FUNCTION_CALL")) > 0) {
          # Skip function name
          i <- i + 1
          next
        }
      }
      # This is a positional argument
      arg_type <- infer_argument_type(child, var_context, current_line)
      args[[length(args) + 1]] <- list(
        node = child,
        type = arg_type,
        position = position,
        name = NA_character_
      )
      position <- position + 1
    }

    i <- i + 1
  }

  args
}

#' Infer type of an argument from its AST node
#'
#' @param arg_node XML node of the argument
#' @param var_context Optional list of variable assignments for lookup
#' @param current_line Optional line number where argument is used (for variable lookup)
#' @return Character string with inferred type or "unknown"
#' @keywords internal
infer_argument_type <- function(arg_node, var_context = NULL, current_line = NULL) {
  # Check for function calls FIRST (before checking their arguments/literals)

  # Check for c() function calls
  c_call <- xml2::xml_find_first(arg_node, ".//SYMBOL_FUNCTION_CALL[text()='c']")
  if (!is.na(c_call)) {
    # Get the first argument to c() to infer type
    first_arg <- xml2::xml_find_first(arg_node, ".//expr[SYMBOL_FUNCTION_CALL[text()='c']]/parent::expr/following-sibling::expr[1]")
    if (!is.na(first_arg)) {
      return(infer_argument_type(first_arg, var_context, current_line))
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

  # Now check for literals (after ruling out function calls)

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

#' Check arguments against type signature
#'
#' @param fn_name Function name
#' @param args List of arguments
#' @param type_info Type information for function
#' @param call_node XML node of the call
#' @param source_expression Source expression
#' @return List of Lint objects
#' @keywords internal
check_arguments <- function(fn_name, args, type_info, call_node, source_expression) {
  if (is.null(type_info$params)) {
    return(list())
  }

  param_names <- names(type_info$params)
  positional_index <- 1
  lints <- list()

  for (i in seq_along(args)) {
    arg <- args[[i]]

    # Determine which parameter this argument corresponds to
    if (!is.na(arg$name)) {
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

    # Skip if we can't infer the type
    if (actual_type == "unknown") {
      next
    }

    # Check type compatibility
    if (!types_compatible(actual_type, expected_type)) {
      # Create a lint
      # Get line and column from XML (these are absolute line numbers in the file)
      line <- as.integer(xml2::xml_attr(args[[i]]$node, "line1"))
      col <- as.integer(xml2::xml_attr(args[[i]]$node, "col1"))
      col_end <- as.integer(xml2::xml_attr(args[[i]]$node, "col2"))

      # Handle NA values
      if (is.na(line)) line <- 1L
      if (is.na(col)) col <- 1L
      if (is.na(col_end)) col_end <- col

      # Get the actual line text from the file
      # source_expression$lines only contains the current expression, not the whole file
      # So we need to read the file to get the correct line content
      line_text <- get_line_from_file(source_expression$filename, line)

      # Ensure columns are within bounds
      max_col <- nchar(line_text) + 1L
      col <- as.integer(min(max(col, 1L), max_col))
      col_end <- as.integer(min(max(col_end, 1L), max_col))

      # Final NA check
      if (is.na(col)) col <- 1L
      if (is.na(col_end)) col_end <- col

      lints[[length(lints) + 1]] <- lintr::Lint(
        filename = source_expression$filename,
        line_number = line,
        column_number = col,
        type = "warning",
        message = sprintf(
          "Argument '%s' expects type '%s' but got '%s'",
          param_name,
          expected_type,
          actual_type
        ),
        line = line_text,
        ranges = list(c(col, col_end))
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

  # Handle union types
  if (grepl("\\|", expected)) {
    expected_types <- split_union_types(expected)
    expected_bases <- gsub("\\(.*\\)$", "", trimws(expected_types))
    return(actual_base %in% expected_bases)
  }

  # Numeric compatibility
  if (expected_base %in% c("numeric", "double") && actual_base %in% c("numeric", "integer", "double")) {
    return(TRUE)
  }

  FALSE
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
