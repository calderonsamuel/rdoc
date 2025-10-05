test_that("type_consistency_linter can be created", {
  linter <- type_consistency_linter()

  expect_s3_class(linter, "linter")
})

test_that("parse_typed_param_text parses correctly", {
  result <- parse_typed_param_text("x {numeric} input value")

  expect_equal(result$param, "x")
  expect_equal(result$type, "numeric")
  expect_equal(result$description, "input value")
})

test_that("parse_typed_return_text parses correctly", {
  result <- parse_typed_return_text("{numeric} output value")

  expect_equal(result$type, "numeric")
  expect_equal(result$description, "output value")
})

test_that("infer_argument_type detects string", {
  skip_if_not_installed("xml2")

  code <- "'test'"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  str_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(str_node)

  expect_equal(result, "character")
})

test_that("infer_argument_type detects numeric", {
  skip_if_not_installed("xml2")

  code <- "123"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  num_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(num_node)

  expect_equal(result, "numeric")
})

test_that("infer_argument_type detects logical", {
  skip_if_not_installed("xml2")

  code <- "TRUE"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  bool_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(bool_node)

  expect_equal(result, "logical")
})

test_that("infer_argument_type detects NULL", {
  skip_if_not_installed("xml2")

  code <- "NULL"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  null_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(null_node)

  expect_equal(result, "NULL")
})

test_that("types_compatible handles exact matches", {
  expect_true(types_compatible("numeric", "numeric"))
  expect_true(types_compatible("character", "character"))
  expect_false(types_compatible("numeric", "character"))
})

test_that("types_compatible handles union types", {
  expect_true(types_compatible("NULL", "character | NULL"))
  expect_true(types_compatible("character", "character | NULL"))
  expect_false(types_compatible("numeric", "character | NULL"))
})

test_that("types_compatible handles numeric compatibility", {
  expect_true(types_compatible("integer", "numeric"))
  expect_true(types_compatible("numeric", "numeric"))
  expect_true(types_compatible("double", "numeric"))
})

test_that("types_compatible ignores length constraints", {
  expect_true(types_compatible("numeric", "numeric(1)"))
  expect_true(types_compatible("character", "character(n)"))
})

test_that("linter catches type mismatch with literals", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} input
    foo <- function(x) x * 2

    foo('not a number')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should have at least one lint
  expect_true(length(lints) > 0)

  # Check the lint message
  lint_messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("numeric.*character", lint_messages)))
})

test_that("linter passes correct types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} input
    foo <- function(x) x * 2

    foo(123)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter handles union types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric | NULL} input
    foo <- function(x) x

    foo(NULL)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter handles multiple parameters", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} first
    #' @typedParam y {character} second
    foo <- function(x, y) paste(x, y)

    foo('wrong', 123)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should catch the first argument mismatch
  expect_true(length(lints) > 0)
})

test_that("linter skips unknown types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} input
    foo <- function(x) x * 2

    y <- 'string'
    foo(y)  # Can't infer type of variable
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not lint since we can't infer the type
  expect_length(lints, 0)
})

test_that("find_loaded_packages detects library calls", {
  skip_if_not_installed("xml2")

  code <- "
    library(dplyr)
    require(ggplot2)
  "

  parsed <- parse(text = code, keep.source = TRUE)
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parsed))

  source_expr <- list(xml_parsed_content = xml)
  packages <- find_loaded_packages(source_expr)

  expect_true("dplyr" %in% packages)
  expect_true("ggplot2" %in% packages)
})

test_that("linter handles no type annotations gracefully", {
  skip_if_not_installed("lintr")

  code <- "
    # Regular function without types
    foo <- function(x) x * 2

    foo('string')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not lint if no type annotations
  expect_length(lints, 0)
})
