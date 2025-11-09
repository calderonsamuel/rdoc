# Check arguments against type signature

Check arguments against type signature

## Usage

``` r
check_arguments(
  fn_name,
  args,
  type_info,
  call_node,
  source_expression,
  mode = "lenient"
)
```

## Arguments

- fn_name:

  Function name

- args:

  List of call_argument S7 objects

- type_info:

  Type information for function

- call_node:

  XML node of the call

- source_expression:

  Source expression

- mode:

  Type checking mode ("lenient", "exported", "strict")

## Value

List of Lint objects
