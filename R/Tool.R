#' @title Tool Object
#'
#' @description
#' Base class for all nemo tools.
#'
#' A Tool object:
#' - has a name (`name`);
#' - has a path to a directory with its outputs (`path`);
#' - has a schema configuration Config object (`config`);
#' - has a tibble of files matching its Config patterns (`files`);
#' - has a tibble with the parsed and tidied files as tibbles (`tbls`);
#'
#' @examples
#' name <- "tool1"; pkg <- "nemo";
#' path <- system.file("extdata", name, package = pkg)
#' tool <- Tool$new(name = name, pkg = pkg, path = path)
#' tool$filter_files(exclude = "table3")
#' x <- Tool1$new(path = path)$
#'   filter_files(exclude = "alignments_dupfreq")$
#'   tidy(keep_raw = TRUE)
#' x$tbls
#' x$files
#' x$list_files()
#' @testexamples
#' path <- system.file("extdata/tool1", package = "nemo")
#' t_all <- Tool1$new(path = path)
#' expect_equal(
#'   t_all$files$tool_parser,
#'   c("tool1_table1", "tool1_table1", "tool1_table2", "tool1_table3", "tool1_table4", "tool1_table5")
#' )
#' t_excl <- Tool1$new(path = path)$filter_files(exclude = "tool1_table3")
#' expect_false("tool1_table3" %in% t_excl$files$tool_parser)
#' expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4", "tool1_table5") %in% t_excl$files$tool_parser))
#' t_incl <- Tool1$new(path = path)$filter_files(include = "tool1_table1")
#' expect_equal(unique(t_incl$files$tool_parser), "tool1_table1")
#' expect_error(
#'   Tool1$new(path = path)$filter_files(include = "tool1_table1", exclude = "tool1_table3"),
#'   "You cannot define both include and exclude"
#' )
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
    #' @description List files in given tool directory.
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
    #' Parsed data in enframed tibble.
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
      schema <- self$raw_schemas_all |>
        dplyr::filter(.data$name == pname) |>
        dplyr::select("version", "schema")
      parse_file_nohead(
        fpath = x,
        schema = schema,
        delim = delim,
        ...
      )
    },
    #' @description Tidy a list of files.
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
    #' @param diro (`character(1)`)\cr
    #' Directory path to output tidy files. Ignored if format is db.
    #' @param format (`character(1)`)\cr
    #' Format of output.
    #' @param input_id (`character(1)`)\cr
    #' Input ID to use for the dataset (e.g. `run123`).
    #' @param output_id (`character(1)`)\cr
    #' Output ID to use for the dataset (e.g. `run123`).
    #' @param dbconn (`DBIConnection`)\cr
    #' Database connection object (see `DBI::dbConnect`).
    #' @return A tibble with the tidy data and their output location prefix.
    write = function(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = ulid::ulid(),
      dbconn = NULL
    ) {
      if (format != "db") {
        if (is.null(diro)) {
          stop("Output directory must be specified when format is not 'db'.")
        }
        fs::dir_create(diro)
        diro <- normalizePath(diro)
      }
      stopifnot(!is.null(input_id), !is.null(output_id))
      stopifnot("Did you forget to tidy?" = private$is_tidied)
      if (is.null(self$tbls)) {
        # even though tidying is not needed, there must be no files detected
        # for tidying (and therefore writing). So return NULL.
        return(NULL)
      }
      d_write <- self$tbls |>
        dplyr::select(
          "tool_parser",
          "parser",
          "prefix",
          "tidy"
        ) |>
        tidyr::unnest("tidy", names_sep = "_") |>
        dplyr::rowwise() |>
        dplyr::mutate(
          tidy_data = list(
            tidy_data |>
              tibble::add_column(
                input_id = as.character(input_id),
                input_pfix = as.character(prefix),
                output_id = as.character(output_id),
                .before = 1
              )
          ),
          # handle sub-tbls
          tbl_name = dplyr::if_else(
            .data$parser == .data$tidy_name,
            .data$tool_parser,
            paste(.data$tool_parser, .data$tidy_name, sep = "_")
          ),
          # used to write when non-db format
          fpfix = paste(file.path(diro, .data$prefix), .data$tbl_name, sep = "_"),
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
    #' Files to include.
    #' @param exclude (`character(n)`)\cr
    #' Files to exclude.
    #' @return A tibble with the tidy data and their output location prefix.
    nemofy = function(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = ulid::ulid(),
      dbconn = NULL,
      include = NULL,
      exclude = NULL
    ) {
      # fmt: skip
      self$
        filter_files(include = include, exclude = exclude)$
        tidy()$
        write(
          diro = diro,
          format = format,
          input_id = input_id,
          output_id = output_id,
          dbconn = dbconn
      )
    }
  ) # public end
)
