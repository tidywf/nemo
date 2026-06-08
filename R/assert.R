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

#' Assert output format
#'
#' Stops with an informative message if `format` is not a valid output format.
#' @param format Output format to validate.
#' @param choices Available choices for valid output formats.
#' @return `TRUE` invisibly on success.
#' @examples
#' nemo_assert_out_fmt("tsv")
#' @testexamples
#' expect_true(nemo_assert_out_fmt("tsv"))
#' expect_error(nemo_assert_out_fmt("foo"))
#' expect_error(nemo_assert_out_fmt(c("tsv", "csv")))
#' @export
nemo_assert_out_fmt <- function(format, choices = nemo_out_formats()) {
  y <- glue::glue_collapse(choices, sep = ", ", last = " or ")
  if (!rlang::is_scalar_character(format) || !format %in% choices) {
    nemo_stop(glue("Output format should be _one_ of {y}."))
  }
  invisible(TRUE)
}

#' @keywords internal
assert_files_tbl <- function(x) {
  if (!tibble::is_tibble(x)) {
    nemo_stop("'files_tbl' must be a tibble.")
  }
  if (!identical(colnames(x), c("bname", "size", "lastmodified", "path"))) {
    nemo_stop("'files_tbl' must have columns: bname, size, lastmodified, path.")
  }
}

#' @keywords internal
assert_include_exclude <- function(include, exclude) {
  if (!is.null(include) && !is.null(exclude)) {
    nemo_stop("You cannot define both include and exclude.")
  }
}

#' @keywords internal
check_unknown_parsers <- function(parsers, known, label) {
  unknown <- parsers[!parsers %in% known]
  if (length(unknown) > 0) {
    nemo_stop(glue(
      "filter_files: unknown tool_parser(s) in {label}: {glue::glue_collapse(unknown, sep = ', ')}."
    ))
  }
}
