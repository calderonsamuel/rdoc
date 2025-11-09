# Parse @typedReturn tag

This tag works as both @return (for roxygen2 documentation) and provides
type information for static type checking. Format: {type} description

## Usage

``` r
# S3 method for class 'roxy_tag_typedReturn'
roxy_tag_parse(x)
```

## Arguments

- x:

  A roxy_tag object

## Value

A roxy_tag object with return class for roxygen2 compatibility
