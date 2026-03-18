# Contributing to Claude Agent SDK Expert

Thanks for your interest in improving this skill! Here's how to contribute.

## How to Contribute

1. **Fork** the repository
2. **Create a branch** for your change: `git checkout -b my-improvement`
3. **Make your changes** following the guidelines below
4. **Submit a pull request** with a clear description of what you changed and why

## What to Contribute

- **New anti-patterns**: Real failure modes you've seen in agent code
- **Better code examples**: More realistic BAD/GOOD pairs
- **Corrections**: Fixes for inaccurate SDK information or outdated patterns
- **Real-world failure cases**: "We shipped this and it broke because..."
- **New reference topics**: If an important agent pattern isn't covered

## Guidelines

- **Be concise.** Developers skim reference docs — every sentence should earn its place.
- **Explain the "why."** Don't just say "don't do X" — explain what breaks and how.
- **Focus on AI-introduced patterns.** Traditional code review catches traditional bugs. This skill targets failure modes specific to agent development: hallucinated tool calls, context loss, infinite loops, silent failures, etc.
- **Include code examples.** Every anti-pattern needs a BAD/GOOD code pair. Abstract advice without examples doesn't help.
- **Test your changes.** Install the skill locally and verify that the reference files load correctly and the examples make sense.

## Local Testing

```bash
# Copy to your Claude skills directory
cp -r claude-agent-sdk-expert/ ~/.claude/skills/claude-agent-sdk-expert/

# Open Claude Code and test
# /claude-agent-sdk-expert should trigger the skill
```

## Code of Conduct

Be respectful, constructive, and focused on making the skill better for everyone.
