# Top 10 Agent Gotchas

Quick-reference checklist of the most common Claude Agent SDK mistakes. Each one has caused production incidents. Check these **before** diving into a full review.

---

## 1. Missing `maxIterations`

**Symptom**: Agent runs forever, burns tokens, never returns.
**Why**: Without a cap, the agentic loop continues until the model emits `end_turn` — which may never happen if the task is ambiguous.
**Fix**: Always set `maxIterations` (TS) or `max_iterations` (Python). Start with 10-20 for most tasks.

## 2. Swallowing Tool Errors Into Empty Returns

**Symptom**: Agent proceeds as if the tool succeeded, produces hallucinated downstream results.
**Why**: A `catch` block returns `""`, `[]`, `null`, or `undefined` instead of surfacing the error. The model has no signal that something failed.
**Fix**: Return a descriptive error string from the tool: `return "Error: failed to fetch user — connection timeout"`. Let the agent decide how to recover.

## 3. Reimplementing the Agentic Loop

**Symptom**: Hand-rolled `while` loop calling `messages.create()` repeatedly, manually appending tool results.
**Why**: Duplicates logic the SDK already handles (tool dispatch, stop conditions, context assembly). Bugs hide in the seams.
**Fix**: Use `agent.query()` or `agent.stream()`. The SDK manages the loop, tool execution, and stop conditions.

## 4. `tool_choice: "any"` When You Meant a Specific Tool

**Symptom**: Agent calls random tools instead of the one you intended.
**Why**: `"any"` means "must call *some* tool" — not a specific one. The model picks whichever tool seems relevant.
**Fix**: Use `tool_choice: { type: "tool", name: "specific_tool_name" }` to force a specific tool call.

## 5. No `additionalProperties: false` on Schemas

**Symptom**: Model invents extra fields not in your schema. Validation passes but downstream code breaks on unexpected keys.
**Why**: Without `additionalProperties: false`, the JSON Schema allows any extra properties. Models will hallucinate plausible-sounding fields.
**Fix**: Add `additionalProperties: false` to every `object` type in your tool input schemas and structured output schemas.

## 6. Dumping Full Context to Subagents

**Symptom**: Subagent hits context window limit, runs slowly, or gets confused by irrelevant information.
**Why**: Passing the parent's entire conversation history to a subagent wastes tokens and dilutes the subagent's focus.
**Fix**: Pass only the specific task description and minimal required context. Subagents should receive a focused prompt, not a conversation dump.

## 7. StopHook That Can Never Be Satisfied

**Symptom**: Agent loops until `maxIterations`, then stops without completing the task.
**Why**: The `StopHook` condition requires something the agent can't achieve (e.g., "all tests pass" when tests have an unrelated failure).
**Fix**: StopHooks should check for *agent completion signals*, not external success criteria. Use them to validate the agent tried, not that the world changed.

## 8. Tool Descriptions Under 20 Characters

**Symptom**: Agent picks wrong tools or ignores useful tools.
**Why**: The model selects tools primarily by description. Short descriptions like `"Gets data"` provide no selection signal.
**Fix**: Write 1-3 sentence descriptions covering: what the tool does, when to use it, what it returns. Think of it as a docstring for the model.

## 9. No Timeout on External Calls in Tools

**Symptom**: Agent hangs indefinitely waiting for an API or database call inside a tool.
**Why**: Tools execute synchronously in the agentic loop. A hung tool blocks the entire agent.
**Fix**: Set explicit timeouts on all HTTP requests, database queries, and subprocess calls inside tools. Return a timeout error so the agent can retry or adapt.

## 10. Parsing JSON From Text Output Instead of `tool_use` Extraction

**Symptom**: Brittle regex/JSON.parse on model text that breaks when the model changes formatting.
**Why**: Model text output is free-form. Even with instructions to output JSON, the model may wrap it in markdown, add commentary, or change structure.
**Fix**: Use `tool_use` content blocks for structured data extraction. Define a tool whose input schema matches your desired output, and the model will return validated structured data.
