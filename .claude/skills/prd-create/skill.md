---
name: prd-create
description: "Internal skill invoked by /triad.prd to generate industry-standard PRD content using proven frameworks from Google, Amazon, and Intercom. Do NOT invoke directly — use /triad.prd instead, which wraps this skill with Triad governance and sign-offs."
---

# PRD Creation Skill

## Purpose

Guide Product Managers through creating comprehensive, industry-standard Product Requirements Documents (PRDs) that serve as the foundation for superior technical specifications.

## Industry-Standard PRD Frameworks

This skill synthesizes best practices from:

### 1. **Amazon's PR/FAQ (Press Release / Frequently Asked Questions)**
- Start with the customer and work backward
- Write the press release first (forces clarity on customer value)
- Anticipate and answer tough questions upfront

### 2. **Google's PRD Template**
- Clear problem statement and goals
- User stories with acceptance criteria
- Success metrics (OKRs)
- Technical constraints and dependencies

### 3. **Intercom's Job Stories**
- When [situation], I want to [motivation], so I can [expected outcome]
- Focus on context and causality, not just user roles

### 4. **Pragmatic Institute's Requirements Framework**
- Market problems (not solutions)
- Personas and use cases
- Prioritization criteria
- Success metrics

## PRD Structure

Every PRD created by this skill follows this proven structure:

```markdown
# [Feature Name] - Product Requirements Document

**Status**: [Draft / Review / Approved]
**Created**: YYYY-MM-DD
**Author**: product-manager
**Reviewers**: [architect, team-lead, etc.]
**Phase**: [Phase 1 / Phase 2 / etc.]
**Priority**: [P0 / P1 / P2]

---

## 📋 Executive Summary

### The One-Liner
[One sentence that a 10-year-old could understand]

### Problem Statement
[What problem are we solving? Who has this problem? How painful is it?]

### Proposed Solution
[High-level approach to solving the problem]

### Success Criteria
[How we'll know we succeeded - specific, measurable metrics]

### Timeline
[Target dates for key milestones]

---

## 🎯 Strategic Alignment

### Product Vision Alignment
**Reference**: [Link to docs/product/01_Product_Vision/product-vision.md]

[How does this feature support our product vision?]

### OKR Support
**Reference**: [Link to docs/product/06_OKRs/YYYY-QN.md]

**Objective**: [Which objective does this support?]
**Key Results**:
- [KR1]: [How this feature moves the needle]
- [KR2]: [Impact on this metric]

### Roadmap Fit
**Reference**: [Link to docs/product/03_Product_Roadmap/phase-N.md]

**Phase**: [Which phase is this in?]
**Week**: [Which week of the phase?]
**Dependencies**: [What must be complete first?]

---

## 🧑‍💼 Target Users & Personas

**Reference**: [Link to docs/product/01_Product_Vision/target-users.md]

### Primary Persona: [Persona Name]

**Demographics**:
- Role: [Job title / role]
- Experience: [Technical level, domain expertise]
- Goals: [What they're trying to achieve]
- Pain Points: [Current challenges]

**Why This Matters to Them**:
[Specific value this feature delivers to this persona]

### Secondary Persona: [Persona Name]

[Repeat structure above]

---

## 📖 User Stories

### User Story Format
Using Intercom's Job Story format for better context:

**When** [situation/context],
**I want to** [motivation/action],
**So I can** [expected outcome/benefit].

### Primary User Stories

#### US-[ID]: [Story Title]
**When**: [Situation/context that triggers this need]
**I want to**: [What the user wants to do]
**So I can**: [The benefit/outcome they expect]

**Acceptance Criteria**:
- **Given** [context], **when** [action], **then** [outcome]
- **Given** [context], **when** [action], **then** [outcome]
- **Given** [context], **when** [action], **then** [outcome]

**Priority**: [P0 / P1 / P2]
**Effort**: [S / M / L / XL]

[Repeat for each user story]

---

## 🎨 User Experience Requirements

### Customer Journey Context
**Reference**: [Link to docs/product/04_Customer_Journey_Maps/]

**Journey Stage**: [Which stage of the customer journey?]
**Touchpoints**: [Where does user interact with this feature?]
**Emotions**: [How should user feel? What frustrations are we removing?]

### Key User Flows

#### Flow 1: [Flow Name]
1. User [starts at this state/page]
2. User [performs this action]
3. System [responds with this]
4. User [sees/receives this feedback]
5. User [achieves this outcome]

**Happy Path**: [Describe ideal scenario]
**Edge Cases**: [What could go wrong? How do we handle it?]

[Repeat for each major flow]

### UI/UX Considerations

**Information Architecture**:
- [How is information organized?]
- [What's the navigation structure?]

**Progressive Disclosure**:
- [What do users see first?]
- [What's revealed with interaction?]

**Error Prevention**:
- [How do we prevent mistakes?]
- [What validation happens when?]

**Feedback Patterns**:
- [How do we communicate system state?]
- [What feedback for actions?]

---

## ⚙️ Functional Requirements

### Core Capabilities

#### Requirement 1: [Capability Name]
**Description**: [What this capability does]

**Inputs**: [What data/actions are required?]
**Processing**: [What happens in the system?]
**Outputs**: [What's the result?]

**Business Rules**:
- [Rule 1]
- [Rule 2]
- [Rule 3]

**Edge Cases**:
- [Case 1]: [How we handle it]
- [Case 2]: [How we handle it]

[Repeat for each core capability]

### Data Requirements

**Data Model**:
```
Entity: [Name]
Fields:
  - [field_name]: [type] - [description]
  - [field_name]: [type] - [description]

Relationships:
  - [relationship description]
```

**Validation Rules**:
- [Field]: [Validation requirements]
- [Field]: [Validation requirements]

**Data Lifecycle**:
- **Creation**: [When/how is data created?]
- **Updates**: [When/how is data modified?]
- **Deletion**: [When/how is data removed?]
- **Retention**: [How long is data kept?]

### Integration Requirements

**External Systems**:
- [System 1]: [What data is exchanged? Protocol?]
- [System 2]: [What data is exchanged? Protocol?]

**APIs**:
- [API endpoint 1]: [Purpose, inputs, outputs]
- [API endpoint 2]: [Purpose, inputs, outputs]

**Events/Webhooks**:
- [Event 1]: [When triggered? Payload?]
- [Event 2]: [When triggered? Payload?]

---

## 🚀 Non-Functional Requirements

### Performance Requirements

**Response Time**:
- API endpoints: [< Xms for 95th percentile]
- Page load: [< Xs for initial render]
- Search queries: [< Xs for results]

**Throughput**:
- Concurrent users: [Support N simultaneous users]
- Requests per second: [Support N req/s]
- Data volume: [Handle N records/documents]

**Scalability**:
- Horizontal scaling: [Can we add more instances?]
- Vertical scaling: [Resource requirements per instance]
- Growth projection: [Expected 6-month, 12-month usage]

### Reliability Requirements

**Availability**:
- Target uptime: [99.X%]
- Acceptable downtime: [X minutes per month]
- Maintenance windows: [When? How often?]

**Error Handling**:
- Graceful degradation: [What happens when dependencies fail?]
- Retry logic: [Automatic retry? Backoff strategy?]
- User feedback: [How do we communicate errors?]

**Data Integrity**:
- ACID guarantees: [Required where?]
- Backup strategy: [How often? Retention?]
- Disaster recovery: [RTO? RPO?]

### Security Requirements

**Authentication**:
- Method: [JWT / OAuth / SAML / etc.]
- Session management: [Timeout, refresh tokens]
- Multi-factor auth: [Required? Optional?]

**Authorization**:
- Access control: [RBAC / ABAC / ACL]
- Permission model: [Who can do what?]
- Audit logging: [What actions are logged?]

**Data Protection**:
- Encryption at rest: [AES-256? Which data?]
- Encryption in transit: [TLS 1.3? All connections?]
- PII handling: [What's considered PII? How protected?]
- Compliance: [GDPR / CCPA / SOC 2 / etc.]

### Accessibility Requirements

**WCAG Compliance**: [Level A / AA / AAA]

**Screen Reader Support**: [Required? Which screen readers?]

**Keyboard Navigation**: [Full keyboard access? Shortcuts?]

**Color Contrast**: [Minimum contrast ratios]

**Internationalization**:
- Languages: [Which languages supported?]
- Localization: [Date/time formats, currency, etc.]
- Right-to-left: [RTL support needed?]

---

## 📊 Success Metrics

### Primary Metrics (Leading Indicators)

**Metric 1**: [Metric name]
- **Definition**: [How is it measured?]
- **Baseline**: [Current state]
- **Target**: [Goal state]
- **Timeline**: [When measured?]
- **Owner**: [Who tracks this?]

**Metric 2**: [Metric name]
[Repeat structure]

### Secondary Metrics (Lagging Indicators)

**Metric 1**: [Metric name]
[Repeat structure]

### User Satisfaction Metrics

**NPS (Net Promoter Score)**:
- Current: [Score]
- Target: [Score]

**CSAT (Customer Satisfaction)**:
- Current: [Score]
- Target: [Score]

**Feature Adoption**:
- DAU (Daily Active Users): [Target N users]
- WAU (Weekly Active Users): [Target N users]
- Activation rate: [X% of users try feature within Y days]

### Business Metrics

**Revenue Impact**: [How does this drive revenue?]

**Cost Savings**: [How does this reduce costs?]

**Efficiency Gains**: [How does this improve productivity?]

---

## 🔍 Scope & Boundaries

### In Scope (MVP / Phase 1)

**Must Have (P0)**:
- ✅ [Feature 1]: [Why critical?]
- ✅ [Feature 2]: [Why critical?]
- ✅ [Feature 3]: [Why critical?]

**Should Have (P1)**:
- 🎯 [Feature 1]: [Why important?]
- 🎯 [Feature 2]: [Why important?]

### Out of Scope (Future Phases)

**Could Have (P2)** - Not in MVP:
- 🔮 [Feature 1]: [Deferred to Phase 2 because...]
- 🔮 [Feature 2]: [Deferred to Phase 3 because...]

**Won't Have** - Explicitly excluded:
- ❌ [Feature 1]: [Why not doing this?]
- ❌ [Feature 2]: [Why not doing this?]

### Assumptions

- [Assumption 1 about users, technology, or environment]
- [Assumption 2]
- [Assumption 3]

**Validation Needed**:
- [ ] [Assumption 1]: [How will we validate?]
- [ ] [Assumption 2]: [How will we validate?]

### Constraints

**Technical Constraints**:
- [Constraint 1]: [Why? Impact?]
- [Constraint 2]: [Why? Impact?]

**Business Constraints**:
- Budget: [Any cost limits?]
- Timeline: [Hard deadlines?]
- Resources: [Team size? Availability?]

**External Dependencies**:
- [Dependency 1]: [What do we need from whom? When?]
- [Dependency 2]: [What do we need from whom? When?]

---

## 🛣️ Timeline & Milestones

### Phase Breakdown

**Phase 1: [Name]** (Week X-Y)
- Week X: [Milestone]
- Week Y: [Milestone]
- **Deliverable**: [What's complete?]

**Phase 2: [Name]** (Week X-Y)
[Repeat structure]

### Key Milestones

| Milestone | Target Date | Owner | Status |
|-----------|-------------|-------|--------|
| PRD Approval | YYYY-MM-DD | product-manager | 🟡 In Review |
| Spec Complete | YYYY-MM-DD | architect | 📋 Pending |
| Design Mockups | YYYY-MM-DD | designer | 📋 Pending |
| Dev Complete | YYYY-MM-DD | team-lead | 📋 Pending |
| Testing Complete | YYYY-MM-DD | tester | 📋 Pending |
| Production Deploy | YYYY-MM-DD | devops | 📋 Pending |
| User Validation | YYYY-MM-DD | product-manager | 📋 Pending |

Legend: ✅ Complete | 🟢 On Track | 🟡 In Review | 📋 Pending | 🔴 Blocked

---

## ⚠️ Risks & Dependencies

### Technical Risks

**Risk 1**: [Risk description]
- **Likelihood**: [High / Medium / Low]
- **Impact**: [High / Medium / Low]
- **Mitigation**: [How we reduce risk]
- **Contingency**: [What if it happens?]

**Risk 2**: [Risk description]
[Repeat structure]

### Business Risks

**Risk 1**: [Risk description]
[Repeat structure]

### Dependencies

**Internal Dependencies**:
- **[Team/Feature]**: [What do we need? When? Who owns?]
- **[Team/Feature]**: [What do we need? When? Who owns?]

**External Dependencies**:
- **[Vendor/Partner]**: [What do we need? When? Who owns?]
- **[Vendor/Partner]**: [What do we need? When? Who owns?]

**Dependency Graph**:
```
[This Feature]
  ├─ Depends on: [Feature/Service 1]
  ├─ Depends on: [Feature/Service 2]
  └─ Blocks: [Feature/Service 3]
```

---

## ❓ Open Questions

**Format**: [Question] - [Owner] - [Due Date] - [Status]

### Product Questions
- [ ] [Question about user behavior or requirements] - [Owner] - [Due] - [Researching / Answered]
- [ ] [Question about scope or priorities] - [Owner] - [Due] - [Status]

### Technical Questions
- [ ] [Question about architecture or implementation] - [Owner] - [Due] - [Status]
- [ ] [Question about performance or scalability] - [Owner] - [Due] - [Status]

### Design Questions
- [ ] [Question about UX or visual design] - [Owner] - [Due] - [Status]

### Business Questions
- [ ] [Question about business model or pricing] - [Owner] - [Due] - [Status]

---

## 📚 References

### Product Documentation
- Product Vision: [Link to docs/product/01_Product_Vision/]
- OKRs: [Link to docs/product/06_OKRs/]
- Roadmap: [Link to docs/product/03_Product_Roadmap/]
- User Stories: [Link to docs/product/05_User_Stories/]
- Customer Journeys: [Link to docs/product/04_Customer_Journey_Maps/]

### Technical Documentation
- Constitution: [Link to .aod/memory/constitution.md]
- Architecture: [Link to relevant architecture docs]
- API Docs: [Link to API documentation]

### Research & Analysis
- User Research: [Link to research findings]
- Competitive Analysis: [Link to competitive research]
- Market Analysis: [Link to market research]

### External Resources
- [Resource 1]: [Link]
- [Resource 2]: [Link]

---

## ✅ Approval & Sign-Off

### PRD Review Checklist

**Product Manager** (product-manager):
- [ ] Problem statement is clear and user-focused
- [ ] User stories have measurable acceptance criteria
- [ ] Success metrics are defined and measurable
- [ ] Scope is realistic for timeline
- [ ] Risks and dependencies identified
- [ ] Aligns with product vision and OKRs

**Architect**:
- [ ] Technical requirements are clear
- [ ] Non-functional requirements are realistic
- [ ] Dependencies are accurate
- [ ] Technical risks are identified
- [ ] Architecture approach is sound

**Engineering Lead** (team-lead):
- [ ] Requirements are implementable
- [ ] Effort estimates are reasonable
- [ ] Team capacity is available
- [ ] Timeline is realistic

**Design** (if applicable):
- [ ] UX requirements are clear
- [ ] User flows are complete
- [ ] Accessibility requirements defined

### Approval Status

| Role | Name | Status | Date | Comments |
|------|------|--------|------|----------|
| Product Manager | product-manager | 📋 Pending | - | - |
| Architect | architect | 📋 Pending | - | - |
| Engineering Lead | team-lead | 📋 Pending | - | - |

Legend: ✅ Approved | 🟡 Approved with Comments | ❌ Rejected | 📋 Pending

---

## 📝 Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | YYYY-MM-DD | product-manager | Initial PRD |

---

## Appendix A: User Research Findings

[Include relevant user research, interviews, surveys, analytics]

## Appendix B: Technical Spikes

[Include results from technical feasibility investigations]

## Appendix C: Design Explorations

[Include early design mockups, wireframes, prototypes]
```

---

## PRD Creation Workflow

### Step 1: Gather Context

Before starting, collect:

1. **Product Context**:
   - Read `docs/product/01_Product_Vision/product-vision.md`
   - Read `docs/product/01_Product_Vision/target-users.md`
   - Read relevant `docs/product/06_OKRs/` for current quarter

2. **Feature Context**:
   - What problem are we solving?
   - Who requested this? (User feedback, leadership, competitive pressure?)
   - What's the urgency/priority?

3. **Technical Context**:
   - Read `.aod/memory/constitution.md` for constraints
   - **Read `docs/architecture/README.md` for current architecture state** (what exists vs what's needed)
   - **Read `docs/architecture/04_deployment_environments/production.md` and `staging.md`** (verify infrastructure status)
   - **Read `docs/product/STATUS.md` for feature completion status** (identify recently completed features)
   - **Search git log for recent feature completions** (e.g., "Feature 003 complete", "deployed", "APPROVED")
   - Search knowledge base for similar features
   - **Identify dependencies AND verify which are already satisfied vs pending**

4. **PDL Source Check** (optional — if PDL is in use):
   - Check if `docs/product/_backlog/02_USER_STORIES.md` exists
   - If it exists and contains entries with status "Ready for PRD", present them to the user
   - If user selects a backlog item, populate `source.idea_id` and `source.story_id` in PRD frontmatter:
     ```yaml
     source:           # Optional — populated when PRD originates from PDL
       idea_id: null   # IDEA-NNN reference
       story_id: null  # US-NNN reference
     ```
   - If user starts fresh (no backlog item selected), leave source fields as null

### Step 2: Draft PRD Sections

Work through the PRD structure systematically:

```markdown
## Recommended Order:
1. Executive Summary (write last, but placeholder early)
2. Strategic Alignment (ensures feature fits vision)
3. Target Users & Personas (who benefits?)
4. User Stories (what do they need?)
5. User Experience Requirements (how do they use it?)
6. Functional Requirements (what does it do?)
7. Non-Functional Requirements (how well does it do it?)
8. Success Metrics (how do we measure success?)
9. Scope & Boundaries (what's in/out?)
10. Timeline & Milestones (when does it happen?)
11. Risks & Dependencies (what could go wrong?)
12. Open Questions (what don't we know?)
13. References (supporting docs)
14. Executive Summary (revisit with full context)
```

### Step 3: Validate Completeness

Use this checklist:

```markdown
## PRD Quality Checklist

### Clarity
- [ ] Problem statement is clear to non-technical stakeholders
- [ ] User stories use plain language, not jargon
- [ ] Success metrics are specific and measurable
- [ ] Scope boundaries are explicit (in scope vs out of scope)

### Completeness
- [ ] All major user flows documented
- [ ] Edge cases identified and handled
- [ ] Non-functional requirements specified
- [ ] Dependencies and risks identified
- [ ] Open questions captured

### Alignment
- [ ] Aligns with product vision
- [ ] Supports current quarter OKRs
- [ ] Fits roadmap timeline
- [ ] Serves target user personas
- [ ] References customer journey maps

### Feasibility
- [ ] Technical requirements are realistic
- [ ] Timeline accounts for dependencies
- [ ] Team capacity is available
- [ ] Risks have mitigation plans
- [ ] Assumptions are documented and validated

### Traceability
- [ ] Links to product vision
- [ ] Links to OKRs
- [ ] Links to roadmap
- [ ] Links to user stories
- [ ] Links to constitution for constraints
```

### Step 4: Get Feedback

**Review Process**:
1. **Self-review**: Walk through PRD as if you're seeing it fresh
2. **Stakeholder review**: Share with architect, team-lead for technical feasibility
3. **User validation**: If possible, validate assumptions with actual users
4. **Revision**: Incorporate feedback, answer open questions
5. **Approval**: Get sign-offs from required stakeholders

### Step 5: Handoff to Spec Creation

Once PRD is approved:

1. **Create spec.md** using `/triad.specify`
2. **Provide PRD as input**: Reference PRD location in spec creation
3. **Validate alignment**: Ensure spec.md reflects PRD requirements
4. **Sign-off on spec**: Product Manager approves spec.md before implementation

---

## Integration with Triad Workflow

### PRD → Spec Mapping

| PRD Section | Maps to Spec Section |
|-------------|----------------------|
| Problem Statement | Background / Motivation |
| User Stories | User Stories / Use Cases |
| Functional Requirements | Functional Requirements |
| Non-Functional Requirements | Non-Functional Requirements |
| Success Metrics | Success Criteria |
| Scope & Boundaries | Scope / Out of Scope |
| Timeline | Implementation Plan |
| Risks & Dependencies | Risks / Constraints |

### Spec → Plan Validation

Product Manager validates plan.md ensures:
- Timeline aligns with PRD milestones
- Technical approach serves user stories
- Architecture supports non-functional requirements
- Tasks prioritization reflects user value

### Plan → Tasks Validation

Product Manager validates tasks.md ensures:
- Task prioritization matches product priorities
- MVP scope matches PRD in-scope items
- Task descriptions reference user value
- Dependencies align with PRD dependencies

---

## Common PRD Pitfalls

### ❌ Don't Do This

**Vague Problem Statements**:
- Bad: "Users have trouble with authentication"
- Good: "Users abandon sign-up flow at 40% rate due to password complexity requirements that don't match their mental model"

**Solution-Focused User Stories**:
- Bad: "As a user, I want a JWT refresh mechanism"
- Good: "When my session is active and my auth token is about to expire, I want to stay logged in automatically, so I don't lose my work mid-task"

**Unmeasurable Success Metrics**:
- Bad: "Users will be happier"
- Good: "NPS increases from 32 to 45, CSAT for auth flow increases from 6.2 to 8.5"

**Missing Acceptance Criteria**:
- Bad: "User can search"
- Good: "Given 1000 documents indexed, when user searches 'postgres connection', then results return in <2s with relevant docs ranked first"

### ✅ Do This

**Clear, User-Focused Problem Statements**:
- Start with user pain, quantify impact, explain why now

**Context-Rich Job Stories**:
- When [situation], I want to [action], so I can [outcome]
- Focus on causality and context

**SMART Success Metrics**:
- Specific, Measurable, Achievable, Relevant, Time-bound

**Testable Acceptance Criteria**:
- Given-When-Then format for every user story

---

## Templates & Examples

### Quick-Start PRD Template

For simple features, use this minimal template:

```markdown
# [Feature] PRD - Quick Start

## Problem
[2-3 sentences: What problem? Who has it? How painful?]

## Solution
[2-3 sentences: High-level approach]

## User Stories
1. When [situation], I want to [action], so I can [outcome]
   - AC: Given [context], when [action], then [outcome]

## Success Metrics
- [Metric 1]: [Baseline → Target]
- [Metric 2]: [Baseline → Target]

## Scope
**In**: [P0 features]
**Out**: [Explicitly excluded]

## Timeline
[Start date → Launch date]

## Risks
- [Risk 1]: [Mitigation]
```

### Full PRD Example

See the PRD template structure above for comprehensive features.

---

## Research-Backed Best Practices

### Sources

1. **"Inspired" by Marty Cagan** (Silicon Valley Product Group)
   - Outcome-driven product development
   - Focus on problems, not solutions
   - Continuous discovery and validation

2. **Amazon PR/FAQ Method**
   - Customer obsession starts with working backward from press release
   - Forces clarity on customer value proposition
   - FAQ anticipates objections

3. **Google's HEART Framework** (Happiness, Engagement, Adoption, Retention, Task Success)
   - User-centered metrics
   - Leading + lagging indicators
   - Behavior change focus

4. **Intercom's Jobs-to-be-Done Framework**
   - Context and causality over demographics
   - When-I-Want-So format captures motivation
   - Better than persona-based user stories

### Key Principles

1. **Start with Why**: Problem statement before solution
2. **User-Centered**: Always frame from user perspective
3. **Measurable**: Define success quantitatively
4. **Validated**: Test assumptions, don't guess
5. **Aligned**: Connect to strategy (vision, OKRs)
6. **Realistic**: Scope to capacity and timeline
7. **Traceable**: Link to supporting docs

---

## Success Criteria for This Skill

You've used this skill successfully when:

1. **PRD is Complete**: All sections filled with specific, actionable content
2. **PRD is Clear**: Non-technical stakeholders understand the problem and value
3. **PRD is Aligned**: References product vision, OKRs, roadmap, user stories
4. **PRD is Feasible**: Technical team confirms it's buildable in timeline
5. **PRD Enables Great Specs**: `/triad.specify` produces superior spec.md from this PRD
6. **PRD Gets Approved**: Stakeholders sign off without major revisions

---

## Command Reference

```bash
# Create a new PRD (invokes this skill automatically)
/triad.prd <topic>

# Create spec from PRD
/triad.specify

# Validate PRD-spec alignment
/triad.analyze
```

---

## Related Skills

- **kb-query**: Search knowledge base for similar features or patterns
- **root-cause-analyzer**: Dig into complex requirement ambiguities
- **spec-validator**: Validate consistency between PRD and spec

---

## Documentation

All PRDs should be saved to:
```
docs/product/02_PRD/YYYY-MM-DD-feature-name.md
```

And indexed in:
```
docs/product/02_PRD/README.md
```

---

**Remember**: A great PRD makes technical specification easy. A poor PRD dooms the project from the start. Invest the time to get this right.
