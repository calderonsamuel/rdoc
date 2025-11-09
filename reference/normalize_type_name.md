# Normalize type name (trim whitespace only)

Type names must use the full S7 class name (e.g., "class_integer", not
"integer"). This function only trims whitespace.

## Usage

``` r
normalize_type_name(type_string)
```

## Arguments

- type_string:

  Character string with type name

## Value

Normalized type string

## Examples

``` r
if (FALSE) { # \dontrun{
normalize_type_name("class_integer")  # "class_integer"
normalize_type_name(" class_integer ") # "class_integer"
} # }
```
