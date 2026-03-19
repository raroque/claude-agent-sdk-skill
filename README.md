# Claude Agent SDK Expert

**Agent Skill for AI Coding Assistants**

![Claude Agent SDK](https://img.shields.io/badge/Claude-Agent%20SDK-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)
![Author: @raroque](https://img.shields.io/badge/Author-@raroque-orange)

Built by [Chris Raroque](https://github.com/raroque) in collaboration with [Aloa](https://aloa.co).

---

## Background

AI-assisted agent development introduces failure modes that traditional code review misses. Agents hallucinate tool calls, lose context mid-conversation, swallow errors into infinite retry loops, and produce outputs that look correct but aren't grounded in actual tool results.

This skill encodes hard-won patterns from building production Claude agents. It works in two modes:

- **Review mode**: Audits existing agent code for anti-patterns, ranked by severity
- **Build mode**: Helps write new agent code with best practices baked in

## Installation

### Using npx (recommended)

```bash
npx skills add https://github.com/raroque/claude-agent-sdk-skill
```

### Manual installation

```bash
git clone https://github.com/raroque/claude-agent-sdk-skill.git
cp -r claude-agent-sdk-skill/claude-agent-sdk-expert/ ~/.claude/skills/claude-agent-sdk-expert/
```

## Usage

### Claude Code

```
/claude-agent-sdk-expert
```

Or just describe what you need — the skill activates automatically when your conversation involves agent development:

- "Review my agent code for anti-patterns"
- "Help me build a multi-agent system"
- "Is my tool design correct?"
- "Why is my agent looping?"

### OpenAI Codex

```
$claude-agent-sdk-expert
```

## What It Covers

| Category | Key Catches |
|----------|-------------|
| **Gotchas (Always Loaded)** | Top 10 most common mistakes — missing `maxIterations`, silent catches, manual loops, `tool_choice: "any"`, and more |
| **Agentic Loop** | Reimplemented loops, missing iteration guards, ignored `max_tokens` truncation |
| **Tool Design** | Vague descriptions, too many tools, side-effect-only tools, unbounded output |
| **Prompt Engineering** | Over-prompting, buried critical rules, missing stopping criteria |
| **Structured Output** | Raw JSON parsing, all-optional schemas, deep nesting, missing `additionalProperties: false` |
| **Context Management** | Full context to subagents, no summarization, unbounded tool output |
| **MCP Integration** | Too many servers, name conflicts, hardcoded secrets, missing env vars |
| **Error Handling** | Opaque errors, silent failures, infinite retry loops, missing timeouts |
| **Hooks & Lifecycle** | Business logic in hooks, blocking without timeout, StopHook infinite loops |
| **Multi-Agent** | Circular delegation, subagents knowing each other, premature multi-agent |

## Quick Scan

The skill includes a static analysis script that greps for common anti-patterns before a manual review. No dependencies required — it's a portable bash script.

```bash
bash claude-agent-sdk-expert/scripts/scan-agent-patterns.sh ./my-agent-project
```

Output format: `[PATTERN_NAME] file:line — description`. Catches missing `maxIterations`, `tool_choice: "any"`, silent catch blocks, missing `additionalProperties: false`, short tool descriptions, manual agentic loops, and JSON.parse on text output.

The script is informational (always exits 0) — it's a fast first pass, not a gate.

## Session Memory (Review Log)

The skill maintains a review log at `claude-agent-sdk-expert/data/review-log.jsonl`. After each review or build session, a one-line JSON entry is appended with the date, mode, project, SDK language, findings, and severity counts. On subsequent sessions, the skill reads this log to identify recurring patterns across reviews.

The log files are git-ignored so they stay local to your machine.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. We welcome new anti-patterns, better examples, corrections, and real-world failure cases.

## License

[MIT](LICENSE)
