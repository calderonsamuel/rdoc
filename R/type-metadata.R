#' S7 Classes for Type Metadata
#'
#' These classes provide a type-safe representation of type annotations
#' extracted from @typedParam and @typedReturn tags. Using S7 classes
#' instead of plain lists prevents common errors like typos in field names
#' and ensures consistent structure across the codebase.
#'
#' ## Design Philosophy
#'
#' rdoc uses S7 internally for all type metadata, practicing what it preaches.
#' S7 objects are used throughout:
#'
#' - Internal type registry: S7 objects
#' - Serialization (inst/types.rds): S7 objects (serialize perfectly with saveRDS)
#' - Tests: Access S7 properties with `@` operator
#'
#' This provides type safety and validation while maintaining clean serialization.
#'
#' @name type-metadata
NULL

#' Parameter Type Information
#'
#' Represents type information for a single function parameter.
#'
#' @param type Character string with the type specification (e.g., "numeric[1]")
#' @param description Character string describing the parameter
#' @export
param_type <- S7::new_class(
  "param_type",
  properties = list(
    type = S7::class_character,
    description = S7::class_character
  ),
  validator = function(self) {
    if (length(self@type) != 1) {
      "@type must be a scalar character"
    } else if (length(self@description) != 1) {
      "@description must be a scalar character"
    }
  }
)

#' Return Type Information
#'
#' Represents type information for a function's return value.
#'
#' @param type Character string with the type specification
#' @param description Character string describing the return value
#' @export
return_type <- S7::new_class(
  "return_type",
  properties = list(
    type = S7::class_character,
    description = S7::class_character
  ),
  validator = function(self) {
    if (length(self@type) != 1) {
      "@type must be a scalar character"
    } else if (length(self@description) != 1) {
      "@description must be a scalar character"
    }
  }
)

#' Function Type Signature
#'
#' Complete type signature for a function, including all parameters
#' and the return type.
#'
#' @param params Named list of param_type objects (names are parameter names)
#' @param return return_type object or NULL if no return type specified
#' @export
function_signature <- S7::new_class(
  "function_signature",
  properties = list(
    params = S7::class_list,
    return = S7::class_any  # Will validate in validator
  ),
  validator = function(self) {
    # Validate return type
    if (!is.null(self@return) && !S7::S7_inherits(self@return, return_type)) {
      return("@return must be a return_type object or NULL")
    }

    # Validate that all params are param_type objects
    for (i in seq_along(self@params)) {
      param <- self@params[[i]]
      if (!S7::S7_inherits(param, param_type)) {
        return(sprintf("params[[%d]] must be a param_type object", i))
      }
    }

    # Validate that params is named
    if (length(self@params) > 0 && is.null(names(self@params))) {
      return("@params must be a named list")
    }

    NULL
  }
)
