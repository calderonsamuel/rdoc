# Validate function return type matches declaration

Validate function return type matches declaration

## Usage

``` r
validate_return_type(
  fn_assign_node,
  declared_type,
  source_expression,
  param_info = NULL
)
```

## Arguments

- fn_assign_node:

  XML node of function assignment

- declared_type:

  Declared return type from @typedReturn

- source_expression:

  Source expression for creating lints

- param_info:

  Optional list of parameter type info from @typedParam

## Value

List of Lint objects (empty if validation passes or cannot be performed)
