#' Generate a Mermaid GitHub Actions flowchart
#'
#' @description
#' Reads the local `deploy.yaml` GHA file and fetches reusable GHA files from
#' the tidywf/actions repo to build a Mermaid flowchart of the full CI/CD pipeline.
#'
#' @param deploy_yaml (`character(1)`)\cr
#' Path to the `.github/workflows/deploy.yaml` file.
#' @param actions_url (`character(1)`)\cr
#' Base URL for raw reusable workflow YAML files in the tidywf/actions repo (see
#' example).
#'
#'
#' @return A character string containing the Mermaid diagram.
#' @examples
#' #repo <- "https://raw.githubusercontent.com/tidywf/actions/"
#' #actions_url <- paste0(repo, "refs/heads/main/.github/workflows")
#' #deploy_yaml <- here::here(".github/workflows/deploy.yaml")
#' #nemo_gha_mermaid(actions_url, deploy_yaml)
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
    purrr::set_names(job_names)

  i1 <- "    "
  i2 <- "        "

  bump_m <- .gha_render_steps(bump_steps, "B", i1)

  deploy_subgraph_lines <- character(0)
  for (i in seq_along(job_names)) {
    j <- job_names[i]
    prefix <- paste0(toupper(substring(j, 1, 1)), "S")
    m <- .gha_render_steps(deploy_steps[[j]], prefix, i2)
    deploy_subgraph_lines <- c(
      deploy_subgraph_lines,
      paste0(i2, "subgraph ", j, ' ["', job_labs[i], '"]'),
      m$lines,
      paste0(i2, "end")
    )
  }

  job_chain <- if (length(job_names) > 1) {
    paste0(i2, job_names[-length(job_names)], " --> ", job_names[-1])
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
      paste0(i1, 'BUMP --> DEPLOY'),
      "",
      paste0(i1, "subgraph DEPLOY [\"\U0001F527 conda-docs\"]"),
      deploy_subgraph_lines,
      "",
      job_chain,
      paste0(i1, "end")
    ),
    collapse = "\n"
  )
}

.gha_ignore_steps <- function(name) {
  ignore <- c(
    "app token",
    "codeout",
    "dvc setup",
    "dvc pull"
  )
  lname <- tolower(name)
  any(purrr::map_lgl(ignore, \(p) grepl(p, lname, fixed = TRUE)))
}

.gha_read_steps <- function(path) {
  if (!file.exists(path) && !grepl("^https://", path)) {
    return(character(0))
  }
  y <- yaml::read_yaml(path)
  steps <- y$jobs[[1]]$steps
  nms <- steps |> purrr::map_chr("name", .default = "")
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
