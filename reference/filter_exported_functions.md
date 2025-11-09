# Filter function types to only include exported functions

Checks which functions have \#' @export directive in their
documentation. This is used to determine which functions are accessible
from the module.

## Usage

``` r
filter_exported_functions(module_file, all_types)
```

## Arguments

- module_file:

  Path to module .r/.R file

- all_types:

  Named list of all function types

## Value

Named list of only exported function types
