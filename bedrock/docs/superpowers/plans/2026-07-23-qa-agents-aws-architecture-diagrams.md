# QA-Agents AWS Architecture Diagrams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an implementation-ready post-proposal AWS architecture package with six boundary-aware diagrams while keeping the existing proposal source stable.

**Architecture:** Create a dedicated Markdown source for the post-proposal architecture. Add a linked `After Proposal` HTML section that renders the same decisions as self-contained SVG diagrams. ETUS remains the local execution/evidence harness; AWS remains the governed control plane.

**Tech Stack:** Markdown, Mermaid flowcharts/sequences, static HTML, inline SVG, existing Bedrock documentation CSS, Node-based static checks, Chrome headless screenshot validation.

## Global Constraints

- Markdown is the source of truth; HTML is the human-readable rendering.
- Keep the new architecture package separate from the existing proposal draft sections.
- Use standard AWS service names and explicit AWS account, region, VPC, subnet, security group and endpoint labels.
- Every diagram must distinguish user machine, ETUS, AWS, third-party systems and target test environment.
- Mark MVP, Phase 2 and later capabilities in the diagrams and surrounding text.
- Use ASCII in source files except for existing file character conventions.
- Do not introduce external runtime dependencies or require an internet connection to render HTML.
- Do not modify unrelated dirty files or commit changes without explicit user instruction.

---

### Task 1: Create the architecture Markdown source

**Files:**
- Create: `bedrock/docs/qa-agents-aws-after-proposal-architecture.md`
- Reference: `bedrock/docs/qa-agents-aws-after-proposal-architecture-design.md`
- Reference: `bedrock/docs/qa-agents-aws-business-proposal-draft-report.md`

**Interfaces:**
- Consumes: approved design spec, existing proposal contracts, official AWS research links.
- Produces: the authoritative architecture decisions, AWS responsibility matrix, six Mermaid diagrams, deployment configuration notes and implementation gates.

- [ ] **Step 1: Add document metadata and scope boundary**

Include source-of-truth rules, relationship to the proposal draft and the selected production-shaped hybrid approach.

- [ ] **Step 2: Add AWS service responsibility and deployment configuration tables**

Document the account/region assumptions, VPC/private connectivity options, IAM roles, data stores, service integrations, MVP status and Phase 2 status.

- [ ] **Step 3: Add the six Mermaid diagrams**

Include deployment/network, component/container, sequence, Knowledge Base/memory lifecycle, ETUS evidence flow and security/observability/evaluation flow. Each must label ownership and MVP versus Phase 2.

- [ ] **Step 4: Add contracts, security rules, failure handling and acceptance criteria**

Name the cross-boundary fields and require explicit behavior for missing sources, unsupported claims, denied tool actions, incomplete evidence, stale memory and failed evaluation gates.

- [ ] **Step 5: Run Markdown checks**

Run:

```bash
git diff --check -- bedrock/docs/qa-agents-aws-after-proposal-architecture.md
rg -n "TBD|TODO|FIXME" bedrock/docs/qa-agents-aws-after-proposal-architecture.md
```

Expected: `git diff --check` passes and the placeholder search returns no output.

### Task 2: Add the HTML architecture group and diagrams

**Files:**
- Modify: `bedrock/docs/qa-agents-aws-business-proposal.html`
- Modify: `bedrock/docs/docs-theme.css` only if existing responsive rules cannot support the new diagrams.
- Modify: `bedrock/docs/docs-brand.css` only if existing brand tokens are insufficient.

**Interfaces:**
- Consumes: `qa-agents-aws-after-proposal-architecture.md` decisions and existing HTML diagram conventions.
- Produces: a navigable `After Proposal` architecture section with six readable, labeled SVG diagrams.

- [ ] **Step 1: Add the new document link to the After Proposal navigation group**

Link to the local Markdown source and preserve existing menu anchors.

- [ ] **Step 2: Add deployment/network SVG**

Use nested frames for User Machine, Third Party, AWS Account/Region, VPC and optional private connectivity. Label arrows as local-only, HTTPS/public, AWS service API or private VPC path.

- [ ] **Step 3: Add component/container SVG**

Map logical containers to AWS services and identify owner lanes for QA, AI, Software, Cloud and Security.

- [ ] **Step 4: Add sequence SVG**

Show the ticket-to-final-QA-note path, human approval gates and failure branches.

- [ ] **Step 5: Add Knowledge Base/memory, ETUS evidence and security/evaluation SVGs**

Show source trust, citation, memory promotion, local evidence, policy decisions, traces, audit events and release gates.

- [ ] **Step 6: Add diagram legends and MVP/Phase 2 callouts**

Make ownership and deployment phase understandable without relying on color alone.

### Task 3: Link the architecture package without changing proposal semantics

**Files:**
- Modify: `bedrock/docs/qa-agents-aws-business-proposal.html`
- Modify: `bedrock/docs/qa-agents-aws-business-proposal-draft-report.md` only if a cross-reference is needed in the existing After Proposal deliverables list.

**Interfaces:**
- Consumes: new architecture Markdown path.
- Produces: a stable cross-reference from proposal to implementation architecture.

- [ ] **Step 1: Add a concise cross-reference**

State that implementation diagrams and cloud configuration detail live in the separate architecture document.

- [ ] **Step 2: Verify no existing proposal heading or anchor changes**

Compare the existing navigation anchors and heading IDs before and after the edit.

### Task 4: Validate structure and visual rendering

**Files:**
- Test: `bedrock/docs/qa-agents-aws-after-proposal-architecture.md`
- Test: `bedrock/docs/qa-agents-aws-business-proposal.html`

**Interfaces:**
- Consumes: completed Markdown and HTML artifacts.
- Produces: passing static checks and a reviewed desktop screenshot.

- [ ] **Step 1: Validate HTML anchors and entities**

Run the existing Node check for duplicate IDs, missing local anchors and unescaped ampersands.

- [ ] **Step 2: Validate Markdown and HTML whitespace**

Run:

```bash
git diff --check -- bedrock/docs/qa-agents-aws-after-proposal-architecture.md bedrock/docs/qa-agents-aws-business-proposal.html
```

- [ ] **Step 3: Render the HTML with Chrome headless**

Capture a desktop screenshot and inspect that nested frames, labels, arrows and legends remain readable without overlap.

- [ ] **Step 4: Check responsive overflow behavior**

Verify that diagrams remain horizontally scrollable on narrow viewports and that surrounding text does not overflow its parent.

- [ ] **Step 5: Report residual risks**

Call out any AWS capability that remains conditional on account region, service availability, security approval or future implementation validation.
