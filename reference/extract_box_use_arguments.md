# Extract argument expressions from box::use() call

For box::use(), arguments can be:

- Simple: mod/math (just an expr)

- Aliased: m = mod/math (SYMBOL_SUB, EQ_SUB, expr)

- Multiple: separated by OP-COMMA

## Usage

``` r
extract_box_use_arguments(call_expr)
```

## Arguments

- call_expr:

  XML node of the box::use() call expression

## Value

List of lists, each containing nodes for one argument

## Details

We need to group nodes between commas as single argument units.
