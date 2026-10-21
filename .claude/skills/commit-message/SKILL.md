---
name: commit-message
description: Draft (and optionally create) a git commit message from the current changes, following this repo's commit conventions. Use when the user asks to commit, generate a commit message, or write a commit for their current changes.
---

# Commit message generator

Auto-drafts a commit message from whatever is currently staged/unstaged in the
working tree, matching this repo's commit style, then creates the commit if
the user wants it.

## Args

`$ARGUMENTS` may contain:
- Free text hints (e.g. a ticket number, "focus on the RBAC migration") — fold
  these into the message, don't just append them verbatim.
- `--dry-run` / `--preview` — only draft and show the message, do not stage or
  commit anything.
- Otherwise: draft the message AND create the commit (this invocation itself
  counts as the user's explicit request to commit, per the git safety rules
  in CLAUDE.md/system instructions — no need to ask again).

## Steps

1. Run in parallel:
   - `git status` (never `-uall`)
   - `git diff HEAD` (staged + unstaged) — if nothing is staged, diff will
     cover unstaged changes; also check untracked files from `git status`
   - `git log --oneline -10` to match this repo's existing message style
     (this repo favors short, why-focused subjects — see recent commits)
2. If there are no staged, unstaged, or relevant untracked changes, say so
   and stop. Do not fabricate a commit.
3. Read the actual diff content (not just filenames) to understand *why* the
   change was made, not just what changed. Skip files that look like secrets
   (`.env`, `credentials.json`, keys) — warn the user instead of staging them.
4. Draft a commit message:
   - Subject: imperative mood, concise, under ~70 chars, no trailing period.
   - Body (only if it adds information the subject can't carry): 1-3 bullets
     on *why*, not a restatement of the diff. Skip the body for small,
     self-explanatory changes.
   - Follow Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`,
     `chore:`, `test:`, `docs:`) only if recent `git log` output actually
     uses them — otherwise match the plain style already in this repo's
     history.
5. If `--dry-run`/`--preview` was passed: print the drafted message and stop.
6. Otherwise:
   - Stage the relevant files by name (never `git add -A`/`git add .`).
   - Create the commit with the drafted message via a heredoc, ending with:
     `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
   - Run `git status` after to confirm a clean result.
   - If a pre-commit hook fails, fix the underlying issue, re-stage, and
     create a new commit — never `--no-verify`.
7. Report back the final subject line (and body if any) in 1-2 sentences.
   Do not push — pushing requires a separate explicit request.

## Guardrails (from this repo's operating rules)

- Never use `-i` interactive git flags.
- Never amend an existing commit unless the user explicitly says "amend".
- Never force-push, reset --hard, or otherwise touch history as part of this
  skill.
- Only commit files relevant to the change at hand — don't sweep in
  unrelated untracked files.
