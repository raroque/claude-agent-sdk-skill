# MCP Integration

## What Is MCP

The Model Context Protocol (MCP) is an open standard for connecting AI models to external tools and data sources. Instead of building custom tool integrations, you configure MCP servers that expose tools, resources, and prompts through a standardized protocol.

In the Claude Agent SDK, MCP servers are configured at the agent level and their tools become available alongside your custom tools.

## Server Configuration

### Project-Level Configuration (`.mcp.json`)

Project-level MCP config lives in `.mcp.json` at the project root and is shared across the team:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dir"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### User-Level Configuration

User-level MCP config goes in `~/.claude/settings.json` and applies to all projects:

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-slack"],
      "env": {
        "SLACK_TOKEN": "${SLACK_TOKEN}"
      }
    }
  }
}
```

### SDK-Level Configuration

In the Agent SDK, MCP servers are configured programmatically:

```typescript
import { Agent, McpServer } from "claude-agent-sdk";

const agent = new Agent({
  name: "dev-assistant",
  instructions: "...",
  tools: [customTool],
  mcpServers: [
    new McpServer({
      name: "github",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-github"],
      env: { GITHUB_TOKEN: process.env.GITHUB_TOKEN },
    }),
  ],
});
```

## Custom vs. Community Servers

**Community servers** (from the MCP ecosystem): Pre-built integrations for GitHub, Slack, filesystem, databases, etc. Use these when available — they handle auth, pagination, and error cases.

**Custom servers**: Build your own when you need domain-specific tools that don't exist in the ecosystem. Follow the MCP specification for tool definitions.

```typescript
// When to build custom vs. use community
// Community: GitHub, Slack, PostgreSQL, filesystem, Notion, Linear
// Custom: Your internal API, proprietary data format, company-specific workflow
```

## Anti-Patterns to Detect

1. **Too many MCP servers**: Loading 10+ MCP servers floods the model with tool definitions. Each server may expose multiple tools, and the model sees ALL of them. This degrades tool selection accuracy.

```json
// BAD: Kitchen sink approach
{
  "mcpServers": {
    "github": { ... },
    "slack": { ... },
    "linear": { ... },
    "notion": { ... },
    "postgres": { ... },
    "redis": { ... },
    "s3": { ... },
    "elasticsearch": { ... },
    "datadog": { ... },
    "pagerduty": { ... }
  }
}

// GOOD: Only servers needed for this project's workflow
{
  "mcpServers": {
    "github": { ... },
    "postgres": { ... }
  }
}
```

2. **Tool name conflicts**: Two MCP servers exposing tools with the same name. The model can't distinguish them and may call the wrong one.

```
// BAD: Both servers have a "search" tool
Server A: search (searches codebase)
Server B: search (searches documentation)

// GOOD: Namespaced or distinct names
Server A: search_code
Server B: search_docs
```

3. **Missing environment variables**: Configuring MCP servers with env vars that aren't set. The server starts but fails on first use.

```json
// BAD: No fallback or validation
{
  "env": {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}"
  }
}
// If GITHUB_TOKEN isn't set, every GitHub tool call fails at runtime

// GOOD: Validate at startup
```

```typescript
// Validate MCP server requirements before starting the agent
if (!process.env.GITHUB_TOKEN) {
  throw new Error("GITHUB_TOKEN is required for the GitHub MCP server");
}
```

4. **Secrets in project config**: Hardcoding tokens or secrets in `.mcp.json` which gets committed to version control.

```json
// BAD: Secret in project config
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_TOKEN": "ghp_xxxxxxxxxxxx"
      }
    }
  }
}

// GOOD: Reference environment variables
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

5. **No server health checks**: Not handling the case where an MCP server fails to start or crashes mid-session. The agent should degrade gracefully, not hang or crash.

6. **Treating MCP tools as trusted**: MCP server tools execute external code. Treat their outputs as untrusted input — validate and sanitize before using in sensitive operations.
