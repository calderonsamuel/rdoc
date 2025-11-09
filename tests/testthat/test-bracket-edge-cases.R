test_that("parse_type_constraints handles nested generics", {
  # Single nesting - should now work with .+ pattern
  result <- parse_type_constraints("class_list<class_list<class_integer>>")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_list<class_integer>")
  expect_type(result, "list")  # R's internal type is "list"
})

test_that("parse_type_constraints rejects empty angle brackets", {
  # With validation, empty angle brackets are now an error
  expect_error(
    parse_type_constraints("class_list<>"),
    "Expected type after '<'"
  )
})

test_that("parse_type_constraints handles whitespace in angle brackets", {
  result <- parse_type_constraints("class_list< class_integer >")

  # Actually DOES match with .+ pattern (whitespace preserved in element_type)
  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, " class_integer ")
})

test_that("parse_type_constraints rejects double angle brackets", {
  # class_list<int><char> is malformed - validation catches it
  expect_error(
    parse_type_constraints("class_list<int><char>"),
    "Multiple element types"
  )
})
