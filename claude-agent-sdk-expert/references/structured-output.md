# Structured Output & Schema Design

## Use tool_use for Extraction

The most reliable way to get structured output from Claude is to define a tool whose schema matches your desired output format and use `tool_choice` to force the model to call it.

```typescript
// BAD: Asking for JSON in the prompt — fragile, model may wrap in markdown
const result = await agent.query(
  "Extract the customer info and return it as JSON: {name, email, phone}"
);
const data = JSON.parse(result.content); // May fail

// GOOD: Define an extraction tool with a strict schema
const extractCustomerTool = {
  name: "extract_customer",
  description: "Extract structured customer information from the provided text.",
  inputSchema: {
    type: "object",
    properties: {
      name: {
        type: "string",
        description: "Full name of the customer",
      },
      email: {
        type: "string",
        description: "Email address",
      },
      phone: {
        type: "string",
        description: "Phone number in E.164 format (e.g., +14155551234)",
      },
    },
    required: ["name", "email"],
    additionalProperties: false,
  },
};

// Force the model to use this specific tool
const result = await client.messages.create({
  model: "claude-sonnet-4-6-20250514",
  messages: [{ role: "user", content: documentText }],
  tools: [extractCustomerTool],
  tool_choice: { type: "tool", name: "extract_customer" },
});

const extracted = result.content.find(b => b.type === "tool_use")?.input;
```

## Required vs. Optional vs. Nullable

Be intentional about which fields are required:

```typescript
// BAD: Everything optional — model skips fields it's unsure about
const schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    email: { type: "string" },
    phone: { type: "string" },
    address: { type: "string" },
    notes: { type: "string" },
  },
  // No required array — everything is optional
};

// GOOD: Required fields are required, truly optional fields use nullable
const schema = {
  type: "object",
  properties: {
    name: {
      type: "string",
      description: "Customer full name. Always present in invoices.",
    },
    email: {
      type: "string",
      description: "Customer email. Always present in invoices.",
    },
    phone: {
      type: ["string", "null"],
      description: "Phone number if present, null if not found in document.",
    },
    shippingAddress: {
      type: ["string", "null"],
      description: "Shipping address if different from billing, null otherwise.",
    },
  },
  required: ["name", "email", "phone", "shippingAddress"],
  additionalProperties: false,
};
```

The pattern: make all fields `required`, but use `["type", "null"]` for fields that may legitimately be absent. This forces the model to explicitly return `null` rather than silently omitting fields.

## additionalProperties: false

Always set `additionalProperties: false`. Without it, the model may add extra fields you don't expect, and your downstream code won't be typed for them.

```typescript
// BAD: Model might add random extra fields
const schema = {
  type: "object",
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
  },
};

// GOOD: Strict — only these fields allowed
const schema = {
  type: "object",
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
  },
  required: ["title", "summary"],
  additionalProperties: false,
};
```

## Enum Usage

Use enums whenever a field has a known set of valid values:

```typescript
// BAD: Free-text category — model invents inconsistent values
category: {
  type: "string",
  description: "The category of the issue",
}

// GOOD: Constrained to valid values
category: {
  type: "string",
  description: "The category of the issue",
  enum: ["bug", "feature", "performance", "security", "documentation"],
}
```

## Anti-Patterns to Detect

1. **All-optional schemas**: Every field is optional, so the model returns sparse, unpredictable objects.

2. **Deep nesting**: Schemas more than 2-3 levels deep confuse the model and lead to structural errors.

```typescript
// BAD: 4 levels deep
const schema = {
  type: "object",
  properties: {
    customer: {
      type: "object",
      properties: {
        address: {
          type: "object",
          properties: {
            geo: {
              type: "object",
              properties: {
                lat: { type: "number" },
                lng: { type: "number" },
              },
            },
          },
        },
      },
    },
  },
};

// GOOD: Flattened where possible
const schema = {
  type: "object",
  properties: {
    customerName: { type: "string" },
    addressLine1: { type: "string" },
    city: { type: "string" },
    latitude: { type: ["number", "null"] },
    longitude: { type: ["number", "null"] },
  },
  required: ["customerName", "addressLine1", "city", "latitude", "longitude"],
  additionalProperties: false,
};
```

3. **Parsing raw JSON from text output**: Using `JSON.parse()` on the model's text response instead of using tool_use extraction. This breaks when the model wraps JSON in markdown code blocks or adds explanation text.

4. **Missing descriptions on schema fields**: The model uses field descriptions to understand what to put in each field. Without them, it guesses based on the field name alone.

5. **Inconsistent enum values**: Using different casing or naming conventions across enums in the same schema (e.g., mixing "Bug", "FEATURE", "perf-issue").
