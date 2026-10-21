XML_FILE ?= draft-smyslov-ipsecme-ikev2-fragm-large-msg.xml

DOCNAME_FULL := $(shell xmllint --xpath "string(//rfc/@docName)" $(XML_FILE) 2>/dev/null)
DOCNAME_BASE := $(shell echo $(DOCNAME_FULL) | sed -E 's/-[0-9]+$$//')
VERSION := $(shell echo $(DOCNAME_FULL) | sed -E 's/.*-([0-9]{2})$$/\1/')

NEW_FILE := draft/$(DOCNAME_FULL)
LBASE := draft/$(DOCNAME_BASE)-latest
PBASE := publish/$(DOCNAME_FULL)

MAIN_BRANCH ?= main
PUSH_TO_REMOTE ?= origin

VERSION_NOZERO := $(shell echo "$(VERSION)" | sed -e 's/^0*//')
NEXT_VERSION := $(shell printf "%02d" "$$(($(VERSION_NOZERO) + 1))")
SBASE := $(patsubst draft-%,%,$(DOCNAME_BASE))
PBRANCH ?= publish-$(SBASE)-$(VERSION)

BRANCH_EXISTS := $(shell git rev-parse --verify $(MAIN_BRANCH) 2>/dev/null)

all: $(NEW_FILE).xml $(NEW_FILE).txt $(NEW_FILE).html $(LBASE).xml $(LBASE).txt $(LBASE).html

lint:
	@xmllint --format $(NEW_FILE).xml

rfcdiff:
	@rfcdiff --body --diff $(OLD_FILE).txt $(NEW_FILE).txt

.PHONY: all lint rfcdiff

$(NEW_FILE).html: $(XML_FILE)
	xml2rfc --cache /tmp --html $(NEW_FILE).xml

$(NEW_FILE).txt: $(XML_FILE)
	xml2rfc --cache /tmp --text $(NEW_FILE).xml

$(NEW_FILE).xml: $(XML_FILE)
	mkdir -p draft
	cp $(XML_FILE) $@

$(LBASE).%: $(NEW_FILE).%
	cp $< $@

.PHONY: git-clean-check
git-clean-check:
	@echo Checking for git clean status
	@STATUS="$$(git status -s)"; [[ -z "$$STATUS" ]] || echo "$$STATUS"

.PHONY: main-branch-check
main-branch-check:
ifeq ($(BRANCH_EXISTS),)
	$(error Branch '$(MAIN_BRANCH)' does not exist. Exiting.)
endif

.PHONY: push_to_remote
push_to_remote:
ifeq ($(strip $(PUSH_TO_REMOTE)),)
	@echo "PUSH_TO_REMOTE is not set. Skipping git push."
else
	git push $(PUSH_TO_REMOTE) $(PBRANCH)
	git push $(PUSH_TO_REMOTE) -f --tags
endif

.PHONY: publish
publish: main-branch-check git-clean-check $(NEW_FILE).xml $(NEW_FILE).txt $(NEW_FILE).html
	if [ -f $(PBASE).xml ]; then echo "$(PBASE).xml already present, increment version?"; exit 1; fi
	@mkdir -p publish
	cp $(NEW_FILE).xml $(NEW_FILE).txt $(NEW_FILE).html publish
	git checkout -b $(PBRANCH)
	git tag -m "publish-$(SBASE)-$(VERSION)" bp-$(PBRANCH)
	git add $(PBASE).xml $(PBASE).txt $(PBASE).html
	git commit -m "publish-$(SBASE)-$(VERSION)"
	git tag -m "published-$(SBASE)-$(VERSION)" published-$(SBASE)-$(VERSION)
	$(MAKE) PBRANCH=$(PBRANCH) push_to_remote
	git checkout $(MAIN_BRANCH)
	git merge --ff-only $(PBRANCH)
	sed -i -e 's/\(docName="$(DOCNAME_BASE)-\)$(VERSION)"/\1$(NEXT_VERSION)"/' $(XML_FILE)
	git commit -am "new version -$(NEXT_VERSION) post-publish $(SBASE)-$(VERSION)"
	$(MAKE) PBRANCH=$(MAIN_BRANCH) push_to_remote

debug:
	@echo "DOCNAME_FULL = [$(DOCNAME_FULL)]"
	@echo "DOCNAME_BASE = [$(DOCNAME_BASE)]"
	@echo "VERSION = [$(VERSION)]"
	@echo "NEW_FILE = [$(NEW_FILE)]"
