# Tests for Phase 23: Scope-Aware Function Detection
# Verifies that nested functions are not flagged in exported mode

test_that("nested anonymous functions in closures are not checked", {
  # This is the classic linter pattern - factory that returns a function
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Public linter function",
    "#' @typedParam mode {class_character} checking mode",
    "#' @typedReturn {class_list} linter result",
    "#' @export",
    "type_consistency_linter <- function(mode = 'lenient') {",
    "  lintr::Linter(function(source_expression) {",
    "    # This anonymous function should NOT be checked for missing types",
    "    xml <- source_expression$xml_parsed_content",
    "    list()",
    "  })",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # Should have NO lints - nested function's parameters are not checked
  expect_length(lints, 0)
})

test_that("factory functions - returned functions are not checked", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Create a processor function",
    "#' @typedParam config {class_list} configuration",
    "#' @typedReturn {class_function} processor function",
    "#' @export",
    "create_processor <- function(config) {",
    "  function(data) {",
    "    # This returned function should NOT be checked for missing types",
    "    process(data, config)",
    "  }",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # No lints - nested function parameters are not checked
  expect_length(lints, 0)
})

test_that("private helpers inside exported functions are not checked", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Process data",
    "#' @typedParam x {class_numeric} input data",
    "#' @typedReturn {class_numeric} processed data",
    "#' @export",
    "process_data <- function(x) {",
    "  # Define helper inside the function",
    "  helper <- function(y) {",
    "    # This helper should NOT be checked for missing types",
    "    y * 2",
    "  }",
    "  helper(x)",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # No lints - nested function 'helper' is not checked
  expect_length(lints, 0)
})

test_that("top-level exported functions without types ARE checked", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Process data",
    "#' @export",
    "process_data <- function(x, y) {",
    "  x + y",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # Should flag missing type annotations for x, y, and return type
  expect_length(lints, 3)
  expect_true(any(grepl("Parameter 'x' missing type annotation", sapply(lints, function(x) x$message))))
  expect_true(any(grepl("Parameter 'y' missing type annotation", sapply(lints, function(x) x$message))))
  expect_true(any(grepl("missing return type annotation", sapply(lints, function(x) x$message))))
})

test_that("top-level non-exported functions are not checked in exported mode", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Internal helper",
    "internal_helper <- function(x, y) {",
    "  x + y",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # Should not check non-exported functions
  expect_length(lints, 0)
})

test_that("@keywords internal tag skips type checking", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Internal utility function",
    "#' @keywords internal",
    "#' @export",
    "internal_util <- function(x, y) {",
    "  x + y",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # Should not check @keywords internal functions
  expect_length(lints, 0)
})

test_that("@internal tag skips type checking", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Internal utility function",
    "#' @internal",
    "#' @export",
    "internal_util <- function(x, y) {",
    "  x + y",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # Should not check @internal functions
  expect_length(lints, 0)
})

test_that("functions in lists are not checked (edge case)", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Create handlers",
    "#' @typedReturn {class_list} list of handlers",
    "#' @export",
    "create_handlers <- function() {",
    "  list(",
    "    handle_error = function(err) {",
    "      # This function in a list should NOT be checked",
    "      print(err)",
    "    },",
    "    handle_warning = function(warn) {",
    "      print(warn)",
    "    }",
    "  )",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  expect_length(lints, 0)
})

test_that("strict mode checks assigned nested functions", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Factory function",
    "#' @typedParam config {class_list} configuration",
    "create_processor <- function(config) {",
    "  # Assigned nested function - strict mode checks this",
    "  helper <- function(data) {",
    "    process(data, config)",
    "  }",
    "  helper",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "strict")))

  # Strict mode should flag the nested function's parameter
  # since it's an assignment, not an anonymous function
  expect_true(length(lints) > 0)
  expect_true(any(grepl("Parameter 'data' missing type annotation", sapply(lints, function(x) x$message))))
})

test_that("multiple levels of nesting are handled", {
  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Triple-nested function",
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_function} nested function",
    "#' @export",
    "triple_nested <- function(x) {",
    "  function(y) {",
    "    function(z) {",
    "      x + y + z",
    "    }",
    "  }",
    "}"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))

  # Should not check anonymous nested functions
  expect_length(lints, 0)
})

test_that("is_function_top_level correctly identifies top-level functions", {
  # Test the helper function directly
  test_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "top_level <- function() { }",
    "factory <- function() {",
    "  nested <- function() { }",
    "  nested",
    "}"
  ), test_file)

  # Parse the file
  code <- parse(test_file, keep.source = TRUE)
  parsed_xml <- xmlparsedata::xml_parse_data(code)
  xml_doc <- xml2::read_xml(parsed_xml)

  # Find function assignments
  fn_assigns <- xml2::xml_find_all(xml_doc, "//expr[LEFT_ASSIGN and .//FUNCTION]")

  # First function should be top-level
  expect_true(is_function_top_level(fn_assigns[[1]]))

  # Second function (factory) should be top-level
  expect_true(is_function_top_level(fn_assigns[[2]]))

  # Third function (nested) should NOT be top-level
  expect_false(is_function_top_level(fn_assigns[[3]]))
})
