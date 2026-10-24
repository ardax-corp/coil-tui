# coil-tui — run package tests and the format check.
#
# Targets:
#   make test   — coil test harness (needs `coil` on PATH)
#   make fmt    — check formatting of src/ and tests/
#
# Needs coil-stdlib and coil-cli checkouts next to this one, or their
# `src` directories passed in COIL_ROOTS.

.PHONY: all test fmt

COIL ?= coil
COIL_ROOTS ?= --root ../coil-stdlib/src --root ../coil-cli/src
COIL_TEST_FLAGS ?=

all: test

test:
	$(COIL) test $(COIL_TEST_FLAGS) $(COIL_ROOTS)

fmt:
	$(COIL) fmt --check src tests
