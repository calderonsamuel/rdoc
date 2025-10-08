#' Normalize type name (trim whitespace only)
#'
#' Type names must use the full S7 class name (e.g., "class_integer", not "integer").
#' This function only trims whitespace.
#'
#' @param type_string Character string with type name
#' @return Normalized type string
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' normalize_type_name("class_integer")  # "class_integer"
#' normalize_type_name(" class_integer ") # "class_integer"
#' }
normalize_type_name <- function(type_string) {
  trimws(type_string)
}

# S7 type name mapping - list of valid S7 class names
# We dynamically get the class objects from S7 namespace to avoid identity issues
.s7_type_names <- c(
  # Original 9 types
  "class_logical", "class_integer", "class_double", "class_complex",
  "class_character", "class_raw", "class_list", "class_expression", "class_numeric",

  # Base classes (4)
  "class_call", "class_environment", "class_function", "class_name",

  # Unions (3)
  "class_atomic", "class_language", "class_vector",

  # S3 wrappers (7)
  "class_data.frame", "class_Date", "class_factor", "class_formula",
  "class_POSIXct", "class_POSIXlt", "class_POSIXt",

  # Special
  "class_any"
)

#' Get S7 class object from type name
#'
#' Dynamically retrieves from S7 namespace to ensure we get the same object
#' instances that tests and other code use.
#'
#' @param type_name Full S7 class name (e.g., "class_integer")
#' @return S7 class object or NULL
#' @keywords internal
get_s7_class_from_namespace <- function(type_name) {
  # Type name should already have "class_" prefix
  # Try to get from S7 namespace
  tryCatch(
    getExportedValue("S7", type_name),
    error = function(e) NULL
  )
}

#' Check if type is an S7 base type
#'
#' @param type_string Type name to check
#' @return Logical
#' @keywords internal
is_s7_base_type <- function(type_string) {
  type_string <- normalize_type_name(type_string)

  # NULL is a special case - not an S7 class but a valid type
  type_string == "NULL" || type_string %in% .s7_type_names
}

#' Resolve external type reference (package::class syntax)
#'
#' Handles type references to external packages. Tries to find S7 class objects
#' exported by the package, and falls back to creating S7 wrappers for S3 classes.
#'
#' @param type_string Type string in "package::class" format
#' @return S7 class object or NULL
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # If roxygen2 exports S7 class (future):
#' resolve_external_type("roxygen2::roclet")  # Uses exported S7 class
#'
#' # If roxygen2 uses S3 (current):
#' resolve_external_type("roxygen2::roclet")  # Creates S7 wrapper via new_S3_class()
#' }
resolve_external_type <- function(type_string) {
  # Parse package::class syntax
  if (!grepl("::", type_string, fixed = TRUE)) {
    return(NULL)  # Not an external type
  }

  parts <- strsplit(type_string, "::", fixed = TRUE)[[1]]
  if (length(parts) != 2) {
    return(NULL)  # Invalid syntax
  }

  package <- parts[1]
  class_name <- parts[2]

  # Step 1: Try to get exported S7 class from package
  s7_class <- tryCatch({
    obj <- getExportedValue(package, class_name)
    if (inherits(obj, "S7_class")) {
      return(obj)
    }
    NULL
  }, error = function(e) NULL)

  if (!is.null(s7_class)) {
    return(s7_class)
  }

  # Step 2: Create S7 wrapper for S3 class
  # Note: S7::new_S3_class() doesn't have a package parameter
  # The package qualification is for rdoc's type tracking only
  S7::new_S3_class(class_name)
}

#' Convert type string to S7 class object
#'
#' This is the PRIMARY type resolution function. Converts rdoc type annotations
#' to S7 class objects, which are the source of truth for type checking.
#'
#' @param type_string Full S7 class name (e.g., "class_integer") or external type (e.g., "roxygen2::roclet")
#' @return S7 class object or NULL if not S7 type
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # S7 class names resolve to S7 class objects
#' type_string_to_s7_class("class_integer")  # S7::class_integer
#'
#' # S7 union types
#' type_string_to_s7_class("class_numeric")  # S7::class_numeric (union)
#'
#' # NULL is special case
#' type_string_to_s7_class("NULL")           # NULL
#'
#' # External types (Phase 24.1)
#' type_string_to_s7_class("roxygen2::roclet")  # S7 wrapper or exported S7 class
#' }
type_string_to_s7_class <- function(type_string) {
  type_string <- normalize_type_name(type_string)

  # Check for external type reference (package::class)
  if (grepl("::", type_string, fixed = TRUE)) {
    return(resolve_external_type(type_string))
  }

  # NULL is a special case - not an S7 class
  if (type_string == "NULL") {
    return(NULL)
  }

  # Dynamically get from S7 namespace to ensure object identity
  get_s7_class_from_namespace(type_string)
}

#' Convert S7 class object to type string
#'
#' @param s7_class S7 class object
#' @return Full S7 class name (e.g., "class_integer")
#' @keywords internal
s7_class_to_type_string <- function(s7_class) {
  # Check if this is a union (like class_numeric)
  if (inherits(s7_class, "S7_union")) {
    # For unions, return full class name
    # class_numeric is integer | double
    return("class_numeric")
  }

  # Get class name from S7 class object and prefix with class_
  # S7 base class objects have a $class property (which is the short form)
  paste0("class_", s7_class$class)
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

  # Handle unions - CHECK EXPECTED FIRST (important for subtype checking)
  # When expected is a union (A|B|C), actual is compatible if it matches any member
  if (inherits(expected_s7, "S7_union")) {
    # Special case: If actual is also a union, check if all actual members
    # are compatible with at least one expected member
    if (inherits(actual_s7, "S7_union")) {
      for (actual_class in actual_s7$classes) {
        # Check if this actual member matches ANY expected member
        found_match <- FALSE
        for (expected_class in expected_s7$classes) {
          if (s7_class_compatible(actual_class, expected_class)) {
            found_match <- TRUE
            break
          }
        }
        if (!found_match) {
          return(FALSE)
        }
      }
      return(TRUE)
    }

    # Actual is not a union - check if it matches any member of expected union
    for (union_class in expected_s7$classes) {
      if (s7_class_compatible(actual_s7, union_class)) {
        return(TRUE)
      }
    }
    return(FALSE)
  }

  # If we get here, expected is not a union
  # If actual is a union but expected isn't, they're incompatible
  # (can't assign a union to a non-union type)
  if (inherits(actual_s7, "S7_union")) {
    return(FALSE)
  }

  # Check inheritance for S7 classes (regular classes, not S3 wrappers)
  if (inherits(actual_s7, "S7_class") && !inherits(actual_s7, "S7_S3_class")) {
    current <- actual_s7
    while (!is.null(current)) {
      if (identical(current, expected_s7)) {
        return(TRUE)
      }
      # Move to parent class - use S7::prop() for R < 4.3.0 compatibility
      parent_class <- S7::prop(current, "parent")
      current <- if (!is.null(parent_class)) parent_class else NULL
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
#' Fallback for types not in S7. Note: Most types should use S7 class names now.
#' This is only for special cases like NULL.
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

  FALSE
}

#' Convert type to S7 display name for error messages
#'
#' Expands S7 union types (like class_numeric) to their constituent types
#' for clearer error messages. E.g., "class_numeric | class_character" becomes
#' "class_integer | class_double | class_character".
#'
#' @param type_string Type string to display
#' @return Display name with S7 unions expanded
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' type_to_s7_display("class_integer")  # "class_integer"
#' type_to_s7_display("class_numeric")  # "class_integer | class_double"
#' type_to_s7_display("class_numeric | class_character")  # "class_integer | class_double | class_character"
#' type_to_s7_display("NULL | class_numeric")  # "NULL | class_integer | class_double"
#' }
type_to_s7_display <- function(type_string) {
  # Parse the type
  ast <- tryCatch(
    parse_type_syntax(type_string),
    error = function(e) NULL
  )

  if (is.null(ast)) {
    return(normalize_type_name(type_string))
  }

  # Expand the AST to flatten S7 unions
  expanded <- expand_s7_unions_in_ast(ast)

  # Convert back to string
  ast_to_string(expanded)
}

#' Expand S7 union types in AST
#'
#' Recursively expands S7 union types (like class_numeric = class_integer | class_double)
#' into their constituent types for display purposes.
#'
#' @param ast_node AST node from parse_type_syntax
#' @return AST node with S7 unions expanded
#' @keywords internal
expand_s7_unions_in_ast <- function(ast_node) {
  if (ast_node$node_type == "union") {
    # Expand each type in the union
    expanded_types <- list()
    for (type_node in ast_node$types) {
      expanded <- expand_s7_unions_in_ast(type_node)
      if (expanded$node_type == "union") {
        # If expansion resulted in a union, flatten it
        expanded_types <- c(expanded_types, expanded$types)
      } else {
        expanded_types <- c(expanded_types, list(expanded))
      }
    }

    return(list(
      node_type = "union",
      types = expanded_types
    ))
  }

  # For simple types, check if it's an S7 union that should be expanded
  if (ast_node$node_type == "type") {
    type_name <- ast_node$base_type

    # Recursively expand element type if present
    expanded_element_type <- if (!is.null(ast_node$element_type)) {
      expand_s7_unions_in_ast(ast_node$element_type)
    } else {
      NULL
    }

    # Expand all S7 unions (package developers control verbosity)
    if (is.null(ast_node$package)) {
      expanded_types <- NULL

      # class_numeric: integer | double
      if (type_name == "class_numeric") {
        expanded_types <- list("class_integer", "class_double")
      }
      # class_atomic: logical | integer | double | complex | character | raw
      else if (type_name == "class_atomic") {
        expanded_types <- list("class_logical", "class_integer", "class_double",
                                "class_complex", "class_character", "class_raw")
      }
      # class_vector: logical | integer | double | complex | character | raw | expression | list
      else if (type_name == "class_vector") {
        expanded_types <- list("class_logical", "class_integer", "class_double",
                                "class_complex", "class_character", "class_raw",
                                "class_expression", "class_list")
      }
      # class_language: name | call
      else if (type_name == "class_language") {
        expanded_types <- list("class_name", "class_call")
      }

      # If we found an expansion, create union AST
      if (!is.null(expanded_types)) {
        return(list(
          node_type = "union",
          types = lapply(expanded_types, function(type) {
            list(node_type = "type", base_type = type, package = NULL,
                 length_constraint = ast_node$length_constraint,
                 element_type = expanded_element_type)
          })
        ))
      }
    }

    # Return with expanded element type if present
    if (!is.null(expanded_element_type)) {
      return(list(
        node_type = "type",
        base_type = ast_node$base_type,
        package = ast_node$package,
        length_constraint = ast_node$length_constraint,
        element_type = expanded_element_type
      ))
    }
  }

  # Return unchanged
  ast_node
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
#' ast <- parse_type_syntax("NULL | class_integer")
#' s7_union <- rdoc_union_to_s7(ast)
#' # Returns: <S7_union>: <NULL> or <class_integer>
#'
#' # Complex case
#' ast <- parse_type_syntax("NULL | class_character | class_integer")
#' s7_union <- rdoc_union_to_s7(ast)
#' # Returns: <S7_union>: <NULL>, <class_character>, or <class_integer>
#' }
rdoc_union_to_s7 <- function(ast_node) {
  # Helper to construct full type string from AST node
  ast_to_type_string <- function(type_node) {
    if (!is.null(type_node$package)) {
      paste0(type_node$package, "::", type_node$base_type)
    } else {
      type_node$base_type
    }
  }

  # If not a union node, just convert single type
  if (ast_node$node_type != "union") {
    type_name <- ast_to_type_string(ast_node)

    # Handle NULL specially
    if (type_name == "NULL") {
      return(NULL)
    }

    # Convert to S7 class (handles both built-in and external types)
    return(type_string_to_s7_class(type_name))
  }

  # Extract S7 class objects for each type in union
  s7_classes <- lapply(ast_node$types, function(type_node) {
    type_name <- ast_to_type_string(type_node)

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
