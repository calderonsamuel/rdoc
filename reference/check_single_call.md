# Check a single function call

Check a single function call

## Usage

``` r
check_single_call(
  call_node,
  all_types,
  var_context,
  source_expression,
  mode = "lenient"
)
```

## Arguments

- call_node:

  XML node of the function call

- all_types:

  List of type information

- var_context:

  List of variable assignments

- source_expression:

  Source expression

- mode:

  Type checking mode ("lenient", "exported", "strict")

## Value

List of Lint objects
