# MoshPit Session Journal

Older entries: [JOURNAL_ARCHIVE.md](JOURNAL_ARCHIVE.md).

## Session Handoff — 2026-11-12 21:50

### Completed This Session

Reviewed the global CLAUDE.md and UADF against Anthropic's current guidance (the Fable 5.2
and Opus 5.5 prompting guides, Claude Code's memory, best-practices and skills docs, and
Lydia Hallie's talk "Rethinking Claude Code Best Practices", whose transcript is in
`docs/references/`). The guidance comes down to: keep only what Claude can't learn from the
code, rewrite "never/always" rules with their scope and reason, and delete cautions whose
reason no longer holds. Branch `chore/instruction-review`, merged to `main`:

- `954e60a` Web search: the WebSearch tool is **blocked**, and the 11-10 "fix" was wrong
  (correction added to that entry below). Searching works by fetching a Bing results page.
- `ab09257` Global `config/CLAUDE.md` 154 → 98 lines.
- `61b335c` Older journal entries moved to `JOURNAL_ARCHIVE.md`.
- `7b55f48` Talk transcript added.
- `ab087da` UADF v4.0.0: moved from `github.com/mfaughn/UADF` into `config/uadf/`. The
  commands are now four skills that run only when typed. `launch.sh` copies them into
  containers, and `config/uadf/install-host.sh` symlinks them on the host. See
  `config/uadf/CHANGELOG.md`.
- `75cb87b` New project `CLAUDE.md`, holding the facts the journal kept repeating.
- `669bce7` Removed the v2 UADF README and the unused `config/templates/`. Also deleted the
  `uadf/` clone, which was in sync with GitHub.

### Current State
- Branch: `main`, pushed to origin. Last commit: the journal update after `b06773f`.
- Verification:
  - `/uadf-start` ran correctly via `claude -p` with an isolated `CLAUDE_CONFIG_DIR`.
  - The container copy and host symlink installs were tested in temp dirs.
  - `shellcheck` and `bash -n` are clean apart from 3 older notes in `launch.sh`.
  - `/uadf-handoff` has **not** been run yet. Its first real use is the test.

### Next Steps
1. ✅ *Done (confirmed 11-12).* **On the host:** delete `~/.claude/commands/uadf/`, which is mounted into every
   container and would show each command twice, as `/uadf:uadf-*`. Then run
   `config/uadf/install-host.sh` if you want the skills on the host.
2. **Mostly done in mosh-pit (checked 11-12, after the handoff):** the image was rebuilt
   (`dcg` 0.16.0), this container has `NoNewPrivs: 1`, auto mode is on, packages
   installed, and the five default plugins installed. Playwright's Chromium layout had
   changed and broke the MCP; fixed in `launch.sh` (see "Update after the handoff"
   below). Still to do: recreate the other projects.
   **Rebuild and recreate, starting with one test project.** Back up the current image,
   then build, then recreate:
   ```bash
   podman tag claude-dev:latest claude-dev:pre-v5   # rollback point
   mosh build
   mosh fresh                                       # in one test project
   ```
   The rebuild changes more than the `dcg` pin: every later layer installs whatever is
   newest at build time (Playwright, `@playwright/mcp`, Chromium, Claude Code). After
   `mosh fresh`, check three things:
   - the project's `provision.sh` installed its packages, which shows `no-new-privileges`
     doesn't block `apt` as root;
   - Playwright starts, if the project uses it;
   - the status bar says "auto mode on".

   If something breaks, run `podman tag claude-dev:pre-v5 claude-dev:latest` and
   `mosh fresh` again. If it still breaks, the cause is the flag, not the new image. If all
   is well, recreate the other projects with `mosh fresh` whenever convenient. They keep
   working meanwhile, without the flag. This also covers the plugin-install test in step 5.
3. Run `/uadf-handoff` at the end of the next session and check it follows the commit
   rules: on `main` it reviews changes before writing the entry, and the journal is
   always the last commit.
4. Run `/doctor prompt-audit` (interactive) as a cross-check on the new instruction files.
5. Carried over from 10-29: test plugin installs in a fresh container (✅ done, all five
   installed), and close the plugin-drift gap in `mosh update`.

### Open Questions / Blockers
- **Search:** set up a SearXNG-backed search to replace fetching Bing pages, or ask the GCP
  admin to allow `claude-haiku-5-5:web_search`. SearXNG now runs on the host at :8888,
  but containers get "connection refused" (see "Update after the handoff").
- **Ideas from the talk, not done:**
  - ~~add a `Read(.env)` deny rule~~ (done in the security review below);
  - a `shellcheck` hook that exits with code 2 on failure;
  - ~~archive the GitHub UADF repo~~ (done 11-12: README points here, repo archived).
- ~~**`NOTES.md`** is stale in several places~~ (fixed 11-12).

### Decided After the Handoff
- **Effort stays `high`** for every model. It's Fable 5.2's default anyway; for Opus 5.5
  (default `medium`) it trades speed and cost for depth, which suits this work. Use
  `/effort medium` per session when speed matters.
- **Containers start in auto mode** (`--permission-mode auto` in `config/launch.sh`)
  instead of `--dangerously-skip-permissions`. Applies on the next `mosh` launch, without
  `mosh fresh`. Tested through the gateway: an ordinary `curl` ran without prompting, and an
  exfiltration-style command was blocked with `[Data Exfiltration]`. The classifier
  ignores `ANTHROPIC_DEFAULT_SONNET_MODEL` (the `[1m]` Sonnet 5.5 alias) and uses its
  Sonnet 5 default, which the gateway served. The `Containerfile` `CMD` was changed to match.
  It only matters after a rebuild, and `mosh` normally runs `launch.sh` instead.

- **Container security review** (commit after `53f9063`):
  - Added `--security-opt=no-new-privileges` and bumped `MOSH_VERSION` to 5. It's a
    creation-time flag, so **each project needs `mosh fresh`** to get it. Untested in a
    real container, because containers can't be created from inside one. Check that
    provisioning (`apt` as root) and Playwright still work after the first `mosh fresh`.
  - Added a `Read(.env)` deny rule, the env-file cleanup trap, and a pinned `dcg` (v0.16.0,
    which takes effect at the next `mosh build`).
  - Left out on purpose: `--cap-drop=ALL` (breaks `apt` in provisioning), `--read-only`
    (breaks self-update and installs), and resource limits (the VM caps them already).
- **Follow-ups from the review:**
  1. **GitHub PAT (user, on GitHub):** the token in every container is a *classic* PAT
     with `admin:org`, `admin:org_hook`, `admin:public_key`, `admin:repo_hook`,
     `repo`, `workflow`, `write:packages` and more, expiring 2027-11-10. Replace it with a
     fine-grained token limited to the needed repos (Contents and Pull requests R/W, no
     admin scopes).
  2. **After that:** log `gh` in by adding `export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"`
     to `config/launch.sh`. Today `gh` is not logged in, because it reads `GH_TOKEN`; only
     git uses the token, through the credential helper.
  3. **Optional:** Podman's VM shares all of `/Users`. Limiting it to the project folders
     would shrink what a container escape reaches, but that means recreating the VM.

### Things Worth Not Rediscovering
- **The container appears to run as real root in the Podman VM** (`/proc/self/uid_map` is
  `0 0 4294967295`), and the VM can see the Mac's `/Users`. The `claude` user has zero
  effective capabilities, the default seccomp filter is on, and there's no sudo.
- **`gh repo list` returning nothing is not evidence.** `gh` isn't logged in here.
- **WebSearch is blocked by an org policy, not a settings rule.** Every call returns the
  Vertex error `constraints/vertexai.allowedPartnerModelFeatures … web_search for
  claude-haiku-5-5`, from the main session or a subagent. Tested 2026-11-12. The 11-10
  session only saw WebSearch appear in the tool list, and it never ran a search. Bing
  result pages work through WebFetch or curl; DuckDuckGo returns a CAPTCHA, and Brave
  returns 429.
- **A symlink in `/workspace` can't reach a host path outside the mounts.** It resolves
  inside the container. That's why UADF now lives in this repo.
- **`disable-model-invocation: true` skills are invisible to the model.** Asking Claude
  "what uadf skills do you have?" returns none. Test by invoking `/uadf-start` instead.
- **`mosh fresh` keeps the `~/.claude` volume, so auto memory survives it.** The journal's
  advantage is git: history, review, and other machines.
- **Why the old handoff's WIP commit rarely happened.** The soft "if there are uncommitted
  changes" step lost to Claude Code's built-in "commit only when asked" rule, and the
  journal was written *after* the git check. The new skill says that invoking it
  authorizes the commits.
- **`git mv -k` on an untracked file silently does nothing.** Use plain `mv`.

### Update after the handoff (2026-11-12, later)
- **Playwright MCP was broken in rebuilt images.** Playwright build 1254 moved the headless
  shell to `chromium_headless_shell-*/chrome-headless-shell-linux-arm64/chrome-headless-shell`.
  `launch.sh` still looked for the old `chrome-linux/headless_shell` path, so it passed
  no `--executable-path`, and the MCP fell back to full Chromium. Full Chromium crashes here
  ("Target page, context or browser has been closed"), while the headless shell works
  (tested with the MCP's own `playwright-core`). `launch.sh` now tries both layouts and
  warns if neither matches. This takes effect at the next `mosh` launch in projects with
  `mosh playwright on`. Python Playwright was never affected.
- **SearXNG isn't reachable from containers.** `host.containers.internal` resolves to
  `192.168.127.254`, but port 8888 there refuses the connection. The host server is most
  likely bound to `127.0.0.1`, and it would need to listen on an address the Podman VM can
  reach. The Cowork plugin isn't needed in containers: it starts SearXNG in its own
  container, which doesn't work from inside a container. They only need the URL.
- **`web-researcher` agent** no longer tries `WebSearch`; it searches through Bing pages,
  like the global `CLAUDE.md`.
- **GitHub PAT:** you're not planning to replace it for now. The `GH_TOKEN` follow-up
  waits on that decision.
- **UADF GitHub repo archived**, with a README notice pointing to `config/uadf/` here.
- `NOTES.md` brought up to date: web search, launch modes, MCP injection, base image,
  the Chromium layout, the prevention of bind-mount contamination, and the file inventory.
- **`mosh update` is the only way an existing container's Claude Code gets updated.**
  Plain `mosh` resumes the container without updating, because `DISABLE_AUTOUPDATER=1`
  and `autoUpdates: false` are set. Only a new container (`mosh fresh`) runs the installer.
  Checked 11-13: this container's only binary, 2.1.323, dates from its creation. The
  "drift gap" step is dropped, since `mosh update` is unused.
- **SearXNG plan (11-13):** a shared Podman network `websearch`. The plugin's `searxng-up.sh`
  (v0.1.3) now creates it and attaches SearXNG. Next: `mosh` v6 adds `--network websearch`
  to new containers, then `mosh fresh` each project and test
  `curl -s 'http://searxng:8080/search?q=test&format=json'`. Start with curl and a
  `config/CLAUDE.md` note. For MCP tools later, copy the plugin's `server/dist/server.mjs`
  into this repo rather than mounting the plugin folder.
- **mosh v6 (11-13):** new containers join the `websearch` network (created if missing;
  `MOSH_NETWORK=` opts out), and every `mosh` launch now updates Claude Code before
  checking plugins. A failed download warns and the launch continues. `mosh update`
  and new containers share the same `update_claude_code` function. The container
  `CLAUDE.md` and `web-researcher` now search through SearXNG first and fall back to
  Bing. Tested with a stub `podman` only. **Next:** `mosh fresh` one project, then check
  SearXNG with curl, a dev-server port, and the update message on a second launch.
- **mosh v6 verified on the Mac (11-13)** in a fresh project container: `curl` to
  `http://searxng:8080/search?...&format=json` returns results, port publishing works on
  the `websearch` network, and a second `mosh` launch prints "Updating Claude Code".
- **Permission slip:** an in-place `sed` edit in `c8e8507` dropped the execute bit on `mosh`
  (fixed in `703367b`). Check `git diff --summary` for mode changes after editing scripts.
- **The user's TODO list:** review default plugins; run `/doctor prompt-audit`; finish tx
  integration with the desktop app (a different project).
- **Default plugins reviewed (11-13):** dropped `code-review`, `code-simplifier`,
  `ralph-loop` and `commit-commands`; kept `frontend-design`. Built-ins (`/code-review`,
  `/simplify`, `/loop`) or the current models cover the four, and two of them depend on
  `gh`, which isn't logged in. They're removed from `default-plugins.txt` and set to `false`
  in `settings.json`, which disables them in existing containers at their next launch
  (verified with an isolated `CLAUDE_CONFIG_DIR`). TODO list item done.
- **Transmissions mailbox merged (11-13, `e011f9d`, ADR-0002 Accepted).** A desktop app
  session wrote it on `tx-transmissions`: `transmissions/` in each project, the `tx-*`
  skills and an inbox hook in every container, and `mosh tx init|status`. My review found
  two ways for a container to reach the host, both fixed in `6d44a42`: `mosh tx status`
  ran the project's own `tx.sh`, and `init.sh` wrote through symlinks. The hook announces
  unread mail on **every** prompt; the user wants that nagging. Not pushed yet (user's call).
  **Open:** whether the desktop's `tx-desktop` skill runs `tx.sh` on the Mac (then it needs
  `TX_ROOT` and a trusted copy too); a real launch test (skills appear, hook output reaches
  Claude, auto mode allows `tx.sh`); `mosh tx init` on macOS bash 3.2. The desktop app and
  the container share one working tree, so only one of them should edit at a time.
- **Transmissions question #3 closed (11-13, `146ce49`, by the desktop session).** The
  desktop runs `tx.sh` in its Linux sandbox, which can still write to every connected
  folder, so its `tx-desktop` skill now runs an embedded, checksummed copy of `tx.sh`
  (from `6d44a42`) with `TX_ROOT`, treats `PROTOCOL.md` as untrusted, and refuses mailboxes
  with symlinks. **Consequence:** any change to `config/transmissions/tx.sh` must be followed
  by updating the copy and checksum in `tx-desktop` from a desktop session. Verified that
  the checksum matches `tx.sh` on `main`.

## Session Handoff — 2026-11-13 19:36

### Completed This Session
Picked up the 11-12 handoff. The bullets added under that entry ("Update after the
handoff") give the detail; in short:

- **Rebuild and recreate checked** in this container: the image is rebuilt (`dcg` 0.16.0),
  `NoNewPrivs: 1`, auto mode is on, and the five default plugins installed. Found that
  Playwright build 1254 moved the Chromium headless shell, so Playwright MCP fell back to
  full Chromium, which crashes. `launch.sh` now finds both layouts (`c8e8507`). Not tested
  with the MCP itself; the user deferred that until they next need Playwright.
- **Docs:** `NOTES.md` brought up to date, the `web-researcher` agent stopped calling the
  blocked WebSearch tool (`c8e8507`). The GitHub UADF repo was archived, with a README
  pointing to `config/uadf/`.
- **mosh v6** (`d34e661`): every `mosh` launch updates Claude Code (before, only new
  containers did), and new containers join a shared Podman network, `websearch`, so they
  reach the host's SearXNG at `http://searxng:8080`. Search instructions now try SearXNG
  first, then Bing. **Verified on the Mac by the user:** SearXNG answers from a fresh
  container, published ports still work, and launching prints "Updating Claude Code".
- **Fixed a regression I caused:** an in-place `sed` edit dropped `mosh`'s execute bit,
  so `mosh fresh` failed with "permission denied" (`703367b`).
- **Default plugins:** dropped `code-review`, `code-simplifier`, `ralph-loop` and
  `commit-commands`, and kept `frontend-design` (`c1acbff`).
- **Transmissions mailbox merged** (`e011f9d`, ADR-0002 Accepted). A desktop app session
  wrote it: a `transmissions/` folder per project, `tx-*` skills and an inbox hook in every
  container, and `mosh tx init|status`. Review found and fixed two ways a container could
  reach the host (`6d44a42`). The desktop side then hardened its own skill (`146ce49`).
- Pushed to `origin/main`. The `tx-transmissions` branch was deleted after merging.

### Current State
- Branch: `main`, level with `origin/main`. Last commit before this entry: `5a13fcc`
  Record the desktop side's transmissions security answer.
- Nothing left uncommitted.
- Verification: no test suite. `bash -n` and `shellcheck` on every changed script
  (`mosh` and `launch.sh` keep 3 older notes each; the transmissions scripts are clean).
  The new `mosh` functions were run against a fake `podman`. The mailbox was tested end to
  end in a scratch project, and both security attacks were reproduced before the fix and
  shown blocked after. mosh v6 was confirmed on the Mac by the user.

### Next Steps
1. **Test the mailbox in a real container.** In a project: `mosh tx init`, have the desktop
   send a message, then check that the container announces it, that `/tx-inbox` processes
   it, and that auto mode doesn't block the `tx.sh` calls.
2. Run `mosh tx init` on the Mac once, to confirm it works under macOS's bash 3.2.
3. Recreate the other projects with `mosh fresh` when convenient. Until then they search
   through Bing and lack `no-new-privileges`.
4. The user's own TODO list: run `/doctor prompt-audit`; finish tx integration with the
   desktop app.

### Open Questions / Blockers
- **Lasting facts proposed for the project `CLAUDE.md`** (awaiting the user's answer):
  don't edit scripts with `sed -i` and check `git diff --summary` for mode changes; the
  desktop app and the container share one working tree, so only one should edit at a time;
  changing `config/transmissions/tx.sh` means updating the copy and checksum in the
  desktop's `tx-desktop` skill.
- Playwright MCP after the path fix is untested (deferred by the user).
- The GitHub token is still a classic PAT with admin scopes. The user isn't planning to
  replace it, so `gh` stays logged out.

### Things Worth Not Rediscovering
- **Only a new container used to get a Claude Code update.** Containers have
  `DISABLE_AUTOUPDATER=1`, so resumed containers stayed on their creation-day version until
  mosh v6. Checked from this container's single installed version and its timestamp.
- **SearXNG on the host is published only on the Mac's `127.0.0.1:8888`, on purpose**
  (no login, rate limiter off). Containers reach it through the `websearch` network on
  its internal port 8080, not through `host.containers.internal:8888`, which is refused.
- **`sed -i` here can drop a file's execute bit** (it did to `mosh`, 755 → 644).
- **Anything in `/workspace` is writable from the container, so the Mac must never run or
  write through it blindly.** That was the root of both transmissions bugs: running the
  project's `tx.sh`, and following planted symlinks. The desktop's sandbox has the same
  issue, because it can write to every connected folder.
- **Playwright's browser directory layout changes between builds**, not only the version
  number. Full Chromium crashes in these containers ("Target page, context or browser has
  been closed"); the headless shell works.
- **Setting a plugin to `false` in `enabledPlugins` disables an installed plugin.**
  Checked with `claude plugin list --json` under an isolated `CLAUDE_CONFIG_DIR`.

## Session Handoff — 2026-11-13 20:15

### Completed This Session
- **Prompt audit** (`/claude-api prompt-audit`) of every Claude Code instruction file that
  loads in this project. Every path, command and environment variable they name was
  checked against `mosh`, `launch.sh`, `Containerfile` and `tx.sh`, and all exist. Two
  edits applied (`3e57aed`): `web-researcher` lost a generic "be thorough but concise"
  line in favour of the reason to be brief, and `tx-history` lost two search-strategy
  steps (its rules stay).
- **FHIR command** (`~/.claude/commands/fhir-ig-templates.md`): the user chose to keep it
  global and gave it a frontmatter `description` on the Mac. Confirmed: the skill list in
  this session now shows that description instead of `---`.
- **Three lasting facts added to the project `CLAUDE.md`** (`4045627`), closing the open
  question from the previous entry: no `sed -i` on scripts, only one of desktop app and
  container edits the shared working tree at a time, and a `tx.sh` change needs the
  `tx-desktop` copy and checksum updated. The matching auto-memory note was deleted as a
  duplicate.
- Pushed everything, including the previous handoff `53e4add`.

### Current State
- Branch: `main`, level with `origin/main` before this entry. Last commit before it:
  `4045627` Record three lasting facts in CLAUDE.md.
- Nothing left uncommitted.
- Verification: no test suite. The two prompt edits were checked by diff, with no
  file-mode changes (`git diff --summary`). The FHIR header was checked by reading the
  file's bytes and by the description appearing in the skill list.

### Next Steps
1. **Roll the new config out to the other projects:** run `mosh fresh` once in each (no
   `mosh build` needed; the image was rebuilt after the last `Containerfile` change,
   `dfbba11`). A plain launch would bring `config/`, the `tx-*` skills, the disabled
   plugins and the Claude Code update, but only `fresh` adds the `websearch` network and
   `no-new-privileges`.
2. In each project that should talk to the desktop, run `mosh tx init` on the Mac. The
   first run is also the bash 3.2 check from the last entry.
3. **Test the mailbox in a real container:** have the desktop send a message, then check
   that the container announces it, that `/tx-inbox` processes it, and that auto mode
   allows the `tx.sh` calls.
4. The user's remaining TODO: finish tx integration with the desktop app.

### Open Questions / Blockers
- Playwright MCP after the path fix in `c8e8507` is still untested (deferred by the user).
- The GitHub token is still a classic PAT with admin scopes, so `gh` stays logged out.

### Things Worth Not Rediscovering
- **The Mac's `~/.claude/commands` is mounted read-only into every container**
  (`mosh:605`). That is why the FHIR command is in every project but not in this repo, and
  why it can only be edited on the Mac.
- **A command or skill costs one line per session until it's invoked:** only its name
  and frontmatter `description` appear in the skill list. Without frontmatter, the list
  shows the first line of the file. The frontmatter is ignored if `---` is indented; the
  FHIR edit first failed that way. Windows line endings parse fine.
- **This container's loaded config is older than `config/`.** It hasn't been launched
  since mosh v6: its `CLAUDE.md` says to search with Bing only, its `web-researcher`
  still lists `WebSearch`, it has no `tx-*` skills, and the four dropped plugins are still
  enabled. Checked by `diff` against `config/`. Any `mosh` launch fixes all of it.
- **Plugin issues are moot here:** the four dropped plugins are disabled through
  `enabledPlugins: false` in `config/settings.json` (`c1acbff`) at the next launch. The
  audit had found real bugs in them (for example, commit-push-pr's allowlist uses
  `git checkout --branch`, a flag that doesn't exist).
