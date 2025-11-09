# Extract slash-separated path from expression

Handles paths like:

- mod/math

- ./local/utils

- `mod/math\[add\]` (extracts "mod/math", ignoring bracket contents)

## Usage

``` r
extract_slash_separated_path(expr_node)
```

## Arguments

- expr_node:

  XML node containing path expression

## Value

Character string with path
