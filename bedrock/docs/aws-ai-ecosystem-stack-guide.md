# Ban do he sinh thai AI cua AWS

Ngay xac minh: 2026-07-22

Tai lieu nay bo sung cho visualization `aws-ai-project-stack-map.html`. Muc tieu la giup hinh dung AWS cho minh nhung stack nao khi build ung dung AI, genAI, agent va ML production.

## 1. Nhin tong the

AWS AI ecosystem co the chia thanh 8 stack:

1. **Ready-made AI assistants**: Amazon Q Business, Amazon Q Developer, Amazon Q in QuickSight, Contact Center AI.
2. **Generative AI platform**: Amazon Bedrock, model access, inference, prompt management, guardrails, knowledge bases, flows, model evaluation/customization.
3. **Agent production platform**: Amazon Bedrock AgentCore, runtime, harness, gateway, memory, identity, browser/code/web-search tools, observability, evaluation, policy, registry.
4. **ML platform**: Amazon SageMaker AI, Studio, training, tuning, inference, pipelines, feature store, model cards, Clarify, Model Monitor, managed MLflow.
5. **Applied AI APIs**: Textract, Transcribe, Polly, Translate, Comprehend, Rekognition, Lex, Personalize, Forecast va cac service API AI theo domain.
6. **Data/RAG/search layer**: S3, S3 Vectors, Glue, Lake Formation, Athena, Redshift, OpenSearch, Aurora/PostgreSQL vector, Kendra, Bedrock Knowledge Bases.
7. **Application and integration runtime**: Lambda, Step Functions, EventBridge, API Gateway, AppSync, ECS/EKS, Connect, Kinesis, SNS/SQS.
8. **Security, governance, and operations**: IAM, IAM Identity Center, KMS, VPC/PrivateLink, CloudWatch, CloudTrail, CloudFormation/CDK/Terraform, Organizations AI opt-out, Macie, Config.

## 2. Stack nao dung khi nao?

| Stack | Khi nen dung | AWS cho minh | Minh van phai tu quyet dinh |
|---|---|---|---|
| Amazon Q | Can assistant co san cho employee/developer | Enterprise assistant, IDE assistant, permission-aware answers | Data connectors, access policy, rollout, adoption |
| Bedrock | Can build genAI app bang foundation model | Model access, inference, prompt, guardrail, RAG, flow | Prompt contract, model choice, cost/latency, eval |
| AgentCore | Can deploy/operate agent production | Runtime, memory, gateway, identity, tool, observability, eval | Agent boundary, tool schema, policy, quality loop |
| SageMaker AI | Can custom ML/FM lifecycle | Studio, training, tuning, inference, MLOps | Dataset, features, algorithm, experiment, model governance |
| Applied AI APIs | Can API AI ready-made | OCR, speech, translation, NLP, vision, bot | Input quality, human review, compliance, UX fallback |
| Data/RAG/search | Can dua enterprise data vao AI | Storage, catalog, vector/search, governed access | Data freshness, ACL, chunking, lineage, tenant boundary |
| Runtime/integration | Can gan AI vao product/workflow | Events, APIs, orchestration, containers, queues | Failure handling, retries, approvals, idempotency |
| Security/ops | Can productionize safely | Identity, encryption, logs, audit, deployment IaC | Least privilege, SLO, runbook, incident process |

## 2A. Mental model cho software engineer

Dung ban do nay theo thu tu tu tren xuong:

1. **Amazon Q la managed product**: minh enable/rollout assistant co san cho employee, developer, BI user. Day la duong nhanh nhat neu bai toan khop UX va permission model cua AWS.
2. **Bedrock la genAI application platform**: minh build custom app bang foundation model, prompt contract, guardrail, RAG, flow va evaluation. Day la lop nen bat dau cho chatbot/RAG/custom generation.
3. **AgentCore la production infrastructure cho agent**: minh van phai viet agent boundary/business logic, nhung AWS cung cap runtime, harness, gateway, memory, identity, policy, observability, evaluation va optimization.
4. **SageMaker AI la ML/model lifecycle platform**: dung khi minh can train/tune/host custom model, data science workflow, feature store, model monitor, model card, pipeline va governance.
5. **Data, runtime, security la lop bat buoc**: S3/vector/search, Lambda/ECS/EKS/Step Functions, IAM/KMS/VPC/CloudWatch/CloudTrail khong phai "AI feature" nhung quyet dinh he thong co chay production duoc hay khong.

Mot cach chon nhanh:

```text
Need ready-made assistant?      -> Amazon Q
Need custom LLM/RAG app?        -> Bedrock
Need agent goi tool/memory?     -> AgentCore
Need custom model/MLOps?        -> SageMaker AI
Need OCR/speech/vision API?     -> Applied AI APIs
Need governed enterprise data?  -> Data/RAG/search layer
Need production workflow?       -> Runtime + security + ops layer
```

## 2B. Decision matrix cho du an thuc te

| Neu request/product can | Chon chinh | Them khi nao | Ly do |
|---|---|---|---|
| Employee hoi tai lieu noi bo, can ACL nhanh | Amazon Q Business | Them custom app sau neu can UX/workflow rieng | Q da co assistant UX, connectors, permission-aware retrieval va rollout model |
| Developer assistant trong IDE/CLI | Amazon Q Developer | Them internal MCP/tools neu team can platform hoa | Giam effort build assistant tu dau |
| Chat/RAG tren data cua product | Bedrock + Knowledge Bases + Guardrails | Them Flows/Step Functions neu co workflow node ro | Model, prompt, retrieval, citation va guardrail nam trong mot lop genAI app |
| Workflow deterministic: retrieve -> transform -> call API -> respond | Bedrock Flows hoac app backend/Step Functions + Bedrock | Them AgentCore neu can agent tu lap ke hoach | Flow/state machine de test, retry, approve va rollback de hon autonomous loop |
| Agent phai goi tool nhieu buoc, co memory, identity, policy | AgentCore Runtime/Harness + Gateway + Memory + Policy | Bedrock lam model provider; Lambda/API/MCP lam tools | AgentCore giai quyet session isolation, tool access, auth, trace va eval |
| Internal APIs can expose cho nhieu agent | AgentCore Gateway + Registry | Them Policy/Identity cho production | Gateway chuan hoa Lambda/OpenAPI/MCP thanh tool entrypoint co governance |
| Custom classification/ranking/forecasting/model artifact | SageMaker AI | Bedrock co the goi SageMaker endpoint nhu tool/API | SageMaker phu hop train/tune/deploy/monitor custom model hon |
| OCR, speech-to-text, translation, vision, NLP ready-made | Textract/Transcribe/Translate/Rekognition/Comprehend/Lex | Bedrock/AgentCore reasoning tren output neu can | API chuyen dung re hon, de operate hon LLM neu task khop |

## 2C. Cost model nen lap truoc khi spike

AI cost khong chi la token. Nen tinh theo request/session va tach cac dong chi phi sau:

### Bedrock RAG app

```text
Cost/request =
  model input tokens
+ model output tokens
+ prompt cache/cache write neu dung
+ Knowledge Base storage/indexing/retrieval
+ embedding/reranking neu dung custom model
+ Guardrails input/output evaluation
+ Lambda/ECS/EKS/API Gateway/app runtime
+ vector/search/data-store storage
+ CloudWatch logs/metrics/traces
+ data transfer va retry overhead
```

Risk cost chinh: prompt/context qua dai, retrieval tra qua nhieu chunk, output dai, guardrail/rerank bat tren moi request, log payload qua day, retry khong co idempotency.

### AgentCore agent

```text
Cost/session =
  model tokens cho moi reasoning step
+ AgentCore Runtime CPU/memory active consumption
+ Gateway list/invoke/search/tool-indexing calls
+ Policy authorization requests cho tool calls
+ Identity token/API-key requests neu dung non-AWS resources
+ Memory short-term events, long-term records, retrieval
+ Browser/Code Interpreter CPU/memory neu dung
+ Web Search queries neu dung
+ CloudWatch telemetry
+ Evaluation sampling/batch/A-B test
```

Risk cost chinh: agent loop khong gioi han iteration, tool call fan-out, web search/browser lam mac dinh, memory ghi qua nhieu, eval sampling qua cao, trace/log giu payload lon.

### Amazon Q Business

```text
Cost/month =
  user subscriptions
+ index units per hour
+ connector/indexing capacity
+ media/document processing
+ optional API/embedded chat consumption
```

Risk cost chinh: index ton tai se tiep tuc tinh tien, connector sync nhieu data khong can thiet, rollout Pro cho user chua dung that.

### SageMaker AI

```text
Cost/month =
  Studio/domain/notebook/compute
+ training/tuning jobs
+ endpoint instance/serverless/async/batch inference
+ storage/artifacts/features
+ pipelines/processing jobs
+ Model Monitor/Clarify/CloudWatch
```

Risk cost chinh: endpoint realtime chay idle, notebook/Studio resources de quen, training job lap lai khong track, endpoint scale qua muc.

## 2D. Production readiness checklist

Truoc khi dua vao pilot voi user that, can co toi thieu:

- Account, region, service availability, model access va quota da xac minh.
- IAM roles theo least privilege; tach deploy role, runtime role, data-access role.
- KMS, VPC/PrivateLink, data residency, logging policy da quyet dinh.
- Tenant boundary va ACL model ro rang; test user khong doc duoc data ngoai quyen.
- Prompt contract/versioning va release/rollback strategy.
- RAG source-of-truth, freshness SLA, chunking, metadata filter, citation policy.
- Tool catalog: schema, owner, timeout, retry, rate limit, idempotency, destructive-action approval.
- Guardrail/policy test cases: prompt attack, PII, denied topics, forbidden tool call.
- Golden dataset va evaluation rubric: accuracy, groundedness, refusal quality, tool success, latency.
- Observability: correlation id, spans, token count, model latency, retrieval latency, tool latency, error taxonomy.
- Budget/quota alarms: tokens, retrieval, Gateway calls, Web Search, Browser/Code Interpreter, CloudWatch ingestion.
- Incident runbook: model outage, retrieval degradation, tool failure, cost spike, bad answer, credential issue.

## 3. Bedrock stack

Bedrock la lop genAI platform. Neu anh chi can goi model, RAG, guardrail, prompt version, hoac workflow genAI co node ro rang, Bedrock la diem bat dau.

Thanh phan can doc ky:

- Model access va inference: model, latency, region, cost, quota.
- Prompt Management: version prompt, variables, inference parameters.
- Guardrails: content filters, denied topics, sensitive information, prompt attack filters.
- Knowledge Bases: RAG managed, citations, vector stores, structured data, graph/multimodal options.
- Flows: workflow visual noi prompt, foundation model, Knowledge Base, Lambda va AWS services.
- Model evaluation/customization/import: khi can so sanh, tinh chinh, hoac dung model rieng.
- Agents Classic: nen xem nhu legacy/maintenance path cho du an moi, vi AWS docs hien dinh huong AgentCore cho production agents moi.

## 4. AgentCore stack

AgentCore la lop de host va operate agent, framework/model agnostic. No khong thay minh viet business logic, nhung giam phan ha tang lap lai cho agent production.

Thanh phan can doc ky:

- Runtime: host agent/tool code, serverless, session isolation, endpoints, versions.
- Harness: managed agent loop cho truong hop muon khai bao model/tools/context ma khong viet loop day du.
- Gateway: bien API, Lambda, OpenAPI/Smithy, MCP server, model provider thanh tool entrypoint co auth va policy.
- Memory: short-term va long-term memory.
- Identity: inbound auth, outbound credentials, OAuth/API key, workload identity.
- Built-in tools: Browser, Code Interpreter, Web Search.
- Observability: traces, logs, metrics, CloudWatch/OpenTelemetry.
- Evaluations/Optimization: online/on-demand/batch eval, recommendation, A/B testing.
- Policy/Registry: deterministic tool-call control va catalog/approval workflow.

## 5. SageMaker AI stack

SageMaker AI la lop ML platform. Dung khi can train/fine-tune/custom model, MLOps, experiment tracking, inference endpoint, governance model, hoac data science workflow.

Thanh phan can doc ky:

- Studio/Unified Studio: workspace cho data science/ML.
- Training/tuning: managed training jobs, distributed training, hyperparameter tuning.
- Inference: realtime, batch, async/serverless options.
- Pipelines: MLOps workflow.
- Feature Store: quan ly features.
- Model Cards, Clarify, Model Monitor: governance, explainability, drift/quality monitoring.
- Managed MLflow: experiment tracking cho ML/genAI.

## 6. Tai lieu nen chuan bi cho moi stack

### Tai lieu chung

- Use-case brief: ai dung, workflow nao, success criteria nao.
- Decision matrix: Amazon Q vs Bedrock vs AgentCore vs SageMaker.
- Security baseline: account, region, IAM, KMS, VPC, audit log, data residency.
- Cost model: model/runtime/tool cost, quotas, expected traffic.
- Evaluation rubric: golden set, metrics, thresholds, failure categories.

### Cho Bedrock/genAI app

- Prompt contract: input/output schema, examples, failure policy.
- RAG design: data source, ACL, chunking, vector store, refresh cadence, citations.
- Guardrail policy: allowed/denied content, PII, prompt attack handling.
- Flow map: nodes, retries, Lambda/API integration, alias/version release.

### Cho AgentCore/agent platform

- Agent boundary spec: what agent can/cannot do.
- Tool catalog: schema, owner, permission, rate limit, idempotency.
- Identity model: user-delegated vs service-to-service vs agent identity.
- Memory policy: what to remember, retention, delete/export, tenant namespace.
- Evaluation plan: session/trace/span evaluators, online sampling, release gate.
- Observability runbook: traces, metrics, dashboards, alerts, incident steps.

### Cho SageMaker/ML

- Dataset card: source, label quality, split, bias, privacy.
- Experiment plan: baseline, metrics, hyperparameters, tracking.
- Model card: intended use, limitation, eval result, owner, approval.
- Deployment runbook: endpoint type, scaling, rollback, monitoring.

## 7. Learning path de bat dau

1. **Mot ngay**: doc decision guide AWS genAI/ML, Bedrock overview, SageMaker overview, Amazon Q overview.
2. **Hai ngay**: doc Bedrock Knowledge Bases, Guardrails, Flows, Prompt Management; chon mot RAG/workflow use case.
3. **Ba ngay**: doc AgentCore overview va `awslabs/agentcore-samples`; deploy mot agent nho bang AgentCore CLI.
4. **Bon ngay**: them Gateway, Memory, Identity, Observability vao spike.
5. **Nam ngay**: viet evaluation rubric, run eval, tao production-readiness checklist.

## 8. Data flow thuc te khi co request

### Flow A: GenAI/RAG app tren Bedrock

1. User gui request vao web/mobile/API.
2. App layer xac thuc user, lay tenant/context, ghi correlation id.
3. Optional guardrail input check de chan prompt attack/PII/noi dung cam.
4. App goi Bedrock Knowledge Base de retrieve context tu data source/vector store.
5. App ghep prompt contract + retrieved context + user query.
6. App goi Bedrock Converse/InvokeModel hoac Flow.
7. Optional guardrail output check.
8. App tra response co citation, log trace, metrics, token/cost.

Dung khi tac vu chinh la hoi-dap, summarization, extraction, generation co data.

### Flow B: Agent production tren AgentCore

1. User request vao product app hoac API endpoint cua agent.
2. Identity layer xac thuc user/service, tao session va permission context.
3. AgentCore Runtime/Harness nhan request va gan session isolation.
4. Agent doc short-term/long-term memory neu can.
5. Agent lap ke hoach va chon tool.
6. Tool call di qua AgentCore Gateway.
7. Gateway check policy/identity/credential, roi goi Lambda/API/MCP/server/service ben ngoai.
8. Ket qua tool quay lai agent; agent co the lap nhieu vong.
9. Agent tao final answer/action result.
10. Observability ghi trace/span/tool latency; Evaluations cham session/trace theo sampling.
11. Memory update nhung thong tin duoc phep nho.

Dung khi agent can goi tool nhieu buoc, chay dai, co memory, co auth/policy ro rang.

### Flow C: ML inference tren SageMaker AI

1. Request vao application/API Gateway/Lambda/service backend.
2. App validate input, transform features, lay feature tu Feature Store neu can.
3. App goi SageMaker endpoint hoac batch/async inference.
4. Endpoint load model artifact/container va tra prediction.
5. App ap dung business rule, threshold, human review neu confidence thap.
6. Model Monitor/CloudWatch ghi drift, latency, error, quality.
7. Neu co drift/regression, retraining pipeline chay lai bang SageMaker Pipelines.

Dung khi output la prediction/classification/ranking/custom model hon la natural-language agent.

### Flow D: Amazon Q Business

1. Employee hoi trong Amazon Q Business web experience/chat.
2. Q xac thuc user qua IAM Identity Center/IdP.
3. Q ap dung permission-aware retrieval tren enterprise connectors/index.
4. Q generate answer co citation theo document user duoc phep xem.
5. Admin theo doi connectors, data sync, feedback, access policy.

Dung khi minh muon assistant enterprise co san thay vi build custom RAG app.

## 9. Request journey qua cac stack AWS

Mot request production thuong khong di thang tu user vao model. No di qua cac lop sau:

1. **Channel/app edge**: web/mobile/chat/API, CloudFront, API Gateway, ALB, Lambda/ECS/EKS.
2. **Security/context**: IAM/Cognito/IAM Identity Center, tenant context, KMS/VPC, input guardrail.
3. **Orchestration**: Bedrock Flow, app backend, AgentCore Runtime/Harness, Step Functions.
4. **Knowledge/tool/model work**:
   - RAG: Knowledge Base -> vector/search/data source -> Bedrock model.
   - Agent: Memory -> planning -> Gateway -> tools/APIs/Lambda/MCP -> model.
   - ML: feature transform -> SageMaker endpoint -> model artifact.
5. **Action/response**: final answer, citation, action result, approval/rollback neu co.
6. **Governance loop**: CloudWatch/CloudTrail traces, evaluations, model/tool metrics, cost, memory update/retraining.

Tu khoa de thiet ke: request path la data plane; setup guide/IaC/evaluation/runbook la control plane. Neu chi ve data plane ma thieu control plane, he thong se kho operate.

## 10. Setup guide theo tung cum

### Cum 0: Nen tang account va security

1. Chon AWS account/region va xac dinh data residency.
2. Tao IAM roles theo least privilege; bat IAM Identity Center neu co nhieu users.
3. Chuan bi KMS keys, VPC/PrivateLink neu workload can private networking.
4. Bat CloudTrail/CloudWatch baseline, tagging, budget/quota alert.
5. Viet security baseline: ai co quyen deploy, ai co quyen doc data, log gi duoc giu.

### Cum 1: Amazon Q assistant

1. Chon Q Business hay Q Developer.
2. Voi Q Business: tao application, ket noi data sources, cau hinh user/group/ACL mapping.
3. Kiem tra answers co citation va user khong thay document ngoai quyen.
4. Rollout pilot cho mot nhom nho, thu feedback, them connector.
5. Voi Q Developer: setup trong IDE/CLI/console, cau hinh workforce identity va policy.

### Cum 2: Bedrock genAI app

1. Mo Bedrock console va xac nhan model access/region/quota.
2. Chon API path: Converse/InvokeModel, Prompt Management, Knowledge Base, hoac Flow.
3. Tao prompt contract va test trong playground/local script.
4. Neu RAG: chuan bi data source, vector store, sync job, citation policy.
5. Them Guardrails cho input/output va prompt attack/PII.
6. Tao evaluation set truoc khi release.
7. Deploy app backend qua Lambda/ECS/EKS/API Gateway tuy product.

### Cum 3: AgentCore agent platform

1. Cai AgentCore CLI va chuan bi AWS credentials.
2. Scaffold project: `agentcore create`.
3. Chay local: `agentcore dev`.
4. Deploy agent: `agentcore deploy`.
5. Invoke va doc logs/traces: `agentcore invoke`.
6. Them capabilities theo thu tu an toan: Memory -> Gateway/tools -> Identity -> Policy -> Observability/Evaluations.
7. Chuan hoa tool catalog va evaluation rubric truoc khi mo cho users that.

### Cum 4: SageMaker AI/ML

1. Tao SageMaker AI Domain va user profile; dung quick setup cho ca nhan, custom setup cho org.
2. Mo Studio/Unified Studio.
3. Chuan bi dataset, S3 location, IAM role, KMS/VPC neu can.
4. Chay notebook/training job hoac Canvas/no-code path.
5. Track experiment bang MLflow/Pipelines.
6. Deploy endpoint hoac batch/async inference.
7. Them Model Monitor, Clarify, Model Card, rollback plan.

### Cum 5: Applied AI APIs

1. Chon API theo input: Textract/document, Transcribe/audio, Translate/language, Comprehend/NLP, Rekognition/image, Lex/chatbot.
2. Tao IAM role/API permissions va data bucket neu can.
3. Test voi sample input that, ghi confidence/errors.
4. Thiet ke human review cho case low confidence/high risk.
5. Dua output API vao Bedrock/AgentCore neu can reasoning tiep.

### Cum 6: Data/RAG/search

1. Inventory data sources, owner, classification, freshness.
2. Quyet dinh storage/search: S3/S3 Vectors, OpenSearch, Aurora vector, Redshift/Athena, Kendra.
3. Map ACL/tenant boundary truoc khi ingest.
4. Chon chunking/embedding/rerank/citation strategy.
5. Tao sync job va monitoring freshness.
6. Kiem tra retrieval bang question set truoc khi goi model.

### Cum 7: Runtime/integration va ops

1. Ve workflow: request, state, action, retry, approval, rollback.
2. Chon Lambda/Step Functions/EventBridge/API Gateway/ECS/EKS/AppSync.
3. Gan observability: CloudWatch metrics/logs, traces, alarms.
4. Gan audit: CloudTrail, structured app logs, correlation id.
5. IaC hoa bang CDK/CloudFormation/Terraform.
6. Tao runbook: incident, quota, cost spike, model/tool failure.

## 11. Nguon chinh

- AWS: [Choosing an AWS generative AI service](https://docs.aws.amazon.com/generative-ai-on-aws-how-to-choose/)
- AWS: [Choosing an AWS machine learning service](https://docs.aws.amazon.com/decision-guides/latest/machine-learning-on-aws-how-to-choose/guide.html)
- AWS: [Amazon Bedrock documentation](https://docs.aws.amazon.com/bedrock/)
- AWS: [Amazon Bedrock quickstart](https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started.html)
- AWS: [Amazon Bedrock Knowledge Bases](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- AWS: [Amazon Bedrock Guardrails](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- AWS: [Amazon Bedrock Flows](https://docs.aws.amazon.com/bedrock/latest/userguide/flows.html)
- AWS: [Amazon Bedrock AgentCore overview](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- AWS: [Get started with Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-get-started-cli.html)
- AWS: [AgentCore harness vs Runtime](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness-vs-runtime.html)
- AWS: [Amazon Bedrock Agents Classic maintenance mode](https://docs.aws.amazon.com/bedrock/latest/userguide/agents-classic-maintenance-mode.html)
- AWS: [Amazon Bedrock pricing](https://aws.amazon.com/bedrock/pricing/)
- AWS: [Amazon Bedrock AgentCore pricing](https://aws.amazon.com/bedrock/agentcore/pricing/)
- AWS: [Amazon Q Business pricing](https://aws.amazon.com/q/business/pricing/)
- AWS: [Amazon SageMaker pricing](https://aws.amazon.com/sagemaker/pricing/)
- AWS: [Amazon SageMaker AI documentation](https://docs.aws.amazon.com/sagemaker/)
- AWS: [Guide to getting set up with Amazon SageMaker AI](https://docs.aws.amazon.com/sagemaker/latest/dg/gs.html)
- AWS: [Amazon Q documentation](https://docs.aws.amazon.com/amazonq/)
- AWS: [AWS machine learning services overview](https://docs.aws.amazon.com/machine-learning/)
- GitHub: [awslabs/agentcore-samples](https://github.com/awslabs/agentcore-samples)
