# Multi-Agent Patterns

## Coordinator-Subagent Architecture

The most effective multi-agent pattern is a coordinator that delegates to specialized subagents. The coordinator understands the overall task and routes subtasks to agents with focused tool sets and instructions.

```typescript
import { Agent } from "claude-agent-sdk";

// Subagent: Focused on code analysis
const codeAnalyzer = new Agent({
  name: "code-analyzer",
  model: "claude-sonnet-4-6-20250514",
  instructions: `You analyze code for bugs and anti-patterns.
Focus only on correctness and reliability issues — ignore style.
Return findings as a structured list with file, line, severity, and description.`,
  tools: [readFileTool, searchCodeTool, grepTool],
});

// Subagent: Focused on documentation
const docWriter = new Agent({
  name: "doc-writer",
  model: "claude-sonnet-4-6-20250514",
  instructions: `You write technical documentation based on code analysis.
Write concise, accurate docs. Do not speculate about code behavior — only document what you can verify by reading the code.`,
  tools: [readFileTool, writeFileTool],
});

// Coordinator: Orchestrates the workflow
const coordinator = new Agent({
  name: "code-review-coordinator",
  model: "claude-sonnet-4-6-20250514",
  instructions: `You coordinate code reviews.

Process:
1. Use the code-analyzer subagent to find issues in the changed files
2. Use the doc-writer subagent to update documentation if needed
3. Synthesize findings into a review summary

Only delegate to subagents — do not read or modify files directly.`,
  tools: [
    codeAnalyzer.asTool("analyze_code", "Analyze code files for bugs and anti-patterns"),
    docWriter.asTool("write_docs", "Write or update documentation based on findings"),
  ],
});
```

## Context Passing

Pass only what each subagent needs. Over-sharing context wastes tokens and can confuse the subagent.

```typescript
// BAD: Dumping everything to the subagent
const analyzerTool = {
  name: "analyze",
  async run(input: { task: string }) {
    return await codeAnalyzer.query(
      `Full conversation so far: ${entireConversation}\n\n` +
      `All files in repo: ${allFiles}\n\n` +
      `Task: ${input.task}`
    );
  },
};

// GOOD: Focused context for the specific subtask
const analyzerTool = {
  name: "analyze",
  async run(input: { files: string[]; focusAreas: string[] }) {
    return await codeAnalyzer.query(
      `Analyze these files for issues:\n` +
      `Files: ${input.files.join(", ")}\n` +
      `Focus areas: ${input.focusAreas.join(", ")}`
    );
  },
};
```

## Subagent Isolation

Subagents should be self-contained. They get their own tools, instructions, and context. They should NOT:
- Know about other subagents
- Share state with other subagents
- Assume context from the coordinator's conversation

```typescript
// BAD: Subagent references another subagent
const subagentA = new Agent({
  instructions: "After you're done, pass results to the doc-writer agent",
  // Subagent A shouldn't know about subagent B
});

// GOOD: Subagent is self-contained
const subagentA = new Agent({
  instructions: "Analyze the provided code and return structured findings. Your output will be used by other systems — be precise and complete.",
  // No knowledge of other agents — the coordinator handles handoffs
});
```

## Structured Handoffs

The coordinator should pass structured data between subagents, not raw text:

```typescript
// BAD: Passing raw text between subagents
const analysisResult = await codeAnalyzer.query("Analyze auth.ts");
await docWriter.query(`Here's what the analyzer found: ${analysisResult.content}`);
// docWriter has to parse free-text to understand findings

// GOOD: Structured handoff
const analysisResult = await codeAnalyzer.query("Analyze auth.ts");
// Coordinator parses the structured findings
const findings = parseFindings(analysisResult.content);

await docWriter.query(
  `Update documentation for the following confirmed issues:\n` +
  JSON.stringify(findings.filter(f => f.severity === "critical"), null, 2)
);
```

## When to Use Multi-Agent

**Use multi-agent when:**
- Different subtasks need different tool sets (separation of concerns)
- Subtasks have different trust levels (e.g., read-only analyst vs. read-write editor)
- You need to parallelize independent work streams
- Context isolation is important (subagent A's tool results shouldn't pollute subagent B's context)

**Don't use multi-agent when:**
- A single agent with 4-5 tools can handle the entire workflow
- The "subtasks" are sequential and share all context
- You're adding multi-agent purely for architectural elegance

## Anti-Patterns to Detect

1. **Circular delegation**: Agent A delegates to Agent B, which delegates back to Agent A. This creates infinite loops.

```typescript
// BAD: Potential circular delegation
const agentA = new Agent({
  tools: [agentB.asTool("call_b", "...")],
});
const agentB = new Agent({
  tools: [agentA.asTool("call_a", "...")], // Circular!
});
```

2. **Subagents knowing each other**: Subagents that reference other subagents by name or assume they exist. All coordination should go through the coordinator.

3. **Premature multi-agent**: Splitting a simple task into coordinator + subagents when one agent would suffice. This adds latency (each subagent call is a full API round trip), complexity, and token cost.

```
// Signs you've over-architected:
// - Coordinator just passes through to a single subagent
// - Subagents have overlapping tool sets
// - You're passing the full context to every subagent anyway
// - The task completes in 2-3 tool calls total
```

4. **No result synthesis**: Coordinator delegates to subagents but doesn't synthesize their results. It just concatenates outputs, losing the coordination value.

5. **Shared mutable state**: Subagents writing to the same file, database, or resource without coordination. This leads to race conditions and overwritten results.

```typescript
// BAD: Both subagents write to the same file
const subagentA = new Agent({ tools: [writeFileTool] }); // Writes to report.md
const subagentB = new Agent({ tools: [writeFileTool] }); // Also writes to report.md
// Whoever writes last wins — other's work is lost

// GOOD: Subagents return results, coordinator writes
const subagentA = new Agent({ tools: [readFileTool, analysisTool] });
const subagentB = new Agent({ tools: [readFileTool, analysisTool] });
// Coordinator collects both results and writes the final report
```

6. **Unbalanced subagent workloads**: One subagent doing 90% of the work while others sit idle. This suggests the decomposition is wrong.
