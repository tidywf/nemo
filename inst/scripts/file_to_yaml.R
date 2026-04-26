# Generate a skeleton schema.yaml for a new tool.
# Auto-detects raw column names and types from sample files.
# Fill in 'tidy', 'description', and 'since' placeholders manually before use.
{
  use("glue", "glue")
  use("tibble", "tribble")
  use("dplyr")
  use("purrr", "map")
  use("here", "here")
  use("fs", "dir_create")
  use("nemo", c("config_prep_raw_schema", "config_prep_write"))
}

tool <- "tool1"
d1 <- here(glue("inst/extdata/{tool}/latest"))

d <- tibble::tribble(
  ~name    , ~descr                   , ~pat                       , ~ftype , ~path                      ,
  "table1" , "Description of table1." , "\\.tool1\\.table1\\.tsv$" , "txt"  , "sampleA.tool1.table1.tsv" ,
  "table2" , "Description of table2." , "\\.tool1\\.table2\\.tsv$" , "txt"  , "sampleA.tool1.table2.tsv" ,
) |>
  dplyr::mutate(path = file.path(d1, .data$path))

strip_quotes <- function(x) gsub("'", "", x)

build_columns <- function(raw_schema) {
  purrr::map(seq_len(nrow(raw_schema)), function(i) {
    raw_nm <- strip_quotes(raw_schema$field[i])
    list(
      raw = glue("'{raw_nm}'"),
      tidy = glue("'{tolower(raw_nm)}'"),
      type = raw_schema$type[i],
      description = "'TODO'",
      since = "'latest'"
    )
  })
}

tables <- d |>
  dplyr::rowwise() |>
  dplyr::mutate(
    raw_schema = list(config_prep_raw_schema(.data$path, delim = "\t")),
    columns = list(build_columns(.data$raw_schema))
  ) |>
  dplyr::ungroup()

cfg <- list(
  tables = purrr::set_names(
    purrr::map(seq_len(nrow(tables)), function(i) {
      pat <- tables$pat[i]
      attr(pat, "quoted") <- TRUE
      list(
        description = glue("'{tables$descr[i]}'"),
        pattern = pat,
        ftype = glue("'{tables$ftype[i]}'"),
        columns = tables$columns[[i]]
      )
    }),
    tables$name
  )
)

out_dir <- here(glue("inst/config/tools/_tmp"))
fs::dir_create(out_dir)
out <- file.path(out_dir, glue("{tool}.schema.yaml"))
config_prep_write(cfg, out)
message("Written: ", out)
