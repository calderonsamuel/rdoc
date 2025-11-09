# Implementation of annotation checking (internal)

Implementation of annotation checking (internal)

## Usage

``` r
check_strict_mode_annotations_impl(
  fn_assign_node,
  type_info,
  source_expression,
  mode
)
```

## Arguments

- fn_assign_node:

  XML node of function assignment

- type_info:

  Type information extracted from comments (can be NULL)

- source_expression:

  Source expression

- mode:

  Type checking mode (for error messages)

## Value

List of Lint objects
