#' AWS S3 Sync Helper
#'
#' @param src (`character(1)`)\cr
#' S3 source path.
#' @param dest (`character(1)`)\cr
#' Local destination path.
#' @param pats (`tibble()`)\cr
#' Patterns tibble with `inex` ("in" or "ex") and `pat` (pattern) columns.
#' If `NULL` and `workflow` is given, the workflow's schema-derived patterns
#' are used (see [wf_sync_patterns()]); if both are `NULL`, everything is
#' excluded.
#' @param workflow (`character(1)`)\cr
#' Workflow name (e.g. `"wigits"`, `"dragen"`) whose schema-derived sync
#' patterns to use. Ignored when `pats` is supplied.
#' @param dryrun (`logical(1)`)\cr
#' If `TRUE`, passes `--dryrun` to `aws s3 sync` so operations are displayed
#' without being executed.
#'
#' @examples
#' \dontrun{
#' src <- "s3://my-awesome-bucket/path/to/run1"
#' dest <- sub("s3:/", "~/s3", src)
#' pats <- tibble::tribble(
#'   ~inex, ~pat,
#'   "ex", "*",
#'   "in", "*foo.csv"
#' )
#' s3sync(src, dest, pats)
#'
#' # let the workflow's schemas decide what to pull down
#' s3sync(src, dest, workflow = "wigits")
#' }
#' @export
s3sync <- function(src, dest, pats = NULL, workflow = NULL, dryrun = FALSE) {
  pats_default <- tibble::tribble(
    ~inex , ~pat ,
    "ex"  , "*"
  )
  if (is.null(pats) && !is.null(workflow)) {
    pats <- wf_sync_patterns(workflow)
  }
  pats <- pats %||% pats_default
  dest <- path.expand(dest)
  pat_args <- pats |>
    dplyr::mutate(
      flag = as.character(glue::glue("--{.data$inex}clude")),
      pat = shQuote(.data$pat)
    ) |>
    tidyr::pivot_longer(c("flag", "pat"), values_to = "value") |>
    dplyr::pull("value")
  args <- c("s3", "sync", shQuote(src), shQuote(dest), pat_args)
  if (dryrun) {
    args <- c(args, "--dryrun")
  }
  system2("aws", args)
}
