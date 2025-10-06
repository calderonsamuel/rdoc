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
    # Original 9 types
    "logical", "integer", "double", "complex", "character", "raw",
    "list", "expression", "numeric",

    # Base classes (4)
    "call", "environment", "function", "name",

    # Unions (3)
    "atomic", "language", "vector",

    # S3 wrappers (7)
    "data.frame", "Date", "factor", "formula", "POSIXct", "POSIXlt", "POSIXt",

    # Special
    "any"
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

  # Special handling for 'any' - accepts any value
  if (type_string == "any") {
    return(S7::class_any)
  }

  # Map to S7 base classes
  s7_class_map <- list(
    # Original 9 types
    "logical" = S7::class_logical,
    "integer" = S7::class_integer,
    "double" = S7::class_double,
    "complex" = S7::class_complex,
    "character" = S7::class_character,
    "raw" = S7::class_raw,
    "list" = S7::class_list,
    "expression" = S7::class_expression,
    "numeric" = S7::class_numeric,

    # Base classes (4)
    "call" = S7::class_call,
    "environment" = S7::class_environment,
    "function" = S7::class_function,
    "name" = S7::class_name,

    # Unions (3)
    "atomic" = S7::class_atomic,
    "language" = S7::class_language,
    "vector" = S7::class_vector,

    # S3 wrappers (7)
    "data.frame" = S7::class_data.frame,
    "Date" = S7::class_Date,
    "factor" = S7::class_factor,
    "formula" = S7::class_formula,
    "POSIXct" = S7::class_POSIXct,
    "POSIXlt" = S7::class_POSIXlt,
    "POSIXt" = S7::class_POSIXt
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

  # Special case: class_any accepts anything
  if (identical(expected_s7, S7::class_any)) {
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

  # Check inheritance for S7 classes (regular classes, not S3 wrappers)
  if (inherits(actual_s7, "S7_class") && !inherits(actual_s7, "S7_S3_class")) {
    current <- actual_s7
    while (!is.null(current)) {
      if (identical(current, expected_s7)) {
        return(TRUE)
      }
      # Move to parent class
      current <- if (!is.null(current@parent)) current@parent else NULL
    }
  }

  # Check inheritance for S3 wrappers (POSIXct -> POSIXt, etc.)
  if (inherits(actual_s7, "S7_S3_class") && inherits(expected_s7, "S7_S3_class")) {
    actual_classes <- unclass(actual_s7)$class
    expected_classes <- unclass(expected_s7)$class

    # Check if any of the expected classes are in the actual class hierarchy
    for (exp_class in expected_classes) {
      if (exp_class %in% actual_classes) {
        return(TRUE)
      }
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

#' Convert rdoc union AST to S7 union object
#'
#' Takes a union type AST node from the parser and converts it to an S7_union object.
#' Handles NULL specially - NULL is represented as R's NULL (not a class object).
#'
#' @param ast_node Union type AST node with structure: list(node_type = "union", types = list(...))
#' @return S7_union object created with | operator, or single S7 class if not actually a union
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Parse union syntax
#' ast <- parse_type_syntax("NULL | integer")
#' s7_union <- rdoc_union_to_s7(ast)
#' # Returns: <S7_union>: <NULL> or <integer>
#'
#' # Complex case
#' ast <- parse_type_syntax("NULL | character | integer")
#' s7_union <- rdoc_union_to_s7(ast)
#' # Returns: <S7_union>: <NULL>, <character>, or <integer>
#' }
rdoc_union_to_s7 <- function(ast_node) {
  # If not a union node, just convert single type
  if (ast_node$node_type != "union") {
    type_name <- ast_node$base_type

    # Handle NULL specially
    if (type_name == "NULL") {
      return(NULL)
    }

    # Convert to S7 class
    return(type_string_to_s7_class(type_name))
  }

  # Extract S7 class objects for each type in union
  s7_classes <- lapply(ast_node$types, function(type_node) {
    type_name <- type_node$base_type

    # Handle NULL specially - represented as R's NULL
    if (type_name == "NULL") {
      return(NULL)
    }

    # For now, just use base type (ignore length/element constraints)
    # TODO: In future phases, create constrained types
    type_string_to_s7_class(type_name)
  })

  # Create union using | operator
  # NULL | class_a | class_b
  union_obj <- Reduce(`|`, s7_classes)

  union_obj
}
