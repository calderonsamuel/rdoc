# Create a lint object with proper positioning

Helper to eliminate duplication in lint creation. Handles:

- Extracting line/col from XML node

- NA handling with defaults

- Line text retrieval

- Column clamping to line boundaries

## Usage

``` r
create_lint(node, source_expression, message, fallback_line = 1L)
```

## Arguments

- node:

  XML node for positioning

- source_expression:

  Source expression from lintr

- message:

  Lint message

- fallback_line:

  Fallback line if node has no line info

## Value

lintr::Lint object
