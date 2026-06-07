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
#' and tidy with `tidy()`, then write outputs with `write()`. `wrangle()` chains
#' all three steps.
#'
#' @examples
#' fs::path(tempdir(), letters[1:5]) |>
#'   fs::file_temp_push() |>
#'   fs::dir_create()
#' name <- "tool1"; pkg <- "nemo";
#' path <- system.file("extdata/tool1", package = "nemo")
#' toolA <- Tool$new(name = name, pkg = pkg, path = path)
#' toolA$files
#' toolA$filter_files(exclude = "tool1_table3"); toolA$files # note the exclusion this time
#' toolA$list_files()
#'
#' toolB <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(include = "tool1_table1")
#' toolB$files
#' # tidy + write
#' toolC <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(exclude = "tool1_table5")$
#'   tidy()
#' toolC$files
#' toolC$tbls # note the tidy column
#' dir1 <- fs::file_temp(); dir2 <- fs::file_temp()
#' toolC$write(output_dir = dir1, format = "parquet", input_id = "run1")
#' (lfC <- list.files(dir1, full.names = TRUE))
#'
#' # wrangle
#' toolD <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(exclude = "tool1_table5")$
#'   wrangle(output_dir = dir2, format = "parquet", input_id = "run2")
#' (lfD <- list.files(dir2, full.names = TRUE))
#'
#'
#' @testexamples
#' # filter_files: table3 excluded, other parsers present
#' expect_false("tool1_table3" %in% toolA$files$tool_parser)
#' expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% toolA$files$tool_parser))
#' expect_equal(unique(toolB$files$tool_parser), "tool1_table1")
#' # toolC: table5 excluded, table3 retained
#' expect_false("tool1_table5" %in% toolC$files$tool_parser)
#' expect_true("tool1_table3" %in% toolC$files$tool_parser)
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
#' expect_error(toolC$write(output_dir = tempdir(), format = "invalid"), "Invalid format")
#' # tidy: structure and column names
#' expect_false(is.null(toolC$tbls))
#' expect_named(
#'   toolC$tbls,
#'   c(
#'     "tool_parser", "parser", "bname", "size", "lastmodified", "path",
#'     "pattern", "prefix", "group", "tidy"
#'   )
#' )
#' # table4: two versions parsed with correct column counts
#' t4 <- toolC$tbls |> dplyr::filter(tool_parser == "tool1_table4")
#' expect_equal(nrow(t4), 2)
#' t4_ncols <- purrr::map_int(t4$tidy, \(x) ncol(x$data[[1]]))
#' expect_setequal(t4_ncols, c(3L, 5L))
#' # write: two table4 output files (one per version)
#' expect_equal(sum(grepl("table4", lfC)), 2)
#' # write: metadata_tool1.parquet written for standalone Tool
#' meta_c <- arrow::read_parquet(file.path(dir1, "metadata_tool1.parquet"))
#' expect_named(meta_c, c("input_id", "output_id", "input_dirs", "output_dir", "pkg_versions", "files"))
#' expect_equal(meta_c$input_id, "run1")
#' expect_named(toolD$written_files, c("raw_path", "tool_parser", "prefix", "tidy_data", "tbl_name", "outpath"))
#' # input_id / output_id / prefix_include column tests
#' toolE <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(include = "tool1_table1")$tidy()
#' read_pq <- function(d) {
#'   fs <- list.files(d, pattern = "[.]parquet$", full.names = TRUE)
#'   arrow::read_parquet(fs[!grepl("^metadata_", basename(fs))][1])
#' }
#' dE0 <- fs::file_temp(); toolE$write(output_dir = dE0, format = "parquet")
#' dEi <- fs::file_temp(); toolE$write(output_dir = dEi, format = "parquet", input_id = "run1")
#' dEo <- fs::file_temp(); toolE$write(output_dir = dEo, format = "parquet", output_id = "out1")
#' dEp <- fs::file_temp(); toolE$write(output_dir = dEp, format = "parquet", prefix_include = TRUE)
#' dEa <- fs::file_temp(); toolE$write(output_dir = dEa, format = "parquet", input_id = "run1", output_id = "out1", prefix_include = TRUE)
#' expect_false(any(c("input_id", "output_id", "input_prefix") %in% names(read_pq(dE0))))
#' expect_equal(read_pq(dEi)$input_id[1], "run1")
#' expect_equal(read_pq(dEo)$output_id[1], "out1")
#' expect_true("input_prefix" %in% names(read_pq(dEp)))
#' expect_equal(names(read_pq(dEa))[1:3], c("input_id", "input_prefix", "output_id"))
#'
#' @export
Tool <- R6::R6Class(
  "Tool",
  private = list(
    # Do files need to be tidied? Used when no files are detected, so we can
    # use downstream as a bypass.
    is_tidied = NULL,
    is_written = NULL,
    files_tbl = NULL
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
    #' @field files (`tibble()`)\cr
    #' Tibble of files matching available Tool patterns.
    files = NULL,
    #' @field tbls (`tibble()`)\cr
    #' Tibble of tidy tibbles.
    tbls = NULL,
    #' @field written_files (`tibble()`)\cr
    #' Tibble of files written from `self$write()`.
    written_files = NULL,
    #' @description Create a new Tool object.
    #' @param name (`character(1)`)\cr
    #' Name of tool.
    #' @param pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this basically gets
    #' ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [list_files_dir()].
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(name = NULL, pkg = NULL, path = NULL, files_tbl = NULL) {
      stopifnot(!is.null(path) || !is.null(files_tbl))
      nemo_assert_scalar_chr(name)
      nemo_assert_scalar_chr(pkg)
      if (!is.null(files_tbl)) {
        stopifnot(is_files_tbl(files_tbl))
        path <- NULL
      }
      self$name <- name
      self$pkg <- pkg
      self$path <- path
      self$config <- Config$new(self$name, pkg = self$pkg)
      private$files_tbl <- files_tbl
      private$is_tidied <- FALSE
      private$is_written <- FALSE
      # upon init, files starts off as the raw list of files
      self$files <- self$list_files(type = "file")
    },
    #' @description Print details about the Tool.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var      , ~value                           ,
        "name"    , self$name                        ,
        "path"    , self$path %||% "<ignored>"       ,
        "files"   , as.character(nrow(self$files))   ,
        "tidied"  , as.character(private$is_tidied)  ,
        "written" , as.character(private$is_written)
      ) |>
        tidyr::unnest("value")
      cat(glue("#--- Tool {self$pkg}::{self$name} ---#"))
      print(knitr::kable(res))
      invisible(self)
    },
    #' @description Filter files in given tool directory based on inclusion or
    #' exclusion tool_parser names. The result is reflected in the `files` field.
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table3"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    filter_files = function(include = NULL, exclude = NULL) {
      assertthat::assert_that(
        is.null(include) || is.null(exclude),
        msg = "You cannot define both include and exclude!"
      )
      if (nrow(self$files) == 0) {
        return(invisible(self))
      }
      if (!is.null(include)) {
        nemo_assert_chr(include)
        unknown <- include[!include %in% self$files$tool_parser]
        assertthat::assert_that(
          length(unknown) == 0,
          msg = glue(
            "filter_files: unknown tool_parser(s) in include: {glue::glue_collapse(unknown, sep = ', ')}."
          )
        )
        self$files <- self$files |>
          dplyr::filter(.data$tool_parser %in% include)
      }
      if (!is.null(exclude)) {
        nemo_assert_chr(exclude)
        unknown <- exclude[!exclude %in% self$files$tool_parser]
        assertthat::assert_that(
          length(unknown) == 0,
          msg = glue(
            "filter_files: unknown tool_parser(s) in exclude: {glue::glue_collapse(unknown, sep = ', ')}."
          )
        )
        self$files <- self$files |>
          dplyr::filter(!(.data$tool_parser %in% exclude))
      }
      return(invisible(self))
    },
    #' @description List only files of interest in given tool directory, i.e.
    #' only those files that match the patterns listed in the tool config.
    #' @param type (`character(1)`)\cr
    #' File type(s) to return (e.g. any, file, directory, symlink).
    #' See `fs::dir_info`.
    #' @return (`tibble()`)\cr
    #' A tibble with:
    #' - `tool_parser`: tool name followed by parser name;
    #' - `parser`: parser name;
    #' - `bname`: file basename;
    #' - `size`: file size;
    #' - `lastmodified`: last modified timestamp of file;
    #' - `path`: file path;
    #' - `pattern`: file pattern;
    #' - `prefix`: file prefix;
    #' - `group`: if multiple files have the same basename then this is used
    #' as a differentiator.
    list_files = function(type = "file") {
      files_tbl <- private$files_tbl
      patterns <- self$config$get_patterns() |>
        dplyr::rename(pat_name = "name", pat_value = "pattern")
      files <- files_tbl %||% list_files_dir(self$path, type = type)
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
        return(
          dplyr::tibble(
            tool_parser = character(),
            parser = character(),
            bname = character(),
            size = fs::fs_bytes(),
            lastmodified = as.POSIXct(character()),
            path = character(),
            pattern = character(),
            prefix = character(),
            group = character()
          )
        )
      }
      res <- res |>
        dplyr::select("parser", "bname", "size", "lastmodified", "path", "pattern")
      res |>
        dplyr::mutate(
          prefix = stringr::str_remove(.data$bname, .data$pattern),
          # handle wigits version files
          prefix = dplyr::if_else(
            .data$parser == "version" & .data$prefix == "",
            "version",
            .data$prefix
          ),
          tool_parser = paste0(self$name, "_", .data$parser)
        ) |>
        dplyr::mutate(group = dplyr::row_number(), .by = "bname") |>
        dplyr::mutate(
          group = dplyr::if_else(.data$group == 1, "", paste0("_", .data$group)),
          prefix = paste0(.data$prefix, .data$group)
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
    #' @description Get specific tidy schema.
    #' @param table_name (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string.
    #' @return (`tibble()`)\cr
    #' Tidy schema tibble.
    get_schema_tidy = function(table_name = NULL, version = NULL) {
      self$config$get_schema_tidy(x = table_name, version = version)
    },
    #' @description Get specific raw schema.
    #' @param table_name (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string.
    #' @return (`tibble()`)\cr
    #' Raw schema tibble.
    get_schema_raw = function(table_name = NULL, version = NULL) {
      self$config$get_schema_raw(x = table_name, version = version)
    },
    #' @description Get column mapping (raw -> tidy) for a table.
    #' @param table_name (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string.
    #' @return (`tibble()`)\cr
    #' Column map tibble with `raw`, `tidy`, `type`, and `description` columns.
    get_col_map = function(table_name = NULL, version = NULL) {
      self$config$get_col_map(x = table_name, version = version)
    },
    #' @description Dispatch parse for a table: calls custom `parse_{table_name}()` if
    #' defined in the subclass, otherwise falls back to `.parse_by_ftype()`.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param table_name (`character(1)`)\cr
    #' Table name.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .dispatch_parse = function(x, table_name) {
      fun <- glue("parse_{table_name}")
      if (is.function(self[[fun]])) {
        self[[fun]](x)
      } else {
        self$.parse_by_ftype(x, table_name)
      }
    },
    #' @description Dispatch tidy for a table: calls custom `tidy_{table_name}()` if
    #' defined in the subclass, otherwise falls back to `.tidy_file()`.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' File path or already parsed raw tibble.
    #' @param table_name (`character(1)`)\cr
    #' Table name.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble.
    .dispatch_tidy = function(x, table_name) {
      fun <- glue("tidy_{table_name}")
      if (is.function(self[[fun]])) {
        self[[fun]](x)
      } else {
        self$.tidy_file(x, table_name)
      }
    },
    #' @description Parse a file by looking up its ftype from the config and
    #' calling the appropriate internal parser. Errors for ftypes that require
    #' a custom `parse_{table_name}()` method (e.g. `csv-nohead-long`).
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param table_name (`character(1)`)\cr
    #' Table name.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_by_ftype = function(x, table_name) {
      ftype <- self$config$get_ftype(table_name)
      switch(
        ftype,
        "txt" = self$.parse_file(x, table_name),
        "csv" = self$.parse_file(x, table_name, delim = ","),
        "txt-nohead" = self$.parse_file_nohead(x, table_name),
        "txt-keyvalue" = self$.parse_file_keyvalue(x, table_name),
        stop(glue(
          "No default parser for ftype '{ftype}' (table '{table_name}'). ",
          "Define parse_{table_name}() in the subclass."
        ))
      )
    },
    #' @description Parse file.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param table_name (`character(1)`)\cr
    #' Table name (e.g. "breakends" - see docs).
    #' @param delim (`character(1)`)\cr
    #' File delimiter.
    #' @param ... Passed on to `readr::read_delim`.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_file = function(x, table_name, delim = "\t", ...) {
      parse_file(
        fpath = x,
        pname = table_name,
        schemas_all = self$config$get_schemas_raw(),
        delim = delim,
        ...
      )
    },
    #' @description Tidy file.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' File path or already parsed raw tibble.
    #' @param table_name (`character(1)`)\cr
    #' Table name (e.g. "breakends" - see docs).
    #' @param convert_types (`logical(1)`)\cr
    #' Convert field types based on schema.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble.
    .tidy_file = function(x, table_name, convert_types = FALSE) {
      if (!tibble::is_tibble(x)) {
        x <- self$.dispatch_parse(x, table_name)
      }
      version <- get_tbl_version_attr(x)
      stopifnot(!is.null(version))
      schema <- self$get_schema_tidy(table_name, version = version)
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
        setNames(table_name) |>
        enframe_data()
    },
    #' @description Parse files with no header and two columns representing
    #' key-value pairs.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param table_name (`character(1)`)\cr
    #' Table name (e.g. "qc" - see docs).
    #' @param delim (`character(1)`)\cr
    #' File delimiter.
    #' @param ... Passed on to `readr::read_delim`.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_file_keyvalue = function(x, table_name, delim = "\t", ...) {
      parse_file_keyvalue(
        fpath = x,
        pname = table_name,
        schemas_all = self$config$get_schemas_raw(),
        delim = delim,
        ...
      )
    },
    #' @description Parse headless file.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param table_name (`character(1)`)\cr
    #' Table name (e.g. "breakends" - see docs).
    #' @param delim (`character(1)`)\cr
    #' File delimiter.
    #' @param ... Passed on to `readr::read_delim`.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_file_nohead = function(x, table_name, delim = "\t", ...) {
      ncols <- file_hdr(x, delim = delim, ...) |> length()
      schema <- self$config$get_schemas_raw() |>
        dplyr::filter(.data$name == table_name) |>
        dplyr::select("version", "schema") |>
        dplyr::rowwise() |>
        dplyr::filter(nrow(.data$schema) == ncols) |>
        dplyr::ungroup()
      if (nrow(schema) != 1) {
        stop(glue(
          "Expected exactly one schema version matching {ncols} columns ",
          "for '{table_name}', found {nrow(schema)}."
        ))
      }
      parse_file_nohead(
        fpath = x,
        schema = schema,
        delim = delim,
        ...
      )
    },
    #' @description Tidy a list of files. The result is reflected in the `tbls` field.
    #' @param do_tidy (`logical(1)`)\cr
    #' Should the raw parsed tibbles get tidied?
    #' @param keep_raw (`logical(1)`)\cr
    #' Should the raw parsed tibbles be kept in the final output?
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    tidy = function(do_tidy = TRUE, keep_raw = FALSE) {
      # if no tidying needed, early return
      if (private$is_tidied) {
        return(invisible(self))
      }
      # if no files found, early return
      if (nrow(self$files) == 0) {
        self$tbls <- NULL
        private$is_tidied <- TRUE
        return(invisible(self))
      }
      # if both FALSE, just return the file list
      if (!do_tidy && !keep_raw) {
        self$tbls <- self$files
        return(invisible(self))
      }
      d <- self$files |>
        dplyr::rowwise() |>
        dplyr::mutate(
          raw = list(self$.dispatch_parse(.data$path, .data$parser)),
          tidy = dplyr::if_else(
            do_tidy,
            list(self$.dispatch_tidy(.data$raw, .data$parser)),
            list(NULL)
          )
        ) |>
        dplyr::ungroup()
      if (!keep_raw) {
        d <- d |>
          dplyr::select(-"raw")
      }
      if (!do_tidy) {
        d <- d |>
          dplyr::select(-"tidy")
      }
      self$tbls <- d
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
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param prefix_include (`logical(1)`)\cr
    #' If `TRUE`, prepend an `input_prefix` column to each tidy table.
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly. Results stored in `self$written_files`
    #' (`NULL` if no files were found).
    write = function(
      output_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      prefix_include = FALSE,
      dbconn = NULL
    ) {
      assertthat::assert_that(
        format %in% nemo_out_formats(),
        msg = glue(
          "Invalid format '{format}'. Must be one of: {glue::glue_collapse(nemo_out_formats(), sep = ', ')}."
        )
      )
      if (format != "db") {
        if (is.null(output_dir)) {
          stop("Output directory must be specified when format is not 'db'.")
        }
        fs::dir_create(output_dir)
        output_dir <- normalizePath(output_dir)
      }
      stopifnot("Did you forget to tidy?" = private$is_tidied)
      if (is.null(self$tbls)) {
        self$written_files <- NULL
        return(invisible(self))
      }
      d_write <- self$tbls |>
        dplyr::rename(raw_path = "path") |>
        dplyr::select(
          "raw_path",
          "tool_parser",
          "parser",
          "prefix",
          "tidy"
        ) |>
        tidyr::unnest("tidy", names_sep = "_") |>
        dplyr::rowwise() |>
        dplyr::mutate(
          tidy_data = list({
            d <- tidy_data
            if (!is.null(output_id)) {
              d <- tibble::add_column(d, output_id = as.character(output_id), .before = 1)
            }
            if (prefix_include) {
              d <- tibble::add_column(d, input_prefix = as.character(prefix), .before = 1)
            }
            if (!is.null(input_id)) {
              d <- tibble::add_column(d, input_id = as.character(input_id), .before = 1)
            }
            d
          }),
          # handle sub-tbls
          tbl_name = dplyr::if_else(
            .data$parser == .data$tidy_name,
            .data$tool_parser,
            paste0(.data$tool_parser, .data$tidy_name)
          ),
          # used to write when non-db format
          fpfix = paste(file.path(output_dir, .data$prefix), .data$tbl_name, sep = "_"),
          dbtab = ifelse(
            format == "db",
            list(.data$tbl_name),
            list(NULL)
          ),
          out = list(
            nemo_write(
              d = .data$tidy_data,
              fpfix = .data$fpfix,
              format = format,
              dbconn = dbconn,
              dbtab = .data$dbtab
            )
          ),
          outpath = attr(out, "outpath")
        ) |>
        dplyr::ungroup() |>
        dplyr::select(
          "raw_path",
          "tool_parser",
          "prefix",
          "tidy_data",
          "tbl_name",
          "outpath"
        )
      private$is_written <- TRUE
      self$written_files <- d_write
      if (format != "db" && !is.null(self$path)) {
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
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param output_dir (`character(1)`)\cr
    #' Output directory.
    #' @param pkgs (`character(n)`)\cr
    #' Which R packages to extract versions for.
    #' @return (`tibble()`)\cr
    #' Single-row tibble with columns `input_id`, `output_id`, `input_dirs`,
    #' `output_dir`, `pkg_versions`, and `files`.
    get_metadata = function(input_id, output_id, output_dir, pkgs = NULL) {
      if (is.null(pkgs)) {
        pkgs <- self$pkg
      }
      if (private$is_written) {
        files <- self$written_files |>
          dplyr::mutate(outpath = basename(.data$outpath)) |>
          dplyr::select(tbl = "tbl_name", "prefix", fout = "outpath", fin = "raw_path") |>
          dplyr::mutate(dplyr::across(dplyr::where(is.character), as.character))
      } else {
        files <- self$files |>
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
    #' @description Parse, filter, tidy and write files.
    #' @param output_dir (`character(1)`)\cr
    #' Directory path to output tidy files.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param prefix_include (`logical(1)`)\cr
    #' If `TRUE`, prepend an `input_prefix` column to each tidy table.
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table3"`).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly. Results stored in `self$written_files`.
    wrangle = function(
      output_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      prefix_include = FALSE,
      dbconn = NULL,
      include = NULL,
      exclude = NULL
    ) {
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
          dbconn = dbconn
      )
    }
  ) # public end
)
