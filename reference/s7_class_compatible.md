# Check if actual S7 class is compatible with expected S7 class

This is the CORE compatibility checking function. Uses S7's class
hierarchy for inheritance checking. Handles unions (like class_numeric =
class_integer \| class_double).

## Usage

``` r
s7_class_compatible(actual_s7, expected_s7)
```

## Arguments

- actual_s7:

  S7 class object (actual type)

- expected_s7:

  S7 class object (expected type)

## Value

Logical

## Examples

``` r
if (FALSE) { # \dontrun{
# Exact match
s7_class_compatible(S7::class_integer, S7::class_integer)  # TRUE

# Union compatibility
s7_class_compatible(S7::class_integer, S7::class_numeric)  # TRUE
s7_class_compatible(S7::class_double, S7::class_numeric)   # TRUE

# Inheritance
Parent <- S7::new_class("Parent")
Child <- S7::new_class("Child", parent = Parent)
s7_class_compatible(Child, Parent)  # TRUE (child is compatible with parent)
s7_class_compatible(Parent, Child)  # FALSE
} # }
```
