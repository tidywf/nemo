#' @title Workflow Object
#'
#' @description
#' Orchestrates multiple `Tool` objects over a shared directory, handling file
#' discovery, filtering, tidying, and writing in a single pipeline.
#'
#' A Workflow object:
#' - has a name (`name`);
#' - has one or more paths to workflow results (`path`);
#' - holds `Tool` subclass objects accessible via `get_tools()`;
#' - exposes matched files across all tools via `list_files()`;
#' - has a tibble of written output files, populated after `write()` (`written_files`);
#'
#' The typical workflow is: optionally filter with `filter_files()`, tidy with
#' `tidy()`, then write with `write()`. `run()` chains all three steps.
#'
#' @examples
#' fs::path(tempdir(), letters[1:5]) |>
#'   fs::file_temp_push() |>
#'   fs::dir_create()
#' path <- system.file("extdata/tool1", package = "nemo")
#' tools <- list(tool1 = Tool1)
#' wf <- Workflow$new(name = "wf1", path = path, tools = tools)
#' (lf_all <- wf$list_files())
#' (globs <- wf$get_globs())
#' (sync_pats <- wf$get_sync_patterns())
#' wf$filter_files(exclude = "tool1_table6")
#' wf$tidy()
#' (tbls <- wf$get_tbls())
#' (rs <- wf$get_schemas_raw())
#' dir1 <- fs::file_temp(); dir2 <- fs::file_temp()
#' wf$write(output_dir = dir1, format = "parquet", input_id = "run1")
#' (lf1 <- list.files(dir1, pattern = "tool1.*parquet", full.names = TRUE))
#' (meta <- wf$get_metadata(input_id = "run1", output_id = "out1", output_dir = dir1))
#' wf2 <- Workflow$new(name = "wf2", path = path, tools = tools)
#' wf2$run(output_dir = dir2, format = "parquet", input_id = "run2")
#' (lf2 <- list.files(dir2, pattern = "tool1.*parquet", full.names = TRUE))
#' @export
Workflow <- R6::R6Class(
  "Workflow",
  cloneable = FALSE,
  public = list(
    #' @field name (`character(1)`)\cr
    #' Name of workflow.
    name = NULL,
    #' @field path (`character(n)`)\cr
    #' Path(s) to workflow results.
    path = NULL,
    #' @field metapkg (`character(n)`)\cr
    #' Package name(s) used for metadata version reporting.
    metapkg = NULL,
    #' @field written_files (`tibble(n)`)\cr
    #' Tibble of files written from `self$write()`.
    written_files = NULL,
    #' @field sync_exclude (`character(n)`)\cr
    #' Globs appended as trailing `--exclude` patterns by
    #' `get_sync_patterns()`, to carve files back out of the schema-derived
    #' includes (e.g. duplicate copies of the same output under a different
    #' directory). Subclasses override this.
    sync_exclude = character(),

    #' @description Create a new Workflow object.
    #' @param name (`character(1)`)\cr
    #' Name of workflow.
    #' @param path (`character(n)`)\cr
    #' Path(s) to workflow results.
    #' @param tools (`list(n)`)\cr
    #' Named list of Tool subclasses that compose a Workflow. List names serve
    #' as aliases and need not match each tool's own `$name` field.
    #' @param metapkg (`character(n)`)\cr
    #' Package name(s) used for metadata version reporting.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(name, path, tools, metapkg = "nemo") {
      nemo_assert_scalar_chr(name)
      nemo_assert_chr(metapkg)
      nemo_assert_chr(path)
      if (!all(dir.exists(path))) {
        nemo_stop(glue(
          "Path(s) do not exist: {glue::glue_collapse(path[!dir.exists(path)], sep = ', ')}."
        ))
      }
      self$name <- name
      self$metapkg <- metapkg
      private$validate_tools(tools)
      self$path <- normalizePath(path)
      private$files_tbl <- list_files_dir(self$path)
      private$tools <- tools |>
        purrr::map(\(x) x$new(files_tbl = private$files_tbl))
    },
    #' @description Print details about the Workflow.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var            , ~value                                     ,
        "name"          , self$name                                  ,
        "path"          , glue::glue_collapse(self$path, sep = ", ") ,
        "ntools"        , as.character(length(private$tools))        ,
        "files_total"   , as.character(nrow(private$files_tbl))      ,
        "files_matched" , as.character(nrow(self$list_files()))      ,
        "tidied"        , tolower(as.character(private$is_tidied))   ,
        "written"       , tolower(as.character(private$is_written))
      )
      cat(glue("#--- Workflow {self$name} ---#\n"))
      print(knitr::kable(res))
      invisible(self)
    },
    #' @description Get the list of Tool objects in this Workflow.
    #' @return (`list(n)`)\cr
    #' Named list of instantiated Tool objects.
    get_tools = function() private$tools,
    #' @description Get S3 sync globs for all Tools, derived from their schema
    #' patterns.
    #' @return (`tibble()`)\cr
    #' Bound `get_globs()` tibbles from all Tools (`tool`, `name`, `glob`).
    get_globs = function() {
      private$tools |>
        purrr::map(\(x) x$get_globs()) |>
        dplyr::bind_rows()
    },
    #' @description Build the `aws s3 sync` include/exclude patterns for this
    #' Workflow: exclude everything, then include every schema-derived glob,
    #' then apply `sync_exclude`. `aws s3 sync` filters are ordered and
    #' last-match wins, so the trailing excludes carve back out of the includes.
    #' @return (`tibble()`)\cr
    #' Tibble with `inex` (`"in"`/`"ex"`) and `pat` columns, as expected by
    #' [s3sync()].
    get_sync_patterns = function() {
      dplyr::bind_rows(
        tibble::tibble(inex = "ex", pat = "*"),
        tibble::tibble(inex = "in", pat = unique(self$get_globs()[["glob"]])),
        tibble::tibble(inex = "ex", pat = self$sync_exclude)
      )
    },
    #' @description Filter files in given workflow directory.
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table6"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    filter_files = function(include = NULL, exclude = NULL) {
      assert_include_exclude(include, exclude)
      if (private$is_tidied) {
        nemo_stop("Cannot filter files after tidy() has been called.")
      }
      known <- purrr::map(private$tools, \(x) {
        paste0(x$name, "_", x$config$get_patterns()$name)
      }) |>
        unlist() |>
        unique()
      if (!is.null(include)) {
        check_unknown_parsers(include, known, "include")
      }
      if (!is.null(exclude)) {
        check_unknown_parsers(exclude, known, "exclude")
      }
      if (all(purrr::map_lgl(private$tools, \(x) nrow(x$list_files()) == 0))) {
        return(invisible(self))
      }
      purrr::walk(private$tools, \(x) {
        tool_parsers <- unique(x$list_files()$tool_parser)
        # no include match for this tool -> exclude all its parsers
        if (!is.null(include)) {
          matched <- include[include %in% tool_parsers]
          if (length(matched) > 0) {
            x$filter_files(include = matched)
          } else if (length(tool_parsers) > 0) {
            x$filter_files(exclude = tool_parsers)
          }
        } else if (!is.null(exclude)) {
          matched <- exclude[exclude %in% tool_parsers]
          if (length(matched) > 0) {
            x$filter_files(exclude = matched)
          }
          # tools with no matching parsers are left untouched
        }
      })
      invisible(self)
    },
    #' @description List only files of interest in given workflow directory, i.e.
    #' only those files that match the patterns listed in the individual tool
    #' config.
    #' @return (`tibble()`)\cr
    #' Bound `files` tibbles from all Tools, with a leading `tool` column.
    list_files = function() {
      private$tools |>
        purrr::map(\(x) dplyr::mutate(x$list_files(), tool = x$name, .before = 1)) |>
        dplyr::bind_rows()
    },
    #' @description Tidy Workflow files.
    #' @param keep_raw (`logical(1)`)\cr
    #' Should the raw parsed tibbles be kept in the final output?
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    tidy = function(keep_raw = FALSE) {
      if (private$is_tidied) {
        return(invisible(self))
      }
      purrr::walk(private$tools, \(x) x$tidy(keep_raw = keep_raw))
      private$is_tidied <- TRUE
      return(invisible(self))
    },
    #' @description Write tidy tibbles.
    #' @param output_dir (`character(1)`)\cr
    #' Directory path to output tidy files.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `out1`).
    #' @param prefix_include (`logical(1)`)\cr
    #' If `TRUE`, prepend an `input_prefix` column to each tidy table.
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @param write_metadata (`logical(1)`)\cr
    #' If `TRUE` (default), write a `metadata.parquet` file alongside the tidy
    #' outputs. Set to `FALSE` to suppress.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    write = function(
      output_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      prefix_include = FALSE,
      dbconn = NULL,
      write_metadata = TRUE
    ) {
      nemo_assert_out_fmt(format)
      if (private$is_written) {
        return(invisible(self))
      }
      if (!private$is_tidied) {
        nemo_stop("Did you forget to tidy?")
      }
      output_dir <- private$validate_output_dir(format, output_dir)
      res <- private$tools |>
        purrr::map(\(x) {
          x$write(
            output_dir = output_dir,
            format = format,
            input_id = input_id,
            output_id = output_id,
            prefix_include = prefix_include,
            dbconn = dbconn,
            write_metadata = FALSE
          )
          x$written_files
        }) |>
        dplyr::bind_rows()
      has_output <- nrow(res) > 0
      self$written_files <- if (has_output) res else NULL
      private$is_written <- TRUE
      if (write_metadata && format != "db" && has_output) {
        private$write_metadata_file(input_id, output_id, output_dir)
      }
      return(invisible(self))
    },
    #' @description Filter, tidy, and write files in one step.
    #' @param output_dir (`character(1)`)\cr
    #' Directory path to output tidy files.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `out1`).
    #' @param prefix_include (`logical(1)`)\cr
    #' If `TRUE`, prepend an `input_prefix` column to each tidy table.
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @param write_metadata (`logical(1)`)\cr
    #' If `TRUE` (default), write a `metadata.parquet` file. Set to `FALSE` to suppress.
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table6"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    run = function(
      output_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      prefix_include = FALSE,
      dbconn = NULL,
      write_metadata = TRUE,
      include = NULL,
      exclude = NULL
    ) {
      # fail-fast before parsing
      nemo_assert_out_fmt(format)
      self$filter_files(include = include, exclude = exclude)
      output_dir <- private$validate_output_dir(format, output_dir)
      # Delegate to each Tool's streaming run() to bound memory; a single
      # workflow-level metadata.parquet replaces per-tool metadata.
      res <- private$tools |>
        purrr::map(\(x) {
          x$run(
            output_dir = output_dir,
            format = format,
            input_id = input_id,
            output_id = output_id,
            prefix_include = prefix_include,
            dbconn = dbconn,
            write_metadata = FALSE
          )
          x$written_files
        }) |>
        dplyr::bind_rows()
      has_output <- nrow(res) > 0
      self$written_files <- if (has_output) res else NULL
      private$is_tidied <- TRUE
      private$is_written <- TRUE
      if (write_metadata && format != "db" && has_output) {
        private$write_metadata_file(input_id, output_id, output_dir)
      }
      return(invisible(self))
    },
    #' @description Get raw schemas for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound `schemas_raw` tibbles from all Tools, with a leading `tool` column.
    get_schemas_raw = function() {
      private$tools |>
        purrr::map(\(x) dplyr::mutate(x$config$get_schemas_raw(), tool = x$name, .before = 1)) |>
        dplyr::bind_rows()
    },
    #' @description Get tidy schemas for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound tidy schema tibbles from all Tools, with a leading `tool` column.
    get_schemas_tidy = function() {
      private$tools |>
        purrr::map(\(x) dplyr::mutate(x$config$get_schemas_tidy(), tool = x$name, .before = 1)) |>
        dplyr::bind_rows()
    },
    #' @description Get tidy tibbles for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound `tbls` tibbles from all Tools, with a leading `tool` column.
    #' When `tidy(keep_raw = TRUE)` was used, each tool's tibble also contains
    #' a `raw` list-column.
    get_tbls = function() {
      private$tools |>
        purrr::map(\(x) {
          t <- x$get_tbls()
          if (is.null(t)) {
            return(NULL)
          }
          dplyr::mutate(t, tool = x$name, .before = 1)
        }) |>
        purrr::compact() |>
        dplyr::bind_rows()
    },
    #' @description Get metadata for the workflow run.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `out1`).
    #' @param output_dir (`character(1)`)\cr
    #' Output directory.
    #' @param pkgs (`character(n)`)\cr
    #' Which R packages to extract versions for.
    #' @return (`tibble()`)\cr
    #' Single-row tibble with columns `input_id`, `output_id`, `input_dirs`,
    #' `output_dir`, `pkg_versions`, and `files`.
    get_metadata = function(input_id, output_id, output_dir, pkgs = NULL) {
      pkgs <- pkgs %||% self$metapkg
      if (!is.null(self$written_files)) {
        files <- meta_files_from_written(self$written_files)
      } else {
        files <- private$files_tbl |>
          dplyr::select(fin = "path", "size") |>
          dplyr::mutate(size = as.numeric(.data$size))
      }
      nemo_metadata(
        files = files,
        pkgs = pkgs,
        input_id = input_id,
        output_id = output_id,
        input_dirs = self$path,
        output_dir = output_dir
      )
    }
  ), # public end
  private = list(
    validate_tools = function(x) {
      if (!rlang::is_bare_list(x)) {
        nemo_stop("`tools` must be a list.")
      }
      if (length(x) == 0) {
        nemo_stop("`tools` must not be empty.")
      }
      if (is.null(names(x)) || any(names(x) == "")) {
        nemo_stop("`tools` must be a named list.")
      }
      if (!all(purrr::map_lgl(x, R6::is.R6Class))) {
        nemo_stop("All elements of `tools` must be R6 classes.")
      }
      if (!all(purrr::map_lgl(x, wf_is_tool_subclass))) {
        nemo_stop("All elements of `tools` must inherit from Tool.")
      }
    },
    # Normalised once so every Tool gets the same path.
    validate_output_dir = function(format, output_dir) {
      if (format == "db") {
        return(output_dir)
      }
      if (is.null(output_dir)) {
        nemo_stop("Output directory must be specified when format is not 'db'.")
      }
      normalizePath(output_dir, mustWork = FALSE)
    },
    write_metadata_file = function(input_id, output_id, output_dir) {
      meta <- self$get_metadata(
        input_id = input_id,
        output_id = output_id,
        output_dir = output_dir
      )
      arrow::write_parquet(meta, file.path(output_dir, "metadata.parquet"))
    },
    is_tidied = FALSE,
    is_written = FALSE,
    files_tbl = NULL,
    tools = NULL
  ) # private end
)

# Does an R6 class inherit from Tool anywhere in its ancestry?
# `cls$inherit` is a symbol, resolved in `cls$parent_env` (the defining
# namespace) so this works when nemo is imported but not attached.
wf_is_tool_subclass <- function(cls) {
  parent <- cls$inherit
  env <- cls$parent_env
  while (!is.null(parent)) {
    parent_cls <- tryCatch(
      get(as.character(parent), envir = env, inherits = TRUE),
      error = function(e) NULL
    )
    if (is.null(parent_cls)) {
      return(FALSE)
    }
    if (identical(parent_cls$classname, "Tool")) {
      return(TRUE)
    }
    env <- parent_cls$parent_env
    parent <- parent_cls$inherit
  }
  FALSE
}
