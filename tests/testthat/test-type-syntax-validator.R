test_that("validate_type_syntax accepts valid simple types", {
  expect_silent(validate_type_syntax("class_integer"))
  expect_silent(validate_type_syntax("class_character"))
  expect_silent(validate_type_syntax("data.frame"))
  expect_silent(validate_type_syntax("MyCustomClass"))
})

test_that("validate_type_syntax accepts valid length constraints", {
  expect_silent(validate_type_syntax("class_integer[1]"))
  expect_silent(validate_type_syntax("class_numeric[5]"))
  expect_silent(validate_type_syntax("class_character[100]"))
})

test_that("validate_type_syntax accepts valid element type constraints", {
  expect_silent(validate_type_syntax("class_list<class_integer>"))
  expect_silent(validate_type_syntax("class_list<class_character>"))
  expect_silent(validate_type_syntax("class_list<class_list<class_integer>>"))
})

test_that("validate_type_syntax accepts combined constraints", {
  expect_silent(validate_type_syntax("class_list<class_integer>[3]"))
  expect_silent(validate_type_syntax("class_list<class_numeric[5]>[2]"))
})

test_that("validate_type_syntax accepts union types", {
  expect_silent(validate_type_syntax("class_integer | class_character"))
  expect_silent(validate_type_syntax("class_integer | class_character | class_logical"))
  expect_silent(validate_type_syntax("class_list<class_integer | class_character>"))
})

test_that("validate_type_syntax rejects empty type spec", {
  expect_error(
    validate_type_syntax(""),
    "Empty type specification"
  )

  expect_error(
    validate_type_syntax("   "),
    "Empty type specification"
  )
})

test_that("validate_type_syntax rejects empty angle brackets", {
  expect_error(
    validate_type_syntax("class_list<>"),
    "Empty element type"
  )

  expect_error(
    validate_type_syntax("class_list< >"),
    "Empty element type"
  )
})

test_that("validate_type_syntax rejects multiple element types", {
  expect_error(
    validate_type_syntax("class_list<int><char>"),
    "Multiple element types"
  )

  expect_error(
    validate_type_syntax("class_list<class_integer><class_character>"),
    "Multiple element types"
  )
})

test_that("validate_type_syntax rejects empty square brackets", {
  expect_error(
    validate_type_syntax("class_integer[]"),
    "Empty length constraint"
  )

  expect_error(
    validate_type_syntax("class_integer[ ]"),
    "Empty length constraint"
  )
})

test_that("validate_type_syntax rejects non-numeric length constraints", {
  expect_error(
    validate_type_syntax("class_integer[abc]"),
    "must be a positive integer"
  )

  expect_error(
    validate_type_syntax("class_integer[1.5]"),
    "must be a positive integer"
  )

  expect_error(
    validate_type_syntax("class_integer[-1]"),
    "must be a positive integer"
  )
})

test_that("validate_type_syntax rejects unbalanced angle brackets", {
  expect_error(
    validate_type_syntax("class_list<class_integer"),
    "Unbalanced angle brackets.*1 '<' but 0 '>'"
  )

  expect_error(
    validate_type_syntax("class_listclass_integer>"),
    "Unbalanced angle brackets.*0 '<' but 1 '>'"
  )

  expect_error(
    validate_type_syntax("class_list<class_list<class_integer>"),
    "Unbalanced angle brackets.*2 '<' but 1 '>'"
  )
})

test_that("validate_type_syntax rejects unbalanced square brackets", {
  expect_error(
    validate_type_syntax("class_integer[1"),
    "Unbalanced square brackets.*1 '\\[' but 0 '\\]'"
  )

  expect_error(
    validate_type_syntax("class_integer1]"),
    "Unbalanced square brackets.*0 '\\[' but 1 '\\]'"
  )
})

test_that("validate_type_syntax rejects pipes at start or end", {
  expect_error(
    validate_type_syntax("| class_integer"),
    "Invalid union: cannot start or end with '\\|'"
  )

  expect_error(
    validate_type_syntax("class_integer |"),
    "Invalid union: cannot start or end with '\\|'"
  )
})

test_that("validate_type_syntax rejects consecutive pipes", {
  expect_error(
    validate_type_syntax("class_integer || class_character"),
    "consecutive '\\|' operators not allowed"
  )

  expect_error(
    validate_type_syntax("class_integer | | class_character"),
    "consecutive '\\|' operators not allowed"
  )
})

test_that("validate_type_syntax provides source location in error messages", {
  expect_error(
    validate_type_syntax("class_list<>", source_location = "@typedParam foo"),
    "at @typedParam foo"
  )

  expect_error(
    validate_type_syntax("class_integer[]", source_location = "@typedReturn"),
    "at @typedReturn"
  )
})

test_that("validate_type_syntax shows type in error message", {
  expect_error(
    validate_type_syntax("class_list<>"),
    "Type:.*class_list<>"
  )
})

test_that("validate_type_syntax reports multiple errors", {
  # Empty angle brackets + empty square brackets
  expect_error(
    validate_type_syntax("class_list<>[]"),
    "Empty element type"
  )

  expect_error(
    validate_type_syntax("class_list<>[]"),
    "Empty length constraint"
  )
})

test_that("validate_type_syntax accepts whitespace around constraints", {
  # Whitespace is allowed in some places
  expect_silent(validate_type_syntax("class_integer | class_character"))
  expect_silent(validate_type_syntax("class_integer  |  class_character"))
})

test_that("validate_type_syntax works with complex nested types", {
  expect_silent(validate_type_syntax("class_list<class_list<class_list<class_integer>>>"))
  expect_silent(validate_type_syntax("class_list<class_integer | class_character>[5]"))
})

test_that("validate_type_syntax returns invisible NULL on success", {
  result <- validate_type_syntax("class_integer")
  expect_null(result)
  expect_invisible(validate_type_syntax("class_integer"))
})

test_that("validate_type_syntax rejects parenthesis syntax", {
  expect_error(
    validate_type_syntax("numeric(1)"),
    "Invalid syntax.*use '\\[n\\]'"
  )

  expect_error(
    validate_type_syntax("class_integer(5)"),
    "use '\\[n\\]' for length constraints, not '\\(n\\)'"
  )

  expect_error(
    validate_type_syntax("class_character(100)"),
    "Invalid syntax"
  )
})
