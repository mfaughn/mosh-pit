# Zombie Process Accumulation in Claude Code Containers: Problem Analysis and Mitigation

## Summary

Claude Code sessions running inside Docker/Podman containers without a proper init process will
accumulate zombie (defunct) subprocesses over time. This causes the Claude Code event loop to
eventually freeze — the session becomes unresponsive, keyboard input stops working, the status
animation halts, and Escape does nothing. The only recovery is to kill and restart the container,
losing session context. The fix is to run Claude Code under `tini`, a minimal init process designed
for containers.

---

## The Problem in Detail

### What Claude Code does

Claude Code is a Node.js process. During agentic operation it spawns subprocesses to execute tools:
bash commands, test runners (vitest, jest), build tools (esbuild, npm scripts), linters, Python
scripts, and so on. After each subprocess completes, the parent process is expected to call
`waitpid()` to collect the child's exit status and remove it from the kernel's process table.

### What goes wrong

In a container without an init process, Claude Code runs as **PID 1**. PID 1 is special in Linux:
it is the init process, and the kernel does not deliver the default `SIGCHLD` handling to it.
Normally, the kernel would nudge a process when a child exits. As PID 1, Claude Code must
explicitly and proactively reap children — and Node.js does not do this reliably for all
subprocess patterns.

When a subprocess finishes but the parent hasn't called `wait()`, the child becomes a **zombie**
(shown as `<defunct>` in `ps aux`). Zombies hold a slot in the kernel process table and retain
their exit status, but otherwise consume no memory or CPU — they are just waiting to be reaped.

### How zombies cause a freeze

Claude Code blocks its event loop when it tries to communicate with a subprocess that it believes
is still running (via a pipe or IPC channel) but which has already died uncleanly. The typical
sequence is:

1. Claude Code spawns a subprocess (e.g., `npm exec vitest`)
2. The subprocess crashes or is killed before it writes its full output
3. The pipe buffer fills, or the read end of the pipe blocks waiting for data that will never come
4. Claude Code's event loop is now stuck in a blocking `read()` syscall
5. Since the event loop is blocked, no input is processed — keyboard, Escape, signals via the
   terminal — nothing gets through
6. The status animation freezes because it too depends on the event loop

### What we observed

In a real session running FHIR-related TypeScript development over ~5 hours:

- **200+ zombie processes** accumulated (`esbuild`, `vitest`, `node (vitest 1-4)`, `sh`, `npm`)
- Several zombie vitest worker threads showed **7–22% CPU usage** — indicating they were not
  fully dead but in uninterruptible states, likely blocked on I/O or IPC
- The pattern was consistent: each vitest run left behind a cluster of 5–8 zombies
- The container's Claude Code session became completely unresponsive
- `kill -CHLD 1` (sending SIGCHLD to the Claude Code process) was attempted as a non-destructive
  nudge; it did not recover the session
- The container had to be killed and restarted, losing session context

A second container running a different Claude Code session showed only 2 zombie Python processes
but had also frozen — confirming that even a small number of un-reaped zombies can trigger the
deadlock if Claude Code is blocked on the right pipe.

---

## Why This Happens More with Certain Workloads

The problem is worse when Claude Code is:

- **Running tests repeatedly** — test frameworks like vitest spawn worker thread pools; each run
  produces multiple processes that must all be reaped
- **Doing iterative build/test loops** — esbuild is spawned as a subprocess by vitest and other
  tools; rapid iteration produces rapid zombie accumulation  
- **Running long agentic sessions** — more tool calls = more subprocesses = higher probability of
  hitting the deadlock

Memory pressure is **not** the cause. The frozen sessions observed had 1.1GB and 344MB usage
respectively against a 16GB Podman VM limit — well within bounds.

---

## The Fix: tini as PID 1

### What tini is

`tini` is a minimal init process (~25KB) designed specifically for containers. Its only jobs are:

1. **Zombie reaping** — it calls `waitpid(-1, WNOHANG)` in a loop, reaping any zombie child
   regardless of which process spawned it
2. **Signal forwarding** — it forwards signals (SIGINT, SIGTERM, etc.) to the process it manages
3. **Correct PID 1 behavior** — it handles the special responsibilities that come with being PID 1

With tini as PID 1, Claude Code runs as a normal child process (e.g., PID 2+). Any zombie it
creates gets adopted and reaped by tini before it can accumulate and cause problems.

### Implementation options

#### Option 1: Dockerfile ENTRYPOINT (recommended for your framework)

```dockerfile
# Install tini
RUN apt-get update && apt-get install -y tini && rm -rf /var/lib/apt/lists/*

# Use tini as the entrypoint, with claude as the managed process
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude"]
```

When Claude Code spawns subprocesses, tini will automatically reap any that become zombies.
The `--` separator tells tini to pass all remaining arguments to the child process.

#### Option 2: podman/docker run flag

```bash
podman run --init your-image
# or
docker run --init your-image
```

This injects the container runtime's bundled init (usually tini or catatonit) as PID 1 without
modifying the Dockerfile. Simpler for ad-hoc use, but the Dockerfile approach is more explicit
and portable.

#### Option 3: Explicit tini binary in your framework launch script

If your container framework has a launch script that starts Claude Code, you can prepend tini:

```bash
exec tini -- claude "$@"
```

### Verifying tini is working

After adding tini, confirm it's running as PID 1:

```bash
podman exec -it <container> ps aux | head -5
```

You should see something like:
```
PID   USER     COMMAND
1     claude   /usr/bin/tini -- claude
2     claude   claude
...
```

To confirm zombie reaping is working during a long session, periodically check:
```bash
podman exec -it <container> ps aux | grep defunct | wc -l
```

With tini, this count should stay near zero even during heavy vitest/esbuild workloads.

---

## Additional Mitigations for Context Loss

Even with tini preventing freezes, long Claude Code sessions can still be interrupted. These
practices reduce the cost of any restart:

### Periodic /compact

Run `/compact` in the Claude Code session periodically during long agentic tasks. This compresses
the conversation history into a summary, so if the session must be restarted, the new session can
be initialized with the compact summary rather than starting cold.

### Checkpoint outputs to files

Instruct Claude Code to write important intermediate outputs, decisions, and plans to files in the
workspace as it goes — not just at the end. Files survive container restarts; context does not.

### Keep a diagnostic terminal open

Maintain a second `podman exec -it <container> bash` session in the container at all times.
This gives you a live diagnostic window without needing to scramble for access when the primary
session freezes.

### Recovery sequence (if a freeze occurs before tini is in place)

1. From a second terminal in the container: `kill -CHLD 1` — non-destructive nudge, worth trying
2. If no recovery after a few seconds: `podman kill --signal=KILL <container>` from the host
3. Restart the container
4. Initialize the new Claude Code session with any compact summary or checkpoint files from the
   previous session

---

## Notes for Framework Integration

When building the container launch framework, consider:

- **Always use tini** — make it a non-negotiable part of the base image, not an option
- **PID limit headroom** — each vitest run produces ~8 processes; long sessions can accumulate
  hundreds of PIDs even with tini (tini reaps them but they still exist briefly). If you hit
  container PID limits, set `--pids-limit` on the container to something generous (e.g., 2000)
  rather than the default
- **Session persistence** — consider whether the framework should snapshot `/compact` output
  automatically on a timer or before shutdown
- **Agentic loop guardrails** — the zombie accumulation was partly caused by Claude Code running
  vitest dozens of times in a loop trying to fix failing tests. Framework-level limits on repeated
  tool invocations (e.g., max N consecutive bash executions) could prevent runaway loops that
  accelerate zombie accumulation

---

*Document prepared based on live diagnostic session, March 2026.*
