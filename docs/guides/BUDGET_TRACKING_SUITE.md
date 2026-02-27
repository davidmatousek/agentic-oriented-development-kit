# Budget Tracking Feature Suite

**Features**: 032, 034, 036, 038, 042, 047, **054**
**Purpose**: Measure, analyze, and optimize AOD Triad performance toward single-session lifecycle completion
**Last Updated**: 2026-02-14

---

## Vision

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              THE GOAL                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   /aod.run "Add user authentication"                                        │
│                                                                             │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│   │Discover │───▶│ Define  │───▶│  Plan   │───▶│  Build  │───▶│ Deliver │  │
│   └─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
│                                                                             │
│                         ALL IN ONE SESSION                                  │
│                                                                             │
│   ════════════════════════════════════════════════════════════════════════  │
│   [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] <80%   │
│                          Context Window Usage                               │
│                                                                             │
│   Safety margin preserved ────────────────────────────────────▶ ████ 20%   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**The goal is NOT to pause gracefully. The goal is to NEVER NEED to pause.**

---

## User Perspective

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER PERSPECTIVE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   WANT:     Fewest pauses possible                                          │
│             ────────────────────────                                        │
│             "Let me kick off /aod.run and come back to a finished feature"  │
│                                                                             │
│   WON'T     Sacrifice quality for fewer pauses                              │
│   ACCEPT:   ─────────────────────────────────                               │
│             "A broken feature delivered fast is worse than waiting"         │
│                                                                             │
│   DON'T     How long it takes                                               │
│   CARE:     ────────────────────                                            │
│             "If it takes 2 hours but finishes in one session, great"        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### User Priority Stack

```
                         ▲
                         │
           ┌─────────────┴─────────────┐
           │                           │
           │    1. QUALITY             │  ████████████  Non-negotiable
           │       Complete, correct,  │
           │       production-ready    │
           │                           │
           ├───────────────────────────┤
           │                           │
           │    2. FEW PAUSES          │  ████████████  Minimize interruptions
           │       Ideally zero,       │
           │       but safety-net OK   │
           │                           │
           ├───────────────────────────┤
           │                           │
           │    3. SPEED               │  ░░░░░░░░░░░░  Don't care
           │       Willing to wait     │
           │       for quality         │
           │                           │
           └───────────────────────────┘
                         │
                         ▼
```

### What Users See vs What The System Does

| User Experience | System Implementation |
|-----------------|----------------------|
| "Zero pauses" | Total context < 80% of window |
| "One pause" | Auto-pause triggered, `/aod.run --resume` needed |
| "Quality output" | Full Triad governance, thorough research, complete validation |
| "It just works" | Budget tracking, trend analysis, calibrated estimates |

**Users don't see tokens** — they see whether they had to resume or not. All the budget tracking, optimization, and auto-pause logic are implementation details serving the user goal of **uninterrupted, high-quality feature delivery**.

---

## The Optimization Triad

```
                                 QUALITY
                                    ▲
                                   /│\
                                  / │ \
                                 /  │  \
                                /   │   \
                               /    │    \
                              /   KEEP    \
                             /   AT ALL    \
                            /    COSTS      \
                           /        │        \
                          /         │         \
                         /          │          \
                        ▼───────────┴───────────▼
               CONTEXT MGMT                   SPEED
                  KEEP                      SACRIFICE OK


    ┌────────────────────────────────────────────────────────────────────┐
    │                                                                    │
    │   "I will wait longer for a complete, high-quality lifecycle      │
    │    that fits in one session, rather than rush and compromise."    │
    │                                                                    │
    └────────────────────────────────────────────────────────────────────┘
```

### What Quality Means (Non-Negotiable)

| Quality Component | Description | Never Compromise |
|-------------------|-------------|------------------|
| **Triad Governance** | PM + Architect + Team-Lead reviews | All sign-offs required |
| **Research Phase** | KB query, codebase exploration, web research | Thorough discovery |
| **Spec Completeness** | User stories, acceptance criteria, edge cases | No shortcuts |
| **Architecture Review** | Technical feasibility, security, scalability | Full analysis |
| **Testing Validation** | Post-delivery validation, Definition of Done | Complete verification |

### Acceptable Optimizations (Context Reduction Without Quality Loss)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ✓ ACCEPTABLE OPTIMIZATIONS                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LAZY LOADING                                                               │
│  ├── Load governance rules only when gate is reached                       │
│  ├── Load reference files on-demand, not upfront                           │
│  └── Defer research docs until actually needed                             │
│                                                                             │
│  CACHING                                                                    │
│  ├── Cache approved artifact metadata (don't re-read full files)           │
│  ├── Store governance verdicts (don't re-run same review)                  │
│  └── Remember already-validated state across stages                        │
│                                                                             │
│  SERIALIZATION (trade speed for context)                                   │
│  ├── Run Triad reviews sequentially instead of parallel                    │
│  ├── Process one stage fully before loading next stage's context           │
│  └── Unload completed stage artifacts before starting next                 │
│                                                                             │
│  COMPRESSION                                                                │
│  ├── Remove redundant instructions that repeat across skills               │
│  ├── Consolidate duplicate file reads                                      │
│  └── Summarize large artifacts instead of full content (where safe)        │
│                                                                             │
│  STRUCTURAL                                                                 │
│  ├── Split monolithic skills into core + references                        │
│  ├── Use compound state helpers (one call, multiple values)                │
│  └── Extract stage-specific logic to load only when needed                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Off-Limits Optimizations (Would Hurt Quality)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ✗ OFF-LIMITS — NEVER DO THESE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ✗ Skip Triad sign-offs to save context                                    │
│  ✗ Reduce research depth or skip KB queries                                │
│  ✗ Shorten prompts that produce better output quality                      │
│  ✗ Remove governance gates or validation steps                             │
│  ✗ Skip post-delivery validation                                           │
│  ✗ Omit edge cases or acceptance criteria from specs                       │
│  ✗ Rush architecture review to save tokens                                 │
│  ✗ Skip Definition of Done checklist                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

The budget tracking system exists to:
1. **Measure** actual context consumption per stage
2. **Identify** efficiency opportunities that DON'T compromise quality
3. **Tune** the AOD Triad process to fit within a single session
4. **Protect** against "prompt too long" errors as a safety net (not the norm)

---

## Overview

Features 032, 034, 036, 038, 042, and **047** form an integrated **performance evaluation and optimization system** that measures context consumption and tunes the AOD Triad process for single-session completion.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CONTEXT BUDGET TRACKING SUITE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ═══════════════════════════════ MEASURE ═══════════════════════════════   │
│                                                                             │
│  032: Real-time Budget    034: Cross-Session     036: Auto-Pause            │
│       Tracking                 History                Orchestration         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │ • Heuristic     │     │ • prior_sessions│     │ • High-conf     │       │
│  │   estimation    │────▶│   array         │────▶│   auto-pause    │       │
│  │ • Stage map %   │     │ • Trend analysis│     │ • Low-conf      │       │
│  │ • Adaptive load │     │ • Predictions   │     │   manual prompt │       │
│  └─────────────────┘     └─────────────────┘     │ • --force-cont  │       │
│                                                   └─────────────────┘       │
│                                                                             │
│  038: Universal Tracking  042: Self-Calibrating   054: Parallel Budget     │
│  ┌─────────────────┐          Registry                 Hardening           │
│  │ • All 7 skills  │     ┌─────────────────┐     ┌─────────────────┐       │
│  │ • Standalone +  │◀───▶│ • 5-feature FIFO│     │ • 1.0x/1.5x/3.0x│       │
│  │   orchestrated  │     │ • Calibrated    │◀───▶│   multipliers   │       │
│  │ • Non-fatal     │     │   defaults      │     │ • Circuit-breaker│       │
│  └─────────────────┘     └─────────────────┘     │ • Churn detect  │       │
│                                   │              └─────────────────┘       │
│  ═══════════════════════════════ │ ════════════════════════════════════   │
│                                   │                                         │
│                                   ▼ OPTIMIZE                                │
│                                                                             │
│                    047: Define/Plan Stage Optimization                      │
│                    ┌─────────────────────────────────────┐                 │
│                    │ • Lazy governance loading           │                 │
│                    │ • Serialized Triad reviews          │                 │
│                    │ • Governance verdict caching        │                 │
│                    │ • Substage context unloading        │                 │
│                    │                                     │                 │
│                    │ TARGET: Define ≤12K, Plan ≤15K     │                 │
│                    │         Total lifecycle <60K        │                 │
│                    └─────────────────────────────────────┘                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## How to Use

### Running the Orchestrator

```bash
# Start a new feature lifecycle
/aod.run "Add user authentication"

# Resume after session pause
/aod.run --resume

# Override auto-pause (use with caution!)
/aod.run --force-continue --resume

# Check current status
/aod.run --status
```

### What You'll See

**Stage Map with Budget Tracking:**
```
┌──────────────────────────────────────────────────────────────┐
│  STAGE MAP                                      (~45% used)  │
├──────────────────────────────────────────────────────────────┤
│  [✓] Discover  ──▶  [✓] Define  ──▶  [●] Plan  ──▶  Build   │
│                                       ↑                      │
│                                   YOU ARE HERE               │
│                                                              │
│  Trend: ↑ 12K avg/stage (3 sessions) • ~2 sessions remain   │
└──────────────────────────────────────────────────────────────┘
```

**Auto-Pause Output (High Confidence):**
```
⏸️ AUTO-PAUSE TRIGGERED

Historical data predicts the next stage (build) will exceed remaining budget.
  Predicted cost: ~13K tokens
  Remaining budget: ~8K tokens
  Confidence: High (based on 3 prior sessions)

State saved to .aod/run-state.json
Current stage (plan) marked complete.

To resume in a new session:
  /aod.run --resume
```

**Manual Prompt (Low Confidence):**
```
Budget alert: Estimated ~75% used. Next stage (build) may exceed remaining budget.
Confidence: low confidence — 1 session of data
Recommend: /aod.run --resume in a new session.

? Continue to next stage or pause and resume later? (low confidence — 1 session)
  ○ Continue anyway
  ○ Pause and resume
```

---

## The Context Evaluation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTEXT EVALUATION FLOW                             │
│                         (Core Loop Step 12)                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                              STAGE COMPLETES
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │  1. READ BUDGET SUMMARY       │
                    │     estimated | usable | %    │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │  2. ESTIMATE NEXT STAGE COST  │
                    │     (4-tier fallback chain)   │
                    └───────────────┬───────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
           ▼                        ▼                        ▼
    ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
    │ REGISTRY    │    OR    │ HISTORICAL  │    OR    │ CURRENT     │
    │ calibrated  │─────────▶│ per-stage   │─────────▶│ session     │
    │ defaults    │  (miss)  │ average     │  (miss)  │ average     │
    └─────────────┘          └─────────────┘          └──────┬──────┘
                                                             │(miss)
                                                             ▼
                                                      ┌─────────────┐
                                                      │ DEFAULT     │
                                                      │ 15,000 tkns │
                                                      └─────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │  3. CALCULATE MARGIN          │
                    │  margin = (remaining - cost)  │
                    │           ─────────────────   │
                    │               remaining       │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │  4. CHECK 2-REJECTION         │
                    │     ESCALATION                │
                    │                               │
                    │  2+ rejections on same gate?  │
                    │  YES: threshold = 30% (70%)   │
                    │  NO:  threshold = 20% (80%)   │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                     ┌──────────────────────────────┐
                     │  5. CHECK --force-continue   │
                     └──────────────┬───────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
             [flag set]                      [flag not set]
                    │                               │
                    ▼                               ▼
           ┌─────────────────┐      ┌───────────────────────────────┐
           │ ⚠️ WARN + LOG   │      │  6. CONFIDENCE ROUTING        │
           │ Continue anyway │      └───────────────┬───────────────┘
           └────────┬────────┘                      │
                    │               ┌───────────────┴───────────────┐
                    │               │                               │
                    │     [sessions >= 3 AND                [sessions < 3 OR
                    │      margin < threshold]               margin >= threshold]
                    │               │                               │
                    │               ▼                               ▼
                    │    ┌─────────────────────┐      ┌─────────────────────┐
                    │    │  ⏸️ AUTO-PAUSE      │      │  🔔 ASK USER        │
                    │    │  (no prompt)        │      │  (manual decision)  │
                    │    │                     │      │                     │
                    │    │  • Log event        │      │  • Show confidence  │
                    │    │  • Save state       │      │  • Continue/Pause?  │
                    │    │  • EXIT             │      │                     │
                    │    └─────────────────────┘      └──────────┬──────────┘
                    │                                            │
                    │                              ┌─────────────┴─────────────┐
                    │                              │                           │
                    │                       [Continue]                   [Pause]
                    │                              │                           │
                    │                              │                           ▼
                    │                              │              ┌─────────────────────┐
                    │                              │              │  Save state + EXIT  │
                    │                              │              └─────────────────────┘
                    │                              │
                    └──────────────────────────────┴──────────────┐
                                                                  │
                                                                  ▼
                                              ┌───────────────────────────────┐
                                              │  7. CONTINUE TO NEXT STAGE    │
                                              │     (loop back to step 1)     │
                                              └───────────────────────────────┘
```

---

## Confidence Routing Decision Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CONFIDENCE ROUTING MATRIX                              │
├───────────────┬────────────────┬────────────────┬───────────────────────────┤
│  SESSION      │    MARGIN      │    ACTION      │    USER EXPERIENCE        │
│  COUNT        │                │                │                           │
├───────────────┼────────────────┼────────────────┼───────────────────────────┤
│               │                │                │                           │
│    0          │    any         │  MANUAL PROMPT │  "insufficient data"      │
│               │                │                │                           │
├───────────────┼────────────────┼────────────────┼───────────────────────────┤
│               │                │                │                           │
│    1          │    any         │  MANUAL PROMPT │  "low confidence —        │
│               │                │                │   1 session of data"      │
│               │                │                │                           │
├───────────────┼────────────────┼────────────────┼───────────────────────────┤
│               │                │                │                           │
│    2          │    any         │  MANUAL PROMPT │  "medium confidence —     │
│               │                │                │   2 sessions of data"     │
│               │                │                │                           │
├───────────────┼────────────────┼────────────────┼───────────────────────────┤
│               │                │                │                           │
│   3+          │   < 20%        │  AUTO-PAUSE    │  No prompt. Automatic     │
│               │  (tight)       │                │  state save and exit.     │
│               │                │                │                           │
├───────────────┼────────────────┼────────────────┼───────────────────────────┤
│               │                │                │                           │
│   3+          │   >= 20%       │  MANUAL PROMPT │  "borderline margin"      │
│               │  (borderline)  │                │                           │
│               │                │                │                           │
├───────────────┼────────────────┼────────────────┼───────────────────────────┤
│               │                │                │                           │
│   any         │   sufficient   │  CONTINUE      │  No interruption.         │
│               │   budget       │                │  Proceed normally.        │
│               │                │                │                           │
└───────────────┴────────────────┴────────────────┴───────────────────────────┘

  Note: With 2+ governance rejections on same gate, threshold drops to 30% (70% trigger)
```

---

## Data Flow Across Features

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FEATURE LIFECYCLE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

  ╔═══════════════════════════════════════════════════════════════════════╗
  ║                         FEATURE START                                  ║
  ╚═══════════════════════════════════════════════════════════════════════╝
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────────┐
         │              PERFORMANCE REGISTRY                     │
         │         .aod/memory/performance-registry.json         │
         │                                                       │
         │   {                                                   │
         │     "calibrated_defaults": {                          │
         │       "usable_budget": 60000,    ◀─── READ            │
         │       "per_stage_estimates": {                        │
         │         "discover": 10000,                            │
         │         "define": 20000,                              │
         │         "plan": 20000,                                │
         │         "build": 13000,                               │
         │         "deliver": 11500                              │
         │       }                                               │
         │     },                                                │
         │     "features": [ ... 5 max, FIFO ... ]              │
         │   }                                                   │
         └────────────────────────┬─────────────────────────────┘
                                  │
                                  ▼
         ┌──────────────────────────────────────────────────────┐
         │                  RUN-STATE FILE                       │
         │               .aod/run-state.json                     │
         │                                                       │
         │   Created with calibrated defaults:                   │
         │   • usable_budget: 60000 (from registry)              │
         │   • stage_estimates: pre-populated                    │
         │   • prior_sessions: [] (grows over sessions)          │
         │                                                       │
         └────────────────────────┬─────────────────────────────┘
                                  │
                                  ▼
  ╔═══════════════════════════════════════════════════════════════════════╗
  ║                      STAGE EXECUTION LOOP                             ║
  ║                                                                        ║
  ║   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────┐ ║
  ║   │Discover │───▶│ Define  │───▶│  Plan   │───▶│  Build  │───▶│Deliv│ ║
  ║   └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘    └──┬──┘ ║
  ║        │              │              │              │             │    ║
  ║        ▼              ▼              ▼              ▼             ▼    ║
  ║   [estimate]     [estimate]     [estimate]     [estimate]    [final]  ║
  ║                                                                        ║
  ║   Each stage:                                                          ║
  ║   1. Write pre-estimate                                                ║
  ║   2. Execute stage                                                     ║
  ║   3. Write post-estimate                                               ║
  ║   4. Check budget → auto-pause/prompt/continue                         ║
  ║                                                                        ║
  ╚═══════════════════════════════════════════════════════════════════════╝
                                  │
                                  │ (session ends, resumes...)
                                  │
                                  ▼
         ┌──────────────────────────────────────────────────────┐
         │              PRIOR SESSIONS ARRAY                     │
         │            (max 3 entries, FIFO)                      │
         │                                                       │
         │   "prior_sessions": [                                 │
         │     { "session": 1, "stages": {...}, "total": 45000 },│
         │     { "session": 2, "stages": {...}, "total": 52000 },│
         │     { "session": 3, "stages": {...}, "total": 48000 } │
         │   ]                                                   │
         │                                                       │
         │   Used for:                                           │
         │   • Trend analysis (aod_state_get_trend_summary)      │
         │   • Per-stage historical averages                     │
         │   • Session count for confidence routing              │
         │                                                       │
         └────────────────────────┬─────────────────────────────┘
                                  │
                                  ▼
  ╔═══════════════════════════════════════════════════════════════════════╗
  ║                        FEATURE DELIVERY                               ║
  ╚═══════════════════════════════════════════════════════════════════════╝
                                  │
                                  ▼
         ┌──────────────────────────────────────────────────────┐
         │           REGISTRY POPULATION (/aod.deliver)          │
         │                                                       │
         │   1. Archive run-state to specs/{NNN}-*/              │
         │   2. Extract stage estimates from run-state           │
         │   3. Append feature to registry (FIFO, max 5)         │
         │   4. Recalculate calibrated_defaults from all         │
         │                                                       │
         │   ┌─────────────────────────────────────────────┐     │
         │   │  features: [                                │     │
         │   │    { "034": ... },                          │     │
         │   │    { "038": ... },                          │     │
         │   │    { "042": ... },                          │     │
         │   │    { "036": ... }  ◀─── NEWEST              │     │
         │   │  ]                                          │     │
         │   └─────────────────────────────────────────────┘     │
         │                                                       │
         └────────────────────────┬─────────────────────────────┘
                                  │
                                  │ (feeds back to next feature)
                                  │
                                  ▼
                         ┌───────────────┐
                         │  NEXT FEATURE │
                         │  STARTS HERE  │────────▶ (loop)
                         └───────────────┘
```

---

## File Locations

```
.aod/
├── run-state.json                      # Current feature state + budget
├── memory/
│   └── performance-registry.json       # Historical calibration data
└── scripts/bash/
    ├── run-state.sh                    # Budget tracking functions
    └── performance-registry.sh         # Registry functions

specs/{NNN}-feature-name/
└── run-state.json                      # Archived state after delivery
```

---

## Feature Summary

| Feature | What It Does | Role in Vision |
|---------|--------------|----------------|
| **032** | Tracks token usage per stage | **Measure** — visibility into what consumes context |
| **034** | Stores historical session data | **Baseline** — establishes performance benchmarks |
| **036** | Auto-pauses when confident | **Safety Net** — prevents errors while optimizing |
| **038** | Works with standalone skills | **Coverage** — measures ALL workflows, not just orchestrated |
| **042** | Calibrates from real data | **Feedback** — tells us if optimizations are working |
| **047** | Optimizes Define/Plan stages | **Optimize** — reduces context consumption without sacrificing quality |
| **054** | Parallel execution budget hardening | **Accuracy** — multiplier-based scaling for concurrent agents + churn detection |

**The system learns from itself** — each delivered feature provides data to optimize the next iteration toward single-session completion. Feature 047 acts on the measurement data from 032-042 to implement actual optimizations.

---

## Optimization Strategy

The budget data isn't just for pausing — it's for **tuning the process**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OPTIMIZATION FEEDBACK LOOP                           │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │  RUN LIFECYCLE  │
                              │   /aod.run      │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
           ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
           │   MEASURE    │   │   MEASURE    │   │   MEASURE    │
           │  per stage   │   │  per skill   │   │  per action  │
           └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
                  │                  │                  │
                  └──────────────────┼──────────────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │   PERFORMANCE REGISTRY │
                        │                        │
                        │  • Stage costs         │
                        │  • Session counts      │
                        │  • Total consumption   │
                        └───────────┬────────────┘
                                    │
                                    ▼
                        ┌────────────────────────┐
                        │      ANALYZE           │
                        │                        │
                        │  Which stage is        │
                        │  consuming the most?   │
                        │                        │
                        │  ┌──────────────────┐  │
                        │  │ discover:  10K   │  │
                        │  │ define:    20K ◀─┼──┼── Feature 047
                        │  │ plan:      20K ◀─┼──┼── optimized these
                        │  │ build:     13K   │  │
                        │  │ deliver:   11K   │  │
                        │  └──────────────────┘  │
                        └───────────┬────────────┘
                                    │
                                    ▼
                        ┌────────────────────────┐
                        │    TUNE (Feature 047)  │
                        │                        │
                        │  ✓ Lazy load refs      │
                        │  ✓ Cache governance    │
                        │  ✓ Serialize reviews   │
                        │  ✓ Unload substages    │
                        └───────────┬────────────┘
                                    │
                                    ▼
                        ┌────────────────────────┐
                        │    REPEAT UNTIL:       │
                        │                        │
                        │    Full lifecycle      │
                        │    fits in <80%        │
                        │    of context window   │
                        └────────────────────────┘
```

### Implementation Audit (Verified 2026-02-13)

All components of the feedback loop are in place and working. A jq scoping bug in `aod_registry_recalculate()` was fixed on 2026-02-13 — the learning loop now correctly computes calibrated defaults from historical data.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     FEEDBACK LOOP AUDIT RESULTS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  RECORD PHASE                                                    ✓ VERIFIED │
│  ├── aod_state_update_budget()     run-state.sh:536             ✓          │
│  ├── aod_state_get_budget_summary() run-state.sh                ✓          │
│  ├── prior_sessions handling        run-state.sh                ✓          │
│  └── Budget Tracking in all 7 commands:                                    │
│      ├── aod.discover.md            ✓                                      │
│      ├── aod.define.md              ✓                                      │
│      ├── aod.spec.md                ✓                                      │
│      ├── aod.project-plan.md        ✓                                      │
│      ├── aod.tasks.md               ✓                                      │
│      ├── aod.build.md               ✓                                      │
│      └── aod.deliver.md             ✓                                      │
│                                                                             │
│  RECALCULATE PHASE                                           ✓ FIXED/WORKS │
│  ├── aod_registry_append_feature()  performance-registry.sh     ✓          │
│  ├── aod_registry_recalculate()     performance-registry.sh:233 ✓ (fixed)  │
│  └── Called from aod.deliver.md     lines 130, 137              ✓          │
│                                                                             │
│  USE UPDATED VALUES PHASE                                        ✓ VERIFIED │
│  ├── Registry read in SKILL.md      aod_registry_get_default    ✓          │
│  ├── usable_budget from registry    all 7 commands              ✓          │
│  ├── per_stage_estimates used       SKILL.md:90, 110            ✓          │
│  └── Entry modes read calibrated    entry-modes.md:26, 149      ✓          │
│                                                                             │
│  REGISTRY DATA                                                   ✓ LEARNING │
│  ├── File exists                    .aod/memory/performance-registry.json  │
│  ├── Features tracked               5 of 5 max                  ✓          │
│  └── Calibrated defaults            COMPUTED FROM ACTUAL DATA   ✓          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**What improves automatically over time:**
- `usable_budget` — calibrated from actual consumption (currently 76,100 from 5 features)
- `per_stage_estimates` — averages from last 5 features (see Current Performance Baseline below)
- Auto-pause predictions — based on historical accuracy

**Bug Fixed (2026-02-13):** The `aod_registry_recalculate()` function had a jq scoping bug where `.features[]` was referenced inside a `map()` where the context was a string, not the root object. Fixed by capturing the root object with `. as $root |` before the map.

**Known Gap** (tracked as [Issue #46](https://github.com/davidmatousek/product-led-spec-kit/issues/46)):
The loop records and uses data automatically, but doesn't yet **automatically identify optimization opportunities** (e.g., "Define stage is 40% over target"). The ANALYZE step in the diagram above was manual — Feature 047 addressed the highest-impact optimizations identified through manual analysis. Future iterations may automate this analysis.

### Current Performance Baseline

From the registry (5 features tracked: 042, 036, 047, 049×2):

| Stage | Original Hardcoded | Learned (Actual) | 047 Target | Status |
|-------|-------------------|------------------|------------|--------|
| Discover | 10,000 | **14,666** | 8K | ⚠️ Higher than expected |
| Define | 20,000 | **37,500** | ≤12K | ❌ Needs optimization |
| Plan | 20,000 | **23,750** | ≤15K | ⚠️ Over target |
| Build | 13,000 | **18,000** | 10K | ⚠️ Higher than expected |
| Deliver | 11,500 | **5,000** (default) | 8K | ✅ Under target |
| **usable_budget** | **60,000** | **76,100** | <60K | ⚠️ Recalibrated |

**Key Insight**: The learned values from actual measurements are significantly higher than the original hardcoded estimates. This explains why Feature 047's optimization targets (Define ≤12K, Plan ≤15K) were not met — the original baselines underestimated actual consumption.

**Feature 047 Optimizations Applied**:
- Lazy governance loading (load at gate, not at stage start)
- Serialized Triad reviews (PM → Architect → Team-Lead, sequential)
- Governance verdict caching (mtime-based invalidation)
- Substage context unloading (boundary markers between spec/plan/tasks)

**Next Steps**:
1. The optimizations are working, but the baselines need adjustment
2. Define stage (37.5K learned) may need architectural changes, not just lazy loading
3. Consider splitting Define into smaller substages like Plan has (spec/project-plan/tasks)

### Optimization Priorities

All optimizations preserve full quality — they reduce redundancy, not thoroughness.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 OPTIMIZATION PRIORITIES (Quality-Preserving)                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  HIGH IMPACT (Define + Plan = 40K combined):                   FEATURE 047 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ✓ 1. PRD generation in /aod.define loads full governance rules     │   │
│  │    → Lazy-load only when governance gate reached                   │   │
│  │    Quality: Reviews still happen, just loaded later                │   │
│  │    Status: IMPLEMENTED (FR-001, FR-002, FR-003)                    │   │
│  │                                                                     │   │
│  │ ✓ 2. Triple parallel reviews load 3 agent contexts simultaneously  │   │
│  │    → Serialize reviews (slower but same thoroughness)              │   │
│  │    Quality: Same review depth, just sequential not parallel        │   │
│  │    Status: IMPLEMENTED (FR-005, FR-006, FR-007)                    │   │
│  │                                                                     │   │
│  │ ✓ 3. /aod.spec, /aod.project-plan, /aod.tasks each load SKILL.md   │   │
│  │    → Unload previous substage before loading next                  │   │
│  │    Quality: Same skill content, just not all loaded at once        │   │
│  │    Status: IMPLEMENTED (FR-013, FR-014, FR-015, FR-016)            │   │
│  │                                                                     │   │
│  │ ✓ 4. Governance verdict caching                                    │   │
│  │    → Cache approval verdicts, invalidate on file modification      │   │
│  │    Quality: Same governance outcomes, cached for reuse             │   │
│  │    Status: IMPLEMENTED (FR-009, FR-010, FR-011, FR-012)            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  MEDIUM IMPACT (Build = 13K):                                   FUTURE     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │   5. Architect checkpoints reload full spec.md each time           │   │
│  │    → Cache spec metadata, full reload only if spec changed         │   │
│  │    Quality: Architect still validates against spec, just cached    │   │
│  │    Status: PENDING (future optimization)                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  LOWER IMPACT (Discover + Deliver = 21.5K):                     FUTURE     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │   6. Discovery research reads full doc content                     │   │
│  │    → Store findings in research.md, reference summary later        │   │
│  │    Quality: Research still thorough, results cached for reuse      │   │
│  │    Status: PENDING (future optimization)                           │   │
│  │                                                                     │   │
│  │   7. Delivery retrospective reloads completed artifacts            │   │
│  │    → Use run-state metadata instead of re-reading files            │   │
│  │    Quality: Same validation, data already captured in state        │   │
│  │    Status: PENDING (future optimization)                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Success Criteria

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SUCCESS METRICS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1: Measure (COMPLETE - Features 032, 034, 036, 038, 042)             │
│  ├── [✓] Budget tracking in all stages                                     │
│  ├── [✓] Performance registry with historical data                         │
│  └── [✓] Per-stage cost visibility                                         │
│                                                                             │
│  PHASE 2: Analyze (COMPLETE - Feature 047 PRD)                              │
│  ├── [✓] Identify top 3 context consumers (Define, Plan, Build)            │
│  ├── [✓] Profile tool call patterns per stage                              │
│  └── [✓] Map skill dependencies and redundant loads                        │
│                                                                             │
│  PHASE 3: Optimize (IN PROGRESS - Feature 047)                              │
│  ├── [●] Reduce Define stage from 20K → 12K (implemented, validating)      │
│  ├── [●] Reduce Plan stage from 20K → 15K (implemented, validating)        │
│  ├── [●] Total lifecycle < 60K tokens (target, pending validation)         │
│  └── [ ] Single-session completion rate > 90%                              │
│                                                                             │
│  PHASE 4: Validate (PENDING)                                                │
│  ├── [ ] 10 consecutive features complete in one session                   │
│  ├── [ ] Auto-pause triggers < 10% of runs                                 │
│  └── [ ] Zero "prompt too long" errors                                     │
│                                                                             │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                             │
│  FEATURE 047 SUCCESS CRITERIA (Per Spec)                                    │
│  ├── SC-001: Define stage ≤12K tokens (40% reduction)                      │
│  ├── SC-002: Plan stage ≤15K tokens (25% reduction)                        │
│  ├── SC-003: Full lifecycle <60K tokens (20% reduction)                    │
│  ├── SC-004: All Triad sign-offs present on tasks.md                       │
│  ├── SC-005: Post-delivery validation passes                               │
│  └── SC-006: Single-session completion rate 0% → 80%+                      │
│                                                                             │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                             │
│  QUALITY GATES (Must Pass At Every Phase)                                   │
│  ├── [✓] All Triad sign-offs still required                                │
│  ├── [✓] Research phase produces actionable findings                       │
│  ├── [✓] Specs include all acceptance criteria and edge cases              │
│  ├── [✓] Architecture review catches feasibility issues                    │
│  ├── [✓] Post-delivery validation passes all tests                         │
│  └── [✓] No regression in output quality vs pre-optimization               │
│                                                                             │
│  If ANY quality gate fails after optimization → REVERT the optimization    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Feature 047 Validation Status

Feature 047 implemented the high-impact optimizations. Validation completed with Feature 049:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FEATURE 047 VALIDATION CHECKLIST                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  IMPLEMENTATION STATUS:                                        ✓ COMPLETE  │
│  ├── [✓] Lazy governance loading (FR-001 to FR-004)                        │
│  ├── [✓] Serialized Triad reviews (FR-005 to FR-008)                       │
│  ├── [✓] Governance verdict caching (FR-009 to FR-012)                     │
│  └── [✓] Substage context unloading (FR-013 to FR-016)                     │
│                                                                             │
│  POST-DELIVERY VALIDATION (Feature 049):                 ⚠️ PARTIAL SUCCESS │
│  ├── [✓] Run /aod.run with simple feature idea                             │
│  ├── [⚠] Capture Define stage tokens (target: ≤12K)    → No data (gaps)   │
│  ├── [✗] Capture Plan stage tokens (target: ≤15K)      → 20K actual       │
│  ├── [✓] Capture total lifecycle tokens (target: <60K) → 66% utilization  │
│  ├── [✓] Verify all 5 stages complete without auto-pause                   │
│  ├── [✓] Verify all Triad sign-offs present on tasks.md                    │
│  └── [✓] Update performance-registry.json with measured actuals            │
│                                                                             │
│  VALIDATION REPORT:                                                         │
│  specs/049-simple-logging-utility/POST-VALIDATION-REPORT.md                 │
│                                                                             │
│  KEY FINDINGS:                                                              │
│  • Single-session completion: ✅ ACHIEVED (primary goal)                    │
│  • Discover stage: 2K actual vs 10K target (80% under)                     │
│  • Plan stage: 20K actual vs 15K target (33% over — needs tuning)          │
│  • Overall utilization: 66% (under 80% threshold)                          │
│  • Tracking gaps: Define/Build/Deliver post-actuals not captured           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Next Steps**:
1. Fix budget tracking instrumentation to capture all stage post-actuals
2. Run 2-3 additional features to validate consistency
3. Adjust Plan stage target if 15K proves unrealistic

---

### The Auto-Pause is a Safety Net, Not the Goal

```
                    CURRENT STATE                         TARGET STATE

     Session 1          Session 2              Single Session
    ┌─────────┐        ┌─────────┐            ┌─────────────────────────────┐
    │Discover │        │  Build  │            │ Discover → Define → Plan → │
    │ Define  │  ──▶   │ Deliver │     ══▶    │ Build → Deliver             │
    │  Plan   │        │         │            │                             │
    │ [PAUSE] │        │ [DONE]  │            │ [DONE in one go]            │
    └─────────┘        └─────────┘            └─────────────────────────────┘

    Auto-pause as                              Auto-pause as
    NORMAL FLOW                                RARE EXCEPTION
    (multi-session)                            (safety net only)
```

---

## Related Documentation

- [AOD Lifecycle Guide](AOD_LIFECYCLE.md) - Full lifecycle documentation
- [Run-State Functions](../../.aod/scripts/bash/run-state.sh) - Budget tracking API
- [Performance Registry](../../.aod/scripts/bash/performance-registry.sh) - Calibration API
- [ADR-003](../architecture/02_ADRs/ADR-003-heuristic-token-estimation.md) - Token estimation decision

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-14 | **Feature 054**: Added parallel execution budget hardening — multiplier-based scaling (1.0x/1.5x/3.0x) for concurrent agents + circuit-breaker pattern for churn detection (3+ consecutive identical failures) |
| 2026-02-13 | **Bug fix**: Fixed jq scoping bug in `aod_registry_recalculate()` — learning loop now works; updated baselines with actual learned values (usable_budget: 76K, define: 37.5K, plan: 23.7K) |
| 2026-02-13 | Feature 049 post-validation: Single-session completion achieved (66% utilization); Plan stage 33% over target; tracking gaps identified |
| 2026-02-13 | Added Feature 047 (Define/Plan optimization) to suite; updated diagrams, baselines, and success criteria |
| 2026-02-12 | Initial documentation (Features 032, 034, 036, 038, 042) |
