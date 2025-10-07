test_that("get_box_search_paths uses existing option if set", {
  # Set option temporarily
  old_opt <- getOption("box.path")
  on.exit(options(box.path = old_opt), add = TRUE)

  # Use a real temp directory instead of fake path for cross-platform compatibility
  tmp_dir <- withr::local_tempdir()
  options(box.path = c("R/modules", "shared"))

  paths <- get_box_search_paths(tmp_dir)

  expect_length(paths, 2)
  # Compare normalized paths to handle Windows path variations
  expect_equal(paths[1], normalizePath(file.path(tmp_dir, "R", "modules"), mustWork = FALSE))
  expect_equal(paths[2], normalizePath(file.path(tmp_dir, "shared"), mustWork = FALSE))
})

test_that("get_box_search_paths parses .Rprofile with c() syntax", {
  # Create temp .Rprofile
  tmp_dir <- withr::local_tempdir()
  rprofile <- file.path(tmp_dir, ".Rprofile")
  writeLines('options(box.path = c("R/modules", "shared"))', rprofile)

  # Clear existing option
  old_opt <- getOption("box.path")
  on.exit(options(box.path = old_opt), add = TRUE)
  options(box.path = NULL)

  paths <- get_box_search_paths(tmp_dir)

  expect_length(paths, 2)
  # Compare normalized paths to handle Windows path variations
  expect_equal(paths[1], normalizePath(file.path(tmp_dir, "R", "modules"), mustWork = FALSE))
  expect_equal(paths[2], normalizePath(file.path(tmp_dir, "shared"), mustWork = FALSE))
})

test_that("get_box_search_paths parses .Rprofile with single path", {
  tmp_dir <- withr::local_tempdir()
  rprofile <- file.path(tmp_dir, ".Rprofile")
  writeLines('options(box.path = "R/modules")', rprofile)

  old_opt <- getOption("box.path")
  on.exit(options(box.path = old_opt), add = TRUE)
  options(box.path = NULL)

  paths <- get_box_search_paths(tmp_dir)

  expect_length(paths, 1)
  # Compare normalized paths to handle Windows path variations
  expect_equal(paths, normalizePath(file.path(tmp_dir, "R", "modules"), mustWork = FALSE))
})

test_that("get_box_search_paths handles absolute paths in .Rprofile", {
  tmp_dir <- withr::local_tempdir()
  rprofile <- file.path(tmp_dir, ".Rprofile")

  # Create a real absolute path that works on all platforms
  abs_path <- file.path(tmp_dir, "my_modules")

  # Write to .Rprofile with proper path formatting for the platform
  writeLines(sprintf('options(box.path = "%s")', abs_path), rprofile)

  old_opt <- getOption("box.path")
  on.exit(options(box.path = old_opt), add = TRUE)
  options(box.path = NULL)

  paths <- get_box_search_paths(tmp_dir)

  # Compare normalized paths to handle Windows path variations
  expect_equal(paths, normalizePath(abs_path, mustWork = FALSE))
})

test_that("get_box_search_paths uses BOX_PATH environment variable", {
  old_opt <- getOption("box.path")
  old_env <- Sys.getenv("BOX_PATH", unset = NA)
  on.exit({
    options(box.path = old_opt)
    if (is.na(old_env)) {
      Sys.unsetenv("BOX_PATH")
    } else {
      Sys.setenv(BOX_PATH = old_env)
    }
  }, add = TRUE)

  options(box.path = NULL)
  Sys.setenv(BOX_PATH = paste("R/modules", "shared", sep = .Platform$path.sep))

  # Use temp dir without .Rprofile
  tmp_dir <- withr::local_tempdir()
  paths <- get_box_search_paths(tmp_dir)

  expect_length(paths, 2)
  # Compare normalized paths to handle Windows path variations
  expect_equal(paths[1], normalizePath(file.path(tmp_dir, "R", "modules"), mustWork = FALSE))
  expect_equal(paths[2], normalizePath(file.path(tmp_dir, "shared"), mustWork = FALSE))
})

test_that("get_box_search_paths defaults to project root", {
  tmp_dir <- withr::local_tempdir()

  old_opt <- getOption("box.path")
  old_env <- Sys.getenv("BOX_PATH", unset = NA)
  on.exit({
    options(box.path = old_opt)
    if (is.na(old_env)) {
      Sys.unsetenv("BOX_PATH")
    } else {
      Sys.setenv(BOX_PATH = old_env)
    }
  }, add = TRUE)

  options(box.path = NULL)
  Sys.unsetenv("BOX_PATH")

  paths <- get_box_search_paths(tmp_dir)

  expect_equal(paths, normalizePath(tmp_dir))
})

test_that("parse_box_path_from_rprofile handles comments", {
  tmp_dir <- withr::local_tempdir()
  rprofile <- file.path(tmp_dir, ".Rprofile")
  writeLines(c(
    "# Comment line",
    "options(box.path = 'R/modules')",
    "# Another comment"
  ), rprofile)

  paths <- parse_box_path_from_rprofile(rprofile)

  expect_equal(paths, "R/modules")
})

test_that("parse_box_path_from_rprofile returns empty for non-existent file", {
  paths <- parse_box_path_from_rprofile("/nonexistent/file")

  expect_length(paths, 0)
})

test_that("extract_quoted_strings extracts multiple strings", {
  text <- '"first", "second", "third"'
  strings <- extract_quoted_strings(text)

  expect_equal(strings, c("first", "second", "third"))
})

test_that("extract_quoted_strings handles single quotes", {
  text <- "'first', 'second'"
  strings <- extract_quoted_strings(text)

  expect_equal(strings, c("first", "second"))
})

test_that("extract_quoted_strings handles mixed quotes", {
  text <- '"first", \'second\''
  strings <- extract_quoted_strings(text)

  expect_equal(strings, c("first", "second"))
})

test_that("resolve_module_path finds module in search path", {
  # Create test module structure
  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.r")
  writeLines("#' @export\nadd <- function(a, b) a + b", module_file)

  current_file <- file.path(tmp_dir, "script.r")

  resolved <- resolve_module_path("mod/math", current_file, tmp_dir)

  expect_equal(resolved, normalizePath(module_file))
})

test_that("resolve_module_path handles .R extension", {
  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.R")  # Capital R
  writeLines("#' @export\nadd <- function(a, b) a + b", module_file)

  current_file <- file.path(tmp_dir, "script.r")

  resolved <- resolve_module_path("mod/math", current_file, tmp_dir)

  expect_equal(resolved, normalizePath(module_file))
})

test_that("resolve_module_path handles relative paths with ./", {
  tmp_dir <- withr::local_tempdir()
  module_file <- file.path(tmp_dir, "utils.r")
  writeLines("#' @export\nhelper <- function() 1", module_file)

  current_file <- file.path(tmp_dir, "script.r")

  resolved <- resolve_module_path("./utils", current_file)

  expect_equal(resolved, normalizePath(module_file))
})

test_that("resolve_module_path handles relative paths with subdirectories", {
  tmp_dir <- withr::local_tempdir()
  subdir <- file.path(tmp_dir, "local")
  dir.create(subdir)
  module_file <- file.path(subdir, "utils.r")
  writeLines("#' @export\nhelper <- function() 1", module_file)

  current_file <- file.path(tmp_dir, "script.r")

  resolved <- resolve_module_path("./local/utils", current_file)

  expect_equal(resolved, normalizePath(module_file))
})

test_that("resolve_module_path returns NULL for non-existent module", {
  tmp_dir <- withr::local_tempdir()
  current_file <- file.path(tmp_dir, "script.r")

  resolved <- resolve_module_path("nonexistent/module", current_file, tmp_dir)

  expect_null(resolved)
})

test_that("resolve_module_path searches multiple search paths", {
  tmp_dir1 <- withr::local_tempdir()
  tmp_dir2 <- withr::local_tempdir()

  # Create module in second path
  mod_dir <- file.path(tmp_dir2, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.r")
  writeLines("#' @export\nadd <- function(a, b) a + b", module_file)

  current_file <- file.path(tmp_dir1, "script.r")

  resolved <- resolve_module_path("mod/math", current_file, c(tmp_dir1, tmp_dir2))

  expect_equal(resolved, normalizePath(module_file))
})

test_that("normalize_box_paths converts relative to absolute", {
  tmp_dir <- withr::local_tempdir()

  paths <- normalize_box_paths(c("R/modules", "shared"), tmp_dir)

  expect_length(paths, 2)
  expect_true(all(grepl("^/", paths) | grepl("^[A-Z]:", paths)))  # Unix or Windows absolute
  # Compare normalized paths to handle Windows path variations
  expect_equal(paths[1], normalizePath(file.path(tmp_dir, "R", "modules"), mustWork = FALSE))
  expect_equal(paths[2], normalizePath(file.path(tmp_dir, "shared"), mustWork = FALSE))
})

test_that("normalize_box_paths handles absolute paths", {
  # Create a real absolute path for the current platform
  tmp_dir <- withr::local_tempdir()
  absolute_path <- file.path(tmp_dir, "absolute", "path")

  paths <- normalize_box_paths(absolute_path, tmp_dir)

  # Compare normalized paths to handle Windows path variations
  expect_equal(paths, normalizePath(absolute_path, mustWork = FALSE))
})
