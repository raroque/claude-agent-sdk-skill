# Tool Design & Scoping

## The Cardinal Rule

**Tool descriptions are the primary selection mechanism.** The model reads descriptions to decide which tool to call. A vague or misleading description means wrong tool selection — no amount of clever schema design can fix that.

```typescript
// BAD: Vague description — model can't distinguish from other search tools
const searchTool = {
  name: "search",
  description: "Search for things",
  inputSchema: { ... }
};

// GOOD: Specific, actionable description with clear scope
const searchTool = {
  name: "search_codebase",
  description: "Search the current repository for code matching a regex pattern. Returns file paths and matching lines. Use this when you need to find where a function, class, or pattern is defined or used. Do NOT use this for searching external documentation — use search_docs instead.",
  inputSchema: { ... }
};
```

## The 4-5 Tool Rule

Agents work best with 4-5 focused tools. More than that and the model struggles to select correctly. If you need more capabilities, consider:
- Combining related operations into one tool with a mode parameter
- Splitting into subagents, each with their own focused tool set
- Removing tools that are rarely used

```typescript
// BAD: Too many fine-grained tools
const tools = [
  readFileTool,
  writeFileTool,
  appendFileTool,
  deleteFileTool,
  renameFileTool,
  copyFileTool,
  moveFileTool,
  listDirectoryTool,
  createDirectoryTool,
  // Model wastes tokens deliberating between these
];

// GOOD: Consolidated file operations
const tools = [
  fileOperationTool,   // mode: read | write | delete | list
  searchTool,          // Find files and content
  executeTool,         // Run shell commands
  summarizeTool,       // Compress content for context management
];
```

## tool_choice Options

Control how the model selects tools:

```typescript
// Let the model decide (default)
tool_choice: "auto"

// Force a specific tool call (useful for structured extraction)
tool_choice: { type: "tool", name: "extract_data" }

// Force the model to use SOME tool (any tool)
tool_choice: "any"

// Prevent tool use entirely
tool_choice: "none"
```

**Anti-pattern**: Using `tool_choice: "any"` when you meant to use a specific tool. This forces tool use but doesn't guarantee the *right* tool.

## Input Schema Best Practices

```typescript
// BAD: No descriptions, loose types, optional everything
const schema = {
  type: "object",
  properties: {
    q: { type: "string" },
    n: { type: "number" },
    opts: { type: "object" },
  },
};

// GOOD: Descriptive names, constrained types, required fields, closed schema
const schema = {
  type: "object",
  properties: {
    query: {
      type: "string",
      description: "The search query. Supports regex patterns.",
    },
    maxResults: {
      type: "integer",
      description: "Maximum number of results to return. Range: 1-100.",
      minimum: 1,
      maximum: 100,
    },
    fileType: {
      type: "string",
      description: "Filter results to this file extension.",
      enum: ["ts", "js", "py", "go", "rs"],
    },
  },
  required: ["query"],
  additionalProperties: false,
};
```

## Structured Error Responses

Tools should return structured errors, not throw exceptions or return raw strings.

```typescript
// BAD: Throwing or returning unstructured errors
async function searchTool(input: { query: string }) {
  const results = await db.search(input.query);
  if (!results.length) {
    throw new Error("No results found"); // Model sees unhelpful error
  }
  return results;
}

// GOOD: Structured error response the model can reason about
async function searchTool(input: { query: string }) {
  try {
    const results = await db.search(input.query);
    if (!results.length) {
      return {
        success: false,
        error: "no_results",
        message: `No results found for "${input.query}". Try broadening the search terms or checking for typos.`,
        suggestions: ["Remove filters", "Use fewer keywords", "Check spelling"],
      };
    }
    return { success: true, results };
  } catch (err) {
    return {
      success: false,
      error: "search_failed",
      message: `Search failed: ${err.message}`,
    };
  }
}
```

## Anti-Patterns to Detect

1. **Side-effect-only tools**: Tools that perform an action but return nothing (or just "OK"). The model needs feedback to know what happened and decide next steps.

```typescript
// BAD: No feedback
async function deployTool() {
  await deploy();
  return "OK";
}

// GOOD: Actionable feedback
async function deployTool() {
  const result = await deploy();
  return {
    success: true,
    url: result.url,
    version: result.version,
    duration: result.durationMs,
  };
}
```

2. **Tools returning too much data**: Dumping entire database tables or full file contents into the context window. Summarize or paginate.

```typescript
// BAD: Returns entire table
async function listUsersTool() {
  return await db.query("SELECT * FROM users"); // Could be 100k rows
}

// GOOD: Paginated with summary
async function listUsersTool(input: { page?: number; pageSize?: number }) {
  const page = input.page ?? 1;
  const pageSize = Math.min(input.pageSize ?? 20, 100);
  const offset = (page - 1) * pageSize;
  const [rows, total] = await Promise.all([
    db.query(`SELECT id, name, email FROM users LIMIT $1 OFFSET $2`, [pageSize, offset]),
    db.query(`SELECT COUNT(*) FROM users`),
  ]);
  return { users: rows, page, pageSize, totalUsers: total, totalPages: Math.ceil(total / pageSize) };
}
```

3. **Ambiguous tool boundaries**: Two tools that overlap in capability, so the model frequently picks the wrong one. Consolidate or sharpen descriptions.

4. **Missing required fields**: Making everything optional when the tool can't function without certain inputs. This leads to the model omitting critical parameters.

5. **No enum constraints**: Using raw strings where a fixed set of values is expected. The model may hallucinate invalid values.
