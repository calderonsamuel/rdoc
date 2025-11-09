# Get cached module types with mtime-based invalidation

Caches module type information keyed by file path + modification time.
Automatically re-parses if file has been modified.

## Usage

``` r
get_cached_module_types(module_file)
```

## Arguments

- module_file:

  Absolute path to module .r/.R file

## Value

Named list of function types (same format as inst/types.rds)
