test_that("linter catches type errors in box module calls with full import", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  # Create module
  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2"
  ), file.path(mod_dir, "math.r"))

  # Create script with type error
  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/math)",
    "result <- math$double('text')  # Should error: string instead of numeric"
  ), script_file)

  # Run linter
  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "numeric.*character", ignore.case = TRUE)
})

test_that("linter validates correct box module calls", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @typedParam a {class_numeric} first",
    "#' @typedParam b {class_numeric} second",
    "#' @typedReturn {class_numeric} sum",
    "#' @export",
    "add <- function(a, b) a + b"
  ), file.path(mod_dir, "math.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/math)",
    "result <- math$add(1, 2)  # Correct types"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter works with aliased box imports", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @typedParam x {class_integer} value",
    "#' @typedReturn {class_integer} result",
    "#' @export",
    "triple <- function(x) x * 3L"
  ), file.path(mod_dir, "math.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(m = mod/math)",
    "result <- m$triple(5.5)  # Should error: double instead of integer"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "integer.*numeric", ignore.case = TRUE)
})

test_that("linter works with selective box imports", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @typedParam x {class_character} text",
    "#' @typedReturn {class_character} upper",
    "#' @export",
    "upcase <- function(x) toupper(x)",
    "",
    "#' @typedParam x {class_character} text",
    "#' @typedReturn {class_character} lower",
    "#' @export",
    "downcase <- function(x) tolower(x)"
  ), file.path(mod_dir, "string.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/string[upcase])",  # Only import upcase
    "result <- upcase(123)  # Should error: numeric instead of character"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "character.*numeric", ignore.case = TRUE)
})

test_that("linter works with attach-all box imports", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @typedParam x {class_logical} condition",
    "#' @typedReturn {class_character} message",
    "#' @export",
    "status <- function(x) if (x) 'yes' else 'no'"
  ), file.path(mod_dir, "util.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/util[...])",
    "msg <- status('not a logical')  # Should error"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "logical.*character", ignore.case = TRUE)
})

test_that("linter handles box modules with no type annotations", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @export",
    "helper <- function(x) x + 1"
  ), file.path(mod_dir, "util.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/util)",
    "result <- util$helper('anything')  # No lint since no types declared"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter handles non-existent box modules gracefully", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(nonexistent/module)",
    "result <- module$func('anything')  # No lint since module not found"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter validates box module property access syntax", {
  skip_if_not_installed("lintr")
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  writeLines(c(
    "#' @typedParam n {class_integer[1]} count",
    "#' @typedReturn {class_character} message",
    "#' @export",
    "repeat_msg <- function(n) paste(rep('hi', n), collapse = ' ')"
  ), file.path(mod_dir, "msg.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/msg)",
    "greeting <- msg$repeat_msg(3L)  # Correct",
    "bad <- msg$repeat_msg(3.5)  # Should error: double instead of integer"
  ), script_file)

  lints <- lintr::lint(script_file, linters = type_consistency_linter())

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "class_integer.*class_numeric", ignore.case = TRUE)
  expect_equal(lints[[1]]$line_number, 3)  # Error on line 3
})
