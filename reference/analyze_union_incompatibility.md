# Analyze union type incompatibility for error messages

When a union type is incompatible with an expected type, determine
whether:

- Scenario 1 (Partial): Some union members are compatible (needs type
  narrowing)

- Scenario 2 (Total): No union members are compatible (completely wrong
  type)

## Usage

``` r
analyze_union_incompatibility(actual_type, expected_type)
```

## Arguments

- actual_type:

  The actual type string (may contain unions with \|)

- expected_type:

  The expected type string

## Value

List with elements: scenario ("partial", "total", or NULL),
expected_display
