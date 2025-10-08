# rdoc Feature Validation Script
#
# PURPOSE: Manual validation of all rdoc features in VSCode
# INSTRUCTIONS:
#   1. Open this file in VSCode with languageserver + lintr configured
#   2. Ensure .lintr has: type_consistency_linter(mode = "strict")
#   3. Look for squiggly lines under function calls marked with # ❌
#   4. Verify NO squiggly lines under calls marked with # ✅
#   5. Hover over errors to see lint messages

# =============================================================================
# FEATURE 1: Basic Type Checking (Literals)
# =============================================================================

#' Add two numbers
#' @typedParam x {class_numeric} first number
#' @typedParam y {class_numeric} second number
#' @typedReturn {class_numeric} sum
add_numbers <- function(x, y) {
  x + y
}

# ✅ PASS: Correct types
add_numbers(1, 2)
add_numbers(3.14, 2.71)

# ❌ FAIL: Wrong types
add_numbers("text", 2)      # Expects class_numeric, got class_character
add_numbers(1, TRUE)        # Expects class_numeric, got class_logical
add_numbers(NULL, 2)        # Expects class_numeric, got NULL

# =============================================================================
# FEATURE 2: Length Constraints [n]
# =============================================================================

#' Get first element
#' @typedParam x {class_character[1]} single string
#' @typedReturn {class_character[1]} the string
get_first <- function(x) {
  x
}

# ✅ PASS: Scalar string
get_first("hello")

# ❌ FAIL: Not length-1 (rdoc doesn't check runtime length yet, but syntax works)
# Note: Length validation is syntax-level only for now
get_first(c("a", "b"))  # May not error (runtime length checking not implemented)

# =============================================================================
# FEATURE 3: Element Type Constraints <T>
# =============================================================================

#' Process list of numbers
#' @typedParam items {class_list<class_numeric>} list of numbers
#' @typedReturn {class_numeric} sum of all numbers
sum_list <- function(items) {
  sum(unlist(items))
}

# ✅ PASS: List of numbers
sum_list(list(1, 2, 3))

# ❌ FAIL: Not a list
sum_list(c(1, 2, 3))        # Expects class_list, got class_numeric

# Note: Element type validation (<class_numeric>) is syntax-level only
# rdoc validates container type (list) but not element types yet

# =============================================================================
# FEATURE 4: Union Types |
# =============================================================================

#' Accept number or string
#' @typedParam value {class_numeric | class_character} input value
#' @typedReturn {class_character} string representation
to_string <- function(value) {
  as.character(value)
}

# ✅ PASS: Either type in union
to_string(42)
to_string("hello")

# ❌ FAIL: Not in union
to_string(TRUE)            # Expects class_numeric | class_character, got class_logical
to_string(list(1, 2))      # Expects class_numeric | class_character, got class_list

# =============================================================================
# FEATURE 5: NULL Safety (NULL | Type)
# =============================================================================

#' Optional parameter
#' @typedParam name {NULL | class_character[1]} optional name
#' @typedReturn {class_character} greeting
greet <- function(name) {
  if (is.null(name)) "Hello!" else paste("Hello", name)
}

# ✅ PASS: NULL or character
greet(NULL)
greet("Alice")

# ❌ FAIL: Wrong type
greet(123)                 # Expects NULL | class_character, got class_numeric
greet(TRUE)                # Expects NULL | class_character, got class_logical

# =============================================================================
# FEATURE 6: Variable Type Inference
# =============================================================================

#' Needs numeric input
#' @typedParam x {class_numeric} number
#' @typedReturn {class_numeric} result
double_it <- function(x) {
  x * 2
}

# ✅ PASS: Inferred from literal assignment
my_num <- 42
double_it(my_num)          # Infers my_num is class_numeric

# ✅ PASS: Inferred from c()
my_vec <- c(1, 2, 3)
double_it(my_vec)          # Infers my_vec is class_numeric

# ❌ FAIL: Inferred from wrong type
my_str <- "text"
double_it(my_str)          # Infers my_str is class_character, expects class_numeric

# ✅ PASS: Inferred from list()
my_list <- list(1, 2)
# (Need a function that expects list to test)

# =============================================================================
# FEATURE 7: Function Return Type Inference
# =============================================================================

#' Get a number
#' @typedReturn {class_numeric[1]} a number
get_number <- function() {
  42
}

#' Needs character input
#' @typedParam x {class_character} text
#' @typedReturn {class_character} uppercased
upper <- function(x) {
  toupper(x)
}

# ✅ PASS: Infers from @typedReturn
result <- get_number()
# double_it(result)        # Should pass (result is class_numeric from @typedReturn)

# ❌ FAIL: Infers from @typedReturn
num_result <- get_number()
upper(num_result)          # get_number returns class_numeric, upper expects class_character

# =============================================================================
# FEATURE 8: Return Value Validation
# =============================================================================

#' Should return numeric
#' @typedReturn {class_numeric} result
#' @keywords internal
bad_return <- function() {
  "text"                   # ❌ Implementation returns character, declared numeric
}

#' Should return character
#' @typedReturn {class_character} result
#' @keywords internal
good_return <- function() {
  "text"                   # ✅ Matches declaration
}

#' Comparison returns logical
#' @typedReturn {class_logical} result
#' @keywords internal
is_big <- function(x) {
  x > 10                   # ✅ Correctly returns logical
}

# =============================================================================
# FEATURE 9: Named and Positional Arguments
# =============================================================================

#' Function with multiple params
#' @typedParam x {class_numeric} first
#' @typedParam y {class_character} second
#' @typedParam z {class_logical} third
#' @typedReturn {class_character} result
multi_param <- function(x, y, z) {
  paste(x, y, z)
}

# ✅ PASS: Positional arguments
multi_param(1, "hello", TRUE)

# ✅ PASS: Named arguments
multi_param(x = 1, y = "hello", z = TRUE)
multi_param(y = "hello", z = TRUE, x = 1)  # Out of order

# ❌ FAIL: Wrong positional types
multi_param("text", 1, TRUE)     # x is character, expects numeric

# ❌ FAIL: Wrong named types
multi_param(x = "text", y = 1, z = TRUE)  # x is character, y is numeric

# =============================================================================
# FEATURE 10: External Types (package::class)
# =============================================================================

# Note: This requires roxygen2 package to be installed

#' Returns a roclet
#' @typedReturn {roxygen2::roclet} a roclet object
#' @keywords internal
make_roclet <- function() {
  roxygen2::roclet("test")
}

#' Expects a roclet
#' @typedParam x {roxygen2::roclet} roclet input
#' @typedReturn {class_character} description
#' @keywords internal
describe_roclet <- function(x) {
  class(x)[1]
}

# ✅ PASS: External type from function return
# my_roclet <- make_roclet()
# describe_roclet(my_roclet)

# ❌ FAIL: Wrong external type
# describe_roclet("not a roclet")

# =============================================================================
# FEATURE 11: All S7 Base Types
# =============================================================================

#' Test atomic types
#' @typedParam lgl {class_logical} logical
#' @typedParam int {class_integer} integer
#' @typedParam dbl {class_double} double
#' @typedParam cplx {class_complex} complex
#' @typedParam chr {class_character} character
#' @typedParam raw {class_raw} raw bytes
#' @typedReturn {class_list} combined
test_atomics <- function(lgl, int, dbl, cplx, chr, raw) {
  list(lgl, int, dbl, cplx, chr, raw)
}

# ✅ PASS: All correct types
test_atomics(
  lgl = TRUE,
  int = 1L,
  dbl = 3.14,
  cplx = 1+2i,
  chr = "text",
  raw = raw(10)
)

#' Test base classes
#' @typedParam fn {class_function} a function
#' @typedParam env {class_environment} an environment
#' @typedReturn {class_list} combined
test_base <- function(fn, env) {
  list(fn, env)
}

# ✅ PASS: Function and environment
test_base(fn = sum, env = new.env())

#' Test S3 wrappers
#' @typedParam df {class_data.frame} data frame
#' @typedParam dt {class_Date} date
#' @typedParam fct {class_factor} factor
#' @typedReturn {class_list} combined
test_s3_wrappers <- function(df, dt, fct) {
  list(df, dt, fct)
}

# ✅ PASS: S3 wrapped types
test_s3_wrappers(
  df = data.frame(x = 1:3),
  dt = Sys.Date(),
  fct = factor(c("a", "b"))
)

# ❌ FAIL: Wrong S3 types
test_s3_wrappers(
  df = list(x = 1:3),      # Expects class_data.frame, got class_list
  dt = "2024-01-01",       # Expects class_Date, got class_character
  fct = c("a", "b")        # Expects class_factor, got class_character
)

# =============================================================================
# FEATURE 12: Union of S7 Types (Numeric = Integer | Double)
# =============================================================================

#' Accept any numeric
#' @typedParam x {class_numeric} integer or double
#' @typedReturn {class_numeric} result
add_one <- function(x) {
  x + 1
}

# ✅ PASS: Both integer and double work (class_numeric is union)
add_one(1L)    # class_integer (subset of class_numeric)
add_one(3.14)  # class_double (subset of class_numeric)

# =============================================================================
# FEATURE 13: Three-Level Mode System
# =============================================================================

# To test modes, update .lintr config:
#
# MODE: lenient (default)
#   linters: with_defaults(type_consistency_linter = rdoc::type_consistency_linter())
#   - Only checks typed functions
#   - Allows untyped functions
#
# MODE: exported
#   linters: with_defaults(type_consistency_linter = rdoc::type_consistency_linter(mode = "exported"))
#   - Requires types on @export functions
#   - Allows untyped internal functions
#
# MODE: strict
#   linters: with_defaults(type_consistency_linter = rdoc::type_consistency_linter(mode = "strict"))
#   - Requires types on ALL functions
#   - Warns on unknown types in arguments

# Untyped function (different behavior per mode)
#' @export
untyped_exported <- function(x) {
  x + 1
}

# Lenient: ✅ No error
# Exported: ❌ Error (missing types on @export function)
# Strict: ❌ Error (missing types)

#' @keywords internal
untyped_internal <- function(x) {
  x + 1
}

# Lenient: ✅ No error
# Exported: ✅ No error (internal function)
# Strict: ❌ Error (missing types)

# =============================================================================
# FEATURE 14: Comparison and Logical Operators Return Logical
# =============================================================================

#' Expects logical
#' @typedParam condition {class_logical} true or false
#' @typedReturn {class_character} result
if_true <- function(condition) {
  if (condition) "yes" else "no"
}

# ✅ PASS: Comparison operators inferred as logical
x <- 5
if_true(x > 3)
if_true(x >= 5)
if_true(x < 10)
if_true(x <= 5)
if_true(x == 5)
if_true(x != 0)

# ✅ PASS: Logical operators inferred as logical
if_true(TRUE & FALSE)
if_true(TRUE | FALSE)
if_true(!FALSE)

# =============================================================================
# FEATURE 15: Constructor Inference
# =============================================================================

#' Needs specific types
#' @typedParam num {class_numeric} number vector
#' @typedParam lst {class_list} list
#' @typedParam df {class_data.frame} data frame
#' @typedParam mat {class_matrix} matrix
#' @typedReturn {class_list} combined
test_constructors <- function(num, lst, df, mat) {
  list(num, lst, df, mat)
}

# ✅ PASS: Inferred from constructors
v <- c(1, 2, 3)           # Inferred as class_numeric
l <- list(1, 2)           # Inferred as class_list
d <- data.frame(x = 1:3)  # Inferred as class_data.frame
m <- matrix(1:4, 2, 2)    # Inferred as class_matrix

test_constructors(v, l, d, m)

# ❌ FAIL: Wrong constructor
wrong_vec <- c("a", "b")
test_constructors(
  num = wrong_vec,        # Inferred as class_character, expects class_numeric
  lst = l,
  df = d,
  mat = m
)

# =============================================================================
# VALIDATION CHECKLIST
# =============================================================================
#
# Open this file in VSCode and verify:
#
# [ ] Lines marked ✅ have NO red squiggles
# [ ] Lines marked ❌ have RED squiggles underneath the function call
# [ ] Hovering over ❌ lines shows helpful error message
# [ ] Error messages show:
#     - Expected type
#     - Actual type
#     - Parameter name
# [ ] All S7 base types work (class_integer, class_character, etc.)
# [ ] Union types work (| operator)
# [ ] NULL safety works (NULL | Type)
# [ ] External types work (roxygen2::roclet)
# [ ] Variable inference works (assignments tracked)
# [ ] Function return inference works (@typedReturn used)
# [ ] Named and positional arguments both work
# [ ] Comparison operators (>, <, ==) inferred as logical
# [ ] Logical operators (&, |, !) inferred as logical
#
# =============================================================================
# EXPECTED ERRORS (should see these in VSCode)
# =============================================================================
#
# Line ~29: add_numbers("text", 2)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#
# Line ~30: add_numbers(1, TRUE)
#   → Type mismatch for parameter 'y': expected class_numeric, got class_logical
#
# Line ~31: add_numbers(NULL, 2)
#   → Type mismatch for parameter 'x': expected class_numeric, got NULL
#
# Line ~62: sum_list(c(1, 2, 3))
#   → Type mismatch for parameter 'items': expected class_list, got class_numeric
#
# Line ~82: to_string(TRUE)
#   → Type mismatch for parameter 'value': expected class_numeric | class_character, got class_logical
#
# Line ~83: to_string(list(1, 2))
#   → Type mismatch for parameter 'value': expected class_numeric | class_character, got class_list
#
# Line ~102: greet(123)
#   → Type mismatch for parameter 'name': expected NULL | class_character, got class_numeric
#
# Line ~103: greet(TRUE)
#   → Type mismatch for parameter 'name': expected NULL | class_character, got class_logical
#
# Line ~125: double_it(my_str)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#
# Line ~149: upper(num_result)
#   → Type mismatch for parameter 'x': expected class_character, got class_numeric
#
# Line ~161: bad_return function body
#   → Return type mismatch: expected class_numeric, got class_character
#
# Line ~190: multi_param("text", 1, TRUE)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#
# Line ~193: multi_param(x = "text", y = 1, z = TRUE)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#   → Type mismatch for parameter 'y': expected class_character, got class_numeric
#
# Line ~266: test_s3_wrappers with wrong types
#   → Type mismatch for parameter 'df': expected class_data.frame, got class_list
#   → Type mismatch for parameter 'dt': expected class_Date, got class_character
#   → Type mismatch for parameter 'fct': expected class_factor, got class_character
#
# Line ~327: test_constructors with wrong_vec
#   → Type mismatch for parameter 'num': expected class_numeric, got class_character
#
# =============================================================================
