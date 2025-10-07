#' Parse type specification with bracket constraints
#'
#' Parses type specifications supporting:
#' - Length constraints: class_integer\[1\], class_numeric\[5\]
#' - Element type constraints: class_list<class_integer>
#' - Combined: class_list<class_numeric>\[3\]
#'
#' @param type_spec Type specification string (e.g., "class_integer\[1\]")
#' @param validate Whether to validate syntax (default TRUE). Set to FALSE if
#'   syntax was already validated during tag parsing.
#' @return List with base_type, length_constraint, and element_type
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Length constraint
#' parse_type_constraints("class_integer[1]")
#' # Returns: list(base_type = "class_integer", length_constraint = 1)
#'
#' # Element type constraint
#' parse_type_constraints("class_list<class_integer>")
#' # Returns: list(base_type = "class_list", element_type = "class_integer")
#'
#' # Combined
#' parse_type_constraints("class_list<class_numeric>[3]")
#' # Returns: list(base_type = "class_list", element_type = "class_numeric", length_constraint = 3)
#' }
parse_type_constraints <- function(type_spec, validate = TRUE) {
  # Validate syntax before parsing (unless already validated during tag parsing)
  if (validate) {
    validate_type_syntax(type_spec)
  }

  # Initialize result
  result <- list(
    base_type = type_spec,
    length_constraint = NULL,
    element_type = NULL
  )

  # Pattern for combined syntax: base<element>[length]
  # Example: class_list<class_integer>[3] or class_list<class_numeric[5]>[3]
  # Use .+? (lazy match) for element type to allow nested brackets
  combined_pattern <- "^([^<>\\[\\]]+)<(.+?)>\\[([0-9]+)\\]$"
  combined_match <- regmatches(type_spec, regexec(combined_pattern, type_spec, perl = TRUE))[[1]]

  if (length(combined_match) == 4) {
    result$base_type <- combined_match[2]
    result$element_type <- combined_match[3]
    result$length_constraint <- as.integer(combined_match[4])
    return(result)
  }

  # Pattern for element type only: base<element>
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

  # Pattern for length constraint only: base[length]
  # Example: class_integer[1]
  length_pattern <- "^([^<>\\[\\]]+)\\[([0-9]+)\\]$"
  length_match <- regmatches(type_spec, regexec(length_pattern, type_spec, perl = TRUE))[[1]]

  if (length(length_match) == 3) {
    result$base_type <- length_match[2]
    result$length_constraint <- as.integer(length_match[3])
    return(result)
  }

  # No constraints found, return base type as-is
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

  # Add length constraint if present
  if (!is.null(parsed_type$length_constraint)) {
    result <- paste0(result, "[", parsed_type$length_constraint, "]")
  }

  result
}

#' Check if actual type satisfies length constraint
#'
#' @param actual_length Integer length of actual value
#' @param expected_constraint Integer expected length from type spec
#' @return Logical
#' @keywords internal
check_length_constraint <- function(actual_length, expected_constraint) {
  if (is.null(expected_constraint)) return(TRUE)
  if (is.null(actual_length)) return(TRUE)  # Can't check, assume OK

  actual_length == expected_constraint
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
