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

#' S7 Wrapper for xml2::xml_node
#'
#' Wraps the xml_node S3 class from xml2 package for type-safe usage in S7 classes.
#' This allows us to specify xml_node as a property type instead of using class_any.
#'
#' Used throughout rdoc for:
#' - Argument nodes in call_argument
#' - Variable assignment value nodes
#' - Return expression nodes
#' - Any XML AST node from xmlparsedata
#'
#' @keywords internal
xml_node <- S7::new_S3_class("xml_node")

#' S7 Wrapper for ParserState R6 Class
#'
#' Wraps the ParserState R6 class for type-safe usage in S7 classes.
#' This allows ParserState to be used as a property type in S7 objects
#' while maintaining R6's mutable state machine semantics.
#'
#' ParserState is an R6 class (not S7) because it manages mutable state:
#' - Advances position during parsing (mutates in place)
#' - Provides imperative state machine API
#' - Encapsulates private fields (tokens, position)
#'
#' The S7 wrapper enables type-safe composition in S7 classes while
#' preserving R6's reference semantics for performance.
#'
#' @keywords internal
parser_state <- S7::new_S3_class("ParserState")

#' Lexer Token
#'
#' Represents a single token from the type syntax lexer.
#' Tokens are the atomic units produced by lexical analysis of type annotations.
#'
#' The lexer recognizes 9 distinct token types:
#' - IDENTIFIER: Type names (e.g., "class_integer", "roxygen2")
#' - LANGLE, RANGLE: Generic type delimiters `<` and `>`
#' - LBRACKET, RBRACKET: Length constraint delimiters `[` and `]`
#' - PIPE: Union type operator `|`
#' - DOUBLE_COLON: Package qualification `::`
#' - NUMBER: Numeric literals (only valid in brackets)
#' - EOF: End of input marker
#'
#' @field type Character string - token type (validated against known types)
#' @field value Character string - lexeme (actual text matched)
#' @field position Integer - character position in input string (1-indexed)
#' @keywords internal
token <- S7::new_class(
  "token",
  properties = list(
    type = S7::class_character,
    value = S7::class_character,
    position = S7::class_integer
  ),
  validator = function(self) {
    # Validate token type against known types
    valid_types <- c(
      "IDENTIFIER", "LANGLE", "RANGLE", "LBRACKET", "RBRACKET",
      "PIPE", "DOUBLE_COLON", "NUMBER", "EOF"
    )

    if (length(self@type) != 1) {
      return("@type must be a scalar character")
    }
    if (!self@type %in% valid_types) {
      return(sprintf(
        "Invalid token type '%s'. Must be one of: %s",
        self@type,
        paste(valid_types, collapse = ", ")
      ))
    }

    if (length(self@value) != 1) {
      return("@value must be a scalar character")
    }

    if (length(self@position) != 1) {
      return("@position must be a scalar integer")
    }
    if (self@position < 1) {
      return(sprintf("@position must be positive (got %d)", self@position))
    }

    NULL
  }
)

#' Variable Assignment Information
#'
#' Represents a variable assignment detected during static analysis.
#' Used to track variable types across the file for type inference.
#'
#' This class serves two purposes in the linting pipeline:
#' 1. **During extraction**: Stores assignment location and the XML node to analyze later
#' 2. **During caching**: Stores assignment location and the inferred type for lookup
#'
#' The `value_node` field is optional because:
#' - Present during extraction (needs to be analyzed)
#' - NULL during caching (type already inferred, node no longer needed)
#'
#' @field line Integer line number where assignment occurs (1-indexed)
#' @field type Character string with inferred type (e.g., "class_integer", "unknown")
#' @field value_node Optional XML node representing the assigned value expression
#' @keywords internal
variable_assignment <- S7::new_class(
  "variable_assignment",
  properties = list(
    line = S7::class_integer,
    type = S7::class_character,
    value_node = xml_node | NULL
  ),
  validator = function(self) {
    if (length(self@line) != 1) {
      return("@line must be a scalar integer")
    }
    if (self@line < 1) {
      return(sprintf("@line must be positive (got %d)", self@line))
    }

    if (length(self@type) != 1) {
      return("@type must be a scalar character")
    }

    NULL
  }
)

#' Parameter Type Information
#'
#' Represents type information for a single function parameter.
#'
#' @param type Character string with the type specification (e.g., "numeric[1]")
#' @param description Character string describing the parameter
#' @keywords internal
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
#' @keywords internal
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
#' @keywords internal
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

#' Function Call Argument Information
#'
#' Represents information about an argument in a function call, including
#' its inferred type, position, and optional name (for named arguments).
#' Used during static type checking to validate function calls.
#'
#' @field node XML node representing the argument expression
#' @field type Character string with inferred type (e.g., "class_integer", "unknown")
#' @field position Integer position of the argument (1-indexed)
#' @field name Character string with argument name for named arguments, or NULL for positional
#' @keywords internal
call_argument <- S7::new_class(
  "call_argument",
  properties = list(
    node = xml_node,
    type = S7::class_character,
    position = S7::class_integer,
    name = S7::class_character | NULL
  ),
  validator = function(self) {
    if (length(self@type) != 1) {
      return("@type must be a scalar character")
    }
    if (length(self@position) != 1) {
      return("@position must be a scalar integer")
    }
    if (self@position < 1) {
      return("@position must be positive (got %d)", self@position)
    }
    if (!is.null(self@name) && length(self@name) != 1) {
      return("@name must be a scalar character or NULL")
    }
    NULL
  }
)

#' Namespace Import Information
#'
#' Represents a namespace import from library(), require(), or box::use().
#' Unifies the concept of namespace imports across different R mechanisms.
#'
#' This class supports three import mechanisms:
#' - `library(pkg)`: Traditional package loading (attaches all exports)
#' - `require(pkg)`: Conditional package loading (attaches all exports)
#' - `box::use(...)`: Modern module/package imports (flexible attachment)
#'
#' Import modes for box::use():
#' - Full module: `box::use(mod/math)` → qualified access via `math$func`
#' - Aliased: `box::use(m = mod/math)` → qualified access via `m$func`
#' - Selective: `box::use(mod/math[add])` → unqualified access to `add()`
#' - Attach all: `box::use(mod/math[...])` → unqualified access to all exports
#'
#' @field source_type Character: "package" or "module"
#' @field source_path Character: Package name or module path
#' @field namespace_name Character: Derived namespace name (last component of path)
#' @field namespace_alias Character or NULL: Optional alias for the namespace
#' @field selected_objects Character vector or NULL: Selectively imported objects (NULL = none selected)
#' @field attach_all Logical: Whether all exports are attached to namespace
#' @field import_mechanism Character: "library", "require", or "box"
#' @field line Integer: Source line number where import occurs
#' @keywords internal
namespace_import <- S7::new_class(
  "namespace_import",
  properties = list(
    source_type = S7::class_character,
    source_path = S7::class_character,
    namespace_name = S7::class_character,
    namespace_alias = S7::class_character | NULL,
    selected_objects = S7::class_character | NULL,
    attach_all = S7::class_logical,
    import_mechanism = S7::class_character,
    line = S7::class_integer
  ),
  validator = function(self) {
    # Validate source_type enum
    if (length(self@source_type) != 1 || !self@source_type %in% c("package", "module")) {
      return("@source_type must be 'package' or 'module'")
    }

    # Validate import_mechanism enum
    if (length(self@import_mechanism) != 1 || !self@import_mechanism %in% c("library", "require", "box")) {
      return("@import_mechanism must be 'library', 'require', or 'box'")
    }

    # Validate scalar character properties
    if (length(self@source_path) != 1) {
      return("@source_path must be a scalar character")
    }
    if (length(self@namespace_name) != 1) {
      return("@namespace_name must be a scalar character")
    }

    # Validate scalar logical
    if (length(self@attach_all) != 1) {
      return("@attach_all must be a scalar logical")
    }

    # Validate line number
    if (length(self@line) != 1 || self@line < 1) {
      return("@line must be a positive scalar integer")
    }

    # library/require constraints
    if (self@import_mechanism %in% c("library", "require")) {
      if (!is.null(self@namespace_alias)) {
        return("library/require do not support aliasing")
      }
      if (!is.null(self@selected_objects)) {
        return("library/require do not support selective imports")
      }
      if (!self@attach_all) {
        return("library/require always attach all exports")
      }
    }

    # Box: mutual exclusion between selective imports and attach_all
    if (self@import_mechanism == "box") {
      if (!is.null(self@selected_objects) && self@attach_all) {
        return("Cannot have both selective imports and attach_all")
      }
    }

    # Modules can only be imported via box
    if (self@source_type == "module" && self@import_mechanism != "box") {
      return("Modules can only be imported via box")
    }

    # Validate namespace_name is last component of source_path
    path_parts <- strsplit(self@source_path, "/")[[1]]
    expected_name <- path_parts[length(path_parts)]
    if (self@namespace_name != expected_name) {
      return(sprintf(
        "@namespace_name '%s' must match last component of @source_path '%s'",
        self@namespace_name,
        expected_name
      ))
    }

    NULL
  }
)
