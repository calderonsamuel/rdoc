# Tests for R/linter.R
# Core linter orchestration and configuration

test_that("type_consistency_linter can be created", {
  linter <- type_consistency_linter()

  expect_s3_class(linter, "linter")
})
