# Agentic Loop Architecture

## Core Pattern

The Claude Agent SDK manages the agentic loop for you. The `query()` function sends a message, receives a response, checks if the model wants to use tools, executes them, and loops until the model stops. Your job is to configure it correctly — not to reimplement it.

```typescript
// GOOD: Let the SDK handle the loop
const agent = new Agent({
  name: "research-agent",
  model: "claude-sonnet-4-6-20250514",
  instructions: "You are a research assistant...",
  tools: [searchTool, readTool, summarizeTool],
});

const result = await agent.query("Find recent papers on transformer efficiency");
```

```python
# GOOD: Python equivalent
agent = Agent(
    name="research-agent",
    model="claude-sonnet-4-6-20250514",
    instructions="You are a research assistant...",
    tools=[search_tool, read_tool, summarize_tool],
)

result = await agent.query("Find recent papers on transformer efficiency")
```

## Stop Reason Handling

The SDK loop continues until the model returns a `stop_reason` of `end_turn`. Understanding stop reasons is critical:

| `stop_reason` | Meaning | SDK Behavior |
|---------------|---------|--------------|
| `end_turn` | Model is done | Loop exits, returns result |
| `tool_use` | Model wants to call a tool | SDK executes tool, feeds result back |
| `max_tokens` | Response was truncated | **Danger zone** — see below |

### max_tokens Truncation

When the model hits `max_tokens`, its response is cut off mid-generation. This is almost always a bug, not intentional behavior.

```typescript
// BAD: Ignoring max_tokens — agent silently produces truncated output
const result = await agent.query(prompt);
// If stop_reason was max_tokens, result.content is incomplete

// GOOD: Set appropriate max_tokens and handle truncation
const agent = new Agent({
  name: "writer",
  model: "claude-sonnet-4-6-20250514",
  maxTokens: 8192, // Generous limit for the task
  instructions: "...",
  tools: [...],
});
```

## Max Iteration Guards

Agentic loops can run indefinitely if the model keeps calling tools without converging. Always set a max iteration limit.

```typescript
// BAD: No iteration limit — infinite loop if model never stops
const agent = new Agent({
  name: "agent",
  instructions: "...",
  tools: [searchTool],
});

// GOOD: Explicit iteration limit
const agent = new Agent({
  name: "agent",
  instructions: "...",
  tools: [searchTool],
  maxIterations: 20, // Bail out after 20 tool calls
});
```

## Single vs. Multi-Agent Decision

Use a single agent when:
- The task has one clear domain (e.g., "answer questions about this codebase")
- All tools are relevant to the same workflow
- Context doesn't need to be isolated between subtasks

Use multi-agent when:
- Subtasks have different trust boundaries (e.g., one agent reads files, another writes them)
- You need to limit which tools are available for which subtasks
- The coordinator needs to synthesize results from independent workstreams

**Anti-pattern**: Reaching for multi-agent when a single agent with good tools would suffice. Multi-agent adds complexity, latency, and context-passing overhead.

## Streaming vs. Non-Streaming

```typescript
// Non-streaming: Wait for complete result
const result = await agent.query("Analyze this data");
console.log(result.content);

// Streaming: Process tokens as they arrive
const stream = agent.stream("Analyze this data");
for await (const event of stream) {
  if (event.type === "text") {
    process.stdout.write(event.text);
  }
}
```

Use streaming when:
- You need to show progress to users in real-time
- The response might be long and you want to display incrementally

Use non-streaming when:
- You're processing the result programmatically
- You're in a pipeline where partial results aren't useful

## Anti-Patterns to Detect

1. **Reimplementing the loop**: Writing your own while loop around raw API calls instead of using `Agent.query()`. The SDK handles tool execution, error recovery, and iteration correctly — don't reinvent it.

2. **No iteration guard**: Missing `maxIterations` means a confused model can loop forever, burning tokens and time.

3. **Ignoring stop_reason**: Not checking or handling `max_tokens` truncation leads to silently incomplete outputs.

4. **Premature multi-agent**: Splitting into coordinator + subagents when one agent with 3-4 tools would be simpler and faster.

5. **Blocking on streaming unnecessarily**: Using streaming when you just need the final result adds complexity for no benefit.
