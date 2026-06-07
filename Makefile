.PHONY: all pkgdown test

readme:
	@quarto render README.qmd

air:
	@air format

pkgdown:
	@R -e "pkgdown::build_site()" --quiet --no-restore --no-save

readme-pkgdown: readme pkgdown

roxydoc:
	@R -e "devtools::document()" --quiet --no-restore --no-save

build:
	@R -e "pak::local_install(upgrade = FALSE, dependencies = FALSE)" --quiet --no-restore --no-save

build-readme: build readme

bump:
ifndef VERSION
	$(error VERSION is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
ifndef BRANCH
	$(error BRANCH is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
	@gh workflow run bump.yaml --ref $(BRANCH) --field version=$(VERSION)

test:
	@R -e "devtools::test()" --no-restore --no-save

check:
	@R -e "devtools::check()" --no-restore --no-save
