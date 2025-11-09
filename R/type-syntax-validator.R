#' Validate type annotation syntax
#'
#' Uses the recursive descent parser to validate type syntax.
#' This replaces the previous regex-based validation (Phase 13.1) with
#' a proper parser (Phase 13.4) for better error messages and maintainability.
#'
#' @param type_spec Type specification string (e.g., "class_integer")
#' @param source_location Optional location info for error messages
#' @return Invisible NULL if valid, aborts with error if invalid
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' validate_type_syntax("class_integer")  # Valid - returns NULL
#' validate_type_syntax("class_list<>")      # Invalid - aborts with error
#' validate_type_syntax("class_list<int><char>")  # Invalid - aborts
#' }
validate_type_syntax <- function(type_spec, source_location = NULL) {
  # Check for forbidden 'missing' and 'class_missing' types before parsing
  if (grepl("\\b(class_)?missing\\b", type_spec, ignore.case = FALSE)) {
    cli::cli_abort(
      c(
        "Type 'missing' or 'class_missing' is not allowed in type annotations",
        "i" = "Use missing(arg) to check for missing arguments, not type annotations",
        "i" = "If you need optional parameters, use {{NULL | Type}} instead"
      ),
      call = NULL
    )
  }

  # Check for short-form type names (not allowed - must use S7 class names)
  short_forms <- c(
    "logical", "integer", "double", "complex", "character", "raw",
    "list", "expression", "numeric", "call", "environment", "function",
    "name", "atomic", "language", "vector", "Date",
    "factor", "formula", "POSIXct", "POSIXlt", "POSIXt", "any"
  )

  # Build regex pattern to match short forms as complete words
  # Match word boundaries to avoid matching "class_integer" when looking for "integer"
  pattern <- paste0("\\b(", paste(short_forms, collapse = "|"), ")\\b")

  # Special case: data.frame needs special handling (dot breaks word boundary)
  if (grepl("\\bdata\\.frame\\b", type_spec)) {
    cli::cli_abort(
      c(
        "Short-form type name 'data.frame' is not allowed",
        "i" = "Use the full S7 class name: 'class_data.frame'",
        "i" = "Example: Change {{{{data.frame}}}} to {{{{class_data.frame}}}}"
      ),
      call = NULL
    )
  }

  if (grepl(pattern, type_spec, ignore.case = FALSE)) {
    # Extract which short form was used
    matches <- regmatches(type_spec, gregexpr(pattern, type_spec, perl = TRUE))[[1]]
    short_form <- matches[1]  # Get first match

    cli::cli_abort(
      c(
        "Short-form type name '{short_form}' is not allowed",
        "i" = "Use the full S7 class name: 'class_{short_form}'",
        "i" = "Example: Change {{{{integer}}}} to {{{{class_integer}}}}"
      ),
      call = NULL
    )
  }

  # Use the parser to validate syntax
  # The parser throws errors with precise locations and helpful messages
  tryCatch(
    {
      parse_type_syntax(type_spec)
      invisible(NULL)
    },
    error = function(e) {
      # Re-throw with source location context if provided
      if (!is.null(source_location)) {
        cli::cli_abort(
          c(
            "Invalid type annotation syntax in {.field {source_location}}:",
            "x" = conditionMessage(e)
          ),
          call = NULL
        )
      } else {
        # Re-throw original error
        cli::cli_abort(
          c(
            "Invalid type annotation syntax in {.code {type_spec}}:",
            "x" = conditionMessage(e)
          ),
          call = NULL
        )
      }
    }
  )
}
