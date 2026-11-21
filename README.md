# Claude Model Evaluation: iOS/Swift Code Generation

## What This Is

A small evaluation harness that runs six iOS/Swift prompts of increasing complexity against three Claude model tiers (Haiku 4.5, Sonnet 4.6, Opus 4.6) through the Claude Code CLI. It also runs a **Haiku-draft → Opus-review pipeline** and compares the reviewed code with Haiku's draft and with Opus working alone.

**Who did what.** I posed the question, ran both runs in March 2026 and decided to re-run with revised prompts. Claude Code chose the six features to test and wrote the scripts, prompts and scoring rubric from my meta-prompt (see [Build Your Own Evaluation](#build-your-own-evaluation)). Claude Opus 4.6 drafted my original March write-up. In November 2026 the findings below were recounted from the raw output files with Claude's help and corrected.

**What the results do and don't show.** The numbers below measure **output length (lines) and generation time**, from **one sample per model per test**. The six-criterion quality rubric in [SCORING.md](SCORING.md) has not been applied yet, so nothing here establishes which model writes *better* code. Shorter is not automatically better: it can also mean missing error handling or tests.

**About the March 2026 thread.** I posted these results on X in March 2026. That thread also reported compile results (Opus 6/6, Sonnet 5/6, Haiku 2/6) and v2 generation times. This repo has no compile script, per-file results or timing logs, so those figures can't be checked here and should be treated as unverified. The thread called the counts "lines of Swift"; they are lines of the whole response, including prose around the code.

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

# Extract Swift code blocks for Xcode (defaults: results/ → swift-previews/)
python3 extract_swift.py
python3 extract_swift.py results-v2 swift-previews-v2
```

Results land in `results/`: one markdown file per model per test. Existing results are skipped, so delete a file to re-run that test:

```bash
rm results/opus-01-simple-list-view.md
./run-eval.sh 01
```

### Re-running With Newer Models

The model IDs and the results folder can be overridden with environment variables, so a new run doesn't overwrite earlier results. The tier names (`haiku`, `sonnet`, `opus`) only set file names; any model ID works in any slot.

```bash
HAIKU_MODEL=claude-haiku-5-5 SONNET_MODEL=claude-sonnet-5-5 OPUS_MODEL=claude-opus-5-5 \
EVAL_RESULTS_DIR=results-v3 ./run-eval.sh

HAIKU_MODEL=claude-haiku-5-5 OPUS_MODEL=claude-opus-5-5 \
EVAL_RESULTS_DIR=results-v3 ./run-review.sh

python3 extract_swift.py results-v3 swift-previews-v3
```

| Variable | Default |
|----------|---------|
| `HAIKU_MODEL` | `claude-haiku-4-5-20251001` |
| `SONNET_MODEL` | `claude-sonnet-4-6` |
| `OPUS_MODEL` | `claude-opus-4-6` |
| `EVAL_RESULTS_DIR` | `results/` (`results-v2/` for the `-v2` scripts) |

## Runs

| Run | Date | Prompts | Outputs | Scripts |
|-----|------|---------|---------|---------|
| **v2** (current) | Mar 2026 | `prompts/`: unit tests removed; every answer must compile as a single iOS app target | `results-v2/`, `swift-previews-v2/` | `run-eval-v2.sh`, `run-review-v2.sh` |
| v1 | Mar 2026 | Original prompts (archived in `claude-ios-model-eval/prompts/`); test 05 asked for unit tests | `results/`, `swift-previews/` | `run-eval.sh`, `run-review.sh` |

`claude-ios-model-eval/` is an archived snapshot of the v1 run as originally shared. Because `prompts/` now holds the v2 prompts, running `run-eval.sh` today does not reproduce v1.

The cards in `images/` and the README inside `claude-ios-model-eval/` are the March originals, kept as a record. They make claims about quality and value (for example "Skip Sonnet" and "beats Opus solo") that the results here don't support.

## Test Prompts

| # | Test | Complexity | What It Covers |
|---|------|-----------|----------------|
| 01 | Simple List View | Low | SwiftUI list, search, navigation, @Observable |
| 02 | Core Data CRUD | Medium | Persistence, managed objects, add/edit/delete |
| 03 | Networking Layer | Medium | async/await, retry logic, Codable, error types |
| 04 | Compositional Layout | Medium-High | UICollectionView, sections, App Store-style grid |
| 05 | Combine Pipeline | High | Search debounce, cancellation (v1 also asked for unit tests) |
| 06 | Full Settings Screen | High | PhotosPicker, form validation, UserDefaults, multi-screen |

## Results

### v2: lines of output (current prompts)

The scripts print generation times to the terminal and don't save them, so v2 times are not in this repo.

| Test | Haiku | Sonnet | Opus | Haiku→Opus review | Review vs. Haiku draft |
|------|------:|-------:|-----:|------------------:|-----------------------:|
| 01 Simple List | 245 | 159 | **152** | 180 | −27% |
| 02 Core Data | 467 | **247** | 255 | 331 | −29% |
| 03 Networking | 540 | 649 | **424** | 458 | −15% |
| 04 Compositional | 536 | 550 | **372** | 398 | −26% |
| 05 Combine | 284 | 356 | 315 | **229** | −19% |
| 06 Full Feature | 656 | 633 | 571 | **549** | −16% |

### v1: lines / generation time (original prompts)

| Test | Haiku | Sonnet | Opus | Haiku→Opus review | Review vs. Haiku draft |
|------|------:|-------:|-----:|------------------:|-----------------------:|
| 01 Simple List | 216 / 13s | 186 / 21s | **135** / 19s | 154 | −29% |
| 02 Core Data | 287 / 45s | 291 / 114s | 240 / 29s | **209** | −27% |
| 03 Networking | 426 / 40s | 626 / 133s | 420 / 42s | **336** | −21% |
| 04 Compositional | 456 / 24s | 486 / 225s | 404 / 52s | **380** | −17% |
| 05 Combine | 461 / 55s | 715 / 307s | 801 / 85s | **392** | −15% |
| 06 Full Feature | 590 / 30s | 649 / 342s | 587 / 65s | **474** | −20% |

Bold marks the shortest output in each row.

## Key Findings

1. **Opus usually writes the shortest code.** It was the shortest of the three solo models in 5 of 6 v1 tests and 4 of 6 v2 tests.
2. **Opus reliably shortens Haiku's drafts.** The review step cut Haiku's output by 15–29% in every test of both runs.
3. **The pipeline's advantage over Opus alone did not replicate.** In v1 the reviewed code was shorter than Opus solo in 5 of 6 tests; in v2 it was shorter in 2 of 6. The three tests that flipped (02, 03 and 04) never asked for unit tests. In those tests Haiku's v2 drafts came out longer than its v1 drafts (287→467, 426→540 and 456→536 lines), while Opus solo changed little (240→255, 420→424 and 404→372). Test 05, the only one that asked for unit tests in v1, favored the pipeline in both runs. With one sample per test, the difference may be run-to-run variation, and it can't be attributed to the prompt change.
4. **Sonnet was the slowest model in every v1 test**, at 1.1–5.3× Opus's time. Its output was the longest of the three solo models in 4 of 6 v1 tests and 3 of 6 v2 tests. Without rubric scores, this says nothing about quality.

The main lesson so far concerns method, not models: the headline result did not hold in a second run, so line-count comparisons need several samples per test and quality scoring before they support conclusions.

## Known Limitations and Next Steps

- Score every output with the [SCORING.md](SCORING.md) rubric, starting with a compile check in Xcode
- Run several samples per model per test to measure variance (currently n=1)
- Record token usage and cost per run (needed for SCORING.md's score/cost ratio)
- Record generation time in v2-style runs
- Re-run on current models (see [Re-running With Newer Models](#re-running-with-newer-models))

## Cost

Prices change over time, so this repo no longer lists them. See [Anthropic's pricing page](https://www.anthropic.com/pricing) for current per-token prices.

## Structure

```
model-eval/
├── prompts/                    # 6 test prompts (v2) + review-template.md
├── results/                    # v1 raw model outputs (.md) and logs (.log)
├── results-v2/                 # v2 raw model outputs
├── swift-previews/             # v1 Swift files extracted for Xcode
├── swift-previews-v2/          # v2 Swift files extracted for Xcode
├── images/                     # Charts and cards summarizing the v1 run
├── claude-ios-model-eval/      # Archived v1 snapshot (original prompts and results)
├── run-eval.sh / -v2.sh        # Individual model runner
├── run-review.sh / -v2.sh      # Haiku→Opus review pipeline
├── extract_swift.py            # Pulls ```swift blocks out of results into .swift files
├── post-thread.mjs             # Posts a markdown thread to X (needs .env; see .env.example)
├── SCORING.md                  # Scoring rubric
└── LICENSE                     # MIT
```

## Viewing Swift Files in Xcode

The `swift-previews/` and `swift-previews-v2/` directories contain the Swift code extracted from each model's output. To preview:

1. Create a new iOS App project in Xcode (SwiftUI, iOS 17+)
2. Drag the `.swift` files into the project
3. Open any file and use the Canvas preview (Cmd+Option+P)

Note: Some files reference UIKit or Core Data, so those frameworks need to be linked. Files with `@main` should replace your existing App entry point, not be added alongside it.

## Build Your Own Evaluation

Meta-prompt to create an evaluation for any domain (swap in current model IDs):

> I want to evaluate how different Claude models perform at generating [YOUR DOMAIN] code. Help me design:
>
> 1. Six test prompts of increasing complexity, from a simple standalone feature to a complex multi-component system. Each prompt should describe a real feature someone would actually build.
>
> 2. A shell script (`run-eval.sh`) that runs each prompt against claude-haiku-4-5-20251001, claude-sonnet-4-6, and claude-opus-4-6 using `claude --print`. Save outputs to `results/` with naming `{model}-{test-name}.md`. Skip existing results. Track line counts and execution time.
>
> 3. A review pipeline script (`run-review.sh`) that feeds Haiku's output to Opus with a review prompt. Compare reviewed version to both Haiku's draft and Opus's solo output.
>
> 4. A scoring rubric (`SCORING.md`) with criteria relevant to [YOUR DOMAIN].

## License

[MIT](LICENSE)
