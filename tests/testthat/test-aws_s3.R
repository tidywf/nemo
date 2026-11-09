pats <- tibble::tribble(
  ~inex , ~pat    ,
  "ex"  , "*"     ,
  "in"  , "*.tsv"
)

test_that("s3sync_args() default: no progress, errors only", {
  args <- s3sync_args("s3://b/r", "/tmp/d", pats)
  expect_equal(args[1:4], c("s3", "sync", shQuote("s3://b/r"), shQuote("/tmp/d")))
  expect_equal(args[5:8], c("--exclude", shQuote("*"), "--include", shQuote("*.tsv")))
  expect_true(all(c("--no-progress", "--only-show-errors") %in% args))
  expect_false("--dryrun" %in% args)
})

test_that("s3sync_args() quiet = FALSE shows per-file lines", {
  args <- s3sync_args("s3://b/r", "/tmp/d", pats, quiet = FALSE)
  expect_true("--no-progress" %in% args)
  expect_false("--only-show-errors" %in% args)
})

test_that("s3sync_args() dryrun output is not silenced by quiet", {
  args <- s3sync_args("s3://b/r", "/tmp/d", pats, dryrun = TRUE)
  expect_true("--dryrun" %in% args)
  expect_false("--only-show-errors" %in% args)
})
