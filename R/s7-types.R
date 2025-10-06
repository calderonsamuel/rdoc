#' Normalize type name to handle both short and S7 class forms
#'
#' Accepts both "integer" and "class_integer" forms, normalizing to short form.
#'
#' @param type_string Character string with type name
#' @return Normalized type string
#' @keywords internal
normalize_type_name <- function(type_string) {
  type_string <- trimws(type_string)

  # Strip "class_" prefix if present
  type_string <- gsub("^class_", "", type_string)

  # Handle S7 type aliases
  # numeric is integer | double in S7
  if (type_string == "numeric") {
    return("numeric")
  }

  type_string
}

#' Check if type is an S7 base type
#'
#' @param type_string Type name to check
#' @return Logical
#' @keywords internal
is_s7_base_type <- function(type_string) {
  type_string <- normalize_type_name(type_string)

  s7_base_types <- c(
    "logical", "integer", "double", "complex", "character", "raw",
    "list", "expression", "numeric"
  )

  # NULL is a special case - not an S7 class but a valid type
  if (type_string == "NULL") {
    return(TRUE)
  }

  type_string %in% s7_base_types
}

#' Convert type string to S7 class object
#'
#' @param type_string Type name
#' @return S7 class object or NULL if not S7 type
#' @keywords internal
type_string_to_s7_class <- function(type_string) {
  type_string <- normalize_type_name(type_string)

  # NULL is a special case - not an S7 class
  if (type_string == "NULL") {
    return(NULL)
  }

  # Map to S7 base classes
  s7_class_map <- list(
    "logical" = S7::class_logical,
    "integer" = S7::class_integer,
    "double" = S7::class_double,
    "complex" = S7::class_complex,
    "character" = S7::class_character,
    "raw" = S7::class_raw,
    "list" = S7::class_list,
    "expression" = S7::class_expression,
    "numeric" = S7::class_numeric
  )

  s7_class_map[[type_string]]
}

#' Convert S7 class object to type string
#'
#' @param s7_class S7 class object
#' @return Type string
#' @keywords internal
s7_class_to_type_string <- function(s7_class) {
  # Check if this is a union (like class_numeric)
  if (inherits(s7_class, "S7_union")) {
    # For unions, return "numeric" (the union name)
    # class_numeric is integer | double
    return("numeric")
  }

  # Get class name from S7 class object
  # S7 base class objects have a $class property
  class_name <- s7_class$class

  # Strip "class_" prefix for short form
  normalize_type_name(class_name)
}

#' Check if two S7 types are compatible
#'
#' Handles S7's numeric union (integer | double)
#'
#' @param actual Actual type string
#' @param expected Expected type string
#' @return Logical
#' @keywords internal
s7_types_compatible <- function(actual, expected) {
  actual <- normalize_type_name(actual)
  expected <- normalize_type_name(expected)

  # Exact match
  if (actual == expected) {
    return(TRUE)
  }

  # S7's class_numeric is class_integer | class_double
  if (expected == "numeric" && actual %in% c("integer", "double")) {
    return(TRUE)
  }

  if (actual == "numeric" && expected %in% c("integer", "double")) {
    return(TRUE)
  }

  FALSE
}
