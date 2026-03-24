# Roadmap

Future features and enhancements for mosh.

---

## Worktree Support with Session Resume

**Priority:** Medium
**Status:** Design notes only

### Problem

Claude Code supports `--worktree` to create git worktrees and work in isolated
branch directories. Currently mosh has no way to launch worktree sessions or
resume them.

With the session auto-resume feature (saving `last-session-id` per project
volume), only one session ID is tracked per project. If mosh added worktree
support naively, multiple concurrent worktree sessions would overwrite each
other's saved session ID.

### Architecture Decision: Separate Containers per Worktree

Two approaches were considered:

**Option A — Multiple sessions in a single container:** Each worktree runs as a
separate `exec -it` into the same container.

| Pros | Cons |
|------|------|
| Shared provisioning (install once) | Container lifecycle is the big problem — `mosh` does `$RUNTIME stop` on exit, so the first session to exit kills all others. Needs reference counting. |
| Lower resource footprint | Shared `~/.claude` volume — session files and state can interfere between worktree sessions |
| Simple mental model (one project = one container) | If the container crashes, all worktree sessions die together |
| Predictable container name (`cc-myproject`) | Resource contention between multiple Claude + Playwright instances |

**Option B — Separate container per worktree:** Each worktree gets its own
container, e.g., `cc-myproject-feature-xyz`.

| Pros | Cons |
|------|------|
| Complete isolation — no shared state | Duplicate provisioning per container |
| Container lifecycle works as-is, zero changes | Container sprawl (`podman ps` gets noisy) |
| Session resume already solved — each container has its own volume and `last-session-id` | More disk usage per worktree |
| Independent start/stop/crash | Git worktree placement needs investigation (see open questions) |

**Recommendation: Option B.** It fits the existing mosh architecture with no
changes to the core container lifecycle. The stop-on-exit behavior in Option A
is fundamental to how mosh works, and adding reference counting is non-trivial
complexity. Provisioning duplication is solvable (cached layers, shared volumes).
Container sprawl is manageable with a `mosh list` command.

### Session Resume Storage

With separate containers (Option B), each worktree container has its own named
volume, so `~/.claude/last-session-id` is per-worktree by construction — no
keyed lookup needed. The same mechanism used for regular projects works
unchanged.

If Option A were chosen instead, session storage would need a directory-based
lookup keyed by branch name:

```
~/.claude/last-session-id                      # main workspace (no worktree)
~/.claude/worktree-sessions/feature-xyz        # session ID for feature-xyz worktree
```

### CLI

```
mosh worktree feature-xyz       # launch or resume worktree session
mosh new worktree feature-xyz   # start fresh worktree session
```

### Open Questions

- Does `claude --worktree` create the git worktree automatically, or does it
  expect one to already exist? Mosh may need to handle creation.
- When resuming with `--resume <id>`, does Claude Code restore the working
  directory to the worktree path automatically, or does mosh need to `cd` into
  it before launching?
- Git worktree placement: `claude --worktree` presumably creates the worktree
  relative to the repo. If `/workspace` is a bind mount from the host, where
  does the worktree end up? Inside the container's ephemeral filesystem (lost
  on `mosh fresh`)? On the host via the bind mount? Needs investigation.
- Branch names can contain characters problematic for container names (e.g.,
  `/`). Need to sanitize — the existing `container_name_from_dirs` function
  already does something similar with `tr`.
