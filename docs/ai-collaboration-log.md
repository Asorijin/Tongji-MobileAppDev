# AI 协作记录（Incremental Development Log）

> 工具：TRAE（AI 编程助手）。协作方式：**SDD 增量开发**——每个需求先写进 `docs/spec.md`，
> 再把 Prompt 限定在单个模块、单个接口内，改完必须跑回归。
> 依据作业 §16：禁止「一个 Prompt 生成整个名片 App」，必须做到
> **AI Context Control + Incremental Development + Regression Protection**。

- 记录周期：Week 1 – Week 6（按增量记录，不按日期堆砌）
- 回归基线：`swift test`（Windows，领域层 + 数据层）与 `scripts/run-tests.sh`（macOS 模拟器全量）
- 原则：**没有跑过的测试不写「通过」**。模拟器/CI 结果以运行记录为准，见 §6。

---

## 0. 为什么不是「一个 Prompt 生成整个 App」

作业 §16 明确了反面做法：

> 不允许：「请使用 SwiftUI 帮我完整复刻名片全能王。」然后直接接受 AI 生成整个系统。

本项目的实际做法与之相反：

| 维度 | 反面做法 | 本项目做法 |
| --- | --- | --- |
| 范围 | 一次生成整个 App | 一次只动一个模块/一个接口（见 §2 表格） |
| 上下文 | 把所有代码丢给 AI | 先给规格 + 现有接口 + 已通过的用例，要求「不得修改 XX」 |
| 验证 | 看截图「像不像」 | 每次改完跑全量回归；确定性行为必须有测试断言 |
| 数据 | 直接上真实名片 | 只用合成名片 + Ground Truth |
| 结果 | 看起来能跑 | 20 个确定性场景可追溯到具体测试（`docs/test-suite.md`） |

### 0.1 反例检查清单（每次提交前自检）

- [ ] 本次 Prompt 是否只涉及一个模块或一个明确接口？
- [ ] Prompt 是否明确列出了「不允许修改」的既有部分？
- [ ] 改完后是否运行了全量测试，而不只运行新用例？
- [ ] 新行为是否先写进了 `docs/spec.md`（或已有规格条目）？
- [ ] 是否有任何字段是 AI「推断」出来的而不是名片上出现的？（§8 硬约束）

---

## 1. 协作流程（每个增量都走这五步）

```text
规格（spec.md 的一句话条目）
   ↓
Prompt（限定范围 + 给出接口 + 给出已验证用例）
   ↓
TRAE 实现（只改允许的文件）
   ↓
人工审查（逐行读 diff；对照规格与 §8 不编造）
   ↓
回归（本地 swift test → 模拟器全量 → CI）
```

人工审查不是走形式。Week 4 的字段解析是概率性 AI 输出与可靠软件数据的分界线，
这里的人工核对比例最高（每个字段都要对照名片原文）。

---

## 2. 增量记录

> 每条格式：**Prompt（实际使用的请求）→ TRAE 修改范围 → 人工验证 → 回归结果**。

### 2.1 工程骨架（Week 2）

**Prompt**
> 根据 docs/spec.md 的目录结构和数据模型，生成 XcodeGen 工程定义 project.yml 与
> App 入口、AppEnvironment。只创建目录与空壳视图，不要实现 OCR、不要实现解析器。
> 要求：iOS 16.0 部署目标，单 App target，Debug 开启 ENABLE_TESTABILITY，
> 所有页面预留 Accessibility Identifier。

**TRAE 修改范围**：`project.yml`、`CamCardClone/App/*`、空的 Features 目录结构。

**人工验证**：工程能生成、空壳页面可导航；标识符与 spec.md §3 的表格一致。

**回归**：骨架阶段无测试；后续每个增量都以此工程为基线。

---

### 2.2 BusinessCard 数据模型与 CardStore（Week 2 / Week 5）

**Prompt**
> 现有 docs/data-model.md 已定义 BusinessCard Schema。请只实现 Models 与 Data 层：
> BusinessCard / Tag / ParsedContactFields，CardStore 的增删改查、搜索、标签关联、
> JSON 原子持久化、ImageStore 的相对路径。不得引入第三方依赖；日期用 ISO8601、
> 键排序；损坏存档按空存档处理。为每一类行为写 XCTest（不依赖 UIKit），
> 测试放在 CamCardDataTests/。

**TRAE 修改范围**：`Domain/Models/*`、`Data/CardStore.swift`、`Data/ImageStore.swift`、
`CamCardDataTests/CardStoreTests.swift`（12 例）。

**人工验证**：逐条对照 `docs/data-model.md` 的派生属性与电话展示契约；
确认搜索按字面量而非正则（输入 `(` 不崩溃）。

**回归**：`swift test` 数据层 12/12 通过。

---

### 2.3 字段解析器 BusinessCardFieldParser（Week 4，最重要）

**Prompt**（对应作业 §16 推荐的格式）
> 现有 OCRService 已能够返回 OCR 原始文本。请不要修改 OCRService 接口和现有 MVVM 架构，
> 仅实现 BusinessCardFieldParser，将 OCR 结果映射为 name、company、jobTitle、department、
> mobiles、officePhones、faxes、emails、websites、address、postalCode 等字段。
> 对于无法确认的字段必须返回 nil，不允许根据语义生成原图中不存在的信息。
> 显式标签值为「无 / 暂无 / n/a / -」时该字段必须为空，且后续启发式不得再填。
> 完成后针对 docs/test-cards 里的样例编写单元测试。

**TRAE 修改范围**：`Domain/Parsing/BusinessCardFieldParser.swift`、`FieldExtractionRules.swift`、
`TextNormalizer.swift`、`CamCardCloneTests/FieldParserTests.swift`。

**人工验证**：
- 逐条对照作业 §7.5 的 8 个必填字段与 4 个可选字段；
- 检查「无网站不得虚构网站」的实现是否真的在标签层拦截（不是在后处理里删）；
- 检查未分类行是否被保留而不是被强行归类。

**回归**：新增 23 例全部通过；已有的数据层用例不受影响。

**周内第一次纠错 Prompt**（Week 4 的典型问题）
> 目前字段解析中，大部分英文名片会把公司名错误识别为姓名（例如把
> "ABC Technologies Inc." 填入 name）。请分析原因，只修改字段分类规则，
> 不改变 BusinessCard 数据模型、OCRService 和现有已经通过的测试。
> 修改完成后重新运行全部测试。

**TRAE 修改范围**：仅 `FieldExtractionRules.swift` 的姓名/公司判定顺序与后缀词表
（Ltd / Inc / LLC / Co / 有限公司 / 集团 等）；未改模型、未改 OCR。
**人工验证**：用 C07/C09/C21 三张英文/双语样例对照 Ground Truth 确认修复且未回归。
**回归**：全量 `swift test` 通过；新增 C21 的固定样例用例防复发。

---

### 2.4 数据集与 Ground Truth（Week 1 / Week 3）

**Prompt**
> 编写 scripts/make_test_cards.py，生成 41 张合成名片（40 张用于字段准确率 + 1 张空白异常卡），
> 每张输出 flat / tilt / rotate / shadow 四个变体，并生成 ground-truth.json。
> 所有数据必须是虚构的（example.com、555/138 0000 号段），不得使用真实人名或电话。
> 号码展示格式必须与 BusinessCardFieldParser.normalizePhone 完全一致：
> 需要把同一套规则复刻到 Python 的 display_phone。另写 verify_test_cards.py 做静态校验。

**TRAE 修改范围**：`scripts/make_test_cards.py`、`scripts/verify_test_cards.py`、
`docs/test-cards/*`（41 张 × 4 = 164 张 PNG + README + Ground Truth）。

**人工验证**：抽查 C01/C03/C31/C41 的原图与 Ground Truth 逐字段一致；
确认没有真实个人信息；确认 tilt/rotate/shadow 是「同一张名片的不同拍摄条件」而不是四张不同名片。

**回归**：`python scripts/verify_test_cards.py` 通过（41 张 / 164 图像 / Ground Truth 40 条）。

---

### 2.5 Vision OCR 与图像校正（Week 3）

**Prompt**
> 实现 OCRService：使用 Vision VNRecognizeTextRequest（accurate、语言 zh-Hans + en-US、
> minimumTextHeight 0.01），返回完整原始文本、逐块置信度与归一化包围盒。
> 另实现 CardImageCorrector：VNDetectRectanglesRequest 检测名片四边形 →
> CIPerspectiveCorrection；检测不到时回退整图，不得让流程失败。
> 不要接入 UI；只实现服务层和可在模拟器上运行的测试（C01_flat / C03_tilt）。

**TRAE 修改范围**：`Services/OCR/OCRService.swift`、`Services/Vision/*`、
`CamCardCloneTests/OCRServiceTests.swift`、`ImageCorrectionTests.swift`。

**人工验证**：阅读代码确认没有把识别文本用于任何「补全」；
确认回退路径会保留原图而不是返回空；确认测试用的是真实生成的 PNG。

**回归**：Vision/校正用例在 iOS 模拟器执行（CI）；Windows 上按平台条件编译为空。

---

### 2.6 扫描 → 确认 → 保存 UI（Week 2 / Week 4 / Week 5）

**Prompt**
> 实现 ScannerView 的状态机：选择页 → 拍摄/相册 → 识别中 → 失败（重试/手动录入）/ 成功（确认表单）。
> 复用现有 OCRService 与解析器，不得修改它们的接口。确认表单 CardEditView 要覆盖全部字段，
> 多值字段每行一个；所有字段为空时保存按钮禁用。保存走 CardStore。
> Debug 下支持 -scanFixture 注入合成名片，走完全相同的识别代码路径。

**TRAE 修改范围**：`Features/Scanner/ScannerView.swift`、`Features/CardDetail/CardEditView.swift`、
`App/LaunchOptions.swift`、少量 `AppEnvironment` 装配。

**人工验证**：确认「注入」只替换图像来源，识别链路没有被测试专用分支绕过；
确认取消不落库；确认空表单不可保存。

**回归**：单元测试不受影响；UI 路径由 `ExceptionPathUITests` 覆盖（模拟器 / CI）。

---

### 2.7 名片夹、详情、搜索、标签、删除、导出（Week 5）

**Prompt**
> 实现名片夹列表（空状态、标签筛选横幅、搜索）、详情页、标签管理、编辑/删除/导出。
> 搜索复用 CardStore.search，不要新增第二套过滤逻辑；导出复用 VCardExporter，
> 不得在 UI 里拼接 vCard 文本。删除必须有确认弹窗。逐页补齐 spec.md §3 的标识符。

**TRAE 修改范围**：`Features/CardList/*`、`Features/CardDetail/CardDetailView.swift`、
`Features/Tags/*`、`Services/Export/VCardExporter.swift`、`VCardExporterTests.swift`。

**人工验证**：逐字段核对 vCard 映射与转义；确认删除标签不删名片；
确认详情页空字段不显示行。

**回归**：导出 6 例 + 数据层用例通过。

---

### 2.8 UI 测试与 CI（Week 5 / Week 6）

**Prompt**
> 为 T01、T13–T19 编写 XCUITest（CardListUITests），使用 -seedSampleCards 固定示例数据，
> 不依赖网络与真实个人信息。注意模拟器中文 typeText 不可靠，全部输入用 ASCII。
> 分享面板的断言只验证「面板出现」与关闭后回到详情页，不去点具体分享渠道。
> 不得修改被测 UI 的标识符来迎合测试。

**TRAE 修改范围**：`CamCardCloneUITests/CardListUITests.swift`、`project.yml` 的 UI 测试 target 与
fixture 复制脚本、`.github/workflows/ci.yml`。

**人工验证**：逐条核对每个用例断言的场景编号；确认没有「只点一下不断言」的空测试；
确认 CI 只跑真实命令、失败会保留日志与 xcresult。

**回归**：首次 CI 运行结果见 §6（未运行前不写「通过」）。

---

### 2.9 首次 CI 前的预检修正（Week 5 / Week 6）

**Prompt**
> 在首次推送 CI 之前，对全部 UI 路径、展示层与构建配置做一次静态审查。
> 只修复会导致确定性场景失败或构建失败的问题：iOS 16 同一视图多个 .sheet / .alert 的呈现冲突、
> UI 测试之间的存档污染与元素类型误用、手动录入取消后未返回名片夹、
> AppEnvironment 未转发 CardStore 的变化、构建脚本复制 fixture 时的沙箱限制、
> Ubuntu 24.04 系统 Python 的 PEP 668 限制。
> 不新增功能、不改无障碍标识符、不改解析器与 vCard 导出。
> 可以抽成纯逻辑的部分必须补单元测试；其余改动只能由首次 CI 运行验证，不得提前标「通过」。

**TRAE 修改范围**：
- `CardDetailView`：两个 `.sheet` 合并为单一 `ActiveSheet` 枚举；删除确认与导出失败合并为单一 alert，
  标题与按钮文案保持规格不变（「删除这张名片？」/ 删除 / 取消）。
- `ScannerView`：sheet 的关闭判断抽成 `Domain/Scanning/ScannerDismissal.swift` 纯逻辑，
  新增 `ScannerDismissalTests`（4 例）。
- `AppEnvironment`：订阅 `store.objectWillChange` 并转发给观察它的视图。
- `CardListUITests.testFirstLaunchShowsEmptyState`：启动参数改为 `-resetStore`——用例按字母序执行，
  前面的导出用例会留下存档，原写法测到的不是「首次启动」。
- `ExceptionPathUITests`：`empty-state-title` 挂在 `Text` 上，查询从 `buttons` 改为 `staticTexts`（3 处）。
- `project.yml`：仅 App target 设置 `ENABLE_USER_SCRIPT_SANDBOXING: NO`，fixture 复制脚本未声明输入文件。
- `.github/workflows/ci.yml`：PyYAML 安装改用 `actions/setup-python@v5` 提供的 Python。
- `.gitignore`：排除作业原始 docx、Python 缓存与 XcodeGen 生成物。

**人工验证**：
- 逐条对照 T01/T11/T13/T14/T16/T17/T19/T20 的断言，确认是为修复行为缺陷而改，
  不是为了「让测试变绿」削弱被测 UI；
- 确认合并后的删除弹窗仍是「确认后才删除」，且 `app.alerts["删除这张名片？"]` 仍能匹配；
- 确认 `ScannerDismissal` 的三种组合都有断言，包括「识别失败且未打开表单时保留扫描页」。

**回归**：`swift test` 由 44 例增至 **48/48 通过**（新增扫描关闭规则 4 例）；
`python scripts/verify_test_cards.py` 仍为 41 张 / 164 图像。
展示层与 CI 配置的修改没有本地运行环境，状态仍是 ⏳，只由首次 CI 运行给出结论。

---

## 3. 修改范围统计

| 增量 | 新增/修改文件 | 涉及模块 | 是否改动既有接口 |
| --- | --- | --- | --- |
| 2.1 骨架 | project.yml、App/* | App | —（首次） |
| 2.2 模型/数据层 | Models、Data、DataTests | Domain/Data | —（首次） |
| 2.3 解析器 | Parsing、FieldParserTests | Domain | 否（仅新增） |
| 2.4 数据集 | scripts、docs/test-cards | 工具/数据 | 否 |
| 2.5 OCR/校正 | Services/OCR、Services/Vision、Tests | Services | 否（新增） |
| 2.6 扫描/表单 | Features/Scanner、CardEditView、LaunchOptions | UI | 否（调用既有接口） |
| 2.7 列表/详情/标签/导出 | Features/*、Services/Export、Tests | UI/Services | 否 |
| 2.8 UI 测试/CI | UITests、project.yml、ci.yml | 测试/CI | 否 |
| 2.9 预检修正 | ScannerDismissal、Detail/Scanner UI、UITests、ci.yml | UI/测试/CI | 否（仅模块内修正） |

> 关键点：所有增量都是**追加**或**在模块内修改**，没有出现「AI 顺手重构整个工程」的情况。
> 唯一一次接口级改动（vCard 文件名规则）先改规格、再加用例，然后才改实现。

---

## 4. 人工验证记录

| 验证项 | 方法 | 结论 |
| --- | --- | --- |
| 字段不编造（§8） | 逐字段对照 C01/C07/C21/C31 原文 | 通过：缺失字段保持 nil；显式「无」被拦截 |
| 电话展示格式 | Swift 实现 vs Ground Truth vs Python 生成器三方对照 | 通过：同一契约 |
| 数据集虚构性 | 全量扫描姓名/公司/号码/邮箱域名 | 通过：无真实个人信息 |
| vCard 映射 | 逐行对照 `docs/data-model.md` §5 | 通过 |
| 取消不落库 / 手动录入取消返回名片夹 | `ScannerDismissalTests`（✅）+ UI 测试 | 规则单测通过；UI 端到端待 CI |
| 识别失败可手动录入 | UI 测试 + 代码审查 | 自动化路径已覆盖（待 CI 确认） |
| 删除标签不删名片 | UI 测试 + 单测 | 单测通过；（UI 待 CI） |

> 「待 CI 确认」表示用例已写好且本地静态审查通过，但尚未在模拟器/CI 上真实运行过。
> 这一类项目不标记为通过。

---

## 5. AI 能力边界分析（Week 6）

参照作业 §8，对本次 AI 协作的边界做诚实评估：

### 5.1 AI 做得好、可以放手的部分

- **样板代码与界面装配**：SwiftUI 列表/表单/导航、XcodeGen 配置、CI YAML——规格清楚时一次成型，人工主要审查标识符和状态。
- **规则明确的文本解析**：标签匹配、电话分组、vCard 转义——只要规格写成可判定的规则，AI 实现与测试的迭代很快。
- **测试脚手架**：从规格条目到 XCTest 用例的映射，人工只要核对断言是否真的验证了场景。

### 5.2 AI 容易出错、必须人工盯的部分

- **「看起来对」的启发式**：AI 倾向于让解析器「总能填上字段」。必须在 Prompt 中明确
  「无法确认返回 nil」，并在审查中专门找「凭空补全」。
- **平台差异**：SwiftPM 与 Xcode 的模块边界（`canImport` 在 Windows 上会定义 `Xcode`）、
  iOS 16 的 `LabeledContent` 合并无障碍子元素、多个 `.sheet` 只有最后一个生效——这些都靠实际构建与测试暴露，不能靠推断。
- **UI 测试的稳定性**：中文输入、系统分享面板、系统权限弹窗在模拟器上的行为与真机不同。
  AI 写出的用例可能「断言了不存在的东西」，必须用真实运行结果校正。
- **数据虚构风险**：AI 生成测试数据时可能混入真实姓名/号码。本项目用统一检查脚本 +
  example.com/555 号段规则约束。

### 5.3 本项目如何把 AI 限制在规格之内

1. 规格先于代码：`docs/spec.md` 是唯一依据，Prompt 不引入规格外功能。
2. 回归保护：每次改动跑全量测试；数据集用例（40/40）防止解析器「修一个坏一个」。
3. 证据链：`rawOCRText` 随名片保存，任何字段都能追溯到 OCR 原文。
4. 不编造：显式空值占位机制 + 未分类行 + 测试断言（T09）。
5. 文档诚实：未运行的结果写成待运行；已知差距列在 `docs/spec.md` §9。

---

## 6. 回归结果记录

| 日期 | 范围 | 命令 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-10-31 | 领域 32 + 数据 12 | `swift test`（Windows，Swift 6.4.2） | 44/44 通过 | 不含 Vision/UIKit 用例 |
| 2026-11-01 | 领域 32 + 扫描流程 4 + 数据 12 | `swift test`（Windows，Swift 6.4.2） | 48/48 通过 | 2.9 新增 `ScannerDismissalTests`；仍不含 Vision/UIKit 用例 |
| 2026-10-31 | 数据集 | `python scripts/verify_test_cards.py` | 通过（41 张 / 164 图像） | — |
| （首次 CI 后补充） | XCTest + XCUITest 全量 | GitHub Actions `build-and-test` | 待运行 | 记录运行链接与用例数 |
| （Week 6 验收） | T01–T20 | `docs/test-suite.md` 全量 | 待运行 | 只记录真实结果 |

---

## 7. 给后续维护者的建议

- 新增字段规则时，先在 `docs/spec.md` §4.5 写清楚判定条件，再在 `FieldParserTests` 加一个样例，
  最后才改解析器——不要在 Prompt 里直接说「优化一下解析」。
- 修改无障碍标识符等于修改规格：同步更新 `docs/spec.md` §3、UI 测试与本文档。
- CI 失败时先看日志再改代码；不要为了「变绿」放宽断言。
