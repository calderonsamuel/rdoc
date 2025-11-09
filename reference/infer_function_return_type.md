# Infer actual return type from function body

Infer actual return type from function body

## Usage

``` r
infer_function_return_type(
  body_node,
  param_types = list(),
  return_node = FALSE
)
```

## Arguments

- body_node:

  XML node of function body

- param_types:

  Optional named list of parameter types (param_name -\> type_string)

- return_node:

  Logical, if TRUE returns list(type=..., node=...) instead of just type

## Value

Character string with inferred type or "unknown"/"complex", or list if
return_node=TRUE
