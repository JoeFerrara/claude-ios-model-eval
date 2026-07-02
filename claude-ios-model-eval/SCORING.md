# Scoring Guide

Rate each model's output per test on these criteria (1-5 scale):

| Criteria | What to check |
|----------|--------------|
| **Compiles** | Does it compile in Xcode with zero errors? (yes=5, minor fixes=3, major issues=1) |
| **Correctness** | Does it do what was asked? All requirements met? |
| **Swift conventions** | Proper naming, access control, value vs reference types, protocol-oriented design |
| **Modern APIs** | Uses iOS 17+ APIs where appropriate (@Observable, modern SwiftUI, etc.) |
| **Error handling** | Handles edge cases, optionals properly, no force unwraps |
| **Completeness** | All requested features present? Tests included when asked? |

## Scoring Sheet

Copy this table for each test:

| Test | Model | Compiles | Correct | Conventions | Modern | Errors | Complete | Total | Tokens | Cost |
|------|-------|----------|---------|-------------|--------|--------|----------|-------|--------|------|
| 01 | haiku | /5 | /5 | /5 | /5 | /5 | /5 | /30 | | |
| 01 | sonnet | /5 | /5 | /5 | /5 | /5 | /5 | /30 | | |
| 01 | opus | /5 | /5 | /5 | /5 | /5 | /5 | /30 | | |

## Cost Reference (per 1M tokens, as of March 2026)

| Model | Input | Output |
|-------|-------|--------|
| Haiku 4.5 | $0.80 | $4.00 |
| Sonnet 4.6 | $3.00 | $15.00 |
| Opus 4.6 | $15.00 | $75.00 |

Calculate cost-efficiency: **score / cost** — highest ratio wins.
