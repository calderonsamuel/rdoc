# Types roclet

This roclet generates type metadata from @typedParam and @typedReturn
tags. The metadata is saved to inst/types.rds and gets installed with
the package.

## Usage

``` r
roclet_types()
```

## Value

A roxygen2 roclet object for type metadata generation

## Details

This function is typically used in DESCRIPTION files rather than called
directly, so type annotations are not enforced.

## Examples

``` r
if (FALSE) { # \dontrun{
# Use in roxygen2::roxygenize()
roxygen2::roxygenize(roclets = c("collate", "rd", "namespace", "rdoc::roclet_types"))
} # }
```
