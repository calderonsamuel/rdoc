# Validate type annotation syntax

Uses the recursive descent parser to validate type syntax. This replaces
the previous regex-based validation (Phase 13.1) with a proper parser
(Phase 13.4) for better error messages and maintainability.

## Usage

``` r
validate_type_syntax(type_spec, source_location = NULL)
```

## Arguments

- type_spec:

  Type specification string (e.g., "class_integer")

- source_location:

  Optional location info for error messages

## Value

Invisible NULL if valid, aborts with error if invalid

## Examples

``` r
if (FALSE) { # \dontrun{
validate_type_syntax("class_integer")  # Valid - returns NULL
validate_type_syntax("class_list<>")      # Invalid - aborts with error
validate_type_syntax("class_list<int><char>")  # Invalid - aborts
} # }
```
