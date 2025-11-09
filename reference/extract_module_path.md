# Extract module path from expression (handles slash-separated paths)

Parses expressions like:

- mod/math → "mod/math"

- ./local/utils → "./local/utils"

- ../shared/helpers → "../shared/helpers"

## Usage

``` r
extract_module_path(expr_node)
```

## Arguments

- expr_node:

  XML node containing the module path expression

## Value

Character string with full module path, or NULL
