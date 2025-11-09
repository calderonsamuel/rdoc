# Type consistency linter

Checks function calls against type annotations from @typedParam and
@typedReturn tags. Works with both local function definitions and
installed packages.

## Usage

``` r
type_consistency_linter(mode = c("lenient", "exported", "strict"))
```

## Arguments

- mode:

  Type checking mode: - \`"lenient"\` (default): Check typed functions
  only, ignore untyped functions - \`"exported"\`: Require types on
  \`@export\` functions, internal functions optional - \`"strict"\`:
  Require types on all functions

## Value

A linter function for use with lintr

## Examples

``` r
if (FALSE) { # \dontrun{
# Lenient mode (default) - gradual adoption:
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter()
)

# Exported mode - enforce types on public API:
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter(mode = "exported")
)

# Strict mode - require types everywhere:
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter(mode = "strict")
)
} # }
```
