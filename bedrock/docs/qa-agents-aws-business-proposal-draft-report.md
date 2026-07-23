# QA-Agents AWS Business Proposal Draft Report

Ngay cap nhat: 2026-07-23  
Trang thai: Draft report for review  
Pham vi: QA-Agents shared verification context, AWS/Bedrock/AgentCore fit, ETUS execution/evidence harness

## 1. Purpose

Tai lieu nay la ban Markdown de gui review, khong bao gom diagram. No tong hop noi dung business, product, engineering, AWS architecture va ETUS architecture thanh mot ban doc lien mach.

Nguyen tac source-of-truth:

- Markdown la source-of-truth cho noi dung.
- HTML `qa-agents-aws-business-proposal.html` chi la ban trinh bay de human doc de hon.
- Neu co thay doi ve scope, decision, architecture, roadmap hoac data contract, update Markdown truoc roi moi refresh HTML.

Tai lieu lien quan trong repo:

- [`rfc-qa-agents-ai-support.md`](rfc-qa-agents-ai-support.md): RFC source-of-truth goc.
- [`qa-agents-aws-business-proposal.html`](qa-agents-aws-business-proposal.html): HTML proposal de review nhanh.
- [`aws-ai-project-stack-map.html`](aws-ai-project-stack-map.html): visual map ve AWS AI ecosystem.
- [`aws-ai-ecosystem-stack-guide.md`](aws-ai-ecosystem-stack-guide.md): Markdown guide ve AWS AI stack.
- [`aws-bedrock-agent-ecosystem-research.md`](aws-bedrock-agent-ecosystem-research.md): research notes ve Bedrock/AgentCore ecosystem.

## 2. Executive Summary

QA-Agents khong nen duoc dinh vi la mot autonomous QA agent tu dong pass/fail thay QA. Root value cua san pham la tao **shared verification context**: mot artifact chung giup QA, Product va Engineer cung hieu ticket intent, current behavior, business rule, implementation signal, risk, verification plan va evidence truoc khi QA sign-off.

Decision hien tai:

- Primary user: **QA**.
- Context contributors: **Product** va **Engineer**.
- MVP artifact: **Ready-for-QA Verification Context Record**.
- Phase 1 AWS fit: **Amazon Bedrock + retrieval/RAG don gian + Amazon Bedrock AgentCore Runtime/Harness boundary**.
- Phase 1 authority: **draft-only**, human-reviewed, no auto-write.
- Phase 2 expansion: AgentCore Gateway, Memory, Identity, Policy, Evaluations va governed tool integrations.
- ETUS role: **execution/evidence harness hien co**; Bedrock/AgentCore role: **production control plane**.

## 3. Problem Statement

Trong delivery workflow hien tai, QA khong chi "test". QA phai tong hop context tu nhieu nguon:

- Ticket/spec de hieu intent va acceptance criteria.
- Product/business history de hieu rule, exception, decision cu.
- Engineer/PR/build/codebase signals de hieu implementation shape va impact surface.
- Manual/automation/CI evidence de verify.
- Final note/source-of-truth de luu lai release memory.

Root problem la **context fragmentation**. Ticket khong bao gio la toan bo su that. Ticket la intent artifact; codebase la implementation artifact; test case la coverage artifact; evidence la verification artifact; source-of-truth document la memory artifact. QA-Agents can noi cac artifact nay lai thanh mot shared verification context co trace.

Problem statement de dung cho review:

> Khi QA nhan mot ticket, QA khong the tin rang ticket da phan anh day du current product behavior, business rules, codebase coverage va impact surface. De verify dung, QA phai tu tong hop context tu ticket, nguoi, docs cu, PR/code, existing tests va evidence. Viec tong hop nay cham, khong nhat quan, phu thuoc vao memory ca nhan, va de dan den verify sai scope hoac miss regression.

## 4. Product Framing

### 4.1 Product Opportunity

QA-Agents co the tro thanh QA workbench: noi QA bat dau tu ticket, duoc AI ho tro hieu scope, de xuat test, verify co evidence, va ket thuc bang document co the tin duoc.

Business outcomes:

- Tang toc time-to-understand ticket.
- Giam verify sai scope.
- Tang shared-context alignment giua QA, Product va Engineer.
- Phat hien ambiguity/mismatch som hon.
- Tang chat luong test coverage va edge-case thinking.
- Giam miss regression do impact analysis yeu.
- Tang evidence completeness va release confidence.
- Tao final verification memory dung lai cho regression sau nay.

### 4.2 Personas

| Persona | Vai tro | Pain hien tai | QA-Agents nen ho tro | QA-Agents khong nen lam |
|---|---|---|---|---|
| QA Engineer | Primary user, verify ticket/build | Context phan tan, ticket thieu current behavior, evidence viet thu cong | Ticket brief, current-state brief, test matrix, evidence checklist, final note draft | Tu pass/fail thay QA |
| QA Lead | Quan ly quality/risk | Kho nhin ticket nao risk cao, coverage/evidence ra sao | Risk summary, blocked reason, evidence quality, trend | Tao metric ao khong co evidence |
| Product/BA | Context contributor | Ticket co the thieu business rule/current behavior | Confirm expected behavior, rule, priority, release risk | Bi AI thay product sign-off |
| Engineer/Tech Lead | Context contributor | QA feedback thieu technical context hoac den muon | Confirm implementation shape, impacted layers, PR/code/test/CI signal | Bi AI chot architecture/implementation |
| Platform/Security owner | Control plane owner | Can policy, audit, data boundary | Guardrails, auth, trace, retention, no-write policy | De agent tu do goi/write third-party tools |

## 5. Scope Ownership

QA-Agents phai tach ro business/product scope va engineer/technology scope. Neu khong tach, AI de tron expected behavior voi implementation guess va tao false confidence.

| Scope group | Owner chinh | QA-Agents duoc lam | QA-Agents khong duoc tu quyet |
|---|---|---|---|
| Business/Product | Product owner, Business owner, BA | Tong hop intent, business rule, customer impact, priority, out-of-scope, release risk, historical decision; tao question khi thieu source | Chot expected behavior moi, doi business rule, accept release risk, override product priority |
| QA/Verification | QA owner, QA lead | Tao verification context record, test matrix, evidence checklist, defect wording draft, sign-off note draft, final verification memory | Tu dong pass/fail release, bo qua missing evidence, bien AI inference thanh QA sign-off |
| Engineer/Technology | Engineer owner, Tech lead, DevOps/SRE khi can | Tong hop implementation hints, impacted layers, PR/code/test/CI signals, deploy/build constraints, non-functional risk | Chot architecture/implementation thay engineer, khang dinh code behavior neu khong co source, write PR/ticket/CI action trong Phase 1 |
| AI/System/AWS | QA-Agents service owner, platform/security owner | Retrieve approved docs, label source-backed/inferred/unknown, run Bedrock prompt contracts, Guardrails, AgentCore session/trace, persist draft/evidence metadata | Tro thanh authority ve business/technical truth; luu memory ngoai policy; goi write tools khong approval |
| Third-party systems | Tool/system owner | Lam source/link: ticketing, PR, CI, docs, chat, test management, evidence store | Bi agent write truc tiep trong MVP; can Gateway/Identity/Policy/human approval neu sang Phase 2 |

Business/Product scope:

- Customer/user segment, business goal, KPI/impact, priority.
- Expected behavior, acceptance criteria, out-of-scope, exception/rule.
- Historical decision, policy, release note, customer promise.
- Release risk acceptance va business trade-off.

Engineer/Technology scope:

- Implementation shape: UI, API, database, config, permission, background job, integration.
- Codebase signal: component, route, endpoint, schema, config, existing tests, PR diff.
- Runtime/deployment constraints: environment, build version, feature flag, migration, cache, queue, observability.
- Technical risk: regression surface, compatibility, performance, security, data integrity, rollback.

QA scope:

- Translate business intent + technical signal thanh verification plan.
- Mark unknown/ambiguous areas and route question dung owner.
- Execute manual/automated tests, capture evidence, write defect and final note.
- Update final verification memory chi sau khi evidence co gia tri.

AI authority rules:

- **Source-backed**: co citation/link/source ro; AI co the summarize va de xuat.
- **Inferred**: suy luan tu source gan ke; phai gan nhan confidence/risk va can human review.
- **Unknown**: khong co source du; phai tao clarification block, khong duoc dien vao nhu fact.
- **Owner locked**: business decision chi Product/Business owner chot; technical decision chi Engineer/Tech owner chot; QA sign-off chi QA chot.

## 6. Runtime and Container Boundary

Proposal phai phan biet ro cac frame sau:

| Frame | Nam o dau | Thanh phan thuoc frame | Ghi chu |
|---|---|---|---|
| Human workspace | Nguoi dung/team | QA, Product, Engineer, QA Lead, reviewer | Nguoi chot decision va review AI output |
| User machine/local environment | May QA/developer hoac local runner | Browser UI, ETUS CLI/Dashboard, Playwright/Appium, Docker hooks, local YAML/artifacts/cache/memory khi chay local | Co the chua thuoc AWS; can policy ve secrets/local data |
| AWS account/control plane | AWS cloud cua to chuc | CloudFront, WAF, Cognito, API Gateway, Lambda, Step Functions, SQS, EventBridge, DynamoDB, S3, KMS, CloudWatch, Bedrock, AgentCore | Production boundary cho auth, storage, governance, observability |
| Third-party/external systems | SaaS hoac he thong ben ngoai AWS | Jira/ClickUp/Linear, GitHub/GitLab, CI, Slack/Teams, Notion/Confluence/Drive, external LLM/provider neu dung | Phase 1 uu tien read/manual links; Phase 2 moi Gateway + Identity + Policy |
| Target system under test | App/web/mobile/backend can QA | Staging/prod-like app, API, device/browser farm, test data system | Co the nam trong AWS, local, hoac third-party; can label rieng |

Boundary rules:

- UI cua nguoi dung khong mac dinh nam trong AWS; neu serve bang CloudFront thi UI asset nam AWS, nhung browser session nam tren may nguoi dung.
- ETUS local runner, Appium device, Docker hook va local artifact khong thuoc AWS neu chua deploy/host len AWS.
- Bedrock/AgentCore/CloudWatch/S3/DynamoDB la AWS control plane, khong phai replacement bat buoc cho ETUS runtime.
- Ticketing/PR/CI/docs/chat la third-party/external systems cho den khi co governed tool integration.
- Neu target system nam trong AWS, van phai ve/tach nhu "system under test", khong tron voi QA-Agents control plane.

## 7. Prerequisite: Knowledge Base and Source Understanding

Before QA-AI agents create a test plan, suggest verification steps, or help verify a ticket, they must understand the approved knowledge boundary for the ticket. This is a prerequisite, not an optional technical enhancement.

The agent must know:

- Which product and business sources are approved.
- Which current-behavior sources can be trusted.
- Which engineering or technical signals are only hints.
- Which evidence or memory can be reused.
- Which sources are stale, ownerless, conflicting, or forbidden.
- Which gaps must become clarification questions before QA execution.

Without this prerequisite, the agent can produce a polished but unsafe test plan. It may treat a stale document as current behavior, treat a code path as business truth, or convert inference into a fact. That is more dangerous than not using AI.

Knowledge Base is therefore the **approved retrieval boundary** for QA-Agents. It is the controlled set of source-of-truth documents and reviewed records that the agent can use to ground the Ready-for-QA Verification Context Record.

How this affects the QA flow:

1. Ticket arrives at ready-for-QA.
2. QA-AI agent retrieves only approved Knowledge Base sources and permitted optional signals.
3. Agent labels each important claim as `source-backed`, `inferred`, or `unknown`.
4. If context is missing, stale, or conflicting, the agent creates a Clarification Block instead of generating confident test instructions.
5. QA reviews the context record.
6. Only after that should the agent help produce test matrix, evidence checklist, ETUS execution suggestions, or final QA note.

Minimum prerequisite checks:

| Check | Required behavior |
|---|---|
| Source exists | Important claims should cite approved source when possible |
| Source is allowed | Retrieval must respect permission and data classification |
| Source is fresh | Stale or ownerless source cannot be treated as fact |
| Owner is clear | Product owns business truth; Engineering owns technical truth; QA owns sign-off |
| Conflict is visible | Conflicting sources become mismatch or risk, not silent AI resolution |
| Unknown is explicit | Missing source becomes `unknown` and a clarification question |
| Evidence is separate | Execution evidence and ETUS memory are not automatically source-of-truth |

This prerequisite makes Knowledge Base part of product governance, not just infrastructure.

## 8. MVP Artifact

MVP artifact la **Ready-for-QA Verification Context Record**. Artifact nay duoc tao khi ticket chuyen sang ready-for-QA, truoc khi QA execute.

Record toi thieu gom 5 phan:

| Section | Muc dich | Ai review |
|---|---|---|
| Ticket intent | Hieu ticket muon thay doi gi, acceptance criteria va out-of-scope | QA |
| Current behavior | Ghi lai he thong hien dang behave the nao va source nao xac nhan | QA + Engineer neu can |
| Business history | Ghi rule/exception/decision lien quan, hoac "unknown" neu chua co source | QA + Product neu can |
| QA verification plan | Bien context thanh scenarios must-have/regression/risk-based | QA |
| Final verification memory | Luu ket qua verify, evidence, risk, decision va note cho lan sau | QA |

Nguyen tac MVP:

- Neu chua biet current behavior/business history, record phai ghi `unknown` va tao question, khong duoc suy dien.
- Record duoc tao tai ready-for-QA, nhung final memory chi hoan tat sau khi QA verify.
- Record la shared context de thao luan, khong phai approval artifact tu dong.
- Storage/publish channel co the quyet dinh sau; product value truoc mat nam o chat luong record.

## 9. Core Entities

| Entity | Mo ta | Source |
|---|---|---|
| Ticket | Requirement/bug/task can verify | Jira/Linear/GitHub Issues/ClickUp tuy team |
| Business Context | Rule, decision, historical behavior, exception | Source-of-truth docs, ticket cu, decision log, release note |
| Codebase Signal | Component/API/route/test/config co lien quan | Git repo, PR diff, code search, test suite |
| Current-State Brief | Tong hop ticket vs business history vs codebase current state | QA-Agents generated + QA reviewed |
| Impact Surface | Flow/module/role/data boundary co the bi anh huong | QA-Agents generated + Engineer/QA reviewed |
| Clarification Block | Cau hoi co cau truc de QA copy gui Product/Engineer | QA-Agents generated + QA sent manually |
| Test Case | Test scenario co expected result | QA-Agents, existing test management, Markdown |
| Verification Session | Mot lan QA verify ticket/build/PR | QA-Agents |
| Evidence | Screenshot, video, logs, API response, test output | Drive/S3/GitHub artifact/CI |
| Defect | Bug/failure found by QA | Ticketing system |
| Source-of-Truth Document | Final verification record | Markdown/Docs/Notion/Confluence/Git repo |

## 10. Minimum Data Contract for Phase 1

```yaml
ticket:
  id: string
  title: string
  description: string
  acceptance_criteria: string[]
  links: string[]
  owner: string
  status: string

verification_session:
  id: string
  ticket_id: string
  qa_owner: string
  environment: string
  build_version: string
  started_at: string
  status: draft | in_progress | pass | fail | blocked

current_state_brief:
  ticket_id: string
  current_behavior_summary: string
  related_business_rules: string[]
  related_code_areas: string[]
  implementation_shape:
    layers: string[] # ui, api, database, config, background_job, permission, integration, unknown
    source: engineer_note | pr_diff | code_signal | qa_input | unknown
    confidence: low | medium | high
  related_existing_tests: string[]
  impacted_flows: string[]
  mismatch_or_ambiguity: string[]
  questions_for_product_or_engineer: string[]
  reviewed_by_qa: boolean

clarification_block:
  ticket_id: string
  area: current_behavior | business_rule | implementation_hint | scope | evidence
  owner_suggested: product | engineer | qa_lead
  context: string[]
  questions: string[]
  why_this_matters: string
  needed_before: test_planning | qa_execution | product_signoff | release
  blocking: boolean

test_case:
  id: string
  requirement_ref: string
  context_ref: string
  title: string
  type: positive | negative | regression | permission | data | ui | api
  priority: p0 | p1 | p2
  steps: string[]
  expected_result: string
  evidence_required: string[]
  result: pending | pass | fail | blocked

evidence:
  id: string
  test_case_id: string
  type: screenshot | video | log | api_response | ci_output | note
  uri: string
  captured_at: string
```

## 11. AWS and Bedrock Ecosystem Fit

Decision: Phase 1 dung **Bedrock + retrieval/RAG don gian + AgentCore Runtime/Harness boundary**.

Rationale:

- Phase 1 output la artifact draft/review, khong phai autonomous agent action.
- Core value la tong hop shared verification context co citation, khong phai tool orchestration nhieu buoc.
- Team can validate prompt contract, source quality, QA review workflow va evaluation truoc.
- AgentCore van nen co mat de pilot gan voi production shape: runtime boundary, session isolation, endpoint, trace/observability va upgrade path.
- AgentCore Gateway/Identity/Policy/write tools de Phase 2 khi agent can goi ticketing/PR/test/evidence tools nhieu buoc.

AWS fit matrix:

| Need | AWS layer phu hop | Ghi chu |
|---|---|---|
| Summarize ticket/spec/test result | Amazon Bedrock | Goi foundation model qua Converse/InvokeModel |
| RAG tren source-of-truth docs, historical tickets, QA guideline | Bedrock Knowledge Bases | Can ACL/freshness/citation policy ro |
| Doi chieu ticket voi business history/current behavior | Bedrock + Knowledge Bases + code/doc retrieval | Core value: ticket is not the truth |
| Tim codebase signals | Code search/repo index + Bedrock reasoning | Can cite file/path/test va khong suy dien qua muc |
| Guardrail cho PII, prompt attack, noi dung khong duoc luu | Bedrock Guardrails | Apply input/output theo policy |
| Runtime boundary cho QA Assistant | AgentCore Runtime/Harness | Phase 1 neu muon pilot gan voi production deployment |
| Agent goi ticketing/PR/test/evidence tools nhieu buoc | AgentCore Gateway + Runtime/Harness | Phase 2 neu can multi-tool agent production |
| Memory theo QA/project/domain | AgentCore Memory | Phase 2; chi luu thong tin duoc phep nho |
| Tool policy va outbound auth | AgentCore Gateway + Identity + Policy | Phase 2; can khi agent co the tao/update ticket/document |
| Observability/evaluation | CloudWatch + AgentCore Evaluations/Bedrock eval | Can trace, token, tool latency, quality score |
| Evidence/file storage | S3/Drive/Docs tuy stack hien co | Can retention va permission boundary |

Phase 1 AWS stack:

- Experience/auth: QA Workbench UI, CloudFront, WAF, Cognito, API Gateway.
- Application runtime: Lambda, AgentCore Runtime/Harness, optional SQS, optional Step Functions.
- AI/retrieval: Bedrock Converse, Guardrails, optional Knowledge Bases, vector store.
- Data/events: DynamoDB, S3, EventBridge, Secrets Manager.
- Security/ops: IAM, KMS, CloudWatch, CloudTrail, evaluation metrics.

Phase 2 AWS expansion:

- AgentCore Gateway exposes ticket/PR/evidence/source-of-truth tools.
- AgentCore Identity and Policy control tool access and outbound auth.
- AgentCore Memory stores managed session/domain memory with ETUS taxonomy.
- CloudWatch and AgentCore Evaluations close the quality loop.
- Step Functions/SQS/EventBridge handle async publish, review and escalation.

## 12. Knowledge Base Definition for QA-Agents

The Knowledge Base is the approved retrieval boundary for QA-Agents. It is not a place to ingest every available document or chat transcript. Its purpose is to provide controlled, source-backed context for the Ready-for-QA Verification Context Record.

### Purpose

The Knowledge Base should help QA-Agents retrieve:

- Product and business rules relevant to a ticket.
- Historical decisions and exceptions.
- QA guidelines and verification standards.
- Previous QA verification records and release notes.
- Approved source-of-truth documents.
- Known current behavior when it has an owner and review trail.

The Knowledge Base should support these output labels:

- `source-backed`: the claim is grounded in an approved source with citation.
- `inferred`: the claim is reasoned from nearby sources and needs human review.
- `unknown`: no reliable source exists; QA-Agents must ask a clarification question.

### Included Sources

Recommended Phase 1 sources:

| Source type | Examples | Use |
|---|---|---|
| Product source-of-truth | PRD, RFC, product spec, business rule docs | Expected behavior, scope, rule, exception |
| Decision history | Decision logs, approved historical tickets, release decision notes | Why a behavior exists, what changed before |
| QA source-of-truth | QA guidelines, test strategy, final verification records | Verification approach, evidence expectation, regression memory |
| Release history | Release notes, known risk notes, hotfix notes | Current or previous release behavior and risk |
| Technical references | Approved architecture docs, API docs, runbooks | Implementation shape and operational constraints |

Optional Phase 2 sources:

- PR diff summaries.
- CI/test results.
- Issue comments that have been reviewed or promoted to source-of-truth.
- ETUS verified behavioral memory.
- Customer-support signals after redaction and owner approval.

### Excluded Sources

The Knowledge Base should not ingest these by default:

- Raw chat threads.
- Unreviewed personal notes.
- Production logs.
- Secrets, credentials, tokens, API keys.
- PII or customer data.
- Raw customer support tickets unless redacted and approved.
- Stale documents without owner, freshness metadata, or review status.
- AI-generated summaries that do not link back to primary sources.

If excluded material is useful, it should first be reviewed, redacted, summarized, assigned an owner, and promoted into an approved source-of-truth document.

### Required Metadata

Each indexed document or chunk should carry metadata:

| Metadata | Purpose |
|---|---|
| `source_type` | Product spec, decision log, QA record, release note, runbook, ETUS memory |
| `owner` | Product, QA, Engineering, Platform, Security |
| `product_area` | Domain, module, workflow, service, or feature area |
| `permission_level` | Who can retrieve this source |
| `freshness` | Current, review needed, stale, deprecated |
| `last_reviewed_at` | Date of latest human review |
| `source_url` | Link to primary source |
| `confidence` | High, medium, low based on source quality |
| `data_classification` | Public/internal/confidential/restricted |

### Citation and Freshness Rules

- Every important claim in a verification record must cite an approved source when possible.
- If no source exists, the output must be labeled `unknown`.
- If a source is stale, deprecated, ownerless, or not reviewed, the output must be labeled `inferred` or `unknown`.
- Newer source-of-truth documents override older documents only when the owner and review status are clear.
- Conflicting sources must be surfaced as a mismatch, not silently resolved by AI.
- Knowledge Base retrieval must not override Product, Engineering, or QA authority.

### Phase 1 Implementation Boundary

Phase 1 should keep Knowledge Base usage read-only:

- Use Bedrock Knowledge Bases or equivalent retrieval over approved documents.
- Apply ACL, metadata filtering, and citation requirements.
- Do not let the assistant write back into source-of-truth documents automatically.
- Do not use raw chat or unreviewed content as retrieval input.
- Store generated records separately until QA reviews them.

Phase 1 success criteria:

- QA can see which source supports each important claim.
- Unknown context becomes a clarification question.
- Stale or conflicting sources are visible.
- The record improves time-to-understand without increasing false confidence.

### Phase 2 Expansion

Phase 2 can connect Knowledge Base with AgentCore and ETUS:

- AgentCore Memory stores governed session/domain memory.
- AgentCore Gateway exposes approved source-of-truth, ticket, PR, CI, ETUS, and evidence tools.
- AgentCore Identity and Policy enforce read/write access.
- ETUS verified behavioral memory can be promoted into the Knowledge Base after trust and provenance checks.
- AgentCore Evaluations can measure citation quality, source freshness, hallucination risk, and clarification usefulness.

### Relationship with ETUS Memory

ETUS memory and the Knowledge Base solve related but different problems:

| Layer | Role |
|---|---|
| Knowledge Base | Approved retrieval over source-of-truth documents and reviewed records |
| ETUS memory | Curated behavioral QA memory from verified execution |
| AgentCore Memory | Managed cloud memory primitive for sessions, actors, and domain memory |

Recommended rule: ETUS memory should not automatically become Knowledge Base truth. It should be promoted only when it has source test, evidence, trust score, no active contradiction, and owner review when needed.

## 13. Technical Operating Model for Correct Execution

This section defines what must be true technically for QA-AI Agents to work correctly from MVP to higher enhancement layers. The system should be designed as a controlled verification platform, not as a free-form chatbot and not as an unconstrained autonomous QA worker.

### 13.1 Non-Negotiable Technical Principles

| Principle | Why it matters | Implementation requirement |
|---|---|---|
| Human authority remains explicit | QA, Product, and Engineering own different truths | Every output must show who must review or approve it |
| Retrieval happens before reasoning | The agent must understand approved context before planning tests | Knowledge Base/source gate runs before test matrix generation |
| Claims are source-labeled | Prevents false confidence | Every important claim is `source-backed`, `inferred`, or `unknown` |
| Test plans are reviewable artifacts | QA must be able to reject or edit AI output | Store draft records separately from approved records |
| Evidence is first-class | Final QA notes without evidence are not trustworthy | Evidence objects must link to test case, run, environment, and build |
| Tool actions are gated | Agent tools can mutate external systems if uncontrolled | Phase 1 is read-only; Phase 2 uses Gateway, Identity, Policy, approval |
| Memory is curated, not automatic | Bad memory creates long-term wrong behavior | Memory writes need provenance, trust, contradiction, and review rules |
| Evaluation is part of delivery | AI quality must be measured, not assumed | Track citation quality, hallucination, risk labels, and QA acceptance |

### 13.2 MVP Technical Architecture

MVP should be a draft-only QA Assistant with a strict request lifecycle:

1. Receive ticket and QA-entered context.
2. Validate schema, user identity, permission, data classification, and request size.
3. Retrieve approved Knowledge Base sources with metadata filters.
4. Construct prompt with source snippets, source metadata, and output contract.
5. Call Bedrock Converse with Guardrails.
6. Produce a Ready-for-QA Verification Context Record.
7. Persist draft record, source links, model metadata, token usage, latency, and trace ID.
8. QA reviews, edits, approves, blocks, or requests clarification.
9. Only approved context proceeds to test matrix, evidence checklist, ETUS suggestion, or final note.

MVP should not:

- Write comments to tickets automatically.
- Update source-of-truth docs automatically.
- Pass or fail a test automatically.
- Call PR, CI, ticket, or evidence tools directly.
- Store memory without review.
- Treat code search result as business truth.

### 13.3 QA Engineering Requirements

QA engineering must define how AI output becomes testable and auditable.

| Area | Requirement |
|---|---|
| Test design | Test cases must map to requirement, business rule, current behavior, risk, and evidence requirement |
| Coverage | Matrix must include positive, negative, regression, permission, data, UI, API, and edge-case scenarios where relevant |
| Priority | Each test case must have priority and rationale, not just a list of steps |
| Evidence | Evidence required must be explicit: screenshot, video, log, API response, CI output, note, or ETUS artifact |
| Result states | Use `pending`, `pass`, `fail`, `blocked`; `blocked` must include blocker owner and next question |
| Environment | Record environment, build version, feature flag, data setup, user role, device/browser when relevant |
| Defect quality | Defect wording should include repro steps, expected vs actual, evidence, impact, and source context |
| Final note | Final QA note must link verified scope, unresolved risks, evidence, defects, and release confidence |

Definition of done for MVP QA output:

- QA can explain why each test exists.
- QA can see which source or risk produced each test.
- Missing context is visible before execution.
- Evidence checklist is clear before QA starts.
- Final note can be reused for release review or regression memory.

### 13.4 AI Engineering Requirements

AI engineering must make model behavior predictable, inspectable, and evaluable.

| Layer | Requirement |
|---|---|
| Prompt contract | Use structured output schema for ticket brief, current-state brief, test matrix, clarification block, and final note |
| Grounding | Prompt must include source snippets and metadata; model must not invent missing context |
| Output labels | Every important claim must be `source-backed`, `inferred`, or `unknown` |
| Confidence | Confidence must be based on source quality, freshness, agreement, and owner clarity, not model certainty |
| RAG quality | Retrieval must be evaluated for relevance, freshness, permission filtering, and citation accuracy |
| Guardrails | Apply input and output guardrails for PII, secrets, prompt injection, restricted content, and unsupported actions |
| Model routing | Use smaller/faster model for classification and extraction; stronger model for synthesis and risk reasoning if needed |
| Evaluation | Maintain golden ticket set with expected context, test plan quality rubric, hallucination checks, and human QA ratings |
| Regression | Prompt/version changes must run against evaluation dataset before release |

Minimum AI evaluation set:

- 10 simple tickets with clear acceptance criteria.
- 10 ambiguous tickets that should produce clarification questions.
- 10 tickets with stale or conflicting docs.
- 10 regression-heavy tickets.
- 10 tickets requiring Product vs Engineering owner separation.
- 10 ETUS evidence-backed cases after execution integration exists.

Key AI metrics:

- Citation precision.
- Unknown detection accuracy.
- Hallucination rate.
- Clarification usefulness.
- QA acceptance rate.
- Test matrix usefulness.
- Evidence checklist completeness.
- Source freshness correctness.
- Owner routing correctness.

### 13.5 Software Engineering Requirements

Software engineering must make the system reliable, versioned, idempotent, and auditable.

| Component | Requirement |
|---|---|
| API layer | Validate request schema, auth context, tenant/project, data classification, size limits, and idempotency key |
| Session model | Persist verification session ID, ticket ID, user, status, source set, model version, prompt version, trace ID |
| Draft record | Store generated records as drafts until QA approval |
| Versioning | Version prompt templates, output schema, Knowledge Base index, and final record |
| Audit | Log who generated, reviewed, edited, approved, blocked, or exported each record |
| Async jobs | Use queue/state machine for ingestion, export, evaluation, ETUS run triggers, and long-running processing |
| Error handling | Classify failures: validation, retrieval, guardrail block, model timeout, policy denial, external tool failure |
| Idempotency | Re-running same ticket/context should not duplicate records or evidence links unexpectedly |
| Data retention | Draft TTL, evidence retention, audit retention, and memory retention must be explicit |
| Multi-tenant boundary | Workspace/project/team isolation must be enforced at API, retrieval, storage, and logs |

Recommended service boundaries:

- `Context Intake API`: accepts ticket and QA context.
- `Knowledge Retrieval Service`: retrieves approved sources with metadata filters.
- `Synthesis Service`: calls model with prompt contracts and guardrails.
- `Verification Record Service`: stores draft, review, approval, export, and versioning.
- `Evidence Service`: stores evidence metadata and artifact links.
- `Evaluation Service`: runs quality checks over records, traces, and human feedback.
- `Integration Service`: Phase 2 boundary for ticket, PR, CI, ETUS, and docs tools.

### 13.6 Cloud Engineering Requirements

Cloud engineering must enforce isolation, security, observability, and cost control.

| Area | MVP requirement | Enhanced requirement |
|---|---|---|
| Identity | Cognito/OIDC for users; IAM roles for services | AgentCore Identity for agent workload identities and external credentials |
| Runtime | Lambda or AgentCore Runtime/Harness for assistant invocation | Runtime behind AgentCore Gateway for centralized governance |
| Retrieval | Bedrock Knowledge Bases or equivalent approved retrieval | Metadata-aware multi-index retrieval with freshness and ACL policies |
| Storage | DynamoDB for sessions, S3 for exports/evidence, TTL for drafts | Versioned records, object retention policy where required |
| Security | IAM least privilege, KMS encryption, Secrets Manager | Resource policies, policy-as-code, per-tool approval policies |
| Network | Private access where needed, no direct secret exposure | VPC endpoints/private connectivity for internal systems where required |
| Observability | CloudWatch logs, metrics, traces, alarms | AgentCore Observability, trace-to-eval linkage, quality dashboards |
| Audit | CloudTrail for control-plane actions | Full audit of Gateway/tool calls and approval decisions |
| Cost | Token, retrieval, storage, and runtime metrics | Budgets, throttles, model routing, cache, batch evaluation controls |
| Resilience | Retry safe jobs, dead-letter queues, timeout policies | Multi-region or disaster recovery only if business criticality requires |

Minimum CloudWatch metrics:

- Request count, success, failure, latency.
- Model token usage and model latency.
- Retrieval hit count, empty retrieval count, stale source count.
- Guardrail block count.
- Unknown/clarification rate.
- QA approval/edit/reject rate.
- Evidence completeness rate.
- ETUS run trigger/result count when integrated.
- Cost per verification record.

### 13.7 Enhancement Layers

| Layer | Capability | New technical requirement | Exit criteria |
|---|---|---|---|
| MVP | Draft-only context assistant | Read-only Knowledge Base, Bedrock prompt contracts, Guardrails, draft record store | QA accepts context record quality and can use it before testing |
| MVP+ | Evidence-aware QA workbench | Evidence metadata model, final note generation, QA review workflow | Final notes consistently link evidence, risk, and verified scope |
| Execution integration | ETUS-assisted verification | ETUS run metadata, artifact links, memory deltas, local/cloud runner boundary | ETUS evidence can be attached to records without replacing QA sign-off |
| Governed tools | Ticket/PR/CI/docs integrations | AgentCore Gateway, Identity, Policy, approval UX, audit trail | Agent can read tools and draft writes with human approval |
| Managed memory | Cross-ticket/project learning | AgentCore Memory + ETUS memory promotion rules | Memory improves future context without propagating contradictions |
| Continuous evaluation | Quality and regression loop | AgentCore/Bedrock evaluations, golden dataset, trace sampling | Prompt/model/tool changes are evaluated before rollout |
| Semi-automated verification | Constrained agentic workflows | Policy-gated tool plans, sandboxed execution, rollback, human checkpoints | Agent can run bounded workflows but QA still owns sign-off |

### 13.8 Release Gates by Phase

MVP release gate:

- Knowledge Base source policy approved.
- Prompt contracts versioned.
- Guardrails configured.
- Draft record schema implemented.
- QA review workflow implemented.
- Source labels visible.
- No write tools enabled.
- Basic observability and audit logs available.
- Golden ticket evaluation passes agreed threshold.

Phase 2 release gate:

- Gateway tool contracts reviewed.
- Identity and credential flow approved.
- Policy rules defined for every tool.
- Human approval required for write actions.
- Tool calls traced and auditable.
- Rollback/undo path exists for any write-capable integration.
- Evaluation dataset covers tool failures and permission denial.

Managed memory release gate:

- Memory schema has owner, source, trust, confirmation, contradiction, and expiry.
- Memory write path is reviewable.
- Deprecated or contradicted memory is not retrieved as fact.
- ETUS memory promotion requires evidence and source test.
- Memory access follows project/user permission boundaries.

### 13.9 Technical Definition of Done

The system is technically ready only when:

- A QA reviewer can trace every important claim to a source, inference, or unknown.
- A Product reviewer can see which business decisions still need confirmation.
- An Engineer can see which implementation signals are evidence vs hints.
- A Cloud/Security reviewer can see where data is stored, who can access it, and how actions are audited.
- An AI engineer can evaluate output quality against a repeatable dataset.
- A software engineer can replay a session using prompt version, model version, source set, and trace ID.
- A QA lead can compare planned tests, executed tests, evidence, defects, and release confidence.

## 14. ETUS Architecture as Existing Asset

Decision: ETUS khong nen duoc xem nhu demo rieng le nam ngoai proposal. ETUS hien co nhieu thanh phan dung voi product direction cua QA-Agents:

- Local-first QA harness.
- Memory-aware execution.
- Dashboard evidence.
- MCP surface cho coding agents.
- Skills cho authoring/debug/triage.
- Web/mobile adapters.
- Hook sandbox.
- SQLite observability.

Proposal Bedrock nen coi ETUS la **execution/evidence harness hien co**, con AWS Bedrock/AgentCore la **production control plane** co the cloud-hoa, govern va scale cac capability do.

ETUS current system shape:

| Layer | Thanh phan ETUS | Vai tro |
|---|---|---|
| Human/operator surface | Dashboard UI, CLI | QA/developer author test, run, inspect, triage, config, memory, insights |
| Agent-facing surface | MCP server, packaged skills | Coding agents co tool contract de tao test/suite/hook, enqueue run, doc artifact/log, cancel, classify failure |
| Local app/runtime | Dashboard server | HTTP API, static UI, run queue, child process runner, SQLite DB, live editor, artifacts |
| Core execution | Core runner + agent loop | Resolve config, variables, secrets, hooks, cache, memory; observe, plan, execute, verify |
| Platform adapters | Web Playwright, Android/iOS Appium | Browser/mobile observe, action execution, screenshots, logs, accessibility/screen context |
| State/evidence | SQLite, YAML files, artifacts, logs, cache, memory | Run history, steps, reasoning traces, token events, screenshots, reports, memory observations |
| Extension/sandbox | Docker hook sandbox | Setup/teardown, fixtures, env/secrets, pre/post actions |

ETUS execution sequence, in prose:

1. QA/developer/agent selects YAML test or suite.
2. CLI/Dashboard resolves config, target, model, variables, hooks, cache and memory.
3. Core runner initializes adapter and navigates to target.
4. Each step observes screen/DOM, reads cache, calls planner on cache miss, executes normalized action, verifies completion and captures evidence.
5. Run finalizes result, artifacts, SQLite records, cache and memory deltas.
6. Dashboard/MCP expose run evidence for triage.

## 15. ETUS Memory Model

ETUS memory hien tai la **curated behavioral QA memory**, khong chi la conversation memory.

Current shape:

- Memory scopes: `product`, `suite`, `test`.
- Storage tiers: `products`, `suites`, `tests`.
- Observation format: Markdown file co YAML frontmatter va body.
- Key fields: `id`, `title`, `content`, `trust`, `created`, `last_confirmed`, `confirmed_count`, `contradicted_count`, `source_test`.
- Suite observations co them `position` va `suite_snapshot`.
- Memory API/UI reads catalog by product, product detail, scoped observations, invalid files.
- Security scan title/body truoc khi accept/read; invalid parse/security files duoc report thay vi silently trust.
- Curator flow sau run dung A.U.D.N. framework:
  - `ADD`: ghi observation moi neu hanh vi dang nho.
  - `UPDATE`: confirm observation dung/relevant va tang trust.
  - `DEPRECATE`: giam trust khi observation bi contradict.
  - `NOOP`: khong ghi gi neu run khong co insight dang nho.

Memory principle:

- ETUS memory = QA behavior memory co provenance va trust.
- AgentCore Memory = managed cloud memory primitive.
- Hai thu nen ket hop, khong thay the nhau.

Mapping nen dung:

- AgentCore Memory cung cap managed short-term/long-term store, actor/session scoping, retrieval va observability.
- ETUS schema cung cap domain taxonomy: product/suite/test observations, trust, confirmation, contradiction, source test, suite snapshot.
- Memory phai curated, scoped va contradictable; "remember everything" se tao false confidence.

## 16. ETUS Capability Mapping to Bedrock/AWS

| ETUS capability hien co | Dua vao proposal? | AWS/Bedrock mapping |
|---|---|---|
| Natural-language runner va planner/verifier loop | Co | Deploy/wrap runner bang AgentCore Runtime khi can cloud endpoint/session/trace; giu local mode cho dev/device-specific runs |
| Curated product/suite/test memory | Co, uu tien cao | Map sang AgentCore Memory long-term strategies/records; giu ETUS trust/provenance schema nhu domain layer |
| Dashboard evidence: SQLite runs, steps, logs, token events, artifacts | Co | CloudWatch/OTEL for traces, S3 for artifacts, DynamoDB for session metadata, AgentCore Evaluations for quality loop |
| MCP server va skills | Co | Phase 2 expose qua AgentCore Gateway nhu MCP/OpenAPI tools co Identity/Policy/human approval |
| Web/mobile adapters | Co, nhung khong replace ngay | AgentCore Browser co the ho tro managed browser session/replay; Appium/local device flow van can ETUS adapter |
| Hook sandbox | Co | Map thanh Gateway tools/Lambda/Step Functions/Code Interpreter tuy isolation, network va audit need |
| Cache/self-healing execution | Co | Dung nhu cost/performance layer; CloudWatch metrics can track cache hit, replanning, healing attempts |
| Failure triage/reporting | Co | Feed final QA note, defect wording, release confidence record va eval dataset |

## 17. Recommended Architecture Without Diagram

Khong nen bat dau bang "rewrite ETUS len AWS". Nen tach thanh ba boundary:

1. **Verification context boundary**
   - Bedrock + optional Knowledge Bases tao Ready-for-QA Verification Context Record.
   - Artifact nay sinh truoc execution.
   - Output phai co labels: source-backed, inferred, unknown.

2. **Execution/evidence boundary**
   - ETUS chay verification, thu screenshots/logs/traces/artifacts.
   - ETUS update curated QA memory chi sau khi evidence co gia tri.
   - Boundary nay co the local-first hoac AgentCore Runtime-hosted tuy target.

3. **Governance/control-plane boundary**
   - AgentCore Gateway/Identity/Policy/Observability/Evaluations quan ly tool access, auth, trace, eval, policy va rollout.
   - Boundary nay can thiet khi agent duoc phep goi ticket/PR/CI/evidence/source-of-truth tools.

Phase 1 target:

- QA Workbench/manual intake collects ticket + QA input.
- Bedrock/AgentCore Runtime assistant creates context record.
- QA reviews and approves plan.
- ETUS can execute selected tests and capture evidence.
- ETUS memory stores verified behavioral observations.
- Final source-of-truth note links context + execution evidence.

Phase 2 target:

- AgentCore Runtime/Harness hosts QA assistant.
- AgentCore Gateway exposes ETUS MCP tools + ticket/PR/CI/evidence tools.
- AgentCore Identity/Policy controls who/what can read or write.
- AgentCore Memory stores managed session/domain memory with ETUS taxonomy.
- CloudWatch + AgentCore Evaluations close the quality loop.

## 18. Request Journey

Phase 1 journey:

1. QA inputs ticket + current behavior/business history/clarification if known.
2. API validates auth, schema and policy.
3. AgentCore Runtime/Harness creates bounded session.
4. Bedrock prompt contracts synthesize context with Guardrails.
5. Optional retrieval uses approved docs/source-of-truth only.
6. Draft Ready-for-QA Verification Context Record is generated.
7. QA reviews, edits and approves.
8. If context is missing, AI creates Clarification Block for QA to send manually.
9. If answer is inferred, output labels confidence/risk.
10. If risk is high, Product/Engineer confirmation is required.
11. QA executes manual/automation/ETUS tests and attaches evidence.
12. Final QA note and final verification memory are created after evidence.

## 19. Prompt Contract Outputs

Ticket brief output:

```json
{
  "problem_summary": "string",
  "user_impact": "string",
  "acceptance_criteria": ["string"],
  "affected_flows": ["string"],
  "ambiguities": ["string"],
  "qa_focus": ["string"]
}
```

Current-state brief output:

```json
{
  "current_behavior": "string",
  "related_business_rules": ["string"],
  "related_code_or_test_signals": ["string"],
  "implementation_shape": {
    "layers": ["ui", "api", "database", "config", "background_job", "permission", "integration", "unknown"],
    "source": "engineer_note | pr_diff | code_signal | qa_input | unknown",
    "confidence": "low | medium | high"
  },
  "impact_surface": ["string"],
  "mismatch_or_ambiguity": ["string"],
  "questions_for_product_or_engineer": ["string"],
  "source_labels": ["source-backed", "inferred", "unknown"]
}
```

Final QA note output:

```json
{
  "scope_verified": ["string"],
  "result": "pass | fail | blocked",
  "environment": "string",
  "build_version": "string",
  "evidence_links": ["string"],
  "defects": ["string"],
  "known_risks": ["string"],
  "follow_ups": ["string"],
  "release_confidence": "low | medium | high"
}
```

## 20. After Proposal Implementation Architecture Backlog

Section nay khong thay the proposal. No la backlog va target architecture outline de team tiep tuc sau khi proposal duoc approve. Muc tieu la tranh nhay thang vao full agentic system khi cac boundary, contract, Knowledge Base, memory, evidence va approval gate chua duoc chot.

Recommended direction: **hybrid**.

- Dung backlog de chia viec trien khai theo workstream.
- Dung target architecture outline de biet he thong dich se gom nhung layer nao.
- Dung release gates de quyet dinh luc nao moi nang cap tu MVP sang managed AWS/AgentCore capabilities.

### 20.1 Implementation Principles After Proposal

- MVP phai giai quyet context fragmentation truoc, khong bat dau bang autonomous testing.
- QA van la authority cuoi cung cho pass/fail, scope verified va release confidence.
- Knowledge Base la prerequisite truoc khi agent de xuat verification; no khong duoc gom nguon untrusted.
- Memory chi duoc promote sau khi co human confirmation hoac evidence duoc chap nhan.
- Evidence/log/test artifact la audit record, khong phai memory.
- Tool integrations bat dau read-only; write-back chi duoc mo khi co approval UX, audit va rollback path.
- ETUS nen giu vai tro execution/evidence harness; AWS/Bedrock/AgentCore nen giu vai tro control plane, governance, retrieval, trace va evaluation.

### 20.2 MVP Implementation Blueprint

MVP nen duoc xay nhu mot bounded QA assistant/workbench:

1. QA input ticket, environment, current behavior neu biet, risk/notes va source links.
2. System validate schema, auth, PII/secrets policy va source eligibility.
3. Retrieval chi doc approved Knowledge Base/doc/source-of-truth.
4. Bedrock prompt contract tao draft Verification Context Record.
5. Output phai label claim thanh `source-backed`, `inferred`, `unknown`.
6. Neu thieu context, agent tao Clarification Block thay vi tu doan.
7. QA review/edit/approve context record.
8. QA chay manual test, automation hoac ETUS run.
9. Evidence duoc attach vao record: screenshot, log, CI link, ETUS artifact, defect link.
10. Final QA note duoc tao sau evidence va human decision.
11. Memory update chi xay ra sau khi QA confirm insight dang nho.

MVP should not:

- Auto pass/fail ticket.
- Auto write ticket comment, PR comment, release note, docs update.
- Treat ticket text as complete truth.
- Treat memory as source-of-truth.
- Use raw chat history, Slack, local files, screenshots, or CI logs as trusted KB without curation.
- Call third-party write tools without human approval.

### 20.3 Target Architecture Outline

| Layer | MVP responsibility | Later enhanced responsibility | Key decision |
|---|---|---|---|
| Human workspace | QA reviews artifact; Product/Engineer answer clarifications | Approval workflow and routed escalation | Who owns final decision for business rule, implementation risk, release risk? |
| User machine/local ETUS | Optional local execution, evidence capture, artifacts, local memory | Packaged QA workbench, local runner, device/browser-specific adapter | Which runs must stay local vs can be cloud-hosted? |
| AWS control plane | Bedrock call, optional Knowledge Bases, S3/DynamoDB record store, CloudWatch traces | AgentCore Runtime/Gateway/Identity/Memory/Policy/Evaluations | Which AgentCore components are needed per phase? |
| Third-party systems | Read-only links/manual copy in MVP | Governed Gateway tools for ClickUp/Jira/GitHub/CI/docs | Which systems are read-only, draft-write, or approved-write? |
| Target system under test | Manual or ETUS-driven test target | Controlled browser/API/mobile automation flows | What environments are safe for AI-assisted execution? |
| Governance/audit | Prompt version, model version, source set, trace id, user approval | Policy-as-code, CloudTrail/CloudWatch, eval dashboards | What is required to replay and audit a QA decision? |

### 20.4 Implementation Workstreams

| Workstream | Owner lens | Deliverables | MVP exit criteria |
|---|---|---|---|
| Product/QA workflow | Product + QA | Ticket intake form, clarification flow, verification context UX, final QA note format | QA can use the artifact before test execution and identify missing context earlier |
| Knowledge Base | AI + Engineering | Source registry, trust levels, freshness policy, retrieval filters, citation format | Every important claim can be traced to approved source, inference, or unknown |
| Prompt/output contract | AI Engineering | Versioned prompts, structured JSON schema, refusal/clarification rules, confidence/risk labels | Output is stable enough for repeated review on golden tickets |
| Evidence model | QA + Software | Evidence schema, ETUS artifact links, CI/manual evidence links, defect reference fields | Final note ties result to concrete evidence and verified scope |
| ETUS integration | QA Automation + Software | Run metadata contract, artifact export, memory delta policy, local/cloud boundary | ETUS evidence can be attached without replacing QA sign-off |
| Cloud runtime | Cloud + Software | API boundary, auth, Bedrock invocation, storage, logs, trace ids, retention | Sessions are observable, replayable and permissioned |
| Governance and security | Cloud + Security | PII/secrets policy, IAM boundary, no-write policy, audit trail, approval gate | No sensitive data or write action escapes policy |
| Evaluation | AI + QA Lead | Golden ticket dataset, expected outputs, hallucination/grounding metrics, regression suite | Prompt/model/source changes are evaluated before rollout |

### 20.5 Contracts to Design Next

These contracts should be designed before coding a production MVP:

- **Ticket intake contract**: ticket id, title, description, acceptance criteria, owner, product area, environment, links, risk, QA notes.
- **Source registry contract**: source id, type, owner, freshness, trust level, allowed scope, citation path, expiry, exclusion reason.
- **Retrieval contract**: query intent, allowed source filters, max age, citation requirement, conflict handling, missing context behavior.
- **Verification context record contract**: business intent, current behavior, impacted flows, risk, test matrix, evidence checklist, clarifications, source labels.
- **Evidence contract**: evidence id, source, type, environment, run id, timestamp, link/path, owner, result, retention.
- **Memory contract**: scope, statement, source evidence, trust, confirmation, contradiction, expiry, last confirmed, access boundary.
- **Tool contract**: tool name, read/write mode, identity, required approval, input schema, output schema, audit fields, rollback/undo path.
- **Evaluation contract**: golden input, expected claims, required citations, blocked actions, allowed uncertainty, scoring rubric.

### 20.6 Target Runtime Flow for Implementation Design

1. **Intake**: QA submits ticket and known context through workbench or form.
2. **Policy precheck**: system blocks secrets/PII, validates project permission and source boundary.
3. **Knowledge retrieval**: system retrieves from approved KB/source registry only.
4. **Synthesis**: Bedrock prompt creates structured Verification Context Record.
5. **Grounding check**: output is checked for unsupported claim, missing citation, contradiction and unknowns.
6. **Human review**: QA edits/approves, then sends clarification to Product/Engineer if needed.
7. **Execution**: QA runs manual/automation/ETUS tests; ETUS produces run metadata and artifacts.
8. **Evidence attach**: evidence links are attached to the record and final QA note.
9. **Memory promotion**: only confirmed and evidence-backed observations can update memory.
10. **Evaluation loop**: sampled sessions feed golden dataset and regression evaluation.

### 20.7 Enhancement Layers After MVP

| Layer | Capability | When to add | Risk if added too early |
|---|---|---|---|
| Layer 0: manual artifact | Markdown/HTML/ClickUp report and manual prompt | Proposal/pilot alignment | None; slow but safe |
| Layer 1: QA workbench | Form + structured output + manual approval | MVP start | UX can drift without schema discipline |
| Layer 2: Knowledge Base | Managed retrieval over approved docs | When source registry is ready | Wrong sources create false confidence |
| Layer 3: AgentCore Runtime | Managed session/runtime/trace boundary | When usage needs service endpoint and observability | Runtime complexity before contract maturity |
| Layer 4: Gateway tools | Read-only ClickUp/GitHub/CI/docs tools | When tool schemas and identity are ready | Tool hallucination or unauthorized access |
| Layer 5: Managed memory | Project/suite/test/user correction memory | When promotion/contradiction rules are tested | Stale memory can become hidden false truth |
| Layer 6: Controlled write-back | Draft or approved ticket/doc/comment writes | When approval UX, audit and rollback exist | Agent can create production workflow noise |
| Layer 7: Semi-automated verification | Bounded plans, sandboxed execution, policy gates | When eval and rollback are strong | Agent may overfit happy path or miss risk |

### 20.8 Decisions to Make Before Full Implementation

- Which ticketing system is first-class in MVP: ClickUp, Jira, or manual intake?
- Which documents become approved Knowledge Base sources?
- Who owns source freshness and conflict resolution?
- Which evidence types are mandatory for final QA note?
- Which ETUS runs are local-only vs allowed through cloud control plane?
- Which third-party tools are read-only in Phase 2?
- What is the minimum golden dataset size before prompt/model rollout?
- What PII/customer-data rules apply to ticket text, screenshots, logs and artifacts?
- What is the retention period for context records, evidence, traces and memory?
- What approval model is required before any write-back integration?

### 20.9 After Proposal Deliverables

The next documentation package should include:

- `qa-agents-aws-after-proposal-architecture.md`: implementation architecture source of truth with AWS deployment, network, runtime, memory, ETUS evidence, security and evaluation diagrams rendered in the HTML reader view.
- Component architecture diagram.
- Runtime/container boundary diagram.
- Sequence diagram for ticket-to-final-QA-note.
- Data model for Verification Context Record, Evidence and Memory.
- Source registry and Knowledge Base policy.
- IAM/security boundary.
- Tool governance matrix.
- Evaluation plan and golden dataset definition.
- MVP implementation plan with milestones and release gates.

## 21. Roadmap

Phase 0: RFC alignment

- Chot target user, pain, artifact, AWS fit.
- Chot data policy: PII, customer data, logs, secrets.
- Chot leading indicator cho pilot dashboard.
- Confirm source-of-truth publish channel.

Phase 1: Simple AgentCore MVP

- QA Workbench hoac manual form.
- AgentCore Runtime/Harness wraps assistant.
- Bedrock prompt contracts + Guardrails.
- Optional Knowledge Bases over approved docs.
- DynamoDB/S3/CloudWatch for record and telemetry.
- No auto-write to ticket/doc/PR/CI.

Phase 2: Tool-integrated agent

- AgentCore Gateway exposes ticket/PR/evidence/source-of-truth tools.
- Identity/Policy control outbound access.
- SQS/EventBridge/Step Functions handle async workflows.
- AgentCore Memory stores managed session/domain memory with ETUS taxonomy.
- AgentCore Evaluations measure agent/tool quality.
- Human approval before write actions.

## 22. Success Metrics

Metric set:

- Time-to-understand ticket.
- Shared-context alignment.
- Mismatch detection before testing.
- Test coverage usefulness.
- Evidence completeness.
- Regression risk coverage.
- Defect quality.
- Release confidence.

Pilot leading indicators:

- QA can explain scope faster without losing accuracy.
- QA identifies ambiguity/current-state mismatch earlier.
- Product/Engineer clarification becomes more structured.
- Final QA note has evidence links and known risk.
- Record is reused later for regression or release review.

## 23. Risks and Guardrails

Critical risks:

- False confidence from AI synthesis without source.
- Shifting responsibility from Product/Engineer to QA.
- AI output with no citation.
- Code path being mistaken for business truth.
- Impact analysis too broad and noisy.
- Documentation theater: final notes look good but are not reused.
- Data leakage: PII, secrets, production logs, customer data.
- Premature auto-write to third-party tools.

Guardrails:

- Every important claim must be `source-backed`, `inferred`, or `unknown`.
- AI must not pass/fail release.
- AI must not override Product/Engineer/QA owner decisions.
- Unknown context must become a clarification question.
- Write actions are disabled in Phase 1.
- Memory writes require policy, provenance and contradiction handling.
- Evidence is first-class: final note should link run, step, screenshot/log/API/CI artifact where available.

## 24. Open Questions

1. Ticket source la gi: Jira, Linear, GitHub Issues, ClickUp, hay system noi bo?
2. Test cases hien dang o dau: spreadsheet, test management tool, Markdown, repo, hay tribal knowledge?
3. Source-of-truth document nen publish o dau: Git repo, Notion, Confluence, Google Docs, hay ticket comment?
4. QA evidence hien dang luu o dau: Drive, S3, CI artifacts, test tool, hay attachment trong ticket?
5. PR/build/source code/historical docs nen duoc dua vao optional enrichment theo rule nao?
6. Khi nao optional source-code/PR analysis moi duoc nang thanh dependency?
7. AI duoc phep tao defect/ticket draft truc tiep khong, hay chi generate text de QA copy?
8. Data nao bi cam dua vao model: PII, customer data, secrets, logs production?
9. Metric nao la leading indicator cho pilot dau tien?
10. ETUS nen tiep tuc local-first hay co subset runner nao can host qua AgentCore Runtime?

## 25. External References

- Amazon Bedrock AgentCore overview: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html
- AgentCore Runtime: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agents-tools-runtime.html
- AgentCore Gateway: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway.html
- AgentCore Memory get started: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/memory-get-started.html
- AgentCore Memory strategies: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/memory-strategies.html
- AgentCore Identity: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/identity.html
- AgentCore Policy: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/policy.html
- AgentCore Browser: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/browser-tool.html
- AgentCore Code Interpreter: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/code-interpreter-tool.html
- AgentCore Observability: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/observability.html
- AgentCore Evaluations: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/evaluations.html
- Amazon Bedrock overview: https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html
- Amazon Bedrock Guardrails: https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html
- Amazon Bedrock Knowledge Bases: https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html
- AWS Architecture Icons: https://aws.amazon.com/architecture/icons/
