# Stack Pack Consumer Test Guide — SwiftUI + CloudKit

**Purpose**: Validate the full AOD Kit consumer experience — from `git clone` to a working application — using the `swiftui-cloudkit` stack pack.

**What you're building**: A simple iPhone app ("IdeaSnap") that lets creators capture ideas in one tap, then emails the idea to themselves. Replaces the painful workflow of opening Mail, typing your own email address, composing a subject, and eventually losing the idea in inbox noise.

**Key constraints**:
- Text capture only (voice/image channels are future features — good AOD lifecycle test)
- Uses iOS `MFMailComposeViewController` for email — no external services
- Offline-first via SwiftData + CloudKit (ideas persist locally, sync across devices)
- App Store publishable quality (privacy policy, review guidelines) even if not published

**Time estimate**: ~30 minutes (target for SC-001)

---

## Prerequisites

- Claude Code installed (`claude` CLI)
- Xcode 26+ installed (with iOS simulator)
- Git installed
- GitHub CLI (`gh`) installed and authenticated
- A GitHub account with repo creation permissions

---

## Phase 1: Clone & Initialize

Navigate to your projects directory (e.g., `~/Projects/` or `~/code/`) — the clone command will create a new subfolder here:

```bash
# Clone the public template
git clone https://github.com/davidmatousek/agentic-oriented-development-kit.git idea-snap
cd idea-snap

# Run interactive setup
make init
```

**When prompted, enter:**

| Prompt | Value |
|--------|-------|
| Project Name | `idea-snap` |
| Description | `iPhone app for creators to capture ideas quickly and email them to themselves` |
| GitHub Org | `davidmatousek` |
| GitHub Repo | `idea-snap` |
| AI Agent | `1` (Claude Code) |
| Tech Stack | `2` (SwiftUI + CloudKit) |

> **Note**: Selecting a stack pack auto-fills all technology defaults (database, auth, cloud provider, etc.) from its `defaults.env`. No additional prompts needed. The "Other" path prompts for database and cloud provider only.

```bash
# Verify setup
make check
```

**Expected output:**
- All checks pass (green checkmarks)
- 2 stack packs available
- No pack active

### Post-Init Verification

Confirm that `make init` replaced all template placeholders:

```bash
# Should return NO results — all placeholders replaced
grep -rn '{{' .aod/memory/constitution.md
```

> **Note**: When a stack pack is selected during init, its `defaults.env` automatically fills `{{TECH_STACK_DATABASE}}`, `{{TECH_STACK_VECTOR}}`, `{{TECH_STACK_AUTH}}`, and `{{RATIFICATION_DATE}}`. No manual editing should be required.

---

## Phase 2: Activate Stack Pack

Open Claude Code in your project directory:

```bash
# CLI
claude

# Or open the project folder in VS Code and use the Claude Code extension
```

Run these commands inside Claude Code:

```
# List available packs — verify both show up
/aod.stack list

# Activate the SwiftUI + CloudKit pack
/aod.stack use swiftui-cloudkit

# Scaffold the project structure
/aod.stack scaffold
```

### Verification Checklist

After activation:
- [ ] `.aod/stack-active.json` exists with `"pack": "swiftui-cloudkit"`
- [ ] `.claude/rules/stack/` contains `conventions.md`, `security.md`, `persona-loader.md`
- [ ] Activation summary shows loaded rules and available persona supplements

After scaffold:
- [ ] Xcode project structure exists (`IdeaSnap/App/`, `IdeaSnap/Views/`, etc.)
- [ ] `IdeaSnap/Models/` directory exists for SwiftData models
- [ ] `IdeaSnap/ViewModels/` directory exists
- [ ] `IdeaSnap/Services/` directory exists
- [ ] `IdeaSnap.entitlements` exists (iCloud capability)
- [ ] `IdeaSnapTests/` and `IdeaSnapUITests/` targets exist

---

## Phase 3: Review Product Vision

Review the seeded product vision that `make init` generated from your project description:

```bash
cat docs/product/01_Product_Vision/product-vision.md
```

You should see your project description as the mission statement, with `[To be refined]` markers for the remaining sections. **Don't fill these in manually** — `/aod.define` in the next phase will walk you through a guided Vision Refinement Workshop to populate them.

---

## Phase 4: AOD Lifecycle (Governance)

```bash
# Create a GitHub repo (needed for issue tracking)
gh repo create davidmatousek/idea-snap --private --source=. --push
```

Run the full Triad workflow inside Claude Code:

```
# Step 1: Define the PRD
/aod.define iPhone app for creators to quickly capture ideas — single-screen text input, one-tap capture that emails the idea to yourself using iOS MFMailComposeViewController (no external email services). Pain points: current workflow of emailing yourself requires too many taps, have to type in your own email address every time, and ideas get buried in inbox noise. Offline-first with SwiftData + CloudKit sync. App Store publishable quality. Text-only capture for MVP — voice and image channels are future features.

# Step 2: Create the spec (PM sign-off required)
/aod.spec

# Step 3: Create the technical plan (PM + Architect sign-off required)
/aod.project-plan

# Step 4: Generate tasks (PM + Architect + Team-Lead sign-off required)
/aod.tasks

# Step 5: Build it
/aod.build
```

### Governance Verification

- [ ] `.aod/spec.md` contains PM sign-off block
- [ ] `.aod/plan.md` contains PM + Architect sign-off blocks
- [ ] `.aod/tasks.md` contains PM + Architect + Team-Lead sign-off blocks
- [ ] Feature branch follows `NNN-feature-name` format
- [ ] Each governance gate required approval before proceeding

---

## Phase 5: Validate Stack Pack Impact

After `/aod.build` completes, verify the stack pack conventions were enforced.

### Convention Enforcement

- [ ] All UI uses **SwiftUI** (no Storyboards, no XIBs)
- [ ] File structure follows **STACK.md convention** (`App/`, `Views/`, `ViewModels/`, `Models/`, `Services/`)
- [ ] ViewModels use **`@Observable`** (not legacy `ObservableObject` / `@Published`)
- [ ] ViewModels annotated with **`@MainActor`**
- [ ] Navigation uses **`NavigationStack`** (not deprecated `NavigationView`)
- [ ] Async code uses **`async/await`** (no completion handlers, no `DispatchQueue`)
- [ ] Dependencies managed via **Swift Package Manager** (no CocoaPods, no Carthage)

### Security Pattern Enforcement

- [ ] User email stored in **Keychain** (not `UserDefaults`)
- [ ] Input validated at **ViewModel layer** before passing to Services
- [ ] SwiftData `@Model` used for idea persistence with proper **access control**
- [ ] CloudKit container permissions scoped to **private database**
- [ ] No force unwraps (`!`) on user input or external data

### Architecture Pattern Enforcement

- [ ] **MVVM** separation — Views contain no business logic or direct data access
- [ ] **Protocol-based DI** — Services injected via protocols (enables testing with mocks)
- [ ] **Offline-first** — Ideas save to local SwiftData store, CloudKit syncs when available
- [ ] Email uses **`MFMailComposeViewController`** — no external email services added

### Anti-Pattern Absence

- [ ] No `ObservableObject` / `@Published` (legacy patterns)
- [ ] No `NavigationView` (deprecated)
- [ ] No `AnyView` type erasure
- [ ] No Storyboards or XIBs
- [ ] No `UserDefaults` for sensitive data
- [ ] No singletons — DI via `@Environment` or initializer injection
- [ ] No `any` protocol types where `some` suffices

---

## Phase 6: Deliver

Close the feature with documentation updates and cleanup:

```
# Close the feature
/aod.deliver
```

### Delivery Verification

- [ ] Definition of Done checklist passes
- [ ] Documentation updated (PRD index, changelog, etc.)
- [ ] Feature branch merged or ready for PR
- [ ] Delivery retrospective captured (surprises, lessons learned)

---

## Phase 7: Reversibility Test

```
# Remove the stack pack
/aod.stack remove
```

### Clean Removal Verification

- [ ] `.aod/stack-active.json` is deleted
- [ ] `.claude/rules/stack/` is empty or deleted
- [ ] Project files (`IdeaSnap/`, tests, etc.) are **untouched**
- [ ] Governance artifacts (`.aod/spec.md`, `plan.md`, `tasks.md`) are **untouched**
- [ ] Running `/aod.stack list` shows no active pack

---

## Phase 8 (Bonus): Cross-Session Consistency

Open a **second Claude Code session** in the same project (with the pack re-activated) and ask:

> "Add an idea history screen that shows all previously captured ideas with search and swipe-to-delete"

### Consistency Verification

- [ ] New view uses SwiftUI with `@Observable` ViewModel (same as Phase 4 output)
- [ ] Data access uses SwiftData `@Query` (same persistence layer)
- [ ] Navigation uses `NavigationStack` (same pattern)
- [ ] File naming follows the same PascalCase + suffix convention
- [ ] No contradictory patterns introduced

---

## Success Criteria Summary

| ID | Criterion | Target | Pass/Fail |
|----|-----------|--------|-----------|
| SC-001 | Cold start to `/aod.build` | < 30 minutes | |
| SC-003 | Security patterns in output | 100% (Keychain + validation + DI) | |
| SC-005 | Pack works end-to-end | Activate + scaffold + build succeeds | |
| SC-006 | Clean reversibility | Zero residual state after remove | |
| SC-007 | Context budget | < 800 lines per invocation | |
| SC-002 | Cross-session consistency | Identical patterns (bonus) | |

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| `make init` fails | Ensure Xcode and Git are installed (`xcodebuild -version`, `git --version`) |
| `/aod.stack use` says pack not found | Verify `stacks/swiftui-cloudkit/STACK.md` exists |
| Scaffold conflicts with existing files | Choose overwrite/skip per-file when prompted |
| Governance sign-off loops | Address reviewer feedback, re-submit until APPROVED |
| `gh repo create` fails | Ensure `gh auth login` completed successfully |
| `MFMailComposeViewController` unavailable in simulator | Test email flow on a physical device with Mail configured |

---

## Notes

- This test uses the **public template** repo, not the private `product-led-spec-kit`
- Text-only capture is intentional MVP scope — voice/image channels validate the AOD lifecycle for future features
- Stack pack conventions are enforced through two surfaces: rules files (passive) and `/aod.build` prompt injection (active)
- Core governance agents (PM, Architect, Team-Lead) are **not** affected by stack packs — they remain stack-agnostic
- `MFMailComposeViewController` requires a configured Mail account — it won't work on simulators without one
