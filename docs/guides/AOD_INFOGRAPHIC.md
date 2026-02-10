# AOD Lifecycle Infographic

**Version**: 2.0.0

**Related**:
- [AOD Quickstart](AOD_QUICKSTART.md) -- Quick onboarding guide
- [AOD Lifecycle Guide](AOD_LIFECYCLE_GUIDE.md) -- Stage-by-stage deep reference
- [SDLC Triad Reference](../AOD_TRIAD.md) -- Governance layer documentation

---

```
+==============================================================================================+
||              AOD: AGENTIC ORIENTED DEVELOPMENT LIFECYCLE                                   ||
||                        End-to-End Feature Lifecycle                                         ||
+==============================================================================================+

  TRIAD GOVERNANCE LAYER (configurable — Light / Standard / Full)
  +---------------------------------------------------------------------------+
  |  [PM]  What & Why: Scope & requirements                                   |
  |  [Architect]  How: Technical decisions                                     |
  |  [Team-Lead]  When & Who: Timeline & resources                            |
  +---------------------------------------------------------------------------+

================================================================================================
  STAGE 1: DISCOVER                                              Command: /aod.discover
================================================================================================

  /aod.discover <idea>
       |
       v
  +-----------+      +--------------+      +------------------+      +------------------+
  |  Capture  | ---> | Score (ICE)  | ---> | Evidence         | ---> | PM Validation    |
  |  Idea     |      |              |      | Prompt           |      | (tier-dependent) |
  +-----------+      +--------------+      +------------------+      +------------------+
       |                    |                      |                         |
       v                    v                      v                         v
   GitHub Issue        ICE Dimensions         Evidence Capture         PM Decision
   stage:discover      +-----------+           +-----------------+
                       | Impact  1-10 |        | Score < 12      |---> Auto-deferred
                       | Confidence 1-10 |     | Score >= 12     |---> Proceed
                       | Effort  1-10 |        | Score 25+       |---> P0 Fast-track
                       +-----------+           +-----------------+

================================================================================================
  STAGE 2: DEFINE                                                Command: /aod.define
================================================================================================

  /aod.define <topic>
  +-----------------------------------------------------------------------+
  |  PM drafts PRD --> Architect + Team-Lead review --> PM finalizes       |
  |  Output: docs/product/02_PRD/{NNN}-{topic}-{date}.md                  |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Gate: [PM] [Architect] [Team-Lead] TRIPLE SIGN-OFF              |
       +-----------------------------------------------------------------+
                                     |
                                     v

================================================================================================
  STAGE 3: PLAN                                                  Command: /aod.plan
================================================================================================

  /aod.plan (router — auto-detects sub-step)

  SUB-STEP 1: Specification                 /aod.spec (via /aod.plan)
  +-----------------------------------------------------------------------+
  |  Research (KB + Codebase + Architecture + Web) --> Generate spec       |
  |  Output: .aod/spec.md                                                 |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Gate: [PM] PM SIGN-OFF                                          |
       +-----------------------------------------------------------------+
                                     |
                                     v
  SUB-STEP 2: Architecture Plan             /aod.project-plan (via /aod.plan)
  +-----------------------------------------------------------------------+
  |  Architecture decisions, API contracts, data models                    |
  |  Output: .aod/plan.md                                                 |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Gate: [PM] [Architect] DUAL SIGN-OFF                            |
       +-----------------------------------------------------------------+
                                     |
                                     v
  SUB-STEP 3: Task Breakdown               /aod.tasks (via /aod.plan)
  +-----------------------------------------------------------------------+
  |  Task breakdown, agent assignments, parallel execution waves          |
  |  Output: .aod/tasks.md + agent-assignments.md                        |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Gate: [PM] [Architect] [Team-Lead] TRIPLE SIGN-OFF              |
       +-----------------------------------------------------------------+
                                     |
                                     v

================================================================================================
  STAGE 4: BUILD                                                 Command: /aod.build
================================================================================================

  /aod.build
  +-----------------------------------------------------------------------+
  |  Wave 1: [Agent] [Agent] [Agent]   (parallel)                        |
  |       +----- Architect checkpoint -----+                              |
  |  Wave 2: [Agent] [Agent]              (parallel)                      |
  |       +----- Architect checkpoint -----+                              |
  |  Wave 3: [Agent]                       (sequential)                   |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Gate: [Architect] checkpoints at wave boundaries                |
       +-----------------------------------------------------------------+
                                     |
                                     v

================================================================================================
  STAGE 5: DELIVER                                               Command: /aod.deliver
================================================================================================

  /aod.deliver
  +-----------------------------------------------------------------------+
  |  1. Definition of Done validation                                     |
  |  2. Retrospective: metrics, surprises, next ideas                     |
  |  3. KB entry from lessons learned                                     |
  |  4. New ideas --> GitHub Issues (stage:discover) --> FEEDBACK LOOP     |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Gate: DoD check (all tiers)                                     |
       +-----------------------------------------------------------------+

================================================================================================
  ARTIFACT TRAIL
================================================================================================

  GitHub Issue --> PRD --> spec.md --> plan.md --> tasks.md --> CODE --> Retrospective
     Discover     Define    Plan       Plan       Plan       Build      Deliver
```
