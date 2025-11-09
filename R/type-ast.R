#' S7 Classes for Type Parser AST
#'
#' rdoc's type parser produces an Abstract Syntax Tree (AST) representing
#' the structure of type annotations. Using S7 classes ensures AST nodes
#' are well-formed and validates invariants at construction time.
#'
#' @name type-ast
NULL

#' Type reference node (e.g., "numeric", "pkg::Class")
#'
#' Represents a reference to a single type, optionally qualified with
#' a package name and/or element type constraint.
#'
#' Examples:
#' - `numeric` → type_ref(base_type = "numeric")
#' - `pkg::Class` → type_ref(base_type = "Class", package = "pkg")
#' - `list<numeric>` → type_ref(base_type = "list", element_type = ...)
#'
#' @field base_type Character[1] - the type name (e.g., "numeric")
#' @field package Character[1] or NULL - package qualification (e.g., "pkg")
#' @field element_type type_ref/union_type or NULL - element type for generics
#'
#' @keywords internal
type_ref <- S7::new_class(
  "type_ref",
  properties = list(
    base_type = S7::class_character,
    package = S7::new_property(S7::class_character | NULL, default = NULL),
    element_type = S7::new_property(S7::class_any, default = NULL)
  ),
  validator = function(self) {
    # Validate base_type is scalar
    if (length(self@base_type) != 1) {
      return("@base_type must be a scalar character")
    }

    # Validate package is scalar or NULL
    if (!is.null(self@package) && length(self@package) != 1) {
      return("@package must be a scalar character or NULL")
    }

    # Validate element_type is an AST node or NULL
    if (!is.null(self@element_type)) {
      if (!S7::S7_inherits(self@element_type, type_ref) &&
          !S7::S7_inherits(self@element_type, union_type)) {
        return("@element_type must be a type_ref or union_type node")
      }

      # Semantic validation: only list types can have element types
      if (self@base_type != "list" && self@base_type != "class_list") {
        return(sprintf(
          "Type '%s' cannot have element type (only 'list' and 'class_list' support <T> syntax)",
          self@base_type
        ))
      }
    }

    NULL
  }
)

#' Union type node (e.g., "NULL | numeric")
#'
#' Represents a union of multiple types. Enforces rdoc's opinionated rules:
#' - At least 2 types in the union
#' - NULL must appear first if present
#' - No duplicate NULL values
#'
#' Examples:
#' - `NULL | numeric` → union_type(types = list(type_ref("NULL"), type_ref("numeric")))
#' - `integer | character` → union_type(types = list(type_ref("integer"), type_ref("character")))
#'
#' @field types List of type_ref or union_type nodes (length >= 2)
#'
#' @keywords internal
union_type <- S7::new_class(
  "union_type",
  properties = list(
    types = S7::class_list
  ),
  validator = function(self) {
    # Must have at least 2 types
    if (length(self@types) < 2) {
      return("@types must contain at least 2 type nodes (unions with <2 types should be flattened)")
    }

    # Validate each element is an AST node
    for (i in seq_along(self@types)) {
      node <- self@types[[i]]
      if (!S7::S7_inherits(node, type_ref) && !S7::S7_inherits(node, union_type)) {
        return(sprintf(
          "@types[[%d]] must be a type_ref or union_type node",
          i
        ))
      }
    }

    # Find NULL positions (rdoc's opinionated rule)
    null_indices <- which(sapply(self@types, function(t) {
      S7::S7_inherits(t, type_ref) && t@base_type == "NULL"
    }))

    # NULL must be first if present
    if (length(null_indices) > 0 && null_indices[1] != 1) {
      return(sprintf(
        "NULL must be first in union type (found at position %d)",
        null_indices[1]
      ))
    }

    # No duplicate NULLs
    if (length(null_indices) > 1) {
      return(sprintf(
        "NULL can only appear once in union type (found at positions: %s)",
        paste(null_indices, collapse = ", ")
      ))
    }

    NULL
  }
)
