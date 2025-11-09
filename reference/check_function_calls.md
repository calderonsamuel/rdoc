# Check function calls against type signatures

Check function calls against type signatures

## Usage

``` r
check_function_calls(
  xml,
  all_types,
  var_context,
  source_expression,
  mode = "lenient"
)
```

## Arguments

- xml:

  XML parsed content

- all_types:

  List of all type information

- var_context:

  List of variable assignments

- source_expression:

  Source expression for creating lints

- mode:

  Type checking mode ("lenient", "exported", "strict")

## Value

List of Lint objects
