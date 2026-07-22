# Nghien cuu AWS Bedrock va he sinh thai build agent

Ngay xac minh: 2026-07-22
Pham vi: Amazon Bedrock, Amazon Bedrock AgentCore, repo `awslabs/agentcore-samples`, va cac thanh phan AWS lien quan den viec build agent production.

## 1. Ket luan nhanh

Neu nhin AWS nhu mot "agent platform", AWS khong chi ban cho minh model. AWS dang co gang ban ca mot bo ha tang de dua agent tu prototype len production:

- Model layer: Amazon Bedrock cho truy cap foundation models, inference, prompt routing, model evaluation, custom/import model.
- App builder layer: Knowledge Bases, Guardrails, Prompt Management, Flows, Agents Classic.
- Agent production layer: Bedrock AgentCore cho runtime, memory, gateway/tools, identity, browser, code interpreter, observability, evaluation, optimization, policy, registry.
- Framework layer: AWS khong bat buoc dung mot SDK duy nhat. AgentCore duoc thiet ke framework/model agnostic, ho tro Strands Agents, LangGraph, CrewAI, LlamaIndex, Google ADK, OpenAI Agents SDK, custom framework, va nhieu model trong/ngoai Bedrock.

Diem can chu y nhat: Amazon Bedrock Agents doi ten thanh **Amazon Bedrock Agents Classic** va se khong mo cho khach hang moi tu **2026-07-30**. Voi du an moi, nen nghien cuu AgentCore truoc, chi xem Agents Classic nhu legacy/maintenance path neu co nhu cau cu the.

## 2. Mental model: AWS cho minh nhung gi?

### Lop 1: Foundation model va inference

Day la lop "goi model":

- Truy cap model qua Amazon Bedrock, bao gom model cua Amazon va nha cung cap thu ba.
- Quan ly inference: realtime, batch, provisioned throughput, cross-region inference, inference profiles.
- Quan ly prompt/model: Prompt Management, Prompt Routing, Evaluation, fine-tuning/distillation/import model.

Dung lop nay khi minh dang build mot ung dung LLM binh thuong: chatbot, summarizer, extractor, classifier, generation API.

### Lop 2: RAG va workflow

Day la lop "ung dung genAI co data va quy trinh":

- **Knowledge Bases**: managed RAG, citations, multimodal retrieval, reranking, data source/vector store/structured data/graph options.
- **Guardrails**: loc noi dung, prompt attack, sensitive information, policy an toan.
- **Prompt Management**: version va tai su dung prompt.
- **Flows**: visual workflow noi prompt, FM, Knowledge Base, Lambda va cac AWS service khac; publish immutable version va deploy qua alias.

Dung lop nay khi tac vu co luong ro rang: query docs, lay data, goi Lambda, tao report, gui request sang he thong khac.

### Lop 3: Agent production

Day la lop "agent thuc su chay dai hon, goi tool, co identity, co memory, co quan sat":

- **AgentCore Runtime**: host agent/tool code trong serverless runtime, co session isolation bang microVM, version/endpoint/rollback, HTTP/MCP/A2A.
- **AgentCore Harness**: managed agent loop. Minh khai bao model, system prompt, tools, skills; AWS quan ly orchestration, environment, memory, identity, networking, observability.
- **AgentCore Gateway**: bien API, Lambda, OpenAPI/Smithy, MCP server, agent khac, va inference provider thanh mot endpoint an toan cho agent.
- **AgentCore Memory**: short-term session memory va long-term memory persisted across sessions.
- **AgentCore Identity**: workload identity, inbound JWT, outbound OAuth/API-key credential management, truy cap AWS va third-party services.
- **AgentCore Tools**: Code Interpreter, Browser, Web Search.
- **AgentCore Observability/Evaluations/Optimization**: trace, debug, evaluate online/on-demand/batch, sinh recommendation, A/B test.
- **AgentCore Policy**: enforcement deterministic bang Cedar/natural language policy qua Gateway.
- **Agent Registry, Payments**: catalog/governance va microtransaction; hien dang co thanh phan preview.

Dung lop nay khi agent can production behavior: nhieu user, nhieu tool, auth ro rang, long-running task, audit, eval, rollback, governance.

## 3. AWS cho minh gi va khong cho gi?

AWS cho minh phan "production plumbing" ma agent prototype thuong thieu:

- Noi chay agent an toan: runtime/harness, microVM session isolation, version, endpoint, rollback.
- Noi ket noi tool: gateway bien API/Lambda/MCP/model provider thanh mot entrypoint co auth va observability.
- Noi giu context: memory ngan han/dai han, co namespace va co the chia se giua agents.
- Noi cap quyen: identity, credential provider, inbound/outbound auth, policy enforcement.
- Noi quan sat va cai tien: trace, log, metric, evaluation, recommendation, A/B testing.
- Noi dong goi thanh platform noi bo: registry, approval workflow, IaC, CLI, SDK, sample/blueprint.

AWS khong tu dong cho minh:

- Business semantics: agent nen lam gi, tool nao duoc goi, khi nao phai dung lai.
- Chat/task UX: giao dien nguoi dung, escalation flow, approval step, undo/rollback nghiep vu.
- Golden dataset va eval rubric: AWS co evaluator, nhung minh phai dinh nghia chat luong theo use case.
- Data governance chi tiet: memory retention, PII policy, document permission, tenant boundary.
- Chi phi hop ly mac dinh: can dat budget, quota, sampling, model routing, cache/retry strategy.
- Dam bao website/API ben ngoai on dinh: browser automation va third-party APIs van can fallback va monitoring.

Mot cach noi ngan: AWS giam phan ha tang lap lai; minh van phai thiet ke san pham, boundary, data, policy va quality loop.

## 4. AgentCore khac gi so voi Bedrock Agents Classic?

| Cau hoi | Bedrock Agents Classic | Bedrock AgentCore |
|---|---|---|
| Huong dung moi | Legacy/maintenance; khong mo cho khach hang moi tu 2026-07-30 | Huong moi cho production agent |
| Framework | AWS-managed agent config | Any framework/custom code |
| Model | Chu yeu trong he Bedrock | Model-agnostic, trong va ngoai Bedrock |
| Tooling | Action groups, Knowledge Bases, code interpreter, memory | Runtime, Harness, Gateway, Identity, Memory, Tools, Observability, Eval, Policy |
| Protocol | AWS-specific agent API | HTTP, MCP, A2A; Gateway lam unified entrypoint |
| Fit | Quick managed agent theo pattern cu | Platform de host/govern/operate agent va MCP tools |

Nhan dinh: voi du an moi, nen xem AgentCore la target production. Agents Classic chi nen doc de hieu pattern cu hoac maintain he thong da ton tai.

## 5. Ban do dich vu AgentCore

| Thanh phan | AWS giai quyet viec gi | Minh van phai tu quyet dinh |
|---|---|---|
| Harness | Agent loop managed: model, tools, context, memory, sandbox, observability | Prompt, tool design, skill/domain logic, eval criteria |
| Runtime | Deploy agent/tool code serverless, isolated session, version/endpoint | Framework, app code, dependency, request/response contract |
| Gateway | Mot cong an toan cho tools/agents/models; translate MCP sang API/Lambda; auth in/out | Tool schema, permission model, API boundary, latency/cost |
| Memory | Short-term va long-term memory managed | Memory taxonomy, what to remember, privacy/retention |
| Identity | Agent/user/service identity, credential vault, OAuth/API key flows | IdP, scopes, least privilege, approval UX |
| Code Interpreter | Sandbox chay code Python/JS/TS, data analysis, file processing | Code policy, package set, data access, max runtime/cost |
| Browser | Managed browser automation voi isolation, replay/audit | Website terms, auth flow, failure recovery, anti-bot limits |
| Observability | Trace/span/log/metric theo OpenTelemetry/CloudWatch | SLO, dashboards, alert rules, incident workflow |
| Evaluations | Built-in/custom evaluator, online/on-demand/batch scoring | Golden dataset, rubric, threshold, regression policy |
| Optimization | Prompt/tool description recommendations, config bundles, A/B test | Whether recommendation is acceptable, rollout criteria |
| Policy | Deterministic guardrail cho tool calls qua Gateway | Cedar/natural language policy, test cases, exception flow |
| Registry | Catalog agents/tools/MCP/skills co approval workflow | Org taxonomy, ownership, lifecycle, publication rules |
| Payments | x402 microtransaction cho paid APIs/MCP/content | Budget limits, wallet provider, compliance, business model |

## 6. Cac pattern build agent tren AWS

### Pattern A: Managed harness first

Dung khi can thu nhanh mot agent co tool/memory/browser/code interpreter ma chua muon tu viet agent loop.

Flow:

1. Khai bao model, instruction, tools, skills.
2. Chay session tren managed harness.
3. Gan memory, gateway, identity, observability.
4. Khi config khong du nua, export sang code hoac chuyen sang Runtime/custom framework.

### Pattern B: Framework-first, AgentCore Runtime deploy

Dung khi team da co LangGraph/CrewAI/Strands/OpenAI Agents SDK/custom agent.

Flow:

1. Giua lai agent code va framework.
2. Wrap thanh HTTP/MCP/A2A service theo contract AgentCore.
3. Deploy len Runtime bang AgentCore CLI/Python SDK/AWS SDK.
4. Them Gateway, Memory, Identity, Observability, Evaluations.

### Pattern C: Tool platform/MCP gateway

Dung khi gia tri nam o viec expose internal API cho nhieu agent dung chung.

Flow:

1. Chuan hoa OpenAPI/Smithy/Lambda schemas.
2. Dua vao AgentCore Gateway de expose thanh MCP-compatible tools.
3. Gan Identity va Policy de kiem soat ai/agent nao goi tool nao.
4. Dang ky vao Registry de teams tim va dung lai.

### Pattern D: RAG/workflow agent

Dung khi tac vu can docs/data va workflow ro rang hon la autonomous loop.

Flow:

1. Knowledge Bases cho retrieval co citation.
2. Guardrails cho safety.
3. Flows neu can workflow deterministic/visual node.
4. AgentCore chi can khi agent phai tu lap ke hoach, goi nhieu tool, giu memory, hoac chay production voi eval/observability.

## 7. Repo `awslabs/agentcore-samples` nen doc nhu the nao?

Repo sample khong chi la code demo; no la learning map.

Thu tu doc de co hinh dung nhanh:

1. `00-getting-started/README.md`: AgentCore CLI, create/dev/deploy agent, project structure.
2. `01-features/README.md`: ban do tung capability: Harness, Runtime, Gateway, Memory, Identity, Observability/Evaluation/Optimization, Policy, Registry, Payments, Tools.
3. `02-use-cases/README.md`: chon use case gan voi minh:
   - conversational agents: support, SRE, operations, finance, healthcare, lakehouse;
   - workflow automation agents: event-driven claims, market/web intelligence, B2B payable;
   - coding assistants: text-to-python IDE, Claude Code gateway MCP.
4. `03-integrations/`: tich hop voi Bedrock Agents, Langfuse/AgentOps va cac stack ben ngoai.
5. `04-infrastructure-as-code/`: CDK/CloudFormation/Terraform.
6. `05-blueprints/` va `06-workshops/`: app day du va workshop co huong dan theo buoc.

De bat dau thuc nghiem, nen lam mot spike nho:

```bash
npm install -g @aws/agentcore
agentcore create --name CustomerSupport --framework Strands --model-provider Bedrock --defaults
cd CustomerSupport
agentcore dev
agentcore deploy
agentcore invoke --prompt "What can you help me with?"
```

Dieu kien truoc khi spike:

- AWS account co credentials.
- Region co AgentCore va model access da bat trong Bedrock.
- Node.js 20+.
- `uv` neu dung Python agents.
- IAM permission cho Bedrock/AgentCore va cac resource deploy phu tro.

## 8. Cau hoi quyet dinh kien truc

Truoc khi build, nen tra loi cac cau hoi nay:

1. Agent co can tu lap ke hoach va goi tool nhieu buoc, hay chi la workflow co node ro rang?
2. Agent co can memory qua nhieu session/user/project khong?
3. Tool nao la internal API/Lambda co the dua qua Gateway?
4. Tool call nao can policy deterministic thay vi chi prompt instruction?
5. Identity la user-delegated, service-to-service, hay agent autonomous identity?
6. Co can browser/code interpreter/web search managed khong, hay tool backend du?
7. Dinh nghia "agent lam dung" bang evaluator nao? Co golden dataset khong?
8. Can observability/SLO nao truoc khi cho user that?
9. Neu dung model ngoai Bedrock, gateway/identity/cost/audit xu ly ra sao?
10. Thanh phan nao dang preview va co chap nhan rui ro thay doi API khong?

## 9. Huong nghien cuu tiep theo

De bien tai lieu nay thanh implementation plan, nen chia thanh 3 nhanh:

### Nhanh 1: Platform capability map

Muc tieu: biet chinh xac service nao giai quyet van de nao.

Output nen co:

- Bang service/capability/cost/risk/status GA-preview.
- So do reference architecture: user app -> identity -> runtime/harness -> gateway -> tools/data -> observability/eval.
- Checklist AWS account/region/IAM/model access.

### Nhanh 2: Hands-on spike

Muc tieu: deploy duoc mot agent cuc nho.

Output nen co:

- Repo spike scaffold bang AgentCore CLI.
- Local dev runbook.
- Deploy/invoke runbook.
- Observability/evaluation minimal evidence.

### Nhanh 3: Use-case fit

Muc tieu: chon use case thuc te de dau tu.

Ung vien tot:

- Customer support/RAG agent co Gateway tool goi backend.
- SRE/operations agent goi AWS APIs co policy.
- Research/data-analysis agent co Browser + Code Interpreter + Memory.
- Internal MCP platform expose APIs cho nhieu coding/ops agents.

## 10. Nguon chinh da dung

- AWS: [Overview - Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- AWS: [AgentCore Runtime - how it works](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-how-it-works.html)
- AWS: [Host agent or tools with AgentCore Runtime](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agents-tools-runtime.html)
- AWS: [AgentCore Harness](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness.html)
- AWS: [AgentCore Gateway](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway.html)
- AWS: [AgentCore Memory](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/memory.html)
- AWS: [AgentCore Identity](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/identity.html)
- AWS: [AgentCore Policy](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/policy.html)
- AWS: [AgentCore Evaluations](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/evaluations.html)
- AWS: [AgentCore Optimization](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/optimization.html)
- AWS: [AWS Agent Registry](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/registry.html)
- AWS: [AgentCore Payments](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/payments.html)
- AWS: [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- AWS: [Amazon Bedrock Agents](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- AWS: [Amazon Bedrock Flows](https://docs.aws.amazon.com/bedrock/latest/userguide/flows.html)
- AWS: [Amazon Bedrock Knowledge Bases](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- AWS Prescriptive Guidance: [Strands Agents](https://docs.aws.amazon.com/prescriptive-guidance/latest/agentic-ai-frameworks/strands-agents.html)
- GitHub: [awslabs/agentcore-samples](https://github.com/awslabs/agentcore-samples)
