#' @title Config Object
#'
#' @description
#' Reads and parses a tool's `schema.yaml` from `inst/config/tools/<tool>/` in
#' the package. The schema defines each output table: its file pattern, file
#' type, description, and versioned columns (raw name, tidy name, type, versions).
#' Exposes raw and tidy schemas and column mappings used by `Tool` for
#' file discovery and column renaming.
#'
#' A Config object:
#' - belongs to a package (`pkg`)
#' - has a tool name (`tool`)
#' - has a parsed tables list (accessible via `get_tables()`)
#' - caches all raw schemas as a flat tibble (`schemas_raw`)
#' - caches all tidy schemas as a flat tibble (`schemas_tidy`)
#' @examples
#' tool <- "tool1"
#' pkg <- "nemo"
#' conf <- Config$new(tool, pkg)
#' (patterns <- conf$get_patterns())
#' (ftypes <- conf$get_ftypes())
#' (pat1 <- conf$get_pattern("table1"))
#' (ftype1 <- conf$get_ftype("table1"))
#' (descr1 <- conf$get_description("table1"))
#' (descr <- conf$get_descriptions())
#' (rs <- conf$get_schemas_raw())
#' (ts <- conf$get_schemas_tidy())
#' (s1 <- conf$get_schema_raw("table1"))
#' conf$get_schema_raw("table1", version = "v1.2.3")
#' conf$get_schema_tidy("table1")
#' conf$validate_schemas()
#' (cm <- conf$get_col_map("table5"))
#'
#' @testexamples
#' # initialize
#' expect_error(Config$new("foo", pkg))
#' expect_error(Config$new("tool1", "nonexistent_pkg"), "Config directory not found")
#' # get_patterns
#' expect_equal(nrow(patterns), 6)
#' # get_ftypes
#' expect_equal(dplyr::distinct(ftypes, .data$ftype) |> nrow(), 5)
#' # get_pattern
#' expect_equal(pat1, "\\.tool1\\.table1\\.tsv$")
#' # get_ftype
#' expect_equal(ftype1, "txt")
#' # get_description
#' expect_true(is.character(descr1))
#' # get_descriptions
#' expect_equal(nrow(descr), 6)
#' # get_schemas_raw / get_schemas_tidy
#' expect_equal(dplyr::filter(rs, .data$name == "table1") |> nrow(), 3)
#' expect_equal(dplyr::filter(ts, .data$name == "table1") |> nrow(), 3)
#' # get_schema_raw
#' expect_named(s1, c("version", "field", "type"))
#' expect_equal(nrow(conf$get_schema_raw("table1", version = "v1.2.3")), 5)
#' expect_equal(nrow(conf$get_schema_raw("table1", version = "v4.5.6")), 4)
#' expect_error(conf$get_schema_raw("foo"))
#' expect_error(conf$get_schema_raw("table1", version = "foo"))
#' # validate_schemas
#' expect_true(conf$validate_schemas())
#' # get_col_map
#' expect_named(cm, c("raw", "tidy", "type", "description"))
#'
#' @export
Config <- R6::R6Class(
  "Config",
  public = list(
    #' @field tool (`character(1)`)\cr
    #' Tool name.
    tool = NULL,
    #' @field pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    pkg = NULL,
    #' @description Create a new Config object.
    #' @param tool (`character(1)`)\cr
    #' Tool name.
    #' @param pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(tool, pkg) {
      nemo_assert_scalar_chr(tool)
      nemo_assert_scalar_chr(pkg)
      tool <- tolower(tool)
      self$tool <- tool
      self$pkg <- pkg
      private$tables <- private$read()
      private$check_schemas()
      private$schemas_both <- private$compute_schemas()
      private$schemas_raw <- private$derive_schema(private$schemas_both, "raw")
      private$schemas_tidy <- private$derive_schema(private$schemas_both, "tidy")
    },

    #' @description Print details about the Config.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var    , ~value                               ,
        "tool"  , self$tool                            ,
        "pkg"   , self$pkg                             ,
        "ntbls" , as.character(length(private$tables))
      )
      cat(glue("#--- Config {self$pkg}::{self$tool} ---#\n"))
      print(knitr::kable(res))
      invisible(self)
    },

    #' @description Return all output file patterns.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `pattern`.
    get_patterns = function() private$get_field_for_all_tables("pattern"),

    #' @description Return all output file types.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `ftype`.
    get_ftypes = function() private$get_field_for_all_tables("ftype"),

    #' @description Return all table descriptions.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `description`.
    get_descriptions = function() private$get_field_for_all_tables("description"),

    #' @description Return pattern for a specific table.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @return (`character()`)\cr
    #' File pattern(s).
    get_pattern = function(x) private$get_field_for_table(x, "pattern"),

    #' @description Return ftype for a specific table.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @return (`character(1)`)\cr
    #' File type.
    get_ftype = function(x) private$get_field_for_table(x, "ftype"),

    #' @description Return description for a specific table.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @return (`character(1)`)\cr
    #' Table description.
    get_description = function(x) private$get_field_for_table(x, "description"),

    #' @description Return the parsed tables list.
    #' @return (`list()`)\cr
    #' Named list of table definitions from schema.yaml.
    get_tables = function() private$tables,

    #' @description Return raw schemas for all tables.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(field, type)).
    get_schemas_raw = function() private$schemas_raw,

    #' @description Return tidy schemas for all tables.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(field, type)).
    get_schemas_tidy = function() private$schemas_tidy,

    #' @description Return both raw and tidy schemas for all tables.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(raw, tidy, type)).
    get_schemas_both = function() private$schemas_both,

    #' @description Get raw schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version. If NULL, returns all versions.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_raw = function(x, version = NULL) {
      private$get_schema(x, version, private$schemas_raw)
    },
    #' @description Get tidy schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version. If NULL, returns all versions.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_tidy = function(x, version = NULL) {
      private$get_schema(x, version, private$schemas_tidy)
    },
    #' @description Validate schemas.
    #' Intentionally soft: returns `FALSE` + warning (not `stop()`) so callers
    #' can report schema problems without halting execution.
    #' Checks raw YAML types from `tables` directly, before remapping.
    #' @return (`logical(1)`)\cr
    #' `TRUE` if all field types are valid, `FALSE` otherwise.
    validate_schemas = function() {
      invalid <- private$collect_invalid_schema_types()
      if (nrow(invalid) == 0) {
        return(TRUE)
      }
      warning(private$format_invalid_types_msg(invalid))
      FALSE
    },
    #' @description Get column mapping (raw -> tidy) for a table.
    #' Used for tables with custom parse logic (e.g. csv-nohead-long).
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version. If NULL, uses the latest version. Unlike `get_schema_raw()`/`get_schema_tidy()`,
    #' which return all versions when NULL, this always resolves to a single version.
    #' @return (`tibble()`)\cr
    #' Tibble with columns `raw`, `tidy`, `type`, `description`.
    get_col_map = function(x, version = NULL) {
      nemo_assert_scalar_chr(x)
      if (!x %in% private$schemas_both[["name"]]) {
        stop(glue("{x} not found in schemas for {self$tool}."), call. = FALSE)
      }
      if (!is.null(version)) {
        nemo_assert_scalar_chr(version)
      }
      tbl_rows <- private$schemas_both |> dplyr::filter(.data$name == x)
      versions <- tbl_rows[["version"]]
      if (is.null(version)) {
        version <- tail(versions, 1)
      } else {
        private$assert_version(x, version, versions)
      }
      tbl_rows |>
        dplyr::filter(.data$version == .env$version) |>
        tidyr::unnest("schema") |>
        dplyr::select("raw", "tidy", "type", "description")
    }
  ), # end public
  private = list(
    tables = NULL,
    schemas_raw = NULL,
    schemas_tidy = NULL,
    schemas_both = NULL,
    collect_invalid_schema_types = function() {
      private$tables |>
        purrr::imap(\(tab, tab_name) {
          purrr::map(tab[["columns"]], \(col) {
            tibble::tibble(name = tab_name, field = col[["raw"]], type = col[["type"]])
          })
        }) |>
        purrr::list_flatten() |>
        dplyr::bind_rows() |>
        dplyr::filter(!.data$type %in% names(.schema_type_map))
    },
    format_invalid_types_msg = function(invalid) {
      valid_types_print <- glue::glue_collapse(names(.schema_type_map), sep = ", ", last = " or ")
      entries <- invalid |>
        dplyr::mutate(entry = glue("{.data$name} -> {.data$field} -> {.data$type}")) |>
        dplyr::pull("entry") |>
        glue::glue_collapse(sep = "; ")
      glue(
        "Field types need to be one of: {valid_types_print}\n",
        "Check the following in the {self$tool} config:\n{entries}"
      )
    },
    check_schemas = function() {
      invalid <- private$collect_invalid_schema_types()
      if (nrow(invalid) == 0) {
        return(invisible(NULL))
      }
      stop(private$format_invalid_types_msg(invalid), call. = FALSE)
    },
    assert_version = function(x, version, versions) {
      if (!version %in% versions) {
        stop(glue("{version} not found in versions for {x} in {self$tool}."), call. = FALSE)
      }
    },
    read = function() {
      pkg_config_path <- system.file("config/tools", package = self$pkg)
      if (!dir.exists(pkg_config_path)) {
        stop(
          glue("Config directory not found for package '{self$pkg}': {pkg_config_path}"),
          call. = FALSE
        )
      }
      tool_path <- file.path(pkg_config_path, self$tool)
      if (!dir.exists(tool_path)) {
        stop(glue("No config for {self$tool} under {pkg_config_path}."), call. = FALSE)
      }
      schema_path <- file.path(tool_path, "schema.yaml")
      if (!file.exists(schema_path)) {
        stop(glue("schema.yaml not found for {self$tool} at {schema_path}"), call. = FALSE)
      }
      cfg <- yaml::read_yaml(schema_path)
      if (!"tables" %in% names(cfg)) {
        stop(
          glue("schema.yaml for {self$tool} is missing the top-level 'tables' key."),
          call. = FALSE
        )
      }
      cfg[["tables"]]
    },
    get_field_for_table = function(x, key) {
      nemo_assert_scalar_chr(x)
      if (!x %in% names(private$tables)) {
        stop(glue("{x} not found in tables for {self$tool}."), call. = FALSE)
      }
      private$tables[[x]][[key]]
    },
    get_field_for_all_tables = function(key) {
      purrr::map_chr(private$tables, key) |>
        tibble::enframe(name = "name", value = key)
    },
    compute_schema_one = function(tab, tab_name) {
      cols_df <- tab[["columns"]] |>
        purrr::map(\(col) {
          tibble::tibble(
            raw = col[["raw"]],
            tidy = col[["tidy"]],
            type = col[["type"]],
            description = col[["description"]],
            versions = list(col[["versions"]])
          )
        }) |>
        dplyr::bind_rows()
      versions <- config_sort_versions(unique(unlist(cols_df[["versions"]])))
      schema_rows <- purrr::map(versions, \(v) {
        cols_v <- cols_df |>
          dplyr::filter(purrr::map_lgl(.data$versions, \(vs) v %in% vs)) |>
          dplyr::mutate(type = schema_type_remap(.data$type)) |>
          dplyr::select("raw", "tidy", "type", "description")
        tibble::tibble(version = v, schema = list(cols_v))
      }) |>
        dplyr::bind_rows()
      schema_rows |>
        dplyr::mutate(name = tab_name, tbl_description = tab[["description"]], .before = 1)
    },
    compute_schemas = function() {
      private$tables |>
        purrr::imap(private$compute_schema_one) |>
        dplyr::bind_rows()
    },
    derive_schema = function(cache, side) {
      cache |>
        dplyr::mutate(
          schema = purrr::map(
            .data$schema,
            \(s) dplyr::select(s, field = dplyr::all_of(side), "type")
          )
        )
    },
    get_schema = function(x, version, schemas) {
      nemo_assert_scalar_chr(x)
      if (!x %in% schemas[["name"]]) {
        stop(glue("{x} not found in schemas for {self$tool}."), call. = FALSE)
      }
      res <- schemas |>
        dplyr::filter(.data$name == x)
      if (!is.null(version)) {
        nemo_assert_scalar_chr(version)
        private$assert_version(x, version, res[["version"]])
        res <- res |>
          dplyr::filter(.data$version == .env$version)
      }
      res |>
        tidyr::unnest("schema") |>
        dplyr::select("version", "field", "type")
    }
  ) # end private
)

.schema_type_map <- c(char = "c", float = "d", int = "i")

schema_type_remap <- function(x) {
  unname(.schema_type_map[x])
}

#' Sort version strings with "latest" always last
#'
#' @param versions (`character(n)`)\cr
#' Vector of unique version strings (e.g. `c("v1.2.3", "latest")`) — typically from `unlist()`ing the `versions` list-col.
#' @returns Sorted character vector with `"latest"` last.
#' @keywords internal
config_sort_versions <- function(versions) {
  non_latest <- versions[versions != "latest"]
  non_latest <- non_latest[order(numeric_version(gsub("^[vV]", "", non_latest)))]
  c(non_latest, if ("latest" %in% versions) "latest")
}

#' Prepare config schema from raw file
#'
#' @description
#' Scaffolds a schema tibble from a raw file. The `tidy` column is a
#' best-effort snake_case conversion — edit the YAML after writing.
#'
#' @param path (`character(1)`)\cr
#' File path.
#' @param v (`character(1)`)\cr
#' Version string to assign to all columns (default `"latest"`).
#' @param ... Passed on to `readr::read_delim`.
#' @returns A tibble with columns `raw`, `tidy`, `type`, `description`,
#' and `versions` (list-col of `list(v)`).
#' @examples
#' path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
#' (x <- config_prep_raw_schema(path = path, delim = "\t"))
#' @testexamples
#' expect_named(x, c("raw", "tidy", "type", "description", "versions"))
#' expect_equal(nrow(x), 6L)
#' expect_equal(x[1, "raw",  drop = TRUE], "SampleID")
#' expect_equal(x[1, "tidy", drop = TRUE], "sample_id")
#' expect_equal(x[1, "type", drop = TRUE], "char")
#' expect_equal(unlist(x[[1, "versions"]]), "latest")
#' @export
config_prep_raw_schema <- function(path, v = "latest", ...) {
  type_map <- c(
    "character" = "char",
    "integer" = "int",
    "numeric" = "float",
    "logical" = "char"
  )
  .to_snake <- function(s) {
    gsub(
      "^_+|_+$",
      "",
      gsub("[^a-z0-9]+", "_", tolower(gsub("([[:lower:]])([[:upper:]])", "\\1_\\2", s)))
    )
  }
  raw_types <- path |>
    readr::read_delim(n_max = 100, show_col_types = FALSE, ...) |>
    purrr::map_chr(\(x) class(x)[1])
  unknown <- setdiff(unique(raw_types), names(type_map))
  if (length(unknown) > 0) {
    warning(glue("Column types not in type_map will produce NA: {paste(unknown, collapse = ', ')}"))
  }
  raw_types |>
    tibble::enframe(name = "raw", value = "type") |>
    dplyr::mutate(
      tidy = .to_snake(.data$raw),
      type = unname(type_map[.data$type]),
      description = "",
      versions = purrr::map(.data$raw, \(.) list(v))
    ) |>
    dplyr::select("raw", "tidy", "type", "description", "versions")
}

#' Prepare config from raw file
#'
#' @description
#' Scaffolds a single-table config entry from a raw file. Part of the
#' `config_prep_*` family for bootstrapping a new `schema.yaml`.
#'
#' @param path (`character(1)`)\cr
#' File path.
#' @param name (`character(1)`)\cr
#' Table name (key in `tables:`).
#' @param descr (`character(1)`)\cr
#' Table description.
#' @param pat (`character(1)`)\cr
#' File pattern (regex).
#' @param type (`character(1)`)\cr
#' File type (`ftype`).
#' @param v (`character(1)`)\cr
#' Version string to assign to all columns (default `"latest"`).
#' @param ... Passed on to `readr::read_delim`.
#' @returns A named list matching the `tables:` entry format for `schema.yaml`.
#' @examples
#' path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
#' name <- "table1"
#' descr <- "Table1 from Tool1."
#' pat <- "\\.tool1\\.table1\\.tsv$"
#' l <- config_prep_raw(path, name, descr, pat)
#' @testexamples
#' expect_equal(names(l[[1]]), c("description", "pattern", "ftype", "columns"))
#' expect_equal(length(l[[1]][["columns"]]), 6L)
#' col1 <- l[[1]][["columns"]][[1]]
#' expect_named(col1, c("raw", "tidy", "type", "description", "versions"))
#' expect_equal(col1[["raw"]], "SampleID")
#' expect_equal(col1[["tidy"]], "sample_id")
#' @export
config_prep_raw <- function(path, name, descr, pat, type = "txt", v = "latest", ...) {
  schema <- config_prep_raw_schema(path = path, v = v, ...)
  columns <- purrr::pmap(schema, list)
  entry <- list(description = descr, pattern = pat, ftype = type, columns = columns)
  rlang::set_names(list(entry), name)
}

#' Prepare config for multiple raw files
#'
#' @param x (`tibble()`)\cr
#' Tibble with columns `name`, `descr`, `pat`, `type`, and `path`.
#'
#' @returns A list `list(tables = ...)` ready to write with `config_prep_write()`.
#'
#' @examples
#' dir1 <-  "extdata/tool1/latest"
#' path1 <- system.file(dir1, "sampleA.tool1.table1.tsv", package = "nemo")
#' path2 <- system.file(dir1, "sampleA.tool1.table2.tsv", package = "nemo")
#' x <- tibble::tibble(
#'   name = c("table1", "table2"),
#'   descr = c("Table1 from Tool1.", "Table2 from Tool1."),
#'   pat = c("\\.tool1\\.table1\\.tsv$", "\\.tool1\\.table2\\.tsv$"),
#'   type = c("txt", "txt"),
#'   path = c(path1, path2)
#' )
#' config <- config_prep_multi(x)
#' @testexamples
#' expect_equal(names(config), "tables")
#' expect_equal(names(config[["tables"]]), c("table1", "table2"))
#' tbl1 <- config[["tables"]][["table1"]]
#' expect_equal(names(tbl1), c("description", "pattern", "ftype", "columns"))
#' expect_equal(length(tbl1[["columns"]]), 6L)
#' expect_named(tbl1[["columns"]][[1]], c("raw", "tidy", "type", "description", "versions"))
#' @export
config_prep_multi <- function(x) {
  assertthat::assert_that(tibble::is_tibble(x), msg = "'x' must be a tibble.")
  assertthat::assert_that(
    all(c("name", "descr", "pat", "type", "path") %in% colnames(x)),
    msg = "'x' must have columns: name, descr, pat, type, path."
  )
  tables <- purrr::pmap(
    dplyr::select(x, "name", "descr", "pat", "type", "path"),
    \(name, descr, pat, type, path) {
      config_prep_raw(path = path, name = name, descr = descr, pat = pat, type = type)
    }
  ) |>
    purrr::list_flatten()
  list(tables = tables)
}

#' Write config to YAML file
#'
#' @param x (`list()`)\cr
#' Config list, generated by `config_prep_multi()`.
#' @param out (`character(1)`)\cr
#' Output file path.
#'
#' @returns Nothing, called for side effects.
#'
#' @examples
#' dir1 <- "extdata/tool1/latest"
#' path1 <- system.file(dir1, "sampleA.tool1.table1.tsv", package = "nemo")
#' path2 <- system.file(dir1, "sampleA.tool1.table2.tsv", package = "nemo")
#' x <- tibble::tibble(
#'   name = c("table1", "table2"),
#'   descr = c("Table1 from Tool1.", "Table2 from Tool1."),
#'   pat = c("\\.tool1\\.table1\\.tsv$", "\\.tool1\\.table2\\.tsv$"),
#'   type = c("txt", "txt"),
#'   path = c(path1, path2)
#' )
#' config <- config_prep_multi(x)
#' out <- tempfile(fileext = ".yaml")
#' config_prep_write(config, out)
#' @testexamples
#' parsed <- yaml::read_yaml(out)
#' expect_equal(names(parsed), "tables")
#' expect_equal(names(parsed[["tables"]]), c("table1", "table2"))
#' tbl1 <- parsed[["tables"]][["table1"]]
#' expect_equal(names(tbl1), c("description", "pattern", "ftype", "columns"))
#' col1 <- tbl1[["columns"]][[1]]
#' expect_named(col1, c("raw", "tidy", "type", "description", "versions"))
#' expect_equal(col1[["raw"]], "SampleID")
#' expect_equal(col1[["versions"]][[1]], "latest")
#' @export
config_prep_write <- function(x, out) {
  yaml::write_yaml(x, out, column.major = FALSE)
}
