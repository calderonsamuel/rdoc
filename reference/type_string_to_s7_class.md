# Convert type string to S7 class object

This is the PRIMARY type resolution function. Converts rdoc type
annotations to S7 class objects, which are the source of truth for type
checking.

## Usage

``` r
type_string_to_s7_class(type_string)
```

## Arguments

- type_string:

  Full S7 class name (e.g., "class_integer") or external type (e.g.,
  "roxygen2::roclet")

## Value

S7 class object or NULL if not S7 type

## Examples

``` r
if (FALSE) { # \dontrun{
# S7 class names resolve to S7 class objects
type_string_to_s7_class("class_integer")  # S7::class_integer

# S7 union types
type_string_to_s7_class("class_numeric")  # S7::class_numeric (union)

# NULL is special case
type_string_to_s7_class("NULL")           # NULL

# External types (Phase 24.1)
type_string_to_s7_class("roxygen2::roclet")  # S7 wrapper or exported S7 class
} # }
```
