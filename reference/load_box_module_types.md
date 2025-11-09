# Load type information from box modules

Detects box::use() calls in the file and loads type information from the
imported modules. Handles full imports, selective imports, and module
aliases.

## Usage

``` r
load_box_module_types(xml, current_file)
```

## Arguments

- xml:

  XML AST of the file

- current_file:

  Path to the file being linted

## Value

Named list of function types from all imported modules

## Examples

``` r
if (FALSE) { # \dontrun{
# File contains: box::use(mod/math)
types <- load_box_module_types(xml, "/proj/script.r")
# Returns: list(math$add = list(params = ..., return = ...), ...)
} # }
```
