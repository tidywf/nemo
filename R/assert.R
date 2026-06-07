#' Assert scalar character
#'
#' Stops with an informative message if `x` is not a single non-NA character string.
#' @param x Object to check.
#' @param arg Name of `x` used in the error message; defaults to the expression
#'   passed as `x`.
#' @return `x` invisibly on success.
#' @export
nemo_assert_scalar_chr <- function(x, arg = deparse(substitute(x))) {
  if (!rlang::is_scalar_character(x)) {
    stop(glue("'{arg}' must be a single character string."), call. = FALSE)
  }
  invisible(x)
}

#' Assert character vector
#'
#' Stops with an informative message if `x` is not a character vector.
#' @param x Object to check.
#' @param arg Name of `x` used in the error message.
#' @return `x` invisibly on success.
#' @export
nemo_assert_chr <- function(x, arg = deparse(substitute(x))) {
  if (!rlang::is_character(x)) {
    stop(glue("'{arg}' must be a character vector."), call. = FALSE)
  }
  invisible(x)
}

#' Assert not NULL
#'
#' Stops with an informative message if `x` is `NULL`.
#' @param x Object to check.
#' @param arg Name of `x` used in the error message.
#' @return `x` invisibly on success.
#' @export
nemo_assert_not_null <- function(x, arg = deparse(substitute(x))) {
  if (is.null(x)) {
    stop(glue("'{arg}' must not be NULL."), call. = FALSE)
  }
  invisible(x)
}

assert_include_exclude <- function(include, exclude) {
  assertthat::assert_that(
    is.null(include) || is.null(exclude),
    msg = "You cannot define both include and exclude."
  )
}
