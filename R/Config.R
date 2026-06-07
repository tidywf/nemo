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
#' # get_col_map
#' expect_named(cm, c("raw", "tidy", "type", "description"))
#'
#' @export
Config <- R6::R6Class(
  "Config",
  cloneable = FALSE,
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
      invalid <- private$collect_invalid_schema_types()
      if (nrow(invalid) > 0) {
        stop(private$format_invalid_types_msg(invalid), call. = FALSE)
      }
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
    #' Version string. If `NULL`, **all** versions are returned (one row per version).
    #' This differs from `get_col_map(version = NULL)`, which resolves to a single version.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_raw = function(x, version = NULL) {
      private$get_schema(x, version, private$schemas_raw)
    },
    #' @description Get tidy schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string. If `NULL`, **all** versions are returned (one row per version).
    #' This differs from `get_col_map(version = NULL)`, which resolves to a single version.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_tidy = function(x, version = NULL) {
      private$get_schema(x, version, private$schemas_tidy)
    },
    #' @description Get column mapping (raw -> tidy) for a table.
    #' Used for tables with custom parse logic (e.g. csv-nohead-long).
    #'
    #' **`version = NULL` resolves to a single version here**, unlike
    #' `get_schema_raw()`/`get_schema_tidy()` which return *all* versions when
    #' `version = NULL`. Use an explicit version string if you need a specific version
    #' from either family of methods.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string. If `NULL`, resolves to the highest semver version present,
    #' or `"latest"` if defined.
    #' @return (`tibble()`)\cr
    #' Tibble with columns `raw`, `tidy`, `type`, `description`.
    get_col_map = function(x, version = NULL) {
      private$get_schema_both_one(x, version) |>
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
        dplyr::filter(!.data$type %in% names(schema_type_map))
    },
    format_invalid_types_msg = function(invalid) {
      valid_types_print <- glue::glue_collapse(names(schema_type_map), sep = ", ", last = " or ")
      entries <- invalid |>
        dplyr::mutate(entry = glue("{.data$name} -> {.data$field} -> {.data$type}")) |>
        dplyr::pull("entry") |>
        glue::glue_collapse(sep = "; ")
      glue(
        "Field types need to be one of: {valid_types_print}\n",
        "Check the following in the {self$tool} config:\n{entries}"
      )
    },
    assert_version = function(x, version, versions) {
      if (!version %in% versions) {
        stop(glue("{version} not found in versions for {x} in {self$tool}."), call. = FALSE)
      }
    },
    # Resolve a version arg: NULL defaults to the last sorted version (highest
    # semver, or "latest" when present); otherwise validates and returns as-is.
    resolve_version = function(x, version, versions) {
      if (is.null(version)) {
        return(tail(versions, 1))
      }
      private$assert_version(x, version, versions)
      version
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
        stop(glue("schema.yaml not found for {self$tool} at {schema_path}."), call. = FALSE)
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
      purrr::map_chr(private$tables, \(x) x[[key]]) |>
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
      purrr::map(versions, \(v) {
        cols_v <- cols_df |>
          dplyr::filter(purrr::map_lgl(.data$versions, \(vs) v %in% vs)) |>
          dplyr::mutate(type = schema_type_remap(.data$type)) |>
          dplyr::select("raw", "tidy", "type", "description")
        tibble::tibble(
          name = tab_name,
          tbl_description = tab[["description"]],
          version = v,
          schema = list(cols_v)
        )
      }) |>
        dplyr::bind_rows()
    },
    compute_schemas = function() {
      private$tables |>
        purrr::imap(private$compute_schema_one) |>
        dplyr::bind_rows()
    },
    derive_schema = function(cache, side) {
      # schema list-cols carry only field + type (no description) because they are
      # consumed directly by tibble::deframe() → readr col-type specs, which require
      # exactly a two-column tibble. Descriptions are available via get_col_map().
      cache |>
        dplyr::mutate(
          schema = purrr::map(
            .data$schema,
            \(s) dplyr::select(s, field = dplyr::all_of(side), "type")
          )
        )
    },
    get_schema_both_one = function(x, version) {
      nemo_assert_scalar_chr(x)
      if (!is.null(version)) {
        nemo_assert_scalar_chr(version)
      }
      if (!x %in% private$schemas_both[["name"]]) {
        stop(glue("{x} not found in schemas for {self$tool}."), call. = FALSE)
      }
      rows <- private$schemas_both |> dplyr::filter(.data$name == x)
      version <- private$resolve_version(x, version, rows[["version"]])
      rows |>
        dplyr::filter(.data$version == .env$version) |>
        tidyr::unnest("schema")
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

schema_type_map <- c(char = "c", float = "d", int = "i")

schema_type_remap <- function(x) {
  unname(schema_type_map[x])
}

#' Sort version strings with "latest" always last
#'
#' Semver strings (with optional `v`/`V` prefix) are sorted numerically;
#' `"latest"` is always placed at the end regardless of position in the input.
#'
#' @param versions (`character(n)`)\cr
#' Vector of unique version strings (e.g. `c("v1.2.3", "latest")`) — typically
#' from `unlist()`ing the `versions` list-col.
#' @returns Sorted character vector with `"latest"` last.
#' @examples
#' config_sort_versions(c("v2.0.0", "v1.0.0", "latest"))
#' config_sort_versions(c("latest", "v1.2.3"))
#' config_sort_versions(c("v1.0.0", "v10.0.0", "v2.0.0"))
#' @testexamples
#' expect_equal(config_sort_versions(c("v2.0.0", "v1.0.0", "latest")), c("v1.0.0", "v2.0.0", "latest"))
#' expect_equal(config_sort_versions(c("latest", "v1.2.3")), c("v1.2.3", "latest"))
#' expect_equal(config_sort_versions(c("v1.0.0", "v10.0.0", "v2.0.0")), c("v1.0.0", "v2.0.0", "v10.0.0"))
#' @export
config_sort_versions <- function(versions) {
  non_latest <- versions[versions != "latest"]
  non_latest <- non_latest[order(numeric_version(gsub("^[vV]", "", non_latest)))]
  c(non_latest, if ("latest" %in% versions) "latest")
}
