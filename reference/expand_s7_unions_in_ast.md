# Expand S7 union types in AST

Recursively expands S7 union types (like class_numeric = class_integer
\| class_double) into their constituent types for display purposes.

## Usage

``` r
expand_s7_unions_in_ast(ast_node)
```

## Arguments

- ast_node:

  AST node from parse_type_syntax

## Value

AST node with S7 unions expanded
