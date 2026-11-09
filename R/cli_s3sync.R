#' Add 's3sync' subparser arguments
#'
#' Registers arguments for the `s3sync` subcommand on an argparse subparsers
#' object. When `wf` is non-NULL the `-w/--workflow` argument is omitted
#' because the workflow is already fixed by the calling package.
#'
#' @param subp Argparse subparsers object (from `$add_subparsers()`).
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow name. When non-NULL, `-w/--workflow` is not added.
#' @examples
#' \dontrun{
#' p <- argparse::ArgumentParser(prog = "test.R", python_cmd = get_python())
#' subp <- p$add_subparsers(dest = "subparser_name")
#' cli_s3sync_add_args(subp, wf = "workflow1")
#' }
#' @export
cli_s3sync_add_args <- function(subp, wf = NULL) {
  # fmt: skip
  s <- subp$add_parser("s3sync", help = "Sync Parsable Workflow Outputs From AWS S3")
  if (is.null(wf)) {
    s$add_argument("-w", "--workflow", help = "Workflow name.", required = TRUE)
  }
  s$add_argument("-s", "--src", help = "S3 source path.", required = TRUE)
  s$add_argument("-d", "--dest", help = "Local destination directory.", required = TRUE)
  # fmt: skip
  s$add_argument("--exclude", help = "Extra glob to exclude, on top of the workflow's patterns. Repeatable.", action = "append")
  # fmt: skip
  s$add_argument("--include", help = "Extra glob to include, on top of the workflow's patterns. Wins over any exclude. Repeatable.", action = "append")
  # fmt: skip
  s$add_argument("--dryrun", help = "Show what would be synced, without syncing.", action = "store_true")
  # fmt: skip
  s$add_argument("--show_patterns", help = "Print the include/exclude patterns and exit.", action = "store_true")
  s$add_argument("-q", "--quiet", help = "Shush all the logs.", action = "store_true")
  # fmt: skip
  s$add_argument("--verbose", help = "Show aws s3 sync's per-file output (default: errors and warnings only).", action = "store_true")
}

#' Parse and dispatch the 's3sync' subcommand
#'
#' Assembles arguments from the parsed argparse result and calls
#' [cli_nemo_s3sync()]. When `wf` is non-NULL it overrides `args$workflow`
#' (used by downstream packages that fix the workflow at the script level,
#' e.g. `tidywigits.R`).
#'
#' @param args Named list of parsed CLI arguments, as returned by argparse.
#' Expected fields: `src`, `dest`, `workflow` (may be `NULL` when `wf` is
#' provided), `include` and `exclude` (may be `NULL`), `dryrun`,
#' `show_patterns`, `quiet`, `verbose` (may be `NULL`).
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow override. When non-NULL, replaces `args$workflow`.
#' @examples
#' args <- list(
#'   src = "s3://bucket/run1", dest = tempfile(), workflow = NULL,
#'   dryrun = FALSE, show_patterns = TRUE, quiet = FALSE
#' )
#' out <- capture.output(cli_s3sync_parse_args(args, wf = "workflow1"))
#' @testexamples
#' expect_true(any(grepl("^ex\t\\*$", out)))
#' @export
cli_s3sync_parse_args <- function(args, wf = NULL) {
  if (args$quiet) {
    Sys.setenv(NEMO_LOG_ENABLE = "FALSE")
  }
  cli_nemo_s3sync(
    src = args$src,
    dest = args$dest,
    workflow = wf %||% args$workflow,
    dryrun = args$dryrun,
    show_patterns = args$show_patterns,
    include = args$include,
    exclude = args$exclude,
    quiet = !isTRUE(args$verbose)
  )
}

#' Sync parsable workflow output files from S3
#'
#' Runs `aws s3 sync` from `src` to `dest`, pulling down only the files the
#' workflow's tool schemas declare (see [wf_s3sync_patterns()]).
#'
#' @param src (`character(1)`)\cr S3 source path.
#' @param dest (`character(1)`)\cr Local destination directory.
#' @param workflow (`character(1)`)\cr Workflow name (e.g. `"wigits"`).
#' @param dryrun (`logical(1)`)\cr Pass `--dryrun` to `aws s3 sync`.
#' @param show_patterns (`logical(1)`)\cr
#' Print the include/exclude patterns as TSV to stdout and return without
#' syncing.
#' @param include,exclude (`character(n)`)\cr
#' Extra globs, added after the workflow's own patterns (see
#' [wf_s3sync_patterns()]).
#' @param quiet (`logical(1)`)\cr
#' Pass `--only-show-errors` to `aws s3 sync` (see [s3sync()]). The CLI
#' sets it unless `--verbose` is given.
#' @examples
#' out <- capture.output(
#'   cli_nemo_s3sync(
#'     src = "s3://bucket/run1", dest = tempfile(),
#'     workflow = "workflow1", show_patterns = TRUE,
#'     include = "*.extra.tsv", exclude = "*.big.tsv"
#'   )
#' )
#' @testexamples
#' expect_true(any(grepl("^ex\t\\*$", out)))
#' expect_equal(utils::tail(out, 2), c("ex\t*.big.tsv", "in\t*.extra.tsv"))
#' expect_error(cli_nemo_s3sync("s3://b/r", tempfile(), "notaworkflow"))
#' @export
cli_nemo_s3sync <- function(
  src,
  dest,
  workflow,
  dryrun = FALSE,
  show_patterns = FALSE,
  include = NULL,
  exclude = NULL,
  quiet = TRUE
) {
  nemo_assert_scalar_chr(src)
  nemo_assert_scalar_chr(dest)
  pats <- wf_s3sync_patterns(workflow, include = include, exclude = exclude)
  if (show_patterns) {
    readr::write_tsv(pats, stdout(), col_names = FALSE)
    return(invisible(pats))
  }
  nemo_log("INFO", "Syncing %d patterns from %s to %s", nrow(pats), src, dest)
  fs::dir_create(dest)
  status <- s3sync(
    src = src,
    dest = dest,
    pats = pats,
    dryrun = dryrun,
    quiet = quiet
  )
  if (status != 0L) {
    nemo_stop(glue("aws s3 sync failed (exit {status})."))
  }
  invisible(status)
}
