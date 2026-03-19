#!/usr/bin/env bash
# scan-agent-patterns.sh — Static analysis for common Claude Agent SDK anti-patterns
# Usage: bash scan-agent-patterns.sh <directory>
# Outputs: [PATTERN_NAME] file:line — description
# Always exits 0 (informational, not a gate)

set -euo pipefail

TARGET="${1:-.}"
FOUND=0

if [ ! -d "$TARGET" ]; then
  echo "Error: '$TARGET' is not a directory"
  exit 0
fi

# Portable grep — prefer rg if available, fall back to grep -rn
if command -v rg &>/dev/null; then
  RG="rg --no-heading --line-number"
else
  RG="grep -rn"
fi

echo "=== Claude Agent SDK Pattern Scan ==="
echo "Target: $TARGET"
echo ""

# 1. new Agent( without maxIterations nearby
# Look for Agent instantiation, then check if maxIterations appears within 10 lines
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  end=$((line + 10))
  if ! sed -n "${line},${end}p" "$file" 2>/dev/null | grep -q "maxIterations\|max_iterations"; then
    echo "[MISSING_MAX_ITERATIONS] ${file}:${line} — new Agent() without maxIterations within 10 lines"
    FOUND=$((FOUND + 1))
  fi
done < <($RG "new Agent\(" "$TARGET" --include='*.ts' --include='*.js' --include='*.py' --include='*.tsx' --include='*.jsx' 2>/dev/null || true)

# 2. tool_choice: "any" usage
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  echo "[TOOL_CHOICE_ANY] ${file}:${line} — tool_choice set to \"any\" — did you mean a specific tool?"
  FOUND=$((FOUND + 1))
done < <($RG 'tool_choice.*["\x27]any["\x27]' "$TARGET" --include='*.ts' --include='*.js' --include='*.py' --include='*.tsx' --include='*.jsx' 2>/dev/null || true)

# 3. JSON.parse on result.content or response.content
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  echo "[JSON_PARSE_TEXT] ${file}:${line} — JSON.parse on content — use tool_use blocks for structured extraction"
  FOUND=$((FOUND + 1))
done < <($RG 'JSON\.parse\(.*\.(content|text)' "$TARGET" --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' 2>/dev/null || true)

# 4. Catch blocks returning empty/null (silent failure)
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  echo "[SILENT_CATCH] ${file}:${line} — catch block returns empty value — surface the error to the agent"
  FOUND=$((FOUND + 1))
done < <($RG 'catch.*\{' "$TARGET" --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' -A 3 2>/dev/null | grep -E 'return\s*(""|\x27\x27|`{2}|\[\]|null|undefined)\s*;?' | sed 's/-[0-9]*-/:/;s/-[0-9]*:/:/;' || true)

# 5. Object with properties but missing additionalProperties
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  end=$((line + 15))
  if ! sed -n "${line},${end}p" "$file" 2>/dev/null | grep -q "additionalProperties"; then
    echo "[MISSING_ADDITIONAL_PROPS] ${file}:${line} — schema object with properties but no additionalProperties: false"
    FOUND=$((FOUND + 1))
  fi
done < <($RG 'type.*["\x27]object["\x27]' "$TARGET" --include='*.ts' --include='*.js' --include='*.py' --include='*.tsx' --include='*.jsx' --include='*.json' 2>/dev/null | grep -v node_modules | grep -v "\.d\.ts" || true)

# 6. Short tool descriptions (under 20 chars)
while IFS=: read -r file line rest; do
  [ -z "$file" ] && continue
  # Extract the description string value
  desc=$(echo "$rest" | sed -n 's/.*description.*["'\'']\([^"'\'']*\)["'\''].*/\1/p')
  if [ -n "$desc" ] && [ ${#desc} -lt 20 ]; then
    echo "[SHORT_DESCRIPTION] ${file}:${line} — tool description under 20 chars: \"${desc}\""
    FOUND=$((FOUND + 1))
  fi
done < <($RG 'description\s*[:=]' "$TARGET" --include='*.ts' --include='*.js' --include='*.py' --include='*.tsx' --include='*.jsx' 2>/dev/null | grep -v node_modules | grep -v "\.d\.ts" | grep -v "package.json" || true)

# 7. while(true) or for(;;) near API calls
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  end=$((line + 10))
  if sed -n "${line},${end}p" "$file" 2>/dev/null | grep -qE '(messages\.create|\.query\(|\.stream\(|fetch\(|axios)'; then
    echo "[MANUAL_LOOP] ${file}:${line} — infinite loop near API call — use SDK agentic loop instead"
    FOUND=$((FOUND + 1))
  fi
done < <($RG '(while\s*\(\s*true\s*\)|for\s*\(\s*;\s*;\s*\))' "$TARGET" --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' 2>/dev/null || true)

# 8. Full conversation concatenation into query/stream
while IFS=: read -r file line _rest; do
  [ -z "$file" ] && continue
  echo "[CONTEXT_DUMP] ${file}:${line} — possible full conversation dump to query/stream — pass focused context instead"
  FOUND=$((FOUND + 1))
done < <($RG '(messages|conversation|history)\s*\.\s*(join|map|reduce).*\.(query|stream)\(' "$TARGET" --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' 2>/dev/null || true)

echo ""
echo "=== Scan Complete ==="
echo "Patterns found: $FOUND"
if [ "$FOUND" -eq 0 ]; then
  echo "No common anti-patterns detected. (This doesn't mean the code is perfect — run a full review for deeper analysis.)"
fi
exit 0
