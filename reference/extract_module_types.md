# Extract type annotations from a box module file

Reads a .r/.R file and extracts all type annotations from functions
marked with \#' @export. Returns type information in the same format as
inst/types.rds for consistency with package type loading.

## Usage

``` r
extract_module_types(module_file)
```

## Arguments

- module_file:

  Path to module .r/.R file

## Value

Named list: function_name -\> list(params = list(...), return = "type")

## Examples

``` r
if (FALSE) { # \dontrun{
# Module file:
# #' @typedParam x {class_numeric} value
# #' @typedReturn {class_numeric} result
# #' @export
# double <- function(x) x * 2

types <- extract_module_types("math.r")
# Returns: list(double = list(params = list(x = "numeric"), return = "numeric"))
} # }
```
