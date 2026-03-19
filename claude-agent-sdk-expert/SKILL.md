---
name: claude-agent-sdk-expert
description: |
  Use when reviewing, debugging, or building AI agents with the Claude Agent SDK (TypeScript or Python).
  Covers the Agent class, query(), agent.stream(), tool_use, tool schemas, maxIterations, subagents,
  hooks (PreToolCall, PostToolCall, StopHook), MCP integration, multi-agent coordination, structured output,
  context window management, stop_reason handling, and agentic loop architecture.
  Do NOT activate for general Claude API usage without agents, simple messages.create() calls,
  or non-agent Anthropic SDK usage — use the claude-api skill for those.
license: MIT
metadata:
  author: Chris Raroque
  version: "1.1"
---

# Claude Agent SDK Expert

## Why This Skill Exists

AI-assisted agent development introduces characteristic failure modes that traditional code review misses. Agents fail silently — they hallucinate tool calls, lose context mid-conversation, swallow errors into infinite retry loops, and produce outputs that look correct but aren't grounded in actual tool results. This skill encodes hard-won patterns from building production Claude agents so you catch these issues before they ship.

## Core Principle

> An agent is only as good as its tools and instructions. The SDK handles the loop — your job is to give it clear tools, clear prompts, and clear boundaries.

## Process

Work through each step below. Step 0 is **always loaded**. For remaining steps, load the referenced file **only if relevant** to the current task. Skip steps that don't apply.

### Step 0: Known Gotchas (Always Load)

Before any deep review or build, scan for the top 10 most common agent mistakes. These are fast to check and catch the majority of production incidents.

```
Read file: references/gotchas.md
```

### Quick Scan (Review Mode)

For code reviews, run the static analysis script first to surface mechanical anti-patterns before doing a manual review. This catches issues like missing `maxIterations`, `tool_choice: "any"`, silent catch blocks, and missing `additionalProperties: false`.

```bash
bash scripts/scan-agent-patterns.sh <target-directory>
```

Review the output, then proceed with the manual steps below for deeper analysis.

### Step 1: Agentic Loop Architecture

Evaluate the core agent loop structure, stop condition handling, and iteration guards.

```
Read file: references/agentic-loop.md
```

### Step 2: Tool Design & Scoping

Review tool definitions for clarity, scope, and schema quality. Ensure descriptions serve as the primary selection mechanism.

```
Read file: references/tool-design.md
```

### Step 3: Prompt Engineering for Agents

Assess system prompts, instruction clarity, and few-shot example usage.

```
Read file: references/prompt-engineering.md
```

### Step 4: Structured Output & Schema Design

Check extraction patterns, schema strictness, and field design.

```
Read file: references/structured-output.md
```

### Step 5: Context Management

Evaluate context window usage, session management, and information retention strategies.

```
Read file: references/context-management.md
```

### Step 6: MCP Integration

Review MCP server configuration, tool namespacing, and integration patterns.

```
Read file: references/mcp-integration.md
```

### Step 7: Error Handling & Reliability

Assess error propagation, validation loops, retry strategies, and escalation triggers.

```
Read file: references/error-handling.md
```

### Step 8: Hooks & Lifecycle

Review PreToolCall, PostToolCall, and StopHook implementations for correctness and safety.

```
Read file: references/hooks-lifecycle.md
```

### Step 9: Multi-Agent Patterns

Evaluate coordinator-subagent architecture, context passing, and handoff patterns.

```
Read file: references/multi-agent.md
```

## Core Instructions

1. **Report genuine issues only.** Do not fabricate problems. If the code is solid, say so.
2. **Prioritize by impact.** Critical issues (crashes, infinite loops, data loss) first, style nits last.
3. **Skip irrelevant sections.** If the agent doesn't use MCP, skip Step 6. If it's single-agent, skip Step 9.
4. **Dual mode — review and build.**
   - **Review mode**: Audit existing agent code. Output severity-ranked findings with concrete fixes.
   - **Build mode**: Help write new agent code. Follow the process steps as a checklist to ensure nothing is missed.
5. **Show, don't tell.** Every finding or recommendation must include a concrete code example — before/after for reviews, working snippets for builds.
6. **Ground in SDK reality.** Reference actual SDK APIs (`query()`, `tool_use`, `stop_reason`, hooks, etc.). Do not invent APIs that don't exist.
7. **Maintain the review log.** After completing a review or build session, append a one-line JSON entry to `data/review-log.jsonl`:
   ```json
   {"date":"YYYY-MM-DD","mode":"review|build","project":"project-name","sdk":"ts|py","findings":["finding1","finding2"],"severity_counts":{"critical":0,"high":0,"medium":0,"low":0}}
   ```
   At session start, if `data/review-log.jsonl` exists, read it and note recurring patterns across past sessions to inform the current review.

## Output Format

### Review Mode

Rank findings by severity:

```
## [CRITICAL] Issue title
**What**: Description of the problem
**Why it matters**: Impact (crashes, data loss, infinite loops, etc.)
**Where**: File and line reference
**Fix**:
// Before (BAD)
<problematic code>

// After (GOOD)
<fixed code>
```

```
## [HIGH] Issue title
...

## [MEDIUM] Issue title
...

## [LOW] Issue title
...
```

### Build Mode

Structure output as:

1. **Architecture Decision** — Which pattern to use and why
2. **Implementation** — Working code following all best practices
3. **Checklist** — Verification points from the relevant process steps

## References

| # | Topic | File |
|---|-------|------|
| 0 | **Gotchas (Always Load)** | `references/gotchas.md` |
| 1 | Agentic Loop Architecture | `references/agentic-loop.md` |
| 2 | Tool Design & Scoping | `references/tool-design.md` |
| 3 | Prompt Engineering | `references/prompt-engineering.md` |
| 4 | Structured Output | `references/structured-output.md` |
| 5 | Context Management | `references/context-management.md` |
| 6 | MCP Integration | `references/mcp-integration.md` |
| 7 | Error Handling | `references/error-handling.md` |
| 8 | Hooks & Lifecycle | `references/hooks-lifecycle.md` |
| 9 | Multi-Agent Patterns | `references/multi-agent.md` |
