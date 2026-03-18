# Context Management

## Context Window Limits

Every model has a finite context window. Agent conversations consume context fast because each tool call and result adds to the message history. A single agentic loop can easily burn through 50-100k tokens.

| Model | Context Window | Practical Limit* |
|-------|---------------|-----------------|
| Claude Sonnet 4.6 | 200k tokens | ~150k usable |
| Claude Opus 4.6 | 200k tokens | ~150k usable |
| Claude Haiku 4.5 | 200k tokens | ~150k usable |

*Practical limit accounts for system prompt, tool definitions, and output tokens.

## Persistent Case Facts

When an agent works through a multi-step task, critical facts from early steps can get "pushed out" of the model's effective attention by later tool results. This is the **lost-in-the-middle** effect.

```typescript
// BAD: Relying on the model to remember facts from 20 tool calls ago
const agent = new Agent({
  instructions: "You are a research assistant. Investigate the issue and write a report.",
  tools: [searchTool, readTool, writeTool],
});
// After 15 tool calls, the model forgets what it found in call #2

// GOOD: Use a scratch pad tool to persist key findings
const scratchPadTool = {
  name: "save_finding",
  description: "Save an important finding to your scratch pad. Use this to record key facts you'll need later. The scratch pad persists across all tool calls.",
  inputSchema: {
    type: "object",
    properties: {
      key: { type: "string", description: "Short label for this finding" },
      value: { type: "string", description: "The finding or fact to save" },
    },
    required: ["key", "value"],
    additionalProperties: false,
  },
};

const readScratchPadTool = {
  name: "read_findings",
  description: "Read all saved findings from your scratch pad. Use this before writing your final report to ensure you include all key facts.",
  inputSchema: {
    type: "object",
    properties: {},
    additionalProperties: false,
  },
};
```

## Session Management

For long-running agent tasks, manage context deliberately:

```typescript
// BAD: One massive conversation that hits context limits
const result = await agent.query(
  "Analyze all 500 files in the repository and report issues"
);
// Context overflow halfway through

// GOOD: Chunk work and summarize between chunks
const files = await getFileList();
const chunkSize = 20;
const findings = [];

for (let i = 0; i < files.length; i += chunkSize) {
  const chunk = files.slice(i, i + chunkSize);
  const result = await agent.query(
    `Analyze these files and report issues:\n${chunk.join("\n")}\n\n` +
    `Previous findings summary: ${findings.length} issues found so far.`
  );
  findings.push(...parseFindings(result));
  // Each chunk starts with a fresh(er) context
}
```

## Context Passing to Subagents

When delegating to subagents, pass only what they need:

```typescript
// BAD: Passing full conversation history to subagent
const subagent = new Agent({
  name: "summarizer",
  instructions: "Summarize the provided content.",
  tools: [],
});
const result = await subagent.query(fullConversationHistory); // Wasteful, noisy

// GOOD: Pass a focused, minimal context
const subagent = new Agent({
  name: "summarizer",
  instructions: "Summarize the key findings from the provided text. Focus on actionable items.",
  tools: [],
});
const result = await subagent.query(
  `Summarize these findings:\n\n${findings.map(f => `- ${f.title}: ${f.detail}`).join("\n")}`
);
```

## Anti-Patterns to Detect

1. **Full context to subagents**: Dumping the entire parent conversation into a subagent's context. Subagents should receive only the information they need for their specific task.

2. **No summarization strategy**: Letting tool results accumulate without any mechanism to compress or summarize intermediate findings. Eventually, early context is effectively invisible.

3. **Unbounded tool output**: Tools that return full file contents, complete database results, or verbose API responses without truncation or summarization. One large tool result can push everything else out of effective attention.

```typescript
// BAD: Tool returns full file
async function readFile(path: string) {
  return fs.readFileSync(path, "utf-8"); // Could be 10k lines
}

// GOOD: Tool returns relevant portion
async function readFile(input: { path: string; startLine?: number; endLine?: number }) {
  const content = fs.readFileSync(input.path, "utf-8");
  const lines = content.split("\n");
  const start = input.startLine ?? 1;
  const end = input.endLine ?? Math.min(start + 100, lines.length);
  return {
    content: lines.slice(start - 1, end).join("\n"),
    totalLines: lines.length,
    showing: `lines ${start}-${end}`,
  };
}
```

4. **No context window awareness**: Not considering how many tokens the agent has consumed and whether it's approaching limits. For long tasks, implement checkpointing.

5. **Repeated information**: Including the same context in every tool call result (e.g., appending system info to every response). This wastes tokens on redundant information the model already has.
