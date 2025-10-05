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
        types = list()
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

    # If no types, nothing to lint
    if (length(all_types) == 0) {
      return(list())
    }

    # Find and check function calls
    check_function_calls(xml, all_types, source_expression)
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
#' @param source_expression Source expression for creating lints
#' @return List of Lint objects
#' @keywords internal
check_function_calls <- function(xml, all_types, source_expression) {
  lints <- list()

  # Find all function calls
  # XPath: Find the outer expr containing a function call
  # Structure: expr > expr > SYMBOL_FUNCTION_CALL
  call_nodes <- xml2::xml_find_all(xml, "//SYMBOL_FUNCTION_CALL/parent::expr/parent::expr")

  for (call_node in call_nodes) {
    lint <- check_single_call(call_node, all_types, source_expression)
    if (!is.null(lint)) {
      lints <- c(lints, list(lint))
    }
  }

  lints
}

#' Check a single function call
#'
#' @param call_node XML node of the function call
#' @param all_types List of type information
#' @param source_expression Source expression
#' @return Lint object or NULL
#' @keywords internal
check_single_call <- function(call_node, all_types, source_expression) {
  # Get function name
  fn_node <- xml2::xml_find_first(call_node, ".//SYMBOL_FUNCTION_CALL")
  if (is.na(fn_node)) {
    return(NULL)
  }

  fn_name <- xml2::xml_text(fn_node)

  # Check if we have type info for this function
  if (!fn_name %in% names(all_types)) {
    return(NULL)
  }

  type_info <- all_types[[fn_name]]

  # Get arguments
  args <- extract_arguments(call_node)

  # Check each argument against type signature
  check_arguments(fn_name, args, type_info, call_node, source_expression)
}

#' Extract arguments from function call
#'
#' @param call_node XML node of function call
#' @return List of argument information
#' @keywords internal
extract_arguments <- function(call_node) {
  # The call_node structure is: expr containing:
  #   - expr with SYMBOL_FUNCTION_CALL (the function name)
  #   - OP-LEFT-PAREN
  #   - expr nodes (the arguments)
  #   - OP-RIGHT-PAREN

  # Get all child expr nodes
  all_exprs <- xml2::xml_find_all(call_node, "./expr")

  # First expr is the function name, rest are arguments
  if (length(all_exprs) <= 1) {
    return(list())  # No arguments
  }

  arg_nodes <- all_exprs[-1]  # Skip first (function name)

  args <- list()
  for (i in seq_along(arg_nodes)) {
    arg_type <- infer_argument_type(arg_nodes[[i]])
    args[[i]] <- list(
      node = arg_nodes[[i]],
      type = arg_type,
      position = i
    )
  }

  args
}

#' Infer type of an argument from its AST node
#'
#' @param arg_node XML node of the argument
#' @return Character string with inferred type or "unknown"
#' @keywords internal
infer_argument_type <- function(arg_node) {
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
#' @return Lint object or NULL
#' @keywords internal
check_arguments <- function(fn_name, args, type_info, call_node, source_expression) {
  if (is.null(type_info$params)) {
    return(NULL)
  }

  # For now, check positional arguments only
  param_names <- names(type_info$params)

  for (i in seq_along(args)) {
    if (i > length(param_names)) {
      break
    }

    expected_type <- type_info$params[[param_names[i]]]$type
    actual_type <- args[[i]]$type

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

      return(lintr::Lint(
        filename = source_expression$filename,
        line_number = line,
        column_number = col,
        type = "warning",
        message = sprintf(
          "Argument '%s' expects type '%s' but got '%s'",
          param_names[i],
          expected_type,
          actual_type
        ),
        line = line_text,
        ranges = list(c(col, col_end))
      ))
    }
  }

  NULL
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
