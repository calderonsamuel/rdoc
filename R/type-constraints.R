#' Parse type specification with bracket constraints
#'
#' Parses type specifications supporting:
#' - Element type constraints: class_list<class_integer>
#'
#' @param type_spec Type specification string (e.g., "class_list<class_integer>")
#' @param validate Whether to validate syntax (default TRUE). Set to FALSE if
#'   syntax was already validated during tag parsing.
#' @return List with base_type and element_type
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Element type constraint
#' parse_type_constraints("class_list<class_integer>")
#' # Returns: list(base_type = "class_list", element_type = "class_integer")
#' }
parse_type_constraints <- function(type_spec, validate = TRUE) {
  # Validate syntax before parsing (unless already validated during tag parsing)
  if (validate) {
    validate_type_syntax(type_spec)
  }

  # Initialize result
  result <- list(
    base_type = type_spec,
    element_type = NULL
  )

  # Pattern for element type: base<element>
  # Example: class_list<class_integer> or class_list<class_list<class_integer>>
  # Strategy: Match from first < to position where angle brackets are balanced
  if (grepl("^([^<>\\[\\]]+)<", type_spec, perl = TRUE)) {
    # Extract base type (before first <)
    base_match <- regmatches(type_spec, regexec("^([^<>\\[\\]]+)<", type_spec, perl = TRUE))[[1]]
    if (length(base_match) == 2) {
      base <- base_match[2]
      rest <- substring(type_spec, nchar(base) + 2)  # Skip past "base<"

      # Find balanced closing >
      depth <- 1
      end_pos <- 0
      chars <- strsplit(rest, "")[[1]]

      for (i in seq_along(chars)) {
        if (chars[i] == "<") depth <- depth + 1
        if (chars[i] == ">") depth <- depth - 1
        if (depth == 0) {
          end_pos <- i
          break
        }
      }

      # Check if we found balanced closing and nothing after it
      if (end_pos > 0 && end_pos == length(chars)) {
        element <- substring(rest, 1, end_pos - 1)
        # Reject empty element type
        if (nchar(trimws(element)) == 0) {
          return(result)  # Return with base_type = full string
        }
        result$base_type <- base
        result$element_type <- element
        return(result)
      }
    }
  }

  # No element type found, return base type as-is
  result
}

#' Format type specification for display
#'
#' Converts parsed type specification back to string format
#'
#' @param parsed_type Parsed type specification from parse_type_constraints()
#' @return Character string
#' @keywords internal
format_type_constraints <- function(parsed_type) {
  result <- parsed_type$base_type

  # Add element type constraint if present
  if (!is.null(parsed_type$element_type)) {
    result <- paste0(result, "<", parsed_type$element_type, ">")
  }

  result
}

#' Check if actual type satisfies element type constraint
#'
#' This is a placeholder for future element type validation
#' Currently returns TRUE as element type checking requires runtime inspection
#'
#' @param actual_type Actual type string
#' @param expected_element Expected element type from type spec
#' @return Logical
#' @keywords internal
check_element_type <- function(actual_type, expected_element) {
  # Element type checking requires runtime inspection of list contents
  # This is beyond static analysis scope for now
  # Return TRUE to avoid false positives
  TRUE
}
