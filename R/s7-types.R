#' Normalize type name to handle both short and S7 class forms
#'
#' Accepts both "integer" and "class_integer" forms, normalizing to short form.
#' This is a helper for backwards compatibility - the main type resolution
#' happens via type_string_to_s7_class().
#'
#' @param type_string Character string with type name
#' @return Normalized type string
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' normalize_type_name("class_integer")  # "integer"
#' normalize_type_name("integer")        # "integer"
#' normalize_type_name("class_numeric")  # "numeric"
#' }
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
#' This is the PRIMARY type resolution function. Converts rdoc type annotations
#' to S7 class objects, which are the source of truth for type checking.
#'
#' @param type_string Type name (accepts both "integer" and "class_integer")
#' @return S7 class object or NULL if not S7 type
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Both forms resolve to S7::class_integer
#' type_string_to_s7_class("integer")        # S7::class_integer
#' type_string_to_s7_class("class_integer")  # S7::class_integer
#'
#' # S7 union types
#' type_string_to_s7_class("numeric")        # S7::class_numeric (union)
#'
#' # Non-S7 types return NULL
#' type_string_to_s7_class("data.frame")     # NULL
#' }
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

#' Check if actual S7 class is compatible with expected S7 class
#'
#' This is the CORE compatibility checking function. Uses S7's class hierarchy
#' for inheritance checking. Handles unions (like class_numeric = class_integer | class_double).
#'
#' @param actual_s7 S7 class object (actual type)
#' @param expected_s7 S7 class object (expected type)
#' @return Logical
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Exact match
#' s7_class_compatible(S7::class_integer, S7::class_integer)  # TRUE
#'
#' # Union compatibility
#' s7_class_compatible(S7::class_integer, S7::class_numeric)  # TRUE
#' s7_class_compatible(S7::class_double, S7::class_numeric)   # TRUE
#'
#' # Inheritance
#' Parent <- S7::new_class("Parent")
#' Child <- S7::new_class("Child", parent = Parent)
#' s7_class_compatible(Child, Parent)  # TRUE (child is compatible with parent)
#' s7_class_compatible(Parent, Child)  # FALSE
#' }
s7_class_compatible <- function(actual_s7, expected_s7) {
  # Exact match
  if (identical(actual_s7, expected_s7)) {
    return(TRUE)
  }

  # Handle unions (like class_numeric)
  if (inherits(expected_s7, "S7_union")) {
    # Check if actual matches any class in the union
    for (union_class in expected_s7$classes) {
      if (s7_class_compatible(actual_s7, union_class)) {
        return(TRUE)
      }
    }
    return(FALSE)
  }

  if (inherits(actual_s7, "S7_union")) {
    # If actual is a union, check if all its members are compatible with expected
    for (union_class in actual_s7$classes) {
      if (!s7_class_compatible(union_class, expected_s7)) {
        return(FALSE)
      }
    }
    return(TRUE)
  }

  # Check inheritance: walk up the parent chain
  if (inherits(actual_s7, "S7_class")) {
    current <- actual_s7
    while (!is.null(current)) {
      if (identical(current, expected_s7)) {
        return(TRUE)
      }
      # Move to parent class
      current <- if (!is.null(current@parent)) current@parent else NULL
    }
  }

  FALSE
}

#' Check if two types are compatible (string-based, for non-S7 types)
#'
#' Fallback for types not in S7 (data.frame, matrix, etc)
#'
#' @param actual Actual type string
#' @param expected Expected type string
#' @return Logical
#' @keywords internal
string_based_compatible <- function(actual, expected) {
  # Exact match
  if (actual == expected) {
    return(TRUE)
  }

  # R's numeric type compatibility: numeric/double/integer are interchangeable
  if (expected %in% c("numeric", "double") && actual %in% c("numeric", "integer", "double")) {
    return(TRUE)
  }

  FALSE
}

#' Convert type to S7 display name for error messages
#'
#' Always uses S7 convention (class_ prefix) for S7 base types
#'
#' @param type_string Type string to convert
#' @return S7 display name
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' type_to_s7_display("integer")      # "class_integer"
#' type_to_s7_display("numeric")      # "class_numeric"
#' type_to_s7_display("data.frame")   # "data.frame" (not S7)
#' }
type_to_s7_display <- function(type_string) {
  # Normalize first (strip class_ if present)
  normalized <- normalize_type_name(type_string)

  # Check if it's an S7 base type
  if (is_s7_base_type(normalized)) {
    return(paste0("class_", normalized))
  }

  # Non-S7 types keep their original name
  normalized
}
