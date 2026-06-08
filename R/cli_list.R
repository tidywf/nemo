#' Add 'list' subparser arguments
#'
#' Registers arguments for the `list` subcommand on an argparse subparsers
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
#' cli_list_add_args(subp, wf = "workflow1")
#' }
#' @export
cli_list_add_args <- function(subp, wf = NULL) {
  # fmt: skip
  fmts <- cli_nemo_list_formats |> glue::glue_collapse(sep = ", ")
  l <- subp$add_parser("list", help = "List Parsable Workflow Outputs")
  if (is.null(wf)) {
    l$add_argument("-w", "--workflow", help = "Workflow name.", required = TRUE)
  }
  l$add_argument("-d", "--in_dir", help = "Input directory.", required = TRUE)
  # fmt: skip
  l$add_argument("-f", "--format", help = paste0("Format of list output [def: %(default)s] (", fmts, ")"), default = cli_nemo_list_formats[["pretty"]])
  l$add_argument("-m", "--max", help = "Max rows to show.", type = "integer")
  l$add_argument("-q", "--quiet", help = "Shush all the logs.", action = "store_true")
}

#' Parse and dispatch the 'list' subcommand
#'
#' Assembles arguments from the parsed argparse result and calls
#' [cli_nemo_list()]. When `wf` is non-NULL it overrides `args$workflow`
#' (used by downstream packages that fix the workflow at the script level,
#' e.g. `tidywigits.R`).
#'
#' @param args Named list of parsed CLI arguments, as returned by argparse.
#' Expected fields: `format`, `in_dir`, `workflow` (may be `NULL` when `wf`
#' is provided), `max`, `quiet`.
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow override. When non-NULL, replaces `args$workflow`.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' args <- list(format = "pretty", in_dir = path, workflow = NULL, quiet = FALSE)
#' capture.output(cli_list_parse_args(args, wf = "workflow1"))
#' @testexamples
#' expect_no_error(capture.output(cli_list_parse_args(args, wf = "workflow1")))
#' args_wf <- list(format = "pretty", in_dir = path, workflow = "workflow1", quiet = FALSE)
#' expect_no_error(capture.output(cli_list_parse_args(args_wf, wf = NULL)))
#' args_quiet <- list(format = "pretty", in_dir = path, workflow = NULL, quiet = TRUE)
#' expect_no_error(capture.output(cli_list_parse_args(args_quiet, wf = "workflow1")))
#' args_tsv <- list(format = "tsv", in_dir = path, workflow = NULL, quiet = FALSE)
#' expect_no_error(capture.output(cli_list_parse_args(args_tsv, wf = "workflow1")))
#' @export
cli_list_parse_args <- function(args, wf = NULL) {
  list_args <- list(
    format = args$format,
    in_dir = args$in_dir,
    workflow = wf %||% args$workflow,
    max = args$max
  )
  if (args$quiet) {
    Sys.setenv(NEMO_LOG_ENABLE = "FALSE")
  }
  do.call(cli_nemo_list, list_args)
}

#' List parsable workflow output files
#'
#' Discovers files under `in_dir` for the given workflow and prints a summary
#' table to stdout.
#'
#' @param in_dir (`character(1)`)\cr Input directory to search.
#' @param workflow (`character(1)`)\cr Workflow name (e.g. `"wigits"`).
#' @param format (`character(1)`)\cr Output format: `"pretty"` or `"tsv"`.
#' @param max (`integer(1)` or `NULL`)\cr Max rows to show. `NULL` shows all.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' out_pretty <- capture.output(
#'   cli_nemo_list(in_dir = path, workflow = "workflow1", format = "pretty")
#' )
#' out_tsv <- capture.output(
#'   cli_nemo_list(in_dir = path, workflow = "workflow1", format = "tsv")
#' )
#' out_max <- capture.output(
#'   cli_nemo_list(in_dir = path, workflow = "workflow1", format = "pretty", max = 3)
#' )
#' @testexamples
#' expect_true(grepl("tool_parser", out_pretty[1]))
#' expect_true(grepl("\\|", out_pretty[1]))
#' expect_true(grepl("tool_parser", out_tsv[1]))
#' expect_true(grepl("\t", out_tsv[1]))
#' expect_equal(length(out_max), 5)
#' expect_error(cli_nemo_list(in_dir = path, workflow = "workflow1", format = "parquet"))
#' expect_error(cli_nemo_list(in_dir = path, workflow = "notaworkflow", format = "pretty"))
#' @export
cli_nemo_list <- function(in_dir, workflow, format = "pretty", max = NULL) {
  fun <- nemoverse_wf_dispatch(workflow)
  nemo_assert_out_fmt(format, choices = cli_nemo_list_formats)
  obj <- fun$new(in_dir)
  d <- obj$list_files()
  res <- d |>
    dplyr::mutate(n = dplyr::row_number()) |>
    dplyr::select("n", "tool_parser", "prefix", "bname", "size", "lastmodified", "path")
  if (!is.null(max)) {
    res <- dplyr::slice_head(res, n = max)
  }
  if (format == "tsv") {
    readr::write_tsv(res, stdout())
  } else {
    cat(knitr::kable(res, format = "markdown"), sep = "\n")
  }
}

cli_nemo_list_formats <- c(tsv = "tsv", pretty = "pretty")
