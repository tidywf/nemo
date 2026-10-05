.PHONY: all pkgdown test check-pushed bump

air:
	@air format .

readme:
	@quarto render README.qmd

pkgdown:
	@R -e "pkgdown::build_site()" --quiet --no-restore --no-save

readme-pkgdown: readme pkgdown

roxydoc:
	@R -e "devtools::document()" --quiet --no-restore --no-save

install:
	@R CMD INSTALL --no-multiarch .

install-readme: install readme

test:
	@R -e "devtools::test()" --quiet --no-restore --no-save

check:
	@R -e "devtools::check()" --quiet --no-restore --no-save

full: roxydoc test install check

check-pushed:
ifndef BRANCH
	$(error BRANCH is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
	@git fetch --quiet origin $(BRANCH)
	@unpushed=$$(git rev-list --count origin/$(BRANCH)..$(BRANCH)); \
	if [ "$$unpushed" -ne 0 ]; then \
		echo "Error: $$unpushed local commit(s) on '$(BRANCH)' not pushed to origin. Push before bumping."; \
		exit 1; \
	fi
	@echo "'$(BRANCH)' is in sync with origin."

bump: check-pushed
ifndef VERSION
	$(error VERSION is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
	@gh workflow run bump.yaml --ref $(BRANCH) --field version=$(VERSION)

