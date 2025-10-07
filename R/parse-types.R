#' Parse a type specification
#'
#' Parses type strings like "numeric(1)", "character | NULL", etc.
#'
#' @param type_string Character string with type specification
#' @return A list with parsed type information
#' @keywords internal
parse_type_spec <- function(type_string) {
  type_string <- trimws(type_string)

  # Check if union type
  if (is_union_type(type_string)) {
    types <- split_union_types(type_string)
    return(list(
      type = "union",
      types = lapply(types, parse_single_type)
    ))
  }

  parse_single_type(type_string)
}

#' Parse a single (non-union) type
#'
#' @param type_string A single type string
#' @return A list with base type and optional length constraint
#' @keywords internal
parse_single_type <- function(type_string) {
  type_string <- trimws(type_string)

  # Check for function signature first (before length constraint check)
  if (grepl("^class_function\\(.*\\)", type_string)) {
    # Function signature: class_function(args): return
    return(parse_function_type(type_string))
  }

  # Check for S3/S4 class notation: <classname>
  if (grepl("^<.*>$", type_string)) {
    class_name <- gsub("^<(.*)>$", "\\1", type_string)
    return(list(
      base = "class",
      class = class_name
    ))
  }

  # Check for length constraint: type(n)
  length_pattern <- "^([^(]+)\\(([^)]+)\\)$"
  matches <- regmatches(type_string, regexec(length_pattern, type_string))[[1]]

  if (length(matches) == 3) {
    # Has length constraint
    return(list(
      base = trimws(matches[2]),
      length = trimws(matches[3])
    ))
  }

  # Simple type
  list(base = type_string)
}

#' Parse function type signature
#'
#' @param type_string Function signature string
#' @return A list with function type information
#' @keywords internal
parse_function_type <- function(type_string) {
  # Pattern: class_function(args) or class_function(args): return
  # First try with colon and return type
  pattern_with_return <- "^class_function\\((.*)\\):\\s*(.+)$"
  matches <- regmatches(type_string, regexec(pattern_with_return, type_string))[[1]]

  if (length(matches) == 3) {
    # Has return type
    args <- if (nchar(matches[2]) > 0) {
      trimws(strsplit(matches[2], ",")[[1]])
    } else {
      character(0)
    }

    return(list(
      base = "class_function",
      args = args,
      return = trimws(matches[3])
    ))
  }

  # Try without return type
  pattern_no_return <- "^class_function\\((.*)\\)$"
  matches <- regmatches(type_string, regexec(pattern_no_return, type_string))[[1]]

  if (length(matches) == 2) {
    args <- if (nchar(matches[2]) > 0) {
      trimws(strsplit(matches[2], ",")[[1]])
    } else {
      character(0)
    }

    return(list(
      base = "class_function",
      args = args
    ))
  }

  # Fallback
  list(base = "class_function")
}

#' Check if type is a union type
#'
#' @param type_string Type specification string
#' @return Logical
#' @keywords internal
is_union_type <- function(type_string) {
  grepl("\\|", type_string)
}

#' Split union type into components
#'
#' @param type_string Union type string
#' @return Character vector of individual types
#' @keywords internal
split_union_types <- function(type_string) {
  types <- strsplit(type_string, "\\|")[[1]]
  trimws(types)
}

#' Validate a type specification
#'
#' Checks if a type specification is valid
#'
#' @param type_string Type specification to validate
#' @return Logical indicating if valid
#' @keywords internal
validate_type_spec <- function(type_string) {
  tryCatch(
    {
      parse_type_spec(type_string)
      TRUE
    },
    error = function(e) FALSE
  )
}

#' Get base R types
#'
#' @return Character vector of base R types
#' @keywords internal
base_r_types <- function() {
  c(
    "class_numeric", "class_integer", "class_double", "class_character", "class_logical",
    "class_complex", "class_raw", "class_list", "class_vector",
    "NULL", "class_any",
    "class_data.frame", "matrix", "array",
    "class_environment", "class_function",
    "class_factor", "class_Date", "class_POSIXct", "class_POSIXlt"
  )
}

#' Check if type is a base R type
#'
#' @param type_string Type to check
#' @return Logical
#' @keywords internal
is_base_type <- function(type_string) {
  # Remove length constraint if present
  base <- gsub("\\(.*\\)$", "", type_string)
  base <- trimws(base)
  base %in% base_r_types()
}
