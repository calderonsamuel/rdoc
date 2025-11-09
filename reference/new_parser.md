# Create parser state object

Factory function that creates a ParserState R6 object. Validates tokens
and initializes mutable state machine.

## Usage

``` r
new_parser(tokens)
```

## Arguments

- tokens:

  List of S7 token objects from lexer

## Value

ParserState R6 object with methods: current(), peek(), advance(),
expect(), match()
