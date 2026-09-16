# ADR-0001: Per-container host port allocation

## Status

Accepted

## Date

2026-09-16

## Context

mosh runs one container per project, all potentially running at the same time.
Until now no container published any ports, so a dev server started inside one
(vite, jekyll, `python -m http.server`, an IG preview) was unreachable from the
host browser.

Publishing ports naively — giving every container the same host mapping — fails
the moment two containers run concurrently, which is the normal case for this
tool. So the host side must be allocated per project, and the allocation has to
survive `mosh fresh`.

Two properties of the runtime shape the whole design:

- **Podman fixes port mappings at container-creation time.** A mapping cannot be
  added to an existing container. Ports are therefore in the same category as
  `--env-file`: baked in at creation, not picked up from `config/` at launch.
- **Containers have separate network namespaces.** Container-side ports can be
  identical everywhere; only host-side numbers must be unique.

## Decision

Each project gets a **slot**; its host block is `20000 + (slot * 10)`. Seven
ports are published from that block of ten, mapped to a fixed, curated set of
container-side ports (3000, 4000, 5173, 8000, 8080, 8888, 9000) identical in
every container. Bindings are `127.0.0.1` only.

Slots are recorded in `.ports`, a gitignored plain-text file next to `.env`,
keyed on container name. A new project claims the lowest unused slot.

## Consequences

### Good
- Collisions are impossible by construction, not by probability.
- `mosh fresh` preserves a project's ports, because the registry keys on the
  container name and `fresh` recomputes the identical name.
- Curated container ports mean most tools need no `--port` flag.
- Reclaiming a slot is a documented one-line edit, requiring no new command.
- The planned per-worktree containers in `ROADMAP.md` get distinct blocks for
  free, since each worktree container has a distinct name.
- Reserving 3 of every 10 host ports means an eighth container port can be added
  later without renumbering existing allocations.

### Bad
- `.ports` is mosh's first piece of shared host-side state, and it can drift from
  reality if containers are removed outside mosh. Mitigated by `mosh ports list`
  marking dead entries `(stale)` rather than by automatic cleanup.
- Ports are pre-allocated whether used or not, and needing an eighth port means
  recreating the container.
- Abandoned projects leak slots until someone edits the file. With 1000 slots
  this is not a practical limit.

### Neutral
- `MOSH_VERSION` bumps to 4; existing containers gain ports only after
  `mosh fresh`.
- Concurrent first-launches are serialised with a `mkdir`-based lock.

## Alternatives Considered

### Hash-derived slots (`hash(container_name) % 1000`)
- **Pros:** No state file at all; the same answer is computable from anywhere,
  and nothing can drift or be lost.
- **Cons:** Birthday collisions are not negligible — roughly 18% odds of a
  collision at 20 projects. Handling that needs probe-and-shift at creation, and
  once a project has shifted, nothing records where it actually landed. The
  fallback quietly reintroduces a registry, without the legibility of a real one.

### Per-project sentinel in the container's own volume
- **Pros:** Matches the existing `mosh dcg` / `mosh playwright` precedent.
- **Cons:** Structurally cannot work. Detecting a collision requires seeing every
  project at once, and a per-project volume only ever sees itself.

### Contiguous container ports (3000-3009) instead of a curated set
- **Pros:** Simplest arithmetic, uniform block.
- **Cons:** Every tool then needs an explicit `--port`, since none of the common
  dev-server defaults except 3000 fall inside the range.

### Binding `0.0.0.0` on the host
- **Pros:** Lets a phone or another machine reach the dev server.
- **Cons:** Exposes every project's unauthenticated dev server to the LAN
  whenever a container runs. Rejected as a default; can be revisited as an
  opt-in toggle mirroring `mosh dcg` if the need arises.

### A reverse proxy or shared gateway container
- **Pros:** One host port total; no per-project allocation.
- **Cons:** Far more moving parts than the problem justifies, and adds a
  component that must be running for any project to serve anything.
