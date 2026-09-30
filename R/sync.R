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
  # patterns come from config, so an empty dir suffices
  tmp <- fs::file_temp()
  fs::dir_create(tmp)
  on.exit(fs::dir_delete(tmp), add = TRUE)
  fun$new(tmp)$get_sync_patterns()
}

# Resolve a package resource dir when installed or under load_all(), where
# system.file() points at the source root and resources live under inst/.
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
#' Translates an `aws s3 sync` glob into an anchored regex, following Python's
#' `fnmatch` (which `aws s3 sync` filters use): `*` = any run of characters
#' (including `/` and the empty string), `?` = one character, `[seq]` = one
#' character in `seq` (ranges like `[0-9]` allowed), `[!seq]` = one character
#' not in `seq`, everything else literal. An unclosed `[` is literal. Used by
#' [schema_glob_check()]. The result is a PCRE regex: match with `perl = TRUE`
#' (escapes inside `[...]` are not portable to R's default TRE engine).
#'
#' @param x (`character(1)`)\cr
#' Glob pattern.
#' @returns (`character(1)`)\cr
#' Anchored PCRE regex equivalent.
#'
#' @examples
#' (r1 <- glob_to_regex("*.purple.qc"))
#' (r2 <- glob_to_regex("*purple/*.purple.qc"))
#' @testexamples
#' expect_true(grepl(r1, "sample1.purple.qc", perl = TRUE))
#' expect_true(grepl(r1, "a/b/sample1.purple.qc", perl = TRUE))
#' expect_false(grepl(r1, "sample1.purple.qc.bak", perl = TRUE))
#' expect_true(grepl(r2, "run/purple/sample1.purple.qc", perl = TRUE))
#' expect_false(grepl(r2, "run/amber/sample1.purple.qc", perl = TRUE))
#' expect_error(glob_to_regex(c("a", "b")))
#' # character classes
#' r3 <- glob_to_regex("*_R[12].fastq.gz")
#' expect_true(grepl(r3, "s1_R1.fastq.gz", perl = TRUE))
#' expect_false(grepl(r3, "s1_R3.fastq.gz", perl = TRUE))
#' r4 <- glob_to_regex("chr[!XY].tsv")
#' expect_true(grepl(r4, "chr1.tsv", perl = TRUE))
#' expect_false(grepl(r4, "chrX.tsv", perl = TRUE))
#' expect_true(grepl(glob_to_regex("s[0-9]x"), "s7x", perl = TRUE))
#' expect_true(grepl(glob_to_regex("a[]]b"), "a]b", perl = TRUE))
#' expect_true(grepl(glob_to_regex("a[^]b"), "a^b", perl = TRUE))
#' expect_true(grepl(glob_to_regex("a[\\]b"), "a\\b", perl = TRUE))
#' # unclosed bracket and other metachars are literal
#' expect_true(grepl(glob_to_regex("a[b"), "a[b", perl = TRUE))
#' expect_true(grepl(glob_to_regex("a(b)+c|d"), "a(b)+c|d", perl = TRUE))
#' @export
glob_to_regex <- function(x) {
  nemo_assert_scalar_chr(x)
  # perl = TRUE: TRE treats a backslash inside [...] as literal
  esc_lit <- \(ch) gsub("([.\\\\+^$(){}\\[\\]|*?])", "\\\\\\1", ch, perl = TRUE)
  chars <- strsplit(x, "")[[1]]
  n <- length(chars)
  out <- character()
  i <- 1L
  while (i <= n) {
    ch <- chars[[i]]
    if (ch == "*") {
      out <- c(out, ".*")
    } else if (ch == "?") {
      out <- c(out, ".")
    } else if (ch == "[") {
      # find the closing ']'; a ']' right after '[' or '[!' is literal
      j <- i + 1L
      if (j <= n && chars[[j]] == "!") {
        j <- j + 1L
      }
      if (j <= n && chars[[j]] == "]") {
        j <- j + 1L
      }
      while (j <= n && chars[[j]] != "]") {
        j <- j + 1L
      }
      if (j > n) {
        out <- c(out, "\\[")
      } else {
        body <- chars[(i + 1L):(j - 1L)]
        neg <- body[[1]] == "!"
        if (neg) {
          body <- body[-1]
        }
        # inside a regex class only \ ^ [ ] need escaping ('-' keeps ranges)
        body <- gsub("([\\\\^\\[\\]])", "\\\\\\1", body, perl = TRUE)
        out <- c(out, paste0("[", if (neg) "^", paste(body, collapse = ""), "]"))
        i <- j
      }
    } else {
      out <- c(out, esc_lit(ch))
    }
    i <- i + 1L
  }
  paste0("^", paste(out, collapse = ""), "$")
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
      covered <- purrr::map(tbl_globs, \(g) grepl(glob_to_regex(g), hits, perl = TRUE)) |>
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
