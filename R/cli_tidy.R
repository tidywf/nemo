#' Add 'tidy' subparser arguments
#'
#' Registers arguments for the `tidy` subcommand on an argparse subparsers
#' object. When `wf` is non-NULL the `-w/--workflow` argument is omitted
#' because the workflow is already fixed by the calling package.
#'
#' @param subp Argparse subparsers object (from `$add_subparsers()`).
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow name passed to [nemoverse_wf_dispatch()].
#'
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
  tidy$add_argument("-o", "--output_dir", help = "Output directory.")
  # fmt: skip
  tidy$add_argument("-f", "--format", help = paste0("Format of output [def: %(default)s] (", fmts, ")"), default = "parquet")
  tidy$add_argument("--input_id", help = "Input ID for this run.")
  oid <- tidy$add_mutually_exclusive_group()
  oid$add_argument("--output_id", help = "Output ID for this run.")
  oid$add_argument("--ulid", help = "Generate a ULID as output ID.", action = "store_true")
  tidy$add_argument("--dbname", help = "Database name.")
  tidy$add_argument("--dbuser", help = "Database user.")
  tidy$add_argument("--include", help = "Include only these files (comma sep tool_parsers).")
  tidy$add_argument("--exclude", help = "Exclude only these files (comma sep tool_parsers).")
  tidy$add_argument(
    "--prefix_include",
    help = "Include input prefix column in output tables.",
    action = "store_true"
  )
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
#' Expected fields: `format`, `in_dir`, `output_dir`, `input_id` (optional),
#' `output_id` (optional), `ulid`, `prefix_include`, `dbname`, `dbuser`,
#' `include`, `exclude`, `workflow` (may be `NULL` when `wf` is provided),
#' `quiet`.
#' `output_id` and `ulid` are mutually exclusive at the CLI level (enforced by
#' argparse). When called directly, if both are set `ulid` takes precedence
#' and `output_id` is silently ignored.
#' @param wf (`character(1)` or `NULL`)\cr
#' Workflow override. When non-NULL, replaces `args$workflow`.
#' @param dbdrv (`DBIDriver` or `NULL`)\cr
#' DBI driver object (e.g. `RPostgres::Postgres()`). Required when
#' `args$format` is `"db"`; ignored otherwise. Supplied by the caller so that
#' nemo does not depend on any specific database backend.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' args <- list(
#'   format = "tsv", in_dir = path, output_dir = tempfile(),
#'   input_id = "run1", output_id = NULL, ulid = FALSE,
#'   prefix_include = FALSE, workflow = NULL, dbname = NULL, dbuser = NULL,
#'   include = NULL, exclude = NULL, quiet = FALSE
#' )
#' cli_tidy_parse_args(args, wf = "workflow1")
#' @testexamples
#' expect_no_error(cli_tidy_parse_args(args, wf = "workflow1"))
#' args_no_dir <- modifyList(args, list(output_dir = NULL))
#' expect_error(cli_tidy_parse_args(args_no_dir, wf = "workflow1"))
#' args_include <- modifyList(args, list(include = "tool1_table1, tool1_table2", output_dir = tempfile()))
#' expect_no_error(cli_tidy_parse_args(args_include, wf = "workflow1"))
#' args_outid1 <- modifyList(args, list(output_id = "out1", output_dir = tempfile()))
#' args_outid2 <- modifyList(args, list(ulid = TRUE, output_dir = tempfile()))
#' args_outid3 <- modifyList(args, list(ulid = TRUE, output_dir = tempfile(), output_id = "out2"))
#' expect_no_error(cli_tidy_parse_args(args_outid1, wf = "workflow1"))
#' expect_no_error(cli_tidy_parse_args(args_outid2, wf = "workflow1"))
#' expect_no_error(cli_tidy_parse_args(args_outid3, wf = "workflow1"))
#' args_pfix <- modifyList(args, list(prefix_include = TRUE, output_dir = tempfile()))
#' expect_no_error(cli_tidy_parse_args(args_pfix, wf = "workflow1"))
#' # this quietens the entire session
#' args_quiet <- modifyList(args, list(quiet = TRUE, output_dir = tempfile()))
#' expect_no_error(cli_tidy_parse_args(args_quiet, wf = "workflow1"))
#' @export
cli_tidy_parse_args <- function(args, wf = NULL, dbdrv = NULL) {
  output_dir <- args$output_dir
  if (args$format != "db") {
    if (is.null(output_dir)) {
      nemo_stop("Output directory must be specified when format is not 'db'.")
    }
    fs::dir_create(output_dir)
    output_dir <- normalizePath(output_dir)
  }
  include <- args$include
  exclude <- args$exclude
  if (!is.null(include)) {
    include <- trimws(strsplit(include, ",")[[1]])
  }
  if (!is.null(exclude)) {
    exclude <- trimws(strsplit(exclude, ",")[[1]])
  }
  # ulid takes priority
  output_id <- if (args$ulid) ulid::ulid() else args$output_id
  tidy_args <- list(
    workflow = wf %||% args$workflow,
    in_dir = args$in_dir,
    output_dir = output_dir,
    out_format = args$format,
    input_id = args$input_id,
    output_id = output_id,
    prefix_include = args$prefix_include,
    dbdrv = dbdrv,
    dbname = args$dbname,
    dbuser = args$dbuser,
    include = include,
    exclude = exclude
  )
  if (args$quiet) {
    Sys.setenv(NEMO_LOG_ENABLE = "FALSE")
  }
  do.call(cli_nemo_tidy, tidy_args)
}

#' Tidy workflow output files
#'
#' Discovers and tidies files under `in_dir` for the given workflow, writing
#' results to `output_dir` in the requested format.
#'
#' @param workflow (`character(1)`)\cr Workflow name passed to
#' [nemoverse_wf_dispatch()].
#' @param in_dir (`character(1)`)\cr Input directory to search.
#' @param output_dir (`character(1)` or `NULL`)\cr Output directory. Required
#' unless `out_format` is `"db"`.
#' @param out_format (`character(1)`)\cr Output format. One of `"parquet"`,
#' `"tsv"`, `"csv"`, `"rds"`, or `"db"`.
#' @param input_id (`character(1)` or `NULL`)\cr Input run identifier.
#' @param output_id (`character(1)` or `NULL`)\cr Output run identifier.
#' @param prefix_include (`logical(1)`)\cr
#' If `TRUE`, prepend an `input_prefix` column to each tidy table.
#' @param dbdrv (`DBIDriver` or `NULL`)\cr DBI driver object (e.g.
#' `RPostgres::Postgres()`). Required when `out_format` is `"db"`.
#' @param dbname (`character(1)` or `NULL`)\cr Database name. Required when
#' `out_format` is `"db"`.
#' @param dbuser (`character(1)` or `NULL`)\cr Database user. Required when
#' `out_format` is `"db"`.
#' @param include (`character(n)` or `NULL`)\cr Tool parser names to include.
#' `NULL` includes all.
#' @param exclude (`character(n)` or `NULL`)\cr Tool parser names to exclude.
#' `NULL` excludes none.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' out <- tempfile()
#' res <- cli_nemo_tidy(
#'   workflow = "workflow1", in_dir = path, output_dir = out,
#'   out_format = "parquet", input_id = "run1"
#' )
#' @testexamples
#' expect_true(inherits(res, "Workflow"))
#' expect_true(length(res$written_files) > 0)
#' expect_error(cli_nemo_tidy(
#'   workflow = "workflow1", in_dir = path, output_dir = tempfile(),
#'   out_format = "badformat", input_id = "run1"
#' ))
#' expect_error(cli_nemo_tidy(
#'   workflow = "notaworkflow", in_dir = path, output_dir = tempfile(),
#'   out_format = "parquet", input_id = "run1"
#' ))
#' @export
cli_nemo_tidy <- function(
  workflow,
  in_dir,
  output_dir,
  out_format,
  input_id = NULL,
  output_id = NULL,
  prefix_include = FALSE,
  dbdrv = NULL,
  dbname = NULL,
  dbuser = NULL,
  include = NULL,
  exclude = NULL
) {
  nemo_assert_out_fmt(out_format)
  fun <- nemoverse_wf_dispatch(workflow)
  dbconn <- NULL
  if (out_format == "db") {
    nemo_assert_not_null(dbdrv)
    nemo_assert_not_null(dbname)
    nemo_assert_not_null(dbuser)
    dbconn <- DBI::dbConnect(
      drv = dbdrv,
      dbname = dbname,
      user = dbuser
    )
  }
  nemo_log("INFO", paste("Tidying dir:", in_dir))
  obj <- fun$new(in_dir)
  res <- obj$run(
    output_dir = output_dir,
    format = out_format,
    input_id = input_id,
    output_id = output_id,
    prefix_include = prefix_include,
    dbconn = dbconn,
    include = include,
    exclude = exclude
  )
  if (out_format == "db") {
    nemo_log("INFO", paste("Tidy results written to db:", dbname))
  } else {
    nemo_log("INFO", paste("Tidy results written to dir:", output_dir))
  }
  invisible(res)
}
