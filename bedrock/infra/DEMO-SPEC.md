# Demo Spec: Verify Ticket Agent

Status: Draft  
Date: 2026-07-24  
Duration target: 15-20 phut demo

## 1. Demo Objective

Trinh bay mot Bedrock Agent co kha nang:
1. **Nhan ticket ID tu ClickUp** -> lay ticket details, acceptance criteria, context
2. **Query Knowledge Base (RAG)** -> tim codebase docs, architecture notes, lịch sử thay doi lien quan
3. **Su dung Memory** -> nho context tu cac session truoc, history verify cu
4. **Tra ve Verification Context** -> structured output giup QA hieu scope, risk, test suggestion

## 2. Demo Flow (Script)

```
[Demo Person]
"Toi la QA, toi vua nhan ticket CU-12345: 'Add retry logic to payment service'"

[Goi Agent]
> "Verify ticket CU-12345"

[Agent internally]
1. Action Group: ClickUp -> GET /task/CU-12345
   -> Lay: title, description, assignee, status, custom fields, comments
   
2. Knowledge Base: RAG query
   -> Query: "payment service retry logic architecture"
   -> Returns: relevant docs voi citations (payment-service.md, error-handling.md, etc.)

3. Memory: Check history
   -> Query: "CU-12345" + "payment service"
   -> Returns: previous verification notes, related tickets verified before

4. Synthesize -> Verification Context Record

[Agent Response]
---
## Verification Context: CU-12345

### Ticket Summary
- Title: Add retry logic to payment service
- Assignee: @engineer-name
- Sprint: Sprint 42
- Priority: High

### Relevant Codebase Context
- Payment service uses `src/services/payment/` (citation: payment-service.md)
- Current error handling: fail-fast, no retry (citation: error-handling.md)
- Related past changes: CU-11890 added timeout config

### Risk Assessment
- HIGH: Payment double-charge if retry is not idempotent
- MEDIUM: Timeout cascade if retry count too high
- LOW: Log noise from retry attempts

### Suggested Test Areas
1. Idempotency: same request retried should not double-charge
2. Max retry limit: verify circuit breaker behavior
3. Timeout: retry should respect overall timeout budget
4. Logging: each retry attempt logged with attempt number
5. Error codes: which HTTP codes trigger retry vs fail

### Previous Verification Memory
- CU-11890 (timeout config): verified 2026-06-15, no regression found
- Payment service last major change: 2026-05-20

### Confidence
- Codebase coverage: 3 relevant docs found
- Business rule coverage: partial (need product confirm on retry policy)
- Missing: retry policy document not found in KB
---
```

## 3. Technology Stack

### Core AWS Services

| Layer | Service | Role trong demo |
|---|---|---|
| Agent | Amazon Bedrock Agent | Orchestration, tool routing, response synthesis |
| Model | Claude 3.5 Sonnet (Bedrock) | Reasoning, synthesis, structured output |
| RAG | Bedrock Knowledge Base | Codebase docs + architecture docs retrieval |
| Vector Store | OpenSearch Serverless | Embedding storage + similarity search |
| Storage | S3 | Document source cho Knowledge Base |
| Compute | Lambda (Python) | ClickUp API handler, Memory handler |
| Memory | DynamoDB | Conversation history, verification records |
| Secrets | Secrets Manager | ClickUp API token |
| IaC | Terraform | Toan bo infrastructure |

### External Integrations

| System | Integration Method | Data |
|---|---|---|
| ClickUp | REST API v2 (via Lambda) | Task details, comments, custom fields |
| Codebase docs | S3 upload (pre-ingested) | Architecture docs, READMEs, RFCs |
| RAG documents | S3 upload (pre-ingested) | Historical verification notes, QA history |

### Agent Configuration

```yaml
Agent:
  name: "verify-ticket-agent"
  model: anthropic.claude-3-5-sonnet-20241022-v2:0
  instruction: |
    You are a QA verification assistant. When given a ticket ID:
    1. Fetch ticket details from ClickUp
    2. Search the knowledge base for relevant codebase and architecture context
    3. Check memory for previous verification history
    4. Produce a structured Verification Context Record
    
    Always cite sources. Flag risks clearly. Never auto-pass/fail.
    
  action_groups:
    - name: ClickUpActions
      lambda: clickup-handler
      actions:
        - GetTask: Fetch task by ID
        - GetTaskComments: Fetch comments on a task
        - SearchTasks: Search related tasks
        
    - name: MemoryActions  
      lambda: memory-handler
      actions:
        - GetVerificationHistory: Get past verification records
        - SaveVerificationContext: Save current verification result
        - GetRelatedTickets: Find related verified tickets

  knowledge_bases:
    - name: codebase-docs
      description: "Architecture docs, READMEs, RFCs, technical specs"
      
    - name: qa-history
      description: "Historical QA notes, verification records, regression docs"
```

## 4. Knowledge Base Content Plan

### Collection 1: Codebase Docs
Upload vao S3 truoc demo:
- Architecture decision records (ADRs)
- Service READMEs
- API specs / OpenAPI docs
- Error handling guidelines
- Deployment runbooks

### Collection 2: QA History
Upload vao S3 truoc demo:
- Previous verification notes (markdown)
- Regression test results
- Known issues / limitations docs
- Release notes

### Embedding Strategy
- Chunking: 512 tokens, 20% overlap
- Model: Amazon Titan Embeddings v2
- Metadata filters: service_name, doc_type, last_updated

## 5. Memory Design

### Short-term (Session)
- Bedrock Agent built-in session memory
- Giu context trong 1 session verify

### Long-term (DynamoDB)

```
Table: verification-memory
PK: ticket_id
SK: timestamp
Attributes:
  - verification_context (JSON)
  - agent_session_id
  - qa_user_id
  - confidence_score
  - sources_cited
  - created_at
  - ttl (90 days)

GSI: service-index
PK: service_name
SK: timestamp
```

### Memory Query Patterns
1. By ticket: "Da verify ticket nay truoc chua?"
2. By service: "Nhung ticket nao lien quan payment service da verify?"
3. By time: "Verification history 30 ngay gan nhat"

## 6. Demo Preparation Checklist

### Truoc demo 1 tuan
- [ ] AWS Account setup + Bedrock model access enable
- [ ] Terraform apply thanh cong
- [ ] ClickUp API token configured
- [ ] 5-10 sample documents uploaded to S3
- [ ] Knowledge Base ingestion complete
- [ ] 3-5 sample verification records in DynamoDB

### Truoc demo 1 ngay
- [ ] Test full flow: invoke agent -> get response
- [ ] Prepare 2-3 ticket IDs for live demo
- [ ] Verify ClickUp API connectivity
- [ ] Check Knowledge Base retrieval quality
- [ ] Prepare backup screenshots/recording in case of issues

### Demo day
- [ ] Warm up agent (first invocation may be slow)
- [ ] Open AWS Console for visual walkthrough
- [ ] Have terminal ready for CLI invocation
- [ ] Backup: pre-recorded successful run

## 7. Demo Script (Chi tiet)

### Part 1: Introduction (2 phut)
- Problem: QA nhan ticket, phai tu tong hop context tu nhieu nguon
- Solution: Bedrock Agent tong hop context tu dong

### Part 2: Architecture Walkthrough (3 phut)
- Show architecture diagram (tu PLAN.md)
- Explain: Agent -> ClickUp + Knowledge Base + Memory -> Response
- Show AWS Console: Agent, KB, Lambda

### Part 3: Live Demo (8 phut)

**Scenario 1: New ticket verification**
```bash
aws bedrock-agent-runtime invoke-agent \
  --agent-id $AGENT_ID \
  --agent-alias-id $ALIAS_ID \
  --session-id "demo-001" \
  --input-text "Verify ticket CU-12345"
```
- Show agent fetching from ClickUp
- Show RAG retrieval with citations
- Show structured output

**Scenario 2: Follow-up question (Memory)**
```bash
aws bedrock-agent-runtime invoke-agent \
  --agent-id $AGENT_ID \
  --agent-alias-id $ALIAS_ID \
  --session-id "demo-001" \
  --input-text "What was verified for payment service last month?"
```
- Show memory recall from DynamoDB
- Show context continuity

**Scenario 3: Save verification (optional)**
```bash
aws bedrock-agent-runtime invoke-agent \
  --agent-id $AGENT_ID \
  --agent-alias-id $ALIAS_ID \
  --session-id "demo-001" \
  --input-text "Save this verification context for CU-12345"
```

### Part 4: Q&A + Next Steps (5 phut)
- Cost: ~$15-35/month for dev
- Next: AgentCore Runtime, Gateway, Policy
- Timeline: 2 weeks MVP -> 1 month pilot

## 8. Success Criteria cho Demo

| Criteria | Target |
|---|---|
| Agent tra loi trong | < 15 seconds |
| ClickUp data chinh xac | Ticket title + description khop |
| RAG co citation | >= 2 relevant docs cited |
| Memory recall | Tra ve history neu co |
| Structured output | Co sections: Summary, Risk, Test Areas |
| Khong hallucinate | Flag "not found" neu KB khong co |

## 9. Known Limitations (Neu trong demo)

- Knowledge Base quality phu thuoc vao documents uploaded
- ClickUp API rate limit: 100 req/min
- First invocation co cold start ~3-5s
- Memory hien tai la custom (DynamoDB), chua dung AgentCore Memory (Phase 2)
- Agent khong tu dong write back vao ClickUp (by design, read-only MVP)

## 10. Post-Demo Roadmap

| Phase | Timeline | Features |
|---|---|---|
| MVP (current) | Week 1-2 | Basic agent + ClickUp read + KB + DynamoDB memory |
| Phase 1.5 | Week 3-4 | Better prompts, more docs, evaluation metrics |
| Phase 2 | Month 2 | AgentCore Runtime, Gateway, managed Memory |
| Phase 3 | Month 3+ | Write-back to ClickUp, ETUS integration, CI/CD |
