#' Add 'tidy' subparser arguments
#'
#' Registers arguments for the `tidy` subcommand on an argparse subparsers
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
#' cli_tidy_add_args(subp, wf = "workflow1")
#' }
#' @export
cli_tidy_add_args <- function(subp, wf = NULL) {
  fmts <- nemo_out_formats() |> glue::glue_collapse(sep = ", ")
  tidy <- subp$add_parser("tidy", help = "Tidy Workflow Outputs")
  if (is.null(wf)) {
    tidy$add_argument("-w", "--workflow", help = "Workflow name.", required = TRUE)
  }
  tidy$add_argument("-d", "--in_dir", help = "Input directory.", required = TRUE)
  tidy$add_argument("-o", "--out_dir", help = "Output directory.")
  # fmt: skip
  tidy$add_argument("-f", "--format", help = paste0("Format of output [def: %(default)s] (", fmts, ")"), default = "parquet")
  tidy$add_argument("-i", "--id", help = "ID to use for this run.", required = TRUE)
  tidy$add_argument("--dbname", help = "Database name.")
  tidy$add_argument("--dbuser", help = "Database user.")
  tidy$add_argument("--include", help = "Include only these files (comma,sep).")
  tidy$add_argument("--exclude", help = "Exclude these files (comma,sep).")
  tidy$add_argument("-q", "--quiet", help = "Shush all the logs.", action = "store_true")
}

#' Parse and dispatch the 'tidy' subcommand
#'
#' Validates and normalises arguments from the parsed argparse result, then
#' calls [cli_nemo_tidy()]. When `wf` is non-NULL it overrides `args$workflow`
#' (used by downstream packages that fix the workflow at the script level,
#' e.g. `tidywigits.R`).
#'
#' @param args Named list of parsed CLI arguments, as returned by argparse.
#'   Expected fields: `format`, `in_dir`, `out_dir`, `id`, `dbname`, `dbuser`,
#'   `include`, `exclude`, `workflow` (may be `NULL` when `wf` is provided),
#'   `quiet`.
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow override. When non-NULL, replaces `args$workflow`.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' args <- list(
#'   format = "parquet", in_dir = path, out_dir = tempfile(),
#'   id = "run1", workflow = NULL, dbname = NULL, dbuser = NULL,
#'   include = NULL, exclude = NULL, quiet = FALSE
#' )
#' cli_tidy_parse_args(args, wf = "workflow1")
#' @testexamples
#' expect_no_error(cli_tidy_parse_args(args, wf = "workflow1"))
#' args_quiet <- modifyList(args, list(quiet = TRUE, out_dir = tempfile()))
#' expect_no_error(cli_tidy_parse_args(args_quiet, wf = "workflow1"))
#' args_no_dir <- modifyList(args, list(out_dir = NULL))
#' expect_error(cli_tidy_parse_args(args_no_dir, wf = "workflow1"))
#' args_include <- modifyList(args, list(include = "tool1_table1,tool1_table2", out_dir = tempfile()))
#' expect_no_error(cli_tidy_parse_args(args_include, wf = "workflow1"))
#' @export
cli_tidy_parse_args <- function(args, wf = NULL) {
  out_dir <- args$out_dir
  if (args$format != "db") {
    if (is.null(out_dir)) {
      stop("Output directory must be specified when format is not 'db'.")
    }
    fs::dir_create(out_dir)
    out_dir <- normalizePath(out_dir)
  }
  include <- args$include
  exclude <- args$exclude
  if (!is.null(include)) {
    include <- strsplit(include, ",")[[1]]
  }
  if (!is.null(exclude)) {
    exclude <- strsplit(exclude, ",")[[1]]
  }
  tidy_args <- list(
    workflow = wf %||% args$workflow,
    in_dir = args$in_dir,
    out_dir = out_dir,
    out_format = args$format,
    id = args$id,
    dbname = args$dbname,
    dbuser = args$dbuser,
    include = include,
    exclude = exclude
  )
  if (args$quiet) {
    suppressMessages(do.call(cli_nemo_tidy, tidy_args))
  } else {
    do.call(cli_nemo_tidy, tidy_args)
  }
}

#' Tidy workflow output files
#'
#' Discovers and tidies files under `in_dir` for the given workflow, writing
#' results to `out_dir` in the requested format.
#'
#' @param workflow (`character(1)`)\cr Workflow name passed to
#'   [nemoverse_wf_dispatch()].
#' @param in_dir (`character(1)`)\cr Input directory to search.
#' @param out_dir (`character(1)` or `NULL`)\cr Output directory. Required
#'   unless `out_format` is `"db"`.
#' @param out_format (`character(1)`)\cr Output format. One of `"parquet"`,
#'   `"tsv"`, `"csv"`, `"rds"`, or `"db"`.
#' @param id (`character(1)`)\cr Run identifier attached to each output.
#' @param dbname (`character(1)` or `NULL`)\cr Database name. Required when
#'   `out_format` is `"db"`.
#' @param dbuser (`character(1)` or `NULL`)\cr Database user. Required when
#'   `out_format` is `"db"`.
#' @param include (`character(n)` or `NULL`)\cr Tool parser names to include.
#'   `NULL` includes all.
#' @param exclude (`character(n)` or `NULL`)\cr Tool parser names to exclude.
#'   `NULL` excludes none.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' out <- tempfile()
#' res <- cli_nemo_tidy(
#'   workflow = "workflow1", in_dir = path, out_dir = out,
#'   out_format = "parquet", id = "run1",
#'   dbname = NULL, dbuser = NULL, include = NULL, exclude = NULL
#' )
#' @testexamples
#' expect_true(inherits(res, "Workflow"))
#' expect_true(length(res$written_files) > 0)
#' expect_error(cli_nemo_tidy(
#'   workflow = "workflow1", in_dir = path, out_dir = tempfile(),
#'   out_format = "badformat", id = "run1",
#'   dbname = NULL, dbuser = NULL, include = NULL, exclude = NULL
#' ))
#' expect_error(cli_nemo_tidy(
#'   workflow = "notaworkflow", in_dir = path, out_dir = tempfile(),
#'   out_format = "parquet", id = "run1",
#'   dbname = NULL, dbuser = NULL, include = NULL, exclude = NULL
#' ))
#' @export
cli_nemo_tidy <- function(
  workflow,
  in_dir,
  out_dir,
  out_format,
  id,
  dbname,
  dbuser,
  include,
  exclude
) {
  valid_out_fmt(out_format)
  fun <- nemoverse_wf_dispatch(workflow)
  dbconn <- NULL
  if (out_format == "db") {
    stopifnot(!is.null(dbname), !is.null(dbuser))
    dbconn <- DBI::dbConnect(
      drv = RPostgres::Postgres(),
      dbname = dbname,
      user = dbuser
    )
  }
  nemo_log("INFO", paste("Tidying dir:", in_dir))
  obj <- fun$new(in_dir)
  res <- obj$nemofy(
    diro = out_dir,
    format = out_format,
    input_id = id,
    dbconn = dbconn,
    include = include,
    exclude = exclude
  )
  if (out_format == "db") {
    nemo_log("INFO", paste("Tidy results written to db:", dbname))
  } else {
    nemo_log("INFO", paste("Tidy results written to dir:", out_dir))
  }
  invisible(res)
}
