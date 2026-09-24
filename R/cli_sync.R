#' Add 'sync' subparser arguments
#'
#' Registers arguments for the `sync` subcommand on an argparse subparsers
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
#' cli_sync_add_args(subp, wf = "workflow1")
#' }
#' @export
cli_sync_add_args <- function(subp, wf = NULL) {
  # fmt: skip
  s <- subp$add_parser("sync", help = "Sync Parsable Workflow Outputs From AWS S3")
  if (is.null(wf)) {
    s$add_argument("-w", "--workflow", help = "Workflow name.", required = TRUE)
  }
  s$add_argument("-s", "--src", help = "S3 source path.", required = TRUE)
  s$add_argument("-d", "--dest", help = "Local destination directory.", required = TRUE)
  # fmt: skip
  s$add_argument("--dryrun", help = "Show what would be synced, without syncing.", action = "store_true")
  # fmt: skip
  s$add_argument("--show_patterns", help = "Print the include/exclude patterns and exit.", action = "store_true")
  s$add_argument("-q", "--quiet", help = "Shush all the logs.", action = "store_true")
}

#' Parse and dispatch the 'sync' subcommand
#'
#' Assembles arguments from the parsed argparse result and calls
#' [cli_nemo_sync()]. When `wf` is non-NULL it overrides `args$workflow`
#' (used by downstream packages that fix the workflow at the script level,
#' e.g. `tidywigits.R`).
#'
#' @param args Named list of parsed CLI arguments, as returned by argparse.
#' Expected fields: `src`, `dest`, `workflow` (may be `NULL` when `wf` is
#' provided), `dryrun`, `show_patterns`, `quiet`.
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow override. When non-NULL, replaces `args$workflow`.
#' @examples
#' args <- list(
#'   src = "s3://bucket/run1", dest = tempfile(), workflow = NULL,
#'   dryrun = FALSE, show_patterns = TRUE, quiet = FALSE
#' )
#' out <- capture.output(cli_sync_parse_args(args, wf = "workflow1"))
#' @testexamples
#' expect_true(any(grepl("^ex\t\\*$", out)))
#' @export
cli_sync_parse_args <- function(args, wf = NULL) {
  if (args$quiet) {
    Sys.setenv(NEMO_LOG_ENABLE = "FALSE")
  }
  cli_nemo_sync(
    src = args$src,
    dest = args$dest,
    workflow = wf %||% args$workflow,
    dryrun = args$dryrun,
    show_patterns = args$show_patterns
  )
}

#' Sync parsable workflow output files from S3
#'
#' Runs `aws s3 sync` from `src` to `dest`, pulling down only the files the
#' workflow's tool schemas declare (see [wf_sync_patterns()]). This keeps the
#' "what do we need?" list in one place (the `schema.yaml` files) instead of
#' duplicating it in every caller.
#'
#' @param src (`character(1)`)\cr S3 source path.
#' @param dest (`character(1)`)\cr Local destination directory.
#' @param workflow (`character(1)`)\cr Workflow name (e.g. `"wigits"`).
#' @param dryrun (`logical(1)`)\cr Pass `--dryrun` to `aws s3 sync`.
#' @param show_patterns (`logical(1)`)\cr
#' Print the include/exclude patterns as TSV to stdout and return without
#' syncing.
#' @examples
#' out <- capture.output(
#'   cli_nemo_sync(
#'     src = "s3://bucket/run1", dest = tempfile(),
#'     workflow = "workflow1", show_patterns = TRUE
#'   )
#' )
#' @testexamples
#' expect_true(any(grepl("^ex\t\\*$", out)))
#' expect_error(cli_nemo_sync("s3://b/r", tempfile(), "notaworkflow"))
#' @export
cli_nemo_sync <- function(
  src,
  dest,
  workflow,
  dryrun = FALSE,
  show_patterns = FALSE
) {
  nemo_assert_scalar_chr(src)
  nemo_assert_scalar_chr(dest)
  pats <- wf_sync_patterns(workflow)
  if (show_patterns) {
    readr::write_tsv(pats, stdout(), col_names = FALSE)
    return(invisible(pats))
  }
  nemo_log("INFO", paste0("Syncing ", nrow(pats), " patterns from ", src, " to ", dest))
  fs::dir_create(dest)
  s3sync(src = src, dest = dest, pats = pats, dryrun = dryrun)
}
