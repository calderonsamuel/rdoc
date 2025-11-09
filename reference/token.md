# Lexer Token

Represents a single token from the type syntax lexer. Tokens are the
atomic units produced by lexical analysis of type annotations.

## Usage

``` r
token(type = character(0), value = character(0), position = integer(0))
```

## Details

The lexer recognizes 9 distinct token types:

- IDENTIFIER: Type names (e.g., "class_integer", "roxygen2")

- LANGLE, RANGLE: Generic type delimiters `<` and `>`

- LBRACKET, RBRACKET: Length constraint delimiters `[` and `]`

- PIPE: Union type operator `|`

- DOUBLE_COLON: Package qualification `::`

- NUMBER: Numeric literals (only valid in brackets)

- EOF: End of input marker

## Fields

- `type`:

  Character string - token type (validated against known types)

- `value`:

  Character string - lexeme (actual text matched)

- `position`:

  Integer - character position in input string (1-indexed)
