# Collect path components from slash-separated expression

Recursively traverse the expression tree to find path components. Stops
at brackets - doesn't include bracket contents in path.

## Usage

``` r
collect_path_components(expr_node)
```

## Arguments

- expr_node:

  XML node to traverse

## Value

Character vector of path components
