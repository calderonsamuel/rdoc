# Check if a function assignment is at the top level (not nested)

Determines whether a function is defined at the top level of the file or
nested inside another function. This is used to filter out false
positives in exported mode, where nested/anonymous functions inside
closures should not be required to have type annotations.

## Usage

``` r
is_function_top_level(fn_assign_node)
```

## Arguments

- fn_assign_node:

  XML node of function assignment

## Value

Logical - TRUE if function is top-level, FALSE if nested
