# Test suite for type syntax parser
# This replaces the regex-based validation with a proper recursive descent parser

# =============================================================================
# LEXER TESTS
# =============================================================================

test_that("lexer tokenizes simple identifier", {
  tokens <- lex_type_syntax("class_numeric")

  expect_equal(length(tokens), 2)  # identifier + EOF
  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "class_numeric")
  expect_equal(tokens[[1]]$position, 1)
  expect_equal(tokens[[2]]$type, "EOF")
})

test_that("lexer tokenizes identifier with underscore", {
  tokens <- lex_type_syntax("class_integer")

  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "class_integer")
})

test_that("lexer tokenizes identifier with dots", {
  tokens <- lex_type_syntax("class_data.frame")

  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "class_data.frame")
})

test_that("lexer tokenizes number", {
  tokens <- lex_type_syntax("[42]")

  expect_equal(tokens[[1]]$type, "LBRACKET")
  expect_equal(tokens[[2]]$type, "NUMBER")
  expect_equal(tokens[[2]]$value, "42")
  expect_equal(tokens[[3]]$type, "RBRACKET")
})

test_that("lexer tokenizes brackets and angles", {
  tokens <- lex_type_syntax("class_list<int>[5]")

  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "class_list")
  expect_equal(tokens[[2]]$type, "LANGLE")
  expect_equal(tokens[[3]]$type, "IDENTIFIER")
  expect_equal(tokens[[3]]$value, "int")
  expect_equal(tokens[[4]]$type, "RANGLE")
  expect_equal(tokens[[5]]$type, "LBRACKET")
  expect_equal(tokens[[6]]$type, "NUMBER")
  expect_equal(tokens[[6]]$value, "5")
  expect_equal(tokens[[7]]$type, "RBRACKET")
  expect_equal(tokens[[8]]$type, "EOF")
})

test_that("lexer tokenizes pipe", {
  tokens <- lex_type_syntax("int | char")

  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[2]]$type, "PIPE")
  expect_equal(tokens[[2]]$position, 5)  # Position of |
  expect_equal(tokens[[3]]$type, "IDENTIFIER")
})

test_that("lexer handles whitespace correctly", {
  tokens <- lex_type_syntax("  class_list  <  int  >  ")

  # Whitespace should be skipped
  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "class_list")
  expect_equal(tokens[[2]]$type, "LANGLE")
  expect_equal(tokens[[3]]$type, "IDENTIFIER")
  expect_equal(tokens[[3]]$value, "int")
})

test_that("lexer tracks positions accurately", {
  tokens <- lex_type_syntax("class_list<int>")

  expect_equal(tokens[[1]]$position, 1)    # 'class_list' starts at 1
  expect_equal(tokens[[2]]$position, 11)  # '<' at position 11
  expect_equal(tokens[[3]]$position, 12)  # 'int' starts at 12
  expect_equal(tokens[[4]]$position, 15)  # '>' at position 15
})

test_that("lexer rejects invalid characters", {
  expect_error(
    lex_type_syntax("int@char"),
    "Unexpected character '@' at position 4"
  )

  expect_error(
    lex_type_syntax("int#5"),
    "Unexpected character '#' at position 4"
  )
})

test_that("lexer allows numbers in identifiers", {
  # Identifiers can contain numbers (like R identifiers)
  tokens <- lex_type_syntax("numeric5")
  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "numeric5")

  tokens <- lex_type_syntax("list10")
  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "list10")

  # This allows custom types like "R6Class2" or "data.frame2"
  tokens <- lex_type_syntax("MyClass123")
  expect_equal(tokens[[1]]$value, "MyClass123")
})

test_that("lexer rejects parentheses", {
  expect_error(
    lex_type_syntax("numeric(5)"),
    "Unexpected character '\\(' at position 8"
  )
})

test_that("lexer rejects curly braces", {
  expect_error(
    lex_type_syntax("numeric{5}"),
    "Unexpected character '\\{' at position 8"
  )
})

test_that("lexer handles empty string", {
  expect_error(
    lex_type_syntax(""),
    "Empty type specification"
  )

  expect_error(
    lex_type_syntax("   "),
    "Empty type specification"
  )
})

# =============================================================================
# PARSER TESTS - AST Structure
# =============================================================================

test_that("parser creates AST for simple type", {
  ast <- parse_type_syntax("class_numeric")

  expect_equal(S7::S7_inherits(ast, type_ref))
  expect_equal(ast@base_type, "class_numeric")
  expect_null(ast@element_type)
  expect_null(ast@length_constraint)
})

test_that("parser creates AST for type with length", {
  ast <- parse_type_syntax("class_numeric[5]")

  expect_equal(S7::S7_inherits(ast, type_ref))
  expect_equal(ast@base_type, "class_numeric")
  expect_equal(ast@length_constraint, 5)
  expect_null(ast@element_type)
})

test_that("parser creates AST for generic type", {
  ast <- parse_type_syntax("class_list<class_integer>")

  expect_true(S7::S7_inherits(ast, type_ref))
  expect_equal(ast@base_type, "class_list")
  expect_true(S7::S7_inherits(ast@element_type, type_ref))
  expect_equal(ast@element_type@base_type, "class_integer")
})

test_that("parser creates AST for generic with length", {
  ast <- parse_type_syntax("class_list<class_integer>[3]")

  expect_equal(S7::S7_inherits(ast, type_ref))
  expect_equal(ast@base_type, "class_list")
  expect_equal(ast@length_constraint, 3)
  expect_equal(ast@element_type@base_type, "class_integer")
})

test_that("parser creates AST for nested generic", {
  ast <- parse_type_syntax("class_list<class_list<class_integer>>")

  expect_equal(ast@base_type, "class_list")
  expect_equal(ast@element_type@base_type, "class_list")
  expect_equal(ast@element_type$element_type@base_type, "class_integer")
})

test_that("parser creates AST for union type", {
  ast <- parse_type_syntax("class_integer | class_character")

  expect_equal(S7::S7_inherits(ast, union_type))
  expect_equal(length(ast@types), 2)
  expect_equal(ast@types[[1]]$base_type, "class_integer")
  expect_equal(ast@types[[2]]$base_type, "class_character")
})

test_that("parser creates AST for multi-way union", {
  ast <- parse_type_syntax("class_integer | class_character | class_logical")

  expect_equal(S7::S7_inherits(ast, union_type))
  expect_equal(length(ast@types), 3)
  expect_equal(ast@types[[1]]$base_type, "class_integer")
  expect_equal(ast@types[[2]]$base_type, "class_character")
  expect_equal(ast@types[[3]]$base_type, "class_logical")
})

test_that("parser creates AST for union in generic", {
  ast <- parse_type_syntax("class_list<class_integer | class_character>")

  expect_equal(ast@base_type, "class_list")
  expect_true(S7::S7_inherits(ast@element_type, union_type))
  expect_equal(length(ast@element_type@types), 2)
})

test_that("parser creates AST for complex nested type", {
  ast <- parse_type_syntax("class_list<class_list<class_integer | class_character>[5]>[10]")

  expect_equal(ast@base_type, "class_list")
  expect_equal(ast@length_constraint, 10)
  expect_equal(ast@element_type@base_type, "class_list")
  expect_equal(ast@element_type@length_constraint, 5)
  expect_true(S7::S7_inherits(ast@element_type@element_type, union_type))
})

# =============================================================================
# PARSER TESTS - Error Messages
# =============================================================================

test_that("parser reports error for empty angle brackets", {
  expect_error(
    parse_type_syntax("class_list<>"),
    "Expected type after '<' at position 12"
  )
})

test_that("parser reports error for empty square brackets", {
  expect_error(
    parse_type_syntax("class_integer[]"),
    "Expected number.*at position 15"
  )
})

test_that("parser reports error for unclosed angle bracket", {
  expect_error(
    parse_type_syntax("class_list<class_integer"),
    "Expected '>' at position 25"
  )
})

test_that("parser reports error for unclosed square bracket", {
  expect_error(
    parse_type_syntax("class_integer[5"),
    "Expected.*at position 16"
  )
})

test_that("parser reports error for unexpected closing bracket", {
  expect_error(
    parse_type_syntax("class_integer>"),
    "Unexpected '>' at position 14"
  )

  expect_error(
    parse_type_syntax("class_integer]"),
    "Unexpected.*at position 14"
  )
})

test_that("parser reports error for pipe at start", {
  expect_error(
    parse_type_syntax("| class_integer"),
    "Unexpected '\\|' at position 1"
  )
})

test_that("parser reports error for pipe at end", {
  expect_error(
    parse_type_syntax("class_integer |"),
    "Unexpected end of input"
  )
})

test_that("parser reports error for consecutive pipes", {
  expect_error(
    parse_type_syntax("class_integer || class_character"),
    "Unexpected '\\|' at position 16"
  )
})

test_that("parser reports error for non-numeric length", {
  expect_error(
    parse_type_syntax("class_integer[abc]"),
    "Expected number.*at position 15"
  )
})

test_that("parser reports error for multiple element types", {
  expect_error(
    parse_type_syntax("class_list<class_integer><class_character>"),
    "Unexpected '<' at position 26.*already has element type"
  )
})

test_that("parser reports error for missing type identifier", {
  expect_error(
    parse_type_syntax("[5]"),
    "Expected type identifier at position 1"
  )
})

test_that("parser provides helpful error for decimal numbers", {
  # Decimal point is rejected by lexer
  expect_error(
    parse_type_syntax("integer[1.5]"),
    "Unexpected character '\\.' at position 10"
  )
})

test_that("parser provides helpful error for negative numbers", {
  # Minus sign is rejected by lexer
  expect_error(
    parse_type_syntax("integer[-5]"),
    "Unexpected character '-' at position 9"
  )
})

# =============================================================================
# PARSER TESTS - Edge Cases
# =============================================================================

test_that("parser handles whitespace in unions", {
  ast1 <- parse_type_syntax("class_integer|class_character")
  ast2 <- parse_type_syntax("class_integer | class_character")
  ast3 <- parse_type_syntax("class_integer  |  class_character")

  expect_equal(S7::S7_inherits(ast1, union_type))
  expect_equal(S7::S7_inherits(ast2, union_type))
  expect_equal(S7::S7_inherits(ast3, union_type))
})

test_that("parser handles deeply nested generics", {
  ast <- parse_type_syntax("class_list<class_list<class_list<class_list<class_integer>>>>")

  expect_equal(ast@base_type, "class_list")
  expect_equal(ast@element_type@base_type, "class_list")
  expect_equal(ast@element_type$element_type@base_type, "class_list")
  expect_equal(ast@element_type$element_type@element_type@base_type, "class_list")
  expect_equal(ast@element_type$element_type@element_type$element_type@base_type, "class_integer")
})

test_that("parser handles complex union in nested generic", {
  ast <- parse_type_syntax("class_list<list<integer | character | logical>>")

  inner_union <- ast@element_type$element_type
  expect_equal(S7::S7_inherits(inner_union, union_type))
  expect_equal(length(inner_union@types), 3)
})

test_that("parser handles type names with dots and underscores", {
  ast1 <- parse_type_syntax("class_data.frame")
  ast2 <- parse_type_syntax("class_integer")
  ast3 <- parse_type_syntax("My.Custom_Class")

  expect_equal(ast1@base_type, "class_data.frame")
  expect_equal(ast2@base_type, "class_integer")
  expect_equal(ast3@base_type, "My.Custom_Class")
})

test_that("parser handles large length constraints", {
  ast <- parse_type_syntax("integer[99999]")

  expect_equal(ast@length_constraint, 99999)
})

test_that("parser returns NULL invisibly on success", {
  result <- parse_type_syntax("class_integer")
  expect_invisible(parse_type_syntax("class_integer"))
})

# =============================================================================
# INTEGRATION TESTS - Real-world Examples
# =============================================================================

test_that("parser handles real-world type annotations", {
  # From actual package usage
  expect_silent(parse_type_syntax("class_numeric"))
  expect_silent(parse_type_syntax("class_character"))
  expect_silent(parse_type_syntax("class_integer[1]"))
  expect_silent(parse_type_syntax("class_list<class_integer>"))
  expect_silent(parse_type_syntax("class_list<class_numeric>[2]"))
  expect_silent(parse_type_syntax("class_data.frame"))
  expect_silent(parse_type_syntax("class_list<class_integer | class_character>"))
})

test_that("parser rejects all invalid syntax from Phase 13.1", {
  # Parentheses
  expect_error(parse_type_syntax("numeric(1)"))

  # Curly braces
  expect_error(parse_type_syntax("numeric{1}"))

  # Multiple element types
  expect_error(parse_type_syntax("class_list<int><char>"))

  # Empty brackets
  expect_error(parse_type_syntax("class_list<>"))
  expect_error(parse_type_syntax("integer[]"))
})

# =============================================================================
# SEMANTIC VALIDATION TESTS
# =============================================================================

test_that("parser rejects element types on non-list types", {
  # Primitive types cannot have element types
  expect_error(
    parse_type_syntax("logical<character>"),
    "Type 'logical' cannot have element type"
  )

  expect_error(
    parse_type_syntax("numeric<integer>"),
    "Type 'numeric' cannot have element type"
  )

  expect_error(
    parse_type_syntax("integer<numeric>"),
    "Type 'integer' cannot have element type"
  )

  expect_error(
    parse_type_syntax("character<logical>"),
    "Type 'character' cannot have element type"
  )
})

test_that("parser allows element types only on list types", {
  # These should work
  expect_silent(parse_type_syntax("class_list<class_integer>"))
  expect_silent(parse_type_syntax("class_list<class_character>"))
  expect_silent(parse_type_syntax("class_list<class_logical>"))
  expect_silent(parse_type_syntax("class_list<class_numeric>"))
})

# =============================================================================
# AST UTILITY TESTS
# =============================================================================

test_that("ast_to_string reconstructs type syntax", {
  # Simple type
  expect_equal(ast_to_string(parse_type_syntax("class_integer")), "class_integer")

  # With length
  expect_equal(ast_to_string(parse_type_syntax("class_integer[5]")), "class_integer[5]")

  # Generic
  expect_equal(ast_to_string(parse_type_syntax("class_list<class_integer>")), "class_list<class_integer>")

  # Complex
  expect_equal(
    ast_to_string(parse_type_syntax("class_list<class_integer | class_character>[5]")),
    "class_list<class_integer | class_character>[5]"
  )
})

test_that("ast_validate checks semantic rules", {
  # Length constraint must be non-negative (0 is allowed)
  ast <- parse_type_syntax("class_integer[5]")
  ast@length_constraint <- -1
  expect_error(ast_validate(ast), "Length constraint must be non-negative")

  # Zero is allowed
  ast@length_constraint <- 0
  expect_silent(ast_validate(ast))
})

# =============================================================================
# NULL POSITION VALIDATION (Phase 14.1)
# =============================================================================

test_that("parser accepts NULL as first in union", {
  # Basic NULL union
  expect_silent(parse_type_syntax("NULL | class_integer"))
  expect_silent(parse_type_syntax("NULL | class_character"))
  expect_silent(parse_type_syntax("NULL | class_logical"))

  # Multi-way union with NULL first
  expect_silent(parse_type_syntax("NULL | class_integer | class_character"))
  expect_silent(parse_type_syntax("NULL | class_integer | class_character | class_logical"))

  # Complex types with NULL first
  expect_silent(parse_type_syntax("NULL | class_list<class_integer>"))
  expect_silent(parse_type_syntax("NULL | class_character[1]"))
  expect_silent(parse_type_syntax("NULL | class_list<class_integer>[5]"))
})

test_that("parser rejects NULL not first in union", {
  # NULL at end
  expect_error(
    parse_type_syntax("class_integer | NULL"),
    "NULL must be first in union type"
  )

  expect_error(
    parse_type_syntax("class_character | NULL"),
    "NULL must be first in union type"
  )

  # NULL in middle
  expect_error(
    parse_type_syntax("class_integer | NULL | class_character"),
    "NULL must be first in union type"
  )

  expect_error(
    parse_type_syntax("class_integer | class_character | NULL"),
    "NULL must be first in union type"
  )

  # Complex types with NULL not first
  expect_error(
    parse_type_syntax("class_list<class_integer> | NULL"),
    "NULL must be first in union type"
  )

  expect_error(
    parse_type_syntax("class_character[1] | NULL"),
    "NULL must be first in union type"
  )
})

test_that("parser rejects multiple NULLs in union", {
  expect_error(
    parse_type_syntax("NULL | class_integer | NULL"),
    "NULL can only appear once in union type"
  )

  expect_error(
    parse_type_syntax("NULL | NULL"),
    "NULL can only appear once in union type"
  )

  expect_error(
    parse_type_syntax("NULL | class_integer | class_character | NULL"),
    "NULL can only appear once in union type"
  )
})

test_that("parser accepts standalone NULL type", {
  # Single NULL (not in union) should work
  ast <- parse_type_syntax("NULL")
  expect_equal(S7::S7_inherits(ast, type_ref))
  expect_equal(ast@base_type, "NULL")
})

test_that("NULL position error messages are helpful", {
  error <- tryCatch(
    parse_type_syntax("class_integer | NULL"),
    error = function(e) conditionMessage(e)
  )

  expect_match(error, "NULL must be first")
  expect_match(error, "Use.*NULL.*Type.*not.*Type.*NULL")
  expect_match(error, "S7.*convention")
})

test_that("NULL position validation preserves AST structure", {
  # Verify that valid NULL unions produce correct AST
  ast <- parse_type_syntax("NULL | class_integer")

  expect_equal(S7::S7_inherits(ast, union_type))
  expect_equal(length(ast@types), 2)
  expect_equal(ast@types[[1]]$base_type, "NULL")
  expect_equal(ast@types[[2]]$base_type, "class_integer")

  # Complex case
  ast <- parse_type_syntax("NULL | class_list<class_integer>[5]")

  expect_equal(S7::S7_inherits(ast, union_type))
  expect_equal(ast@types[[1]]$base_type, "NULL")
  expect_equal(ast@types[[2]]$base_type, "class_list")
  expect_equal(ast@types[[2]]$element_type@base_type, "class_integer")
  expect_equal(ast@types[[2]]$length_constraint, 5)
})
