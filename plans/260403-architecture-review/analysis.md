# Claude Code Architecture Analysis & AIE-Skills Direction

## Date: 2026-04-03

---

## 1. Claude Code Architecture — Key Takeaways

Sources: [ccleaks.com/architecture](https://www.ccleaks.com/architecture), [promptlayer analysis](https://blog.promptlayer.com/claude-code-behind-the-scenes-of-the-master-agent-loop/), [penligent deep-dive](https://www.penligent.ai/hackinglabs/inside-claude-code-the-architecture-behind-tools-memory-hooks-and-mcp/), [chrisbora substack](https://chrisbora.substack.com/p/claude-code-is-not-what-you-think)

Content was rephrased for compliance with licensing restrictions.

### Core Design Philosophy

Claude Code là 512K+ lines, 1800+ files — nhưng triết lý cốt lõi cực kỳ đơn giản:

**"The model is not the product. The product is the system around the model."**

| Layer | Chức năng | Tương đương Kiro |
|-------|----------|-----------------|
| Agent Loop (`query.ts`) | Single-threaded while(tool_call) loop | Kiro agent loop (built-in) |
| Tool System (43+ tools) | JSON tool calls → sandboxed execution → text results | Kiro tools (built-in) |
| Memory (`CLAUDE.md` + auto memory) | Persistent project knowledge + learned patterns | Steering (`always`) + CLAUDE.md equivalent |
| Context Compaction | Multi-layer: micro, auto, reactive compaction at ~92% | Kiro handles internally |
| Permission System | 4 scopes: Managed → User → Project → Local | Kiro permission modes |
| Hooks | PreToolUse, PostToolUse, ConfigChange... | Kiro hooks (same concept) |
| Sub-agents | Same loop, recursive spawn, own context window | Kiro sub-agents |
| Skills | SKILL.md — portable instruction packages | Kiro skills (same spec) |
| Plugins | Bundle skills + agents + hooks + MCP | Kiro Powers |
| MCP | External tool/data integration | Kiro MCP |
| Sandboxing | OS-level (Seatbelt/bubblewrap) for Bash | Kiro sandbox (built-in) |

### Những insight quan trọng nhất

**a) "Simple loop, rich environment"**
- Không dùng multi-agent swarm. Một loop duy nhất: think → act → observe → repeat
- Sub-agents = same loop chạy recursive, KHÔNG phải system riêng
- Planning không phải module riêng — emerge từ cách prompt được build

**b) Memory là stack, không phải single strategy**
- CLAUDE.md = stable rules (team viết)
- Auto memory = learned patterns (agent viết)
- Conversation history = transient
- Compaction = multi-layer (micro → auto → reactive)
- Quan trọng: "Most 'Claude drifted' complaints are really context-budget complaints"

**c) Tools là vocabulary of governance**
- Permission rules refer to tool names
- Hook matchers refer to tool names
- Sub-agent allowlists refer to tool names
- MCP tools appear as regular tools
→ Một ngôn ngữ governance thống nhất

**d) Extension layers có trust surface khác nhau**

| Mechanism | Adds capability? | Changes policy? | Trust level |
|-----------|-----------------|----------------|-------------|
| Skill | No | No (shapes behavior) | Low risk |
| Hook | No (by itself) | Yes | Medium risk |
| Plugin/Power | Sometimes (via MCP) | Potentially | Higher risk |
| MCP | Yes | Indirectly | Highest risk |

**e) Anti-distillation mechanisms**
- Fake tools injected vào system để poison training data extraction
- ~90 feature flags — version bạn chạy ≠ version internal

---

## 2. So sánh với cách tổ chức hiện tại của AIE-Skills

### Hiện tại: Centralized Skill Repo

```
AIE-Skills/                    ← Mono-repo chứa TẤT CẢ skills
├── .kiro/
│   ├── skills/               ← 19 skills
│   ├── steering/             ← 2 steering files
│   ├── hooks/                ← 3 hooks (auto-update README)
│   └── install.sh            ← Copy sang project khác
├── docs/                     ← Best practices, compatibility guide
└── plans/                    ← Implementation plans
```

### Ưu điểm hiện tại
1. Một nơi duy nhất để maintain tất cả skills
2. install.sh đơn giản, copy-based distribution
3. Docs tập trung, dễ reference
4. Hooks auto-update README — neat

### Vấn đề hiện tại
1. **Coupling cao**: Mọi skill sống chung repo → thay đổi 1 skill = noise cho tất cả
2. **No versioning per skill**: Không biết skill nào version nào, update gì
3. **Install = full copy**: Không selective install, không update mechanism
4. **Steering quá ít**: Chỉ 2 files cho 19 skills — thiếu domain-specific conventions
5. **Không có skill interconnection map**: Skills reference nhau nhưng không có formal map
6. **Hooks chỉ phục vụ repo maintenance**: Chưa có hooks cho actual ML workflow

---

## 3. Lessons từ Claude Code → Áp dụng cho AIE-Skills

### Lesson 1: "The system around the model matters more"

Claude Code đầu tư 50K+ lines cho tool orchestration, 12K+ lines cho bash security parsing. Tương tự, AIE-Skills nên đầu tư vào **orchestration layer** — không chỉ viết skills mà còn viết cách skills phối hợp.

**Action**: Tạo skill interconnection map + workflow steering files

### Lesson 2: Memory = Stack of strategies

Claude Code dùng CLAUDE.md (stable) + auto memory (learned) + compaction (transient). AIE-Skills hiện chỉ có steering (`always`). Cần thêm:
- `fileMatch` steering cho từng domain (training, inference, deployment...)
- `auto` steering cho patterns agent tự match

**Action**: Tạo thêm domain-specific steering files

### Lesson 3: Progressive trust & governance

Claude Code có 4 scope levels, permission modes, hooks as policy. AIE-Skills chưa có governance layer nào.

**Action**: Tạo hooks cho critical ML workflows (pre-training checks, deployment gates)

### Lesson 4: Sub-agents as context boundaries

Claude Code dùng sub-agents để isolate context, không chỉ để parallelize. AIE-Skills có thể tạo specialized sub-agent definitions cho common workflows.

**Action**: Define sub-agent patterns trong steering

### Lesson 5: Extension trust surface awareness

MCP servers = highest risk. Skills = lowest risk. AIE-Skills nên document rõ trust model khi thêm MCP-based powers.

**Action**: Thêm trust/security section vào docs

---

## 4. Đề xuất hướng phát triển

### Phase 1: Strengthen Current Repo (Short-term)

| Task | Priority | Effort |
|------|----------|--------|
| Tạo `docs/skill-interconnection-map.md` | High | Low |
| Thêm domain steering: `ml-training-conventions.md`, `inference-deployment.md` | High | Medium |
| Thêm workflow hooks: pre-training checklist, deployment gate | Medium | Low |
| Version tracking per skill (CHANGELOG trong mỗi skill folder) | Medium | Low |
| Selective install (install by skill name) | Medium | Medium |

### Phase 2: Architecture Evolution (Medium-term)

**Option A: Enhanced Mono-repo (Recommended)**

Giữ mono-repo nhưng thêm orchestration layer:

```
AIE-Skills/
├── .kiro/
│   ├── skills/                    ← Skills (giữ nguyên)
│   ├── steering/
│   │   ├── kiro-component-creation.md    ← always
│   │   ├── notebook-conventions.md       ← fileMatch: *.ipynb
│   │   ├── ml-training-workflow.md       ← auto: training, fine-tune
│   │   ├── inference-deployment.md       ← auto: deploy, serve, vllm
│   │   ├── data-pipeline.md             ← auto: dataset, embedding, RAG
│   │   └── gpu-environment.md           ← fileMatch: Dockerfile, docker-compose*
│   ├── hooks/
│   │   ├── update-readme-index.kiro.hook
│   │   ├── pre-training-checklist.kiro.hook    ← NEW
│   │   └── deployment-review.kiro.hook         ← NEW
│   └── install.sh                 ← Enhanced: selective install
├── docs/
│   ├── kiro-compatible.md
│   ├── skill-creation-best-practices.md
│   ├── skill-interconnection-map.md    ← NEW
│   ├── trust-model.md                  ← NEW
│   └── development-roadmap.md          ← NEW
└── plans/
```

Lý do chọn Option A:
- Claude Code cũng là mono-repo (1800+ files, 1 codebase)
- Skill interconnection dễ maintain hơn khi cùng repo
- Install script đã có, chỉ cần enhance
- Không cần infra phức tạp (package registry, versioning system)

**Option B: Modular Packages (Future consideration)**

Nếu scale lên 50+ skills hoặc cần multi-team contribution:
- Mỗi skill = npm/pip package hoặc git submodule
- Central registry + dependency resolution
- Nhưng complexity cao, chưa cần thiết ở scale hiện tại

### Phase 3: Power Development (Long-term)

Khi có MCP servers cần integrate:
- Tạo Powers cho common ML workflows (HuggingFace Power, NVIDIA Power...)
- Bundle: MCP server + steering + hooks + skills
- Đây là evolution tự nhiên khi cần external tool integration

---

## 5. Best Practices đúc kết

### Từ Claude Code Architecture

1. **Keep the loop simple, make the environment rich** — Đừng over-engineer orchestration. Viết skills tốt + steering rõ ràng > complex multi-agent system
2. **Memory is a stack** — Dùng đúng layer: steering (stable rules), auto memory (learned), conversation (transient)
3. **Tools are the governance vocabulary** — Hook vào tool names, không vào abstract concepts
4. **Progressive trust** — Start restrictive, widen as needed. Plan mode trước, auto mode sau
5. **Sub-agents for context isolation** — Delegate để giữ main context clean, không chỉ để parallelize
6. **Treat config as executable** — .kiro/, steering, hooks = code. Review chúng như code

### Cho AIE-Skills cụ thể

1. **Skill = HOW, not WHAT** — Giữ imperative style, không educational
2. **Interconnection > Isolation** — Skills mạnh hơn khi biết chain sang nhau
3. **Steering = team conventions** — Mỗi domain cần steering riêng
4. **Hooks = automated gates** — Dùng cho quality/safety checks, không chỉ repo maintenance
5. **Install = selective** — Cho phép install subset, không force full copy
6. **Document trust surface** — Rõ ràng skill vs hook vs MCP risk levels

---

## 6. Unresolved Questions

1. Kiro có plan support sub-agent definitions kiểu Claude Code không? (custom agents with tool allowlists)
2. Kiro Powers ecosystem sẽ phát triển thế nào? Có package registry không?
3. Skill versioning — nên dùng git tags, CHANGELOG, hay cả hai?
4. Cross-project skill sharing — install.sh đủ hay cần package manager?
5. Auto steering (`auto` inclusion) — Kiro match accuracy thế nào trong thực tế?
