#' Extract types from a vector of comment lines
#'
#' @param comments Character vector of comment lines
#' @return List with params and return type info
#' @keywords internal
#' @importFrom utils tail
extract_types_from_comment_lines <- function(comments) {
  param_types <- list()
  return_type <- NULL

  for (comment_text in comments) {
    content <- sub("^#'\\s*", "", comment_text)

    # Check for @typedParam
    if (grepl("^@typedParam\\s+", content)) {
      param_text <- sub("^@typedParam\\s+", "", content)
      # Parse - catch errors to allow linting to continue
      parsed_param <- try(parse_typed_param_text(param_text), silent = TRUE)

      if (!inherits(parsed_param, "try-error")) {
        param_types[[parsed_param$param]] <- list(
          type = parsed_param$type,
          description = parsed_param$description
        )
      }
      # Note: Validation errors will be reported separately by syntax validation linter
    }

    # Check for @typedReturn
    if (grepl("^@typedReturn\\s+", content)) {
      return_text <- sub("^@typedReturn\\s+", "", content)
      # Parse - catch errors to allow linting to continue
      parsed_return <- try(parse_typed_return_text(return_text), silent = TRUE)

      if (!inherits(parsed_return, "try-error")) {
        return_type <- list(
          type = parsed_return$type,
          description = parsed_return$description
        )
      }
      # Note: Validation errors will be reported separately by syntax validation linter
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
        # Parse - catch errors to allow linting to continue
        parsed_param <- try(parse_typed_param_text(param_text), silent = TRUE)

        if (!inherits(parsed_param, "try-error")) {
          param_types[[parsed_param$param]] <- list(
            type = parsed_param$type,
            description = parsed_param$description
          )
        }
        # Note: Validation errors will be reported separately by syntax validation linter
      }

      # Check for @typedReturn
      if (grepl("^@typedReturn\\s+", content)) {
        return_text <- sub("^@typedReturn\\s+", "", content)
        # Parse - catch errors to allow linting to continue
        parsed_return <- try(parse_typed_return_text(return_text), silent = TRUE)

        if (!inherits(parsed_return, "try-error")) {
          return_type <- list(
            type = parsed_return$type,
            description = parsed_return$description
          )
        }
        # Note: Validation errors will be reported separately by syntax validation linter
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
      # Parse - catch errors to allow linting to continue
      parsed_param <- try(parse_typed_param_text(param_text), silent = TRUE)

      if (!inherits(parsed_param, "try-error")) {
        if (is.null(param_types)) param_types <- list()
        param_types[[parsed_param$param]] <- list(
          type = parsed_param$type,
          description = parsed_param$description
        )
      }
      # Note: Validation errors will be reported separately by syntax validation linter
    }

    # Check for @typedReturn
    if (grepl("^@typedReturn\\s+", content)) {
      return_text <- sub("^@typedReturn\\s+", "", content)
      # Parse - catch errors to allow linting to continue
      parsed_return <- try(parse_typed_return_text(return_text), silent = TRUE)

      if (!inherits(parsed_return, "try-error")) {
        return_type <- list(
          type = parsed_return$type,
          description = parsed_return$description
        )
      }
      # Note: Validation errors will be reported separately by syntax validation linter
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

  param_name <- matches[2]
  type_spec <- matches[3]
  description <- matches[4]

  # Validate type syntax
  validate_type_syntax(type_spec, source_location = paste0("@typedParam ", param_name))

  list(
    param = param_name,
    type = type_spec,
    description = description
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

  type_spec <- matches[2]
  description <- matches[3]

  # Validate type syntax
  validate_type_syntax(type_spec, source_location = "@typedReturn")

  list(
    type = type_spec,
    description = description
  )
}
