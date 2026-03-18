# Error Handling & Reliability

## Structured Error Propagation

Errors in agent systems must flow back to the model in a structured, actionable format. The model needs to understand what went wrong and what it can do about it.

```typescript
// BAD: Opaque error — model has no idea what to do next
async function apiTool(input: { endpoint: string }) {
  const res = await fetch(input.endpoint);
  if (!res.ok) throw new Error("Request failed");
  return res.json();
}

// GOOD: Structured error with recovery guidance
async function apiTool(input: { endpoint: string }) {
  try {
    const res = await fetch(input.endpoint);
    if (!res.ok) {
      return {
        success: false,
        error: {
          type: "http_error",
          status: res.status,
          statusText: res.statusText,
          retryable: res.status >= 500,
          suggestion: res.status === 404
            ? "Check the endpoint path. It may have changed."
            : res.status === 401
            ? "Authentication failed. Check credentials."
            : res.status >= 500
            ? "Server error. Try again in a moment."
            : "Check the request parameters.",
        },
      };
    }
    return { success: true, data: await res.json() };
  } catch (err) {
    return {
      success: false,
      error: {
        type: "network_error",
        message: err.message,
        retryable: true,
        suggestion: "Network request failed. Check connectivity and try again.",
      },
    };
  }
}
```

## Validation Loops

When the model produces output that doesn't pass validation, feed the error back so it can self-correct:

```typescript
// GOOD: Validation loop with structured feedback
const extractionTool = {
  name: "extract_invoice",
  description: "Extract invoice fields from text",
  inputSchema: invoiceSchema,
};

// In your tool handler:
async function handleExtraction(input: any) {
  const validation = validateInvoice(input);
  if (!validation.valid) {
    return {
      success: false,
      error: "validation_failed",
      issues: validation.errors.map(e => ({
        field: e.path,
        message: e.message,
        expected: e.expected,
        received: e.received,
      })),
      instruction: "Fix the listed issues and call this tool again with corrected data.",
    };
  }
  return { success: true, invoice: input };
}
```

## Escalation Triggers

Not all errors should be retried. Define clear escalation paths:

```typescript
const instructions = `
Error handling rules:
- Retryable errors (network timeout, 5xx, rate limit): Retry up to 2 times with backoff
- Validation errors: Fix the input and try again (max 3 attempts)
- Auth errors (401, 403): STOP and report to the user — do not retry
- Not found (404): Try alternative approaches (different search query, different path)
- Unknown errors: STOP and report the full error to the user

If you hit 3 consecutive errors on the same operation, STOP and report the issue instead of continuing to retry.
`;
```

## Retry Strategies

```typescript
// BAD: Immediate retry with no limit — can loop forever
async function retryTool(fn: Function) {
  while (true) {
    try {
      return await fn();
    } catch (e) {
      // Just keep trying forever
    }
  }
}

// GOOD: Bounded retry with exponential backoff
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelayMs: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxRetries) throw err;
      if (!isRetryable(err)) throw err;
      const delay = baseDelayMs * Math.pow(2, attempt);
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw new Error("Unreachable");
}

function isRetryable(err: any): boolean {
  if (err.status >= 500) return true;
  if (err.status === 429) return true;
  if (err.code === "ECONNRESET" || err.code === "ETIMEDOUT") return true;
  return false;
}
```

## Anti-Patterns to Detect

1. **Opaque errors**: Returning "Error occurred" or throwing generic exceptions. The model needs specific error types, messages, and recovery suggestions.

2. **Silent failures**: Catching errors and returning empty/default results instead of signaling failure. The model proceeds as if the operation succeeded.

```typescript
// BAD: Silent failure — model thinks it read a file successfully
async function readFile(path: string) {
  try {
    return fs.readFileSync(path, "utf-8");
  } catch {
    return ""; // Model thinks the file is empty
  }
}

// GOOD: Explicit failure
async function readFile(path: string) {
  try {
    return { success: true, content: fs.readFileSync(path, "utf-8") };
  } catch (err) {
    return {
      success: false,
      error: `File not found: ${path}. Check the path and try again.`,
    };
  }
}
```

3. **Crashing loops**: An error causes the model to retry the exact same action, hitting the same error, burning through iterations.

```
// What happens:
// 1. Model calls tool with bad input
// 2. Tool returns error
// 3. Model retries with the SAME bad input
// 4. Tool returns same error
// 5. Repeat until maxIterations

// Fix: Return actionable error messages that tell the model
// what specifically was wrong and how to fix it
```

4. **No timeout on external calls**: Tool functions that call external APIs without timeouts. A hanging API call blocks the entire agent.

```typescript
// BAD: No timeout
const result = await fetch(url);

// GOOD: Timeout
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 10000);
try {
  const result = await fetch(url, { signal: controller.signal });
} finally {
  clearTimeout(timeout);
}
```

5. **Swallowing stack traces**: Catching errors and only forwarding the message, losing the stack trace that would help debug the issue.

6. **Retry without backoff**: Retrying immediately after failure, especially for rate-limited APIs. This makes the situation worse.
