test_that("extract_module_types extracts types from exported function", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 1)
  expect_named(types, "double")
  expect_equal(types$double$params$x$type, "class_numeric")
  expect_equal(types$double$return$type, "class_numeric")
})

test_that("extract_module_types ignores non-exported functions", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "# No @export here",
    "double <- function(x) x * 2"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 0)
})

test_that("extract_module_types handles multiple exported functions", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam a {class_numeric} first",
    "#' @typedParam b {class_numeric} second",
    "#' @typedReturn {class_numeric} sum",
    "#' @export",
    "add <- function(a, b) a + b",
    "",
    "#' @typedParam a {class_numeric} first",
    "#' @typedParam b {class_numeric} second",
    "#' @typedReturn {class_numeric} product",
    "#' @export",
    "multiply <- function(a, b) a * b"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 2)
  expect_named(types, c("add", "multiply"))
  expect_equal(types$add$params$a$type, "class_numeric")
  expect_equal(types$add$params$b$type, "class_numeric")
  expect_equal(types$multiply$return$type, "class_numeric")
})

test_that("extract_module_types handles mixed exported/non-exported", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "public_func <- function(x) x * 2",
    "",
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "private_func <- function(x) x * 3"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 1)
  expect_named(types, "public_func")
})

test_that("extract_module_types handles functions without type annotations", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' Basic function without types",
    "#' @export",
    "no_types <- function(x) x"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  # Function without @typedParam/@typedReturn should not be included
  expect_length(types, 0)
})

test_that("extract_module_types handles empty file", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(character(0), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 0)
})

test_that("extract_module_types handles non-existent file", {
  types <- extract_module_types("/nonexistent/file.r")

  expect_length(types, 0)
})

test_that("get_cached_module_types caches results", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2"
  ), tmp_file)

  # First call - should parse file
  types1 <- get_cached_module_types(tmp_file)

  # Second call - should use cache
  types2 <- get_cached_module_types(tmp_file)

  expect_identical(types1, types2)
  expect_length(types1, 1)
  expect_named(types1, "double")
})

test_that("get_cached_module_types invalidates cache on file modification", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2"
  ), tmp_file)

  # First call
  types1 <- get_cached_module_types(tmp_file)
  expect_length(types1, 1)

  # Modify file (wait a tiny bit to ensure mtime changes)
  Sys.sleep(0.1)
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2",
    "",
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "triple <- function(x) x * 3"
  ), tmp_file)

  # Second call - should re-parse
  types2 <- get_cached_module_types(tmp_file)

  expect_length(types2, 2)
  expect_named(types2, c("double", "triple"))
})

test_that("get_cached_module_types handles non-existent file", {
  types <- get_cached_module_types("/nonexistent/file.r")

  expect_length(types, 0)
})

test_that("extract_module_types handles complex real-world module", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "# Math utilities module",
    "",
    "#' Add two numbers",
    "#' @typedParam a {class_numeric[1]} first number",
    "#' @typedParam b {class_numeric[1]} second number",
    "#' @typedReturn {class_numeric[1]} sum",
    "#' @export",
    "add <- function(a, b) {",
    "  a + b",
    "}",
    "",
    "#' Multiply two numbers",
    "#' @typedParam a {class_numeric[1]} first number",
    "#' @typedParam b {class_numeric[1]} second number",
    "#' @typedReturn {class_numeric[1]} product",
    "#' @export",
    "multiply <- function(a, b) {",
    "  a * b",
    "}",
    "",
    "#' Helper function (not exported)",
    "validate_input <- function(x) {",
    "  !is.na(x)",
    "}"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 2)
  expect_named(types, c("add", "multiply"))
  expect_equal(types$add$params$a$type, "class_numeric[1]")
  expect_equal(types$add$params$b$type, "class_numeric[1]")
  expect_equal(types$add$return$type, "class_numeric[1]")
  expect_equal(types$multiply$return$type, "class_numeric[1]")
})

test_that("extract_module_types handles @typedParam with no @typedReturn", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @export",
    "print_number <- function(x) print(x)"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 1)
  expect_named(types, "print_number")
  expect_equal(types$print_number$params$x$type, "class_numeric")
  expect_null(types$print_number$return)
})

test_that("extract_module_types handles @typedReturn with no @typedParam", {
  tmp_file <- withr::local_tempfile(fileext = ".r")
  writeLines(c(
    "#' @typedReturn {class_numeric[1]} constant",
    "#' @export",
    "get_pi <- function() 3.14159"
  ), tmp_file)

  types <- extract_module_types(tmp_file)

  expect_length(types, 1)
  expect_named(types, "get_pi")
  expect_equal(types$get_pi$return$type, "class_numeric[1]")
  expect_length(types$get_pi$params, 0)
})
