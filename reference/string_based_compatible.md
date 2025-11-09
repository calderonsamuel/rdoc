# Check if two types are compatible (string-based, for non-S7 types)

Fallback for types not in S7. Note: Most types should use S7 class names
now. This is only for special cases like NULL.

## Usage

``` r
string_based_compatible(actual, expected)
```

## Arguments

- actual:

  Actual type string

- expected:

  Expected type string

## Value

Logical
