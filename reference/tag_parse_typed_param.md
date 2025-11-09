# Internal parser for typed-param

Parses the format: "param_name {type} description" Creates a structure
compatible with roxygen2's @param tag

## Usage

``` r
tag_parse_typed_param(x)
```

## Arguments

- x:

  A roxy_tag object

## Value

A roxy_tag object with both type info and @param compatibility
