test_that("reactable_schema escapes schema text in HTML", {
  skip_if_not_installed("reactable")
  skip_if_not_installed("htmltools")
  d <- nemo_schemavis_data("tool1", pkg = "nemo")
  sv <- d$schema_version[[1]]
  sv$schema[[1]]$description[1] <- "<script>x</script> & y"
  d$schema_version[[1]] <- sv
  html <- as.character(htmltools::renderTags(reactable_schema(d))$html)
  expect_false(grepl("<script>x</script>", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;x&lt;/script&gt; &amp; y", html, fixed = TRUE))
})
