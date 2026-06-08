#' Generate a Mermaid GitHub Actions flowchart
#'
#' @description
#' Reads the local `deploy.yaml` GHA file and fetches reusable GHA files from
#' the tidywf/actions repo to build a Mermaid flowchart of the full CI/CD pipeline.
#'
#' @param actions_url (`character(1)`)\cr
#' Base URL for raw reusable workflow YAML files in the tidywf/actions repo (see
#' example).
#' @param deploy_yaml (`character(1)`)\cr
#' Path to the `.github/workflows/deploy.yaml` file.
#'
#' @return A character string containing the Mermaid diagram.
#' @examples
#' # Real usage (requires network):
#' # repo <- "https://raw.githubusercontent.com/tidywf/actions/"
#' # actions_url <- paste0(repo, "refs/heads/main/.github/workflows")
#' # nemo_gha_mermaid(actions_url, here::here(".github/workflows/deploy.yaml"))
#' d <- tempfile() |> fs::dir_create()
#' bump_wf <- list(jobs = list(bump = list(steps = list(
#'   list(name = "Setup"), list(name = "Bump version")
#' ))))
#' job_wf <- list(jobs = list(deploy = list(steps = list(list(name = "Run deploy")))))
#' deploy_wf <- list(jobs = list(
#'   myjob = list(name = "My Job", uses = "org/repo/.github/workflows/myjob.yaml@main")
#' ))
#' yaml::write_yaml(bump_wf, file.path(d, "bump.yaml"))
#' yaml::write_yaml(job_wf, file.path(d, "myjob.yaml"))
#' yaml::write_yaml(deploy_wf, file.path(d, "deploy.yaml"))
#' diagram <- nemo_gha_mermaid(actions_url = d, deploy_yaml = file.path(d, "deploy.yaml"))
#' @testexamples
#' expect_true(grepl("flowchart TD", diagram, fixed = TRUE))
#' expect_true(grepl("Setup", diagram, fixed = TRUE))
#' expect_true(grepl("Run deploy", diagram, fixed = TRUE))
#' expect_true(grepl("B2 --> J1S1", diagram, fixed = TRUE))
#' @export
nemo_gha_mermaid <- function(actions_url, deploy_yaml) {
  dep <- yaml::read_yaml(deploy_yaml)
  jobs <- dep$jobs
  job_names <- names(jobs)
  job_labs <- job_names |>
    purrr::map_chr(\(j) {
      nm <- jobs[[j]][["name"]]
      if (is.null(nm) || is.na(nm)) j else as.character(nm)
    })
  job_wf_files <- job_names |>
    purrr::map_chr(\(j) {
      uses <- jobs[[j]][["uses"]] %||% paste0(j, ".yaml")
      basename(sub("@.*$", "", uses))
    })
  wf_url <- function(x) paste0(actions_url, "/", x)
  bump_steps <- .gha_read_steps(wf_url("bump.yaml"))
  deploy_steps <- purrr::map(job_wf_files, \(f) .gha_read_steps(wf_url(f))) |>
    rlang::set_names(job_names)
  i1 <- "    "
  i2 <- "        "
  bump_m <- .gha_render_steps(bump_steps, "B", i1)
  deploy_subgraph_lines <- character(0)
  deploy_ms <- list()
  for (i in seq_along(job_names)) {
    j <- job_names[i]
    prefix <- paste0("J", i, "S")
    m <- .gha_render_steps(deploy_steps[[j]], prefix, i2)
    deploy_ms[[j]] <- m
    deploy_subgraph_lines <- c(
      deploy_subgraph_lines,
      paste0(i2, "subgraph ", j, ' ["', job_labs[i], '"]'),
      m$lines,
      paste0(i2, "end")
    )
  }

  bump_last <- utils::tail(bump_m$ids, 1)
  deploy_first <- if (length(job_names) > 0) {
    utils::head(deploy_ms[[job_names[1]]]$ids, 1)
  } else {
    character(0)
  }
  bump_to_deploy <- if (length(bump_last) > 0 && length(deploy_first) > 0) {
    paste0(i1, bump_last, " --> ", deploy_first)
  } else {
    paste0(i1, "BUMP --> DEPLOY")
  }

  job_chain <- if (length(job_names) > 1) {
    purrr::map_chr(seq_len(length(job_names) - 1), \(k) {
      last_id <- utils::tail(deploy_ms[[job_names[k]]]$ids, 1)
      first_id <- utils::head(deploy_ms[[job_names[k + 1]]]$ids, 1)
      if (length(last_id) > 0 && length(first_id) > 0) {
        paste0(i2, last_id, " --> ", first_id)
      } else {
        paste0(i2, job_names[k], " --> ", job_names[k + 1])
      }
    })
  } else {
    character(0)
  }

  paste(
    c(
      "flowchart TD",
      "",
      paste0(i1, "subgraph BUMP [\"\U0001F527 Bump Version\"]"),
      bump_m$lines,
      paste0(i1, "end"),
      "",
      bump_to_deploy,
      "",
      paste0(i1, "subgraph DEPLOY [\"\U0001F527 Deploy\"]"),
      deploy_subgraph_lines,
      "",
      job_chain,
      paste0(i1, "end")
    ),
    collapse = "\n"
  )
}

.gha_skip_patterns <- c("app token", "codeout", "dvc setup", "dvc pull")

.gha_ignore_steps <- function(name) {
  grepl(paste(.gha_skip_patterns, collapse = "|"), tolower(name))
}

.gha_read_steps <- function(path) {
  if (!file.exists(path) && !grepl("^https://", path)) {
    return(character(0))
  }
  y <- yaml::read_yaml(path)
  all_steps <- purrr::map(y$jobs, "steps") |>
    purrr::compact() |>
    purrr::list_flatten()
  if (length(all_steps) == 0) {
    return(character(0))
  }
  nms <- all_steps |> purrr::map_chr("name", .default = "")
  nms[nzchar(nms) & !purrr::map_lgl(nms, .gha_ignore_steps)]
}

.gha_render_steps <- function(steps, prefix, indent) {
  ids <- paste0(prefix, seq_along(steps))
  nodes <- paste0(indent, ids, '["', steps, '"]')
  edges <- if (length(ids) > 1) {
    paste0(indent, ids[-length(ids)], " --> ", ids[-1])
  } else {
    character(0)
  }
  list(ids = ids, lines = c(nodes, edges))
}
