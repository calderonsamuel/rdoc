# Extract box::use() import statements from XML AST

Parses all box::use() calls in the source code and extracts:

- Module paths (e.g., "mod/math", "./local/utils")

- Import aliases (e.g., "m" in `box::use(m = mod/math)`)

- Selective imports (e.g., `c("add", "multiply")`)

- Attach-all imports (e.g., `...` syntax)

## Usage

``` r
extract_box_imports(xml)
```

## Arguments

- xml:

  XML parsed content from lintr

## Value

List of module imports, each with structure: list( module_path =
"mod/math", \# The module path as written module_name = "math", \# Last
component for lookup alias = "m" or NULL, \# User-provided alias imports
= c("add", "multiply") or NULL, \# NULL = full module import attach_all
= FALSE, \# TRUE if ... syntax used line = 5L \# Line number of
box::use() call )

## Examples

``` r
if (FALSE) { # \dontrun{
# box::use(mod/math) → full module import
# box::use(m = mod/math) → aliased import
# box::use(mod/math\[add, multiply\]) → selective import
# box::use(mod/math\[...\]) → attach all
} # }
```
