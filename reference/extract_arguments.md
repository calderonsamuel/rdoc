# Extract arguments from function call

Extract arguments from function call

## Usage

``` r
extract_arguments(
  call_node,
  var_context = NULL,
  current_line = NULL,
  type_registry = NULL,
  param_types = list()
)
```

## Arguments

- call_node:

  XML node of function call

- var_context:

  Optional list of variable assignments for type inference

- current_line:

  Optional line number for variable lookup

- type_registry:

  Optional list of function type signatures for return type lookup

- param_types:

  Optional named list of parameter types (param_name -\> type_string)

## Value

List of call_argument S7 objects
