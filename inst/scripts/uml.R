use("nemo", "nemo_uml")
use("here", "here")

# dput(ls("package:nemo", pattern = "[A-Z].*")) # note: load pkg prior
nemo_uml(
  classes = c("Config", "Tool", "Tool1", "Workflow", "Workflow1"),
  out_dir = here::here("vignettes", "fig", "uml")
)
