#' Generate a Mermaid GitHub Actions flowchart
#'
#' @description
#' Builds a Mermaid flowchart of a repo's CI/CD pipeline from its local GHA
#' workflow files, laid out top to bottom. Each workflow is a subgraph headed by
#' its trigger, each job a single node listing its steps, and job edges follow
#' `needs:` (with redundant transitive edges removed). Jobs calling a reusable workflow (`uses:`) have
#' its steps fetched from the pinned `@ref`. Simple step conditions of the form
#' `inputs.x`, `!inputs.x` or `inputs.x == true|false` are evaluated against the
#' caller's `with:` and the reusable workflow's input defaults: steps that won't
#' run are dropped, steps whose condition can't be decided are marked `(if)`.
#'
#' @param wf_dir (`character(1)`)\cr
#' Path to the repo's `.github/workflows` directory.
#' @param workflows (`character()`)\cr
#' Workflow file names under `wf_dir`, in pipeline order. Consecutive workflows
#' are linked (e.g. bump pushes the tag that triggers deploy).
#' @param actions_dir (`character(1)`)\cr
#' Optional local directory holding the reusable workflow files. When `NULL`
#' (default) they're fetched from `raw.githubusercontent.com` at the ref pinned
#' in each `uses:`.
#' @param skip (`character()`)\cr
#' Case-insensitive regex patterns; matching step names are left out (setup
#' boilerplate repeated across jobs).
#'
#' @return A character string containing the Mermaid diagram.
#' @examples
#' # Real usage (requires network):
#' # nemo_gha_mermaid(here::here(".github/workflows"))
#' wf <- tempfile() |> fs::dir_create()
#' act <- tempfile() |> fs::dir_create()
#' ru <- function(f) paste0("org/actions/.github/workflows/", f, "@v1")
#' yaml::write_yaml(
#'   list(name = "Bump", on = list(workflow_dispatch = NULL), jobs = list(
#'     bump = list(uses = ru("bump.yaml"))
#'   )),
#'   file.path(wf, "bump.yaml")
#' )
#' yaml::write_yaml(
#'   list(name = "Deploy", on = list(push = list(tags = "v*")), jobs = list(
#'     prep = list(name = "Version", steps = list(list(run = "echo"))),
#'     build = list(name = "Build", needs = "prep", uses = ru("build.yaml")),
#'     docs = list(
#'       name = "Docs", needs = c("prep", "build"),
#'       uses = ru("docs.yaml"), with = list(extra = FALSE)
#'     ),
#'     img = list(name = "Image", needs = c("prep", "build"), uses = ru("img.yaml"))
#'   )),
#'   file.path(wf, "deploy.yaml")
#' )
#' steps <- function(...) list(jobs = list(j = list(steps = list(...))))
#' yaml::write_yaml(
#'   steps(list(name = "Codeout"), list(name = "Bump version"), list(name = "Push tag")),
#'   file.path(act, "bump.yaml")
#' )
#' yaml::write_yaml(steps(list(name = "Build pkg")), file.path(act, "build.yaml"))
#' yaml::write_yaml(steps(list(name = "Build image")), file.path(act, "img.yaml"))
#' docs <- steps(
#'   list(name = "Extra step", `if` = "inputs.extra == true"),
#'   list(name = "Maybe step", `if` = "github.event_name == 'push'"),
#'   list(name = "Build site")
#' )
#' docs$on <- list(workflow_call = list(inputs = list(extra = list(default = TRUE))))
#' yaml::write_yaml(docs, file.path(act, "docs.yaml"))
#' diagram <- nemo_gha_mermaid(wf, actions_dir = act)
#' @testexamples
#' expect_true(grepl("flowchart TD", diagram, fixed = TRUE))
#' # skip patterns and caller `with:` overriding an input default
#' expect_false(grepl("Codeout", diagram, fixed = TRUE))
#' expect_false(grepl("Extra step", diagram, fixed = TRUE))
#' # undecidable condition kept, marked
#' expect_true(grepl("Maybe step <i>(if)</i>", diagram, fixed = TRUE))
#' # one node per job, steps listed in its label
#' expect_true(grepl('W2J1["<b>Version</b>"]', diagram, fixed = TRUE))
#' expect_true(grepl("<b>Docs</b><br>", diagram, fixed = TRUE))
#' # needs: fan-out, no transitive prep -> docs edge, no docs -> img chain
#' expect_true(grepl("W2J2 --> W2J3", diagram, fixed = TRUE))
#' expect_true(grepl("W2J2 --> W2J4", diagram, fixed = TRUE))
#' expect_false(grepl("W2J1 --> W2J3", diagram, fixed = TRUE))
#' expect_false(grepl("W2J3 --> W2J4", diagram, fixed = TRUE))
#' # workflows chained via the next trigger
#' expect_true(grepl("W1 -.-> W2T", diagram, fixed = TRUE))
#' # unreadable reusable workflow surfaces in the diagram
#' fs::file_delete(file.path(act, "img.yaml"))
#' d2 <- suppressWarnings(nemo_gha_mermaid(wf, actions_dir = act))
#' expect_true(grepl("could not read img.yaml", d2, fixed = TRUE))
#' @export
nemo_gha_mermaid <- function(
  wf_dir,
  workflows = c("bump.yaml", "deploy.yaml"),
  actions_dir = NULL,
  skip = c("app token", "codeout", "miniforge setup", "qemu setup", "buildx setup", "cr login")
) {
  nemo_assert_scalar_chr(wf_dir)
  nemo_assert_chr(workflows)
  wfs <- purrr::imap(workflows, \(f, i) {
    .gha_workflow(file.path(wf_dir, f), wf_dir, actions_dir, skip, id = paste0("W", i))
  })
  i1 <- "    "
  links <- if (length(wfs) > 1) {
    purrr::map_chr(seq_len(length(wfs) - 1), \(k) {
      paste0(i1, wfs[[k]]$id, " -.-> ", wfs[[k + 1]]$id, "T")
    })
  } else {
    character(0)
  }
  paste(
    c(
      "flowchart TD",
      paste0(i1, "classDef trigger font-weight:bold"),
      paste0(i1, "classDef warn fill:#fff3cd,stroke:#e0a800"),
      purrr::map(wfs, .gha_render_workflow) |> unlist(),
      links
    ),
    collapse = "\n"
  )
}

# Workflow model: list(id, name, trigger, jobs), each job list(id, name, needs,
# steps) with steps a tibble of (label, class); class "" / "cond" / "warn".
.gha_workflow <- function(path, wf_dir, actions_dir, skip, id) {
  y <- .gha_read_yaml(path)
  if (is.null(y)) {
    nemo_stop(glue("Could not read workflow file {path}."))
  }
  jobs <- y[["jobs"]] %||% list()
  keys <- names(jobs)
  needs <- purrr::map(jobs, \(j) intersect(as.character(unlist(j[["needs"]])), keys)) |>
    .gha_reduce_needs()
  job_ids <- rlang::set_names(paste0(id, "J", seq_along(keys)), keys)
  list(
    id = id,
    name = y[["name"]] %||% basename(path),
    # yaml 1.1 reads the bare `on:` key as TRUE
    trigger = .gha_trigger_label(y[["on"]] %||% y[["TRUE"]]),
    jobs = purrr::map(keys, \(k) {
      list(
        id = job_ids[[k]],
        name = jobs[[k]][["name"]] %||% k,
        needs = unname(job_ids[needs[[k]]]),
        steps = .gha_job_steps(jobs[[k]], wf_dir, actions_dir, skip)
      )
    })
  )
}

.gha_job_steps <- function(job, wf_dir, actions_dir, skip) {
  uses <- job[["uses"]]
  if (is.null(uses)) {
    return(.gha_steps(job[["steps"]], inputs = list(), skip = skip))
  }
  src <- .gha_resolve_uses(uses, wf_dir, actions_dir)
  y <- .gha_read_yaml(src)
  if (is.null(y)) {
    return(tibble::tibble(label = paste("⚠️ could not read", basename(src)), class = "warn"))
  }
  defaults <- (y[["on"]] %||% y[["TRUE"]])[["workflow_call"]][["inputs"]] |>
    purrr::map("default") |>
    purrr::compact()
  inputs <- utils::modifyList(defaults, job[["with"]] %||% list())
  steps <- purrr::map(y[["jobs"]], "steps") |>
    purrr::compact() |>
    purrr::list_flatten()
  .gha_steps(steps, inputs = inputs, skip = skip)
}

.gha_steps <- function(steps, inputs, skip) {
  empty <- tibble::tibble(label = character(0), class = character(0))
  if (length(steps) == 0) {
    return(empty)
  }
  purrr::map(steps, \(s) {
    nm <- s[["name"]] %||% ""
    if (!nzchar(nm) || grepl(paste(skip, collapse = "|"), tolower(nm))) {
      return(NULL)
    }
    ok <- .gha_eval_if(s[["if"]], inputs)
    if (isFALSE(ok)) {
      return(NULL)
    }
    tibble::tibble(label = nm, class = if (is.na(ok)) "cond" else "")
  }) |>
    purrr::list_rbind(ptype = empty)
}

# TRUE/FALSE when the condition is a simple test on a known boolean input,
# NA when it can't be decided statically.
.gha_eval_if <- function(expr, inputs) {
  if (is.null(expr)) {
    return(TRUE)
  }
  e <- trimws(gsub("^\\$\\{\\{|\\}\\}$", "", trimws(as.character(expr))))
  re <- "^(!?)\\s*inputs\\.([A-Za-z0-9_-]+)\\s*(?:(==|!=)\\s*(true|false))?$"
  m <- regmatches(e, regexec(re, e, perl = TRUE))[[1]]
  if (length(m) == 0) {
    return(NA)
  }
  # unmatched optional groups can come back as NA or ""
  m[is.na(m)] <- ""
  v <- inputs[[m[3]]]
  if (!rlang::is_scalar_logical(v) || is.na(v)) {
    return(NA)
  }
  res <- if (m[4] == "==") {
    v == (m[5] == "true")
  } else if (m[4] == "!=") {
    v != (m[5] == "true")
  } else {
    v
  }
  if (m[2] == "!") !res else res
}

# drop needs already implied through another need (a -> b -> c: drop a -> c)
.gha_reduce_needs <- function(needs) {
  ancestors <- function(k, seen = character(0)) {
    p <- setdiff(needs[[k]], seen)
    unique(c(p, unlist(purrr::map(p, \(x) ancestors(x, c(seen, p))))))
  }
  purrr::map(needs, \(p) {
    p[!purrr::map_lgl(p, \(x) any(purrr::map_lgl(setdiff(p, x), \(y) x %in% ancestors(y))))]
  })
}

.gha_resolve_uses <- function(uses, wf_dir, actions_dir) {
  if (startsWith(uses, "./")) {
    # local reusable workflow, relative to the repo root
    return(file.path(dirname(dirname(wf_dir)), sub("^\\./", "", uses)))
  }
  m <- regmatches(uses, regexec("^([^/]+)/([^/]+)/(.+)@(.+)$", uses))[[1]]
  if (length(m) == 0) {
    return(uses)
  }
  if (!is.null(actions_dir)) {
    return(file.path(actions_dir, basename(m[4])))
  }
  glue("https://raw.githubusercontent.com/{m[2]}/{m[3]}/{m[5]}/{m[4]}")
}

.gha_read_yaml <- function(src) {
  # a 404 warns before erroring; only the error matters
  tryCatch(
    suppressWarnings(yaml::read_yaml(src)),
    error = function(e) {
      nemo_log("WARN", "Could not read workflow %s: %s", src, conditionMessage(e))
      NULL
    }
  )
}

.gha_trigger_label <- function(on) {
  if (is.character(on)) {
    on <- rlang::set_names(vector("list", length(on)), on)
  }
  if (length(on) == 0) {
    return("▶️ trigger")
  }
  lab <- purrr::imap_chr(on, \(v, k) {
    switch(
      k,
      workflow_dispatch = "manual dispatch",
      push = if (!is.null(v[["tags"]])) {
        "tag push"
      } else if (!is.null(v[["branches"]])) {
        paste("push to", paste(unlist(v[["branches"]]), collapse = ", "))
      } else {
        "push"
      },
      pull_request = "pull request",
      k
    )
  })
  paste("▶️", paste(lab, collapse = " / "))
}

.gha_render_workflow <- function(wf) {
  i1 <- "    "
  i2 <- "        "
  trig <- paste0(wf$id, "T")
  job_lines <- purrr::map_chr(wf$jobs, \(j) {
    paste0(
      i2,
      j$id,
      '["',
      .gha_job_label(j),
      '"]',
      if (any(j$steps$class == "warn")) ":::warn" else ""
    )
  })
  roots <- purrr::keep(wf$jobs, \(j) length(j$needs) == 0) |> purrr::map_chr("id")
  # recycle0: no needs -> no edge (paste0 otherwise drops the empty arg)
  edges <- c(
    paste0(i2, trig, " --> ", roots, recycle0 = TRUE),
    purrr::map(wf$jobs, \(j) paste0(i2, j$needs, " --> ", j$id, recycle0 = TRUE)) |> unlist()
  )
  c(
    "",
    paste0(i1, "subgraph ", wf$id, .gha_node(wf$name)),
    paste0(i2, "direction TB"),
    paste0(i2, trig, '(["', .gha_esc(wf$trigger), '"]):::trigger'),
    job_lines,
    edges,
    paste0(i1, "end")
  )
}

# bold job name, then one line per step; undecidable conditions get "(if)"
.gha_job_label <- function(j) {
  steps <- .gha_esc(j$steps$label)
  steps <- ifelse(j$steps$class == "cond", paste(steps, "<i>(if)</i>"), steps)
  paste0(
    "<b>",
    .gha_esc(j$name),
    "</b>",
    paste0("<br>", steps, collapse = "", recycle0 = TRUE)
  )
}

.gha_node <- function(x) paste0('["', .gha_esc(x), '"]')

# mermaid entity codes; labels are HTML, so escape markup chars too
.gha_esc <- function(x) {
  x |>
    gsub(pattern = "&", replacement = "#amp;", fixed = TRUE) |>
    gsub(pattern = '"', replacement = "#quot;", fixed = TRUE) |>
    gsub(pattern = "<", replacement = "#lt;", fixed = TRUE) |>
    gsub(pattern = ">", replacement = "#gt;", fixed = TRUE)
}
