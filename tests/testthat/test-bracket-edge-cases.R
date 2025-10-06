test_that("parse_type_constraints handles nested generics", {
  # Single nesting - should now work with .+ pattern
  result <- parse_type_constraints("class_list<class_list<class_integer>>")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_list<class_integer>")
  expect_type(result, "list")
})

test_that("parse_type_constraints rejects empty brackets", {
  # With validation, empty brackets are now an error
  expect_error(
    parse_type_constraints("class_integer[]"),
    "Empty length constraint"
  )
})

test_that("parse_type_constraints rejects non-numeric length", {
  # With validation, non-numeric length is now an error
  expect_error(
    parse_type_constraints("class_integer[abc]"),
    "must be a positive integer"
  )
})

test_that("parse_type_constraints rejects empty angle brackets", {
  # With validation, empty angle brackets are now an error
  expect_error(
    parse_type_constraints("class_list<>"),
    "Empty element type"
  )
})

test_that("parse_type_constraints handles whitespace in brackets gracefully", {
  # Validation allows whitespace (after trim), but parsing doesn't match it
  # This is OK - validation passes, parsing treats it as unparseable
  result <- parse_type_constraints("class_integer[ 1 ]")

  # Parser doesn't match whitespace pattern, preserved as-is
  expect_equal(result$base_type, "class_integer[ 1 ]")
  expect_null(result$length_constraint)
})

test_that("parse_type_constraints handles whitespace in angle brackets", {
  result <- parse_type_constraints("class_list< class_integer >")

  # Actually DOES match with .+ pattern (whitespace preserved in element_type)
  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, " class_integer ")
})

test_that("parse_type_constraints handles dots in class names", {
  result <- parse_type_constraints("data.frame[1]")

  # Dots ARE allowed - [^<>\\[\\]]+ matches them
  expect_equal(result$base_type, "data.frame")
  expect_equal(result$length_constraint, 1)
})

test_that("parse_type_constraints handles underscores in class names", {
  result <- parse_type_constraints("my_class[1]")

  expect_equal(result$base_type, "my_class")
  expect_equal(result$length_constraint, 1)
})

test_that("parse_type_constraints handles very large length", {
  result <- parse_type_constraints("class_integer[999999]")

  expect_equal(result$base_type, "class_integer")
  expect_equal(result$length_constraint, 999999)
})

test_that("parse_type_constraints handles zero length", {
  result <- parse_type_constraints("class_integer[0]")

  expect_equal(result$base_type, "class_integer")
  expect_equal(result$length_constraint, 0)
})

test_that("check_length_constraint validates zero length", {
  expect_true(check_length_constraint(0, 0))
  expect_false(check_length_constraint(1, 0))
})

test_that("types_compatible handles subtyping with constraints", {
  # integer[1] should be compatible with numeric[1]
  expect_true(types_compatible("class_integer", "class_numeric", actual_length = 1))

  # But different lengths should fail
  expect_false(types_compatible("class_integer", "class_numeric[2]", actual_length = 1))
})

test_that("types_compatible handles union types with constraints", {
  # Union on right side
  expect_true(types_compatible("class_integer[1]", "class_integer[1] | class_character[1]", actual_length = 1))

  # Union on left side
  expect_true(types_compatible("class_integer[1] | class_character[1]", "class_integer[1]", actual_length = 1))
})

test_that("parse_type_constraints handles combined nested constraints", {
  result <- parse_type_constraints("class_list<class_numeric[5]>[3]")

  # With lazy match .+?, this should now work
  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_numeric[5]")
  expect_equal(result$length_constraint, 3)
})

test_that("parse_type_constraints rejects malformed patterns", {
  # With validation, these are now errors instead of silent preservation

  # Negative length
  expect_error(
    parse_type_constraints("class_integer[-1]"),
    "must be a positive integer"
  )

  # Decimal length
  expect_error(
    parse_type_constraints("class_integer[1.5]"),
    "must be a positive integer"
  )

  # Double brackets - validation can't detect this (would need parsing)
  # Just verify it doesn't crash
  result <- parse_type_constraints("class_integer[1][2]")
  expect_equal(result$base_type, "class_integer[1][2]")  # Preserved as-is
  expect_null(result$length_constraint)  # Not parsed
})

test_that("parse_type_constraints rejects double angle brackets", {
  # class_list<int><char> is malformed - validation catches it
  expect_error(
    parse_type_constraints("class_list<int><char>"),
    "Multiple element types"
  )
})

test_that("format_type_constraints handles complex nested types", {
  parsed <- list(
    base_type = "class_list",
    element_type = "class_numeric[5]",
    length_constraint = 3
  )

  result <- format_type_constraints(parsed)
  expect_equal(result, "class_list<class_numeric[5]>[3]")
})

test_that("types_compatible with NULL and constraints", {
  # NULL should handle constraints gracefully
  expect_true(types_compatible("NULL", "NULL"))

  # NULL vs constrained type
  expect_false(types_compatible("NULL", "class_integer[1]"))
})

test_that("parse_type_constraints handles class_ prefix variations", {
  # With class_ prefix
  result1 <- parse_type_constraints("class_integer[1]")
  expect_equal(result1$base_type, "class_integer")
  expect_equal(result1$length_constraint, 1)

  # Without class_ prefix (also valid)
  result2 <- parse_type_constraints("integer[1]")
  expect_equal(result2$base_type, "integer")
  expect_equal(result2$length_constraint, 1)
})

test_that("parse_type_constraints rejects mixed parenthesis and bracket syntax", {
  # Parentheses in type spec should be rejected
  expect_error(
    parse_type_constraints("class_integer(1)[2]"),
    "Invalid syntax"
  )
})
