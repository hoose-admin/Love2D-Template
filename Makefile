.DEFAULT_GOAL := help

LOVE := $(shell command -v love 2>/dev/null || echo "$$HOME/.local/bin/love")

.PHONY: help play test install install-hooks setup validate eval eval-dry stats clean-log

help:  ## Show this help
	@awk 'BEGIN {FS=":.*##"; print "Targets:"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-18s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

play:  ## Run the game interactively (arrows/wasd to move, space to jump, escape to quit)
	$(LOVE) .

test:  ## Run the 30-second automated walk test; exits non-zero on regression
	$(LOVE) . --test-walk

setup: install install-hooks  ## Install Love2D and git hooks (one-time setup on a fresh clone)

install:  ## Install Love2D on macOS from love2d.org (see scripts/install-love2d.sh)
	scripts/install-love2d.sh

install-hooks:  ## Install the pre-commit audit hook into .git/hooks/
	scripts/install-hooks.sh

validate:  ## Lint every .claude/skills/*/SKILL.md against the template
	@for f in .claude/skills/*/SKILL.md; do \
		scripts/validate-skill.sh "$$f" || exit 1; \
	done

eval:  ## Run trigger fixtures via claude -p and score routing accuracy
	scripts/evaluate-skills.sh

eval-dry:  ## Parse fixtures and print the scoreboard shell without calling claude
	scripts/evaluate-skills.sh --dry-run

stats:  ## Summarize recent entries in .claude/skill-log.jsonl
	scripts/skill-stats.sh

clean-log:  ## Truncate .claude/skill-log.jsonl (use sparingly)
	: > .claude/skill-log.jsonl
	@echo "skill-log.jsonl reset"
