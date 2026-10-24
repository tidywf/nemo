#' @title Config Object
#'
#' @description
#' Reads a tool's `schema.yaml` from `inst/config/tools/<tool>/` in the
#' package, exposing the raw/tidy schemas and column maps `Tool` uses for file
#' discovery and renaming. Fan-out `outputs` get their own schema rows, with
#' `parent` set to the file table. Schema format: see *new-tool* article.
#' @examples
#' tool <- "tool1"
#' pkg <- "nemo"
#' conf <- Config$new(tool, pkg)
#' (patterns <- conf$get_patterns())
#' (globs <- conf$get_globs())
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
#' (cm <- conf$get_col_map("table6"))
#' # table7 fans out into two outputs
#' (outs <- conf$get_outputs())
#' conf$get_table_outputs("table7")
#' conf$get_schema_tidy("table7dp")
#'
#' @testexamples
#' expect_equal(conf$get_table_outputs("table7"), c("table7main", "table7dp"))
#' expect_equal(conf$get_table_outputs("table1"), character())
#' expect_named(outs, c("name", "table", "description"))
#' expect_equal(outs$table[outs$name == "table7dp"], "table7")
#' expect_equal(outs$table[outs$name == "table1"], "table1")
#' expect_false("table7" %in% outs$name)
#' expect_equal(rs$parent[rs$name == "table7"][1], NA_character_)
#' expect_false("table7dp" %in% rs$name)
#' expect_equal(unique(ts$parent[ts$name == "table7dp"]), "table7")
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
      private$validate_tables()
      invalid <- private$collect_invalid_schema_types()
      if (nrow(invalid) > 0) {
        nemo_stop(private$format_invalid_types_msg(invalid))
      }
      private$cache <- new.env(parent = emptyenv())
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

    #' @description Return all output file globs. Derived tables (no file of
    #' their own, hence no `glob`) contribute no rows.
    #' @return (`tibble()`)\cr
    #' Table `name` and its `glob`.
    get_globs = function() {
      empty <- tibble::tibble(name = character(), glob = character())
      private$tables |>
        purrr::imap(\(tab, tab_name) {
          globs <- as.character(tab[["glob"]] %||% character())
          if (length(globs) == 0) {
            return(NULL)
          }
          tibble::tibble(name = tab_name, glob = globs)
        }) |>
        purrr::compact() |>
        # typed empty fallback: bind_rows() of nothing gives a 0x0 tibble
        (\(x) if (length(x) == 0) empty else dplyr::distinct(dplyr::bind_rows(x)))()
    },

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

    #' @description Return the output names declared under a table's
    #' `outputs`.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @return (`character(n)`)\cr
    #' Output names, or `character(0)` when the table has no `outputs`.
    get_table_outputs = function(x) {
      names(private$get_field_for_table(x, "outputs")) %||% character()
    },

    #' @description Return how strictly an output's tidy columns are checked.
    #' `"exact"` (default): exactly the columns of one schema version, in
    #' order. `"subset"`: any subset of them, in any order (for outputs whose
    #' columns depend on the data, e.g. wide pivots of the metrics present).
    #' @param x (`character(1)`)\cr
    #' Output name.
    #' @return (`character(1)`)\cr
    #' `"exact"` or `"subset"`.
    get_output_shape = function(x) {
      nemo_assert_scalar_chr(x)
      out <- purrr::detect(private$tables, \(tab) x %in% names(tab[["outputs"]]))
      if (is.null(out)) {
        nemo_stop(glue("{x} not found in outputs for {self$tool}."))
      }
      out[["outputs"]][[x]][["shape"]] %||% "exact"
    },

    #' @description Return every output table the tool writes: the declared
    #' `outputs` of a fan-out table, or the table itself otherwise.
    #' @return (`tibble()`)\cr
    #' Output `name`, its file `table` and `description`.
    get_outputs = function() {
      private$tables |>
        purrr::imap(\(tab, tab_name) {
          outs <- tab[["outputs"]]
          if (is.null(outs)) {
            return(tibble::tibble(
              name = tab_name,
              table = tab_name,
              description = tab[["description"]]
            ))
          }
          tibble::tibble(
            name = names(outs),
            table = tab_name,
            description = unname(purrr::map_chr(outs, "description"))
          )
        }) |>
        dplyr::bind_rows()
    },

    #' @description Return raw schemas for all tables, plus outputs that carry
    #' raw column names.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, `schema`
    #' (list-col of tibble(field, type)) and `parent` (file table of an
    #' output, `NA` for a file table).
    get_schemas_raw = function() private$schemas_raw,

    #' @description Return tidy schemas for all tables and outputs.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, `schema`
    #' (list-col of tibble(field, type)) and `parent` (file table of an
    #' output, `NA` for a file table).
    get_schemas_tidy = function() private$schemas_tidy,

    #' @description Return both raw and tidy schemas for all tables and
    #' outputs.
    #' @return (`tibble()`)\cr
    #' Table `name`, `tbl_description`, `version`, `schema`
    #' (list-col of tibble(raw, tidy, type, description); `raw` is `NA` for
    #' output columns without one) and `parent` (file table of an output, `NA`
    #' for a file table).
    get_schemas_both = function() private$schemas_both,

    #' @description Get raw schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string. If `NULL`, **all** versions are returned (unlike
    #' `get_col_map()`).
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_raw = function(x, version = NULL) {
      private$get_schema(x, version, "raw")
    },
    #' @description Get tidy schema for a specific table and optional version.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string. If `NULL`, **all** versions are returned (unlike
    #' `get_col_map()`).
    #' @return (`tibble()`)\cr
    #' Table `version`, `field` and `type`.
    get_schema_tidy = function(x, version = NULL) {
      private$get_schema(x, version, "tidy")
    },
    #' @description Get column mapping (raw -> tidy) for a table, e.g. for
    #' custom parse/tidy logic.
    #' @param x (`character(1)`)\cr
    #' Table name.
    #' @param version (`character(1)`)\cr
    #' Version string. If `NULL`, resolves to a single version: `"latest"` if
    #' defined, else the highest semver.
    #' @return (`tibble()`)\cr
    #' Tibble with columns `raw`, `tidy`, `type`, `description`.
    get_col_map = function(x, version = NULL) {
      private$get_schema_both_one(x, version) |>
        dplyr::select("raw", "tidy", "type", "description")
    }
  ), # end public
  private = list(
    tables = NULL,
    cache = NULL,
    schemas_raw = NULL,
    schemas_tidy = NULL,
    schemas_both = NULL,
    # Fail fast on missing keys: otherwise a missing `versions` silently drops
    # the column, and a missing `pattern`/`tidy` surfaces as an obscure
    # map_chr()/select() error far from the schema.
    validate_tables = function() {
      tab_keys <- c("description", "pattern", "ftype", "columns")
      col_keys <- c("raw", "tidy", "type", "versions")
      problems <- purrr::imap(private$tables, \(tab, tab_name) {
        # a fan-out table read by its own parse_<table>() may omit columns:
        # (Tool checks the method exists)
        keys <- if (is.null(tab[["outputs"]])) tab_keys else setdiff(tab_keys, "columns")
        missing_tab <- setdiff(keys, names(tab))
        not_string <- purrr::keep(
          c("description", "pattern", "ftype"),
          \(k) k %in% names(tab) && !rlang::is_string(tab[[k]])
        )
        col_probs <- purrr::imap(tab[["columns"]] %||% list(), \(col, i) {
          missing_col <- setdiff(col_keys, names(col))
          if (length(missing_col) == 0) {
            return(NULL)
          }
          glue(
            "{tab_name} -> column '{col[['raw']] %||% i}': ",
            "missing {glue::glue_collapse(missing_col, sep = ', ')}"
          )
        })
        c(
          if (length(missing_tab) > 0) {
            glue("{tab_name}: missing {glue::glue_collapse(missing_tab, sep = ', ')}")
          },
          if (length(not_string) > 0) {
            glue("{tab_name}: not a single string: {glue::glue_collapse(not_string, sep = ', ')}")
          },
          unlist(col_probs)
        )
      }) |>
        unlist()
      problems <- c(problems, private$validate_outputs())
      if (length(problems) > 0) {
        nemo_stop(glue(
          "Invalid schema.yaml for {self$pkg}::{self$tool}:\n",
          "{glue::glue_collapse(problems, sep = '\n')}"
        ))
      }
      invisible(TRUE)
    },
    # Output columns describe tidy output, so need `tidy` rather than `raw`.
    # Output names are written as <tool>_<output>, hence one namespace with
    # the table names.
    validate_outputs = function() {
      out_keys <- c("description", "columns")
      col_keys <- c("tidy", "type", "versions")
      tab_names <- names(private$tables)
      problems <- purrr::imap(private$tables, \(tab, tab_name) {
        outs <- tab[["outputs"]]
        if (is.null(outs)) {
          return(NULL)
        }
        if (
          !is.list(outs) || length(outs) == 0 || is.null(names(outs)) || !all(nzchar(names(outs)))
        ) {
          return(glue("{tab_name}: outputs must be a non-empty named map"))
        }
        clash <- intersect(names(outs), tab_names)
        out_probs <- purrr::imap(outs, \(out, out_name) {
          loc <- glue("{tab_name} -> output '{out_name}'")
          if (!is.list(out)) {
            return(glue("{loc}: must be a map"))
          }
          missing_out <- setdiff(out_keys, names(out))
          bad_shape <- !is.null(out[["shape"]]) && !isTRUE(out[["shape"]] %in% config_output_shapes)
          col_probs <- purrr::imap(out[["columns"]] %||% list(), \(col, i) {
            missing_col <- setdiff(col_keys, names(col))
            if (length(missing_col) == 0) {
              return(NULL)
            }
            glue(
              "{loc} -> column '{col[['tidy']] %||% i}': ",
              "missing {glue::glue_collapse(missing_col, sep = ', ')}"
            )
          })
          c(
            if (length(missing_out) > 0) {
              glue("{loc}: missing {glue::glue_collapse(missing_out, sep = ', ')}")
            },
            if (bad_shape) {
              glue(
                "{loc}: shape must be one of {glue::glue_collapse(config_output_shapes, sep = ', ')}"
              )
            },
            unlist(col_probs)
          )
        })
        c(
          if (length(clash) > 0) {
            glue(
              "{tab_name}: output name(s) clash with table name(s): {glue::glue_collapse(clash, sep = ', ')}"
            )
          },
          unlist(out_probs)
        )
      }) |>
        unlist()
      all_outs <- unlist(
        purrr::map(private$tables, \(tab) names(tab[["outputs"]])),
        use.names = FALSE
      )
      dup <- unique(all_outs[duplicated(all_outs)])
      c(
        problems,
        if (length(dup) > 0) {
          glue(
            "output name(s) declared by more than one table: {glue::glue_collapse(dup, sep = ', ')}"
          )
        }
      )
    },
    collect_invalid_schema_types = function() {
      private$tables |>
        purrr::imap(\(tab, tab_name) {
          out_cols <- purrr::imap(tab[["outputs"]] %||% list(), \(out, out_name) {
            purrr::map(out[["columns"]], \(col) {
              tibble::tibble(name = out_name, field = col[["tidy"]], type = col[["type"]])
            })
          })
          c(
            purrr::map(tab[["columns"]], \(col) {
              tibble::tibble(name = tab_name, field = col[["raw"]], type = col[["type"]])
            }),
            purrr::list_flatten(out_cols)
          )
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
        nemo_stop(glue("{version} not found in versions for {x} in {self$tool}."))
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
        nemo_stop(glue("Config directory not found for package '{self$pkg}': {pkg_config_path}"))
      }
      tool_path <- file.path(pkg_config_path, self$tool)
      if (!dir.exists(tool_path)) {
        nemo_stop(glue("No config for {self$tool} under {pkg_config_path}."))
      }
      schema_path <- file.path(tool_path, "schema.yaml")
      if (!file.exists(schema_path)) {
        nemo_stop(glue("schema.yaml not found for {self$tool} at {schema_path}."))
      }
      cfg <- yaml::read_yaml(schema_path)
      if (!"tables" %in% names(cfg)) {
        nemo_stop(glue("schema.yaml for {self$tool} is missing the top-level 'tables' key."))
      }
      cfg[["tables"]]
    },
    get_field_for_table = function(x, key) {
      nemo_assert_scalar_chr(x)
      if (!x %in% names(private$tables)) {
        nemo_stop(glue("{x} not found in tables for {self$tool}."))
      }
      private$tables[[x]][[key]]
    },
    get_field_for_all_tables = function(key) {
      purrr::map_chr(private$tables, \(x) x[[key]]) |>
        tibble::enframe(name = "name", value = key)
    },
    # One row per version of a file table or output (`parent` = its file table).
    compute_schema_rows = function(columns, name, description, parent = NA_character_) {
      cols_df <- columns |>
        purrr::map(\(col) {
          tibble::tibble(
            raw = col[["raw"]] %||% NA_character_,
            tidy = col[["tidy"]],
            type = col[["type"]],
            description = col[["description"]] %||% NA_character_,
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
          name = name,
          tbl_description = description,
          version = v,
          schema = list(cols_v),
          parent = parent
        )
      }) |>
        dplyr::bind_rows()
    },
    compute_schema_one = function(tab, tab_name) {
      outs <- purrr::imap(tab[["outputs"]] %||% list(), \(out, out_name) {
        private$compute_schema_rows(
          out[["columns"]],
          out_name,
          out[["description"]],
          parent = tab_name
        )
      })
      # no columns: (custom-parsed fan-out file) -> no schema rows of its own
      own <- if (length(tab[["columns"]]) > 0) {
        private$compute_schema_rows(tab[["columns"]], tab_name, tab[["description"]])
      }
      # unname: bind_rows() packs a named list of tibbles into df-columns
      dplyr::bind_rows(own, unname(outs))
    },
    compute_schemas = function() {
      private$tables |>
        purrr::imap(private$compute_schema_one) |>
        dplyr::bind_rows()
    },
    derive_schema = function(cache, side) {
      # outputs without raw names are never parsed from a file
      if (side == "raw") {
        cache <- dplyr::filter(cache, purrr::map_lgl(.data$schema, \(s) !anyNA(s[["raw"]])))
      }
      # field + type only: deframe()d straight into readr col specs
      cache |>
        dplyr::mutate(
          schema = purrr::map(
            .data$schema,
            \(s) dplyr::select(s, field = dplyr::all_of(side), "type")
          )
        )
    },
    # Schema lookups only read the schemas fixed at initialize(), and Tool
    # calls them per file (fan-out output checks, tidy renames), so memoise by
    # key. Errors are raised before anything is cached.
    cached = function(key, compute) {
      hit <- private$cache[[key]]
      if (!is.null(hit)) {
        return(hit)
      }
      val <- compute()
      assign(key, val, envir = private$cache)
      val
    },
    get_schema_both_one = function(x, version) {
      nemo_assert_scalar_chr(x)
      if (!is.null(version)) {
        nemo_assert_scalar_chr(version)
      }
      key <- paste("both", x, version %||% "<default>", sep = "\r")
      private$cached(key, \() {
        if (!x %in% private$schemas_both[["name"]]) {
          nemo_stop(glue("{x} not found in schemas for {self$tool}."))
        }
        rows <- private$schemas_both |> dplyr::filter(.data$name == x)
        version <- private$resolve_version(x, version, rows[["version"]])
        rows |>
          dplyr::filter(.data$version == .env$version) |>
          tidyr::unnest("schema")
      })
    },
    get_schema = function(x, version, side) {
      nemo_assert_scalar_chr(x)
      if (!is.null(version)) {
        nemo_assert_scalar_chr(version)
      }
      key <- paste(side, x, version %||% "<all>", sep = "\r")
      private$cached(key, \() {
        schemas <- private[[paste0("schemas_", side)]]
        if (!x %in% schemas[["name"]]) {
          nemo_stop(glue("{x} not found in schemas for {self$tool}."))
        }
        res <- schemas |>
          dplyr::filter(.data$name == x)
        if (!is.null(version)) {
          private$assert_version(x, version, res[["version"]])
          res <- res |>
            dplyr::filter(.data$version == .env$version)
        }
        res |>
          tidyr::unnest("schema") |>
          dplyr::select("version", "field", "type")
      })
    }
  ) # end private
)

schema_type_map <- c(char = "c", float = "d", int = "i")

config_output_shapes <- c("exact", "subset")

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
#' expect_equal(config_sort_versions(c("v1.25", "v1.4", "v2.0")), c("v1.4", "v1.25", "v2.0"))
#' expect_error(config_sort_versions(c("v1.2.3-beta", "latest")), "v1.2.3-beta")
#' @export
config_sort_versions <- function(versions) {
  non_latest <- versions[versions != "latest"]
  bad <- non_latest[!grepl("^[vV]?[0-9]+(\\.[0-9]+)*$", non_latest)]
  if (length(bad) > 0) {
    nemo_stop(glue(
      "Unsupported version string(s): {glue::glue_collapse(bad, sep = ', ')}. ",
      "Use 'latest' or numeric dotted versions (e.g. 'v1.2.3')."
    ))
  }
  non_latest <- non_latest[order(numeric_version(gsub("^[vV]", "", non_latest)))]
  c(non_latest, if ("latest" %in% versions) "latest")
}
