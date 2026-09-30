test_that("reactable_schema escapes schema text in HTML", {
  skip_if_not_installed("reactable")
  skip_if_not_installed("htmltools")
  d <- nemo_schemavis_data("tool1", pkg = "nemo")
  d$columns[[1]]$description[1] <- "<script>x</script> & y"
  html <- as.character(htmltools::renderTags(reactable_schema(d))$html)
  expect_false(grepl("<script>x</script>", html, fixed = TRUE))
})

test_that("schema_columns_detail marks per-version column presence", {
  skip_if_not_installed("reactable")
  skip_if_not_installed("htmltools")
  d <- nemo_schemavis_data("tool1", pkg = "nemo")
  i <- which(d$tbl == "table1")
  expect_equal(d$versions[[i]], c("v1.2.3", "v4.5.6", "latest"))
  html <- as.character(
    htmltools::renderTags(schema_columns_detail(d$columns[[i]], d$versions[[i]], d$glob[[i]]))$html
  )
  expect_true(grepl("*.tool1.table1.tsv", html, fixed = TRUE))
})
