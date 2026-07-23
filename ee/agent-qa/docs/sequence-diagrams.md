# ETUS — Sequence Diagrams

> Detailed interaction sequences for the major runtime flows.

---

## 1. Test Run Sequence (CLI → Core → Platform)

```
┌──────┐    ┌──────────┐    ┌────────┐    ┌──────────┐    ┌─────────┐    ┌───────┐
│ User │    │   CLI    │    │  Core  │    │ Planner  │    │ Adapter │    │  LLM  │
└──┬───┘    └────┬─────┘    └───┬────┘    └────┬─────┘    └────┬────┘    └───┬───┘
   │             │              │              │               │             │
   │ etus-agent run│              │              │               │             │
   │────────────▶│              │              │               │             │
   │             │              │              │               │             │
   │             │ resolveConfig()             │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │               │             │
   │             │ discoverWorkspaceFiles()    │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │               │             │
   │             │ resolveTarget()             │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │               │             │
   │             │ resolveLLMModels()          │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │ resolveLLMAuth()             │             │
   │             │              │─────────────▶│               │             │
   │             │              │              │               │             │
   │             │ createPlatformAdapter()     │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │ adapter.setup()│             │
   │             │              │──────────────────────────────▶│             │
   │             │              │              │               │ Launch      │
   │             │              │              │               │ Browser/App │
   │             │              │              │               │             │
   │             │ runHooks(setup)             │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │ [Docker sandbox per hook]    │             │
   │             │              │              │               │             │
   │             │ runTestWithRetry()          │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │               │             │
   │             │              │ ┌─── For each step ───┐     │             │
   │             │              │ │                     │     │             │
   │             │              │ │ executeStep()       │     │             │
   │             │              │ │    │                │     │             │
   │             │              │ │    │ observe()      │     │             │
   │             │              │ │    │───────────────────────▶│             │
   │             │              │ │    │◀──────────────────────│ScreenState  │
   │             │              │ │    │                │     │             │
   │             │              │ │    │ screenshot()   │     │             │
   │             │              │ │    │───────────────────────▶│             │
   │             │              │ │    │◀──────────────────────│ Buffer      │
   │             │              │ │    │                │     │             │
   │             │              │ │    │ plan()         │     │             │
   │             │              │ │    │───────────────▶│     │             │
   │             │              │ │    │               │     │             │
   │             │              │ │    │               │ generateText()    │
   │             │              │ │    │               │─────────────────────▶│
   │             │              │ │    │               │◀────────────────────│
   │             │              │ │    │               │ tool_call(action)  │
   │             │              │ │    │◀──────────────│     │             │
   │             │              │ │    │ ActionPlan    │     │             │
   │             │              │ │    │                │     │             │
   │             │              │ │    │ execute(action)│     │             │
   │             │              │ │    │───────────────────────▶│             │
   │             │              │ │    │◀──────────────────────│ActionResult │
   │             │              │ │    │                │     │             │
   │             │              │ │    │ [if stepComplete]    │             │
   │             │              │ │    │ return StepResult    │             │
   │             │              │ │    │                │     │             │
   │             │              │ └────┘                │     │             │
   │             │              │              │               │             │
   │             │              │ TestResult   │               │             │
   │             │◀─────────────│              │               │             │
   │             │              │              │               │             │
   │             │ report results              │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │               │             │
   │             │ runHooks(teardown)          │               │             │
   │             │─────────────▶│              │               │             │
   │             │              │              │               │             │
   │             │ adapter.cleanup()           │               │             │
   │             │─────────────────────────────────────────────▶│             │
   │             │              │              │               │             │
   │◀────────────│ Exit(0|1)   │              │               │             │
   │             │              │              │               │             │
```

---


## 2. Agent Loop Detail (Single Step with Healing)

```
┌───────────┐    ┌─────────┐    ┌────────┐    ┌─────────┐    ┌────────┐
│ Runner    │    │  Cache  │    │Planner │    │ Adapter │    │Verifier│
└─────┬─────┘    └────┬────┘    └───┬────┘    └────┬────┘    └───┬────┘
      │               │             │              │              │
      │ executeStep("Click login button")         │              │
      │               │             │              │              │
      │ ┌──── Sub-Action Loop (i=0..maxSubActions) ────┐        │
      │ │             │             │              │    │         │
      │ │ observe()   │             │              │    │         │
      │ │─────────────────────────────────────────▶│    │         │
      │ │◀────────────────────────────────────────│    │         │
      │ │ ScreenState{tree, url, metadata}        │    │         │
      │ │             │             │              │    │         │
      │ │ screenshot()│             │              │    │         │
      │ │─────────────────────────────────────────▶│    │         │
      │ │◀────────────────────────────────────────│    │         │
      │ │ Buffer (compressed via sharp)           │    │         │
      │ │             │             │              │    │         │
      │ │ getSubAction(stepHash, i)│              │    │         │
      │ │────────────▶│             │              │    │         │
      │ │             │             │              │    │         │
      │ │ [CACHE HIT] │             │              │    │         │
      │ │◀────────────│ ActionPlan  │              │    │         │
      │ │             │             │              │    │         │
      │ │ [CACHE MISS]│             │              │    │         │
      │ │ invalidateSubActionsFrom(hash, i)       │    │         │
      │ │────────────▶│             │              │    │         │
      │ │             │             │              │    │         │
      │ │ plan(step, screenState, context)        │    │         │
      │ │──────────────────────────▶│              │    │         │
      │ │             │             │ [AI SDK      │    │         │
      │ │             │             │  generateText│    │         │
      │ │             │             │  tool_use]   │    │         │
      │ │◀──────────────────────────│              │    │         │
      │ │ PlanResult{plan, tokenUsage}            │    │         │
      │ │             │             │              │    │         │
      │ │ [if plan.stepFailed] → return FAILURE   │    │         │
      │ │             │             │              │    │         │
      │ │ execute(action)           │              │    │         │
      │ │─────────────────────────────────────────▶│    │         │
      │ │◀────────────────────────────────────────│    │         │
      │ │ ActionResult{success, error?, coords?}  │    │         │
      │ │             │             │              │    │         │
      │ │ [if exec failed]          │              │    │         │
      │ │   consecutiveFailures++   │              │    │         │
      │ │   [if >= healingLimit] → return FAILURE  │    │         │
      │ │   [else continue loop]    │              │    │         │
      │ │             │             │              │    │         │
      │ │ [if exec success + plan.stepComplete]   │    │         │
      │ │   setSubAction(hash, i, plan)           │    │         │
      │ │────────────▶│             │              │    │         │
      │ │   return SUCCESS          │              │    │         │
      │ │             │             │              │    │         │
      │ │ [if exec success + !stepComplete]       │    │         │
      │ │   setSubAction(hash, i, plan)           │    │         │
      │ │────────────▶│             │              │    │         │
      │ │   continue loop (i++)     │              │    │         │
      │ │             │             │              │    │         │
      │ └─────────────────────────────────────────┘    │         │
      │               │             │              │              │
      │ StepResult    │             │              │              │
      │◀──────────────│             │              │              │
```

---


## 3. Dashboard Interaction Flow

```
┌─────────┐     ┌──────────────┐     ┌──────────┐     ┌─────────┐     ┌────────┐
│ Browser │     │ Dashboard UI │     │  Server  │     │   DB    │     │  Core  │
│ (User)  │     │   (React)    │     │ (Node.js)│     │(SQLite) │     │(Runner)│
└────┬────┘     └──────┬───────┘     └────┬─────┘     └────┬────┘     └───┬────┘
     │                 │                  │                │              │
     │ Open dashboard  │                  │                │              │
     │────────────────▶│                  │                │              │
     │                 │ GET /            │                │              │
     │                 │─────────────────▶│                │              │
     │                 │◀─────────────────│ Static assets  │              │
     │◀────────────────│ Render app       │                │              │
     │                 │                  │                │              │
     │ Click "Run Test"│                  │                │              │
     │────────────────▶│                  │                │              │
     │                 │ POST /api/runs/trigger            │              │
     │                 │─────────────────▶│                │              │
     │                 │                  │ INSERT run     │              │
     │                 │                  │───────────────▶│              │
     │                 │                  │                │              │
     │                 │                  │ JobQueue.enqueue()            │
     │                 │                  │────────────────────────────────▶
     │                 │                  │                │              │
     │                 │◀─────────────────│ { runId, status: 'queued' }  │
     │                 │                  │                │              │
     │                 │                  │ ─── Queue processes job ───  │
     │                 │                  │                │              │
     │                 │                  │                │  runTest()   │
     │                 │                  │──────────────────────────────▶│
     │                 │                  │                │              │
     │                 │                  │                │   [agent     │
     │                 │                  │                │    loop      │
     │                 │                  │                │    executes] │
     │                 │                  │                │              │
     │                 │                  │ DashboardReporter.onStepEnd() │
     │                 │                  │◀─────────────────────────────│
     │                 │                  │                │              │
     │                 │                  │ INSERT step    │              │
     │                 │                  │───────────────▶│              │
     │                 │                  │ INSERT traces  │              │
     │                 │                  │───────────────▶│              │
     │                 │                  │ INSERT tokens  │              │
     │                 │                  │───────────────▶│              │
     │                 │                  │                │              │
     │                 │ GET /api/runs/:id (polling)       │              │
     │                 │─────────────────▶│                │              │
     │                 │                  │ SELECT run+steps              │
     │                 │                  │───────────────▶│              │
     │                 │                  │◀──────────────│              │
     │                 │◀─────────────────│ Run detail + steps           │
     │◀────────────────│ Render results   │                │              │
     │                 │                  │                │              │
```

---

## 4. MCP Tool Call Flow

```
┌────────────┐     ┌───────────┐     ┌──────────────┐     ┌──────────┐
│  IDE/Agent │     │MCP Server │     │Dashboard API │     │   Core   │
│  (Client)  │     │(stdio/HTTP)│     │  (HTTP)      │     │          │
└─────┬──────┘     └─────┬─────┘     └──────┬───────┘     └────┬─────┘
      │                  │                  │                   │
      │ tool_call: etus_agent_run_test       │                   │
      │ { testId: "t_...", target: "app" } │                   │
      │─────────────────▶│                  │                   │
      │                  │                  │                   │
      │                  │ Validate params (Zod)               │
      │                  │                  │                   │
      │                  │ POST /api/runs/trigger               │
      │                  │─────────────────▶│                   │
      │                  │                  │                   │
      │                  │                  │ Queue + execute   │
      │                  │                  │──────────────────▶│
      │                  │                  │                   │
      │                  │                  │◀─────────────────│ TestResult
      │                  │◀─────────────────│ { runId, status } │
      │                  │                  │                   │
      │                  │ Analytics capture │                   │
      │                  │ (PostHog event)  │                   │
      │                  │                  │                   │
      │◀─────────────────│ tool_result:     │                   │
      │ { runId, status, │ steps: [...] }   │                   │
      │                  │                  │                   │

──────────────────────────────────────────────────────────────────────

  tool_call: etus_agent_create_test
  { name: "Login flow", steps: [...], target: "app" }

      │─────────────────▶│                  │                   │
      │                  │ generateTestId() │                   │
      │                  │ (from @etus/agent-ids)            │
      │                  │                  │                   │
      │                  │ Validate against TestDefinitionSchema│
      │                  │ (from @etus/agent-core)           │
      │                  │                  │                   │
      │                  │ POST /api/tests  │                   │
      │                  │─────────────────▶│                   │
      │                  │                  │ Write YAML file   │
      │                  │◀─────────────────│                   │
      │◀─────────────────│ { testId, path } │                   │
      │                  │                  │                   │
```

---


## 5. Hook Execution Sequence

```
┌──────────┐     ┌────────────┐     ┌────────┐     ┌───────────┐
│Orchestrator│     │SandboxRunner│     │ Docker │     │Hook Script│
└─────┬─────┘     └──────┬─────┘     └───┬────┘     └─────┬─────┘
      │                  │               │               │
      │ runHooks([hook1, hook2, hook3])  │               │
      │                  │               │               │
      │ ┌── For each hook (sequential) ──┐              │
      │ │                │               │    │         │
      │ │ runHookInSandbox(hook, opts)   │    │         │
      │ │───────────────▶│               │    │         │
      │ │                │               │    │         │
      │ │                │ pullImage(image)    │         │
      │ │                │──────────────▶│    │         │
      │ │                │◀─────────────│    │         │
      │ │                │               │    │         │
      │ │                │ mkdtemp(/tmp/etus-agent-hook-*) │
      │ │                │               │    │         │
      │ │                │ cp hook.file → workDir       │
      │ │                │ cp hook.deps → workDir       │
      │ │                │               │    │         │
      │ │                │ docker run     │    │         │
      │ │                │   --rm --init  │    │         │
      │ │                │   --memory 512m│    │         │
      │ │                │   --cpus 1     │    │         │
      │ │                │   --read-only  │    │         │
      │ │                │   --network none    │         │
      │ │                │   -v workDir:/workspace      │
      │ │                │   -e ENV_VARS  │    │         │
      │ │                │──────────────▶│    │         │
      │ │                │               │    │         │
      │ │                │               │ exec command │
      │ │                │               │────────────▶│
      │ │                │               │             │
      │ │                │               │ [hook runs] │
      │ │                │               │             │
      │ │                │               │ write /tmp/etus-agent.env
      │ │                │               │ (output variables)
      │ │                │               │             │
      │ │                │               │◀────────────│ exit 0
      │ │                │               │             │
      │ │                │◀──────────────│ stdout+stderr
      │ │                │               │             │
      │ │                │ read workDir/tmp/etus-agent.env
      │ │                │ parse variables
      │ │                │ rm -rf workDir │             │
      │ │                │               │             │
      │ │◀───────────────│ HookResult{success, variables, output}
      │ │                │               │             │
      │ │ [if success] merge variables into next hook env
      │ │ [if failure] skip remaining hooks           │
      │ │                │               │             │
      │ └────────────────────────────────┘             │
      │                  │               │             │
      │ HookOrchestrationResult                       │
      │ { results, variables, allPassed, duration }    │
      │                  │               │             │
```

---

## 6. Live Editor WebSocket Session

```
┌────────┐     ┌───────────────┐     ┌───────────────┐     ┌────────┐
│Browser │     │SessionManager │     │  LiveSession  │     │  Core  │
└───┬────┘     └───────┬───────┘     └───────┬───────┘     └───┬────┘
    │                  │                     │                  │
    │ WS connect /ws   │                     │                  │
    │─────────────────▶│                     │                  │
    │                  │                     │                  │
    │ { type: 'open-session', testId }      │                  │
    │─────────────────▶│                     │                  │
    │                  │ create LiveSession  │                  │
    │                  │────────────────────▶│                  │
    │                  │                     │                  │
    │◀─────────────────│ { type: 'session-ready', content }    │
    │                  │                     │                  │
    │ { type: 'edit', content: '...' }      │                  │
    │─────────────────▶│                     │                  │
    │                  │ validate(content)   │                  │
    │                  │────────────────────▶│                  │
    │                  │                     │ TestDefinitionSchema.parse()
    │◀─────────────────│ { type: 'validation-result', valid }  │
    │                  │                     │                  │
    │ { type: 'execute-step', stepIndex: 2 }│                  │
    │─────────────────▶│                     │                  │
    │                  │────────────────────▶│                  │
    │                  │                     │ executeStep()    │
    │                  │                     │─────────────────▶│
    │                  │                     │                  │
    │                  │                     │ onPhase(observe) │
    │◀─────────────────│ { type: 'phase', phase: 'observe' }  │
    │                  │                     │                  │
    │                  │                     │ onPhase(plan)    │
    │◀─────────────────│ { type: 'phase', phase: 'plan',      │
    │                  │   reasoning: '...' }│                  │
    │                  │                     │                  │
    │                  │                     │ onPhase(execute) │
    │◀─────────────────│ { type: 'phase', phase: 'execute',   │
    │                  │   action: {...} }   │                  │
    │                  │                     │                  │
    │                  │                     │◀────────────────│StepResult
    │◀─────────────────│ { type: 'step-result', result }      │
    │                  │                     │                  │
    │ { type: 'close-session' }             │                  │
    │─────────────────▶│                     │                  │
    │                  │ destroy session     │                  │
    │                  │────────────────────▶│                  │
    │                  │                     │                  │
```

---

## 7. Auth Resolution Sequence

```
┌──────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────┐
│ CLI  │     │ LLM Utils  │     │Auth Resolver│     │ Auth Store │     │ Plugin │
└──┬───┘     └─────┬──────┘     └─────┬──────┘     └─────┬──────┘     └───┬────┘
   │               │                  │                  │                 │
   │ resolveModelAuth('openrouter', config)              │                 │
   │──────────────▶│                  │                  │                 │
   │               │                  │                  │                 │
   │               │ resolveLLMAuth('openrouter', llmConfig)              │
   │               │─────────────────▶│                  │                 │
   │               │                  │                  │                 │
   │               │                  │ getLLMAuthProviderPlugin(provider)  │
   │               │                  │────────────────────────────────────▶│
   │               │                  │◀───────────────────────────────────│
   │               │                  │ (null for openai-compatible)       │
   │               │                  │                  │                 │
   │               │                  │ getCredential('openrouter')        │
   │               │                  │─────────────────▶│                 │
   │               │                  │◀────────────────│                 │
   │               │                  │ { type:'api', provider:'openai-compatible',
   │               │                  │   key:'sk-or-...' }               │
   │               │                  │                  │                 │
   │               │                  │ [provider matches + usesApiKey]    │
   │               │                  │                  │                 │
   │               │◀─────────────────│ ResolvedLLMAuth  │                 │
   │               │  { kind:'api-key', apiKey:'sk-or-...' }              │
   │               │                  │                  │                 │
   │               │ applyResolvedAuthToModelConfig()    │                 │
   │               │ → { ...config, apiKey: 'sk-or-...' }                 │
   │               │                  │                  │                 │
   │               │ createModel(config)                 │                 │
   │               │ → createOpenAI({ apiKey, baseURL }) │                 │
   │               │ → provider.chat(model)              │                 │
   │               │                  │                  │                 │
   │◀──────────────│ LanguageModel    │                  │                 │
   │               │                  │                  │                 │
```

---

## 8. Suite Execution Flow

```
┌──────┐     ┌───────────┐     ┌──────────────┐     ┌──────────┐
│ CLI  │     │Suite Runner│     │ Test Runner  │     │ Reporter │
└──┬───┘     └─────┬─────┘     └──────┬───────┘     └────┬─────┘
   │               │                  │                   │
   │ executeSuites()│                  │                   │
   │──────────────▶│                  │                   │
   │               │                  │                   │
   │               │ onSuiteStart()   │                   │
   │               │──────────────────────────────────────▶│
   │               │                  │                   │
   │               │ runHooks(suite.setup)                │
   │               │                  │                   │
   │               │ ┌── For each test in suite ──┐      │
   │               │ │                │           │      │
   │               │ │ onTestStart()  │           │      │
   │               │ │────────────────────────────────────▶│
   │               │ │                │           │      │
   │               │ │ runTestWithRetry(test)     │      │
   │               │ │───────────────▶│           │      │
   │               │ │                │           │      │
   │               │ │                │ [steps execute]  │
   │               │ │                │           │      │
   │               │ │                │ onStepEnd()      │
   │               │ │                │───────────────────▶│
   │               │ │                │           │      │
   │               │ │◀───────────────│TestResult │      │
   │               │ │                │           │      │
   │               │ │ onTestEnd()    │           │      │
   │               │ │────────────────────────────────────▶│
   │               │ │                │           │      │
   │               │ └────────────────────────────┘      │
   │               │                  │                   │
   │               │ runHooks(suite.teardown)             │
   │               │                  │                   │
   │               │ onSuiteEnd()     │                   │
   │               │──────────────────────────────────────▶│
   │               │                  │                   │
   │◀──────────────│ SuiteResult     │                   │
   │               │                  │                   │
```
