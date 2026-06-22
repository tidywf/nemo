.PHONY: all pkgdown test

air:
	@air format

readme:
	@quarto render README.qmd

pkgdown:
	@R -e "pkgdown::build_site()" --quiet --no-restore --no-save && mv docs nogit/pkgdown_site/ && open nogit/pkgdown_site/docs/dev/index.html

readme-pkgdown: readme pkgdown

roxydoc:
	@R -e "devtools::document()" --quiet --no-restore --no-save

build:
	@R -e "pak::local_install(upgrade = FALSE, dependencies = FALSE)" --quiet --no-restore --no-save

build-readme: build readme

test:
	@R -e "devtools::test()" --quiet --no-restore --no-save

check:
	@R -e "devtools::check()" --quiet --no-restore --no-save

full: roxydoc test build check

bump:
ifndef VERSION
	$(error VERSION is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
ifndef BRANCH
	$(error BRANCH is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
	@gh workflow run bump.yaml --ref $(BRANCH) --field version=$(VERSION)

