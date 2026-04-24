#' @title Config Object
#'
#' @description
#' Config YAML file parsing.
#'
#' A Config object:
#' - belongs to a package (`pkg`);
#' - has a tool name (`tool`);
#' - has a parsed configuration list with the schemas (`config`);
#' @examples
#' tool <- "tool1"
#' pkg <- "nemo"
#' conf <- Config$new(tool, pkg)
#' (patterns <- conf$get_patterns())
#' (ftypes <- conf$get_ftypes())
#' (ftype1 <- conf$get_ftype("table1"))
#' (descr <- conf$get_descriptions())
#' (rs <- conf$get_schemas_all("raw"))
#' (ts <- conf$get_schemas_all("tidy"))
#' conf$get_schema("table1")
#' conf$get_schema("table1", v = "v1.2.3")
#' conf$get_schema("table1", raw_or_tidy = "tidy")
#' conf$get_schema("table1", v = "v1.2.3", raw_or_tidy = "tidy")
#' conf$are_schemas_valid()
#' conf$get_col_map("table5")
#'
#' @testexamples
#' expect_error(conf$get_schema("foo"))
#' expect_error(conf$get_schema("table1", v = "foo"))
#' expect_error(conf$get_schema("table1", v = "foo", raw_or_tidy = "tidy"))
#' expect_true(conf$are_schemas_valid())
#' expect_equal(dplyr::filter(rs, .data$name == "table1") |> nrow(), 2)
#' expect_equal(dplyr::filter(ts, .data$name == "table1") |> nrow(), 2)
#' expect_error(Config$new("foo", pkg))
#' expect_equal(nrow(patterns), 5)
#' expect_equal(dplyr::distinct(ftypes, .data$ftype) |> nrow(), 4)
#' expect_equal(ftype1, "txt")
#' expect_equal(nrow(descr), 5)
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
    #' @field config (`list()`)\cr
    #' Config list (parsed schema.yaml).
    config = NULL,
    #' @field raw_schemas_all (`tibble()`)\cr
    #' All raw schemas for tool (versioned, for schema_guess).
    raw_schemas_all = NULL,

    #' @description Create a new Config object.
    #' @param tool (`character(1)`)\cr
    #' Tool name.
    #' @param pkg (`character(1)`)\cr
    #' Package name tool belongs to (for config lookup).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(tool, pkg) {
      tool <- tolower(tool)
      self$tool <- tool
      self$pkg <- pkg
      self$config <- self$read()
      self$raw_schemas_all <- self$get_schemas_all("raw")
    },
    #' @description Print details about the Config.
    #' @param ... (ignored).
    #' @return (`R6::R6Class()`)\cr
    #' R6 object invisibly.
    print = function(...) {
      res <- tibble::tribble(
        ~var   , ~value                                   ,
        "tool" , self$tool                                ,
        "pkg"  , self$pkg                                 ,
        "nraw" , as.character(nrow(self$raw_schemas_all))
      )
      cat(glue("#--- Config {self$pkg}::{self$tool} ---#\n"))
      print(knitr::kable(res))
      invisible(self)
    },
    #' @description Read schema.yaml config.
    #' @return (`list()`)\cr
    #' Parsed YAML as a list of table schemas.
    read = function() {
      pkg_config_path <- system.file("config/tools", package = self$pkg)
      stopifnot(dir.exists(pkg_config_path))
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
      stopifnot("tables" %in% names(cfg))
      cfg
    },
    #' @description Return all output file patterns.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `pattern`.
    get_patterns = function() {
      self$config[["tables"]] |>
        purrr::map("pattern") |>
        tibble::enframe(value = "pattern") |>
        tidyr::unnest("pattern")
    },
    #' @description Return all output file types.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `ftype`.
    get_ftypes = function() {
      self$config[["tables"]] |>
        purrr::map("ftype") |>
        tibble::enframe(value = "ftype") |>
        tidyr::unnest("ftype")
    },
    #' @description Return ftype for a specific table.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @return (`character(1)`)\cr
    #' File type.
    get_ftype = function(x) {
      tabs <- self$config[["tables"]]
      assertthat::assert_that(
        x %in% names(tabs),
        msg = glue("{x} not found in tables for {self$tool}.")
      )
      tabs[[x]][["ftype"]]
    },
    #' @description Return all table descriptions.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `description`.
    get_descriptions = function() {
      self$config[["tables"]] |>
        purrr::map("description") |>
        tibble::enframe(value = "description") |>
        tidyr::unnest("description")
    },
    #' @description Return all raw or tidy schemas.
    #' @param raw_or_tidy (`character(1)`)\cr
    #' Either the raw or the tidy schema.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, and `schema`
    #' (list-col of tibble(field, type) using raw or tidy column names).
    get_schemas_all = function(raw_or_tidy = "raw") {
      tabs <- self$config[["tables"]]
      .get_schema <- function(tab, tab_name) {
        cols_df <- tab[["columns"]] |>
          purrr::map(tibble::as_tibble_row) |>
          dplyr::bind_rows()
        description <- tibble::tibble(tbl_description = tab[["description"]])
        versions <- config_sort_versions(unique(cols_df[["since"]]))
        .get_schema_per_version <- function(v) {
          v_idx <- which(versions == v)
          valid_since <- versions[seq_len(v_idx)]
          cols_v <- cols_df |>
            dplyr::filter(.data$since %in% valid_since) |>
            dplyr::mutate(type = schema_type_remap(.data$type)) |>
            dplyr::select(field = dplyr::all_of({{ raw_or_tidy }}), "type")
          tibble::tibble(version = v, schema = list(cols_v))
        }
        schema_rows <- purrr::map(versions, \(v) .get_schema_per_version(v)) |>
          dplyr::bind_rows()
        dplyr::bind_cols(description, schema_rows) |>
          dplyr::mutate(name = tab_name, .before = 1)
      }
      tabs |>
        purrr::imap(\(tab, tab_name) .get_schema(tab, tab_name)) |>
        dplyr::bind_rows()
    },
    #' @description Get raw schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param v (`character(1)`)\cr
    #' Version. If NULL, returns all versions.
    #' @param raw_or_tidy (`character(1)`)\cr
    #' Either the raw or the tidy schema.
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema = function(x = NULL, v = NULL, raw_or_tidy = "raw") {
      stopifnot(!is.null(x))
      s <- self$get_schemas_all(raw_or_tidy = raw_or_tidy)
      assertthat::assert_that(
        x %in% s[["name"]],
        msg = glue("{x} not found in schemas for {self$tool}.")
      )
      res <- s |>
        dplyr::filter(.data$name == x)
      if (!is.null(v)) {
        assertthat::assert_that(
          v %in% res[["version"]],
          msg = glue("{v} not found in versions for {x} in {self$tool}.")
        )
        res <- res |>
          dplyr::filter(.data$version == v)
      }
      res |>
        tidyr::unnest("schema") |>
        dplyr::select("version", "field", "type")
    },
    #' @description Validate schemas.
    #' @return (`logical(1)`)\cr
    #' TRUE or FALSE.
    are_schemas_valid = function() {
      valid_types <- c(char = "c", int = "i", float = "d")
      valid_types_print <- glue::glue_collapse(valid_types, sep = ", ", last = " or ")
      s <- self$raw_schemas_all
      invalid <- s |>
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
        msg2 <- glue(
          "Field types need to be one of: {valid_types_print}\n",
          "Check the following in the {self$tool} config:\n{msg1}"
        )
        warning(msg2)
        return(FALSE)
      }
      return(TRUE)
    },
    #' @description Get column mapping (raw -> tidy) for a table.
    #' Used for tables with custom parse logic (e.g. csv-nohead-long).
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param v (`character(1)`)\cr
    #' Version. If NULL, uses the latest version.
    get_col_map = function(x = NULL, v = NULL) {
      stopifnot(!is.null(x))
      tabs <- self$config[["tables"]]
      assertthat::assert_that(
        x %in% names(tabs),
        msg = glue("{x} not found in tables for {self$tool}.")
      )
      cols_df <- tabs[[x]][["columns"]] |>
        purrr::map(tibble::as_tibble_row) |>
        dplyr::bind_rows()
      versions <- config_sort_versions(unique(cols_df[["since"]]))
      if (is.null(v)) {
        v <- versions[length(versions)]
      }
      assertthat::assert_that(
        v %in% versions,
        msg = glue("{v} not found in versions for {x} in {self$tool}.")
      )
      v_idx <- which(versions == v)
      valid_since <- versions[seq_len(v_idx)]
      cols_df |>
        dplyr::filter(.data$since %in% valid_since) |>
        dplyr::mutate(type = schema_type_remap(.data$type)) |>
        dplyr::select("raw", "tidy", "type", "description")
    }
  ) # end public
)

#' Sort version strings with "latest" always last
#'
#' @param versions (`character(n)`)\cr
#' Vector of version strings (e.g. `c("v1.2.3", "latest")`).
#' @returns Sorted character vector with `"latest"` last.
#' @keywords internal
config_sort_versions <- function(versions) {
  non_latest <- sort(versions[versions != "latest"])
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
  cmd <- glue("sed -i '' \"s/'''/'/g\" {out}")
  system(cmd)
}
