#' S7 Classes for Package Export Metadata
#'
#' These classes represent different types of exports from R packages.
#' Used in types.rds to provide comprehensive type information beyond
#' just function signatures.
#'
#' @name type-exports
#' @include type-metadata.R
NULL

#' Base Class for Exported Items
#'
#' Abstract base class for all package exports. Provides common
#' structure for functions, classes, data objects, and constants.
#'
#' @field name Character[1] - Export name
#' @field export_type Character[1] - Type: "function", "class", "data"
#' @keywords internal
exported_item <- S7::new_class(
  "exported_item",
  properties = list(
    name = S7::class_character,
    export_type = S7::class_character
  ),
  validator = function(self) {
    if (length(self@name) != 1) {
      return("@name must be a scalar character")
    }

    valid_types <- c("function", "class", "data")
    if (length(self@export_type) != 1 || !self@export_type %in% valid_types) {
      return(sprintf(
        "@export_type must be one of: %s",
        paste(valid_types, collapse = ", ")
      ))
    }

    NULL
  }
)

#' Exported Function Metadata
#'
#' Represents a function export with its complete type signature.
#'
#' @field name Character[1] - Function name
#' @field export_type Character[1] - Always "function"
#' @field signature function_signature - Parameter and return types
#' @keywords internal
exported_function <- S7::new_class(
  "exported_function",
  parent = exported_item,
  properties = list(
    signature = function_signature
  ),
  validator = function(self) {
    if (self@export_type != "function") {
      return("@export_type must be 'function' for exported_function")
    }

    if (!S7::S7_inherits(self@signature, function_signature)) {
      return("@signature must be a function_signature object")
    }

    NULL
  }
)

#' Exported Class Metadata
#'
#' Represents a class export (S7, R6, S3, S4) with constructor signature
#' and property/field definitions.
#'
#' @field name Character[1] - Class name
#' @field export_type Character[1] - Always "class"
#' @field class_system Character[1] - "S7", "R6", "S3", or "S4"
#' @field constructor_signature function_signature or NULL - Constructor types
#' @field properties Named list of param_type objects or NULL - Class properties/fields
#' @keywords internal
exported_class <- S7::new_class(
  "exported_class",
  parent = exported_item,
  properties = list(
    class_system = S7::class_character,
    constructor_signature = function_signature | NULL,
    properties = S7::class_list | NULL
  ),
  validator = function(self) {
    if (self@export_type != "class") {
      return("@export_type must be 'class' for exported_class")
    }

    valid_systems <- c("S7", "R6", "S3", "S4")
    if (length(self@class_system) != 1 || !self@class_system %in% valid_systems) {
      return(sprintf(
        "@class_system must be one of: %s",
        paste(valid_systems, collapse = ", ")
      ))
    }

    # Validate constructor signature if present
    if (!is.null(self@constructor_signature)) {
      if (!S7::S7_inherits(self@constructor_signature, function_signature)) {
        return("@constructor_signature must be function_signature or NULL")
      }
    }

    # Validate properties if present
    if (!is.null(self@properties)) {
      if (length(self@properties) > 0 && is.null(names(self@properties))) {
        return("@properties must be a named list")
      }

      for (i in seq_along(self@properties)) {
        prop <- self@properties[[i]]
        if (!S7::S7_inherits(prop, param_type)) {
          return(sprintf("properties[[%d]] must be a param_type object", i))
        }
      }
    }

    NULL
  }
)

#' Exported Data Object Metadata
#'
#' Represents a data object export (dataset, constant, enum).
#'
#' @field name Character[1] - Data object name
#' @field export_type Character[1] - Always "data"
#' @field type Character[1] - R type (e.g., "data.frame", "numeric")
#' @field dimensions Integer vector or NULL - Dimensions (for arrays/data.frames)
#' @field description Character[1] - Human-readable description
#' @keywords internal
exported_data <- S7::new_class(
  "exported_data",
  parent = exported_item,
  properties = list(
    type = S7::class_character,
    dimensions = S7::class_integer | NULL,
    description = S7::class_character
  ),
  validator = function(self) {
    if (self@export_type != "data") {
      return("@export_type must be 'data' for exported_data")
    }

    if (length(self@type) != 1) {
      return("@type must be a scalar character")
    }

    if (length(self@description) != 1) {
      return("@description must be a scalar character")
    }

    # Validate dimensions if present
    if (!is.null(self@dimensions)) {
      if (length(self@dimensions) < 1) {
        return("@dimensions must have at least one element")
      }
      if (any(self@dimensions < 0)) {
        return("@dimensions must be non-negative")
      }
    }

    NULL
  }
)

#' Package Type Metadata Container
#'
#' Top-level container for all type metadata exported by a package.
#' Saved to inst/types.rds and installed with the package.
#'
#' This container enables:
#' - Format versioning for future evolution
#' - Package-level metadata (version, generation time)
#' - Multiple export types (functions, classes, data)
#' - Migration between format versions
#'
#' @field format_version Integer[1] - Format version (current: 1)
#' @field rdoc_version Character[1] - rdoc version that generated this
#' @field generated_at POSIXct[1] - Generation timestamp
#' @field package_info List - Package name, version, etc.
#' @field exports Named list - Export name -> exported_item subclass
#' @keywords internal
type_metadata <- S7::new_class(
  "type_metadata",
  properties = list(
    format_version = S7::class_integer,
    rdoc_version = S7::class_character,
    generated_at = S7::class_POSIXct,
    package_info = S7::class_list,
    exports = S7::class_list
  ),
  validator = function(self) {
    # Validate format_version
    if (length(self@format_version) != 1) {
      return("@format_version must be a scalar integer")
    }
    if (self@format_version < 1) {
      return("@format_version must be >= 1")
    }

    # Validate rdoc_version
    if (length(self@rdoc_version) != 1) {
      return("@rdoc_version must be a scalar character")
    }

    # Validate generated_at
    if (length(self@generated_at) != 1) {
      return("@generated_at must be a scalar POSIXct")
    }

    # Validate exports
    if (length(self@exports) > 0 && is.null(names(self@exports))) {
      return("@exports must be a named list")
    }

    for (i in seq_along(self@exports)) {
      export <- self@exports[[i]]
      if (!S7::S7_inherits(export, exported_item)) {
        return(sprintf("exports[[%d]] must be an exported_item subclass", i))
      }

      # Validate export name matches list name
      export_name <- names(self@exports)[i]
      if (export@name != export_name) {
        return(sprintf(
          "Export name mismatch: list name '%s' vs object name '%s'",
          export_name,
          export@name
        ))
      }
    }

    NULL
  }
)
