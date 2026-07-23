# RFC: QA-Agents AI Support Journey

Ngay tao: 2026-07-22  
Trang thai: Draft for discussion  
Pham vi hien tai: ho tro QA su dung AI trong luong ticket -> test cases -> verify -> source-of-truth document

## 1. Muc tieu

Muc tieu cua RFC nay la mo ta mot luong ung dung AI cho du an **QA-Agents**, bat dau tu nhu cau thuc te cua QA team:

- Giam thoi gian doc ticket/spec va hieu acceptance criteria.
- Ho tro tao/de-xuat/doi-chieu test cases.
- Ho tro QA verify thay doi cua engineer bang checklist, risk, edge cases va evidence.
- Ghi nhan ket qua verify thanh source-of-truth document co trace ro rang.
- Tao nen mot nen tang co the mo rong cho engineer, product va documentation sau nay.

Quan diem thiet ke: AI khong thay the QA decision. AI la assistant de doc, doi-chieu, de xuat, generate checklist, gom evidence va nhac nhung rui ro de con nguoi verify nhanh va chat luong hon.

## 2. Business/product framing

### 2.1 Problem statement

Trong delivery workflow hien tai, QA khong chi "test". QA dang lam mot cong viec tong hop co nhieu context:

- Doc ticket/spec de hieu y dinh product.
- Dich requirement thanh test cases va edge cases.
- Doi chieu code/build/PR voi acceptance criteria.
- Verify bang manual/automation/evidence.
- Giao tiep lai voi engineer/product khi co ambiguity hoac defect.
- Ghi nhan ket qua thanh source-of-truth cho release va future regression.

Van de khong nam rieng o viec tao test case. Van de lon hon la **context fragmentation**:

```text
Ticket noi mot noi
PR/code noi mot noi
Test cases noi mot noi
Evidence noi mot noi
Product decision noi mot noi
Final source-of-truth thuong bi thieu hoac viet muon
```

AI co gia tri neu no giup QA noi cac context nay lai thanh mot verification workflow co trace, khong chi generate text.

### 2.2 Deeper gap: ticket is not the truth

Mot gap lon hon: QA dang nhan ticket nhu mot con nguoi doc text, nhung ticket khong bao gio la toan bo su that.

Khi mot QA gioi doc ticket, ho khong chi doc chu. Bo nao cua ho lam nhieu viec cung luc:

```text
Ticket says X
  -> Business hien tai dang chay nhu the nao?
  -> Feature nay da tung co rule/exception nao?
  -> Codebase hien dang cover flow nao?
  -> Ticket co noi dung voi current behavior khong?
  -> Change nay co impact den flow/module/role/data nao khac?
  -> Test nao da co san? Test nao con thieu?
  -> Neu verify dung ticket nhung ticket sai/thieu thi sao?
```

Day la diem QA-Agents can tap trung. Neu AI chi summarize ticket, gia tri thap. Neu AI giup QA **doi chieu ticket voi business history, source-of-truth va codebase current state**, gia tri cao hon nhieu.

### 2.3 Context gap model

QA can mot "context lens" gom 4 lop:

| Lop context | Cau hoi QA can tra loi | Gap hien tai |
|---|---|---|
| Ticket intent | Ticket muon thay doi dieu gi? Acceptance criteria la gi? | Ticket co the mo ho, thieu context, sai current behavior |
| Business history | Feature nay da tung co rule, exception, decision nao? | Business memory nam trong dau nguoi, chat, docs cu, ticket cu |
| Codebase current state | He thong hien dang implement/cover flow nay ra sao? | QA thuong khong biet code path, config, permission, data boundary |
| Implementation shape | Change se duoc engineer xu ly o UI, API, database, config, background job, hay ket hop? | Product define behavior, nhung technical shape thuong chi engineer biet |
| Impact surface | Change nay anh huong flow/module/role/data/test nao khac? | Impact analysis phu thuoc kinh nghiem ca nhan va engineer briefing |

Output mong muon khong phai "AI answer". Output mong muon la **QA context brief**:

- Ticket summary.
- Current behavior neu biet.
- Business rules/history co lien quan.
- Code areas/components/API/routes/tests co kha nang lien quan.
- Implementation shape neu biet: UI/API/DB/config/job/combo; neu khong biet thi ghi unknown.
- Impacted flows va regression candidates.
- Ticket ambiguities hoac mismatch voi current state.
- Suggested questions can hoi Product/Engineer truoc khi verify.

### 2.4 Critical reframing: day khong chi la QA knowledge gap

Can can than voi framing "QA khong biet codebase". Neu noi nhu vay, minh co nguy co dat sai van de va day burden ve QA.

Phan bien manh hon:

```text
Van de khong phai QA thieu kien thuc codebase.
Van de la organization thieu mot shared verification context de noi product intent,
business history, current implementation, test coverage va release evidence.
```

QA khong nen phai tu minh reverse-engineer toan bo codebase moi khi verify ticket. Neu ticket khong noi ro current behavior, business history nam trong dau nguoi, va codebase khong co mapping de QA doc duoc, thi day la system gap cua delivery process, khong phai loi cua QA.

Noi cach khac:

- Ticket la **intent artifact**, khong phai truth artifact.
- Codebase la **implementation artifact**, khong phai business explanation.
- Test cases la **coverage artifact**, nhung thuong khong noi du tai sao.
- Evidence la **verification artifact**, nhung thuong sinh ra qua muon.
- Source-of-truth document la **memory artifact**, nhung thuong khong duoc cap nhat dung luc.

QA-Agents nen giai quyet khoang trong giua cac artifact nay.

### 2.5 Sharper problem statement

Problem statement nen duoc viet lai nhu sau:

> Khi QA nhan mot ticket, QA khong the tin rang ticket da phan anh day du current product behavior, business rules, codebase coverage va impact surface. De verify dung, QA phai tu tong hop context tu ticket, nguoi, docs cu, PR/code, existing tests va evidence. Viec tong hop nay cham, khong nhat quan, phu thuoc vao memory ca nhan, va de dan den verify sai scope hoac miss regression.

Day la problem can solve. Khong phai:

- "Can AI generate test cases."
- "Can QA hoi chatbot ve ticket."
- "Can AI doc codebase thay QA."

Decision 2026-07-23: root problem cua QA-Agents la **shared verification context**.

Dieu nay co nghia MVP khong nen duoc dinh vi nhu "AI generate test case" hay "agent tu verify thay QA". MVP nen tao mot artifact chung de QA, Product va Engineer cung nhin vao:

- ticket intent;
- current behavior;
- business rules/history;
- implementation/codebase signals neu co;
- impacted flows;
- ambiguity/mismatch;
- verification plan;
- evidence va final decision.

Nhung solution co the bat dau tu cac viec nho hon:

- tao ticket brief;
- tao current-state brief;
- tao impact surface;
- tao test matrix;
- tao verification note.

### 2.6 What must be true for this product to work

Neu cac dieu kien sau khong dung, QA-Agents se de thanh demo hay nhung product yeu:

| Assumption | Risk neu sai | Cach validate |
|---|---|---|
| Business history co source nao do de retrieve | AI se chi suy dien hoac hoi nguoi lai | Lay 10 ticket cu va xem rule/decision nam o dau |
| Codebase co signal co the map sang feature/flow | AI se cite file path nhung khong giai thich duoc impact | Thu code search tren 5 ticket that |
| QA muon current-state brief truoc khi test matrix | Product co the them step lam cham workflow | Pilot voi QA va do time-to-clarity |
| Engineer/Product chap nhan AI flag mismatch | Neu khong, AI output se bi xem la noise | Review mismatch report voi engineer/product |
| Source-of-truth document duoc dung lai | Neu khong ai doc lai, documentation value thap | Track ai consume final note va luc nao |

### 2.7 Failure modes can thang than

QA-Agents co the fail theo cac cach sau:

1. **False confidence**  
   AI doc ticket + vai file code roi noi nhu da hieu toan bo system. Day nguy hiem hon khong co AI.

2. **Shifting responsibility to QA**  
   Product/Engineer viet ticket thieu context, sau do ky vong QA + AI tu phat hien tat ca. Neu vay AI lam workflow bat cong hon.

3. **No source, only synthesis**  
   AI output nghe hay nhung khong co citation ve ticket/doc/code/evidence. Khong dung duoc cho QA.

4. **Code path != business behavior**  
   Code co the cho biet implementation, nhung khong giai thich tai sao business rule ton tai. Can business history/decision log.

5. **Impact analysis qua rong**  
   AI liet ke qua nhieu flow "co the anh huong", QA bi overload va mat trust.

6. **Documentation theater**  
   AI tao final note dep nhung khong ai dung lai, khong cai thien quality.

### 2.8 Product opportunity

QA-Agents co the tro thanh **QA workbench**: mot noi QA bat dau tu ticket, duoc AI ho tro hieu scope, de xuat test, verify co evidence, va ket thuc bang document co the tin duoc.

Product opportunity khong phai "AI test everything". Product opportunity la:

- Tang toc thoi gian QA hieu ticket.
- Giup QA doi chieu ticket voi current behavior, business history va codebase coverage.
- Tang chat luong test coverage va edge-case thinking.
- Giam defect bi miss do requirement ambiguity.
- Giam rui ro verify dung ticket nhung ticket sai/thieu so voi san pham that.
- Giam thoi gian viet verification note/release evidence.
- Tao knowledge base cho QA regression sau nay.
- Lam product/engineer/QA noi cung mot source-of-truth.

Decision 2026-07-23: business/product scope cua MVP:

- **Primary user**: QA.
- **Context contributors**: Product va Engineer bo sung ngu canh khi QA/AI phat hien ambiguity, mismatch, missing business rule, missing implementation hint, hoac risk can confirm.
- **Root value**: shared verification context, khong phai AI automation.
- **Pain set can solve**:
  - QA mat thoi gian hieu ticket.
  - QA verify sai scope.
  - Product/Engineer/QA khong cung context.
  - Evidence/documentation sau QA bi thieu.
  - Regression bi miss.
- **Business outputs can tao**:
  - Shared verification context.
  - Risk summary.
  - QA sign-off note.
  - Release confidence record.
  - Defect-quality improvement.

### 2.9 Personas

| Persona | Job | Pain hien tai | AI ho tro nen lam gi | AI khong nen lam gi |
|---|---|---|---|---|
| QA Engineer | Primary user: verify ticket/build | Context phan tan, khong ro current behavior/code coverage, test case thieu, evidence viet thu cong | Summarize scope, surface current-state mismatch, suggest test matrix, nhac evidence, draft final note | Tu pass/fail thay QA |
| QA Lead | Quan ly quality/risk | Kho biet ticket nao risk cao, coverage ra sao, impact lan den dau | Highlight risk, impact surface, coverage gaps, blocked reasons, trend | Tao metric ao khong co evidence |
| Engineer | Context contributor: confirm implementation/current behavior khi can | Feedback QA thieu context hoac den muon | Nhan checklist ro, defect wording co repro/evidence, biet QA dang test impact nao | Ep engineer theo AI neu ticket/spec sai |
| Product/PM | Context contributor: confirm business intent/rule khi can | Kho doc technical evidence, missing product risk, ticket co the khong phan anh current behavior | Tao product-facing summary, unresolved mismatch, risk, demo checklist | Thay Product sign-off |
| Tech Lead/EM | Dieu phoi delivery | Quality gate khong nhat quan | Xem status/risk/evidence theo ticket | Bien AI thanh gate quan lieu |

### 2.10 Jobs-to-be-done

Khi QA nhan mot ticket can verify:

- **Understand**: "Hay giup toi hieu ticket nay dang thay doi dieu gi, ai bi anh huong, acceptance criteria la gi."
- **Reconstruct current state**: "Hay giup toi biet san pham/codebase hien dang cover feature nay nhu the nao, va ticket co noi dung voi hien trang khong."
- **Assess impact**: "Hay giup toi tim cac flow, role, data boundary, API/UI va regression areas co the bi anh huong."
- **Plan**: "Hay giup toi bien requirement thanh test matrix co priority, edge cases va evidence can capture."
- **Verify**: "Hay giup toi theo doi minh da verify cai gi, con thieu cai gi, can regression flow nao."
- **Communicate**: "Hay giup toi viet feedback/bug report ro rang cho engineer/product."
- **Document**: "Hay giup toi tao source-of-truth verification note de nguoi sau doc lai hieu ticket da duoc verify nhu the nao."

### 2.11 Product hypothesis

Hypothesis cho Phase 1:

> Neu QA co mot AI assistant draft-only giup doc ticket, tao test matrix, nhac evidence va draft verification note, thi QA se verify nhanh hon va final documentation day du hon ma khong can cho AI quyen write/action tu dong.

Hypothesis manh hon cho product direction:

> Neu QA-Agents co the noi ticket voi business history va codebase current state de tao QA context brief, thi QA se phat hien ambiguity/impact som hon va giam risk verify sai scope.

Can validate hypothesis bang pilot that, khong chi demo.

### 2.12 Value proposition

QA-Agents nen duoc position nhu sau:

```text
QA-Agents helps QA turn a ticket into a traceable verification record:
from current-state understanding, to impact-aware test planning, to evidence-backed QA sign-off.
```

Thong diep noi bo:

- Cho QA: "Bot giup ban doc ticket, nho business context, soi impact, lap checklist, khong quen evidence."
- Cho Engineer: "QA feedback se ro repro, expected/actual, evidence."
- Cho Product: "Ban nhan duoc product-level verification summary va risk."
- Cho manager: "Co visibility vao quality readiness, blockers va documentation consistency."

### 2.13 Product principles

1. **Human owns the decision**  
   AI chi draft/de-xuat. QA/Product/Engineer van la owner cua pass/fail/approve.

2. **Trace before confidence**  
   Moi claim quan trong phai link ve ticket/spec/PR/evidence.

3. **Ticket is an input, not the truth**  
   QA-Agents phai luon doi chieu ticket voi business history, current behavior va codebase signals neu co.

4. **QA verifies behavior, not implementation guesses**  
   Product define behavior. Engineer co the implement bang UI, API, database, config, background job, permission layer, hoac ket hop. QA-Agents khong nen ep QA doan technical shape neu chua co source.

5. **Implementation hints need provenance**  
   Neu AI noi change co lien quan den UI/API/DB/code path nao, output phai ghi ro source hoac confidence. Neu khong co source, phai la "unknown" hoac "needs engineer confirmation".

6. **Workflow over chatbot**  
   Product khong nen chi la chat box. QA can workbench co ticket brief, test matrix, evidence panel, final note.

7. **Draft first, automation later**  
   Phase 1 nen draft-only. Write actions va agent automation chi them khi da co trust/eval.

8. **Evidence is the product**  
   Gia tri cuoi cung khong phai cau tra loi cua AI, ma la verification record co evidence.

9. **Minimize context switching**  
   QA khong nen phai copy qua lai giua ticket, PR, spreadsheet, docs neu integration da co.

## 3. Product scope options

### Option A: QA Copilot trong ticket flow

AI song gan ticket. QA click "Generate QA brief", "Generate test cases", "Draft QA note".

Uu diem:

- De rollout.
- It thay doi workflow.
- Adoption nhanh neu team dang song trong ticketing system.

Nhuoc diem:

- Kho tao mot verification session co state rieng.
- Evidence/source-of-truth co the van phan tan.

### Option B: QA Workbench rieng cho verification session

QA-Agents co UI/session rieng: ticket brief, test matrix, execution checklist, evidence, final note.

Uu diem:

- Dung product shape cho QA.
- De tao source-of-truth va quality metrics.
- Mo duong cho AgentCore/tools sau nay.

Nhuoc diem:

- Can integration va adoption cao hon.
- QA phai mo them mot workspace.

### Option C: Source-of-truth generator truoc

Bat dau tu cuoi luong: QA paste ticket/result/evidence, AI draft final verification note.

Uu diem:

- Scope nho nhat.
- Gia tri ro cho documentation.
- It rui ro.

Nhuoc diem:

- Khong ho tro QA trong qua trinh verify.
- Khong giam context fragmentation tu dau.

Recommendation: **Option B as product direction, Option C as smallest pilot, Option A as integration surface later**.

Noi cach khac:

- Vision: QA Workbench.
- MVP pilot: Ready-for-QA Verification Context Record.
- Integration: ticket comments/buttons sau khi flow duoc validate.

## 4. Success metrics

### Business/product metrics

Decision 2026-07-23: MVP success khong chi do mot metric duy nhat. MVP nen do ca bo metric sau de xem QA-Agents co tao duoc business value that hay khong.

| Metric | Vi sao quan trong | Cach do |
|---|---|---|
| QA time-to-understand ticket | Do AI co giam thoi gian doc/spec khong | QA self-report + time from open to approved brief |
| Shared-context alignment | Product/Engineer/QA co cung nhin mot context khong | % ticket co approved Verification Context Record truoc khi QA execute |
| Current-state mismatch detection | Do AI co giup phat hien ticket sai/thieu so voi hien trang khong | So mismatch/ambiguity duoc flag truoc khi verify |
| Impact analysis usefulness | Do AI co tim dung flow/module/role bi anh huong khong | QA/Engineer rate useful/partial/not useful |
| Test coverage usefulness | Do AI co de xuat dung cases khong | QA rate useful/partial/not useful tren test cases |
| Regression risk reduction signal | Do AI co giup QA nho impacted flow/regression candidate khong | So regression candidates duoc them vao plan va duoc QA confirm useful |
| Evidence completeness | Do output co dung source-of-truth khong | % final notes co build/env/status/evidence/defects |
| Defect communication quality | Engineer co reproduce nhanh hon khong | Engineer rating hoac reopen/clarification count |
| Product sign-off clarity | Product co hieu risk va scope khong | PM rating, so cau hoi follow-up |
| Release confidence record completeness | Ticket co record du de dung lai khi release/regression khong | % record co scope, risk, evidence, known limitations, sign-off status |
| Documentation reuse | Source-of-truth co duoc dung lai khong | Link/reference count, regression reuse |
| Clarification before testing | Ambiguity/mismatch co duoc resolve truoc khi QA test khong | So clarification raised before verification begins |

### Guardrail metrics

| Metric | Target dau tien |
|---|---|
| AI pass/fail without human confirmation | 0 |
| Unsupported claim without source/evidence | 0 P0 cases |
| Sensitive data leakage to final docs | 0 |
| Hallucinated acceptance criteria | 0 P0 cases |

## 5. Product rollout hypothesis

Rollout nen di theo trust ladder:

```text
Level 0: AI drafts text only
Level 1: AI structures QA session and evidence checklist
Level 2: AI reads ticket/PR/docs through integrations
Level 3: AI drafts write actions for QA approval
Level 4: AI performs low-risk write actions with policy
Level 5: AI agent orchestrates multi-tool verification support
```

Phase hien tai nen dung o Level 0-1. Chua nen di thang vao Level 4-5.

## 6. Business questions can chot truoc technical

1. Root problem minh muon solve la gi: **shared verification context**. QA speed, QA quality, source-of-truth va release confidence la downstream outcomes, khong phai root positioning.
2. Ai dang chiu trach nhiem tao shared verification context hom nay: Product, Engineer, QA, hay khong ai ro?
3. Ticket thieu context la exception hay la normal workflow?
4. QA hien dang lay business history tu dau: docs, ticket cu, chat, con nguoi, hay memory ca nhan?
5. QA co access/ky nang doc codebase den muc nao, va can AI translate codebase signals thanh ngon ngu QA ra sao?
6. Khi AI flag ticket/current-state mismatch, ai la nguoi resolve: Product, Engineer, QA Lead, hay ticket owner?
7. Source-of-truth hien tai ai doc lai va dung vao luc nao?
8. QA team co san sang lam viec trong QA Workbench rieng khong, hay phai nam trong ticketing tool?
9. Product/Engineer mong muon output tu QA la gi: checklist, defect report, demo note, risk summary, hay release sign-off?
10. MVP nen optimize cho speed, quality, documentation consistency, current-state mismatch detection, hay cross-team visibility?

## 7. Context: journey hien tai

Journey cua mot ticket co the mo ta bang 6 buoc:

```text
1. Team nhan ticket
2. Test cases
3. Engineer coding
4. QA verify
5. Product verify
6. Source-of-truth document
```

Moi buoc deu co the integration voi AI, nhung khong nen trien khai tat ca ngay tu dau. Phase dau nen tap trung vao QA verify vi day la noi co gia tri ro nhat: QA can hieu ticket, test dung scope, bat edge cases, va ghi evidence.

## 8. Journey target voi AI touchpoints

| Buoc | Actor chinh | Input | Output | AI co the ho tro | Quyen quyet dinh cuoi |
|---|---|---|---|---|---|
| 1. Team nhan ticket | PM/Tech Lead/QA Lead | Ticket, PRD, design, bug report, user impact | Ticket summary, scope, acceptance criteria, risk | Summarize ticket, tach requirement, hoi cau hoi mo, detect ambiguity | Team/owner |
| 2. Test cases | QA | Ticket summary, acceptance criteria, business history, existing regression suite | Test cases, edge cases, data setup, expected result | Generate draft test cases, map test case -> requirement/history/current behavior, suggest negative cases | QA |
| 3. Engineer coding | Engineer | Ticket, test cases, codebase context | Code change, PR, implementation note | Explain expected behavior, generate implementation checklist, detect missing tests/impact areas | Engineer/reviewer |
| 4. QA verify | QA | Build/branch, PR diff, codebase signals, test cases, environment, logs/screenshots | Verification result, defects, evidence | Build verify checklist, compare PR diff vs acceptance/current behavior, suggest impacted flows, structure evidence | QA |
| 5. Product verify | Product/PM | QA result, demo, screenshots, release note | Product sign-off or change request | Summarize change in product language, highlight unresolved risk, create demo script | Product/PM |
| 6. Source-of-truth document | QA/PM/Tech Lead | Ticket, test result, PR, decision, release note | Final document, test evidence, known limitation | Draft final verification doc, update decision log, link artifacts | Document owner |

## 9. Phase 1 scope: QA AI Assistant

Phase 1 nen tap trung vao mot assistant cho QA voi artifact chinh la **Ready-for-QA Verification Context Record**.

Thoi diem tao record: khi ticket chuyen sang **ready for QA**. Day la luc du som de giup QA verify dung scope, nhung du muon de ticket da co implementation/build context co the tham chieu neu can.

MVP khong can quyet dinh ngay record se luu o dau. Ban dau record co the la Markdown/manual artifact. Dieu can validate truoc la: record co giup QA hieu current behavior, business history, ambiguity va final memory tot hon khong.

### Ready-for-QA intake model

Decision 2026-07-23: **Phase 1 minimum context = ticket + QA input**.

Trong MVP, system khong bat buoc doc PR diff, source code, build artifact, historical docs hay test management tool. Cac source do co the duoc paste/link thu cong neu QA co san, nhung khong la dependency de pilot chay duoc.

Ly do:

- Giam integration scope de validate product value truoc.
- Ep artifact tap trung vao shared verification context, khong bien MVP thanh code-analysis platform.
- Cho phep QA dung ngay voi ticket that va context QA dang co.
- Lam ro chat luong dau ra phu thuoc vao ticket + QA input; neu context thieu, AI phai tao Clarification Block thay vi suy dien.

MVP nen dung **hybrid intake**:

```text
Structured form cho cac truong bat buoc
  + AI follow-up khi input thieu, mau thuan, hoac co ambiguity
```

Ly do:

- Form giu record co cau truc va de bien thanh source-of-truth.
- AI follow-up giup QA khong phai tu nghi het edge cases tu dau.
- "Unknown" la gia tri hop le, de tranh QA hoac AI bia business history.
- Follow-up chi nen xuat hien khi co ly do ro, khong bien flow thanh chat lan man.

#### Required intake fields

| Field | Cau hoi | Gia tri hop le |
|---|---|---|
| Ticket | Ticket/spec can verify la gi? | Text/link/paste tu ticketing system |
| Current behavior | Theo hieu biet hien tai, product dang behave nhu the nao? | Text hoac `unknown` |
| Business rule/history | Co rule, exception, decision, ticket cu nao lien quan khong? | Text/link hoac `unknown` |
| Clarification needed | QA dang nghi ngo/can clarify dieu gi truoc khi verify? | Text hoac `none` |

#### Optional intake fields

| Field | Cau hoi | Vi du |
|---|---|---|
| Source links | Source nao dang duoc dung de hieu context? | Ticket cu, doc, chat, PR, release note |
| Suspected impacted flows | QA nghi flow nao co the bi anh huong? | Web, mobile, admin, API, permission, report, payment |
| Engineer implementation hint | Neu engineer da de lai note, change nam o dau? | UI, API, DB, config, job, permission, unknown |
| PR/build/test artifacts | Co PR/build/test output nao QA muon dua vao khong? | PR link, branch, build id, CI output, test run |

#### AI follow-up rules

AI chi hoi follow-up khi:

- Current behavior la `unknown` nhung ticket yeu cau thay doi behavior hien co.
- Business history la `unknown` nhung ticket co dau hieu rule/exception/domain-specific.
- Acceptance criteria mau thuan voi current behavior QA nhap.
- Ticket yeu cau behavior moi nhung khong co implementation hint nao, va QA can biet regression scope.
- Ticket thieu out-of-scope cho change co impact rong.
- QA ghi suspected impacted flow nhung test plan khong cover flow do.

AI khong nen hoi follow-up chi de "cho du". Neu khong co ambiguity ro, tao record ngay.

#### Clarification block

Khi AI phat hien `unknown`, `mismatch`, hoac `ambiguity` co risk, MVP khong tu tao comment/message truc tiep. AI tao **Clarification Block** de QA copy gui Product/Engineer.

Muc tieu:

- Giam friction cho QA khi can hoi lai.
- Giu workflow draft-only, khong phu thuoc integration.
- Lam cau hoi ro hon: context, risk, nguoi can tra loi, decision can co.

Format de xuat:

```markdown
### Clarification needed

Ticket: <ticket-id>
Area: current behavior | business rule | implementation hint | scope | evidence
Owner suggested: Product | Engineer | QA Lead

Context:
- <what ticket says>
- <what current behavior/history says or unknown>

Question:
- <specific question>

Why this matters:
- <risk if QA verifies without this answer>

Needed before:
- test planning | QA execution | product sign-off | release
```

Rule:

- Product-facing question nen noi bang ngon ngu behavior/business.
- Engineer-facing question co the hoi implementation hint, code path, build scope, regression area.
- Neu cau hoi khong can block QA, mark la `non-blocking`.

#### AI answer authority

Decision 2026-07-23: **AI cung co quyen tra loi**, nhung chi trong boundary cua assistant draft/source-backed.

AI khong chi dat cau hoi. Neu ticket + QA input + approved retrieval context du de tra loi, AI nen tu de xuat cau tra loi de giam clarification loop.

Quyen tra loi cua AI:

- Duoc answer khi cau tra loi co source/context ro tu ticket, QA input, approved docs, historical record, hoac retrieval result.
- Phai gan nhan: `source-backed`, `inferred`, hoac `unknown`.
- Phai ghi confidence/risk: high, medium, low.
- Phai neu ro assumption neu co.
- Phai de xuat owner confirm neu cau tra loi co impact den business rule, expected behavior, implementation scope, release risk, hoac customer impact.

AI khong duoc:

- Tu quyet dinh expected behavior khi ticket/source khong du.
- Tu override Product/Engineer/QA confirmation.
- Tu pass/fail ticket thay QA.
- Bien inference thanh fact.

Ownership model:

| Area | AI co the tra loi? | Human authority |
|---|---|---|
| Ticket summary | Co, neu dua tren ticket | QA review |
| Current behavior | Co, neu QA input/source ro; neu khong thi `unknown` | QA, Engineer confirm khi mismatch/risk cao |
| Business rule/history | Co, neu co approved docs/history | Product confirm khi rule/intent chua ro |
| Implementation hint | Co, neu co engineer note/PR/source duoc cung cap | Engineer confirm |
| Impact/risk | Co, dang risk hypothesis | QA/QA Lead/Product confirm theo scope |
| Final sign-off | Chi draft note | QA |

#### Blocking vs non-blocking rule

MVP rule:

```text
If expected behavior is unclear -> blocking.
If expected behavior is clear but coverage/risk is incomplete -> non-blocking.
```

Blocking clarification:

- Thieu cau tra loi se lam QA khong the xac dinh expected behavior.
- Khong ro current behavior dung la gi.
- Khong ro business rule/exception.
- Acceptance criteria mau thuan nhau.
- Khong ro change ap dung cho role/user/data nao.
- Khong ro pass/fail nen danh gia theo rule nao.

Non-blocking clarification:

- QA van co the verify core scope, nhung can ghi risk/follow-up.
- Khong ro regression co nen mo rong toi flow phu nao.
- Khong ro implementation nam o UI/API/DB, nhung expected behavior da ro.
- Thieu source link cho business history, nhung Product da confirm behavior trong ticket.
- Co edge case chua ro nhung khong thuoc acceptance criteria chinh.

#### Current behavior ownership

MVP dung ownership model **QA-first, conditional confirmation**:

```text
QA nhap current behavior/business history theo hieu biet hien tai
  -> AI draft Verification Context Record
  -> AI flag unknown/mismatch/ambiguity co risk
  -> Engineer hoac Product chi confirm phan can confirm
```

Ly do:

- Khong bat Engineer/Product confirm moi ticket.
- QA van la owner cua verification session.
- Neu current behavior unknown hoac ticket co mismatch, workflow co co che escalate som.
- Product confirm business intent/rule; Engineer confirm implementation/current behavior khi can.

Ownership split:

| Field | Primary owner | Conditional reviewer |
|---|---|---|
| Ticket intent | Product/ticket owner | QA |
| Current behavior | QA | Engineer neu unknown/mismatch |
| Business history | QA | Product neu rule/decision unclear |
| Implementation shape | Engineer | QA chi consume as hint |
| Verification plan | QA | Engineer/Product neu scope ambiguity |
| Final verification memory | QA | Product/Engineer neu risk accepted |

Phase 1 capability:

1. **Ticket understanding**
   - Doc ticket/PRD/bug report.
   - Tao summary ngan gon: problem, user impact, expected behavior, acceptance criteria.
   - Detect ambiguity: requirement nao chua ro, dependency nao thieu, test data nao can co.

2. **Current-state and impact support**
   - Doi chieu ticket voi business history/source-of-truth neu co.
   - Neu co PR/codebase context, chi ra code areas/API/routes/components/tests co kha nang lien quan.
   - Flag mismatch: ticket mo ta behavior khong khop current behavior, thieu rule cu, thieu role/data boundary.
   - De xuat impacted flows can regression va cau hoi can hoi Product/Engineer truoc khi verify.

3. **Test-case support**
   - De xuat test cases theo acceptance criteria.
   - Tach positive, negative, regression, permission, data-boundary, edge-case.
   - Map moi test case ve requirement, business rule, current behavior hoac impacted flow de QA biet minh dang cover cai gi.

4. **Verification support**
   - Tao QA verification checklist tu ticket + current-state brief + PR diff + existing test cases.
   - Suggest impacted flows/areas can regression.
   - Nhac QA capture evidence: screenshot, logs, API response, environment, build version, timestamp.
   - Ho tro phan loai ket qua: pass, fail, blocked, needs product clarification.

5. **Source-of-truth drafting**
   - Generate final QA verification note.
   - Link ticket, PR, build, test cases, defects, screenshots/logs.
   - Ghi ro decision: QA pass/fail, risk accepted, known limitation, follow-up ticket.

Ngoai scope Phase 1:

- AI tu dong approve/reject ticket thay QA.
- AI tu dong merge/deploy.
- AI tu dong tao bug tren production neu chua co human confirmation.
- Browser automation full end-to-end thay cho QA manual flow.

## 10. Proposed user flow cho QA

```text
QA mo QA-Agents
  -> Chon ticket vua chuyen sang ready for QA
  -> QA dien hybrid intake: current behavior, business history, clarification needed
  -> AI hoi follow-up neu input thieu/mau thuan
  -> AI tao Ready-for-QA Verification Context Record
  -> AI tao Ticket Brief
  -> QA review va edit acceptance criteria neu can
  -> AI tao Current-State Brief va Impact Surface
  -> AI tao Clarification Block neu co unknown/mismatch/ambiguity risk
  -> QA/Engineer/Product resolve mismatch neu co
  -> AI de xuat Test Matrix
  -> QA chon/bo sung test cases
  -> AI tao Verification Checklist
  -> QA thuc hien verify va attach evidence
  -> AI summarize ket qua + detect missing evidence
  -> QA confirm final status
  -> AI draft Source-of-Truth Verification Document
```

Chi tiet interaction:

1. **Start session**
   - QA nhap ticket id hoac chon ticket dang o ready-for-QA status.
   - System lay ticket content, linked PR, branch/build, related docs.
   - AI tao session context va correlation id.

2. **Hybrid intake**
   - QA dien 3 field bat buoc:
     - Current behavior.
     - Business rule/history.
     - Clarification needed.
   - QA co the them source links va suspected impacted flows neu biet.
   - AI chi hoi follow-up khi thay thieu/mau thuan/ambiguity ro.
   - `unknown` la gia tri hop le.

3. **Ticket brief**
   - AI output:
     - Problem summary.
     - Acceptance criteria.
     - Affected users/flows.
     - Unknowns/open questions.
     - Suggested test focus.
   - QA co the edit de chinh lai source-of-truth cho session.

4. **Current-state brief**
   - AI doi chieu ticket voi cac source co san:
     - business docs/source-of-truth;
     - ticket cu/decision log neu co;
     - PR diff/codebase signals neu co;
     - existing tests/regression suite neu co.
   - AI output:
     - Current behavior summary.
     - Business rules/history lien quan.
     - Code areas/components/API/routes/tests co kha nang lien quan.
     - Implementation shape neu biet: UI/API/DB/config/job/permission/combo/unknown.
     - Impacted flows.
     - Mismatch/ambiguity.
     - Questions can hoi Product/Engineer.
   - QA dung brief nay de quyet dinh co the verify ngay hay can clarify truoc.

5. **Clarification block**
   - Neu co unknown/mismatch/ambiguity co risk, AI tao block de QA copy gui dung nguoi.
   - Block ghi ro:
     - context;
     - question;
     - owner suggested;
     - risk neu khong clarify;
     - needed before step nao.
   - Neu question khong block QA, mark `non-blocking`.

6. **Test matrix**
   - AI tao bang:
     - Requirement.
     - Related current behavior/business rule.
     - Test case.
     - Type: positive/negative/regression/permission/data/UI/API.
     - Priority.
     - Expected result.
     - Evidence required.
   - QA approve subset de verify.

7. **Verification execution**
   - QA chay test manually hoac tu automation co san.
   - QA attach evidence.
   - AI nhac missing evidence neu test case pass/fail nhung thieu screenshot/log/API response/build version.
   - AI suggest defect wording neu fail.

8. **Final QA note**
   - AI draft final note:
     - Scope verified.
     - Ticket/current-state mismatches da resolve hoac con open.
     - Build/environment.
     - Pass/fail/blocked.
     - Evidence links.
     - Defects/follow-ups.
     - Known risk.
     - Product verification recommendation.

## 11. Information architecture cua QA-Agents

### MVP artifact: Ready-for-QA Verification Context Record

Record toi thieu gom 5 phan:

| Section | Muc dich | Ai review |
|---|---|---|
| Ticket intent | Hieu ticket muon thay doi gi, acceptance criteria va out-of-scope | QA |
| Current behavior | Ghi lai he thong hien dang behave the nao va source nao xac nhan | QA + Engineer neu can |
| Business history | Ghi rule/exception/decision lien quan, hoac "unknown" neu chua co source | QA + Product neu can |
| QA verification plan | Bien context thanh scenarios must-have/regression/risk-based | QA |
| Final verification memory | Luu ket qua verify, evidence, risk, decision va note cho lan sau | QA |

Nguyen tac MVP:

- Neu chua biet current behavior/business history, record phai ghi "unknown" va tao question, khong duoc suy dien.
- Record duoc tao tai ready-for-QA, nhung final memory chi hoan tat sau khi QA verify.
- Record la shared context de thao luan, khong phai approval artifact tu dong.
- Storage/publish channel de quyet dinh sau; product value truoc mat nam o chat luong record.

### Core entities

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

### Minimum data contract cho Phase 1

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
  blocking: boolean # true only when expected behavior is unclear

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

## 12. AWS AI ecosystem fit

Decision 2026-07-23 revised: Phase 1 dung **Bedrock + retrieval/RAG don gian + AgentCore runtime boundary**.

Ly do:

- Phase 1 output la artifact draft/review, khong phai autonomous agent action.
- Core value la tong hop shared verification context co citation, khong phai tool orchestration nhieu buoc.
- Team can validate prompt contract, source quality, QA review workflow va evaluation truoc.
- Tuy nhien van nen dua AgentCore vao Phase 1 neu muc tieu la pilot theo production shape: co runtime boundary, session isolation, endpoint, trace/observability va duong nang cap len tool-integrated agent.
- AgentCore Gateway/Identity/Policy/write tools van de Phase 2 khi agent can goi ticketing/PR/test/evidence tools nhieu buoc.

Can phan biet ro:

- **AgentCore Phase 1**: host/wrap QA Assistant nhu mot agent runtime co contract ro; dung cho invoke/session/trace/deploy discipline.
- **AgentCore Phase 2**: them Gateway, Memory, Identity, Policy, tool calling va write actions.

Phase 1 ap dung AWS AI ecosystem theo huong sau:

| Need | AWS layer phu hop | Ghi chu |
|---|---|---|
| Summarize ticket/spec/test result | Amazon Bedrock | Goi foundation model qua Converse/InvokeModel |
| RAG tren source-of-truth docs, historical tickets, QA guideline | Bedrock Knowledge Bases | Can ACL/freshness/citation policy ro |
| Doi chieu ticket voi business history/current behavior | Bedrock + Knowledge Bases + code/doc retrieval | Day la core value: ticket is not the truth |
| Tim codebase signals: component/API/routes/tests/config | Code search/repo index + Bedrock reasoning | Can cite file/path/test va khong suy dien qua muc |
| Guardrail cho PII, prompt attack, noi dung khong duoc luu | Bedrock Guardrails | Apply input/output theo policy |
| Runtime boundary cho QA Assistant | AgentCore Runtime/Harness | Phase 1 neu muon pilot gan voi production deployment |
| Agent goi ticketing/PR/test/evidence tools nhieu buoc | AgentCore Gateway + Runtime/Harness | Phase 2 neu can multi-tool agent production |
| Memory theo QA/project/domain | AgentCore Memory | Phase 2; chi luu thong tin duoc phep nho |
| Tool policy va outbound auth | AgentCore Gateway + Identity + Policy | Phase 2; can khi agent co the tao/update ticket/document |
| Observability/evaluation | CloudWatch + AgentCore Evaluations/Bedrock eval | Can trace, token, tool latency, quality score |
| Evidence/file storage | S3/Drive/Docs tuy stack hien co | Can retention va permission boundary |

Phase 1 pragmatic path: AgentCore-wrapped Bedrock/RAG draft-only

```text
QA-Agents app
  -> auth/user context
  -> AgentCore Runtime/Harness endpoint
  -> ticket + QA input
  -> optional retrieval/RAG from approved docs
  -> Bedrock prompt contracts + Guardrails
  -> Ready-for-QA Verification Context Record
  -> QA review/edit/confirm
  -> source-of-truth document generator
  -> audit log + metrics
```

Phase 2 agent path: AgentCore tool-integrated QA Agent

```text
QA-Agents app
  -> AgentCore Runtime/Harness
  -> Memory by ticket/project/user
  -> Gateway tools:
       ticket tool
       PR diff tool
       CI/test result tool
       evidence storage tool
       source-of-truth document tool
  -> Policy approval for write actions
  -> Observability + Evaluations
```

## 13. Prompt contracts

### Ticket brief prompt output

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

### Current-state brief prompt output

```json
{
  "current_behavior_summary": "string",
  "related_business_rules": [
    {
      "rule": "string",
      "source": "ticket|doc|decision_log|release_note|human_note",
      "source_ref": "string"
    }
  ],
  "related_code_signals": [
    {
      "area": "component|api|route|service|config|test",
      "path_or_ref": "string",
      "why_relevant": "string",
      "confidence": "low|medium|high"
    }
  ],
  "implementation_shape": {
    "layers": ["ui|api|database|config|background_job|permission|integration|unknown"],
    "source": "engineer_note|pr_diff|code_signal|qa_input|unknown",
    "confidence": "low|medium|high",
    "needs_engineer_confirmation": true
  },
  "impacted_flows": ["string"],
  "existing_test_coverage": ["string"],
  "ticket_current_state_mismatch": ["string"],
  "questions_for_product_or_engineer": ["string"]
}
```

### Clarification block prompt output

```json
{
  "clarifications": [
    {
      "area": "current_behavior|business_rule|implementation_hint|scope|evidence",
      "owner_suggested": "product|engineer|qa_lead",
      "context": ["string"],
      "questions": ["string"],
      "why_this_matters": "string",
      "needed_before": "test_planning|qa_execution|product_signoff|release",
      "blocking": true,
      "blocking_reason": "expected_behavior_unclear|coverage_risk_only|none",
      "copyable_message": "string"
    }
  ]
}
```

### Test matrix prompt output

```json
{
  "test_cases": [
    {
      "requirement_ref": "string",
      "context_ref": "string",
      "title": "string",
      "type": "positive|negative|regression|permission|data|ui|api",
      "priority": "p0|p1|p2",
      "steps": ["string"],
      "expected_result": "string",
      "evidence_required": ["string"],
      "risk_if_missed": "string"
    }
  ]
}
```

### Final verification note output

```json
{
  "ticket_id": "string",
  "environment": "string",
  "build_version": "string",
  "qa_status": "pass|fail|blocked|needs_product_clarification",
  "verified_scope": ["string"],
  "test_summary": [
    {
      "test_case": "string",
      "result": "pass|fail|blocked",
      "evidence": ["uri"],
      "notes": "string"
    }
  ],
  "defects": ["string"],
  "known_risks": ["string"],
  "product_verification_recommendation": "string"
}
```

## 14. Guardrails va human control

Bat buoc co cac rule sau:

- AI output la draft, khong phai final decision.
- Moi write action can human confirmation:
  - tao/update defect;
  - update ticket status;
  - publish source-of-truth document;
  - notify Product/Engineer.
- AI phai cite input source khi dua ra claim:
  - ticket section;
  - acceptance criteria;
  - PR/diff;
  - code path/test/config neu claim ve codebase current state;
  - test evidence;
  - historical docs.
- AI phai phan biet ro:
  - "confirmed by source";
  - "inferred from code/doc";
  - "needs human confirmation".
- Neu khong co du source ve current behavior, AI phai noi "unknown" thay vi suy dien.
- Neu khong co engineer note/PR/code signal ro, AI khong duoc khang dinh implementation shape. Chi duoc de xuat hypothesis kem confidence va question cho engineer.
- Khong dua PII/secrets/log sensitive vao model neu chua co masking policy.
- Memory chi duoc luu thong tin da duoc policy cho phep, co namespace theo project/ticket/user.

## 15. Evaluation plan

Can tao golden set gom cac ticket that hoac synthetic:

| Metric | Cach danh gia |
|---|---|
| Requirement extraction accuracy | AI co lay dung acceptance criteria khong |
| Current-state mismatch detection | AI co flag dung ticket/current behavior mismatch khong |
| Impact surface usefulness | QA/Engineer co thay impacted flows/modules huu ich khong |
| Code signal precision | Related code paths/tests co dung va cite duoc khong |
| Implementation-shape humility | AI co tranh khang dinh UI/API/DB khi thieu source khong |
| Test coverage usefulness | QA danh gia test cases co bat dung risk khong |
| Hallucination rate | AI co them requirement khong co trong source khong |
| Evidence completeness | Final note co du screenshot/log/build/env khong |
| Defect wording quality | Bug report co repro steps, expected/actual, evidence khong |
| QA time saved | So sanh thoi gian verify truoc/sau |
| Human override rate | QA phai sua output bao nhieu |

Release gate de xuat:

- 0 P0 hallucination tren golden set.
- >= 80% test-case suggestions duoc QA danh gia useful hoac partially useful.
- 100% final notes co ticket id, build/environment, status, evidence summary.
- Write actions bi chan neu thieu human confirmation.

## 16. Cost va operation watch

Cost drivers:

- Model input/output tokens cho ticket/spec/PR diff/test evidence.
- Retrieval calls neu dung Knowledge Base.
- Guardrail evaluation.
- Tool calls neu dung AgentCore/Gateway Phase 2.
- CloudWatch logs/traces.
- Evidence storage.

Cost controls:

- Summarize long ticket/PR diff theo chunk truoc khi dua vao final prompt.
- Cache ticket brief va approved test matrix theo session.
- Gioi han max output tokens theo artifact type.
- Khong bat web search/browser/code interpreter trong Phase 1 neu chua can.
- Log metadata va hashes thay vi full payload sensitive.

Ops controls:

- Correlation id cho moi verification session.
- Version prompt contracts.
- Track model id, prompt version, source docs, user edits.
- Dashboard: latency, token, error, human override, final status, defect count.
- Runbook: model outage, ticket integration outage, evidence upload failure, bad AI recommendation.

## 17. Rollout plan

### Phase 0: RFC va design alignment

- Chot journey va target user.
- Chot integration source: ticketing, PR, evidence, docs.
- Chot what AI can/cannot do.

### Phase 1: QA Assistant draft-only

- Ready-for-QA Verification Context Record.
- Minimum context: ticket + QA input.
- AWS fit: Bedrock + retrieval/RAG don gian, wrapped/hosted qua AgentCore Runtime/Harness neu pilot can production-shaped deployment.
- Khong dung AgentCore Gateway/write tools trong MVP neu chua co tool action nhieu buoc.
- Ticket intent + current behavior + business history draft.
- Test matrix generator based on approved context.
- Verification checklist.
- Final verification memory draft.
- No external write without manual copy/paste or explicit confirm.

### Phase 2: Tool-integrated QA Agent

- Ticket tool read/write.
- PR diff/read tool.
- Evidence upload/link tool.
- Source-of-truth doc publish tool.
- Human approval before write actions.

### Phase 3: Production agent platform

- AgentCore Runtime/Harness.
- Gateway tool catalog.
- Identity/Policy.
- Memory.
- Observability/Evaluations.
- Cost/quota guardrails.

## 18. Decision records: options va rationale

Section nay ghi ro cac option da can nhac de RFC khong chi la danh sach quyet dinh. Moi quyet dinh can co rationale de Product/QA/Engineer co the challenge, accept, hoac doi huong.

### DR1. Root problem

| Option | Mo ta | Danh gia |
|---|---|---|
| A. AI generate test cases | Tap trung tao test cases tu ticket | De demo, nhung de bien thanh feature nho; khong giai quyet ticket thieu context hoac verify sai scope |
| B. AI chatbot cho QA | QA hoi gi thi AI tra loi | Linh hoat, nhung output kho chuan hoa va kho tao source-of-truth |
| C. Shared verification context | Tao context chung giua QA/Product/Engineer truoc khi verify | Chon, vi giai quyet root gap: ticket, business history, current behavior, impact va evidence bi phan tan |
| D. Autonomous QA agent | Agent tu verify va update ticket | Qua som cho MVP; risk cao ve trust, permission va false confidence |

Decision: chon **C. Shared verification context**.

Why this option:

- Day la pain nam truoc test execution: neu QA hieu sai context, test cases va evidence sau do deu co the sai.
- Tao duoc artifact co the review, edit, trace, va dung lai.
- Phu hop voi Phase 1 draft-only va human-controlled workflow.

Why not others:

- Generate test cases chi la output con, khong du la product position.
- Chatbot khong dam bao workflow va evidence.
- Autonomous QA agent can integration, permissions, environment access va eval mature hon.

### DR2. Primary user va contributors

| Option | Mo ta | Danh gia |
|---|---|---|
| A. QA la primary user | QA dung tool de hieu va verify ticket | Chon, vi QA la nguoi truc tiep gap pain va tao verification record |
| B. Product la primary user | Product dung tool de tao better spec | Co gia tri, nhung khong nam o verification moment |
| C. Engineer la primary user | Engineer dung tool de viet implementation/test checklist | Co gia tri, nhung khong giai quyet QA evidence/sign-off gap dau tien |
| D. Multi-role ngang nhau | QA/Product/Engineer cung la user chinh | De lam scope mo va UX phuc tap trong MVP |

Decision: chon **QA la primary user**; Product va Engineer la **context contributors**.

Why this option:

- QA la nguoi can shared context de verify dung scope.
- Product va Engineer van quan trong, nhung nen tham gia khi can confirm business rule, expected behavior, implementation scope hoac release risk.
- Giu MVP workflow co owner ro, tranh bien tool thanh meeting platform.

Why not others:

- Product-first se thanh spec assistant.
- Engineer-first se thanh code/review assistant.
- Multi-role ngang nhau lam MVP kho do value va kho thiet ke ownership.

### DR3. MVP artifact

| Option | Mo ta | Danh gia |
|---|---|---|
| A. Test matrix | Danh sach test cases/edge cases | Can co, nhung khong du de ghi business context va decision |
| B. Clarification Block | Cau hoi de QA gui Product/Engineer | Huu ich, nhung chi xu ly missing context |
| C. QA sign-off note | Final note sau verify | Quan trong, nhung sinh ra qua muon neu khong co context tu dau |
| D. Ready-for-QA Verification Context Record | Artifact gom ticket intent, QA input, risk, ambiguity, impact, test direction va evidence expectation | Chon, vi dung lam shared context truoc khi QA execute |

Decision: chon **Ready-for-QA Verification Context Record**.

Why this option:

- Tao context tai dung thoi diem: khi ticket vao ready-for-QA.
- Lam base cho test matrix, clarification, risk summary va final sign-off note.
- Co the bat dau bang Markdown/manual artifact, chua can integration phuc tap.

Why not others:

- Test matrix va sign-off note la section/output ben trong record, khong nen la artifact goc.
- Clarification Block la co che escalation, khong phai artifact chinh.

### DR4. Minimum context cho Phase 1

| Option | Mo ta | Danh gia |
|---|---|---|
| A. Ticket only | Chi dua ticket cho AI | Qua yeu; ticket thuong khong phan anh current behavior/business history |
| B. Ticket + QA input | Ticket cong current behavior/business history/clarification tu QA | Chon, vi du nhe de pilot va van capture human context |
| C. Ticket + PR/build/source code | Them implementation context bat buoc | Co gia tri, nhung day MVP vao integration/code analysis qua som |
| D. Full enterprise RAG | Ticket + docs + historical tickets + source-of-truth + code index | Target sau, nhung qua nang cho Phase 1 |

Decision: chon **ticket + QA input**.

Why this option:

- Giam dependency integration de pilot nhanh.
- Buoc QA dua vao current context hoac mark `unknown`, giup AI khong bia.
- Neu thieu context, system tao Clarification Block hoac AI answer co nhan `unknown/inferred`.

Why not others:

- Ticket only qua de sinh hallucination hoac output chung chung.
- PR/build/source code bat buoc lam MVP phu thuoc engineering integration.
- Full RAG can data governance, freshness, ACL va citation policy chua chac san sang.

### DR5. AWS fit cho Phase 1

| Option | Mo ta | Danh gia |
|---|---|---|
| A. Bedrock only | App goi Bedrock truc tiep | Don gian nhat, nhung thieu production-shaped agent boundary |
| B. Bedrock + RAG | Them retrieval tu approved docs | Can cho source-backed context, nhung van chua co agent runtime discipline |
| C. Bedrock/RAG + AgentCore Runtime/Harness boundary | AgentCore host/wrap QA Assistant, Bedrock lam reasoning/generation | Chon, vi giu production direction nhung chua day vao tool automation |
| D. Full AgentCore multi-tool agent | Runtime + Gateway + Memory + Identity + write tools ngay tu MVP | Qua som; tang risk permission, tool correctness, eval va ops |

Decision: chon **Bedrock/RAG + AgentCore Runtime/Harness boundary** cho Phase 1.

Why this option:

- Phu hop voi quan diem van dung AgentCore, nhung o muc don gian.
- AgentCore tao endpoint/runtime/session/trace/deploy discipline cho QA Assistant.
- Bedrock/RAG van la core cho synthesis va citation.
- Cho duong nang cap sach len Gateway/Memory/Identity/Policy o Phase 2.

Why not others:

- Bedrock only/Bedrock + RAG only co the nhanh hon, nhung khong hoc duoc AgentCore production shape.
- Full AgentCore multi-tool agent la overbuild cho MVP draft-only.

### DR6. AI answer authority

| Option | Mo ta | Danh gia |
|---|---|---|
| A. AI chi dat cau hoi | AI khong tra loi ambiguity | An toan, nhung lam workflow cham va giam value cua assistant |
| B. AI tra loi co boundary | AI tra loi neu co source/context, gan nhan source-backed/inferred/unknown va confidence/risk | Chon, vi giam clarification loop nhung van giu human authority |
| C. AI tu quyet dinh expected behavior | AI coi cau tra loi la final | Khong chap nhan cho QA/business workflow |

Decision: chon **AI tra loi co boundary**.

Why this option:

- AI co the giam thoi gian hieu ticket neu source/context da du.
- Gan nhan confidence/risk giup QA biet diem nao dung duoc, diem nao can confirm.
- Van giu Product/Engineer/QA la authority cuoi cho business rule, implementation scope, release risk va final sign-off.

Why not others:

- AI chi hoi se bien tool thanh question generator.
- AI final authority tao false confidence va risk verify sai scope.

### DR7. Write actions va escalation

| Option | Mo ta | Danh gia |
|---|---|---|
| A. Manual copy/paste Clarification Block | AI tao block, QA copy/gui | Chon cho MVP vi giu draft-only va giam permission/integration risk |
| B. AI tao comment/ticket draft trong tool | AI draft vao ticket system, cho QA approve | Phase 2 tot, nhung can integration va approval UX |
| C. AI tu write/update ticket/doc | Agent tu dong ghi vao system | Qua som va rui ro cao |

Decision: chon **manual Clarification Block** cho Phase 1.

Why this option:

- Giu AI la assistant, khong phai actor co quyen write.
- Van giam friction cho QA vi cau hoi da duoc structure.
- De pilot ma chua can ticketing integration.

Why not others:

- Draft/comment truc tiep can OAuth, permissions, audit va undo.
- Auto-write can trust/eval/approval policy mature hon.

### DR8. MVP success metrics

| Option | Mo ta | Danh gia |
|---|---|---|
| A. Chon mot metric duy nhat | Vi du time saved | De report, nhung de optimize sai neu bo qua quality/risk |
| B. Do toan bo metric set | Speed, alignment, mismatch, coverage, regression, evidence, defect quality, release confidence | Chon, vi MVP can validate value da chieu |
| C. Chi do qualitative feedback | Nhanh, nhung kho defend business case |

Decision: chon **metric set day du**.

Why this option:

- QA-Agents khong chi tiet kiem thoi gian; no can tang quality va shared context.
- Cac metric giup phan biet output dep voi business value that.
- Van co the chon leading indicator cho pilot dashboard sau.

Why not others:

- Time saved khong du neu QA van miss regression.
- Qualitative-only khong du de ra quyet dinh dau tu tiep.

## 19. Open questions

1. Ticket source la gi: Jira, Linear, GitHub Issues, ClickUp, hay system noi bo?
2. Test cases hien dang o dau: spreadsheet, test management tool, Markdown, repo, hay tribal knowledge?
3. Source-of-truth document nen publish o dau: Git repo, Notion, Confluence, Google Docs, hay ticket comment?
4. QA evidence hien dang luu o dau: Drive, S3, CI artifacts, test tool, hay attachment trong ticket?
5. PR/build/source code/historical docs nen duoc dua vao optional enrichment theo rule nao, va khi nao moi nang len dependency?
6. AI duoc phep tao defect/ticket draft truc tiep khong, hay chi generate text de QA copy?
7. Data nao bi cam dua vao model: PII, customer data, secrets, logs production?
8. Trong cac metric MVP da chot, metric nao la leading indicator cho pilot dau tien: time-to-understand, shared-context alignment, mismatch detection, hay evidence completeness?

## 20. Discussion proposal

De tiep tuc trao doi, nen review cac quyet dinh sau:

1. **MVP artifact**: Ready-for-QA Verification Context Record.
2. **Trigger point**: record duoc tao khi ticket chuyen sang ready for QA.
3. **Intake model**: hybrid intake = structured form + AI follow-up khi thieu/mau thuan.
4. **Current behavior ownership**: QA-first, conditional Engineer/Product confirmation.
5. **Escalation model**: AI tao Clarification Block de QA copy gui Product/Engineer.
6. **AI answer authority**: AI co quyen tra loi trong boundary draft/source-backed; human authority van confirm cac diem risk cao.
7. **AWS fit**: Phase 1 dung Bedrock/RAG don gian + AgentCore runtime boundary; Gateway/write tools danh cho Phase 2 khi co multi-tool agent.
8. **Minimum context**: ticket + QA input.

Recommendation hien tai:

- Root problem da chot: **shared verification context**.
- Primary user da chot: **QA**. Product va Engineer la **context contributors** khi can bo sung business/implementation context.
- Pain set da chot: QA mat thoi gian hieu ticket, verify sai scope, team khong cung context, evidence/documentation thieu, regression bi miss.
- Business outputs da chot: shared verification context, risk summary, QA sign-off note, release confidence record, defect-quality improvement.
- MVP success da chot: do toan bo nhom metric ve speed, alignment, mismatch detection, test coverage, regression risk, evidence completeness, defect quality va release confidence.
- Phase 1 nen la **QA Assistant draft-only** tai ready-for-QA.
- MVP artifact da chot: **Ready-for-QA Verification Context Record**.
- AWS fit da chot: **Bedrock + retrieval/RAG don gian + AgentCore Runtime/Harness boundary cho Phase 1**. AgentCore Gateway/Identity/Policy/write tools danh cho Phase 2 neu can tool-integrated QA Agent.
- Minimum context da chot: **ticket + QA input**. PR/build/source code/historical docs la optional inputs, khong phai MVP dependency.
- Intake nen la **hybrid**: 3 field bat buoc + optional links/impacted flows + AI follow-up co dieu kien.
- Current behavior ownership nen la **QA-first, conditional confirmation**.
- AI answer authority da chot: **AI duoc tra loi neu co source/context ro, phai gan nhan source-backed/inferred/unknown va confidence/risk; human confirm cac diem business/implementation/release risk cao**.
- Escalation nen la **Clarification Block manual copy**, chua tao comment/message truc tiep.
- Input minimum: **ticket + QA-entered current behavior/business history/clarification**. PR/build/source code/historical docs chi la optional enrichment.
- Storage/publish channel de danh gia sau; ban dau co the dung Markdown/manual artifact de validate product value.
