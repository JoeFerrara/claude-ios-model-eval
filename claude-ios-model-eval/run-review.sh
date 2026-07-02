#!/bin/bash
# Haiku-draft → Opus-review pipeline
# Usage: ./run-review.sh [prompt-number]
# Example: ./run-review.sh 01   (run just test 01)
# Example: ./run-review.sh       (run all tests)
#
# This script:
# 1. Runs Haiku to generate the initial draft (if not already done)
# 2. Runs Opus to review and tighten Haiku's output
# 3. Compares line counts across all versions

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"
RESULTS_DIR="$SCRIPT_DIR/results"
REVIEW_TEMPLATE="$PROMPTS_DIR/review-template.md"

mkdir -p "$RESULTS_DIR"

run_pipeline() {
  local prompt_file="$1"
  local test_name=$(basename "$prompt_file" .md)

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  PIPELINE: $test_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local haiku_file="$RESULTS_DIR/haiku-${test_name}.md"
  local review_file="$RESULTS_DIR/opus-review-of-haiku-${test_name}.md"
  local opus_file="$RESULTS_DIR/opus-${test_name}.md"

  # Step 1: Haiku draft
  if [[ -f "$haiku_file" ]] && [[ $(wc -c < "$haiku_file" | tr -d ' ') -gt 100 ]]; then
    local haiku_lines=$(wc -l < "$haiku_file" | tr -d ' ')
    echo "  ⏭  Haiku draft exists (${haiku_lines} lines)"
  else
    rm -f "$haiku_file" "${haiku_file%.md}.log"
    echo "  🔄 Step 1: Haiku drafting..."
    local start_time=$(date +%s)

    claude --model claude-haiku-4-5-20251001 \
      -p "$(cat "$prompt_file") Output all code directly in your response. Do not write any files." \
      --print \
      > "$haiku_file" 2>"$RESULTS_DIR/haiku-${test_name}.log"

    local exit_code=$?
    local duration=$(( $(date +%s) - start_time ))

    if [[ $exit_code -eq 0 ]]; then
      local haiku_lines=$(wc -l < "$haiku_file" | tr -d ' ')
      echo "  ✅ Haiku draft — ${duration}s, ${haiku_lines} lines"
    else
      echo "  ❌ Haiku draft failed (exit $exit_code) after ${duration}s"
      echo "     Check: $RESULTS_DIR/haiku-${test_name}.log"
      return 1
    fi
  fi

  # Step 2: Opus review
  if [[ -f "$review_file" ]] && [[ $(wc -c < "$review_file" | tr -d ' ') -gt 100 ]]; then
    local review_lines=$(wc -l < "$review_file" | tr -d ' ')
    echo "  ⏭  Opus review exists (${review_lines} lines)"
  else
    rm -f "$review_file" "${review_file%.md}.log"
    echo "  🔄 Step 2: Opus reviewing Haiku's draft..."
    local start_time=$(date +%s)

    local review_prompt="$(cat "$REVIEW_TEMPLATE")
$(cat "$haiku_file")"

    claude --model claude-opus-4-6 \
      -p "$review_prompt" \
      --print \
      > "$review_file" 2>"$RESULTS_DIR/opus-review-of-haiku-${test_name}.log"

    local exit_code=$?
    local duration=$(( $(date +%s) - start_time ))

    if [[ $exit_code -eq 0 ]]; then
      local review_lines=$(wc -l < "$review_file" | tr -d ' ')
      echo "  ✅ Opus review — ${duration}s, ${review_lines} lines"
    else
      echo "  ❌ Opus review failed (exit $exit_code) after ${duration}s"
      echo "     Check: $RESULTS_DIR/opus-review-of-haiku-${test_name}.log"
      return 1
    fi
  fi

  # Summary comparison
  echo ""
  echo "  📊 Comparison:"
  local h_lines=$(wc -l < "$haiku_file" 2>/dev/null | tr -d ' ')
  local h_bytes=$(wc -c < "$haiku_file" 2>/dev/null | tr -d ' ')
  local r_lines=$(wc -l < "$review_file" 2>/dev/null | tr -d ' ')
  local r_bytes=$(wc -c < "$review_file" 2>/dev/null | tr -d ' ')
  printf "     %-25s %6s lines  %8s bytes\n" "Haiku draft:" "$h_lines" "$h_bytes"
  printf "     %-25s %6s lines  %8s bytes\n" "Opus review of Haiku:" "$r_lines" "$r_bytes"
  if [[ -f "$opus_file" ]] && [[ $(wc -c < "$opus_file" | tr -d ' ') -gt 100 ]]; then
    local o_lines=$(wc -l < "$opus_file" 2>/dev/null | tr -d ' ')
    local o_bytes=$(wc -c < "$opus_file" 2>/dev/null | tr -d ' ')
    printf "     %-25s %6s lines  %8s bytes\n" "Opus from scratch:" "$o_lines" "$o_bytes"
  fi

  # Reduction percentage
  if [[ "$h_lines" -gt 0 ]]; then
    local reduction=$(( (h_lines - r_lines) * 100 / h_lines ))
    echo ""
    echo "     Reduction: ${reduction}% fewer lines after Opus review"
  fi
}

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  Haiku Draft → Opus Review Pipeline           ║"
echo "║  Auth: Claude Max subscription (no API cost)  ║"
echo "╚═══════════════════════════════════════════════╝"

# Filter to specific test if argument provided
if [[ -n "$1" ]]; then
  prompt_file=$(ls "$PROMPTS_DIR"/${1}*.md 2>/dev/null | grep -v review-template | head -1)
  if [[ -z "$prompt_file" ]]; then
    echo ""
    echo "  No prompt matching '$1' found."
    echo "  Available:"
    ls "$PROMPTS_DIR"/*.md | grep -v review-template | while read f; do echo "    $(basename "$f" .md)"; done
    exit 1
  fi
  run_pipeline "$prompt_file"
else
  for prompt_file in "$PROMPTS_DIR"/*.md; do
    [[ "$(basename "$prompt_file")" == "review-template.md" ]] && continue
    run_pipeline "$prompt_file"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ALL DONE — SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "  %-35s %8s %8s %8s\n" "Test" "Haiku" "Reviewed" "Opus Solo"
printf "  %-35s %8s %8s %8s\n" "---" "-----" "--------" "---------"

for prompt_file in "$PROMPTS_DIR"/*.md; do
  [[ "$(basename "$prompt_file")" == "review-template.md" ]] && continue
  local_test=$(basename "$prompt_file" .md)
  h=$(wc -l < "$RESULTS_DIR/haiku-${local_test}.md" 2>/dev/null | tr -d ' ')
  r=$(wc -l < "$RESULTS_DIR/opus-review-of-haiku-${local_test}.md" 2>/dev/null | tr -d ' ')
  o=$(wc -l < "$RESULTS_DIR/opus-${local_test}.md" 2>/dev/null | tr -d ' ')
  [[ -z "$h" ]] && h="-"
  [[ -z "$r" ]] && r="-"
  [[ -z "$o" ]] && o="-"
  printf "  %-35s %8s %8s %8s\n" "$local_test" "$h" "$r" "$o"
done
echo ""
echo "  Results in: $RESULTS_DIR/"
