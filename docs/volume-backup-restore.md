# Backing Up and Restoring Mosh Volumes

**Status:** Written 2026-11-10, prompted by a major Podman version upgrade.

Mosh keeps all durable per-project state in **named volumes**. Containers are
disposable; volumes are not. This document covers backing them up and restoring
them, which matters most before a Podman upgrade that resets the machine.

## Why this matters

`mosh fresh` removes a **container** and rebuilds it. It never touches volumes —
there is no `volume rm` or `volume prune` anywhere in `mosh`. So a normal
`mosh fresh` is safe and loses nothing.

The risk is different on macOS, where Podman runs inside a VM (`podman machine`).
**The volumes live inside that VM, not on the Mac filesystem.** If an upgrade
involves `podman machine reset`, or removing and re-initing the machine, every
volume goes with it.

What is lost per project if volumes are destroyed:

| State | Path in volume | Consequence |
|---|---|---|
| Session history | `~/.claude/projects/-workspace/*.jsonl` | All past sessions gone |
| Resume pointer | `~/.claude/last-session-id` | Every project starts cold |
| dcg toggle | `~/.claude/.dcg-enabled` | Reverts to default |
| Playwright toggle | `~/.claude/.playwright-enabled` | Reverts to default |

Not lost: anything in the git repo, including `.ports` (host port allocations),
`config/`, and provision scripts. Those are reconstructible by design.

**Credentials are not in this list.** Since the v3 gateway migration, auth is
`ANTHROPIC_API_KEY` + `ANTHROPIC_BASE_URL`, injected from `.env` at container
creation. `.env` lives in the project directory on the host, so it survives a
machine reset untouched and there is nothing to back up. The OAuth paths below
apply only if a project logs in interactively instead.

## Why `podman volume export` does not work here

The obvious command fails on this setup:

```
$ podman volume export mosh-oauth-creds > ~/mosh-oauth-creds.tar
Error: cannot use command "podman volume export" with the remote podman client
```

The macOS `podman` CLI is a **remote client** talking to the VM, and
`volume export` is not available over that connection. (An older syntax error,
`-o` being rejected, is a separate issue — `volume export` takes the volume name
as its only argument.)

The workaround below uses the same throwaway-container pattern that `mosh`
itself uses for the dcg and playwright toggles (see `cmd_dcg` in `mosh`), so it
works regardless of client/server split or Podman version.

## Which volumes exist

```bash
podman volume ls
```

Two kinds:

- `mosh-oauth-creds` — **shared** across all projects, for OAuth logins only.
  **On a gateway-auth setup this volume is empty and always will be**, because
  nothing ever writes a credentials file. Do not bother backing it up; verify
  with the `ls -la /v` command below if unsure.
- `<container-name>-claude-home` — **one per project**, holding that project's
  own credentials, session history, and toggles. The container name is derived
  from the project directory; `podman volume ls` lists them all.

## Backup

The container writes a tar to **stdout**; the Mac's shell captures it. No bind
mount, no `volume export`.

Shared OAuth volume:

```bash
podman run --rm \
  --mount "type=volume,source=mosh-oauth-creds,target=/v" \
  claude-dev:latest \
  tar -cf - -C /v . > ~/mosh-oauth-creds.tar
```

Any per-project volume — substitute the name from `podman volume ls`:

```bash
podman run --rm \
  --mount "type=volume,source=cc-myproject-claude-home,target=/v" \
  claude-dev:latest \
  tar -cf - -C /v . > ~/cc-myproject-claude-home.tar
```

The trailing `.` in `-C /v .` is what captures dotfiles. Without it,
`.credentials.json` is silently missed.

### The command prints nothing on success

`tar -cf -` writes the archive into the redirect target, not to the terminal.
Silence is the expected result. Do not read "nothing happened" as failure —
verify instead.

### Verify the backup before trusting it

```bash
ls -la ~/mosh-oauth-creds.tar
tar -tvf ~/mosh-oauth-creds.tar
```

**File size tells you nothing.** An archive of an *empty* volume is 10,240 bytes,
and so is an archive containing `.credentials.json` — tar pads to a block size.
Only the listing distinguishes them.

| `tar -tvf` output | Meaning |
|---|---|
| `./` and `./.credentials.json` | Worked. |
| `./` only | Command fine, **volume is empty**. |
| No such file | Redirect never ran; the shell errored first. |

An empty volume is the common surprise: **Podman silently auto-creates a volume
that does not exist**, so a misspelled name produces a perfectly valid, empty
archive with no error. An empty `mosh-oauth-creds` is also entirely possible if
each project authenticated on its own before that shared volume existed.

Confirm what is actually in a volume before backing it up:

```bash
podman volume ls
podman run --rm --mount "type=volume,source=mosh-oauth-creds,target=/v" \
  claude-dev:latest ls -la /v
```

If the shared volume is empty, back up the **per-project** volumes instead —
that is where the credentials and session history actually live.

## Restore

Same pattern, reversed. **The `-i` flag is required** — without it stdin is not
connected and the restore silently reads nothing and reports success.

```bash
podman run --rm -i \
  --mount "type=volume,source=mosh-oauth-creds,target=/v" \
  claude-dev:latest \
  tar -xf - -C /v < ~/mosh-oauth-creds.tar
```

Per-project:

```bash
podman run --rm -i \
  --mount "type=volume,source=cc-myproject-claude-home,target=/v" \
  claude-dev:latest \
  tar -xf - -C /v < ~/cc-myproject-claude-home.tar
```

### Ordering after a machine reset

Restore needs the `claude-dev:latest` image, which will not exist after a reset.
Either:

1. `mosh build` first, then restore, then launch projects; or
2. Run `mosh fresh` in one project (which rebuilds the image anyway), then
   restore, then launch the rest.

If the shared OAuth volume is restored before a project's first launch, its
credentials seed into the new container automatically.

## Recommended upgrade sequence

1. `podman machine list` and `podman volume ls` — record what exists.
2. Check the Podman release notes for whether the upgrade requires a machine
   reset. If it only bumps the client/engine and the machine survives, volumes
   survive too and no backup is needed — `mosh fresh` per project is sufficient.
3. If a reset is involved, back up `mosh-oauth-creds` plus any per-project
   volume whose session history matters.
4. Verify each tar with `tar -tvf` **before** upgrading.
5. Upgrade.
6. `mosh build` (or a first `mosh fresh`).
7. Restore volumes.
8. `mosh fresh` in each remaining project.

## Verification status

- The `tar -cf - -C /v .` invocation was tested inside the `claude-dev` image:
  GNU tar 1.34 is present and dotfiles are captured correctly.
- The `podman run` wrappers were **not** executed end to end, because `podman`
  is not available inside the container where this was written.
- `tini` (the image ENTRYPOINT) was confirmed to pass stdout through unchanged,
  so it does not interfere with `tar -cf -`. It does print a harmless
  "not running as PID 1" warning to **stderr**, which does not corrupt the
  archive.
- The volume inventory above was read from `mosh` and `config/launch.sh`
  directly, not inferred.

## Related bug: `.oauth-creds` was owned by root

Discovered 2026-11-11 while investigating why `mosh-oauth-creds` was empty.

`Containerfile` created only `/home/claude/.claude` before its `chown -R`, so
Podman auto-created the `.oauth-creds` mountpoint as `root:root` at first mount.
Podman never chowns a volume once it has content, so the directory stayed
unwritable by the container user (uid 1001):

```
claude:claude 755   /home/claude/.claude
root:root     1755  /home/claude/.oauth-creds
$ touch /home/claude/.oauth-creds/.writetest
touch: cannot touch ...: Permission denied
```

This was latent rather than active — gateway auth writes no credentials file, so
the `cp` in `launch.sh` was never reached. Under OAuth it would have failed on
every launch, and **silently**: the `cp` had no error handling and `launch.sh`
deliberately runs without `set -e`. The symptom would have been re-authenticating
in every project forever, with nothing on screen explaining why.

Fixed in two places:

- `Containerfile` now creates `/home/claude/.oauth-creds` before the `chown -R`,
  so the volume inherits `claude:claude` on first mount.
- `config/launch.sh` reports a failed credential save instead of swallowing it,
  printing the directory's actual ownership and what to do about it.

The Containerfile fix only affects **newly created** volumes. An existing
root-owned `mosh-oauth-creds` keeps its ownership after an image rebuild; remove
the volume so it is recreated:

```bash
podman volume rm mosh-oauth-creds
```

Safe when the volume is empty, which it is on a gateway-auth setup. Check first:

```bash
podman run --rm --mount "type=volume,source=mosh-oauth-creds,target=/v" \
  claude-dev:latest ls -la /v
```
