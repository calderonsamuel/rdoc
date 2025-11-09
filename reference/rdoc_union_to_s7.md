# Convert rdoc union AST to S7 union object

Takes a union type AST node from the parser and converts it to an
S7_union object. Handles NULL specially - NULL is represented as R's
NULL (not a class object).

## Usage

``` r
rdoc_union_to_s7(ast_node)
```

## Arguments

- ast_node:

  Union type AST node with structure: list(node_type = "union", types =
  list(...))

## Value

S7_union object created with \| operator, or single S7 class if not
actually a union

## Examples

``` r
if (FALSE) { # \dontrun{
# Parse union syntax
ast <- parse_type_syntax("NULL | class_integer")
s7_union <- rdoc_union_to_s7(ast)
# Returns: <S7_union>: <NULL> or <class_integer>

# Complex case
ast <- parse_type_syntax("NULL | class_character | class_integer")
s7_union <- rdoc_union_to_s7(ast)
# Returns: <S7_union>: <NULL>, <class_character>, or <class_integer>
} # }
```
