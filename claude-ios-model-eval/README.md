# Claude Model Evaluation: iOS/Swift Code Generation

> **Archived snapshot of the v1 run (March 2026).** Kept as originally shared. Its findings and price table are superseded: see the [top-level README](../README.md) for both runs, corrected findings and current status. The `articles/` folder listed below is no longer in this repo.

## What This Is

A structured evaluation of three Claude model tiers (Haiku 4.5, Sonnet 4.6, Opus 4.6) generating iOS/Swift code, plus a Haiku→Opus review pipeline that produces tighter code than either model alone.

## Quick Start

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- Claude Max subscription or Anthropic API key
- macOS (for Xcode preview of Swift files)

### Run the Evaluation

```bash
# Run all 6 tests against all 3 models
./run-eval.sh

# Run a single test
./run-eval.sh 01

# Run only a specific model
./run-eval.sh --model opus

# Run the Haiku→Opus review pipeline
./run-review.sh

# Run review pipeline for a single test
./run-review.sh 01
```

Results land in `results/` — one markdown file per model per test.

### Delete a result file to re-run that specific test
```bash
rm results/opus-01-simple-list-view.md
./run-eval.sh 01
```

## Structure

```
model-eval/
├── prompts/                    # 6 test prompts (increasing complexity)
│   ├── 01-simple-list-view.md
│   ├── 02-core-data-crud.md
│   ├── 03-networking-layer.md
│   ├── 04-compositional-layout.md
│   ├── 05-combine-pipeline.md
│   ├── 06-full-feature.md
│   └── review-template.md     # Prompt used for Opus review step
├── results/                    # Raw model outputs (.md) and logs (.log)
├── swift-previews/             # Extracted .swift files for Xcode
├── articles/                   # Written articles (X, LinkedIn, Substack)
├── run-eval.sh                 # Individual model runner
├── run-review.sh               # Haiku→Opus review pipeline
├── SCORING.md                  # Scoring rubric
└── README.md                   # This file
```

## Test Prompts

| # | Test | Complexity | What It Covers |
|---|------|-----------|----------------|
| 01 | Simple List View | Low | SwiftUI list, search, navigation, @Observable |
| 02 | Core Data CRUD | Medium | Persistence, managed objects, add/edit/delete |
| 03 | Networking Layer | Medium | async/await, retry logic, Codable, error types |
| 04 | Compositional Layout | Medium-High | UICollectionView, sections, App Store-style grid |
| 05 | Combine Pipeline | High | Search debounce, cancellation, unit tests |
| 06 | Full Settings Screen | High | PhotosPicker, form validation, UserDefaults, multi-screen |

## Results Summary

### Individual Model Runs

| Test | Haiku (lines/time) | Sonnet (lines/time) | Opus (lines/time) |
|------|-------------------|--------------------|--------------------|
| 01 Simple List | 216 / 13s | 186 / 21s | 135 / 19s |
| 02 Core Data | 287 / 45s | 291 / 114s | 240 / 29s |
| 03 Networking | 426 / 40s | 626 / 133s | 420 / 42s |
| 04 Compositional | 456 / 24s | 486 / 225s | 404 / 52s |
| 05 Combine | 461 / 55s | 715 / 307s | 801 / 85s |
| 06 Full Feature | 590 / 30s | 649 / 342s | 587 / 65s |

### Haiku→Opus Review Pipeline

| Test | Haiku Draft | Opus Review | Reduction | Opus Solo |
|------|-------------|-------------|-----------|-----------|
| 01 Simple List | 216 | 154 | 28% | 135 |
| 02 Core Data | 287 | 209 | 27% | 240 |
| 03 Networking | 426 | 336 | 21% | 420 |
| 04 Compositional | 456 | 380 | 16% | 404 |
| 05 Combine | 461 | 392 | 14% | 801 |
| 06 Full Feature | 590 | 474 | 19% | 587 |

## Key Findings

1. **Opus writes the most concise code for simple-to-moderate tasks** but produces more code than Haiku on the most complex prompts (going deeper on tests/error handling).

2. **Sonnet is the worst value for code generation** — consistently the slowest and most verbose, without a quality advantage.

3. **The Haiku→Opus review pipeline produces tighter code than Opus alone** in 5 of 6 tests. The pipeline combines Haiku's speed with Opus's editorial discipline.

## Cost Reference (per 1M tokens)

| Model | Input | Output |
|-------|-------|--------|
| Haiku 4.5 | $0.80 | $4.00 |
| Sonnet 4.6 | $3.00 | $15.00 |
| Opus 4.6 | $15.00 | $75.00 |

## Viewing Swift Files in Xcode

The `swift-previews/` directory contains extracted Swift files from each model's output. To preview:

1. Create a new iOS App project in Xcode (SwiftUI, iOS 17+)
2. Drag the `.swift` files into the project
3. Open any file and use the Canvas preview (Cmd+Option+P)

Note: Some files reference UIKit or Core Data — these need the corresponding frameworks linked. Files with `@main` should replace your existing App entry point, not be added alongside it.

## Build Your Own Evaluation

Meta-prompt to create an evaluation for any domain:

> I want to evaluate how different Claude models perform at generating [YOUR DOMAIN] code. Help me design:
>
> 1. Six test prompts of increasing complexity, from a simple standalone feature to a complex multi-component system. Each prompt should describe a real feature someone would actually build.
>
> 2. A shell script (`run-eval.sh`) that runs each prompt against claude-haiku-4-5-20251001, claude-sonnet-4-6, and claude-opus-4-6 using `claude --print`. Save outputs to `results/` with naming `{model}-{test-name}.md`. Skip existing results. Track line counts and execution time.
>
> 3. A review pipeline script (`run-review.sh`) that feeds Haiku's output to Opus with a review prompt. Compare reviewed version to both Haiku's draft and Opus's solo output.
>
> 4. A scoring rubric (`SCORING.md`) with criteria relevant to [YOUR DOMAIN].
