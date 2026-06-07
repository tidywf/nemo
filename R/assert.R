nemo_stop <- function(...) stop(..., call. = FALSE)

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
    nemo_stop(glue("'{arg}' must be a single character string."))
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
    nemo_stop(glue("'{arg}' must be a character vector."))
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
    nemo_stop(glue("'{arg}' must not be NULL."))
  }
  invisible(x)
}

assert_include_exclude <- function(include, exclude) {
  if (!is.null(include) && !is.null(exclude)) {
    nemo_stop("You cannot define both include and exclude.")
  }
}

check_unknown_parsers <- function(parsers, known, label) {
  unknown <- parsers[!parsers %in% known]
  if (length(unknown) > 0) {
    nemo_stop(glue(
      "filter_files: unknown tool_parser(s) in {label}: {glue::glue_collapse(unknown, sep = ', ')}."
    ))
  }
}
