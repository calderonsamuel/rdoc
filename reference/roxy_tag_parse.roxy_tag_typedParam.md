# Parse @typedParam tag

This tag works as both @param (for roxygen2 documentation) and provides
type information for static type checking. Format: name {type}
description

## Usage

``` r
# S3 method for class 'roxy_tag_typedParam'
roxy_tag_parse(x)
```

## Arguments

- x:

  A roxy_tag object

## Value

A roxy_tag object with param class for roxygen2 compatibility
