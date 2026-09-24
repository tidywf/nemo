#' Sentinel prefix for schema tables with no file of their own
#'
#' Some schema tables are derived from a parent table's file rather than parsed
#' from a file of their own (e.g. the DRAGEN FASTQC positional tables). Their
#' `pattern` is set to `__no_file_match__<table>` so they never match a real
#' file, and they carry no `glob`.
#' @noRd
NEMO_NO_FILE_MATCH <- "__no_file_match__"

#' S3 Sync Patterns for a Workflow
#'
#' Builds the `aws s3 sync` include/exclude pattern tibble for a workflow,
#' from the `glob` fields declared by each of its tool's `schema.yaml`.
#' This is the single source of truth for "which files does this workflow need?"
#' Downstream callers (`tidywigits::s3sync()`, `tidydragen::s3sync()`, the nemo
#' Lambda) should use it rather than maintaining their own copies.
#'
#' @param workflow (`character(1)`)\cr
#' Workflow name (e.g. `"wigits"`, `"dragen"`), as accepted by
#' [nemoverse_wf_dispatch()].
#' @returns (`tibble()`)\cr
#' Tibble with `inex` (`"in"`/`"ex"`) and `pat` columns, suitable for
#' [s3sync()]'s `pats` argument.
#'
#' @examples
#' (pats <- wf_sync_patterns("workflow1"))
#' @testexamples
#' expect_equal(names(pats), c("inex", "pat"))
#' expect_equal(pats$inex[1], "ex")
#' expect_equal(pats$pat[1], "*")
#' expect_gt(nrow(pats), 1)
#' expect_error(wf_sync_patterns("notaworkflow"))
#' @export
wf_sync_patterns <- function(workflow) {
  fun <- nemoverse_wf_dispatch(workflow)
  # Workflow$new can just take a tmp dir to access patterns
  tmp <- fs::file_temp()
  fs::dir_create(tmp)
  on.exit(fs::dir_delete(tmp), add = TRUE)
  fun$new(tmp)$get_sync_patterns()
}

# Resolve a package resource directory in both installed and dev contexts.
# pkgload::load_all() points system.file() at the package *source* root, where
# resources still live under inst/, so a plain system.file("extdata") comes back
# empty unless the repo happens to carry a top-level symlink for it.
pkg_res_dir <- function(pkg, sub) {
  p <- system.file(sub, package = pkg)
  if (nzchar(p) && dir.exists(p)) {
    return(p)
  }
  root <- system.file(package = pkg)
  alt <- file.path(root, "inst", sub)
  if (nzchar(root) && dir.exists(alt)) {
    return(alt)
  }
  ""
}

#' Convert an S3 Sync Glob to a Regex
#'
#' Translates an `aws s3 sync` glob (`*` = any run of characters, `?` = one
#' character, everything else literal) into an anchored regex. Used by
#' [schema_glob_check()]; `aws s3 sync` filters are fnmatch-style, so `*` also
#' matches `/` and an empty string.
#'
#' @param x (`character(1)`)\cr
#' Glob pattern.
#' @returns (`character(1)`)\cr
#' Anchored regex equivalent.
#'
#' @examples
#' (r1 <- glob_to_regex("*.purple.qc"))
#' (r2 <- glob_to_regex("*purple/*.purple.qc"))
#' @testexamples
#' expect_true(grepl(r1, "sample1.purple.qc"))
#' expect_true(grepl(r1, "a/b/sample1.purple.qc"))
#' expect_false(grepl(r1, "sample1.purple.qc.bak"))
#' expect_true(grepl(r2, "run/purple/sample1.purple.qc"))
#' expect_false(grepl(r2, "run/amber/sample1.purple.qc"))
#' expect_error(glob_to_regex(c("a", "b")))
#' @export
glob_to_regex <- function(x) {
  nemo_assert_scalar_chr(x)
  # escape every regex metacharacter, then re-open the two glob wildcards
  esc <- gsub("([.\\\\+^$(){}\\[\\]|])", "\\\\\\1", x)
  esc <- gsub("*", ".*", esc, fixed = TRUE)
  esc <- gsub("?", ".", esc, fixed = TRUE)
  paste0("^", esc, "$")
}

#' Check Schema Globs Against Schema Patterns
#'
#' Guards the `glob` fields in a package's `schema.yaml` files against drifting
#' away from their `pattern` fields. For every table, each test-fixture file
#' that `pattern` matches must also be matched by at least one `glob` —
#' otherwise that file would never be synced down and the parser would silently
#' see nothing.
#'
#' Only the too-narrow direction is checked: a `glob` wider than its `pattern`
#' merely syncs a few extra files, which the parsers ignore.
#'
#' `pattern` is matched against basenames (as `Tool` does when discovering
#' files) while `glob` is matched against the path relative to `fixture_dir`
#' (as `aws s3 sync` matches keys relative to the sync root), so a glob may be
#' tightened with a directory prefix without failing this check.
#'
#' @param pkg (`character(1)`)\cr
#' Package name whose schemas to check.
#' @param fixture_dir (`character(1)`)\cr
#' Directory of test fixtures to match against. Defaults to the package's
#' `extdata`.
#' @returns (`tibble()`)\cr
#' One row per (tool, table, file) that `pattern` matches but no `glob` does.
#' Zero rows means the schemas are consistent.
#'
#' @examples
#' (bad <- schema_glob_check("nemo"))
#' @testexamples
#' expect_equal(nrow(bad), 0)
#' expect_named(bad, c("tool", "table", "file"))
#' expect_error(schema_glob_check("nemo", fixture_dir = "/no/such/dir"))
#' @export
schema_glob_check <- function(pkg, fixture_dir = NULL) {
  nemo_assert_scalar_chr(pkg)
  fixture_dir <- fixture_dir %||% pkg_res_dir(pkg, "extdata")
  if (!dir.exists(fixture_dir)) {
    nemo_stop(glue("Fixture directory not found: {fixture_dir}"))
  }
  rel <- list.files(fixture_dir, recursive = TRUE)
  tools <- list.dirs(
    pkg_res_dir(pkg, "config/tools"),
    recursive = FALSE,
    full.names = FALSE
  )
  empty <- tibble::tibble(tool = character(), table = character(), file = character())
  res <- purrr::map(tools, \(tool) {
    conf <- Config$new(tool, pkg)
    globs <- conf$get_globs()
    purrr::map(conf$get_tables() |> names(), \(tbl) {
      pat <- conf$get_pattern(tbl)
      if (startsWith(pat, NEMO_NO_FILE_MATCH)) {
        return(NULL)
      }
      hits <- rel[grepl(pat, basename(rel), perl = TRUE)]
      if (length(hits) == 0) {
        return(NULL)
      }
      tbl_globs <- globs[globs[["name"]] == tbl, ][["glob"]]
      covered <- purrr::map(tbl_globs, \(g) grepl(glob_to_regex(g), hits)) |>
        purrr::reduce(`|`, .init = rep(FALSE, length(hits)))
      if (all(covered)) {
        return(NULL)
      }
      tibble::tibble(tool = tool, table = tbl, file = hits[!covered])
    }) |>
      purrr::compact() |>
      dplyr::bind_rows()
  }) |>
    purrr::compact()
  if (length(res) == 0) {
    return(empty)
  }
  out <- dplyr::bind_rows(res)
  if (nrow(out) == 0) empty else out
}
