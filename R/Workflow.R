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
#' `tidy()`, then write with `write()`. `nemofy()` chains all three steps.
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
#' (rs <- wf$get_raw_schemas_all())
#' dir1 <- fs::file_temp(); dir2 <- fs::file_temp()
#' wf$write(diro = dir1, format = "parquet", input_id = "run1")
#' (lf1 <- list.files(dir1, pattern = "tool1.*parquet", full.names = TRUE))
#' (meta <- wf$get_metadata(input_id = "run1", output_id = "out1", output_dir = dir1))
#' wf2 <- Workflow$new(name = "wf2", path = path, tools = tools)
#' wf2$nemofy(diro = dir2, format = "parquet", input_id = "run2")
#' (lf2 <- list.files(dir2, pattern = "tool1.*parquet", full.names = TRUE))
#' @testexamples
#' # list_files
#' nms1 <- c(
#'   "tool_parser", "parser", "bname", "size", "lastmodified", "path",
#'   "pattern", "prefix", "group"
#' )
#' expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% lf_all$tool_parser))
#' expect_named(lf_all, nms1)
#' # filter_files + tidy + get_tbls: table5 excluded, table4 retained
#' expect_false("tool1_table5" %in% tbls$tool_parser)
#' expect_true("tool1_table4" %in% tbls$tool_parser)
#' expect_named(tbls, c(nms1, "tidy"))
#' # get_raw_schemas_all
#' expect_named(rs, c("tool", "name", "tbl_description", "version", "schema"))
#' # write: two table4 output files (one per version)
#' expect_equal(sum(grepl("table4", basename(lf1))), 2)
#' expect_named(wf$written_files, c("tool_parser", "prefix", "tidy_data", "tbl_name", "outpath"))
#' # get_metadata
#' expect_named(meta, c("input_id", "output_id", "input_dir", "output_dir", "pkg_versions", "files"))
#' # nemofy: all parsers written
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
    #' @field files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [list_files_dir()].
    files_tbl = NULL,
    #' @field metapkg (`character(1)`)\cr
    #' Package name used for metadata version reporting.
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
    #' @param metapkg (`character(1)`)\cr
    #' Package name used for metadata version reporting.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(name = NULL, path = NULL, tools = NULL, metapkg = "nemo") {
      self$name <- name
      self$metapkg <- metapkg
      private$validate_tools(tools)
      private$is_tidied <- FALSE
      private$is_written <- FALSE
      self$path <- normalizePath(path)
      self$files_tbl <- list_files_dir(self$path)
      # handle everything in a list of Tools
      self$tools <- tools |>
        purrr::map(\(x) x$new(files_tbl = self$files_tbl))
    },
    #' @description Print details about the Workflow.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var         , ~value                                     ,
        "name"       , self$name                                  ,
        "path"       , glue::glue_collapse(self$path, sep = ", ") ,
        "ntools"     , as.character(length(self$tools))           ,
        "nfiles_tot" , as.character(nrow(self$files_tbl))         ,
        "nfiles_pat" , as.character(nrow(self$list_files()))      ,
        "tidied"     , tolower(as.character(private$is_tidied))   ,
        "written"    , tolower(as.character(private$is_written))
      )
      cat("#--- Workflow ---#\n")
      print(res)
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
      self$tools <- self$tools |>
        purrr::map(\(x) x$filter_files(include = include, exclude = exclude))
      invisible(self)
    },
    #' @description List only files of interest in given workflow directory, i.e.
    #' only those files that match the patterns listed in the individual tool
    #' config.
    #' @param type (`character(1)`)\cr
    #' File types(s) to return (e.g. any, file, directory, symlink).
    #' See `fs::dir_info`.
    #' @return (`tibble()`)\cr
    #' Bound `list_files()` tibbles from all Tools.
    list_files = function(type = c("file", "symlink")) {
      self$tools |>
        purrr::map(\(x) x$list_files(type = type)) |>
        dplyr::bind_rows()
    },
    #' @description Tidy Workflow files.
    #' @param tidy (`logical(1)`)\cr
    #' Should the raw parsed tibbles get tidied?
    #' @param keep_raw (`logical(1)`)\cr
    #' Should the raw parsed tibbles be kept in the final output?
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    tidy = function(tidy = TRUE, keep_raw = FALSE) {
      # if no tidying needed, early return
      if (private$is_tidied) {
        return(invisible(self))
      }
      self$tools <- self$tools |>
        purrr::map(\(x) x$tidy(tidy = tidy, keep_raw = keep_raw))
      private$is_tidied <- TRUE
      return(invisible(self))
    },
    #' @description Write tidy tibbles.
    #' @param diro (`character(1)`)\cr
    #' Directory path to output tidy files.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    write = function(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      dbconn = NULL
    ) {
      res <- self$tools |>
        purrr::map(\(x) {
          x$write(
            diro = diro,
            format = format,
            input_id = input_id,
            output_id = output_id,
            dbconn = dbconn
          )
        }) |>
        dplyr::bind_rows()
      private$is_written <- TRUE
      self$written_files <- res
      # Write metadata
      if (format != "db" && !is.null(res)) {
        diro <- normalizePath(diro)
        meta_diro <- file.path(diro, "_metadata") |> fs::dir_create()
        meta <- self$get_metadata(input_id = input_id, output_id = output_id, output_dir = diro)
        jsonlite::write_json(meta, file.path(meta_diro, "metadata.json"), pretty = TRUE)
      }
      return(invisible(self))
    },
    #' @description Parse, filter, tidy and write files.
    #' @param diro (`character(1)`)\cr
    #' Directory path to output tidy files.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table5"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    nemofy = function(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      dbconn = NULL,
      include = NULL,
      exclude = NULL
    ) {
      # fmt: skip
      self$filter_files(include = include, exclude = exclude)$
        tidy()$
        write(
          diro = diro,
          format = format,
          input_id = input_id,
          output_id = output_id,
          dbconn = dbconn
      )
    },
    #' @description Get raw schemas for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound `raw_schemas_all` tibbles from all Tools, with a leading `tool` column.
    get_raw_schemas_all = function() {
      self$tools |>
        purrr::map(\(x) {
          x$raw_schemas_all |>
            dplyr::mutate(tool = x$name) |>
            dplyr::relocate("tool", .before = 1)
        }) |>
        dplyr::bind_rows()
    },
    #' @description Get tidy schemas for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound tidy schema tibbles from all Tools, with a leading `tool` column.
    get_tidy_schemas_all = function() {
      self$tools |>
        purrr::map(\(x) {
          x$tidy_schemas_all |>
            dplyr::mutate(tool = x$name) |>
            dplyr::relocate("tool", .before = 1)
        }) |>
        dplyr::bind_rows()
    },
    #' @description Get tidy tibbles for all Tools.
    #' @return (`tibble()`)\cr
    #' Bound `tbls` tibbles from all Tools.
    get_tbls = function() {
      self$tools |>
        purrr::map(\(x) x$tbls) |>
        dplyr::bind_rows()
    },
    #' @description Get metadata for the workflow run.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param output_dir (`character(1)`)\cr
    #' Output directory.
    #' @param pkgs (`character(n)`)\cr
    #' Which R packages to extract versions for.
    #' @return (`list()`)\cr
    #' List with `input_id`, `output_id`, `input_dir`, `output_dir`,
    #' `pkg_versions`, and `files`.
    get_metadata = function(input_id, output_id, output_dir, pkgs = NULL) {
      if (is.null(pkgs)) {
        pkgs <- self$metapkg
      }
      files <- NULL
      if (private$is_written) {
        # just keep bname and provide diro, no need for full outpath since
        # it's a flat output structure.
        files <- self$written_files |>
          dplyr::mutate(outpath = basename(.data$outpath)) |>
          dplyr::select(tbl = "tbl_name", "prefix", fout = "outpath", fin = "raw_path")
      } else {
        # just select raw path and size
        files <- self$files_tbl |>
          dplyr::select(fin = "path", "size")
      }
      meta <- nemo_metadata(
        files = files,
        pkgs = pkgs,
        input_id = input_id,
        output_id = output_id,
        input_dir = self$path,
        output_dir = output_dir
      )
      return(meta)
    }
  ), # public end
  private = list(
    validate_tools = function(x) {
      stopifnot(rlang::is_bare_list(x))
      stopifnot(all(purrr::map_lgl(x, R6::is.R6Class)))
      tool_nms <- purrr::map_chr(x, "classname") |> tolower()
      stopifnot(!is.null(tool_nms))
      stopifnot(all(purrr::map(x, "inherit") == as.symbol("Tool")))
    },
    # Do files need to be tidied? Used when no files are detected, so we can
    # use downstream as a bypass.
    is_tidied = NULL,
    is_written = NULL
  ) # private end
)
