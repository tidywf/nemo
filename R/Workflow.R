#' @title Workflow Object
#'
#' @description
#' Orchestrates multiple `Tool` objects over a shared directory, handling file
#' discovery, filtering, tidying, and writing in a single pipeline.
#'
#' A Workflow object:
#' - has a name (`name`);
#' - has one or more paths to workflow results (`path`);
#' - has a list of `Tool` subclass objects (`tools`);
#' - has a tibble of all files in the shared directory (`files_tbl`);
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
#' wf$filter_files(exclude = "tool1_table5")
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
#' @testexamples
#' # list_files
#' nms1 <- c(
#'   "tool", "tool_parser", "parser", "bname", "size", "lastmodified", "path",
#'   "pattern", "prefix", "group"
#' )
#' expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% lf_all$tool_parser))
#' expect_named(lf_all, nms1)
#' # filter_files + tidy + get_tbls: table5 excluded, table4 retained
#' expect_false("tool1_table5" %in% tbls$tool_parser)
#' expect_true("tool1_table4" %in% tbls$tool_parser)
#' expect_named(tbls, c(nms1, "tidy"))
#' # get_schemas_raw
#' expect_named(rs, c("tool", "name", "tbl_description", "version", "schema"))
#' # write: two table4 output files (one per version)
#' expect_equal(sum(grepl("table4", basename(lf1))), 2)
#' expect_named(
#'   wf$written_files, c("raw_path", "tool_parser", "prefix", "tbl_name", "outpath")
#' )
#' # get_metadata
#' expect_named(meta, c("input_id", "output_id", "input_dirs", "output_dir", "pkg_versions", "files"))
#' # wrangle: all parsers written
#' expect_true(all(c("tool1_table1", "tool1_table4") %in% sub(".*_(tool1_table\\d).*", "\\1", basename(lf2))))
#'
#' @export
Workflow <- R6::R6Class(
  "Workflow",
  public = list(
    #' @field name (`character(1)`)\cr
    #' Name of workflow.
    name = NULL,
    #' @field path (`character(n)`)\cr
    #' Path(s) to workflow results.
    path = NULL,
    #' @field tools (`list(n)`)\cr
    #' List of Tools that compose a Workflow.
    tools = NULL,
    #' @field metapkg (`character(n)`)\cr
    #' Package name(s) used for metadata version reporting.
    metapkg = NULL,
    #' @field written_files (`tibble(n)`)\cr
    #' Tibble of files written from `self$write()`.
    written_files = NULL,

    #' @description Create a new Workflow object.
    #' @param name (`character(1)`)\cr
    #' Name of workflow.
    #' @param path (`character(n)`)\cr
    #' Path(s) to workflow results.
    #' @param tools (`list(n)`)\cr
    #' List of Tools that compose a Workflow.
    #' @param metapkg (`character(n)`)\cr
    #' Package name(s) used for metadata version reporting.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(name, path, tools, metapkg = "nemo") {
      nemo_assert_scalar_chr(name)
      nemo_assert_chr(metapkg)
      nemo_assert_chr(path)
      assertthat::assert_that(
        all(dir.exists(path)),
        msg = glue(
          "Path(s) do not exist: {glue::glue_collapse(path[!dir.exists(path)], sep = ', ')}."
        )
      )
      self$name <- name
      self$metapkg <- metapkg
      private$validate_tools(tools)
      self$path <- normalizePath(path)
      private$files_tbl <- list_files_dir(self$path)
      self$tools <- tools |>
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
        "ntools"        , as.character(length(self$tools))           ,
        "files_total"   , as.character(nrow(private$files_tbl))      ,
        "files_matched" , as.character(nrow(self$list_files()))      ,
        "tidied"        , tolower(as.character(private$is_tidied))   ,
        "written"       , tolower(as.character(private$is_written))
      )
      cat(glue("#--- Workflow {self$name} ---#\n"))
      print(knitr::kable(res))
      invisible(self)
    },
    #' @description Filter files in given workflow directory.
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table5"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    filter_files = function(include = NULL, exclude = NULL) {
      assert_include_exclude(include, exclude)
      assertthat::assert_that(
        !private$is_tidied,
        msg = "Cannot filter files after tidy() has been called."
      )
      all_parsers <- purrr::map(self$tools, \(x) x$files$tool_parser) |>
        unlist() |>
        unique()
      if (length(all_parsers) == 0) {
        known <- purrr::map(self$tools, \(x) paste0(x$name, "_", x$config$get_patterns()$name)) |>
          unlist() |>
          unique()
        if (!is.null(include)) {
          check_unknown_parsers(include, known, "include")
        }
        if (!is.null(exclude)) {
          check_unknown_parsers(exclude, known, "exclude")
        }
        return(invisible(self))
      }
      if (!is.null(include)) {
        check_unknown_parsers(include, all_parsers, "include")
      }
      if (!is.null(exclude)) {
        check_unknown_parsers(exclude, all_parsers, "exclude")
      }
      purrr::walk(self$tools, \(x) {
        known <- unique(x$files$tool_parser)
        tool_include <- if (!is.null(include)) include[include %in% known] else NULL
        tool_exclude <- if (!is.null(exclude)) exclude[exclude %in% known] else NULL
        if (!is.null(tool_include) || !is.null(tool_exclude)) {
          x$filter_files(include = tool_include, exclude = tool_exclude)
        }
      })
      invisible(self)
    },
    #' @description List only files of interest in given workflow directory, i.e.
    #' only those files that match the patterns listed in the individual tool
    #' config.
    #' @return (`tibble()`)\cr
    #' Bound `files` tibbles from all Tools, with a leading `tool` column.
    list_files = function() private$gather_tool_field("files"),
    #' @description Tidy Workflow files.
    #' @param keep_raw (`logical(1)`)\cr
    #' Should the raw parsed tibbles be kept in the final output?
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    tidy = function(keep_raw = FALSE) {
      if (private$is_tidied) {
        return(invisible(self))
      }
      purrr::walk(self$tools, \(x) x$tidy(keep_raw = keep_raw))
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
      valid_out_fmt(format) # early failsafe; Tool$write() repeats this per-tool
      assertthat::assert_that(private$is_tidied, msg = "Did you forget to tidy?")
      if (format != "db") {
        # normalise once here so all tools receive a canonical path; Tool$write()
        # repeats the normalisation but that is idempotent.
        output_dir <- normalizePath(output_dir, mustWork = FALSE)
      }
      res <- self$tools |>
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
      private$is_written <- has_output
      if (write_metadata && format != "db" && has_output) {
        meta <- self$get_metadata(
          input_id = input_id,
          output_id = output_id,
          output_dir = output_dir
        )
        arrow::write_parquet(meta, file.path(output_dir, "metadata.parquet"))
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
    #' tool_parser names to exclude (e.g. `"tool1_table5"`).
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
      # fmt: skip
      self$filter_files(include = include, exclude = exclude)$
        tidy()$
        write(
          output_dir = output_dir,
          format = format,
          input_id = input_id,
          output_id = output_id,
          prefix_include = prefix_include,
          dbconn = dbconn,
          write_metadata = write_metadata
      )
    },
    #' @description Get raw schemas for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound `schemas_raw` tibbles from all Tools, with a leading `tool` column.
    get_schemas_raw = function() private$gather_tool_schemas("get_schemas_raw"),
    #' @description Get tidy schemas for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound tidy schema tibbles from all Tools, with a leading `tool` column.
    get_schemas_tidy = function() private$gather_tool_schemas("get_schemas_tidy"),
    #' @description Get tidy tibbles for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound `tbls` tibbles from all Tools, with a leading `tool` column.
    get_tbls = function() private$gather_tool_field("tbls"),
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
    is_tool_subclass = function(cls) {
      # cls$inherit stores a symbol (the parent class name), not the class object
      # itself — get() is required to resolve it. We start from parent.env(.GlobalEnv)
      # so a user variable named "Tool" in .GlobalEnv cannot shadow the real class.
      # Do not attempt to traverse $inherit directly without resolving via get().
      parent <- cls$inherit
      while (!is.null(parent)) {
        parent_cls <- tryCatch(
          get(as.character(parent), envir = parent.env(.GlobalEnv), inherits = TRUE),
          error = function(e) NULL
        )
        if (is.null(parent_cls)) {
          return(FALSE)
        }
        if (identical(parent_cls$classname, "Tool")) {
          return(TRUE)
        }
        parent <- parent_cls$inherit
      }
      FALSE
    },
    validate_tools = function(x) {
      assertthat::assert_that(rlang::is_bare_list(x), msg = "`tools` must be a list.")
      assertthat::assert_that(length(x) > 0, msg = "`tools` must not be empty.")
      assertthat::assert_that(
        !is.null(names(x)) && !any(names(x) == ""),
        msg = "`tools` must be a named list."
      )
      assertthat::assert_that(
        all(purrr::map_lgl(x, R6::is.R6Class)),
        msg = "All elements of `tools` must be R6 classes."
      )
      assertthat::assert_that(
        all(purrr::map_lgl(x, private$is_tool_subclass)),
        msg = "All elements of `tools` must inherit from Tool."
      )
    },
    gather_tool_field = function(field) {
      self$tools |>
        purrr::map(\(x) {
          val <- x[[field]]
          if (is.null(val)) {
            return(NULL)
          }
          val |> dplyr::mutate(tool = x$name, .before = 1)
        }) |>
        purrr::compact() |>
        dplyr::bind_rows()
    },
    gather_tool_schemas = function(method_name) {
      self$tools |>
        purrr::map(\(x) {
          x$config[[method_name]]() |>
            dplyr::mutate(tool = x$name, .before = 1)
        }) |>
        dplyr::bind_rows()
    },
    is_tidied = FALSE,
    is_written = FALSE,
    files_tbl = NULL
  ) # private end
)
