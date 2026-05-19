# am-git — features & roadmap

What works today and what's still missing, by category. Three columns:

- **Status** — ✅ shipped, 🚧 partial / known limitations, ❌ not yet.
- **Command / API** — what you type or call. Empty when not implemented.
- **Notes** — limitations, follow-ups, what's missing.

Check items off in the **Status** column as you ship them. Each row
should also link the source file once implemented.

---

## Local repo

| Feature                | Status | Command / API                                      | Notes |
|------------------------|:------:|----------------------------------------------------|-------|
| Init a repo            | ✅     | `am-git init [<dir>]`                              | Scaffolds the full `.git/` skeleton (objects/, objects/pack/, refs/heads/, refs/tags/, info/), writes HEAD pointing at `refs/heads/main`, writes a minimal `[core]` config. Reinit-safe: HEAD and config aren't overwritten if they already exist. Default branch is hardcoded to `main`; no `-b <name>` yet (needs `am-git config` plumbing). |
| Add files              | ✅     | `am-git add <path>...` / `add .`                   | Honours `.gitignore` and `.git/info/exclude`. Clears conflict stages on resolve-then-add. Bypass with explicit paths is not supported — naming an ignored file does not stage it. |
| Remove files           | ✅     | `am-git rm [--cached] <path>...`                   | `--cached` keeps the on-disk file. No `--force`. |
| Rename files           | 🚧     | `am-git mv <source> <destination>`                 | Single file only — directory renames need recursion. Refuses if destination exists or is already tracked (no `-f`). Source must already be tracked. Trailing `/` on destination means "move into directory". |
| Commit                 | ✅     | `am-git commit -m <msg>`                           | Index-based when `.git/index` exists, walks worktree otherwise. Refuses while index has unmerged stages or a rebase is in progress. Auto-creates merge commits when `.git/MERGE_HEAD` is present. |
| Status                 | ✅     | `am-git status`                                    | `XY <path>` format matching `git status --short`. Unmerged paths shown as `UU`/`AA`/`DU`/`UD`. `.gitignore`-aware. |
| `.gitignore`           | ✅     | (file convention)                                  | Multi-level (`.gitignore` per dir + `.git/info/exclude`). Patterns: `#` comments, blank lines, `!` negation, leading `/` anchor, trailing `/` dir-only, glob `*` and `?`. No `**`, no `[abc]` ranges. |
| Reset                  | ✅     | `am-git reset [--soft\|--mixed\|--hard] [<commit>]`| Defaults to `--mixed HEAD` (unstage). Clears `MERGE_HEAD`/`MERGE_MSG` — doubles as `merge --abort` for clean merges. |

## Branches & refs

| Feature                | Status | Command / API                                      | Notes |
|------------------------|:------:|----------------------------------------------------|-------|
| List branches          | ✅     | `am-git branch`                                    | `*` next to current. Reads `refs/heads/`. |
| Create branch          | ✅     | `am-git branch <name>`                             | Branches at HEAD. No `<start-point>` arg yet. |
| Delete branch          | ✅     | `am-git branch -d <name>`                          | Refuses to delete the current branch. No `-D` force-delete. |
| Checkout branch        | ✅     | `am-git checkout <branch>`                         | Wipes orphan files, materialises new tree, re-seeds index, updates HEAD. Always clobbers — no dirty-worktree detection. No `checkout -b`, no detached-HEAD checkout by SHA. |
| Tag                    | 🚧     | `am-git tag [<name> [<commit>]]` / `tag -d`        | Lightweight tags only — ref file under `refs/tags/`. Validates the target SHA is in the object store before writing. Refuses to overwrite an existing tag (no `-f`). Annotated tags (a separate tag object with author/message) aren't written yet; tag-object peeling in `resolveCommitish` would follow. |
| `refs/tags/...` in `resolveCommitish` | ✅ |                                          | `checkout`/`merge`/`merge-base`/`reset`/`diff` all accept tag names. |
| Detached HEAD          | 🚧     |                                                    | `commit` writes to `.git/HEAD` when detached. `merge`/`rebase`/`pull`/`checkout` all refuse detached HEAD. |
| `HEAD~N` / `HEAD^`     | ❌     |                                                    | `resolveCommitish` currently handles bare `HEAD`, 40-char SHA, and `refs/heads/<name>`. Ancestry expressions need a separate parser. |

## Remote operations

| Feature                | Status | Command / API                                      | Notes |
|------------------------|:------:|----------------------------------------------------|-------|
| Clone (smart HTTP)     | ✅     | `am-git clone <url> [<dir>]`                       | Pack download + parse + delta resolve + worktree materialise. HTTPS via am-ssl. |
| Fetch                  | ✅     | `am-git fetch [<url>\|<remote-name>]`              | Defaults to `[remote "origin"]` URL from `.git/config`. |
| Pull (ff-only)         | ✅     | `am-git pull [<url>] [<branch>]`                   | Refuses non-ff. Use `am-git fetch` + `am-git merge` for divergent histories. |
| Push                   | ✅     | `am-git push [<url>] [<branch>]`                   | Defaults from `.git/config`. |
| Remote management      | ❌     | `am-git remote add/remove/-v`                      | Currently you edit `.git/config` by hand. |
| `.git/config` editing  | ✅     | `am-git config [--list \| --unset <key> \| <key> [<value>]]` | Read / write `.git/config`. Section + subsection + key flattened to dotted names (`remote.origin.url`). Writes are canonical INI (sections sorted, comments not preserved — hand-editing and `am-git config` shouldn't be mixed in the same file). No `--global` / `--system` / `--worktree` scope yet. |
| Authentication         | 🚧     |                                                    | Basic auth via env vars. No credential helpers, no SSH transport. |

## Merge & rebase

| Feature                | Status | Command / API                                      | Notes |
|------------------------|:------:|----------------------------------------------------|-------|
| Merge-base             | ✅     | `am-git merge-base <a> <b>`                        | LCA via BFS-first-hit on the commit DAG. |
| Fast-forward merge     | ✅     | `am-git merge <branch>`                            | Detected automatically; just moves the ref. |
| 3-way merge            | ✅     | `am-git merge <branch>`                            | Whole-file conflict markers (`<<<<<<< / ======= / >>>>>>>`) for text files. Binary files leave workdir at HEAD with index stages 1/2/3 for GUI tools. Writes `.git/MERGE_HEAD` + `MERGE_MSG`. |
| Hunk-level conflict markers | ❌ |                                                    | Needs a real line-level diff library (see "Diff" below). Currently we wrap the full ours/theirs versions. |
| Rebase                 | ✅     | `am-git rebase <upstream>`                         | Linear histories only — refuses if any commit in the range is a merge commit. |
| Rebase resume          | ✅     | `am-git rebase --continue` / `--abort`             | State persisted in `.git/rebase-merge/` (real git's layout). |
| `rebase --onto <X>`    | ❌     |                                                    | Mostly arg parsing; replays onto an arbitrary commit instead of `<upstream>`. |
| Interactive rebase     | ❌     | `am-git rebase -i`                                 | Would need an editor protocol + a todo-file mini-language (`pick`/`squash`/`fixup`/`drop`/`reword`). Big project. |
| Cherry-pick            | 🚧     | `am-git cherry-pick <commit>` / `--continue` / `--abort` | Single-commit form. Reuses `replayCommit` directly. Conflict-resume via `.git/CHERRY_PICK_HEAD`. Refuses merge commits (would need `-m <parent>`), refuses root commits (no parent to diff). No multi-commit queue (`cherry-pick A B C`) yet — would add a `.git/sequencer/` todo list, similar to rebase's `.git/rebase-merge/`. |
| Revert                 | 🚧     | `am-git revert <commit>` / `--continue` / `--abort`| Single-commit form. Mirror image of cherry-pick — 3-way merge with base=commit, theirs=parent (swapped). Author is the reverting user (not the original); message is `Revert "<first line>"` + `This reverts commit <SHA>.`. Conflict-resume via `.git/REVERT_HEAD` (real git's filename). Refuses merge / root commits, same as cherry-pick. No multi-commit form yet. |
| Stash                  | ❌     | `am-git stash` / `stash pop`                       | ~200 lines. Save worktree + index as a special hidden commit, restore later. |

## Inspection

| Feature                | Status | Command / API                                      | Notes |
|------------------------|:------:|----------------------------------------------------|-------|
| Log                    | ✅     | `am-git log [-n N]`                                | First-parent walk from HEAD. No `--graph`, no `--all`, no path filter. |
| Show commit            | 🚧     | `am-git show [<commit>]`                           | Header (sha, parents, author, committer) + indented message + path-level name-status. Defaults to HEAD. Root commits show every path as "A" (diffed against the empty tree). Full hunk-level diff awaits the diff library. |
| Path-level diff        | ✅     | `am-git diff [--staged] [--name-only\|--name-status] [<a> [<b>]]` | A/M/D classification. No hunks — see below. |
| Hunk-level diff        | ❌     | `am-git diff` (default output)                     | Needs a Myers/Patience diff library. Should live in a separate `am-diff` package (parallel to `am-z`) so other AmLang projects can use it. ~400-600 lines. |
| Blame                  | ❌     | `am-git blame <file>`                              | Per-line history. Needs hunk-level diff applied iteratively along history. Big. |
| `head` (debug)         | ✅     | `am-git head`                                      | Prints resolved HEAD (branch / commit / detached). |
| Cat / pretty-print     | ✅     | `am-git cat-file -p\|-t <sha>`                     | Inflate a loose object and print type/content. |
| `hash-object`          | ✅     | `am-git hash-object [-w] <file>`                   | Compute (and optionally write) a blob's SHA-1. |
| `write-tree`           | ✅     | `am-git write-tree`                                | Build trees from cwd, print root tree SHA. |
| `commit-tree`          | ✅     | `am-git commit-tree <tree> [-p <p>] -m <msg>`      | Plumbing — wraps `CommitWriter.write`. |
| `ls-stages`            | ✅     | `am-git ls-stages [--rewrite]`                     | Debug: dump index entries with stage bits, optionally round-trip back. |
| `merge-plan`           | ✅     | `am-git merge-plan <a> <b>`                        | Debug: dry-run the 3-way classifier. |

## Polish / quality

| Feature                | Status | Command / API                                      | Notes |
|------------------------|:------:|----------------------------------------------------|-------|
| `--help <command>`     | ❌     |                                                    | Top-level `am-git help` works; per-command help is missing. |
| Coverage               | 🚧     |                                                    | 99 unit tests, ~16% line coverage. Network clients (Clone/Push/Fetch) are mostly untested — would need a fixture server. |
| AmigaOS path quirks    | 🚧     |                                                    | Slash-only paths assumed throughout. Drive prefixes like `RAM:` haven't been audited end-to-end. |
| README / tutorial      | 🚧     |                                                    | `README.md` exists but isn't a walkthrough. A "clone → edit → commit → push on Amiga" tutorial would help adoption. |

---

## Strategic next-step shortlist

In rough order of leverage:

1. **`am-diff` library + hunk-level `am-git diff`** — biggest single payoff; also unlocks proper hunk-level merge conflict markers (the current whole-file markers become hunk-level for free).
2. **`cherry-pick` + `revert`** — small, satisfying, mostly reuses rebase machinery.
3. **`tag` + `config`** — close the daily-driver gap (release flow + no more hand-editing `.git/config`).
4. **`stash`** — useful but bigger than the trio above.
5. **`rebase --onto X`** — small extension of the existing rebase.
6. **Interactive rebase** — own project; needs an editor protocol.

The first item is the only one that fundamentally changes capability; the rest are completeness work.
