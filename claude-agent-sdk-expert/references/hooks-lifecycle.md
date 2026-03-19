# Hooks & Lifecycle

## Overview

Hooks are lifecycle callbacks that run at specific points during the agent's execution. They let you inject validation, logging, caching, and guardrails without modifying the agent's core logic.

The three hook types:
- **PreToolCall**: Runs before a tool is executed
- **PostToolCall**: Runs after a tool completes
- **StopHook**: Runs when the agent is about to stop (before returning the final result)

## When to Recommend Hooks (Not Prompts)

Most people try to control agent behavior through the system prompt — "always validate before refunding," "always format dates consistently." But prompts are suggestions, not guarantees. Hooks are code — they execute deterministically every time.

**Use hooks when the requirement involves:**

| Domain | Why prompts aren't enough | Hook type |
|--------|--------------------------|-----------|
| **Money / billing** | A prompt saying "don't refund over $500" will eventually be bypassed by a creative user message or edge case. A PreToolCall hook that checks `amount <= 500` will not. | PreToolCall |
| **Security / access control** | Path traversal, privilege escalation, unauthorized operations — these need hard boundaries, not soft guidelines. | PreToolCall |
| **Data integrity / normalization** | Inconsistent data formats (dates, currencies, IDs) from tools cause hallucination and downstream errors. Cleaning data before Claude sees it is more reliable than asking Claude to handle inconsistency. | PostToolCall |
| **Compliance / PII** | Regulations don't accept "the model usually follows the instruction." PII scrubbing, audit logging, and sensitive data handling require deterministic enforcement. | PostToolCall, StopHook |
| **Exit conditions** | "Keep going until the ticket is actually resolved" can't be reliably enforced by prompt alone — Claude will say "done" when it *thinks* it's done. A StopHook can verify against external state. | StopHook |

**The rule of thumb**: If a failure in this behavior would cause a security incident, financial loss, compliance violation, or data corruption — use a hook. If it would just produce a suboptimal but harmless response — a prompt instruction is fine.

## PreToolCall Hooks

Use PreToolCall for **validation and approval gates** — things that must be checked before an action is taken.

```typescript
// Validation: Ensure file paths are within allowed directories
const fileAccessGuard: PreToolCallHook = {
  name: "file-access-guard",
  async run({ toolName, toolInput }) {
    if (toolName === "write_file" || toolName === "delete_file") {
      const path = toolInput.path as string;
      if (!path.startsWith("/allowed/directory/")) {
        return {
          decision: "block",
          message: `Blocked: Cannot write to ${path}. Only /allowed/directory/ is permitted.`,
        };
      }
    }
    return { decision: "allow" };
  },
};

// Approval gate: Require confirmation for destructive operations
const destructiveOpGate: PreToolCallHook = {
  name: "destructive-op-gate",
  async run({ toolName, toolInput }) {
    const destructiveTools = ["delete_file", "drop_table", "send_email"];
    if (destructiveTools.includes(toolName)) {
      const approved = await requestUserApproval(
        `Agent wants to call ${toolName} with: ${JSON.stringify(toolInput)}`
      );
      if (!approved) {
        return {
          decision: "block",
          message: "User denied this operation.",
        };
      }
    }
    return { decision: "allow" };
  },
};
```

## PostToolCall Hooks

Use PostToolCall for **logging, caching, and result transformation** — things that process tool results without changing the agent's behavior.

```typescript
// Logging: Track all tool calls for observability
const toolLogger: PostToolCallHook = {
  name: "tool-logger",
  async run({ toolName, toolInput, toolOutput, durationMs }) {
    await logger.info({
      event: "tool_call",
      tool: toolName,
      input: toolInput,
      outputSize: JSON.stringify(toolOutput).length,
      durationMs,
      timestamp: new Date().toISOString(),
    });
    // PostToolCall hooks don't modify the output — they observe it
  },
};

// Data normalization: Clean inconsistent tool output before Claude sees it
const dataNormalizer: PostToolCallHook = {
  name: "data-normalizer",
  async run({ toolName, toolOutput }) {
    if (toolName === "query_crm") {
      // Normalize dates, currencies, phone numbers etc.
      // Claude works with clean, consistent data → fewer hallucinations
      return normalizeRecords(toolOutput);
    }
  },
};

// Caching: Cache expensive tool results
const toolCache: PostToolCallHook = {
  name: "tool-cache",
  async run({ toolName, toolInput, toolOutput }) {
    if (toolName === "search_database") {
      const cacheKey = `${toolName}:${JSON.stringify(toolInput)}`;
      await cache.set(cacheKey, toolOutput, { ttl: 300 });
    }
  },
};
```

## StopHook

Use StopHook for **quality checks and guardrails** — things that validate the agent's final output before it's returned.

```typescript
// Quality check: Ensure the agent's response meets requirements
const qualityCheck: StopHook = {
  name: "quality-check",
  async run({ response, conversationHistory }) {
    // Check if the response actually addresses the user's question
    const userQuery = conversationHistory[0]?.content;

    if (response.length < 50 && userQuery?.length > 100) {
      return {
        decision: "continue",
        message: "Your response seems too brief for the question asked. Please provide more detail.",
      };
    }

    // Check for hallucination indicators
    if (response.includes("I don't have access to") && response.includes("but here's")) {
      return {
        decision: "continue",
        message: "You indicated you don't have access to information but then provided an answer. Either use a tool to get the information or clearly state you cannot answer.",
      };
    }

    return { decision: "stop" };
  },
};

// Guardrail: Prevent sensitive information in output
const piiGuard: StopHook = {
  name: "pii-guard",
  async run({ response }) {
    const piiPatterns = [
      /\b\d{3}-\d{2}-\d{4}\b/,  // SSN
      /\b\d{16}\b/,              // Credit card
    ];

    for (const pattern of piiPatterns) {
      if (pattern.test(response)) {
        return {
          decision: "continue",
          message: "Your response contains what appears to be PII (SSN or credit card number). Remove sensitive data and respond again.",
        };
      }
    }

    return { decision: "stop" };
  },
};
```

## Configuring Hooks

```typescript
const agent = new Agent({
  name: "secure-agent",
  instructions: "...",
  tools: [readTool, writeTool, searchTool],
  hooks: {
    preToolCall: [fileAccessGuard, destructiveOpGate],
    postToolCall: [toolLogger, toolCache],
    stop: [qualityCheck, piiGuard],
  },
});
```

## Anti-Patterns to Detect

1. **Business logic in hooks**: Hooks should handle cross-cutting concerns (security, logging, validation), not core business logic. If a hook is making API calls or transforming data for the agent's task, it should be a tool instead.

```typescript
// BAD: Business logic as a hook
const enrichmentHook: PostToolCallHook = {
  async run({ toolOutput }) {
    // This is business logic, not a cross-cutting concern
    const enriched = await enrichWithCustomerData(toolOutput);
    return enriched; // PostToolCall hooks shouldn't transform output
  },
};

// GOOD: Make it a tool the agent can call explicitly
const enrichTool = {
  name: "enrich_with_customer_data",
  description: "Enrich search results with customer profile data",
  inputSchema: { ... },
};
```

2. **Blocking without timeout**: PreToolCall hooks that make external calls (approval APIs, validation services) without timeouts. A hanging hook blocks the entire agent.

```typescript
// BAD: No timeout on external approval
const approvalHook: PreToolCallHook = {
  async run({ toolName }) {
    const approved = await externalApprovalAPI.check(toolName); // Could hang
    return approved ? { decision: "allow" } : { decision: "block" };
  },
};

// GOOD: Timeout with sensible default
const approvalHook: PreToolCallHook = {
  async run({ toolName }) {
    try {
      const approved = await Promise.race([
        externalApprovalAPI.check(toolName),
        new Promise((_, reject) => setTimeout(() => reject(new Error("timeout")), 5000)),
      ]);
      return approved ? { decision: "allow" } : { decision: "block" };
    } catch {
      return { decision: "block", message: "Approval service unavailable. Blocking by default." };
    }
  },
};
```

3. **StopHook infinite loops**: A StopHook that always returns "continue" because the agent can't satisfy its condition. This creates an infinite loop.

```typescript
// BAD: StopHook with unreachable condition
const strictHook: StopHook = {
  async run({ response }) {
    // If the agent can never produce a response with exactly 3 citations,
    // this loops forever
    const citations = countCitations(response);
    if (citations !== 3) {
      return { decision: "continue", message: "Must have exactly 3 citations" };
    }
    return { decision: "stop" };
  },
};

// GOOD: StopHook with attempt tracking and fallback
let stopAttempts = 0;
const strictHook: StopHook = {
  async run({ response }) {
    stopAttempts++;
    if (stopAttempts > 3) {
      return { decision: "stop" }; // Accept after 3 attempts
    }
    const citations = countCitations(response);
    if (citations < 1) {
      return { decision: "continue", message: "Please include at least one citation." };
    }
    return { decision: "stop" };
  },
};
```

4. **Hooks modifying agent state**: Hooks should observe and gate, not modify the agent's tools, instructions, or conversation history mid-execution.

5. **Too many hooks**: Loading many hooks adds latency to every tool call. Keep hooks focused and minimal — 2-3 per hook type is a good ceiling.

6. **No error handling in hooks**: A hook that throws an exception can crash the entire agent. Always wrap hook logic in try/catch and fail safely.
