---
description: Start a new task following UADF TDD lifecycle
argument-hint: [task-description]
---

# UADF Task: $ARGUMENTS

Starting a new task following the UADF TDD lifecycle.

---

## Step 0: Check Team Mode

Read `CLAUDE.md` and check for `uadf_team_mode: true`.

- **If team mode is OFF (default):** Follow the Single Agent Workflow below.
- **If team mode is ON:** Follow the Team Mode Workflow below.

---

# Single Agent Workflow

(Used when `uadf_team_mode` is `false` or not set)

## 1. Create Task Entry

Add this task to `TASKS.md` with the next available task ID:

```markdown
### TASK-NNN: $ARGUMENTS
- **Status:** IN_PROGRESS
- **Branch:** `feature/NNN-[short-kebab-description]`
- **Test File:** [path to test file]
- **Acceptance Criteria:**
  - [ ] [Criterion from spec.md or interview]
- **Notes:**
```

## 2. Create Feature Branch

```bash
git checkout main
git pull origin main  # if remote exists
git checkout -b feature/NNN-[short-kebab-description]
```

## 3. Interview for Clarity (if needed)

If the task is ambiguous, ask me ONE question at a time:
- What's the expected behavior?
- What are the edge cases?
- How does this integrate with existing code?
- What file(s) should this live in?

## 4. Write Failing Test (RED)

Based on acceptance criteria, write a test that:
- Describes the expected behavior
- Currently fails because the feature doesn't exist

```bash
# Run the test to confirm it fails
npm test -- --grep "[test name]"

# Checkpoint commit
git add -A
git commit -m "RED: [test description] fails"
```

**STOP and show me:** The failing test and the error message.

## 5. Implement (GREEN)

Write the minimal code to make the test pass:
- No gold-plating
- No "while I'm here" improvements
- Just make the test green

```bash
# Run tests
npm test

# Checkpoint commit
git add -A
git commit -m "GREEN: [test description] passes"
```

**STOP and show me:** The passing test.

## 6. Refactor (if needed)

Clean up without changing behavior:
- Extract functions if needed
- Improve naming
- Remove duplication

```bash
# Ensure tests still pass
npm test

# Checkpoint commit (only if you refactored)
git add -A
git commit -m "REFACTOR: [what changed]"
```

## 7. Complete Task

Update `TASKS.md`:
- Change status to `COMPLETED`
- Check off acceptance criteria
- Add any notes

Ask me: "Ready to merge to main, or continue with more tasks on this branch?"

---

# Team Mode Workflow

(Used when `uadf_team_mode` is `true`)

## 1. Announce Team Mode

```
[UADF Team] Team mode is ENABLED
[UADF Team] Task: $ARGUMENTS
[UADF Team] Spawning Dev agent...
```

## 2. Create Task Entry

Same as single agent — add to `TASKS.md` with task ID.

## 3. Spawn Dev Agent

Use the Task tool to spawn a Dev agent with subagent_type "general-purpose":

**Dev Agent Instructions:**
```
You are the UADF Dev agent. Your job is to implement TASK-NNN: $ARGUMENTS

Follow TDD strictly:
1. Create feature branch: git checkout -b feature/NNN-[description]
2. Write a failing test first
3. Commit: "RED: [test] fails"
4. Implement minimal code to pass
5. Commit: "GREEN: [test] passes"
6. Refactor if needed
7. Commit: "REFACTOR: [what]"

Read the project's CLAUDE.md for build/test commands.
Read spec.md for acceptance criteria.

When done, report:
- What you implemented
- What tests you wrote
- Any concerns or edge cases you noticed

Do NOT merge to main. Leave the branch for review.
```

## 4. Report Dev Progress

As Dev agent works, relay progress:
```
[UADF Dev] Creating branch feature/NNN-description
[UADF Dev] Writing failing test...
[UADF Dev] RED: [test description] fails - committed
[UADF Dev] Implementing...
[UADF Dev] GREEN: [test description] passes - committed
[UADF Dev] Implementation complete
```

## 5. Spawn QA Agent

After Dev completes, spawn a QA agent:

**QA Agent Instructions:**
```
You are the UADF QA agent. Review the Dev agent's work on branch feature/NNN-[description].

Your job:
1. git checkout feature/NNN-[description]
2. Read the implementation
3. Run tests: npm test
4. Review code for:
   - Does it meet acceptance criteria in spec.md?
   - Are there missing edge cases?
   - Any obvious bugs or security issues?
   - Code quality concerns?

Report:
- APPROVED: Ready to merge (explain why it's good)
- NEEDS CHANGES: List specific issues to fix

Be constructive. Focus on real problems, not style nitpicks.
```

## 6. Report QA Results

```
[UADF QA] Reviewing implementation...
[UADF QA] Running tests... all pass
[UADF QA] Checking acceptance criteria...
[UADF QA] Result: APPROVED / NEEDS CHANGES
[UADF QA] Feedback: [summary]
```

## 7. Handle QA Feedback

- **If APPROVED:** Report to user, ask if ready to merge
- **If NEEDS CHANGES:** Send feedback to Dev agent for iteration, repeat review cycle

## 8. Complete Task

After approval:
- Update `TASKS.md` status to `COMPLETED`
- Ask user: "QA approved. Ready to merge to main?"

---

# Non-TDD Tasks

If this task doesn't fit TDD (config, docs, styling), still:
1. Create the branch
2. Make checkpoint commits
3. Verify the change works
4. Update TASKS.md

Just skip the RED/GREEN pattern. In team mode, QA still reviews but focuses on correctness rather than test coverage.
