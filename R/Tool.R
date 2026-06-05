#' @title Tool Object
#'
#' @description
#' Base R6 class for all nemo tools. Subclasses implement parsers for specific
#' bioinformatic tool outputs by optionally overriding `parse_{tname}()` and
#' `tidy_{tname}()` methods for custom parse or tidy logic per table.
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
#' toolC$write(out_dir = dir1, format = "parquet", input_id = "run1")
#' (lfC <- list.files(dir1, full.names = TRUE))
#'
#' # wrangle
#' toolD <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(exclude = "tool1_table5")$
#'   wrangle(out_dir = dir2, format = "parquet", input_id = "run2")
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
#' expect_named(toolD, c("raw_path", "tool_parser", "prefix", "tidy_data", "tbl_name", "outpath"))
#' # input_id / output_id / pfix_include column tests
#' toolE <- Tool$new(name = name, pkg = pkg, path = path)$
#'   filter_files(include = "tool1_table1")$tidy()
#' read_pq <- function(d) arrow::read_parquet(list.files(d, pattern = "[.]parquet$", full.names = TRUE)[1])
#' dE0 <- fs::file_temp(); toolE$write(out_dir = dE0, format = "parquet")
#' dEi <- fs::file_temp(); toolE$write(out_dir = dEi, format = "parquet", input_id = "run1")
#' dEo <- fs::file_temp(); toolE$write(out_dir = dEo, format = "parquet", output_id = "out1")
#' dEp <- fs::file_temp(); toolE$write(out_dir = dEp, format = "parquet", pfix_include = TRUE)
#' dEa <- fs::file_temp(); toolE$write(out_dir = dEa, format = "parquet", input_id = "run1", output_id = "out1", pfix_include = TRUE)
#' expect_false(any(c("input_id", "output_id", "input_pfix") %in% names(read_pq(dE0))))
#' expect_equal(read_pq(dEi)$input_id[1], "run1")
#' expect_equal(read_pq(dEo)$output_id[1], "out1")
#' expect_true("input_pfix" %in% names(read_pq(dEp)))
#' expect_equal(names(read_pq(dEa))[1:3], c("input_id", "input_pfix", "output_id"))
#'
#' @export
Tool <- R6::R6Class(
  "Tool",
  private = list(
    # Do files need to be tidied? Used when no files are detected, so we can
    # use downstream as a bypass.
    is_tidied = NULL,
    is_written = NULL
  ),
  public = list(
    #' @field name (`character(1)`)\cr
    #' Name of tool.
    name = NULL,
    #' @field pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    pkg = NULL,
    #' @field path  (`character(1)`)\cr
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
    #' @field raw_schemas_all (`tibble()`)\cr
    #' All raw schemas for tool.
    raw_schemas_all = NULL,
    #' @field tidy_schemas_all (`tibble()`)\cr
    #' All tidy schemas for tool.
    tidy_schemas_all = NULL,
    #' @field get_tidy_schema (`function()`)\cr
    #' Get specific tidy schema.
    get_tidy_schema = NULL,
    #' @field get_raw_schema (`function()`)\cr
    #' Get specific raw schema.
    get_raw_schema = NULL,
    #' @field get_col_map (`function()`)\cr
    #' Get column mapping (raw -> tidy) for a table.
    get_col_map = NULL,
    #' @field files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [list_files_dir()].
    files_tbl = NULL,

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
      stopifnot(
        !is.null(path) || !is.null(files_tbl),
        !is.null(name),
        !is.null(pkg)
      )
      if (!is.null(files_tbl)) {
        stopifnot(is_files_tbl(files_tbl))
        if (!is.null(path)) {
          # ignore if files_tbl is specified
          path <- NULL
        }
      }
      self$name <- name
      self$pkg <- pkg
      self$path <- path
      self$config <- Config$new(self$name, pkg = self$pkg)
      self$raw_schemas_all <- self$config$raw_schemas_all
      self$tidy_schemas_all <- self$config$get_schemas_all("tidy")
      self$get_tidy_schema <- function(x = NULL, v = NULL) {
        self$config$get_schema(x = x, v = v, raw_or_tidy = "tidy")
      }
      self$get_raw_schema <- function(x = NULL, v = NULL) {
        self$config$get_schema(x = x, v = v, raw_or_tidy = "raw")
      }
      self$get_col_map <- self$config$get_col_map
      self$files_tbl <- files_tbl
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
        stopifnot(rlang::is_character(include))
        self$files <- self$files |>
          dplyr::filter(.data$tool_parser %in% include)
      }
      if (!is.null(exclude)) {
        stopifnot(rlang::is_character(exclude))
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
      files_tbl <- self$files_tbl
      stopifnot(!is.null(self$path) || !is.null(files_tbl))
      if (!is.null(files_tbl)) {
        stopifnot(is_files_tbl(files_tbl))
      }
      patterns <- self$config$get_patterns() |>
        dplyr::rename(pat_name = "name", pat_value = "pattern")
      files <- files_tbl %||% list_files_dir(self$path, type = type)
      res <- files |>
        tidyr::crossing(patterns) |>
        dplyr::filter(stringr::str_detect(.data$bname, .data$pat_value)) |>
        dplyr::select(
          parser = "pat_name",
          "bname",
          "size",
          "lastmodified",
          "path",
          pattern = "pat_value"
        )
      if (nrow(res) == 0) {
        return(res)
      }
      res |>
        dplyr::mutate(
          prefix = stringr::str_remove(.data$bname, .data$pattern),
          # handle wigits version files
          prefix = dplyr::if_else(
            .data$parser == "version" & .data$prefix == "",
            "version",
            .data$prefix
          ),
          tool_parser = glue("{self$name}_{.data$parser}")
        ) |>
        dplyr::mutate(group = dplyr::row_number(), .by = "bname") |>
        dplyr::mutate(
          group = dplyr::if_else(.data$group == 1, glue(""), glue("_{.data$group}")),
          prefix = glue("{.data$prefix}{.data$group}")
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
            glue("{.data$prefix}_{.data$grp2}")
          )
        ) |>
        dplyr::select(-"grp2") |>
        dplyr::relocate("tool_parser", .before = 1)
    },
    #' @description Dispatch parse for a table: calls custom `parse_{name}()` if
    #' defined in the subclass, otherwise falls back to `.parse_by_ftype()`.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param tname (`character(1)`)\cr
    #' Table name.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .dispatch_parse = function(x, tname) {
      fun <- glue("parse_{tname}")
      if (is.function(self[[fun]])) {
        self[[fun]](x)
      } else {
        self$.parse_by_ftype(x, tname)
      }
    },
    #' @description Dispatch tidy for a table: calls custom `tidy_{tname}()` if
    #' defined in the subclass, otherwise falls back to `.tidy_file()`.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' File path or already parsed raw tibble.
    #' @param tname (`character(1)`)\cr
    #' Table name.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble.
    .dispatch_tidy = function(x, tname) {
      fun <- glue("tidy_{tname}")
      if (is.function(self[[fun]])) {
        self[[fun]](x)
      } else {
        self$.tidy_file(x, tname)
      }
    },
    #' @description Parse a file by looking up its ftype from the config and
    #' calling the appropriate internal parser. Errors for ftypes that require
    #' a custom `parse_{tname}()` method (e.g. `csv-nohead-long`).
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param tname (`character(1)`)\cr
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_by_ftype = function(x, tname) {
      ftype <- self$config$get_ftype(tname)
      switch(
        ftype,
        "txt" = self$.parse_file(x, tname),
        "csv" = self$.parse_file(x, tname, delim = ","),
        "txt-nohead" = self$.parse_file_nohead(x, tname),
        "txt-keyvalue" = self$.parse_file_keyvalue(x, tname),
        stop(glue(
          "No default parser for ftype '{ftype}' (table '{tname}'). ",
          "Define parse_{tname}() in the subclass."
        ))
      )
    },
    #' @description Parse file.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param name (`character(1)`)\cr
    #' Parser name (e.g. "breakends" - see docs).
    #' @param delim (`character(1)`)\cr
    #' File delimiter.
    #' @param ... Passed on to `readr::read_delim`.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_file = function(x, name, delim = "\t", ...) {
      parse_file(
        fpath = x,
        pname = name,
        schemas_all = self$raw_schemas_all,
        delim = delim,
        ...
      )
    },
    #' @description Tidy file.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' File path or already parsed raw tibble.
    #' @param name (`character(1)`)\cr
    #' Parser name (e.g. "breakends" - see docs).
    #' @param convert_types (`logical(1)`)\cr
    #' Convert field types based on schema.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble.
    .tidy_file = function(x, name, convert_types = FALSE) {
      if (!tibble::is_tibble(x)) {
        x <- self$.dispatch_parse(x, name)
      }
      version <- get_tbl_version_attr(x)
      stopifnot(!is.null(version))
      schema <- self$get_tidy_schema(name, v = version)
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
        setNames(name) |>
        enframe_data()
    },
    #' @description Parse files with no header and two columns representing
    #' key-value pairs.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param name (`character(1)`)\cr
    #' Parser name (e.g. "qc" - see docs).
    #' @param delim (`character(1)`)\cr
    #' File delimiter.
    #' @param ... Passed on to `readr::read_delim`.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_file_keyvalue = function(x, name, delim = "\t", ...) {
      parse_file_keyvalue(
        fpath = x,
        pname = name,
        schemas_all = self$raw_schemas_all,
        delim = delim,
        ...
      )
    },
    #' @description Parse headless file.
    #' @param x (`character(1)`)\cr
    #' File path.
    #' @param pname (`character(1)`)\cr
    #' Parser name (e.g. "breakends" - see docs).
    #' @param delim (`character(1)`)\cr
    #' File delimiter.
    #' @param ... Passed on to `readr::read_delim`.
    #' @return (`tibble()`)\cr
    #' Parsed data in tibble.
    .parse_file_nohead = function(x, pname, delim = "\t", ...) {
      ncols <- file_hdr(x, delim = delim, ...) |> length()
      schema <- self$raw_schemas_all |>
        dplyr::filter(.data$name == pname) |>
        dplyr::select("version", "schema") |>
        dplyr::rowwise() |>
        dplyr::filter(nrow(.data$schema) == ncols) |>
        dplyr::ungroup()
      if (nrow(schema) != 1) {
        stop(glue(
          "Expected exactly one schema version matching {ncols} columns ",
          "for '{pname}', found {nrow(schema)}."
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
      # if no files found, early return
      if (nrow(self$files) == 0) {
        self$tbls <- NULL
        private$is_tidied <- TRUE
        return(invisible(self))
      }
      # if both FALSE, just return the file list
      if (!tidy && !keep_raw) {
        self$tbls <- self$files
        return(invisible(self))
      }
      d <- self$files |>
        dplyr::rowwise() |>
        dplyr::mutate(
          raw = list(self$.dispatch_parse(.data$path, .data$parser)),
          tidy = dplyr::if_else(
            tidy,
            list(self$.dispatch_tidy(.data$raw, .data$parser)),
            list(NULL)
          )
        ) |>
        dplyr::ungroup()
      if (!keep_raw) {
        d <- d |>
          dplyr::select(-"raw")
      }
      if (!tidy) {
        d <- d |>
          dplyr::select(-"tidy")
      }
      self$tbls <- d
      private$is_tidied <- TRUE
      return(invisible(self))
    },
    #' @description Write tidy tibbles.
    #' @param out_dir (`character(1)`)\cr
    #' Directory path to output tidy files. Ignored if format is db.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param pfix_include (`logical(1)`)\cr
    #' If `TRUE`, prepend an `input_pfix` column to each tidy table.
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @return (`tibble()` or `NULL`)\cr
    #' A tibble with columns `raw_path`, `tool_parser`, `prefix`, `tidy_data`,
    #' `tbl_name` and `outpath`, invisibly. `NULL` if no files were found.
    write = function(
      out_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      pfix_include = FALSE,
      dbconn = NULL
    ) {
      if (format != "db") {
        if (is.null(out_dir)) {
          stop("Output directory must be specified when format is not 'db'.")
        }
        fs::dir_create(out_dir)
        out_dir <- normalizePath(out_dir)
      }
      stopifnot("Did you forget to tidy?" = private$is_tidied)
      if (is.null(self$tbls)) {
        # even though tidying is not needed, there must be no files detected
        # for tidying (and therefore writing). So return NULL.
        return(NULL)
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
            if (pfix_include) {
              d <- tibble::add_column(d, input_pfix = as.character(prefix), .before = 1)
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
          fpfix = paste(file.path(out_dir, .data$prefix), .data$tbl_name, sep = "_"),
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
      return(invisible(d_write))
    },
    #' @description Parse, filter, tidy and write files.
    #' @param out_dir (`character(1)`)\cr
    #' Directory path to output tidy files.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param pfix_include (`logical(1)`)\cr
    #' If `TRUE`, prepend an `input_pfix` column to each tidy table.
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @param include (`character(n)`)\cr
    #' tool_parser names to include (e.g. `"tool1_table1"`).
    #' @param exclude (`character(n)`)\cr
    #' tool_parser names to exclude (e.g. `"tool1_table3"`).
    #' @return (`tibble()` or `NULL`)\cr
    #' A tibble with columns `tool_parser`, `prefix`, `tidy_data`, `tbl_name`,
    #' `outpath`, invisibly. `NULL` if no files were found.
    wrangle = function(
      out_dir = ".",
      format = "tsv",
      input_id = NULL,
      output_id = NULL,
      pfix_include = FALSE,
      dbconn = NULL,
      include = NULL,
      exclude = NULL
    ) {
      # fmt: skip
      self$
        filter_files(include = include, exclude = exclude)$
        tidy()$
        write(
          out_dir = out_dir,
          format = format,
          input_id = input_id,
          output_id = output_id,
          pfix_include = pfix_include,
          dbconn = dbconn
      )
    }
  ) # public end
)
