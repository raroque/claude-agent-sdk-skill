# Prompt Engineering for Agents

## Explicit Over Implicit

Agent prompts must be explicit. Unlike chat, agents take autonomous actions — ambiguity leads to wrong tool calls, not wrong words.

```typescript
// BAD: Implicit expectations
const agent = new Agent({
  name: "code-reviewer",
  instructions: "Review code and give feedback.",
  tools: [readFileTool, searchTool, commentTool],
});

// GOOD: Explicit instructions with boundaries
const agent = new Agent({
  name: "code-reviewer",
  instructions: `You are a code reviewer for a TypeScript monorepo.

Your job:
1. Read the files that were changed (use read_file tool)
2. Check for: type safety issues, missing error handling, performance problems
3. Post comments on specific lines (use post_comment tool)

Rules:
- Only review files in src/ — ignore test files, config files, and generated code
- Do NOT suggest style changes (formatting is handled by Prettier)
- If you find a critical issue (security vulnerability, data loss risk), prefix the comment with [CRITICAL]
- If all files look good, post a single approval comment instead of nitpicking`,
  tools: [readFileTool, searchTool, commentTool],
});
```

## System Prompt Structure

A well-structured agent system prompt has four sections:

```
1. IDENTITY: Who you are and your expertise
2. TASK: What you're doing right now (specific to this invocation)
3. TOOLS: When and how to use each tool (supplement tool descriptions)
4. RULES: Boundaries, constraints, and edge case handling
```

```typescript
const instructions = `
# Identity
You are a database migration assistant for a PostgreSQL database.

# Task
Analyze the requested schema change and generate a safe migration.

# Tools
- read_schema: Use this FIRST to understand the current table structure
- generate_migration: Use this to create the migration SQL. Always include a rollback.
- validate_migration: Use this AFTER generating to check for destructive operations

# Rules
- NEVER generate DROP TABLE or DROP COLUMN without explicit user confirmation
- Always check for foreign key dependencies before modifying a column
- If a migration would lock a table with >1M rows, flag it as HIGH RISK
- Include estimated execution time in your response
`;
```

## Few-Shot Examples

For complex tool usage patterns, include examples directly in the instructions:

```typescript
const instructions = `
You extract structured data from documents.

Example interaction:
User: "Extract the invoice details from this PDF"
You: First, read the document:
[calls read_document tool with the file path]
Then, extract structured data:
[calls extract_data tool with the schema]
Finally, validate the extraction:
[calls validate tool to check required fields]

If extraction confidence is below 80%, flag uncertain fields rather than guessing.
`;
```

## Anti-Patterns to Detect

1. **Over-prompting**: Instructions so long and detailed that the model loses track of what matters. Prompts over ~500 words start to see diminishing returns.

```typescript
// BAD: 2000 words of instructions covering every edge case
const instructions = `
You are an AI assistant. You should be helpful. When the user asks...
[200 lines of instructions]
Also remember to be concise. And thorough. And careful. And creative.
`;

// GOOD: Focused, prioritized instructions
const instructions = `
You analyze error logs and identify root causes.

Process:
1. Read the error log (read_log tool)
2. Search for related errors in the past 24h (search_logs tool)
3. Identify the root cause and suggest a fix

Priority: accuracy over speed. If unsure, say so.
`;
```

2. **Instruction hierarchy violations**: Putting critical rules at the end where they get less attention. The model attends most strongly to the beginning and end of the context window, with a dip in the middle.

```typescript
// BAD: Critical safety rule buried in the middle
const instructions = `
You are a helpful assistant.
[50 lines of general instructions]
NEVER execute DELETE queries without confirmation.
[50 more lines of instructions]
`;

// GOOD: Critical rules up front
const instructions = `
CRITICAL RULES:
- NEVER execute DELETE queries without user confirmation
- NEVER modify production data directly

You are a database assistant. [rest of instructions]
`;
```

3. **Conflicting instructions**: Telling the agent to be both "thorough" and "concise" without clarifying when each applies.

4. **Missing tool guidance**: Defining tools but not explaining when to use each one in the instructions. Tool descriptions help, but in-prompt guidance catches edge cases.

5. **Generic identity**: "You are a helpful AI assistant" tells the model nothing useful. Specific identities lead to better tool selection and output quality.

```typescript
// BAD
instructions: "You are a helpful AI assistant that can use tools."

// GOOD
instructions: "You are a senior security engineer reviewing infrastructure-as-code for misconfigurations. You specialize in AWS IAM policies and S3 bucket permissions."
```

6. **No stopping criteria**: Not telling the agent when it's done. Without clear completion conditions, agents tend to over-iterate.

```typescript
// BAD: When does this agent stop?
instructions: "Research the topic and provide information."

// GOOD: Clear completion criteria
instructions: `Research the topic. You are done when:
- You have found at least 3 authoritative sources
- You can answer the original question with specific facts
- OR you have exhausted available search results (stop after 5 searches with no new relevant results)`
```
