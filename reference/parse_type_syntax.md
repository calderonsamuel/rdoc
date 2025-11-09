# Parse type syntax into AST

Recursive descent parser for type annotation syntax.

## Usage

``` r
parse_type_syntax(input)
```

## Arguments

- input:

  Character string containing type syntax

## Value

AST object (nested list structure)

## Details

Grammar (EBNF):

      type_expr         ::= union_type
      union_type        ::= primary_type ("|" primary_type)*
      primary_type      ::= qualified_type element_type?
      qualified_type    ::= identifier ("::" identifier)?
      element_type      ::= "<" type_expr ">"
