# Function Call Argument Information

Represents information about an argument in a function call, including
its inferred type, position, and optional name (for named arguments).
Used during static type checking to validate function calls.

## Usage

``` r
call_argument(
  node = (function (.data) 
 {
    
    stop(sprintf("S3 class <%s> doesn't have a constructor", class[[1]]), call. =
    FALSE)
 })(),
  type = character(0),
  position = integer(0),
  name = character(0)
)
```

## Fields

- `node`:

  XML node representing the argument expression

- `type`:

  Character string with inferred type (e.g., "class_integer", "unknown")

- `position`:

  Integer position of the argument (1-indexed)

- `name`:

  Character string with argument name for named arguments, or NULL for
  positional
