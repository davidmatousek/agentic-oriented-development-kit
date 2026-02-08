# PDL + Triad Infographic

**Version**: 1.0.0

**Related**:
- [PDL + Triad Quickstart](PDL_TRIAD_QUICKSTART.md) -- Full onboarding guide
- [PDL + Triad Lifecycle](PDL_TRIAD_LIFECYCLE.md) -- Stage-by-stage deep reference
- [SDLC Triad Reference](../AOD_TRIAD.md) -- Comprehensive Triad documentation

---

```
+==============================================================================================+
||              PDL + TRIAD: SPEC-DRIVEN DEVELOPMENT WITH GOVERNANCE                          ||
||                            End-to-End Feature Lifecycle                                     ||
+==============================================================================================+

  TRIAD ROLES
  +---------------------------------------------------------------------------+
  |  [PM]  What & Why: Scope & requirements                                   |
  |  [Architect]  How: Technical decisions                                     |
  |  [Team-Lead]  When & Who: Timeline & resources                            |
  +---------------------------------------------------------------------------+

================================================================================================
  PRODUCT DISCOVERY LIFECYCLE (PDL)                           Commands: /pdl.run  /pdl.idea
================================================================================================

  /pdl.run <idea>
       |
       v
  +-----------+      +--------------+      +------------------+      +------------------+
  |  Capture  | ---> | Score (ICE)  | ---> | Validate         | ---> | Product Backlog  |
  |  Idea     |      |              |      | (PM Gate)        |      |                  |
  +-----------+      +--------------+      +------------------+      +------------------+
       |                    |                      |                         |
       v                    v                      v                         v
   01_IDEAS.md        ICE Dimensions          PM Decision            02_USER_STORIES.md
                      +-----------+           +-----------------+
                      | Impact  1-10 |        | Score < 12      |---> Auto-deferred
                      | Confidence 1-10 |     | Score >= 12     |---> Proceed to Triad
                      | Effort  1-10 |        | Score 25+       |---> P0 Fast-track
                      +-----------+           +-----------------+

================================================================================================
  ========================= HANDOFF: Ready for PRD =============================
================================================================================================

  TRIAD GOVERNANCE WORKFLOW                                   Commands: /triad.*
================================================================================================

  PHASE 1: PRD                               /triad.prd <topic>
  +-----------------------------------------------------------------------+
  |  PM drafts --> Architect + Team-Lead review --> PM finalizes           |
  |  Output: docs/product/02_PRD/{NNN}-{topic}-{date}.md                  |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Sign-off: [PM] [Architect] [Team-Lead] TRIPLE SIGN-OFF         |
       +-----------------------------------------------------------------+
                                     |
                                     v
  PHASE 2: Specify                           /triad.specify
  +-----------------------------------------------------------------------+
  |  Research (KB + Codebase + Architecture + Web) --> Generate spec       |
  |  Output: specs/{NNN}-feature/spec.md                                  |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Sign-off: [PM] PM SIGN-OFF                                     |
       +-----------------------------------------------------------------+
                                     |
                                     v
  PHASE 3: Plan                              /triad.plan
  +-----------------------------------------------------------------------+
  |  Architecture decisions, API contracts, data models                    |
  |  Output: specs/{NNN}-feature/plan.md                                  |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Sign-off: [PM] [Architect] DUAL SIGN-OFF                       |
       +-----------------------------------------------------------------+
                                     |
                                     v
  PHASE 4: Tasks                             /triad.tasks
  +-----------------------------------------------------------------------+
  |  Task breakdown, agent assignments, parallel execution waves          |
  |  Output: specs/{NNN}-feature/tasks.md + agent-assignments.md          |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Sign-off: [PM] [Architect] [Team-Lead] TRIPLE SIGN-OFF         |
       +-----------------------------------------------------------------+
                                     |
                                     v
  PHASE 5: Implement                         /triad.implement
  +-----------------------------------------------------------------------+
  |  Wave 1: [Agent] [Agent] [Agent]   (parallel)                        |
  |       +----- Architect checkpoint -----+                              |
  |  Wave 2: [Agent] [Agent]              (parallel)                      |
  |       +----- Architect checkpoint -----+                              |
  |  Wave 3: [Agent]                       (sequential)                   |
  +-----------------------------------------------------------------------+
       +-----------------------------------------------------------------+
       | Sign-off: [Architect] checkpoints at wave boundaries            |
       +-----------------------------------------------------------------+
                                     |
                                     v
  PHASE 6: Review & Deploy                   /triad.close-feature
  +-----------------------------------------------------------------------+
  |  Parallel: [Code-Reviewer] [Security-Analyst] [Architect]             |
  |       +----- Definition of Done check -----+                          |
  |  Deploy: [DevOps] --> staging --> production                          |
  +-----------------------------------------------------------------------+

================================================================================================
  ARTIFACT TRAIL
================================================================================================

  IDEAS.md --> USER_STORIES.md --> PRD.md --> spec.md --> plan.md --> tasks.md --> CODE
     PDL          PDL              Triad      Triad       Triad       Triad      Triad
```
