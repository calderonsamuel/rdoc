#' Tokenize type syntax string
#'
#' Breaks a type syntax string into tokens for parsing.
#'
#' @param input Character string containing type syntax
#' @return List of token objects, each with: type, value, position
#' @keywords internal
lex_type_syntax <- function(input) {
  # Trim and check for empty
  input <- trimws(input)
  if (nchar(input) == 0) {
    cli::cli_abort("Empty type specification", call = NULL)
  }

  tokens <- list()
  position <- 1
  n <- nchar(input)

  while (position <= n) {
    char <- substr(input, position, position)

    # Skip whitespace
    if (char %in% c(" ", "\t", "\n", "\r")) {
      position <- position + 1
      next
    }

    # Single-character tokens
    if (char == "<") {
      tokens <- append(tokens, list(list(type = "LANGLE", value = "<", position = position)))
      position <- position + 1
      next
    }

    if (char == ">") {
      tokens <- append(tokens, list(list(type = "RANGLE", value = ">", position = position)))
      position <- position + 1
      next
    }

    if (char == "[") {
      tokens <- append(tokens, list(list(type = "LBRACKET", value = "[", position = position)))
      position <- position + 1
      next
    }

    if (char == "]") {
      tokens <- append(tokens, list(list(type = "RBRACKET", value = "]", position = position)))
      position <- position + 1
      next
    }

    if (char == "|") {
      tokens <- append(tokens, list(list(type = "PIPE", value = "|", position = position)))
      position <- position + 1
      next
    }

    # Reject parentheses with helpful message
    if (char == "(") {
      cli::cli_abort(
        c(
          "Unexpected character '(' at position {position}",
          "i" = "Use [] for length constraints, not ()"
        ),
        call = NULL
      )
    }

    if (char == ")") {
      cli::cli_abort(
        c(
          "Unexpected character ')' at position {position}",
          "i" = "Use [] for length constraints, not ()"
        ),
        call = NULL
      )
    }

    # Reject curly braces with helpful message
    if (char == "{") {
      cli::cli_abort(
        c(
          "Unexpected character '{{' at position {position}",
          "i" = "Use [] for length constraints, not {{}}"
        ),
        call = NULL
      )
    }

    if (char == "}") {
      cli::cli_abort(
        c(
          "Unexpected character '}}' at position {position}",
          "i" = "Use [] for length constraints, not {{}}"
        ),
        call = NULL
      )
    }

    # Identifier (letters, digits, dots, underscores)
    # Must start with letter, can contain digits, dots, and underscores
    if (grepl("[A-Za-z]", char)) {
      start_pos <- position
      value <- ""

      while (position <= n) {
        char <- substr(input, position, position)
        if (grepl("[A-Za-z0-9._]", char)) {
          value <- paste0(value, char)
          position <- position + 1
        } else {
          break
        }
      }

      tokens <- append(tokens, list(list(type = "IDENTIFIER", value = value, position = start_pos)))
      next
    }

    # Number (only valid inside brackets)
    # Check if we're inside brackets by looking at previous token
    if (grepl("[0-9]", char)) {
      # Check if previous token was LBRACKET
      inside_brackets <- length(tokens) > 0 && tokens[[length(tokens)]]$type == "LBRACKET"

      if (!inside_brackets) {
        # Find what identifier this number is attached to for better error
        cli::cli_abort(
          c(
            "Unexpected number '{char}' at position {position}",
            "i" = "Numbers must be inside [] for length constraints",
            "x" = "Use 'type[{char}]' not 'type{char}'"
          ),
          call = NULL
        )
      }

      start_pos <- position
      value <- ""

      while (position <= n && grepl("[0-9]", substr(input, position, position))) {
        value <- paste0(value, substr(input, position, position))
        position <- position + 1
      }

      tokens <- append(tokens, list(list(type = "NUMBER", value = value, position = start_pos)))
      next
    }

    # Invalid character
    cli::cli_abort(
      "Unexpected character '{char}' at position {position}",
      call = NULL
    )
  }

  # Add EOF token
  tokens <- append(tokens, list(list(type = "EOF", value = "", position = position)))

  tokens
}
