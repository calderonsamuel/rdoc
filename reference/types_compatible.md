# Check if two types are compatible

S7-FIRST ARCHITECTURE: Resolves type strings to S7 class objects and
uses S7's type system for compatibility checking. Falls back to
string-based checking only for non-S7 types (data.frame, matrix, etc).

## Usage

``` r
types_compatible(actual, expected)
```

## Arguments

- actual:

  Actual type string (e.g., "integer", "class_integer")

- expected:

  Expected type string

## Value

Logical

## Examples

``` r
if (FALSE) { # \dontrun{
# S7 types (uses S7::class_* compatibility)
types_compatible("integer", "numeric")        # TRUE (numeric = integer | double)
types_compatible("class_integer", "numeric")  # TRUE (same, normalized)

# S7 inheritance (future: custom classes)
types_compatible("Child", "Parent")  # TRUE if Child inherits from Parent

# Fallback for non-S7 types
types_compatible("data.frame", "data.frame")  # TRUE (string match)
types_compatible("data.frame", "matrix")      # FALSE
} # }
```
