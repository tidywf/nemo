#' Command line interface for nemo
#'
#' Creates a command line interface (CLI) for the nemo package using the
#' argparse package.
#'
#' @param pkg (`character(1)`)\cr
#' Package name.
#' @param descr (`character(1)`)\cr
#' Description of the CLI program.
#' @param wf (`character(1)`)\cr
#' Workflow name.
#' @export
nemo_cli <- function(pkg, descr, wf = NULL) {
  stopifnot(pkg_found(pkg))
  nemo_assert_not_null(descr)
  prog_nm <- paste0(pkg, ".R")
  version <- as.character(utils::packageVersion(pkg))
  p <- argparse::ArgumentParser(
    description = descr,
    prog = prog_nm,
    python_cmd = get_python()
  )
  p$add_argument("-v", "--version", action = "version", version = paste(pkg, version))
  subparser_name <- "subparser_name"
  subp <- p$add_subparsers(help = "sub-command help", dest = subparser_name)
  cli_tidy_add_args(subp, wf = wf)
  cli_list_add_args(subp, wf = wf)
  args <- p$parse_args()

  if (length(args$subparser_name) == 0) {
    p$print_help()
  } else if (args$subparser_name == "tidy") {
    cli_tidy_parse_args(args, wf)
  } else if (args$subparser_name == "list") {
    cli_list_parse_args(args, wf)
  } else {
    all_subp <- c("'tidy'", "'list'") |>
      glue::glue_collapse(sep = ", ", last = " or ")
    stop("Need to specify one of the following: ", all_subp)
  }
}
