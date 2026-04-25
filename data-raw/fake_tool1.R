tool1 <- list(
  # tsv: header present, tab-delimited
  table1 = list(
    list(
      version = "v1.2.3",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        Chromosome = c("chr1", "chr2", "chr3"),
        Start = c(10, 100, 1000),
        End = c(50, 500, 5000),
        metricX = c(0.1, 0.2, 0.3)
      )
    ),
    list(
      version = "latest",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        Chromosome = c("chr1", "chr2", "chr3"),
        Start = c(10, 100, 1000),
        End = c(50, 500, 5000),
        metricX = c(0.1, 0.2, 0.3),
        metricY = c(0.4, 0.5, 0.6),
        metricZ = c(0.7, 0.8, 0.9)
      )
    )
  ),
  # tsv: header present, tab-delimited (simpler, single version)
  table2 = list(
    list(
      version = "latest",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        metricA = c("a", "b", "c"),
        metricB = c(12.3, 4.56, 7.89)
      )
    )
  ),
  # keyvalue: two-column key=value pairs, tab-delimited, no header, pivots to single-row tibble
  table3 = list(
    list(
      version = "latest",
      format = "keyvalue",
      delim = "\t",
      data = tibble::tribble(
        ~key            , ~value    ,
        "SampleID"      , "sampleA" ,
        "QCStatus"      , "Pass"    ,
        "TotalReads"    , "10000"   ,
        "MappedReads"   , "9500"    ,
        "UnmappedReads" , "500"
      )
    )
  ),
  # txt-nohead: no header, positional columns, tab-delimited
  table4 = list(
    list(
      version = "latest",
      format = "txt-nohead",
      data = tibble::tibble(
        SampleID = c("sampleA", "sampleB"),
        Chromosome = c("chr1", "chr2"),
        Start = c(100L, 200L),
        End = c(500L, 800L),
        Depth = c(32.5, 18.1)
      )
    )
  ),
  # csv-nohead-long: no header, comma-delimited, long format with metric name column
  # mimics DRAGEN-style metrics files (category, rg, variable, count, pct)
  # includes TUMOR/NORMAL sections for both SUMMARY and PER RG
  table5 = list(
    list(
      version = "latest",
      format = "csv-nohead-long",
      # fmt: skip
      data = tibble::tribble(
        ~section,                      ~rg,               ~variable,         ~count,    ~pct,
        "TUMOR MAPPING/ALIGNING SUMMARY",  "",            "Total reads",    3000000,   100.00,
        "TUMOR MAPPING/ALIGNING SUMMARY",  "",            "Mapped reads",   2900000,    96.67,
        "TUMOR MAPPING/ALIGNING SUMMARY",  "",            "Unmapped reads",  100000,     3.33,
        "TUMOR MAPPING/ALIGNING SUMMARY",  "",            "Total bases",   450000000,      NA,
        "NORMAL MAPPING/ALIGNING SUMMARY", "",            "Total reads",    1500000,   100.00,
        "NORMAL MAPPING/ALIGNING SUMMARY", "",            "Mapped reads",   1460000,    97.33,
        "NORMAL MAPPING/ALIGNING SUMMARY", "",            "Unmapped reads",   40000,     2.67,
        "NORMAL MAPPING/ALIGNING SUMMARY", "",            "Total bases",   226500000,      NA,
        "TUMOR MAPPING/ALIGNING PER RG",   "BC01.1.FC1", "Total reads",    3000000,   100.00,
        "TUMOR MAPPING/ALIGNING PER RG",   "BC01.1.FC1", "Mapped reads",   2900000,    96.67,
        "TUMOR MAPPING/ALIGNING PER RG",   "BC01.1.FC1", "Unmapped reads",  100000,     3.33,
        "TUMOR MAPPING/ALIGNING PER RG",   "BC01.1.FC1", "Total bases",   450000000,      NA,
        "NORMAL MAPPING/ALIGNING PER RG",  "BC02.1.FC1", "Total reads",    1500000,   100.00,
        "NORMAL MAPPING/ALIGNING PER RG",  "BC02.1.FC1", "Mapped reads",   1460000,    97.33,
        "NORMAL MAPPING/ALIGNING PER RG",  "BC02.1.FC1", "Unmapped reads",   40000,     2.67,
        "NORMAL MAPPING/ALIGNING PER RG",  "BC02.1.FC1", "Total bases",   226500000,      NA
      )
    )
  )
)

purrr::map2(tool1, names(tool1), \(tab, tab_name) {
  stopifnot(length(tab_name) == 1)
  purrr::map(tab, \(entry) {
    odir <- here::here("inst/extdata", "tool1", entry$version) |>
      fs::dir_create()
    if (entry$format == "csv-nohead-long") {
      fname <- file.path(odir, glue::glue("sampleA.tool1.{tab_name}.csv"))
      readr::write_csv(entry$data, fname, col_names = FALSE, na = "")
    } else {
      fname <- file.path(odir, glue::glue("sampleA.tool1.{tab_name}.tsv"))
      has_header <- entry$format == "tsv"
      readr::write_tsv(entry$data, fname, col_names = has_header, na = "NA")
    }
  })
})
