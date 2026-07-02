#!/bin/bash
# Model evaluation for Swift/iOS code generation
# Usage: ./run-eval.sh [prompt-number]
# Example: ./run-eval.sh 01   (run just test 01)
# Example: ./run-eval.sh       (run all tests)
# Example: ./run-eval.sh --model sonnet 03  (run test 03 with sonnet only)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"
RESULTS_DIR="$SCRIPT_DIR/results"

MODELS=("claude-haiku-4-5-20251001" "claude-sonnet-4-6" "claude-opus-4-6")
MODEL_NAMES=("haiku" "sonnet" "opus")

# Parse --model flag
FILTER_MODEL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      FILTER_MODEL="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

mkdir -p "$RESULTS_DIR"

run_test() {
  local prompt_file="$1"
  local test_name=$(basename "$prompt_file" .md)

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  TEST: $test_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Prompt: $(head -1 "$prompt_file")"
  echo ""

  for i in "${!MODELS[@]}"; do
    local model="${MODELS[$i]}"
    local name="${MODEL_NAMES[$i]}"

    # Skip if --model filter is set and doesn't match
    if [[ -n "$FILTER_MODEL" && "$name" != "$FILTER_MODEL" ]]; then
      continue
    fi

    local output_file="$RESULTS_DIR/${name}-${test_name}.md"

    if [[ -f "$output_file" ]]; then
      local size=$(wc -c < "$output_file" | tr -d ' ')
      if [[ "$size" -gt 100 ]]; then
        echo "  ⏭  $name — already exists (${size} bytes), skipping"
        echo "     Delete $output_file to re-run"
        continue
      else
        rm -f "$output_file" "$RESULTS_DIR/${name}-${test_name}.log"
      fi
    fi

    echo "  🔄 Running $name..."
    local start_time=$(date +%s)

    # Run claude with the prompt, capture output
    # --dangerously-skip-permissions lets it write code without prompting
    claude --model "$model" \
      -p "$(cat "$prompt_file") Output all code directly in your response. Do not write any files." \
      --print \
      > "$output_file" 2>"$RESULTS_DIR/${name}-${test_name}.log"

    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local output_size=$(wc -c < "$output_file" | tr -d ' ')
    local output_lines=$(wc -l < "$output_file" | tr -d ' ')

    if [[ $exit_code -eq 0 ]]; then
      echo "  ✅ $name — ${duration}s, ${output_lines} lines, ${output_size} bytes"
    else
      echo "  ❌ $name — failed (exit $exit_code) after ${duration}s"
      echo "     Check: $RESULTS_DIR/${name}-${test_name}.log"
    fi
    echo ""
  done
}

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  Swift/iOS Model Evaluation                   ║"
echo "║  Auth: Claude Max subscription (no API cost)  ║"
echo "╚═══════════════════════════════════════════════╝"

if [[ -n "$FILTER_MODEL" ]]; then
  echo "  Model filter: $FILTER_MODEL only"
fi

# Filter to specific test if argument provided
if [[ -n "$1" ]]; then
  prompt_file=$(ls "$PROMPTS_DIR"/${1}*.md 2>/dev/null | head -1)
  if [[ -z "$prompt_file" ]]; then
    echo ""
    echo "  No prompt matching '$1' found."
    echo "  Available:"
    ls "$PROMPTS_DIR"/*.md | while read f; do echo "    $(basename "$f" .md)"; done
    exit 1
  fi
  run_test "$prompt_file"
else
  for prompt_file in "$PROMPTS_DIR"/*.md; do
    run_test "$prompt_file"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DONE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Results: $RESULTS_DIR/"
echo ""
echo "  Quick compare (line counts):"
for name in "${MODEL_NAMES[@]}"; do
  if [[ -n "$FILTER_MODEL" && "$name" != "$FILTER_MODEL" ]]; then
    continue
  fi
  count=$(ls "$RESULTS_DIR"/${name}-*.md 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    total_lines=$(cat "$RESULTS_DIR"/${name}-*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "    $name: $count tests, $total_lines total lines"
  fi
done
echo ""
echo "  To re-run a test, delete its result file first."
echo "  To score results, see SCORING.md"
