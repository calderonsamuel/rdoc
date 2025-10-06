#' Validate type annotation syntax
#'
#' Uses the recursive descent parser to validate type syntax.
#' This replaces the previous regex-based validation (Phase 13.1) with
#' a proper parser (Phase 13.4) for better error messages and maintainability.
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
  # Check for forbidden 'missing' type before parsing
  if (grepl("\\bmissing\\b", type_spec, ignore.case = FALSE)) {
    cli::cli_abort(
      c(
        "Type 'missing' is not allowed in type annotations",
        "i" = "Use missing(arg) to check for missing arguments, not type annotations",
        "i" = "If you need optional parameters, use {{NULL | Type}} instead"
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
