# Exported Function Metadata

Represents a function export with its complete type signature.

## Usage

``` r
exported_function(
  name = character(0),
  export_type = character(0),
  signature = function_signature()
)
```

## Fields

- `name`:

  Character1 - Function name

- `export_type`:

  Character1 - Always "function"

- `signature`:

  function_signature - Parameter and return types
