#' @title Workflow1 Object
#'
#' @description
#' Pre-configured `Workflow` bundling `Tool1`.
#'
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' wf <- Workflow1$new(path)
#' (lf_all <- wf$list_files())
#' dir1 <- tempdir()
#' wf$wrangle(output_dir = dir1, format = "parquet", input_id = "run1")
#' (lf <- list.files(dir1, pattern = "tool1.*parquet", full.names = TRUE))
#' @testexamples
#' # initialize
#' expect_equal(length(wf$tools), 1)
#' expect_equal(wf$tools[[1]]$name, "tool1")
#' # list_files: all parsers present
#' expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% lf_all$tool_parser))
#' # wrangle: two table4 output files (one per version)
#' expect_equal(sum(grepl("table4", basename(lf))), 2)
#' @export
Workflow1 <- R6::R6Class(
  "Workflow1",
  inherit = Workflow,
  public = list(
    #' @description Create a new Workflow1 object.
    #' @param path (`character(n)`)\cr
    #' Path(s) to Workflow1 results.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(path) {
      tools <- list(
        tool1 = Tool1
      )
      super$initialize(name = "Workflow1", path = path, tools = tools)
    }
  ) # public end
)
