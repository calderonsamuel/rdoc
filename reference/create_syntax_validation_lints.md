# Create lint objects for invalid type annotation syntax

Validates @typedParam and @typedReturn tags in roxygen comments and
creates lint objects for any syntax errors found.

## Usage

``` r
create_syntax_validation_lints(comments, comment_nodes, source_expression)
```

## Arguments

- comments:

  Character vector of roxygen comment lines

- comment_nodes:

  XML nodes for the comments (for line numbers)

- source_expression:

  Source expression for creating lints

## Value

List of lint objects
