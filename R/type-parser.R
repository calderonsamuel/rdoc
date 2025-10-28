#' Parse type syntax into AST
#'
#' Recursive descent parser for type annotation syntax.
#'
#' Grammar (EBNF):
#' \preformatted{
#'   type_expr         ::= union_type
#'   union_type        ::= primary_type ("|" primary_type)*
#'   primary_type      ::= qualified_type element_type? length_constraint?
#'   qualified_type    ::= identifier ("::" identifier)?
#'   element_type      ::= "<" type_expr ">"
#'   length_constraint ::= "[" number "]"
#' }
#'
#' @param input Character string containing type syntax
#' @return AST object (nested list structure)
#' @keywords internal
parse_type_syntax <- function(input) {
  tokens <- lex_type_syntax(input)
  parser <- new_parser(tokens)
  ast <- parse_type_expr(parser)

  # Ensure we consumed all tokens (except EOF)
  token <- parser$current()
  if (token$type != "EOF") {
    if (token$type == "RANGLE") {
      cli::cli_abort(
        c(
          "Unexpected '>' at position {token$position}",
          "x" = "No matching '<' found"
        ),
        call = NULL
      )
    } else if (token$type == "RBRACKET") {
      cli::cli_abort(
        c(
          "Unexpected ']' at position {token$position}",
          "x" = "No matching '[' found"
        ),
        call = NULL
      )
    } else {
      cli::cli_abort(
        "Unexpected token '{token$value}' at position {token$position}",
        call = NULL
      )
    }
  }

  invisible(ast)
}

#' Create parser state object
#' @keywords internal
new_parser <- function(tokens) {
  env <- new.env(parent = emptyenv())
  env$tokens <- tokens
  env$position <- 1

  list(
    current = function() {
      env$tokens[[env$position]]
    },

    peek = function(offset = 1) {
      pos <- env$position + offset
      if (pos <= length(env$tokens)) env$tokens[[pos]] else env$tokens[[length(env$tokens)]]
    },

    advance = function() {
      if (env$position < length(env$tokens)) {
        env$position <- env$position + 1
      }
      env$tokens[[env$position]]
    },

    expect = function(token_type, context = NULL) {
      token <- env$tokens[[env$position]]
      if (token$type != token_type) {
        msg <- c(
          "Expected {token_type} at position {token$position}",
          if (!is.null(context)) c("i" = context)
        )
        cli::cli_abort(msg, call = NULL)
      }
      env$position <- env$position + 1
      token
    },

    match = function(token_type) {
      if (env$tokens[[env$position]]$type == token_type) {
        env$position <- env$position + 1
        return(TRUE)
      }
      FALSE
    }
  )
}

#' Parse type expression (top level)
#' @keywords internal
parse_type_expr <- function(parser) {
  parse_union_type(parser)
}

#' Parse union type (type1 | type2 | ...)
#' @keywords internal
parse_union_type <- function(parser) {
  token <- parser$current()

  # Check for leading pipe
  if (token$type == "PIPE") {
    cli::cli_abort(
      c(
        "Unexpected '|' at position {token$position}",
        "i" = "Union types cannot start with '|'"
      ),
      call = NULL
    )
  }

  # Parse first type
  types <- list(parse_primary_type(parser))

  # Parse additional types separated by |
  while (parser$current()$type == "PIPE") {
    pipe_token <- parser$current()
    parser$advance()

    # Check for consecutive pipes
    if (parser$current()$type == "PIPE") {
      cli::cli_abort(
        c(
          "Unexpected '|' at position {parser$current()$position}",
          "i" = "Consecutive '|' operators not allowed"
        ),
        call = NULL
      )
    }

    # Check for trailing pipe
    if (parser$current()$type == "EOF" || parser$current()$type %in% c("RANGLE", "RBRACKET")) {
      cli::cli_abort(
        c(
          "Unexpected end of input at position {parser$current()$position}",
          "i" = "Expected type after '|' at position {pipe_token$position}"
        ),
        call = NULL
      )
    }

    types <- append(types, list(parse_primary_type(parser)))
  }

  # Return single type or union
  if (length(types) == 1) {
    types[[1]]
  } else {
    # S7 validator will check NULL position and other invariants
    union_type(types = types)
  }
}

#' Parse primary type (qualified identifier with optional element type and length)
#' @keywords internal
parse_primary_type <- function(parser) {
  token <- parser$current()

  # Must start with identifier
  if (token$type != "IDENTIFIER") {
    cli::cli_abort(
      c(
        "Expected type identifier at position {token$position}",
        "x" = "Found '{token$value}' instead"
      ),
      call = NULL
    )
  }

  # Parse qualified type: package or base type
  base_type <- token$value
  package <- NULL
  parser$advance()

  # Check for package qualification (::)
  if (parser$current()$type == "DOUBLE_COLON") {
    parser$advance()

    # Next token must be identifier (the class name)
    if (parser$current()$type != "IDENTIFIER") {
      cli::cli_abort(
        c(
          "Expected class name after '::' at position {parser$current()$position}",
          "x" = "Found '{parser$current()$value}' instead",
          "i" = "Use 'package::class' syntax"
        ),
        call = NULL
      )
    }

    package <- base_type
    base_type <- parser$current()$value
    parser$advance()
  }

  # Optional element type <...>
  element_type <- NULL
  langle_pos <- NULL
  if (parser$current()$type == "LANGLE") {
    langle_pos <- parser$current()$position

    # Semantic validation: only list types can have element types
    if (base_type != "list" && base_type != "class_list") {
      cli::cli_abort(
        c(
          "Type '{base_type}' cannot have element type at position {langle_pos}",
          "i" = "Only 'list' and 'class_list' can use <T> syntax",
          "x" = "Atomic vectors like 'logical', 'numeric', 'integer', 'character' cannot contain other types"
        ),
        call = NULL
      )
    }

    parser$advance()

    # Check for empty <>
    if (parser$current()$type == "RANGLE") {
      cli::cli_abort(
        c(
          "Expected type after '<' at position {langle_pos + 1}",
          "x" = "Found empty element type '<>'"
        ),
        call = NULL
      )
    }

    element_type <- parse_type_expr(parser)

    # Expect closing >
    if (parser$current()$type != "RANGLE") {
      cli::cli_abort(
        c(
          "Expected '>' at position {parser$current()$position}",
          "i" = "To match '<' at position {langle_pos}"
        ),
        call = NULL
      )
    }
    parser$advance()

    # Check for multiple element types: list<int><char>
    if (parser$current()$type == "LANGLE") {
      cli::cli_abort(
        c(
          "Unexpected '<' at position {parser$current()$position}",
          "x" = "Type '{base_type}' already has element type",
          "i" = "Multiple element types are not allowed"
        ),
        call = NULL
      )
    }
  }

  # Optional length constraint [n]
  length_constraint <- NULL
  lbracket_pos <- NULL
  if (parser$current()$type == "LBRACKET") {
    lbracket_pos <- parser$current()$position
    parser$advance()

    # Must have number
    token <- parser$current()
    if (token$type != "NUMBER") {
      if (token$type == "RBRACKET") {
        cli::cli_abort(
          c(
            "Expected number in [] at position {lbracket_pos + 1}",
            "x" = "Found empty length constraint '[]'"
          ),
          call = NULL
        )
      } else {
        cli::cli_abort(
          c(
            "Expected number in [] at position {token$position}",
            "x" = "Found '{token$value}' instead"
          ),
          call = NULL
        )
      }
    }

    length_constraint <- as.integer(token$value)

    # Validate non-negative integer (allow 0 for zero-length vectors)
    if (is.na(length_constraint) || length_constraint < 0) {
      cli::cli_abort(
        c(
          "Invalid length constraint at position {token$position}",
          "x" = "Length must be non-negative integer, found '{token$value}'"
        ),
        call = NULL
      )
    }

    parser$advance()

    # Expect closing ]
    if (parser$current()$type != "RBRACKET") {
      cli::cli_abort(
        c(
          "Expected ']' at position {parser$current()$position}",
          "i" = "To match '[' at position {lbracket_pos}"
        ),
        call = NULL
      )
    }
    parser$advance()
  }

  type_ref(
    base_type = base_type,
    package = package,
    element_type = element_type,
    length_constraint = length_constraint
  )
}

#' Convert AST back to string representation
#' @keywords internal
ast_to_string <- function(ast) {
  if (S7::S7_inherits(ast, union_type)) {
    types_str <- sapply(ast@types, ast_to_string)
    return(paste(types_str, collapse = " | "))
  }

  # Type reference node
  result <- if (!is.null(ast@package)) {
    paste0(ast@package, "::", ast@base_type)
  } else {
    ast@base_type
  }

  if (!is.null(ast@element_type)) {
    result <- paste0(result, "<", ast_to_string(ast@element_type), ">")
  }

  if (!is.null(ast@length_constraint)) {
    result <- paste0(result, "[", ast@length_constraint, "]")
  }

  result
}

#' Validate AST semantic rules
#'
#' Note: S7 validators already enforce most invariants at construction time.
#' This function is kept for recursive validation of nested structures.
#'
#' @keywords internal
ast_validate <- function(ast) {
  # S7 constructors already validated structure at creation time
  # Just recurse for nested nodes
  if (S7::S7_inherits(ast, union_type)) {
    for (type in ast@types) {
      ast_validate(type)
    }
  } else if (S7::S7_inherits(ast, type_ref)) {
    if (!is.null(ast@element_type)) {
      ast_validate(ast@element_type)
    }
  }

  invisible(NULL)
}
