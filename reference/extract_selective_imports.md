# Extract selective imports from module expression

Parses expressions like:

- `module/path\[func1, func2\]` returns
  `list(imports = c("func1", "func2"), attach_all = FALSE)`

- `module/path\[...\]` returns `list(imports = NULL, attach_all = TRUE)`

## Usage

``` r
extract_selective_imports(expr_node)
```

## Arguments

- expr_node:

  XML node containing the module expression with brackets

## Value

List with imports and attach_all flag
