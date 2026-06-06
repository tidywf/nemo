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
#' - has a parsed tables list (`tables`)
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
    #' @field tables (`list()`)\cr
    #' Tables list (parsed from schema.yaml).
    tables = NULL,
    #' @field schemas_raw (`tibble()`)\cr
    #' All raw schemas for tool (versioned, for schema_guess).
    schemas_raw = NULL,
    #' @field schemas_tidy (`tibble()`)\cr
    #' All tidy schemas for tool (versioned, computed once at init).
    schemas_tidy = NULL,

    #' @description Create a new Config object.
    #' @param tool (`character(1)`)\cr
    #' Tool name.
    #' @param pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(tool, pkg) {
      stopifnot("tool not single char string" = rlang::is_scalar_character(tool))
      stopifnot("pkg not single char string" = rlang::is_scalar_character(pkg))
      tool <- tolower(tool)
      self$tool <- tool
      self$pkg <- pkg
      self$tables <- private$read()[["tables"]]
      private$schemas_cache <- private$compute_schemas()
      self$schemas_raw <- private$derive_schema(private$schemas_cache, "raw")
      self$schemas_tidy <- private$derive_schema(private$schemas_cache, "tidy")
    },

    #' @description Print details about the Config.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var    , ~value                            ,
        "tool"  , self$tool                         ,
        "pkg"   , self$pkg                          ,
        "ntbls" , as.character(length(self$tables))
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

    #' @description Return raw schemas for all tables.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(field, type)).
    get_schemas_raw = function() self$schemas_raw,

    #' @description Return tidy schemas for all tables.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(field, type)).
    get_schemas_tidy = function() self$schemas_tidy,

    #' @description Return both raw and tidy schemas for all tables.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(raw, tidy, type)).
    get_schemas_both = function() private$schemas_cache,

    #' @description Get raw schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version. If NULL, returns all versions.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_raw = function(x = NULL, version = NULL) {
      private$get_schema(x, version, self$schemas_raw)
    },
    #' @description Get tidy schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version. If NULL, returns all versions.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_tidy = function(x = NULL, version = NULL) {
      private$get_schema(x, version, self$schemas_tidy)
    },
    #' @description Validate schemas.
    #' Intentionally soft: returns `FALSE` + warning (not `stop()`) so callers
    #' can report schema problems without halting execution.
    #' @return (`logical(1)`)\cr
    #' `TRUE` if all field types are valid, `FALSE` otherwise.
    validate_schemas = function() {
      valid_types <- c(char = "c", int = "i", float = "d")
      valid_types_print <- glue::glue_collapse(valid_types, sep = ", ", last = " or ")
      invalid <- self$schemas_raw |>
        tidyr::unnest("schema") |>
        dplyr::mutate(invalid_type = !.data$type %in% valid_types) |>
        dplyr::filter(.data$invalid_type) |>
        dplyr::mutate(
          warn = glue::glue(
            "{.data$name} -> {.data$version} -> {.data$field} -> {.data$type}"
          )
        )
      if (nrow(invalid) > 0) {
        msg1 <- invalid |>
          dplyr::pull("warn") |>
          glue::glue_collapse(sep = "; ")
        warning(glue(
          "Field types need to be one of: {valid_types_print}\n",
          "Check the following in the {self$tool} config:\n{msg1}"
        ))
        return(FALSE)
      }
      return(TRUE)
    },
    #' @description Get column mapping (raw -> tidy) for a table.
    #' Used for tables with custom parse logic (e.g. csv-nohead-long).
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version. If NULL, uses the latest version.
    get_col_map = function(x = NULL, version = NULL) {
      assertthat::assert_that(
        rlang::is_scalar_character(x),
        msg = "`x` must be a single character string."
      )
      assertthat::assert_that(
        x %in% names(self$tables),
        msg = glue("{x} not found in tables for {self$tool}.")
      )
      assertthat::assert_that(
        !is.null(self$tables[[x]][["columns"]]),
        msg = glue("No columns defined for table '{x}' in {self$tool} config.")
      )
      cols_df <- self$tables[[x]][["columns"]] |>
        purrr::map(\(col) {
          col[["versions"]] <- list(col[["versions"]])
          tibble::as_tibble_row(col)
        }) |>
        dplyr::bind_rows()
      # sorted so versions[length(versions)] picks "latest" if present, else highest semver
      versions <- config_sort_versions(unique(unlist(cols_df[["versions"]])))
      if (is.null(version)) {
        version <- versions[length(versions)]
      }
      assertthat::assert_that(
        version %in% versions,
        msg = glue("{version} not found in versions for {x} in {self$tool}.")
      )
      cols_df |>
        dplyr::filter(purrr::map_lgl(.data$versions, \(vs) version %in% vs)) |>
        dplyr::mutate(type = schema_type_remap(.data$type)) |>
        dplyr::select("raw", "tidy", "type", "description")
    }
  ), # end public
  private = list(
    read = function() {
      pkg_config_path <- system.file("config/tools", package = self$pkg)
      assertthat::assert_that(
        dir.exists(pkg_config_path),
        msg = glue("Config directory not found for package '{self$pkg}': {pkg_config_path}")
      )
      tools <- list.files(pkg_config_path, full.names = FALSE)
      assertthat::assert_that(
        self$tool %in% tools,
        msg = glue("No config for {self$tool} under {pkg_config_path}/.")
      )
      schema_path <- file.path(pkg_config_path, self$tool, "schema.yaml")
      assertthat::assert_that(
        file.exists(schema_path),
        msg = glue("schema.yaml not found for {self$tool} at {schema_path}")
      )
      cfg <- yaml::read_yaml(schema_path)
      assertthat::assert_that(
        "tables" %in% names(cfg),
        msg = glue("schema.yaml for {self$tool} is missing the top-level 'tables' key.")
      )
      cfg
    },
    get_field_for_table = function(x, key) {
      assertthat::assert_that(
        x %in% names(self$tables),
        msg = glue("{x} not found in tables for {self$tool}.")
      )
      self$tables[[x]][[key]]
    },
    get_field_for_all_tables = function(key) {
      self$tables |>
        purrr::map(key) |>
        tibble::enframe(value = key) |>
        tidyr::unnest(dplyr::all_of(key))
    },
    schemas_cache = NULL,
    compute_schemas = function() {
      .get_one <- function(tab, tab_name) {
        cols_df <- tab[["columns"]] |>
          purrr::map(\(col) {
            col[["versions"]] <- list(col[["versions"]])
            tibble::as_tibble_row(col)
          }) |>
          dplyr::bind_rows()
        versions <- config_sort_versions(unique(unlist(cols_df[["versions"]])))
        schema_rows <- purrr::map(versions, \(v) {
          cols_v <- cols_df |>
            dplyr::filter(purrr::map_lgl(.data$versions, \(vs) v %in% vs)) |>
            dplyr::mutate(type = schema_type_remap(.data$type)) |>
            dplyr::select("raw", "tidy", "type")
          tibble::tibble(version = v, schema = list(cols_v))
        }) |>
          dplyr::bind_rows()
        tibble::tibble(name = tab_name, tbl_description = tab[["description"]]) |>
          dplyr::bind_cols(schema_rows)
      }
      self$tables |>
        purrr::imap(.get_one) |>
        dplyr::bind_rows()
    },
    derive_schema = function(cache, which) {
      cache |>
        dplyr::mutate(
          schema = purrr::map(
            .data$schema,
            \(s) dplyr::select(s, field = dplyr::all_of(which), "type")
          )
        )
    },
    get_schema = function(x, version, schemas) {
      stopifnot("x must be a single character string" = rlang::is_scalar_character(x))
      assertthat::assert_that(
        x %in% schemas[["name"]],
        msg = glue("{x} not found in schemas for {self$tool}.")
      )
      res <- schemas |>
        dplyr::filter(.data$name == x)
      if (!is.null(version)) {
        assertthat::assert_that(
          version %in% res[["version"]],
          msg = glue("{version} not found in versions for {x} in {self$tool}.")
        )
        res <- res |>
          dplyr::filter(.data$version == .env$version)
      }
      res |>
        tidyr::unnest("schema") |>
        dplyr::select("version", "field", "type")
    }
  ) # end private
)

#' Sort version strings with "latest" always last
#'
#' @param versions (`character(n)`)\cr
#' Vector of unique version strings (e.g. `c("v1.2.3", "latest")`) — typically from `unlist()`ing the `versions` list-col.
#' @returns Sorted character vector with `"latest"` last.
#' @keywords internal
config_sort_versions <- function(versions) {
  non_latest <- versions[versions != "latest"]
  if (length(non_latest) > 0) {
    non_latest <- non_latest[order(numeric_version(gsub("^[vV]", "", non_latest)))]
  }
  c(non_latest, if ("latest" %in% versions) "latest")
}

#' Prepare config schema from raw file
#'
#' @description
#' Prepares config schema from raw file.
#'
#' @param path (`character(1)`)\cr
#' File path.
#' @param ... Passed on to `readr::read_delim`.
#' @returns A tibble with columns `field` and `type`, each single-quoted for
#' prettier YAML export.
#' @examples
#' path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
#' (x <- config_prep_raw_schema(path = path, delim = "\t"))
#' @testexamples
#' expect_equal(x[1, "field", drop = T], "'SampleID'")
#' @export
config_prep_raw_schema <- function(path, ...) {
  type_map <- c(
    "character" = "'char'",
    "integer" = "'int'",
    "numeric" = "'float'",
    "logical" = "'char'"
  )
  path |>
    readr::read_delim(n_max = 100, show_col_types = FALSE, ...) |>
    purrr::map_chr(class) |>
    tibble::enframe(name = "field", value = "type") |>
    dplyr::mutate(
      type = type_map[.data$type],
      field = paste0("'", .data$field, "'")
    )
}

#' Prepare config from raw file
#'
#' @description
#' Prepares config from raw file.
#'
#' @param path (`character(1)`)\cr
#' File path.
#' @param name (`character(1)`)\cr
#' File nickname.
#' @param descr (`character(1)`)\cr
#' File description.
#' @param pat (`character(1)`)\cr
#' File pattern.
#' @param type (`character(1)`)\cr
#' File type.
#' @param v (`character(1)`)\cr
#' File version.
#' @param ... Passed on to `readr::read_delim`.
#' @returns A named list with the config info.
#' @examples
#' path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
#' name <- "table1"
#' descr <- "Table1 from Tool1."
#' pat <- "\\.tool1\\.table1\\.tsv$"
#' l <- config_prep_raw(path, name, descr, pat)
#' @testexamples
#' expect_equal(names(l[[1]]), c("description", "pattern", "ftype", "schema"))
#' @export
config_prep_raw <- function(path, name, descr, pat, type = "txt", v = "latest", ...) {
  schema <- config_prep_raw_schema(path = path, ...)
  attr(pat, "quoted") <- TRUE
  list(
    list(
      description = glue("'{descr}'"),
      pattern = pat,
      ftype = glue("'{type}'"),
      schema = list(schema) |> purrr::set_names(v)
    )
  ) |>
    purrr::set_names(name)
}

#' Prepare config for multiple raw files
#'
#' @param x (`tibble()`)\cr
#' Tibble with columns `name`, `descr`, `pat`, `type`, and `path`.
#' @param tool_descr (`character(1)`)\cr
#' Tool description.
#'
#' @returns A named list with the config info.
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
#' tool_descr <- "Tool1 does amazing things."
#' config <- config_prep_multi(x, tool_descr)
#' @export
config_prep_multi <- function(x, tool_descr = NULL) {
  stopifnot(
    tibble::is_tibble(x),
    all(c("name", "descr", "pat", "type", "path") %in% colnames(x)),
    !is.null(tool_descr)
  )
  l <- x |>
    dplyr::rowwise() |>
    dplyr::mutate(
      config = config_prep_raw(
        path = .data$path,
        name = .data$name,
        descr = .data$descr,
        pat = .data$pat,
        type = .data$type
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::pull("config")
  list(description = glue::glue("'{tool_descr}'"), raw = l)
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
#' @export
config_prep_write <- function(x, out) {
  yaml::write_yaml(x, out, column.major = FALSE)
  system2("sed", args = c("-i", "", "s/'''/'/g", out))
}
