#' @title Tool Object
#'
#' @description
#' Base R6 class for all nemo tools. Subclasses implement parsers for specific
#' bioinformatic tool outputs by optionally overriding `parse_{table_name}()` and
#' `tidy_{table_name}()` methods for custom parse or tidy logic per table.
#'
#' A Tool object:
#' - has a name (`name`);
#' - has a path to a directory with its outputs (`path`);
#' - has a schema configuration `Config` object (`config`);
#' - has a tibble of files matching its `Config` patterns (`files`);
#' - has a tibble with the parsed and tidied files (`tbls`);
#'
#' The typical workflow is: optionally filter files with `filter_files()`, parse
#' and tidy with `tidy()`, then write outputs with `write()`. `run()` chains
#' all three steps.
#'
#' @examples
#' fs::path(tempdir(), letters[1:5]) |>
#'   fs::file_temp_push() |>
#'   fs::dir_create()
#' name <- "tool1"; pkg <- "nemo";
#' path <- system.file("extdata/tool1", package = "nemo")
#' toolA <- Tool$new(name = name, pkg = pkg, path = path)
#' toolA$list_files()
#' toolA$filter_files(exclude = "tool1_table3"); toolA$list_files() # note the exclusion this time
#'
#' toolB <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(include = "tool1_table1")
#' toolB$list_files()
#' # tidy + write
#' toolC <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(exclude = "tool1_table5")$
#'   tidy()
#' toolC$list_files()
#' toolC$get_tbls() # note the tidy column
#' dir1 <- fs::file_temp(); dir2 <- fs::file_temp()
#' toolC$write(output_dir = dir1, format = "parquet", input_id = "run1")
#' (lfC <- list.files(dir1, full.names = TRUE))
#'
#' # run
#' toolD <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(exclude = "tool1_table5")$
#'   run(output_dir = dir2, format = "parquet", input_id = "run2")
#' (lfD <- list.files(dir2, full.names = TRUE))
#'
#'
#' @testexamples
#' # filter_files: table3 excluded, other parsers present
#' expect_false("tool1_table3" %in% toolA$list_files()$tool_parser)
#' expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% toolA$list_files()$tool_parser))
#' expect_equal(unique(toolB$list_files()$tool_parser), "tool1_table1")
#' # toolC: table5 excluded, table3 retained
#' expect_false("tool1_table5" %in% toolC$list_files()$tool_parser)
#' expect_true("tool1_table3" %in% toolC$list_files()$tool_parser)
#' expect_error(
#'   toolB$filter_files(include = "tool1_table1", exclude = "tool1_table3"),
#'   "You cannot define both include and exclude"
#' )
#' # initialize: non-scalar name/pkg
#' expect_error(Tool$new(name = c("a", "b"), pkg = pkg, path = path))
#' expect_error(Tool$new(name = name, pkg = c("nemo", "nemo"), path = path))
#' # filter_files: unknown parsers
#' expect_error(
#'   Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_nonexistent"),
#'   "unknown tool_parser"
#' )
#' expect_error(
#'   Tool$new(name = name, pkg = pkg, path = path)$filter_files(exclude = "tool1_nonexistent"),
#'   "unknown tool_parser"
#' )
#' # write: invalid format
#' expect_error(toolC$write(output_dir = tempdir(), format = "invalid"), "Output format")
#' # tidy: structure and column names
#' expect_false(is.null(toolC$get_tbls()))
#' expect_named(
#'   toolC$get_tbls(),
#'   c(
#'     "tool_parser", "parser", "bname", "size", "lastmodified", "path",
#'     "pattern", "prefix", "prefix_suffix", "tidy"
#'   )
#' )
#' # table4: two versions parsed with correct column counts
#' t4 <- toolC$get_tbls() |> dplyr::filter(tool_parser == "tool1_table4")
#' expect_equal(nrow(t4), 2)
#' t4_ncols <- purrr::map_int(t4$tidy, \(x) ncol(x$data[[1]]))
#' expect_setequal(t4_ncols, c(3L, 5L))
#' # write: two table4 output files (one per version)
#' expect_equal(sum(grepl("table4", lfC)), 2)
#' # write: metadata_tool1.parquet written for standalone Tool
#' meta_c <- arrow::read_parquet(file.path(dir1, "metadata_tool1.parquet"))
#' expect_named(meta_c, c("input_id", "output_id", "input_dirs", "output_dir", "pkg_versions", "files"))
#' expect_equal(meta_c$input_id, "run1")
#' expect_named(toolD$written_files, c("raw_path", "tool_parser", "prefix", "tbl_name", "outpath"))
#' # input_id / output_id / prefix_include column tests
#' make_toolE <- function() {
#'   Tool$new(name = name, pkg = pkg, path = path)$
#'     filter_files(include = "tool1_table1")$tidy()
#' }
#' read_pq <- function(d) {
#'   fs <- list.files(d, pattern = "[.]parquet$", full.names = TRUE)
#'   arrow::read_parquet(fs[!grepl("^metadata_", basename(fs))][1])
#' }
#' dE0 <- fs::file_temp(); make_toolE()$write(output_dir = dE0, format = "parquet")
#' dEi <- fs::file_temp(); make_toolE()$write(output_dir = dEi, format = "parquet", input_id = "run1")
#' dEo <- fs::file_temp(); make_toolE()$write(output_dir = dEo, format = "parquet", output_id = "out1")
#' dEp <- fs::file_temp(); make_toolE()$write(output_dir = dEp, format = "parquet", prefix_include = TRUE)
#' dEa <- fs::file_temp(); make_toolE()$write(output_dir = dEa, format = "parquet", input_id = "run1", output_id = "out1", prefix_include = TRUE)
#' expect_false(any(c("input_id", "output_id", "input_prefix") %in% names(read_pq(dE0))))
#' expect_equal(read_pq(dEi)$input_id[1], "run1")
#' expect_equal(read_pq(dEo)$output_id[1], "out1")
#' expect_true("input_prefix" %in% names(read_pq(dEp)))
#' expect_equal(names(read_pq(dEa))[1:3], c("input_id", "input_prefix", "output_id"))
#'
#' @export
Tool <- R6::R6Class(
  "Tool",
  cloneable = FALSE,
  private = list(
    is_tidied = FALSE,
    is_written = FALSE,
    files = NULL,
    tbls = NULL,
    files_tbl = NULL,
    # Typed empty tibble for compute_files; kept as a method so the column spec
    # is in one place and easy to update if the schema changes.
    empty_files_tbl = function() {
      tibble::tibble(
        tool_parser = character(),
        parser = character(),
        bname = character(),
        size = fs::fs_bytes(),
        lastmodified = as.POSIXct(character()),
        path = character(),
        pattern = character(),
        prefix = character(),
        prefix_suffix = character()
      )
    },
    compute_files = function() {
      files_tbl <- private$files_tbl
      patterns <- self$config$get_patterns() |>
        dplyr::rename(pat_name = "name", pat_value = "pattern")
      files <- files_tbl %||% list_files_dir(self$path)
      res <- purrr::map(seq_len(nrow(patterns)), \(i) {
        pat_value <- patterns$pat_value[[i]]
        idx <- grepl(pat_value, files$bname, perl = TRUE)
        if (!any(idx)) {
          return(NULL)
        }
        files[idx, ] |>
          dplyr::mutate(parser = patterns$pat_name[[i]], pattern = pat_value)
      }) |>
        dplyr::bind_rows()
      if (nrow(res) == 0) {
        return(private$empty_files_tbl())
      }
      res <- res |>
        dplyr::select("parser", "bname", "size", "lastmodified", "path", "pattern")
      res |>
        dplyr::mutate(
          prefix = stringr::str_remove(.data$bname, .data$pattern),
          prefix = dplyr::if_else(.data$prefix == "", .data$parser, .data$prefix),
          tool_parser = paste0(self$name, "_", .data$parser)
        ) |>
        dplyr::mutate(prefix_suffix = dplyr::row_number(), .by = "bname") |>
        dplyr::mutate(
          prefix_suffix = dplyr::if_else(
            .data$prefix_suffix == 1,
            "",
            paste0("_", .data$prefix_suffix)
          ),
          prefix = paste0(.data$prefix, .data$prefix_suffix)
        ) |>
        # two files with different basenames can reduce to the same prefix when
        # matched by different patterns for the same table (e.g. *.flagstat and
        # *.flag_counts.tsv both stripping to "sample1"). Append _2, _3, ... to
        # disambiguate so outputs don't overwrite each other.
        dplyr::mutate(grp2 = dplyr::row_number(), .by = c("tool_parser", "prefix")) |>
        dplyr::mutate(
          prefix = dplyr::if_else(
            .data$grp2 == 1,
            .data$prefix,
            paste0(.data$prefix, "_", .data$grp2)
          )
        ) |>
        dplyr::select(-"grp2") |>
        dplyr::relocate("tool_parser", .before = 1)
    },
    prepend_id_cols = function(d, tidy_name, prefix, input_id, output_id, prefix_include) {
      new_cols <- c(
        if (!is.null(input_id)) list(input_id = as.character(input_id)),
        if (prefix_include) list(input_prefix = as.character(prefix)),
        if (!is.null(output_id)) list(output_id = as.character(output_id))
      )
      if (length(new_cols) == 0) {
        return(d)
      }
      conflicts <- intersect(names(new_cols), names(d))
      if (length(conflicts) > 0) {
        nemo_stop(glue(
          "Tidy table '{tidy_name}' already contains reserved column(s): ",
          "{glue::glue_collapse(conflicts, sep = ', ')}."
        ))
      }
      dplyr::relocate(
        dplyr::mutate(d, !!!new_cols),
        dplyr::all_of(names(new_cols)),
        .before = 1
      )
    },
    # Dispatch parse for a table: calls custom parse_{table_name}() if defined
    # in the subclass, otherwise falls back to parse_by_ftype().
    dispatch_parse = function(x, table_name) {
      fun <- glue("parse_{table_name}")
      if (is.function(self[[fun]])) {
        self[[fun]](x)
      } else {
        private$parse_by_ftype(x, table_name)
      }
    },
    # Dispatch tidy for a table: calls custom tidy_{table_name}() if defined
    # in the subclass, otherwise falls back to tidy_file().
    # x may be a file path (character) or an already-parsed tibble — dispatch
    # is called with a path when keep_raw = FALSE (the default) and with a tibble
    # when keep_raw = TRUE. Both tidy_file() and any custom tidy_{name}() in a
    # subclass must handle both forms by checking is_tibble(x) before parsing.
    dispatch_tidy = function(x, table_name) {
      fun <- glue("tidy_{table_name}")
      if (is.function(self[[fun]])) {
        self[[fun]](x)
      } else {
        private$tidy_file(x, table_name)
      }
    },
    # Parse a file by looking up its ftype from the config.
    parse_by_ftype = function(x, table_name) {
      ftype <- self$config$get_ftype(table_name)
      switch(
        ftype,
        "txt" = private$parse_file(x, table_name),
        "csv" = private$parse_file(x, table_name, delim = ","),
        "txt-nohead" = private$parse_file_nohead(x, table_name),
        "txt-keyvalue" = private$parse_file_keyvalue(x, table_name),
        nemo_stop(glue(
          "No default parser for ftype '{ftype}' (table '{table_name}'). ",
          "Define parse_{table_name}() in the subclass."
        ))
      )
    },
    # Parse a delimited file using the raw schema for column types.
    parse_file = function(x, table_name, delim = "\t", ...) {
      parse_file(
        fpath = x,
        pname = table_name,
        schemas_all = self$config$get_schemas_raw(),
        delim = delim,
        ...
      )
    },
    # Tidy a file or already-parsed tibble: renames columns via the tidy schema.
    tidy_file = function(x, table_name, convert_types = FALSE) {
      if (!tibble::is_tibble(x)) {
        x <- private$dispatch_parse(x, table_name)
      }
      version <- get_tbl_version_attr(x)
      schema <- self$config$get_schema_tidy(table_name, version = version)
      if (ncol(x) != nrow(schema)) {
        nemo_stop(glue(
          "tidy_file: column count mismatch for '{table_name}' (version '{version}'): ",
          "parsed data has {ncol(x)} column(s) but schema defines {nrow(schema)}."
        ))
      }
      colnames(x) <- schema[["field"]]
      if (convert_types) {
        ctypes <- schema |>
          dplyr::select("field", "type") |>
          tibble::deframe()
        x <- readr::type_convert(
          x,
          col_types = rlang::exec(readr::cols, !!!ctypes)
        )
      }
      list(x) |>
        rlang::set_names(table_name) |>
        nemo_enframe()
    },
    # Parse a key-value file (no header, 2 cols) and pivot wide.
    parse_file_keyvalue = function(x, table_name, delim = "\t", ...) {
      parse_file_keyvalue(
        fpath = x,
        pname = table_name,
        schemas_all = self$config$get_schemas_raw(),
        delim = delim,
        ...
      )
    },
    # Parse a headless file; version is selected by column count.
    parse_file_nohead = function(x, table_name, delim = "\t", ...) {
      parse_file_nohead(
        fpath = x,
        pname = table_name,
        schemas_all = self$config$get_schemas_raw(),
        delim = delim,
        ...
      )
    }
  ),
  public = list(
    #' @field name (`character(1)`)\cr
    #' Name of tool.
    name = NULL,
    #' @field pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    pkg = NULL,
    #' @field path (`character(1)`)\cr
    #' Output directory of tool.
    path = NULL,
    #' @field config (`Config()`)\cr
    #' Config of tool.
    config = NULL,
    #' @field written_files (`tibble()`)\cr
    #' Tibble of files written from `self$write()`.
    written_files = NULL,
    #' @description Create a new Tool object.
    #' @param name (`character(1)`)\cr
    #' Name of tool.
    #' @param pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [list_files_dir()].
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(name, pkg, path = NULL, files_tbl = NULL) {
      if (is.null(path) && is.null(files_tbl)) {
        nemo_stop("Supply either 'path' or 'files_tbl'.")
      }
      if (!is.null(path) && !is.null(files_tbl)) {
        nemo_stop("Supply 'path' or 'files_tbl', not both.")
      }
      nemo_assert_scalar_chr(name)
      nemo_assert_scalar_chr(pkg)
      if (!is.null(files_tbl)) {
        assert_files_tbl(files_tbl)
      } else if (!dir.exists(path)) {
        nemo_stop(glue("Path does not exist: {path}"))
      }
      self$name <- name
      self$pkg <- pkg
      self$path <- if (!is.null(path)) normalizePath(path) else NULL
      self$config <- Config$new(self$name, pkg = self$pkg)
      private$files_tbl <- files_tbl
      private$files <- private$compute_files()
    },
    #' @description Print details about the Tool.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var      , ~value                                    ,
        "name"    , self$name                                 ,
        "path"    , self$path %||% "<ignored>"                ,
        "files"   , as.character(nrow(private$files))         ,
        "tidied"  , tolower(as.character(private$is_tidied))  ,
        "written" , tolower(as.character(private$is_written))
      )
      cat(glue("#--- Tool {self$pkg}::{self$name} ---#\n"))
      print(knitr::kable(res))
      invisible(self)
    },
    #' @description List files matching this tool's patterns.
    #' @return (`tibble()`)\cr
    #' The `files` tibble of matched files. Always a tibble (possibly zero-row),
    #' never `NULL`.
    list_files = function() private$files,
    #' @description Get tidy tibbles after parsing and tidying.
    #' @return (`tibble()` or `NULL`)\cr
    #' The `tbls` tibble, or `NULL` if `tidy()` has not been called or if
    #' `tidy()` found no matching files. When `tidy(keep_raw = TRUE)` was used,
    #' the tibble also contains a `raw` list-column of the unparsed tibbles.
    get_tbls = function() private$tbls,
    #' @description Filter files in given tool directory based on inclusion or
    #' exclusion tool_parser names. The result is reflected in the `files` field.
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table3"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    filter_files = function(include = NULL, exclude = NULL) {
      assert_include_exclude(include, exclude)
      if (private$is_tidied) {
        nemo_stop("Cannot filter files after tidy() has been called.")
      }
      known <- paste0(self$name, "_", self$config$get_patterns()$name)
      if (!is.null(include)) {
        check_unknown_parsers(include, known, "include")
      }
      if (!is.null(exclude)) {
        check_unknown_parsers(exclude, known, "exclude")
      }
      if (nrow(private$files) == 0) {
        return(invisible(self))
      }
      if (!is.null(include)) {
        private$files <- private$files |>
          dplyr::filter(.data$tool_parser %in% include)
      }
      if (!is.null(exclude)) {
        private$files <- private$files |>
          dplyr::filter(!(.data$tool_parser %in% exclude))
      }
      return(invisible(self))
    },
    #' @description Tidy a list of files. The result is reflected in the `tbls` field.
    #' @param keep_raw (`logical(1)`)\cr
    #' Should the raw parsed tibbles be kept in the final output?
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    tidy = function(keep_raw = FALSE) {
      if (private$is_tidied) {
        return(invisible(self))
      }
      if (nrow(private$files) == 0) {
        private$tbls <- NULL
        private$is_tidied <- TRUE
        return(invisible(self))
      }
      if (keep_raw) {
        d <- private$files |>
          dplyr::mutate(
            raw = purrr::map2(.data$path, .data$parser, \(p, t) private$dispatch_parse(p, t)),
            # pass already-parsed raw to dispatch_tidy to avoid re-reading the file
            tidy = purrr::map2(.data$raw, .data$parser, \(r, t) private$dispatch_tidy(r, t))
          )
      } else {
        d <- private$files |>
          dplyr::mutate(
            tidy = purrr::map2(.data$path, .data$parser, \(p, t) private$dispatch_tidy(p, t))
          )
      }
      private$tbls <- d
      private$is_tidied <- TRUE
      return(invisible(self))
    },
    #' @description Write tidy tibbles.
    #' @param output_dir (`character(1)`)\cr
    #' Directory path to output tidy files. Ignored if format is db.
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
    #' If `TRUE` (default), write a `metadata_<tool>.parquet` file alongside
    #' the tidy outputs. Set to `FALSE` when a `Workflow` is orchestrating the
    #' write and will emit its own workflow-level metadata instead.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly. Results stored in `self$written_files`
    #' (`NULL` if no files were found).
    write = function(
      output_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      prefix_include = FALSE,
      dbconn = NULL,
      write_metadata = TRUE
    ) {
      # nemo_assert_out_fmt is also called in Workflow$write() and nemo_osfx(); each layer
      # keeps its own check so callers don't need to worry about ordering.
      nemo_assert_out_fmt(format)
      if (private$is_written) {
        return(invisible(self))
      }
      if (!private$is_tidied) {
        nemo_stop("Did you forget to tidy?")
      }
      if (write_metadata && format != "db" && is.null(self$path)) {
        nemo_stop(
          "Cannot write metadata: Tool was initialised with 'files_tbl' and has no 'path'. ",
          "Set write_metadata = FALSE to suppress metadata writing."
        )
      }
      if (format != "db") {
        if (is.null(output_dir)) {
          nemo_stop("Output directory must be specified when format is not 'db'.")
        }
        output_dir <- normalizePath(output_dir, mustWork = FALSE)
      }
      if (is.null(private$tbls)) {
        self$written_files <- NULL
        private$is_written <- TRUE
        return(invisible(self))
      }
      if (format != "db") {
        fs::dir_create(output_dir)
      }
      # Pure data preparation: unnest, compute names/paths, prepend ID cols
      d_write <- private$tbls |>
        dplyr::rename(raw_path = "path") |>
        dplyr::select("raw_path", "tool_parser", "parser", "prefix", "tidy") |>
        tidyr::unnest("tidy", names_sep = "_") |>
        dplyr::mutate(
          tbl_name = dplyr::if_else(
            .data$parser == .data$tidy_name,
            .data$tool_parser,
            paste(.data$tool_parser, .data$tidy_name, sep = "_")
          ),
          fpfix = paste(file.path(output_dir, .data$prefix), .data$tbl_name, sep = "_"),
          tidy_data = purrr::pmap(
            list(.data$tidy_data, .data$tidy_name, .data$prefix),
            \(d, nm, pfx) private$prepend_id_cols(d, nm, pfx, input_id, output_id, prefix_include)
          )
        )
      # Write files (side effects kept separate from pure prep above)
      outpaths <- purrr::pmap_chr(
        list(d_write$tidy_data, d_write$fpfix, d_write$tbl_name),
        \(d, fp, tn) {
          nemo_write(
            d = d,
            fpfix = fp,
            format = format,
            dbconn = dbconn,
            dbtab = if (format == "db") tn else NULL
          )
        }
      )
      d_write <- d_write |>
        dplyr::mutate(outpath = outpaths) |>
        dplyr::select("raw_path", "tool_parser", "prefix", "tbl_name", "outpath")
      self$written_files <- d_write
      private$is_written <- TRUE
      if (write_metadata && format != "db") {
        meta <- self$get_metadata(
          input_id = input_id,
          output_id = output_id,
          output_dir = output_dir
        )
        arrow::write_parquet(
          meta,
          file.path(output_dir, paste0("metadata_", self$name, ".parquet"))
        )
      }
      return(invisible(self))
    },
    #' @description Get metadata for the tool run.
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
      pkgs <- pkgs %||% self$pkg
      if (!is.null(self$written_files)) {
        files <- meta_files_from_written(self$written_files)
      } else {
        files <- private$files |>
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
    #' If `TRUE` (default), write a `metadata_<tool>.parquet` file alongside
    #' the tidy outputs. Set to `FALSE` to suppress.
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table5"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly. Results stored in `self$written_files`.
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
      # fail-fast before tidy(); write() re-checks but tidy can be slow
      nemo_assert_out_fmt(format)
      # fmt: skip
      self$
        filter_files(include = include, exclude = exclude)$
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
    }
  ) # public end
)
