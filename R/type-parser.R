#' Parse type syntax into AST
#'
#' Recursive descent parser for type annotation syntax.
#'
#' Grammar (EBNF):
#' \preformatted{
#'   type_expr         ::= union_type
#'   union_type        ::= primary_type ("|" primary_type)*
#'   primary_type      ::= qualified_type element_type?
#'   qualified_type    ::= identifier ("::" identifier)?
#'   element_type      ::= "<" type_expr ">"
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
  if (token@type != "EOF") {
    if (token@type == "RANGLE") {
      cli::cli_abort(
        c(
          "Unexpected '>' at position {token@position}",
          "x" = "No matching '<' found"
        ),
        call = NULL
      )
    } else if (token@type == "RBRACKET") {
      cli::cli_abort(
        c(
          "Unexpected ']' at position {token@position}",
          "x" = "No matching '[' found"
        ),
        call = NULL
      )
    } else {
      cli::cli_abort(
        "Unexpected token '{token@value}' at position {token@position}",
        call = NULL
      )
    }
  }

  invisible(ast)
}

#' Parser State (R6 Class)
#'
#' Mutable state machine for parsing type syntax. Manages token stream
#' and current position with bounds checking and validation.
#'
#' @keywords internal
ParserState <- R6::R6Class(
  "ParserState",
  private = list(
    tokens = NULL,
    position = NULL,

    check_bounds = function() {
      if (private$position < 1 || private$position > length(private$tokens)) {
        cli::cli_abort(
          c(
            "Parser position out of bounds",
            "x" = "Position {private$position} exceeds token list length {length(private$tokens)}"
          ),
          call = NULL
        )
      }
    }
  ),

  public = list(
    #' @description Initialize parser with token list
    #' @param tokens List of S7 token objects from lexer
    initialize = function(tokens) {
      # Validate all tokens are S7 token objects
      if (!all(vapply(tokens, function(t) S7::S7_inherits(t, token), logical(1)))) {
        cli::cli_abort(
          c(
            "Invalid token list",
            "x" = "All tokens must be S7 token objects"
          ),
          call = NULL
        )
      }

      private$tokens <- tokens
      private$position <- 1L
    },

    #' @description Get current token without advancing
    #' @return Current S7 token object
    current = function() {
      private$check_bounds()
      private$tokens[[private$position]]
    },

    #' @description Peek ahead at future token without advancing
    #' @param offset Integer offset from current position (default: 1)
    #' @return S7 token object at offset position, or last token if beyond end
    peek = function(offset = 1) {
      pos <- private$position + offset
      if (pos <= length(private$tokens)) {
        private$tokens[[pos]]
      } else {
        private$tokens[[length(private$tokens)]]
      }
    },

    #' @description Advance to next token
    #' @return New current S7 token object after advancing
    advance = function() {
      if (private$position < length(private$tokens)) {
        private$position <- private$position + 1L
      }
      private$check_bounds()
      private$tokens[[private$position]]
    },

    #' @description Expect specific token type and advance
    #' @param token_type Character string with expected token type
    #' @param context Optional context message for error reporting
    #' @return S7 token object that was matched
    expect = function(token_type, context = NULL) {
      token <- private$tokens[[private$position]]
      if (token@type != token_type) {
        msg <- c(
          "Expected {token_type} at position {token@position}",
          if (!is.null(context)) c("i" = context)
        )
        cli::cli_abort(msg, call = NULL)
      }
      private$position <- private$position + 1L
      private$check_bounds()
      token
    },

    #' @description Try to match token type and advance if successful
    #' @param token_type Character string with token type to match
    #' @return TRUE if matched and advanced, FALSE otherwise
    match = function(token_type) {
      if (private$tokens[[private$position]]@type == token_type) {
        private$position <- private$position + 1L
        return(TRUE)
      }
      FALSE
    }
  )
)

#' Create parser state object
#'
#' Factory function that creates a ParserState R6 object.
#' Validates tokens and initializes mutable state machine.
#'
#' @param tokens List of S7 token objects from lexer
#' @return ParserState R6 object with methods: current(), peek(), advance(), expect(), match()
#' @keywords internal
new_parser <- function(tokens) {
  ParserState$new(tokens)
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
  if (token@type == "PIPE") {
    cli::cli_abort(
      c(
        "Unexpected '|' at position {token@position}",
        "i" = "Union types cannot start with '|'"
      ),
      call = NULL
    )
  }

  # Parse first type
  types <- list(parse_primary_type(parser))

  # Parse additional types separated by |
  while (parser$current()@type == "PIPE") {
    pipe_token <- parser$current()
    parser$advance()

    # Check for consecutive pipes
    if (parser$current()@type == "PIPE") {
      cli::cli_abort(
        c(
          "Unexpected '|' at position {parser$current()@position}",
          "i" = "Consecutive '|' operators not allowed"
        ),
        call = NULL
      )
    }

    # Check for trailing pipe
    if (parser$current()@type == "EOF" || parser$current()@type %in% c("RANGLE", "RBRACKET")) {
      cli::cli_abort(
        c(
          "Unexpected end of input at position {parser$current()@position}",
          "i" = "Expected type after '|' at position {pipe_token@position}"
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
  if (token@type != "IDENTIFIER") {
    cli::cli_abort(
      c(
        "Expected type identifier at position {token@position}",
        "x" = "Found '{token@value}' instead"
      ),
      call = NULL
    )
  }

  # Parse qualified type: package or base type
  base_type <- token@value
  package <- NULL
  parser$advance()

  # Check for package qualification (::)
  if (parser$current()@type == "DOUBLE_COLON") {
    parser$advance()

    # Next token must be identifier (the class name)
    if (parser$current()@type != "IDENTIFIER") {
      cli::cli_abort(
        c(
          "Expected class name after '::' at position {parser$current()@position}",
          "x" = "Found '{parser$current()@value}' instead",
          "i" = "Use 'package::class' syntax"
        ),
        call = NULL
      )
    }

    package <- base_type
    base_type <- parser$current()@value
    parser$advance()
  }

  # Optional element type <...>
  element_type <- NULL
  langle_pos <- NULL
  if (parser$current()@type == "LANGLE") {
    langle_pos <- parser$current()@position

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
    if (parser$current()@type == "RANGLE") {
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
    if (parser$current()@type != "RANGLE") {
      cli::cli_abort(
        c(
          "Expected '>' at position {parser$current()@position}",
          "i" = "To match '<' at position {langle_pos}"
        ),
        call = NULL
      )
    }
    parser$advance()

    # Check for multiple element types: list<int><char>
    if (parser$current()@type == "LANGLE") {
      cli::cli_abort(
        c(
          "Unexpected '<' at position {parser$current()@position}",
          "x" = "Type '{base_type}' already has element type",
          "i" = "Multiple element types are not allowed"
        ),
        call = NULL
      )
    }
  }

  # Reject square brackets (length constraints not supported)
  if (parser$current()@type == "LBRACKET") {
    cli::cli_abort(
      c(
        "Unexpected '[' at position {parser$current()@position}"
      ),
      call = NULL
    )
  }

  type_ref(
    base_type = base_type,
    package = package,
    element_type = element_type
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
