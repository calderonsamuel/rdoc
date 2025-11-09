# Check for missing type annotations based on mode

Check for missing type annotations based on mode

## Usage

``` r
check_mode_annotations(
  fn_assign_node,
  type_info,
  source_expression,
  mode,
  comments
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

  Type checking mode ("lenient", "exported", "strict")

- comments:

  Accumulated roxygen comments for this function

## Value

List of Lint objects
