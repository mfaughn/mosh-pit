# MoshPit Session Journal

Older entries: [JOURNAL_ARCHIVE.md](JOURNAL_ARCHIVE.md).

## Session Handoff — 2026-10-29 14:12

### Completed This Session

- **Found why plugin installs failed after a Claude Code update, and fixed it in `mosh`.**
  Not a Claude Code regression — `claude plugin install` works fine on 2.1.292 and the CLI
  surface is unchanged. The cause is that **`mosh` never registered a plugin marketplace**
  (`grep marketplace mosh config/launch.sh` → no hits). `claude plugin install
  name@marketplace` resolves the marketplace from the container's `~/.claude` volume, so on
  a volume that has never had one registered, *every* install fails:

  ```
  ✘ Failed to install plugin "code-review@claude-plugins-official":
    Plugin "code-review" not found in marketplace "claude-plugins-official".
  ```

  That all-or-nothing shape matches the reported symptom ("failed to install any of them")
  better than a partial failure would.

- **Three changes to `mosh`** (uncommitted, in the working tree):

  1. **`register_marketplaces()` + `PLUGIN_MARKETPLACES` array** — registers marketplaces
     before any install. Idempotent (~0.7s when already present), so it runs unconditionally
     rather than behind a check. This is the actual bug fix.
  2. **Failures are loud** — `install_plugins()` collects failures, reports them via `error`
     with names, returns non-zero. New-container path now prints `Setup complete, but some
     plugins failed to install` instead of a clean "Setup complete." The old silent yellow
     `warn` is precisely how a five-plugin wipeout scrolled past unnoticed.
  3. **`heal_plugins()` on the reuse path** — the existing-container branch previously ran
     `start` → `exec launch.sh` → `return` and never touched plugins, so a volume that lost
     its state stayed broken on every future launch. Now gated on a ~0.6s
     `plugin list --json | jq length` probe; the full install pass runs only when state is
     actually missing. Repair failure warns and continues rather than blocking the session.

  Also added `</dev/null` to the install call — a marketplace-declared confirmation prompt
  on non-TTY stdin would otherwise hang the launch.

- **Updated `README.md`** with the marketplace-ordering requirement and the self-heal behaviour.

### Current State
- Branch: `main`. **Uncommitted**: `mosh` (+120/-11), `README.md` (+6).
- Last checkpoint: `7517423` — Correct [1m] guidance: Opus needs the tag too.
- Tests: **No test suite exists in this repo** — nothing to run. Verification was
  `bash -n` (clean), `shellcheck` (3 warnings, all pre-existing at lines 508/617/1028,
  none in new code), and a stubbed-runtime harness covering: happy path, single-plugin
  failure, marketplace-registration failure, heal-skip when healthy, heal-triggers when
  empty, heal-failure-continues, missing per-project `plugins.txt`, and survival under
  `set -e`. Plus the original bug end-to-end: against a virgin `CLAUDE_CONFIG_DIR` the old
  call fails, `install_all_plugins` on that same dir installs all five.
- Live container's real plugin state: all five reinstalled and enabled.
- Backup of the pre-edit script at `/tmp/mosh.orig` (ephemeral — gone on container restart).

### Next Steps
1. **Commit the two modified files** — the user was asked and the session ended before
   answering. Suggested message: `Register plugin marketplaces before installing`.
2. **Verify against a genuinely fresh container**: `mosh fresh` and confirm all five
   plugins install on first launch. Everything so far was verified via isolated
   `CLAUDE_CONFIG_DIR`s, not a real container lifecycle.
3. Consider making `mosh update` (mosh:~1012) check plugin state — see Blockers.

### Open Questions / Blockers

- **The 2.1.289 → 2.1.292 sequence is still unexplained.** `known_marketplaces.json` had
  `lastUpdated: 13:40:17` and the plugin cache was fully populated with all five, yet
  `installed_plugins.json` was `{"version":2,"plugins":{}}` at session start. *Something*
  registered the marketplace and populated the cache **after** `install_plugins` had already
  failed. Leading hypothesis (unproven): Claude Code's own startup resolves `enabledPlugins`
  from the synced `settings.json`, which would also explain why plugin skills were available
  in-session despite an empty install registry. If plugins vanish again after an update, start
  here. The self-heal now papers over it, but does not explain it.

- **`mosh update` still has the drift gap.** It updates Claude Code in a stopped container
  and exits without touching plugins. The binary lives on the **ephemeral overlay**, plugin
  state on the **persistent volume**, so the two drift independently. The new self-heal
  catches it on the next `mosh` launch, but only after the fact.

### Relevant Context — things worth not rediscovering

- **The ephemeral/persistent split is the root structural issue.** Verified via `df`:
  `~/.claude` is a named volume on `/dev/vda4` (persists); `~/.local/share/claude/versions/`
  is on the overlay (does not). Both `2.1.289` (Oct 5, image layer) and `2.1.292` (Oct 7,
  the update) sat on the overlay. Any future "state disappeared after an update" bug should
  be checked against this split first.

- **v1→v2 schema migration was investigated and ruled out.** The new binary *silently
  ignores* v1-shaped `installed_plugins.json` — no error, just "No plugins installed" —
  which looks exactly like the bug. But 2.1.289 already writes v2 (confirmed by running the
  old binary against an isolated config dir), so this was not the cause here. Worth
  remembering as a failure mode: the silence makes it easy to misdiagnose.

- **A marketplace dir that exists but is not a valid git clone does *not* break installs.**
  Tested explicitly; it succeeded. An earlier "corrupted installLocation" warning seen in
  testing was a red herring from a pointed-elsewhere `installLocation`, not the real failure.

- **Useful probes:** `claude plugin list --json | jq length` is ~0.6s and is what
  `heal_plugins` gates on. A re-install of an already-present plugin is ~2.5s, which is why
  the probe exists rather than just re-running installs every launch.

- **`bash -lc` resolves `claude` correctly** in this container (login shell keeps
  `~/.local/bin` on PATH) — checked, because `heal_plugins` depends on it. `jq` is at
  `/usr/bin/jq`.

- **Methodology note:** the first diagnosis this session was wrong. It was presented as a
  container-*build*-time issue; the user corrected that it happens when starting an
  *existing* container that updates Claude Code before launching it. That correction is what
  surfaced the reuse-path gap (fix #3) — the build path alone would not have explained a
  recurring failure.

## Session Notes — 2026-11-10 22:40

Investigating a startup warning about asterisk permission rules (see below) turned up an
unrelated and more consequential gotcha. No code changed this session; findings only.

### GOTCHA: `Write(path)` deny rules silently do nothing

**A deny rule of the form `Write(some/path/**)` has no effect — in any permission mode.**
It does not error, does not warn, and does not appear anywhere as a misconfiguration. It
simply never matches, so a path you believe is fenced off is fully writable.

Official docs state it plainly, under "Write(path), Glob(path), and Grep(path) rules don't
match" (https://code.claude.com/docs/en/permissions): file-path permission checks are
evaluated against **`Edit` and `Read`** rules only. A path inside `Write(...)`, `Glob(...)`
or `Grep(...)` is never consulted.

Measured directly on 2.1.292, with `allow: ["Write"]` present so the deny rule is the only
thing that could block:

| Rule | default mode | `--dangerously-skip-permissions` |
|---|---|---|
| `deny: ["Write"]` (bare name) | blocks | **blocks** |
| `deny: ["Write(**)"]` | no effect | no effect |
| `deny: ["Write(//abs/path/**)"]` | no effect | no effect |
| `deny: ["Edit(subdir/**)"]` | blocks | **blocks** |

**To actually fence off a path, write the rule against `Edit` and `Read`, never `Write`.**

Two further points worth keeping:

- **Bare-name denies survive bypass mode.** `deny: ["Write"]` removes the tool from the
  model's context entirely — the tool reports `No such tool available: Write. Write is
  disabled for this session, in subagents as well as here.` This happens before any
  permission check runs, so `--dangerously-skip-permissions` cannot undo it. Verified for
  `WebSearch` too: it is present in the tool list without the rule and absent with it, under
  bypass mode. So the `deny: ["WebSearch"]` in `config/settings.json` **is** enforced in our
  containers, despite `launch.sh:204` always passing `--dangerously-skip-permissions`.
- **A working path deny also survives bypass mode.** `Edit(e1/**)` blocked under
  `--dangerously-skip-permissions`, with `permission_denials: ["Edit"]`. Bypass mode is not
  a blanket override of deny rules.

### The startup warning that prompted this — not a concern

User saw a message in another project about asterisk permission patterns. It is the
"has a wildcard before the rest of the command" advisory, added in **v2.1.246**
(https://code.claude.com/docs/en/errors). Reproduced verbatim on 2.1.292:

> Permission allow rule (settings.json): Bash(git * main) has a wildcard before the rest of
> the command, so it also matches any options inserted at that position and approves them
> without a prompt. For git, options such as -c and --exec-path can run arbitrary commands.
> Replace that * with the exact value you mean, or only use * after the subcommand (for
> example Bash(git status *)).

- **It is informational only.** Docs: "Claude Code keeps the rule and changes nothing about
  how it matches." No deprecation, no migration, no behavior change. A full search of the
  official CHANGELOG (~1.19M chars) found no entry changing `Tool(*)` semantics, and no
  announced future change.
- **Our `(*)` rules do not trigger it.** Tested `Bash(*)`, `Edit(*)`, `Read(*)` — silent.
  It fires only when `*` precedes a later word that determines the command. `Bash(git * main)`
  and `Bash(git -C * status *)` both fire; the recommended `Bash(git status *)` is silent.
- **`Tool(*)` is documented as equivalent to bare `Tool`** and confirmed by test:
  `Write(*)` permitted top-level, subdirectory, and outside-the-working-directory writes,
  while a scoped `Write(src/**)` control correctly denied the outside write. The `*` is a
  whole-tool wildcard, *not* a gitignore single-segment pattern.
- Scanned every settings file reachable from this container — the global, the repo
  template, and `.claude/settings.local.json`. **None contains a triggering rule.** The
  warning names its source file, so the message itself identifies the culprit project.

### Relevant Context — methodology

- **`Read` is auto-approved regardless of the allow list.** Any permission experiment built
  on Read proves nothing; use `Write` or `Edit`, which are actually gated. Cost one full
  round of meaningless results this session.
- **Always include an `allow` rule when testing a `deny` rule.** With an empty allow list, a
  block in default mode comes from "nothing is allowed," not from the deny rule. This
  confound produced a wrong conclusion twice — first that bypass mode defeats path denies,
  which it does not. The variable was the tool (`Write` vs `Edit`), not the mode.
- **Watch for silent tool fallback.** An early test showed a file created despite
  `deny: ["Write"]` and looked like the deny had failed. It had not — Write was genuinely
  gone and Claude wrote the file with Bash instead. Deny both tools, or forbid the fallback
  in the prompt, before reading anything into the end state.
- **Isolate with `CLAUDE_CONFIG_DIR=/tmp/...`.** Honored correctly, and keeps real settings
  untouched. Confirm the dir is actually loaded first: a bogus rule like `deny: ["Bsh"]`
  prints "matches no known tool — check for typos" in both modes, which proves the file was
  read.

### Podman major-version upgrade — volume backup procedure

Prompted by a pending Podman major version bump that recommends discarding
containers. Written up in full at **`docs/volume-backup-restore.md`**; summary here.

- **`mosh fresh` alone is safe.** It removes a container and rebuilds it, and never
  touches volumes — there is no `volume rm` or `volume prune` anywhere in `mosh`.
- **The real risk is `podman machine`.** On macOS the volumes live inside the Podman
  VM, not on the Mac filesystem. A machine reset or re-init during the upgrade
  destroys every volume: OAuth credentials, session history, resume pointers, and
  the dcg/playwright sentinels. `.ports` is in the repo and survives.
- **`podman volume export` is unavailable here** — "cannot use command
  `podman volume export` with the remote podman client", because the macOS CLI is a
  remote client talking to the VM. Use the throwaway-container tar pattern in the
  doc (the same trick `cmd_dcg` uses to reach into a volume).
- **Restore needs `-i`** on `podman run`, or stdin is not connected and the restore
  silently succeeds while reading nothing.
- **Restore needs the image to exist**, so run `mosh build` (or one `mosh fresh`)
  before restoring after a machine reset.

Verified: `tar -cf - -C /v .` captures dotfiles correctly in the `claude-dev` image
(GNU tar 1.34). NOT verified: the `podman run` wrappers end to end, since podman is
not available inside the container. A 0-byte tar is the symptom to watch for.

### BUG FIXED: `.oauth-creds` volume was owned by root

Found while checking whether `mosh-oauth-creds` was worth backing up before the
Podman upgrade. It was empty — and would have stayed empty even under OAuth.

`Containerfile` created only `/home/claude/.claude` before its `chown -R`, so Podman
auto-created the `.oauth-creds` mountpoint as `root:root`. Podman never chowns a
volume once it has content, so it stayed unwritable by the container user (uid 1001).
Confirmed in the live container: `touch` → `Permission denied`, and
`root:root 1755 /home/claude/.oauth-creds` against `claude:claude 755` for `.claude`.

**Latent, not active.** Since the v3 gateway migration, auth is `ANTHROPIC_API_KEY`
from `.env`, which writes no credentials file — so the `cp` in `launch.sh:229` was
guarded by a condition that is never true. Under OAuth it would have failed every
launch, **silently**: bare `cp`, no error handling, and `launch.sh` deliberately runs
without `set -e`. Symptom would have been re-authenticating in every project forever
with nothing explaining why.

Fixed:
- `Containerfile` — create `/home/claude/.oauth-creds` before the `chown -R`.
- `config/launch.sh` — report a failed credential save, printing the directory's real
  ownership and the remedy, instead of swallowing it. Exits 0 so it can never abort a
  launch.

Only affects **new** volumes. An existing root-owned `mosh-oauth-creds` survives an
image rebuild; `podman volume rm mosh-oauth-creds` to recreate it (safe while empty).

Tested: failure path prints the warning and returns 0; success and no-op paths are
silent; `shellcheck` and `bash -n` clean (three pre-existing notes, none in new code).

**Upshot for the upgrade:** credentials are NOT at risk — `.env` lives in the repo on
the host. Only session history, the resume pointer, and the dcg/playwright sentinels
are volume-only. User does not rely on session history (uses JOURNAL.md for
continuity), so the plan is simply: upgrade, `mosh fresh` per project, no backup.

### FIXED: `deny: ["WebSearch"]` was disabling search everywhere, including subagents

> **Correction (2026-11-12):** removing the deny did **not** make search work. The check
> below only confirmed that WebSearch *appeared in the tool list*. It never ran a search.
> Every real WebSearch call fails with a Vertex org-policy error
> (`constraints/vertexai.allowedPartnerModelFeatures … disallowed feature web_search`),
> in the main session and in subagents. So the original note, "blocked on this model",
> was right, and the deny was redundant. Searching works by fetching a Bing results page
> with WebFetch or curl. See the 2026-11-12 handoff.

The CLAUDE.md policy said WebSearch was "blocked on this model" and to delegate searches
to the `web-researcher` subagent. Both halves were wrong, and the workaround could never
have worked.

**Cause.** `config/settings.json` carried `deny: ["WebSearch"]`. A bare-name deny removes
a tool from the model's context *before* any permission check, and it applies to
**subagents as well as the parent**. So the `web-researcher` subagent — whose own
definition declares `tools: WebSearch, WebFetch, Read` — came up with only
`WebFetch, Read`. An agent file cannot grant back what a deny rule strips.

**Consequence.** Every "web search" this setup has ever done was actually `WebFetch`
against URLs guessed from the model's prior knowledge. A probe agent confirmed this from
its own side: 8 WebFetch calls, zero WebSearch, and it said so plainly when asked.

**Fix (both propagate to every container on next launch — no `mosh fresh` needed, since
`launch.sh:28` re-copies `settings.json` and `CLAUDE.md` from the read-only `/mosh-config`
mount on every launch, and all containers mount the same repo `config/`):**
- `config/settings.json` — `deny` is now `[]`.
- `config/CLAUDE.md` — "Web Search Policy" replaced with "Web Research": use WebSearch
  directly; `web-researcher` is now a context-management choice, not a capability
  workaround.

**Verified after the change**, with the new config in an isolated `CLAUDE_CONFIG_DIR`:
parent tool list includes WebSearch; the `web-researcher` subagent reports
`WebSearch, WebFetch, Read`.

### WebFetch reliability — the summarizer is a small model

WebFetch does not return the page; it returns a *summary* produced by a small fast model,
which misreads values silently. Observed: a GitHub release page's publish date came back
as "November 10, **2024**" when the real value was `2026-11-10T20:01:54Z` — off by two
years, with no indication anything was wrong. Caught only by re-fetching the raw API JSON
and asking for the literal field.

Mitigations now written into `config/CLAUDE.md` under "Getting reliable results out of
WebFetch": fetch raw JSON/API endpoints rather than rendered HTML, name the exact field
and demand it verbatim, give the model an explicit "NOT PRESENT" escape hatch, re-fetch
anything load-bearing with a differently-worded prompt, prefer primary sources over
aggregators, use `offset` on long pages, and treat returned URLs as unreliable even when
the substance is right (a search returned `github.com/podman-container-tools/podman`,
which does not exist, alongside a correct version number).

### Podman 6 upgrade — macOS does NOT require recreating the machine

Verified directly against `api.github.com/repos/containers/podman/releases/tags/v6.0.0`
(published `2026-06-24T17:38:25Z`), quoting the release body:

- "Volume mounts on existing `podman machine` VMs **on Linux** have been broken by this
  change, and the VM will need to be recreated." — **Linux only.**
- "The default `podman machine` provider on Macs has been changed to `libkrun`." …but:
  "The provider set in the configuration only determines the provider used by
  **newly-created VMs**, and can be overridden by the new `podman machine init
  --provider` option."
- "Starting Podman 6 when the BoltDB database is in use will have Podman attempt an
  automatic migration from BoltDB to SQLite."

So on macOS the existing `applehv` VM is not force-recreated, which means **the volumes
inside it survive** and the earlier machine-reset worry in `docs/volume-backup-restore.md`
is overstated for this platform. Other v6.0.0 breaking changes, none of which apply here:
Intel Macs dropped (this host is Apple Silicon), cgroups v1, iptables→nftables,
CNI→Netavark, slirp4netns→Pasta. Latest release at time of writing: v6.2.0, published
`2026-11-10T20:01:54Z`.

Caveat: `podman.io/blog` 404s, so this rests on the release notes alone.

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
