# QA-Agents AWS After-Proposal Architecture Design

Status: Design for review  
Date: 2026-07-23  
Source of truth: This Markdown document defines the post-proposal architecture package. The HTML page is a human-readable visual rendering of the same decisions.

## 1. Goal

Define an implementation-ready, production-shaped hybrid architecture for QA-Agents that lets the Cloud team configure AWS boundaries while preserving ETUS as the local execution and evidence harness.

The design must make these boundaries explicit:

- Human users and approval responsibilities.
- User machine and ETUS local execution.
- AWS account, region, VPC and service boundaries.
- Third-party systems such as ClickUp, GitHub, CI and source-of-truth documentation.
- The target application and test environments.

## 2. Chosen Approach

Use a production-shaped hybrid architecture.

ETUS remains responsible for device- and environment-specific execution, test adapters, local artifacts and evidence capture. AWS provides the governed control plane for intake, source retrieval, model invocation, structured synthesis, persistence, identity, observability and evaluation.

The design is intentionally progressive:

- MVP: a read-oriented assistant with structured output, approved source retrieval, Bedrock inference, Guardrails, durable records and traceability.
- Phase 2: AgentCore Gateway, Identity, Policy, read-only third-party tools, managed Memory and private connectivity.
- Later: approved write-back, bounded execution orchestration and automated evaluation gates.

## 3. AWS Service Responsibilities

| Boundary | AWS capability | Responsibility | MVP status |
|---|---|---|---|
| Ingress | API Gateway or an equivalent authenticated application endpoint | Accept ticket context and return a job/session reference | Required |
| Runtime | Amazon Bedrock AgentCore Runtime | Host the QA assistant session and provide a production-shaped invocation boundary | Required when service endpoint is introduced |
| Model | Amazon Bedrock Converse API | Generate structured verification context from grounded input | Required |
| Safety | Amazon Bedrock Guardrails | Filter sensitive content and apply grounding/safety controls to model interactions | Required |
| Retrieval | Amazon Bedrock Knowledge Bases or a controlled retrieval layer | Search approved source documents and return citations | Required before broad pilot |
| Source store | Amazon S3 | Store versioned source snapshots, exported artifacts and evaluation fixtures | Required |
| Record store | Amazon DynamoDB | Store verification context records, job state, source registry metadata and idempotency keys | Required |
| Async control | Amazon SQS, EventBridge or Step Functions | Decouple long-running ingestion, evaluation and evidence workflows | Optional for MVP; required for async scale |
| Tools | AgentCore Gateway | Expose governed MCP/API/Lambda tools to the agent | Phase 2 |
| Identity | IAM, AgentCore Identity and workload identity | Separate user, runtime and downstream tool credentials | Required for protected integrations |
| Policy | AgentCore Policy with Cedar | Enforce tool-level and input-level allow/deny decisions at the gateway boundary | Phase 2 before tool use |
| Memory | AgentCore Memory plus domain promotion rules | Store approved session and long-term QA knowledge | Phase 2 |
| Observability | CloudWatch, OpenTelemetry/OpenInference and CloudTrail | Trace model/tool calls, policy decisions, latency, errors and audit events | Required |
| Evaluation | AgentCore Evaluations plus a golden dataset | Measure grounding, task completion, tool behavior and regressions | Required before model/prompt rollout |

## 4. Required Diagrams

The HTML rendering must contain seven diagrams. Each diagram must use labeled frames and a legend so ownership is visible without reading the surrounding prose.

### Diagram 1: AWS deployment and network boundary

Show:

- Human/user machine outside AWS.
- ETUS local runner and local artifact directory.
- Third-party systems outside the AWS account.
- AWS account and region frame.
- Public ingress boundary, AgentCore Runtime boundary and data plane boundary.
- VPC, private subnets, security groups, VPC endpoints and optional VPC Lattice/private service path.
- S3, DynamoDB, CloudWatch, Bedrock, Knowledge Bases and optional Gateway.
- Trust direction and network direction on each arrow.

The diagram must mark which paths are internet-facing, AWS service-to-service, private VPC, or local-only.

### Diagram 2: Component and container boundary

Show the logical containers:

- QA workbench/API.
- Policy precheck and redaction.
- Retrieval/source registry.
- Prompt and output contract validator.
- Bedrock model invocation.
- Verification Context Record store.
- ETUS adapter/evidence bridge.
- Tool gateway and approval service.
- Observability/evaluation pipeline.

Each container must be mapped to its owner and its likely AWS implementation.

### Diagram 3: Ticket-to-final-QA-note sequence

Show the ordered runtime sequence:

1. QA submits ticket context.
2. Authentication and project authorization.
3. PII/secret precheck.
4. Approved source retrieval.
5. Bedrock inference with Guardrails.
6. Structured output and grounding validation.
7. QA review and clarification.
8. ETUS/manual test execution.
9. Evidence attachment.
10. Final QA note and optional memory promotion.

Show failure branches for missing source, unsupported claim, denied tool action and incomplete evidence.

### Diagram 4: Knowledge Base and memory lifecycle

Separate:

- Source ingestion and source registry.
- Approved retrieval context.
- Session context.
- Candidate memory.
- Confirmed, evidence-backed memory.
- Expired or contradicted memory.

The diagram must show that model output alone cannot promote a memory entry. Promotion requires human confirmation or execution evidence according to the memory policy.

### Diagram 5: ETUS execution and evidence flow

Show:

- Cloud control plane creating a test intent and execution request.
- Local ETUS runner receiving only an authorized, bounded request.
- Browser/API/mobile/device adapters.
- Target test environment.
- Local artifacts, logs, screenshots, video and result metadata.
- Upload or link-back path to AWS evidence storage.
- Human QA ownership of final interpretation.

The diagram must distinguish local-only device access from cloud-accessible test targets.

### Diagram 6: Security, observability and evaluation flow

Show the cross-cutting controls:

- IAM/user identity.
- Workload identity.
- AgentCore Gateway authentication.
- Cedar policy decision.
- Guardrail decision.
- CloudTrail audit event.
- CloudWatch logs/metrics/traces.
- Evaluation dataset and evaluator result.
- Release gate for prompt/model/source/tool changes.

### Diagram 7: Event-driven AWS workflow

Show the asynchronous control plane separately from the synchronous agent call:

- CloudFront/WAF/Cognito or enterprise OIDC and API Gateway ingress.
- Lambda validation and idempotency adapter.
- EventBridge domain event bus.
- SQS work queue with visibility timeout and dead-letter queue.
- Lambda worker or AgentCore Runtime consumer.
- Step Functions workflow for retries, waits, human approval and evidence processing.
- Bedrock/Knowledge Bases synthesis path.
- S3 artifacts, DynamoDB job state and SNS notification fan-out.
- CloudWatch/CloudTrail operational and audit path.

The diagram must state that EventBridge, SNS and SQS use at-least-once delivery patterns, consumers must be idempotent, and the DLQ requires an operational replay owner.

## 5. Data Contracts Represented in the Diagrams

The diagrams must name the following contracts, even if their full schemas remain in a separate data-model document:

- Ticket Intake Contract.
- Source Registry Contract.
- Retrieval Request and Citation Contract.
- Verification Context Record.
- Evidence Record.
- Memory Entry and Promotion Decision.
- Tool Invocation and Approval Record.
- Evaluation Case and Evaluation Result.

Every record that crosses a boundary must carry `project_id`, `ticket_id`, `session_id`, `trace_id`, `source_set_id`, `created_at`, `actor_id` and `schema_version` where applicable.

## 6. Security and Cloud Configuration Decisions

The Cloud team must be able to derive these configuration requirements from the package:

- Use separate IAM roles for human invocation, AgentCore Runtime execution and downstream integrations.
- Store secrets in AWS Secrets Manager or an approved identity exchange path; never place credentials in prompts, records or artifacts.
- Use resource policies and source conditions for Runtime, Gateway and Memory where supported.
- Use private connectivity for internal services and databases; do not place private test infrastructure on a public endpoint merely to simplify the diagram.
- Apply least-privilege security groups to AgentCore VPC connectivity and private service paths.
- Keep third-party tools read-only until approval, audit and rollback are implemented.
- Enforce source and project boundaries before retrieval and before tool invocation.
- Redact or reject sensitive ticket content before it reaches model context when policy requires it.
- Record model, prompt, guardrail, source set, policy decision and user approval versions for replay.

## 7. Non-Goals

- No autonomous release approval.
- No unrestricted browser, shell or production-system access.
- No assumption that the ticket is the business truth.
- No managed Memory rollout before promotion, contradiction and expiry behavior is evaluated.
- No claim that every AWS service shown is required in the MVP.

## 8. Acceptance Criteria

- A Cloud engineer can identify the AWS account, region, VPC, subnet, security group, endpoint and service boundary from the deployment diagram.
- A QA engineer can follow the ticket-to-evidence flow and see where human approval is required.
- An AI engineer can identify retrieval, prompt, output validation, guardrail and evaluation boundaries.
- A software engineer can identify the contracts and durable records needed for implementation.
- A security engineer can identify identity, policy, secret, private-network and audit controls.
- Every diagram labels MVP versus Phase 2 capability.
- HTML diagrams remain readable on desktop and horizontally scrollable on smaller screens.
- Markdown remains the source of truth and links back to the proposal and Bedrock ecosystem primer.

## 9. Research Basis

- [Amazon Bedrock AgentCore overview](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/)
- [AgentCore Gateway](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway.html)
- [AgentCore Policy and Cedar](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/policy.html)
- [AgentCore VPC connectivity](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-vpc.html)
- [Private connectivity with VPC Lattice](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/vpc-egress-private-endpoints.html)
- [AgentCore resource-based policies](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/resource-based-policies.html)
- [AgentCore observability](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/observability-configure.html)
- [Bedrock Guardrails with Converse](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails-use-converse-api.html)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
