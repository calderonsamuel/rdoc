# Parser State (R6 Class)

Parser State (R6 Class)

Parser State (R6 Class)

## Details

Mutable state machine for parsing type syntax. Manages token stream and
current position with bounds checking and validation.

## Methods

### Public methods

- [`ParserState$new()`](#method-ParserState-new)

- [`ParserState$current()`](#method-ParserState-current)

- [`ParserState$peek()`](#method-ParserState-peek)

- [`ParserState$advance()`](#method-ParserState-advance)

- [`ParserState$expect()`](#method-ParserState-expect)

- [`ParserState$match()`](#method-ParserState-match)

- [`ParserState$clone()`](#method-ParserState-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize parser with token list

#### Usage

    ParserState$new(tokens)

#### Arguments

- `tokens`:

  List of S7 token objects from lexer

------------------------------------------------------------------------

### Method `current()`

Get current token without advancing

#### Usage

    ParserState$current()

#### Returns

Current S7 token object

------------------------------------------------------------------------

### Method `peek()`

Peek ahead at future token without advancing

#### Usage

    ParserState$peek(offset = 1)

#### Arguments

- `offset`:

  Integer offset from current position (default: 1)

#### Returns

S7 token object at offset position, or last token if beyond end

------------------------------------------------------------------------

### Method `advance()`

Advance to next token

#### Usage

    ParserState$advance()

#### Returns

New current S7 token object after advancing

------------------------------------------------------------------------

### Method `expect()`

Expect specific token type and advance

#### Usage

    ParserState$expect(token_type, context = NULL)

#### Arguments

- `token_type`:

  Character string with expected token type

- `context`:

  Optional context message for error reporting

#### Returns

S7 token object that was matched

------------------------------------------------------------------------

### Method [`match()`](https://rdrr.io/r/base/match.html)

Try to match token type and advance if successful

#### Usage

    ParserState$match(token_type)

#### Arguments

- `token_type`:

  Character string with token type to match

#### Returns

TRUE if matched and advanced, FALSE otherwise

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    ParserState$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
