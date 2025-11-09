# Infer type of an argument from its AST node

Infer type of an argument from its AST node

## Usage

``` r
infer_argument_type(
  arg_node,
  var_context = NULL,
  current_line = NULL,
  type_registry = NULL,
  param_types = list()
)
```

## Arguments

- arg_node:

  XML node of the argument

- var_context:

  Optional list of variable assignments for lookup

- current_line:

  Optional line number where argument is used (for variable lookup)

- type_registry:

  Optional list of function type signatures for return type lookup

- param_types:

  Optional named list of parameter types (param_name -\> type_string)

## Value

Character string with inferred type or "unknown"
