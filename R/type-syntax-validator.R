#' Validate type annotation syntax
#'
#' Checks for common malformed patterns and provides clear error messages.
#' This function is called before parsing to catch syntax errors early.
#'
#' @param type_spec Type specification string (e.g., "class_integer\[1\]")
#' @param source_location Optional location info for error messages
#' @return Invisible NULL if valid, aborts with error if invalid
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' validate_type_syntax("class_integer[1]")  # Valid - returns NULL
#' validate_type_syntax("class_list<>")      # Invalid - aborts with error
#' validate_type_syntax("class_list<int><char>")  # Invalid - aborts
#' }
validate_type_syntax <- function(type_spec, source_location = NULL) {
  errors <- character()

  # Trim whitespace for validation
  trimmed <- trimws(type_spec)

  # Check 1: Empty type spec
  if (nchar(trimmed) == 0) {
    errors <- c(errors, "Empty type specification")
  }

  # Check 2: Empty angle brackets
  if (grepl("<\\s*>", type_spec)) {
    errors <- c(errors, "Empty element type: '<>' is not allowed")
  }

  # Check 3: Multiple consecutive angle brackets (indicates multiple element types)
  # Matches patterns like: <int><char> or >foo<bar>
  if (grepl("><", type_spec)) {
    errors <- c(errors, "Multiple element types: only one '<T>' allowed per type")
  }

  # Check 4: Empty square brackets
  if (grepl("\\[\\s*\\]", type_spec)) {
    errors <- c(errors, "Empty length constraint: '[]' must contain a number")
  }

  # Check 5: Non-numeric in square brackets
  # Match [...] where content is not purely digits
  bracket_content <- regmatches(type_spec, gregexpr("\\[([^\\]]+)\\]", type_spec, perl = TRUE))[[1]]
  for (content in bracket_content) {
    # Extract just the content between brackets
    inner <- gsub("^\\[|\\]$", "", content)
    inner_trimmed <- trimws(inner)
    if (!grepl("^[0-9]+$", inner_trimmed)) {
      errors <- c(errors, sprintf("Invalid length constraint: '[%s]' must be a positive integer", inner))
    }
  }

  # Check 6: Unbalanced angle brackets
  open_angle <- lengths(regmatches(type_spec, gregexpr("<", type_spec, fixed = TRUE)))
  close_angle <- lengths(regmatches(type_spec, gregexpr(">", type_spec, fixed = TRUE)))
  if (open_angle != close_angle) {
    errors <- c(errors, sprintf("Unbalanced angle brackets: %d '<' but %d '>' (must match)", open_angle, close_angle))
  }

  # Check 7: Unbalanced square brackets
  open_square <- lengths(regmatches(type_spec, gregexpr("[", type_spec, fixed = TRUE)))
  close_square <- lengths(regmatches(type_spec, gregexpr("]", type_spec, fixed = TRUE)))
  if (open_square != close_square) {
    errors <- c(errors, sprintf("Unbalanced square brackets: %d '[' but %d ']' (must match)", open_square, close_square))
  }

  # Check 8: Pipe at start or end (invalid union)
  if (grepl("^\\s*\\|", type_spec) || grepl("\\|\\s*$", type_spec)) {
    errors <- c(errors, "Invalid union: cannot start or end with '|'")
  }

  # Check 9: Multiple consecutive pipes
  if (grepl("\\|\\s*\\|", type_spec)) {
    errors <- c(errors, "Invalid union: consecutive '|' operators not allowed")
  }

  # Check 10: Parenthesis syntax (incorrect - should use brackets)
  if (grepl("\\([0-9]+\\)", type_spec)) {
    errors <- c(errors, "Invalid syntax: use '[n]' for length constraints, not '(n)'")
  }

  # Check 11: Curly braces for length (should use square brackets)
  # Match both complete {n} and incomplete {n patterns
  if (grepl("\\{[0-9]+", type_spec)) {
    errors <- c(errors, "Invalid syntax: use '[n]' for length constraints, not '{{n}}'")
  }

  # Check 12: Bare number after type name (missing brackets)
  # Match: word followed immediately by digit(s) at end of string or before |
  # e.g., "numeric1", "character5", but NOT "character[100]"
  # Only match if the number is NOT followed by a bracket
  if (grepl("\\w+[0-9]+(?![\\[<>()\\]])", type_spec, perl = TRUE)) {
    # But exclude cases where brackets exist elsewhere (like character[100])
    # Simple check: if there are digits but no opening bracket, it's an error
    if (!grepl("\\[", type_spec)) {
      errors <- c(errors, "Invalid syntax: numbers must be in brackets, e.g., 'numeric[1]' not 'numeric1'")
    }
  }

  # Report errors
  if (length(errors) > 0) {
    # Build error message with helpful context
    if (!is.null(source_location)) {
      # We know which tag caused the error
      header <- "Invalid type annotation syntax in {.field {source_location}}:"
    } else {
      # Called from linter/validator without tag context
      header <- "Invalid type annotation syntax in {.code {type_spec}}:"
    }

    # Format error messages
    error_msgs <- paste("x", errors)
    names(error_msgs) <- rep("", length(errors))

    cli::cli_abort(
      c(
        header,
        "i" = if (is.null(source_location)) "Check your @typedParam and @typedReturn tags" else NULL,
        error_msgs
      ),
      call = NULL
    )
  }

  invisible(NULL)
}
