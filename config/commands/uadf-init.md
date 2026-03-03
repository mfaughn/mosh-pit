---
description: Initialize a project with UADF (Universal Agentic Development Framework)
argument-hint: [project-name]
---

# UADF Project Initialization: $ARGUMENTS

We are initializing **$ARGUMENTS** using the Universal Agentic Development Framework.

Read the UADF framework at @~/.claude/uadf/framework.md to understand the protocol.

---

## Phase 0: Pre-Flight Checks

**Before doing anything else**, run these checks and report any issues:

### Check 1: Existing UADF Files
```bash
ls -la CLAUDE.md spec.md blueprint.md TASKS.md JOURNAL.md ARCHITECTURE.md 2>/dev/null
```

If any exist, **STOP and alert the user**:
> "I found existing UADF files: [list]. This might be an existing UADF project.
> Options:
> 1. Run `/uadf-start` to resume the existing project
> 2. Back up existing files and proceed with fresh init
> 3. Cancel and let me review what's here first
> Which would you prefer?"

### Check 2: Existing Git Repository
```bash
git status 2>/dev/null
```

If git exists with uncommitted changes, **alert the user**:
> "This directory has an existing git repo with uncommitted changes.
> Options:
> 1. Commit or stash changes first, then continue
> 2. Proceed anyway (I won't touch your existing files until you confirm)
> Which would you prefer?"

### Check 3: Non-Empty Directory
```bash
ls -A
```

If directory has files, **inform the user** (not a blocker, just awareness):
> "This directory contains existing files: [summary]. I'll create UADF files alongside them. Let me know if you'd prefer a clean directory."

### Check 4: Project CLAUDE.md Conflicts
If a `CLAUDE.md` already exists, read it and check for conflicting workflow instructions. Alert if found:
> "Your existing CLAUDE.md has workflow instructions that might conflict with UADF: [specifics].
> Options:
> 1. Merge UADF instructions into existing CLAUDE.md
> 2. Replace with UADF CLAUDE.md (I'll back up the original)
> 3. Let me review and decide
> Which would you prefer?"

**Only proceed after checks pass or user confirms how to handle issues.**

---

## Phase 1: Create Project Structure

Initialize git if not already initialized:
```bash
git init
```

Create the `docs/adr/` directory for Architecture Decision Records:
```bash
mkdir -p docs/adr
```

---

## Phase 2: Interview Me

Ask me ONE question at a time to understand the project. Cover:
1. What problem are we solving?
2. Who are the target users?
3. What are the key features (prioritized)?
4. What tech stack should we use?
5. Any constraints (performance, deployment, integrations)?
6. What should be explicitly out of scope?

---

## Phase 3: Generate UADF Files

Based on interview answers, create these files using the templates in @~/.claude/uadf/templates/:

1. **`CLAUDE.md`** — Project instructions:
   - Project overview (1-2 sentences)
   - Build/test/lint commands
   - Tech stack
   - Conventions specific to this project
   - Add: `uadf_team_mode: false` (can be enabled later with `/uadf-team-on`)

2. **`spec.md`** — Product specification (WHAT we're building):
   - Use template from @~/.claude/uadf/templates/spec.md
   - Fill in based on interview

3. **`ARCHITECTURE.md`** — System design:
   - Use template from @~/.claude/uadf/templates/ARCHITECTURE.md
   - Adapt to the project's tech stack

4. **`JOURNAL.md`** — Project log:
   - Use template from @~/.claude/uadf/templates/JOURNAL.md
   - Record initial decisions from interview

5. **`blueprint.md`** — Implementation plan (HOW we'll build it):
   - Use template from @~/.claude/uadf/templates/blueprint.md
   - Break down into phases and tasks
   - **I must approve this before any implementation**

6. **`TASKS.md`** — Task list:
   - Use template from @~/.claude/uadf/templates/TASKS.md
   - Derive tasks from blueprint

---

## Phase 4: Create First ADR

Create `docs/adr/0001-initial-tech-stack.md` documenting the tech stack decision using @~/.claude/uadf/templates/adr-template.md

---

## Phase 5: Confirm Setup

After creating all files:
- Summarize what was created
- Ask me to approve `blueprint.md`
- Remind me: "No implementation until blueprint is approved"
- Mention: "Run `/uadf-team-on` if you want to enable agent team mode for this project"

---

**IMPORTANT:** Do NOT write any implementation code during initialization. This phase is planning only.

Begin with Phase 0 (pre-flight checks), then ask me the first interview question.
