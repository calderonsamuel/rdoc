# Internal parser for typed-return

Parses the format: "{type} description" Creates a structure compatible
with roxygen2's @return tag

## Usage

``` r
tag_parse_typed_return(x)
```

## Arguments

- x:

  A roxy_tag object

## Value

A roxy_tag object with both type info and @return compatibility
