# S7 Wrapper for ParserState R6 Class

Wraps the ParserState R6 class for type-safe usage in S7 classes. This
allows ParserState to be used as a property type in S7 objects while
maintaining R6's mutable state machine semantics.

## Usage

``` r
parser_state
```

## Format

An object of class `S7_S3_class` of length 3.

## Details

ParserState is an R6 class (not S7) because it manages mutable state:

- Advances position during parsing (mutates in place)

- Provides imperative state machine API

- Encapsulates private fields (tokens, position)

The S7 wrapper enables type-safe composition in S7 classes while
preserving R6's reference semantics for performance.
