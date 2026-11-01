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
- `CardDetailView`：两个 `.sheet` 合并为单一 `ActiveSheet` 枚举；删除确认与导出失败合并为单一
  `.alert(alertTitle, isPresented:)`——标题由 `alertTitle` 在渲染时计算（"删除这张名片？" / "导出失败"），
  消息由 `alertMessage` 提供（"删除后无法恢复" / 导出错误描述），按钮文案保持规格不变（删除 / 取消 / 好）。
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
- 确认合并后的删除弹窗仍是「确认后才删除」；iOS 16 的 `.alert(_:isPresented:)` 标题取自渲染时计算的
  `alertTitle`，因此在 UI 测试中用 `app.alerts.firstMatch` 定位弹窗，并以「删除（destructive）/ 取消」两个按钮
  作为「确认弹窗已出现」的判据，再点击删除——按钮角色与文案都能由自动化验证，标题文本不做脆弱匹配；
- 确认 `ScannerDismissal` 的三种组合都有断言，包括「识别失败且未打开表单时保留扫描页」。

**回归**：`swift test` 由 44 例增至 **48/48 通过**（新增扫描关闭规则 4 例）；
`python scripts/verify_test_cards.py` 仍为 41 张 / 164 图像。
展示层与 CI 配置的修改没有本地运行环境，状态仍是 ⏳，只由首次 CI 运行给出结论。

---

### 2.10 Vision 端到端准确率报告（Week 3）

**Prompt**
> 作业 §5 要求概率性 OCR 效果用 30–50 张合成名片 + Ground Truth 做端到端评价。请在现有 VisionOCRService
> 与 BusinessCardFieldParser 之上新增一个只在模拟器运行的测试 VisionAccuracyTests：对 docs/test-cards/images
> 的 40 张 flat 图像执行真实 Vision 识别，保存原始 OCR 文本、解析字段、Ground Truth 与逐字段判定，
> 产出 build/ocr-accuracy-report.md 与 .json；聚合字段级准确率、有值召回、缺失字段精度、虚构数、名片级全对率。
> 不得修改 OCRService、解析器与数据模型；不得在测试里为准确率设置通过阈值（概率性结果原样记录），
> 只对「40 张全部识别完成」与「虚构 = 0」（§8 硬约束）做断言。CI 中用 -only-testing 单独运行并上传工件，
> 主测试运行中用 -skip-testing 跳过它，避免重复执行。

**TRAE 修改范围**：`CamCardCloneTests/VisionAccuracyTests.swift`（新增）、
`.github/workflows/ci.yml`（B 层步骤 + Step Summary + 工件）、`scripts/run-tests.sh`（本地同款步骤）、
`docs/ocr-accuracy.md` §4.2 的实现状态说明、`docs/test-suite.md` 的用例索引。

**人工验证**：
- 确认报告结构覆盖 §4.2 的五步流程（原始文本、解析字段、Ground Truth、逐字段判定、人工归因入口）；
- 确认测试只读 Ground Truth，不写回、不调用任何「补全」逻辑；
- 确认准确率指标只记录、不设通过阈值——概率性结果不能靠调断言来「变绿」；
- 对照 `layoutText` 与 `rawOCRText` 区分「OCR 识别错误」与「规则归类错误」。

**回归**：Windows `swift test` 仍 48/48（该文件在非 Apple 平台按条件编译为空）；
真实数字以 CI 运行产物（`ocr-accuracy-report` 工件）为准，未运行前 `docs/ocr-accuracy.md` §5.2 保持「待运行」。

---

### 2.11 首轮 CI 结果驱动的测试修复（Week 6）

**Prompt**
> 首次 CI 运行（运行 2）显示：静态检查通过、编译通过，XCTest 42 + 12 全部通过，异常路径 UI 4 例全部通过；
> 但 `CardListUITests` 8 例中 5 例失败，失败点全部在点击详情页工具栏菜单 `detail-menu`：
> XCUITest 先执行 AX scroll-to-visible，报 `kAXErrorCannotComplete`，计算出的点击点为 {-1, -1}。
> 只改测试，不改被测 UI：不改菜单结构、不增删无障碍标识符、不删除或放宽任何场景断言。
> 另外：为 B 层评价补充 Ground Truth 字段计数契约断言（有值 248、空 192），
> 数据集变化导致评价分母漂移时必须显式失败；并补充 T12「识别 → 确认 → 保存 → 出现在列表」的端到端用例。

**TRAE 修改范围**：
- `CardListUITests`：新增 `openCardMenu(_:)` 辅助函数，用
  `coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()` 绕过 AX 滚动步骤，
  并等待菜单项「编辑」出现；5 个受影响用例的后续断言保持原样。
  另为 `testDetailShowsAllSavedFields` 增加「旧名片可能在屏幕下方」的滚动兜底
  （`scrollToBottom` 只在目标行不可点击时执行，不断言滚动本身）。
- `VisionAccuracyTests`：新增 `presentChecks == 248`、`absentChecks == 192` 两条结构断言。
- `ExceptionPathUITests`：新增 `testSaveAfterRecognitionAddsCard`（T12：`-scanFixture C01` → 确认表单
  → 保存 → 列表出现 `card-row-朱宏明` → 详情显示姓名）。

**人工验证**：
- 确认 `openCardMenu` 只改变「怎么点到菜单」，没有改变「点到了什么、之后断言什么」；菜单本身仍由用户可点击验证；
- 确认 B 层新增断言只校验评价结构（分母），没有为准确率设置及格线；
- 确认保存用例断言的是真实 OCR 结果进入表单并落库，没有用测试分支绕过识别链路。

**回归**：Windows `swift test` 仍 48/48；UI 修复与 B 层报告的真实结果以第三轮 CI 运行为准，
在运行完成前本文与 `docs/test-suite.md` 均不写「通过」。

---

### 2.12 CI 运行 3 的模拟器缺失与环境修复（Week 6）

**Prompt**
> CI 运行 3 在 `build-for-testing` 阶段失败，日志为
> `Unable to find a device matching the provided destination specifier:
> { platform:iOS Simulator, OS:18.5, name:iPhone SE (3rd generation) }`，
> 该 scheme 的可用目的地只剩 macOS「My Mac」与两个占位符（Any iOS Device / Any iOS Simulator Device）。
> 运行 1、2 与本轮使用同一镜像（macos-15-arm64 / 20261028.0489.1 / Xcode 16.4）且设备正常，
> 因此这不是代码、测试或目的地写法的问题，而是镜像自带的 CoreSimulator 预置设备在部分机器上没有注册
> （与 actions/runner-images#12948 记录的偶发现象一致）。
> 只改 CI：构建前用 `xcrun simctl` 显式创建 iPhone SE (3rd generation) / iOS 18.5 模拟器，
> 后续所有 xcodebuild 步骤改为按该设备 UDID 选取目标；不改 App 代码、不改测试、不调整任何断言。

**TRAE 修改范围**：`.github/workflows/ci.yml`
- env 中整条 `DESTINATION`（name + OS）改为 `SIM_RUNTIME: "18.5"`；
- 新增「准备模拟器」步骤：`simctl list runtimes` 刷新运行版本列表 → 校验 iOS 18.5 运行版本存在
  （缺失时显式报错，而不是等到构建阶段才失败）→
  `xcrun simctl create "CamCardClone-CI" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation
  com.apple.CoreSimulator.SimRuntime.iOS-18-5` → UDID 写入 `$GITHUB_ENV`；
- `build-for-testing`、主测试、B 层报告三处 `-destination` 统一改为 `id=$SIM_UDID`。

**人工验证**：
- 对照运行 3 日志确认失败点与可用目的地列表，排除编译与测试代码问题；
- 确认「缺运行版本」与「缺设备」分开处理：前者属于镜像能力缺失，直接报错；后者每次运行自愈；
- 确认没有跳过或放宽任何用例，B 层与 UI 用例的执行范围不变；
- 本地对 workflow 做 YAML 解析与 shell 语法检查，真实效果由第四轮 CI 运行验证（不提前写「通过」）。

**回归**：本机无 macOS/CoreSimulator，该修复只能由 CI 验证；`swift test` 48/48 不受影响。
第四轮运行结果记录于 §8。

---

### 2.13 CI 运行 4 的 workflow 表达式修复与 actionlint 门禁（Week 6）

**Prompt**
> CI 运行 4 在推送后立刻结束：API 中 `status=completed`、`conclusion=failure`，但 job 数为 0，
> `created_at` 与 `updated_at` 完全相同（18:56:56Z → 18:56:56Z），说明 workflow 在启动任何 job
> 之前就被 GitHub 拒绝，不是构建或测试失败。与运行 3 的提交对比，本次只把 job 名称从固定文本
> 改成了 `iOS 构建与测试（iPhone SE 3rd gen / iOS ${{ env.SIM_RUNTIME }}）`。
> 只改 CI 定义：把 job 名称恢复为字面量；并在 static job 中加入 actionlint 检查，
> 让这类「YAML 能解析、GitHub Actions 表达式不合法」的错误在推送前被本地与 CI 双重拦下。
> 不改 App 代码、不改测试、不调整任何断言。

**TRAE 修改范围**：`.github/workflows/ci.yml`
- job 名称改回字面量 `iOS 构建与测试（iPhone SE 3rd gen / iOS 18.5）`，并注释原因：
  `jobs.<id>.name` 只允许 `github` / `inputs` / `matrix` / `needs` / `strategy` / `vars` 上下文，
  `env` 不可用；
- 新增 `ACTIONLINT_VERSION: "1.7.12"`；
- static job 在 YAML 解析之后新增 actionlint 步骤：下载官方 Linux amd64 发行包并执行，
  `-shellcheck="" -pyflakes=""` 关闭镜像中未安装的外部检查器。

**人工验证**：
- 在本地 Windows 下载 actionlint 1.7.12 复现问题：原文件报
  `jobs.build-and-test.name:60:61: context "env" is not allowed here`，修复后 exit 0；
- `yaml.safe_load` 在修复前后都能解析成功——证明只看 YAML 语法发现不了此类问题，
  这是把语义检查加入 static job 的直接原因；
- 确认 actionlint 只校验仓库内的 workflow 文件，不读取、不上传任何密钥或凭据。

**回归**：仅 CI 定义变化，`swift test` 48/48 不受影响；真实效果由第五轮 CI 运行验证，
运行完成前不写「通过」（§8 第 5 行）。

---

### 2.14 CI 运行 5 的 UI 失败归因与解析器粘连标签修复（Week 6）

**Prompt**
> 运行 5 是首次跑通全链路的一轮：static ✅、编译 ✅、B 层准确率 ✅、异常路径 UI 5/5。
> 但 `CardListUITests` 3 例失败（编辑姓名、编辑后重启保持、标签创建/筛选/删除），
> B 层暴露 C02/C03 两个解析错误。要求：先从工件与 XCTest 日志定位真实原因再改，
> 不允许为了让测试变绿而放宽断言；只改测试与解析器，不降低任何验证强度。

**证据（全部来自运行 5 下载的工件，未推测）**：
- 编辑类用例：XCTest 日志 19:04:51 的无障碍快照显示 `field-name` 的 value 是
  `David Chen` 且键盘焦点在其中；19:04:52.594 的失败信息显示期望值变成了
  `David Chen Jr.David Chen`。即**第二次 `.tap()` 落在已聚焦的输入框上**时，
  XCUITest 先做 AX scroll-to-visible 并失败（`kAXErrorCannotComplete` 系列），
  焦点停留在原位置，逐字符删除大部分被吞掉，新文本被追加到旧文本末尾，
  表单最终保存了「新旧拼接」的名字。详情页忠实显示了存档中的值，**不是展示层问题**。
- 标签用例：失败时的无障碍快照中完全没有 `Conference` 按钮，而编辑表单其他控件都在——
  标签 Section 是表单最后一个 Section，在 iPhone SE（375×667）上位于首屏之下，
  `.tap()` 不会自动滚动。
- B 层：C02 的原始 OCR 是 `地址北京市海淀区中关村大街1号`、C03 是 `部门研发中心`，
  字符全部正确，只是标签与值之间没有分隔符，旧规则把整串当成了字段值。

**TRAE 修改范围**：`CamCardCloneUITests/CardListUITests.swift`、
`CamCardClone/Domain/Parsing/BusinessCardFieldParser.swift`、
`CamCardCloneTests/FieldParserTests.swift`
- UI 测试新增 `replaceText(in:original:with:)`：点击一次获得焦点后，用长按拖拽**选中整段文本**
  （短文本从左拖过行尾，长文本反向再拖一次），再键入新值——键入会替换选区；
  不再对已聚焦输入框二次 `.tap()`。结尾用 `XCTAssertNotEqual` 兜底确认内容确实被替换。
- UI 测试新增 `scrollToVisible(_:in:maxSwipes:)`：标签用例先滑动到标签按钮 `isHittable` 再点击。
- 测试的**断言全部保持原样**：仍然是「详情页显示新姓名、列表出现新行、旧行消失」、
  「重启后修改保持」、「删除标签后名片仍在」。
- 解析器新增 `matchGluedLabel`：在显式标签阶段之后尝试切分无分隔符的「标签+值」行，
  只对 `department` / `address` 生效，且剩余部分必须**本身满足该字段判定**；
  姓名/公司不参与。新增 3 例单测（C02/C03 真实 OCR 文本 + `地址不详`/空剩余值的不过度切分保护）。

**被否定的假设（记录在此以免重复踩坑）**：
- 最初怀疑「iOS 18 对 `detail-name` 的无障碍快照过期」，并曾临时给编辑表单的
  `TextField` 加 `.accessibilityLabel`；日志证据出现后**该实验已完整回退**，
  `CardEditView` 本轮零改动。详情页展示的是存档真实值，问题在输入环节而非展示环节。

**人工验证**：
- 本地 `swift test`（Windows 11 / Swift 6.4.2，需设置 `SDKROOT` 指向 Windows.sdk）
  51/51 通过（领域 39 + 数据 12），其中 `FieldParserTests` 26 例；
- 用 Python 参考实现复跑 A 层数据集仍为 440/440、虚构 0；用运行 5 的真实 OCR 文本
  离线重放新解析器，C02/C03 两处错误消失；
- 修复未改任何被断言的界面元素标识符与文案。

**回归（运行 6 真实结果）**：解析器改动只影响「无分隔符标签行」的归类，A 层 40 张数据集与全部既有单测不变；
B 层在运行 6 中 C02/C03 两处错误消失，字段级 427→429/440、整卡 29→31/40。
UI 侧：`testTagCreateFilterAndDelete` 运行 6 通过（89.438 s）；
两例编辑用例仍失败——不是本轮改动引入的，而是 2.14 的拖拽选区方案在 CI 上键入前等待 App 空闲
超过 60 s（详见 §2.16），已在下一次改动中替换输入方式。

---

### 2.15 Week 6「UI 截图对比」的取证与导出（Week 6）

**Prompt**
> 阶段二交付清单有一项「UI 截图对比」。要求：关键页面（空状态、详情、搜索、标签筛选、
> 确认表单、保存后的列表、相机权限拒绝）在真实模拟器运行时留下截图作为验收证据；
> 截图必须来自实际运行、可导出、不与被测 UI 耦合；不改任何界面代码与断言，
> 不引入新的测试依赖。

**TRAE 修改范围**：`CamCardCloneUITests/UIEvidence.swift`（新增）、
`CamCardCloneUITests/CardListUITests.swift`、`CamCardCloneUITests/ExceptionPathUITests.swift`、
`.github/workflows/ci.yml`、`scripts/run-tests.sh`
- 新增 `UIEvidence.capture(_:_:)`：用 `XCTAttachment(screenshot:)` 截取当前界面，
  `lifetime = .keepAlways` 保证**通过用例的截图也保留**（默认只在失败时保留）；
  截图名称统一为 `S01`–`S07`（ASCII，便于导出文件名稳定）。
- 7 处截图挂在既有用例的**已验证状态之后**（例如详情页断言完字段再截图），
  不新增用例、不改断言、不调整元素标识符。
- CI 新增「导出 UI 截图」步骤：`xcrun xcresulttool export attachments --path build/TestResults.xcresult
  --output-path build/ui-screenshots`，上传工件 `ui-screenshots`（保留 30 天）；
  失败工件 `build-logs-and-results` 同时包含截图目录。
- 本地 `scripts/run-tests.sh` 在测试结束后执行同样的导出，输出到 `build/ui-screenshots/`。

**人工验证**：
- 本地可用 actionlint 1.7.12 校验修改后的 workflow（exit 0）；
- 本地 `bash -n scripts/run-tests.sh` 语法检查通过；
- 本机无 Xcode，截图内容与导出动作只能在 CI 上真实产生——完成前不写「已验证」。

**回归**：仅测试侧与 CI 定义变化；真实结果由下一次 CI 运行验证（§8 第 7 行）。
截图与用例同源，任何 UI 回归都会同时反映在断言与截图上。

**运行 6 暴露的问题（§2.16 修复）**：运行 6 在本节改动提交之前就已完成排队，
因此不含截图步骤；截图的首次真实产出与导出验证在运行 7。

**运行 7 的真实结果**（[41279949458](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)，commit `c499448`）：
- 「导出 UI 截图」步骤日志 `PNG 数量：       7`，工件 `ui-screenshots` 已上传
  （artifact ID `13073381577`，467 225 B，保留 30 天）；
- 7 张截图全部来自**通过**的 UI 用例（13/13 全绿），来源用例与截图编号的对应关系见
  `docs/ui-screenshot-comparison.md` §2 的清单表（`manifest.json` 保留导出的 UUID 文件名）；
- 逐张目视核对 35 项：30 ✅、5 ⚠️（均为「静态截图看不到」的说明）、0 ❌；
- 7 张 PNG 与 `manifest.json` 已按原字节复制进 `docs/ui-screenshots/`，新增
  `scripts/verify_ui_screenshots.py` 做结构校验（7 张齐全、来源用例一致、750×1334），
  已在本机用运行 7 的工件真实运行通过（exit 0）；
- 对比文档：`docs/ui-screenshot-comparison.md`（含「截图能证明什么、不能证明什么」
  与 UI Golden Test 现状：运行时取证 + 结构校验 + 人工对比已做，像素级基线未实现）。

---

### 2.16 运行 6 的编辑用例失败归因与输入方式替换（Week 6）

**Prompt**
> 运行 6：static ✅、XCTest 54/54 ✅、`ExceptionPathUITests` 5/5 ✅、
> `testTagCreateFilterAndDelete` ✅（§2.14 的滚动修复生效），但两例编辑用例仍失败。
> 要求：从 XCTest 日志定位真实原因；若 §2.14 的方案本身有问题就换掉它，
> 不通过放宽断言来变绿。同时把「UI 截图导出失败会让整个 job 标红」这一 CI 风险一并处理。

**证据（来自运行 6 的 job 日志，未推测）**：
- `testEditNameUpdatesListAndDetail` 的交互记录：`t=25.31s Type 'David Chen Jr.'`，
  直到 `t=85.35s App animations complete notification not received, will attempt to continue`
  才合成键入事件——**键入前的「等待 App 空闲」被拖了 60 s**。两次 `press(forDuration: 1.0)` 拖拽
  各自结束后，App 一直未报告空闲；60 s 超时后只键入了部分字符，详情页姓名与期望不符。
- `testEditsSurviveRelaunch` 失败于同一原因（两者的输入辅助函数相同）。
- 失败断言仍是被测功能本身的断言（详情页显示新姓名、重启后保持），未放宽。

**TRAE 修改范围**：`CamCardCloneUITests/CardListUITests.swift`、`.github/workflows/ci.yml`
- 删除 §2.14 的 `replaceText(in:original:with:)`（两次长按拖拽选区），
  改为 `typeReplacing(_:expected:with:)`：点击一次获得焦点 → 读回 value 并断言等于保存值 →
  **坐标点击输入框尾部**把光标放到末尾（首次点击之后不再对控件 `.tap()`，不会触发 AX
  scroll-to-visible）→ 按字符数退格删光 → 直接键入新值。全程没有长按，不产生持续动画。
- 搜索用例继续使用 `clearText(in:)`（运行 6 中该用例通过，不改动）。
- CI「导出 UI 截图」步骤：`xcrun xcresulttool export attachments` 失败时输出 `::warning::`
  并跳过，不再让证据步骤把整个 job 标红（截图是周报证据，不是测试结论）；成功时额外打印 PNG 数量。

**本地验证**：
- `actionlint` 1.7.12 校验修改后的 workflow（exit 0，见 §4）；
- 修改只涉及测试辅助函数，不改变任何断言与界面标识符。

**回归**：输入方式替换只影响两例编辑用例的「如何输入」；其余用例不经过该函数。
真实效果由运行 7 验证（§8 第 7 行），运行完成前不写「通过」。

**运行 7 的真实结果**（[41279949458](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)，commit `c499448`，
结论 **success**，首次全绿）：
- `testEditNameUpdatesListAndDetail` ✅ 28.750 s（运行 5：25.639 s 失败，运行 6：99.747 s 失败）；
- `testEditsSurviveRelaunch` ✅ 24.658 s（运行 5：22.710 s 失败，运行 6：102.165 s 失败）；
- 用例时长从约 100 s 回落到约 25 s，说明「等待 App 空闲 60 s」的超时不再发生；
- 同一轮 `CardListUITests` 8/8（208.802 s）、`ExceptionPathUITests` 5/5（44.047 s），
  XCTest 45 + 12 全部通过，断言一条未改。

---

### 2.17 Week 6「UI 截图对比」文档与截图入库（Week 6）

**Prompt**
> 运行 7 已导出 7 张截图。把这些截图整理成可验收的「UI 截图对比」交付物：
> 说明每张截图来自哪次运行、哪个用例、对照哪条规格；写清楚截图能证明什么、不能证明什么；
> 截图文件入库以便复核；用脚本做结构校验；不要声称实现了像素级 Golden Test。

**TRAE 修改范围**（`docs/ai-collaboration-log.md` 本身除外）：
- 新增 `docs/ui-screenshot-comparison.md`：证据来源、截图清单（UUID → 用例 → 规格）、
  六个一致性维度的证据表、逐张核对（35 项：30 ✅ / 5 ⚠️ / 0 ❌）、与参考 App 的对比边界、
  UI Golden Test 现状（像素级基线未实现，列为差距）；
- 新增 `docs/ui-screenshots/`：运行 7 的 7 张 PNG（原字节重命名）+ `manifest.json`（保留导出 UUID 文件名）；
- 新增 `scripts/verify_ui_screenshots.py`：校验 7 张截图齐全、来源用例与清单一致、PNG 有效且 750×1334；
- 更新 `docs/spec.md`（§7 截图证据引用、§9 第 8 条 UI Golden Test 差距）、
  `docs/test-suite.md`（运行 7 结果、T 行截图引用、§5 结果表）、`docs/ocr-accuracy.md`（§5.5 运行 7 复跑）、
  `README.md`（文档导航）；
- 更新 `scripts/run-tests.sh`（导出后调用结构校验，失败只告警）与 `.github/workflows/ci.yml`
  （把新脚本纳入 `py_compile` 预检；导出步骤在打印 PNG 数量后同样调用结构校验，失败输出
  `::warning::` 而不把 job 标红）。

**本地验证**：
- `python scripts/verify_ui_screenshots.py .tools/ci/run7-artifacts/ui-screenshots` → exit 0；
- `python scripts/verify_ui_screenshots.py docs/ui-screenshots` → exit 0（重命名后的入库副本同样可解析）；
- `python -m py_compile scripts/verify_ui_screenshots.py`、`bash -n scripts/run-tests.sh`、
  `actionlint` 1.7.12 对修改后的 workflow 均通过（exit 0）；
- 7 张截图逐张目视核对，核对项与结果全部写入 `docs/ui-screenshot-comparison.md` §5–§6。

**回归**：只新增文档、截图与校验脚本，不改 App 与测试代码；CI 的改动是 static job 多编译一个
Python 文件、build-and-test 的导出步骤多跑一次结构校验（纯本地文件检查，不增加依赖与耗时）。
提交推送为 `e28da4b` 后触发的 CI 运行 8（[41281795449](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)）
是本增量的独立回归：结论 success，XCTest 45 + 12、XCUITest 13/13、B 层 40/40（429/440 = 97.5%，
与运行 7 逐卡一致），截图导出 7 张，工件已重新上传，明细见 §8。

---

### 2.18 Week 6「T01–T20 验收报告」与「SDD 归档」（Week 6）

**Prompt**
> 依据作业 §17「20 个 Reference Test Scenarios 必须 100% 通过」与 §18 Week 6 交付清单，
> 把 T01–T20 逐条对应到测试用例与**真实运行证据**（运行链接、用例耗时、断言数），
> 形成验收报告。人工清单未执行的必须写「待执行」；「100% 可观察行为等价」要写明声明边界，
> 不得写成「与 CamCard 完全一致」。新增 docs/acceptance-report.md；同时按 SDD 流程把各阶段
> 工件归档成一个总目录（docs/sdd-archive.md，只收录真实存在、可复查的内容），
> 并在 README 与 test-suite.md 中引用。

**TRAE 修改范围**（`docs/acceptance-report.md`、`docs/sdd-archive.md` 新建；`README.md`、
`docs/test-suite.md`、本文件 §3/§6 与本节）：

- 验收报告 8 节：验收结论 → T01–T20 逐场景表（用例名 + 运行 7 耗时 + 状态）→ 六个一致性维度
  （UI / 交互 / 状态 / 数据 / 异常 / 流程）的证据与声明边界 → 概率性功能的 §5 要求对照 →
  Week 6 交付物对照（作业 §18）→ 三轮回归结论 → 人工清单 0/10 与参考环境锁定表阻塞项 → 待办；
- T01–T20 表只引用运行 7（`41279949458`）的真实耗时与断言结果，未执行的 M1–M10 全部写「待执行」；
- 六个一致性维度的每一行都配了「不能证明的部分」，并明确对照片是本项目规格而非参考 App 截图；
- SDD 归档按「观察 → 规格 → 架构/实现 → 测试 → 差异分析 → 修订/回归 → 验收」组织，
  给出每个环节的工件位置与状态，未完成项（锁定表、人工清单、像素级基线、最终演示）单列 §4。

**本地验证**：纯文档增量，无代码与 CI 变更；表格数字逐条取自 `docs/test-suite.md` §1/§5 与
`docs/ui-screenshot-comparison.md` §5（已在运行 7 工件上核对）。核对 T04/T05 覆盖时审读了
`ScannerView.swift` 与 App 内全部「重拍」出现位置（仅 `OCRService.swift:41` 的错误提示文案），
确认拍摄后的「使用照片 / 重拍」位于系统 `UIImagePickerController` 界面、App 内无复核页，
据此在 `docs/spec.md` §4.2 与 §9 第 9 条补记该差距；T04/T05 行、M3 步骤与 §1 边界说明同步写明。

**回归**：不触及 App、测试与 CI 定义。本增量提交推送为 `e24f864` 后触发的 CI 运行 9
（[41283224211](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)）是它的独立回归：
结论 success，XCTest 45 + 12、XCUITest 13/13（204.497 s）、B 层 40/40（429/440 = 97.5%，工件与运行 7
仅 `generatedAt` 不同），截图导出 7 张，明细见 §8。

---

### 2.19 运行 8 之后的文档更正批次：步骤口径、复核提示与截图差异归因（Week 6）

**Prompt**
> 运行 8 全绿之后做一次只改文档的更正：① 修正早期把 `static` job 写成「17 个步骤」的口径，
> 用 GitHub API 的步骤记录数解释清楚；② 给 `observer-log.md` §5 的待核对项补上「复核提示」，
> 让人工核对时知道去哪张截图、哪条用例、哪次运行里找答案；③ 把运行 8 → 运行 9 的截图差异
> 如实写进截图对比文档，不能只说「全部是时间性伪影」；④ 把运行 9 的真实结果落档。
> 不碰 App、测试与 CI 代码，所有数字必须来自真实运行。

**TRAE 修改范围**（全部 `docs/`，不改代码）：

- `docs/ai-collaboration-log.md`：§8 记要补「步骤数核对」；§5.4 更新「断言通过≠界面没变」
  与「一致但不代表性能」「概率性能力可复现」三行；§6/§8 增加运行 9 的真实结果；新增本节；
- `docs/observer-log.md` §5：Q1–Q12 的「核对结果」列在保留「待填写」的前提下补复核提示
  （去哪条用例、哪张截图、哪次运行核对）；锁定表仍留空，待观察者实机填写；
- `docs/ui-screenshot-comparison.md`：新增 §7.2（运行 8 → 9 的 S05 整页下垂约 5 px，对齐后
  残差与掩码统计），并修正 §1/§7.1 中「差异全部是时间性伪影」的结论范围；
  > 2026-11-01 复核更正（§2.20）：本节当时记录的 S05 元素行区间取自粗测（把文字抗锯齿的上沿当作
  元素首行），准确值见 §2.20 的本地验证段；「灰色分区上边界下移」与 0.271% 两处口径也已在
  `ui-screenshot-comparison.md` §7.2 与 §2.20 更正。
- `docs/test-suite.md`：§1 运行记录补运行 9，§5 结果表补三行；
- `docs/ocr-accuracy.md`：新增 §5.7（运行 9 复跑），§7 结论更新为运行 6/7/8/9 四次相同；
- `docs/sdd-archive.md`：§1 代码/文档基线口径、§3 Week 6 行、§5 CI 复核链接更新；
- `docs/acceptance-report.md`：§6 回归表补运行 9 行，§5 Regression Test 行更新为五轮。

**本地验证**：S05 的平移与残差结论用 `.tools/ci/png_pixel_diff.py`（纯 Python PNG 解码）在本机
对两次工件复算：整页 dy=+5 时残差最小，元素行区间逐一对齐（取消 123–150 → 129–155、保存
121–150 → 127–155、识别原文 334–357 → 339–362、姓名值 988–1017 → 993–1022），对齐后残差
53 759 px / 951 750 px，80% 差异 ≤16 灰度级，>32 级仅 2 715 px（0.271%），暗像素 IoU 0.9256。
`git diff e28da4b e24f864 -- CamCardClone/ CamCardCloneTests/ CamCardCloneUITests/ CamCardDataTests/ project.yml .github/`
为空，证明 App、测试与 CI 定义零改动。

**回归**：本批次同样只改文档；推送后触发的 CI 运行在其真实结果出来之前不写结论，
结果出来后按 §8 的格式补记（链接、用例数、耗时、工件大小）。

结果已落档：该批次推送（commit `05c20f1`）触发 **CI 运行 10**
（[41284584464](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)，
2026-11-01T07:23:18Z–07:33:41Z），结论 **success**：`static` 11 条 API 步骤记录全部通过；
XCTest `CamCardCloneTests` 45/45、`CamCardDataTests` 12/12；XCUITest 13/13（321.292 s）；
B 层 40/40（字段级 429/440 = 97.5%，`ocr-accuracy-report` 与运行 9 的差异只有 `generatedAt`）；
截图导出 7 张、逐张 `[通过]`，`ui-screenshots` 480 334 B、`ocr-accuracy-report` 13 483 B。
本批次在本地复算本节数字时发现两处需要更正的口径，已在本节直接修正、并作为下一节（§2.20）的记录：
① 53 759 / 951 750 中，≤16 灰度级占 **80.1%**（此前「80%」四舍五入成立），但按对齐统计区域的 951 750 px
计算，>32 级为 **0.285%**（此前写 0.271%）；② 「灰色分区的上边界由 70 行下移到 75 行」经复核不成立——
三次运行的深色导航带都从第 60 行开始，运行 8 的导航带底色为 RGB 224、运行 9、10 为 225，这是底色整体差 1 级，
不是边界移动。运行 10 的 S05 截图差异与三对运行的完整逐像素统计见 `ui-screenshot-comparison.md` §7.3。

---

### 2.20 运行 10 结果落档与截图差异复算口径更正（Week 6）

**Prompt**
> 运行 10（commit `05c20f1`）已经全绿，把这轮的真实结果落档；同时用同一个复算脚本把
> 运行 8 → 9 → 10 三对全绿运行重新量一遍，把 §7.2 里与实测不符的口径（灰度级分布、
> 「灰色分区上边界由 70 行下移到 75 行」的说法）改正，并把「对齐怎么判定」写成可复算的标准。
> 只改文档，数字全部来自真实工件。

**TRAE 修改范围**（全部 `docs/`，不改 App、测试与 CI 代码）：

- `docs/test-suite.md`：§1 三层状态补运行 10，新增运行 10 的结果段（含 static 11 条步骤记录与
  逐步时间、XCTest 45 + 12、XCUITest 13/13 逐例耗时、B 层 37.738 s、工件大小与 S05 差异），
  §4 覆盖率边界与失败工件说明补运行 10，§5 结果表补三行；
- `docs/ai-collaboration-log.md`：§2.19 回归段补运行 10 的真实结果与两处口径更正；
  §5.4 三行更新为五次运行/四次截图采样，并写明对齐判定标准；§6 补运行 10 两行；
  §8 补运行 10 行与运行 10 记要；新增本节；
- `docs/ui-screenshot-comparison.md`：§7 状态表与 §7.2 的两处口径更正（≤16 灰度级占 80.1%、
  >32 级占 0.285%、「灰色分区上边界」改为实测的顶部结构：横条顶边固定在第 60 行、
  模态面板顶边 80 → 85 → 91 行、底色 224 vs 225）；§1 与 §7 表格补运行 10；新增 §7.3
  （三对运行的对齐、强差异像素、两种掩码口径的 IoU、非 S05 图差异、三次采样位置与对齐准则）；§8 补运行 10 工件路径与复算脚本；
- `docs/ocr-accuracy.md`：新增运行 10 复跑小节，§7 结论改为运行 6、7、8、9、10 五次相同；
- `docs/sdd-archive.md`：文档基线更新到运行 10；UI 证据行补运行 9 → 10 的实测；
- `docs/acceptance-report.md`：§6 回归表补运行 10，回归原则段更新为三次独立回归与 ±5–11 px 抖动范围。

**本地验证**：`python scripts/verify_ui_screenshots.py .tools/ci/run10-artifacts/ui-screenshots` exit 0；
`ocr-accuracy-report.json` 以 JSON 全量比较，运行 10 与运行 9 除 `generatedAt`
（07:10:20Z → 07:33:25Z）外完全相等；三对截图用同一脚本复算（750×1334×3，跳过状态栏 60 行）：
S05 的 B 相对 A 的位移为 +5 px（8 → 9）、+6 px（9 → 10）、+11 px（8 → 10），
热像素（>32 灰度级）2 715 / 5 872 / 1 127，暗像素 IoU 0.9585 / 0.9252 / 0.9627；
S05 之外六张在 8 → 10 中只有状态栏时钟（差异行 11–29），9 → 10 另有 S03 的搜索框光标
（70–113 行，160–163 列，176 px）。S05 的元素行区间（运行 8 → 9 → 10）：取消 121–151 → 126–156 → 132–162、
保存 120–151 → 126–156 → 131–162、标题 211–270 → 216–275 → 222–281、识别原文 334–357 → 339–362 → 345–367、
基本信息 919–942 → 924–947 → 930–953、姓名值 988–1017 → 993–1022 → 999–1028、
白色卡片行 378–841/963–1306 → 383–846/968–1311 → 389–852/974–1317。顶部结构的三次实测：
灰色横条顶边都固定在第 60 行（底色 224 → 225 → 225），横条下沿 79 → 84 → 90 行；
模态面板自身顶边（x=100–650 处 242,242,247 底色的起始行）80 → 85 → 91 行，所以「上边界」是随内容动的，
固定的是横条顶边。对齐判定用「>32 级强差异最少」：9 → 10 若按差异像素最少会误选 +5 行
（45 047 px，但留下 33–64 级 14 942 px、>64 级 7 495 px 的错位双线），而 +6 行强差异仅 5 872 px、
元素行区间逐一对齐；相邻候选 +5 处 22 437、+7 处 31 954。另：S03 搜索框光标在运行 8、10 不可见、
运行 9 可见——运行 8 → 9 与 9 → 10 在同一条带区（70–113 行、160–163 列）各自的差异都为 176 px，
故 8 → 9 的 1 256 px 中「70–113 行」那部分即该光标，而非 §7.1 所述的 63 px 差。

**回归（运行 11，已由真实结果补记）**：本批次只改文档（`git diff 05c20f1 2827935` 为 6 个
`docs/` 文件、256 增 44 删）。推送后触发的
[运行 11 · 41288191075](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075)
（commit `2827935`）结论 **success**：XCTest 45 + 12、XCUITest 13/13（222.892 s）、B 层 429/440
（`ocr-accuracy-report.json` 与运行 10 除 `generatedAt` 外完全相等）；截图 7 张，S05 的内容位置回到
运行 8 的基线（运行 10 的内容比基线低 11 行），S03 的搜索框光标以 (0,122,255) 出现。
该结果使截图采样的结论从「三次」扩展为「五次」——S05 的位移是**离散状态**而非漂移，见 §2.21。

---

### 2.21 运行 11 结果落档与 S05「离散状态」更正（Week 6）

**Prompt**
> 运行 11（commit `2827935`）已经全绿，把这轮的真实结果落档；同时把截图采样从三次扩到五次，
> 回答 §7.3 留下的问题：S05 的 0 → +5 → +11 到底是不是「漂移」。只改文档，
> 每个数字都要能从运行 11 的工件或本地复算脚本里重算出来。

**TRAE 修改范围**（全部 `docs/`，不改 App、测试与 CI 代码）：

- `docs/test-suite.md`：§1 三层状态补运行 11，新增运行 11 结果段（static 11 条步骤记录、XCTest 45 + 12、
  XCUITest 13/13 逐例耗时、B 层 39.680 s、工件 ID 与大小、S05 与运行 8 逐像素一致、S03 光标颜色），
  §4 补运行 11，§5 结果表补三行；
- `docs/ai-collaboration-log.md`：§2.20 的回归段由占位改为运行 11 的真实结果；§5.4 两行更新为
  五次运行 / 五次截图采样；§6 补运行 11 两行；§8 补运行 11 行与运行 11 记要；新增本节；
- `docs/ui-screenshot-comparison.md`：§1 补运行 11；§7 状态表更新；§7.2 的光标措辞更正为
  「运行 7、9、11 可见、运行 8、10 不可见」；§7.3 的「三次实测汇总」补运行 10 → 11 行，
  「0 → +5 → +11」段更正为**离散状态**结论；新增 §7.4（运行 10 → 11 与 8 → 11 的逐像素统计、
  S03 三种光标颜色、状态 A/B/C、运行级时间戳与工件时间的一致性记录），其中元素行区间用同一判据
  在三次运行上重测并列成表（不再沿用各节阈值不同的旧行号）；§8 补运行 11 工件路径；
- `docs/ocr-accuracy.md`：新增 §5.9（运行 11 复跑），§7 结论改为运行 6 → 11 六次相同；
- `docs/sdd-archive.md`：文档基线更新为「运行 11 已独立回归」，复核列表补运行 11；
- `docs/acceptance-report.md`：头部证据基线、§5 Regression 行、§6 运行 11 行与回归原则段更新为
  四次独立回归，并写明 S05 抖动是离散状态。

**本地验证**：

- `python scripts/verify_ui_screenshots.py .tools/ci/run11-artifacts/ui-screenshots` exit 0；
  CI 导出步骤同样逐张 `[通过] S01`–`[通过] S07`；
- `ocr-accuracy-report.json`（152 940 B）以 Python 逐键比较，运行 11 与运行 10 除 `generatedAt`
  （07:33:25Z → 08:28:27Z）外完全相等（`True`）；
- S05 位置（同一复算脚本与口径，跳过状态栏 60 行；位移取「>32 级强差异最少」）：
  运行 11 与运行 8 **逐像素一致**（第 60 行以下差异 0；运行 7 与运行 11 同样为 0），
  运行 10 → 11 的对齐位移为 **−11 行**（运行 11 的内容比运行 10 高 11 行，即回到运行 8 的基线），
  强差异 8 553、对齐后残差 60 715 / 955 500（6.35%），IoU 0.9627（RGB<300）/ 0.9437（灰度<128）
  ——与运行 8 → 10 的 +11 行数值相同，因为掩码对 ±11 行平移是镜像对称的；
- 状态划分：S05 的内容位置只有三种取值——运行 7、8、11 相同（基线，记 A），运行 9 = A + 5 行（B），
  运行 10 = A + 11 行（= B + 6，记 C）。其余 6 张截图的差异始终只有状态栏时钟与 S03 光标，
  运行 8 → 11 的 S01、S02、S04、S05、S06、S07 在第 60 行以下**零差异**，S03 只有光标 176 px；
- S03 光标（行 70–113、列 160–163，均 176 px，来自同一套逐像素差分）：运行 7 可见
  (60,151,251)、运行 8 不可见、运行 9 可见 (119,180,248)、运行 10 不可见、运行 11 可见
  (0,122,255)。任意一对「一侧可见、一侧不可见」的运行都恰好差 176 px——§7.3 原先只写了
  运行 8 → 9 与 9 → 10，运行 7 → 8 与 10 → 11 是同一事实的另外两次实例；
- 元素行区间：用同一判据在运行 8、10、11 的工件上重测（白卡区文字按与纯白最大通道差 >24；
  导航带按钮按蓝通道 − 红通道 >60），运行 11 与运行 8 逐项相同，运行 10 整体下移 10–11 行；
  §7.4 已改为并列三列的表，不再混用各节阈值不同的旧行号；
- 运行级时间戳：运行 11 的 API `created_at` / `updated_at`（09:16:51Z–09:28:45Z）与工件
  `created_at`（09:28:35Z / 09:28:41Z）一致，但 job 的 `started_at` / `completed_at`
  （09:17:04Z–09:28:44Z）与全部 step 的 `started_at` / `completed_at`（08:17:04Z–08:28:43Z，19 条记录）
  比它们早 1 小时；同时 `expires_at`（2026-12-01T08:28:40Z）是保存步骤开始时刻 + 30 天，
  与 step 时间一致。日志时间戳（08:16:5xZ–08:28:4xZ）、提交的 committer date（08:16:44Z）、
  运行 10 的 run 级与 job 级时间一致、以及本地时钟与 GitHub / Cloudflare 的 HTTP `Date`
  （08:50Z 前后）全部支持 08:16–08:28Z 为真实时间。本文件与 `docs/test-suite.md` 引用步骤时间时
  一律用日志与 step 的 UTC，run 级时间只用于链接，不单独下结论。

**回归**：本批次仍只改文档；推送后触发的 CI 运行在其真实结果出来之前不写结论，
结果出来后按 §8 的格式补记。

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
| 2.10 准确率报告 | VisionAccuracyTests、ci.yml、run-tests.sh、ocr 文档 | 测试/CI/文档 | 否（只读调用既有接口） |
| 2.11 CI 结果修复 | CardListUITests、ExceptionPathUITests、VisionAccuracyTests | 测试 | 否（只改测试，不动被测 UI） |
| 2.12 CI 环境修复 | ci.yml | 测试/CI | 否（只改 CI 执行环境） |
| 2.13 CI 表达式修复 | ci.yml | 测试/CI | 否（只改 CI 定义） |
| 2.14 运行 5 失败修复 | CardListUITests、BusinessCardFieldParser、FieldParserTests | 测试/Domain | 否（新增私有方法，Parse 接口不变） |
| 2.15 UI 截图取证与导出 | UIEvidence、UITests、ci.yml、run-tests.sh | 测试/CI | 否 |
| 2.16 运行 6 编辑用例修复 | CardListUITests、ci.yml | 测试/CI | 否（只改测试辅助函数与 CI 证据步骤） |
| 2.17 UI 截图对比（Week 6） | ui-screenshot-comparison.md、docs/ui-screenshots/、verify_ui_screenshots.py、spec.md、test-suite.md、README | 文档/脚本 | 否（只新增证据文档与校验脚本，不动 App 与测试代码） |
| 2.18 T01–T20 验收报告与 SDD 归档（Week 6） | acceptance-report.md、sdd-archive.md、README、test-suite.md、spec.md | 文档 | 否（纯文档增量） |
| 2.19 运行 8 之后的文档更正（Week 6） | ai-collaboration-log.md、observer-log.md、ui-screenshot-comparison.md、test-suite.md、ocr-accuracy.md、sdd-archive.md、acceptance-report.md | 文档 | 否（纯文档增量，不改代码与 CI） |
| 2.20 运行 10 落档与截图复算口径更正（Week 6） | ai-collaboration-log.md、test-suite.md、ui-screenshot-comparison.md、ocr-accuracy.md、sdd-archive.md、acceptance-report.md | 文档 | 否（纯文档增量，复核用脚本只在本机 `.tools/`，不提交） |

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
| 取消不落库 / 手动录入取消返回名片夹 | `ScannerDismissalTests`（✅）+ `ExceptionPathUITests` | 规则单测通过；UI 端到端在 CI 运行 2（4/4）与运行 5（5/5，含保存用例）均真实通过 |
| 识别失败可手动录入 | UI 测试 + 代码审查 | `testUnrecognizableImageOffersManualFallback` 在 CI 运行 2 与运行 5 中均真实通过 |
| 识别 → 确认 → 保存 → 列表出现 | `ExceptionPathUITests.testSaveAfterRecognitionAddsCard` | ✅ CI 运行 7 真实通过（13.292 s；运行 5 该套件 5 例合计 64.233 s） |
| 删除标签不删名片 | UI 测试 + 单测 | 单测通过；UI 用例 CI 运行 6 真实通过（89.438 s，§2.14 的滚动修复生效），运行 7 复跑 47.843 s 通过 |
| 编辑姓名后详情与列表一致 | `CardListUITests.testEditNameUpdatesListAndDetail` | ✅ CI 运行 7 真实通过（28.750 s）；运行 5 因二次点击失败、运行 6 因拖拽导致键入前等待 App 空闲超时仍失败（§2.14→§2.16），§2.16 的输入方式替换生效 |
| UI 截图证据可用 | `scripts/verify_ui_screenshots.py` + 逐张目视核对 | ✅ 运行 7 导出 7 张 PNG（工件 467 225 B）；结构校验 exit 0；逐张核对 35 项：30 ✅ / 5 ⚠️ / 0 ❌（`docs/ui-screenshot-comparison.md`） |

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

### 5.4 支撑上述结论的实测数字（均见 §6、§8 与 `docs/ocr-accuracy.md`）

| 观察 | 实测证据 | 说明 |
| --- | --- | --- |
| AI 能「一次成型」的部分确实一次成型 | 增量 §2.1（工程骨架）、§2.2（数据模型）在首个 CI 轮次即整体编译通过；失败集中在 UIKit 图像加载与 `@MainActor` 边界（运行 1，4 处） | 样板代码、数据模型、XcodeGen 定义只需规格清楚，人工审查标识符 |
| AI 的启发式倾向会被真实数据打脸 | B 层 427/440 → 429/440：13 处错误里只有 2 处是规则可修的解析粘连（C02/C03，§2.14），其余 11 处是 Vision 侧字符错误，加规则无法修回 | 解析器自身在 A 层 440/440 全对，说明错误来自概率性 OCR 而非规则；受控切分（只认部门/地址）证明规则可精确收窄 |
| AI 写 UI 测试的最初版本不稳定 | 运行 2、5、6 共 3 类失败（AX 点击、二次聚焦、长按拖拽后 60 s 空闲等待），全部由真实运行日志定位（§2.11、§2.14、§2.16），每类失败只改测试辅助函数、断言未放宽 | UI 自动化是 AI 最不擅长的部分，必须靠 `.xcresult` 日志与 `t = ...` 交互记录归因 |
| 「断言通过」≠「界面没变」 | 运行 7 → 8：App 代码未变，7 张截图逐像素差异仍为 5 232 / 7 003 500 = 0.075%，全部来自状态栏时钟与搜索框光标（`docs/ui-screenshot-comparison.md` §7.1）；运行 8 → 9：S05 出现表单整体下垂约 5 px 的排版抖动（104 237 px = 10.4185%，内容一致）；运行 9 → 10：同一表单再下垂 6 px（相对运行 8 累计 11 px）；运行 10 → 11：回到运行 8 的基线（对齐 −11 行，强差异 8 553）；运行 8 → 11：第 60 行以下 0 px 差异（只剩状态栏时钟与 S03 光标 176 px）。五次采样里 S05 只有三种位置，运行 7、8、11 逐像素一致 | 截图证据与断言互补；像素基线需要先固定时间、光标状态与模拟器排版参数，三者在当前环境均不可控。对齐的判定标准也需固定：按「不改动任何像素的差异数」最小化会选中边界位移（8 → 10 会误选 dy=+8，计 85 373 px，其中 >64 级 32 276 px 是错位双线），按 >32 灰度级像素最小化才对准元素的真实位移（8 → 10 为 dy=+11，10 → 11 为 dy=−11）——方法说明与复算脚本见 `docs/ui-screenshot-comparison.md` §7.3、§7.4 |
| 云端流水线本身需要单独验证 | 运行 3（目的地缺失，§2.12）、运行 4（workflow 被拒、0 job，§2.13）、运行 8（首次在 CI 内执行截图结构校验）、运行 11（run 级时间戳比 job/step 晚 1 小时，§2.21） | 「YAML 能解析」不等于「GitHub 接受」；CI 的每一步都应有一次真实运行的验证记录。平台元数据也不能当作单一事实来源——引用步骤时间时以日志与 step 记录为准 |
| 一致但不代表性能 | XCTest 与 XCUITest 每轮全绿时，UI 合计耗时 252.850 s（运行 7）→ 288.092 s（运行 8）→ 204.497 s（运行 9）→ 321.292 s（运行 10）→ 222.892 s（运行 11），单项最大波动 47.843 s → 112.195 s（Tag），Delete 22.538 s → 102.681 s | 模拟器调度波动大，CI 计时不能当性能回归指标；本项目的性能结论只用确定性单测 |
| 概率性能力可复现但不可承诺 | B 层运行 6、7、8、9、10、11 六次同为 429/440（运行 7 → 8 → 9 → 10 → 11 工件除 `generatedAt` 外逐字节相同）；同一批 40 张名片上 31/40 整卡全对 | 相同环境 + 相同图像 → 相同结果；因此报告写具体环境下的实测值，不写「准确率约为…」 |

**结论**：AI 在「规格清楚、可判定、可回归」的部分可以放手；在「看起来对即可」的启发式、
平台差异、UI 自动化稳定性、以及任何未经过真实运行验证的结论上必须人工盯。本项目的做法是
在每个增量里都写清「AI 做了什么 / 人核了什么 / 哪一轮 CI 证明了它」，而不是只展示最终全绿的结果。

---

## 6. 回归结果记录

| 日期 | 范围 | 命令 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-10-31 | 领域 32 + 数据 12 | `swift test`（Windows，Swift 6.4.2） | 44/44 通过 | 不含 Vision/UIKit 用例 |
| 2026-11-01 | 领域 32 + 扫描流程 4 + 数据 12 | `swift test`（Windows，Swift 6.4.2） | 48/48 通过 | 2.9 新增 `ScannerDismissalTests`；仍不含 Vision/UIKit 用例 |
| 2026-10-31 | 数据集 | `python scripts/verify_test_cards.py` | 通过（41 张 / 164 图像） | — |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 2](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)） | XCTest 42 + 12 通过；UI 7/12 通过（5 例失败） | 失败全部是 XCUITest 点击工具栏 `Menu` 的 AX 错误，修复见 §2.11；修复后待重跑 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 3](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231201327)） | ❌ 未进入测试阶段 | 镜像未注册模拟器，`build-for-testing` 报找不到 iPhone SE / iOS 18.5；环境问题，修复见 §2.12 |
| 2026-11-01 | 全部 CI job | GitHub Actions（[运行 4](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231848508)） | ❌ 未启动任何 job | job 名称使用 `${{ env.* }}` 被 GitHub 拒绝（job 数 0，瞬时结束）；修复见 §2.13 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 5](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41232174313)） | XCTest 42 + 12 通过；UI 10/13 通过（名片夹 5/8） | 3 个失败：编辑类 2 例（对已聚焦输入框二次点击导致新旧文本拼接）、标签 1 例（标签区在首屏之下）；修复见 §2.14，待运行 6 |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 5](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41232174313)） | ✅ 40/40 张完成识别；字段级 427/440 = 97.0%；召回 235/248 = 94.8%；缺失精度 192/192；虚构 0 | 13 处错误：2 处解析粘连（已修 §2.14）、11 处 OCR 侧（5 处竖排名单字未检出 + 6 处字符误识），详见 `docs/ocr-accuracy.md` §5.3 |
| 2026-11-01 | 领域 39 + 数据 12 | `swift test`（Windows，Swift 6.4.2，`SDKROOT` 指向 Windows.sdk） | 51/51 通过 | 2.14 新增 3 例粘连标签单测；仍不含 Vision/UIKit 用例 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 6](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)） | XCTest 45 + 12 通过；UI 11/13 通过（名片夹 6/8） | 标签用例已通过；两例编辑用例因 `typeText` 前等待 App 空闲 60 s 超时失败（§2.16），修复待运行 7 |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 6](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)） | ✅ 40/40 张完成识别；字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；整卡 31/40 = 77.5% | C02/C03 解析粘连已消除；剩余 11 处全为 OCR 侧（5 处竖排姓名 + 6 处字符误识），详见 `docs/ocr-accuracy.md` §5.4 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)） | ✅ XCTest 45 + 12 通过；UI 13/13 通过（名片夹 8/8、异常路径 5/5） | **首次全绿**（结论 success）：两例编辑用例 28.750 s / 24.658 s 通过（§2.16 生效）；导出 UI 截图 7 张并上传 `ui-screenshots` 工件（467 225 B） |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)） | ✅ 40/40 张完成识别；字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；整卡 31/40 = 77.5% | 51.344 s；40/40 张逐卡 OCR 原文与字段判定与运行 6 完全一致（测试/CI 改动未触及识别链路），详见 `docs/ocr-accuracy.md` §5.5 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 8](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)） | ✅ XCTest 45 + 12 通过；UI 13/13 通过（名片夹 8/8、异常路径 5/5）；B 层 40/40 | Week 6 文档批次的独立回归，结论 success：UI 13 例合计 288.092 s（两例编辑用例 20.570 s / 20.044 s）；截图导出 7 张，`ui-screenshots` 工件 467 054 B |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 8](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)） | ✅ 40/40 张完成识别；字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；整卡 31/40 = 77.5% | 39.442 s；与运行 7 工件逐字节比对仅生成时间戳不同，逐卡结果完全一致（错误构成同 `docs/ocr-accuracy.md` §5.5）；截图逐像素对比见 `docs/ui-screenshot-comparison.md` §7 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 9](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)） | ✅ XCTest 45 + 12 通过；UI 13/13 通过（名片夹 8/8、异常路径 5/5）；B 层 40/40 | 纯文档增量回归，结论 success（07:03:15Z–07:10:35Z）：UI 13 例合计 204.497 s（两例编辑用例 21.424 s / 21.192 s）；截图导出 7 张，`ui-screenshots` 工件 480 239 B |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 9](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)） | ✅ 40/40 张完成识别；字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；整卡 31/40 = 77.5% | 30.892 s；与运行 7 工件比对仅 `generatedAt` 不同；截图逐像素对比发现 S05 约 5 px 排版抖动，见 `docs/ui-screenshot-comparison.md` §7.2 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 10](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)） | ✅ XCTest 45 + 12 通过；UI 13/13 通过（名片夹 8/8、异常路径 5/5）；B 层 40/40 | §2.19 文档更正批次的独立回归，结论 success（07:23:18Z–07:33:41Z）：准备模拟器 24 s、XcodeGen 缓存命中；UI 13 例合计 321.292 s（两例编辑用例 25.784 s / 23.971 s）；截图导出 7 张，`ui-screenshots` 工件 480 334 B |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 10](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)） | ✅ 40/40 张完成识别；字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；整卡 31/40 = 77.5% | 37.738 s；与运行 9 工件比对仅 `generatedAt`（07:10:20Z → 07:33:25Z）不同；S05 相对运行 9 再下移 6 px，见 `docs/ui-screenshot-comparison.md` §7.3 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 11](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075)） | ✅ XCTest 45 + 12 通过；UI 13/13 通过（名片夹 8/8、异常路径 5/5）；B 层 40/40 | §2.20 文档批次的独立回归，结论 success（步骤时间 08:17:04Z–08:28:43Z，run 级时间见 §2.21）：UI 13 例合计 222.892 s（两例编辑用例 21.128 s / 24.029 s）；截图导出 7 张，`ui-screenshots` 工件 467 313 B；S05 与运行 8 逐像素一致 |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件（[运行 11](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075)） | ✅ 40/40 张完成识别；字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；整卡 31/40 = 77.5% | 39.680 s；与运行 10 工件比对仅 `generatedAt`（07:33:25Z → 08:28:27Z）不同；S05 相对运行 10 回到运行 8 的基线，见 `docs/ui-screenshot-comparison.md` §7.4 |
| 2026-11-01 | UI 截图结构与来源 | 本机 `python scripts/verify_ui_screenshots.py docs/ui-screenshots` | ✅ 通过（7 张齐全、来源用例一致、750×1334） | 用运行 7 的真实工件；入库副本见 `docs/ui-screenshots/` |
| （Week 6 验收） | T01–T20 | `docs/test-suite.md` 全量 | 自动化部分已在运行 7 全部真实通过；人工清单（M1–M10）待执行 | 只记录真实结果；汇总报告 `docs/acceptance-report.md`（2026-11-01 编写，人工项与参考环境锁定如实列为待办） |

---

## 7. 给后续维护者的建议

- 新增字段规则时，先在 `docs/spec.md` §4.5 写清楚判定条件，再在 `FieldParserTests` 加一个样例，
  最后才改解析器——不要在 Prompt 里直接说「优化一下解析」。
- 修改无障碍标识符等于修改规格：同步更新 `docs/spec.md` §3、UI 测试与本文档。
- CI 失败时先看日志再改代码；不要为了「变绿」放宽断言。

---

## 8. CI 建设记录（真实运行）

> 只记录 GitHub Actions 的实际运行结果；每轮附运行链接、失败原因与修复提交。

| 轮次 | 运行 | static | build-and-test | 说明 |
| --- | --- | --- | --- | --- |
| 1 | [41229496692](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229496692)（commit `ecb5056`） | ✅ 通过 | ❌ `build-for-testing` 失败 | 4 个编译错误：`SampleCards.install` 在非隔离上下文调用 `CardStore` 的 `@MainActor` 方法（3 处）；`CardDetailView` 误用 `ImageStore.data(for:)` 参数标签（应为 `forRelativePath:`）。修复提交 `96ab470` |
| 2 | [41229690851](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)（commit `96ab470`） | ✅ 通过 | ❌ `test-without-building` 失败 | 编译通过。XCTest：`CamCardCloneTests` 42/42、`CamCardDataTests` 12/12；XCUITest：`ExceptionPathUITests` 4/4、`CardListUITests` 3/8。5 个失败点全部是对详情页工具栏菜单 `detail-menu` 调用 `.tap()` 时 XCUITest 的 AX scroll-to-visible 报 `kAXErrorCannotComplete`（点击点 {-1, -1}），被测功能本身正常；修复提交为 §2.11 的 `openCardMenu` 坐标点击。本轮提交不含 B 层步骤（当时未提交），故无准确率工件 |
| 3 | [41231201327](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231201327)（commit `e4c805c`） | ✅ 通过 | ❌ `build-for-testing` 失败（环境） | 编译未开始：`xcodebuild: error: Unable to find a device matching the provided destination specifier: { platform:iOS Simulator, OS:18.5, name:iPhone SE (3rd generation) }`；该 scheme 的可用目的地只剩「My Mac」与两个占位符。运行 1、2 与本轮镜像与 Xcode 版本完全相同（macos-15-arm64 / `20261028.0489.1` / Xcode 16.4 `16F6`），属镜像未注册预置模拟器的偶发问题（actions/runner-images#12948）。B 层、摘要、工件步骤均因没有 xctestrun 而跳过；修复提交见 §2.12（simctl 显式创建模拟器 + 按 UDID 选取目的地） |
| 4 | [41231848508](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231848508)（commit `047137e`） | ❌ 未运行 | ❌ 未运行 | **workflow 未被接受，0 个 job**：`created_at` 与 `updated_at` 均为 18:56:56Z。运行 3→4 的 CI 改动中唯一的结构变化是 job 名称使用了 `${{ env.SIM_RUNTIME }}`，而 `jobs.<id>.name` 不允许 `env` 上下文。本地 actionlint 1.7.12 原样复现该错误；修复提交见 §2.13（job 名称改回字面量 + static job 增加 actionlint） |
| 5 | [41232174313](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41232174313)（commit `016e0e8`） | ✅ 通过（全部步骤） | ❌ `test-without-building` 失败 | 首轮全链路运行。XCTest：`CamCardCloneTests` 42/42、`CamCardDataTests` 12/12；XCUITest：`ExceptionPathUITests` 5/5（含保存用例）、`CardListUITests` 5/8。3 个失败：`testEditNameUpdatesListAndDetail`、`testEditsSurviveRelaunch`（对已聚焦输入框二次 `.tap()` 触发 AX scroll-to-visible 失败，删除被吞、新值追加），`testTagCreateFilterAndDelete`（标签区在首屏之下，`.tap()` 不滚动）。B 层步骤在测试失败后仍正常执行：40/40 张完成识别、虚构 0、字段级 427/440 = 97.0%，工件已上传。修复见 §2.14 |
| 6 | [41234214941](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)（commit `08c1730`） | ✅ 通过（全部步骤） | ❌ `test-without-building` 失败 | 运行 5 修复后的复跑。XCTest：`CamCardCloneTests` 45/45（`FieldParserTests` 26，含新增 3 例粘连标签）、`CamCardDataTests` 12/12；XCUITest：`ExceptionPathUITests` 5/5、`CardListUITests` 6/8（13 例中 11 例通过）。`testTagCreateFilterAndDelete` 89.438 s 通过；`testEditNameUpdatesListAndDetail`（99.747 s）、`testEditsSurviveRelaunch`（102.165 s）失败——键入选区方案中的两次 1 s 长按拖拽后，`typeText` 前等待 App 空闲 60 s 超时，只键入部分字符。B 层：40/40 张完成识别、虚构 0、字段级 429/440 = 97.5%、整卡 31/40（C02/C03 解析粘连已消除）。修复见 §2.16 |
| 7 | [41279949458](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)（commit `c499448`） | ✅ 通过（全部步骤） | ✅ **通过**（首次全绿） | 本轮提交 §2.15 的截图取证与导出、§2.16 的输入方式替换，以及运行 5/6 的真实结果文档。`build-for-testing` ✅、`test-without-building` ✅（06:13:31Z–06:26:39Z，结论 success）。XCTest：`CamCardCloneTests` 45/45（`FieldParserTests` 26、`FixtureParserTests` 3、`ImageCorrectionTests` 3、`OCRServiceTests` 3、`ScannerDismissalTests` 4、`VCardExporterTests` 6）、`CamCardDataTests` 12/12。XCUITest 13/13：`CardListUITests` 8/8（208.802 s；两例编辑 28.750 s / 24.658 s 通过）、`ExceptionPathUITests` 5/5（44.047 s）。B 层：40/40 张、虚构 0、字段级 429/440 = 97.5%、整卡 31/40，与运行 6 逐卡一致。UI 截图导出 `PNG 数量：       7`，工件 `ui-screenshots`（467 225 B）已上传；失败工件步骤按 `if: failure()` 跳过，属预期 |
| 8 | [41281795449](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)（commit `e28da4b`） | ✅ 通过（全部步骤：checkout、setup-python、PyYAML、YAML 校验、actionlint、数据集校验、py_compile 预检；06:40:52Z–06:41:01Z） | ✅ 通过（06:41:03Z–06:54:43Z，结论 success） | §2.17「UI 截图对比、截图入库与结构校验」批次的独立回归。步骤：`build-for-testing` ✅（06:41:35Z–06:42:09Z）、`运行测试（test-without-building）` ✅（06:42:09Z–06:52:29Z）、`B 层` ✅（06:52:29Z–06:54:33Z）、`导出 UI 截图` ✅、`上传 UI 截图` ✅；`安装 XcodeGen` 因缓存命中跳过、失败工件步骤 `if: failure()` 跳过，均属预期。XCTest：`CamCardCloneTests` 45/45、`CamCardDataTests` 12/12。XCUITest 13/13（288.092 s）：`CardListUITests` 8/8（238.531 s：Delete 25.495 / Detail 13.806 / EditName 20.570 / EditsSurviveRelaunch 20.044 / Export 14.397 / FirstLaunch 7.716 / Search 24.307 / Tag 112.195）、`ExceptionPathUITests` 5/5（49.561 s：CameraPermissionDenied 12.106 / Cancelling 11.267 / FixtureImages 0.113 / SaveAfterRecognition 14.586 / Unrecognizable 11.490）。B 层：40/40 张、虚构 0、字段级 429/440 = 97.5%、召回 237/248、缺失精度 192/192、整卡 31/40，与运行 7 **逐卡及逐字节一致**（工件仅生成时间戳不同）。截图 `PNG 数量：       7` 并上传 `ui-screenshots`（467 054 B），结构校验通过；工件 `ocr-accuracy-report` 13 482 B |
| 9 | [41283224211](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)（commit `e24f864`） | ✅ 通过（全部步骤：checkout、setup-python、PyYAML、YAML 校验、actionlint、数据集校验、py_compile 预检；07:03:17Z–07:03:24Z；API 记为 11 条步骤记录） | ✅ 通过（07:03:26Z–07:10:34Z，结论 success） | §2.18「T01–T20 验收报告与 SDD 归档」批次的独立回归（commit `e24f864`）。步骤：`准备模拟器` ✅（17 s）、`安装 XcodeGen` 缓存命中跳过、`build-for-testing` ✅（07:03:48Z–07:04:05Z）、`运行测试（test-without-building）` ✅（07:04:05Z–07:08:52Z）、`B 层` ✅（07:08:52Z–07:10:24Z）、`导出 UI 截图` ✅（07:10:26Z–07:10:28Z）、`上传 UI 截图` ✅（480 239 B）、`上传准确率报告` ✅（13 482 B）、失败工件步骤 `if: failure()` 跳过，均属预期。XCTest：`CamCardCloneTests` 45/45（"Executed 45 tests, with 0 failures … 5.033 s"）、`CamCardDataTests` 12/12（0.038 s）。XCUITest 13/13（204.497 s）：`CardListUITests` 8/8（164.348 s：Delete 25.325 / Detail 13.470 / EditName 21.424 / EditsSurviveRelaunch 21.192 / Export 12.789 / FirstLaunch 4.886 / Search 21.752 / Tag 43.509）、`ExceptionPathUITests` 5/5（40.149 s：CameraPermissionDenied 8.521 / Cancelling 9.263 / FixtureImages 0.067 / SaveAfterRecognition 12.011 / Unrecognizable 10.288）。B 层：`VisionAccuracyTests` ✅（30.892 s）：40/40 张、虚构 0、字段级 429/440 = 97.5%、召回 237/248、缺失精度 192/192、整卡 31/40；`ocr-accuracy-report.json`（152 940 B）与运行 7 仅 `generatedAt` 不同。截图 7 张逐张 `[通过] S01`–`[通过] S07`；与运行 8 逐像素比较：S01–S04、S06、S07 仅状态栏时间区差异，S05 因表单整体下垂约 5 px 差异 104 237 px（内容一致） |
| 10 | [41284584464](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)（commit `05c20f1`） | ✅ 通过（全部步骤；07:23:20Z–07:23:27Z；API 记为 11 条步骤记录，Complete job 为第 17 号步骤） | ✅ 通过（07:23:29Z–07:33:40Z，结论 success） | §2.19「步骤口径、复核提示与运行 9 截图差异落档」批次的独立回归。static 逐步时间：Set up job 07:23:21–22、checkout 22–23、setup-python 23、安装 PyYAML 23–24、校验 workflow YAML 24、actionlint 24–25、数据集校验 25、py_compile 25、Post setup-python 25、Post checkout 25、Complete job(=17) 25。macOS job：Set up job 07:23:30–31、checkout 31–32、选择 Xcode 16.4 32–33、`准备模拟器` ✅（07:23:33Z–07:23:57Z，24 s）、缓存 XcodeGen 57–58、`安装 XcodeGen` 缓存命中跳过、生成 Xcode 工程 58、`build-for-testing` ✅（07:23:58Z–07:24:21Z）、`运行测试（test-without-building）` ✅（07:24:21Z–07:31:34Z）、`B 层` ✅（07:31:34Z–07:33:30Z）、`准确率摘要` ✅（33:30）、`上传准确率报告` ✅（33:30–33:32）、`导出 UI 截图` ✅（33:32–33:35）、`上传 UI 截图` ✅（33:35–33:36）、`测试摘要` ✅（33:36）、失败工件步骤 `if: failure()` 跳过、Post 缓存 XcodeGen 36–37、Post checkout 37、Complete job 37–38。XCTest：`CamCardCloneTests` 45/45（"Executed 45 tests, with 0 failures … 3.867 s"，子套件 26 + 3 + 3 + 3 + 4 + 6）、`CamCardDataTests` 12/12（0.039 s）。XCUITest 13/13（321.292 s）：`CardListUITests` 8/8（267.362 s：Delete 102.681 / Detail 20.756 / EditName 25.784 / EditsSurviveRelaunch 23.971 / Export 14.907 / FirstLaunch 5.941 / Search 23.530 / Tag 49.787）、`ExceptionPathUITests` 5/5（53.937 s：CameraPermissionDenied 15.285 / Cancelling 12.037 / FixtureImages 0.271 / SaveAfterRecognition 14.508 / Unrecognizable 11.833）。B 层：`VisionAccuracyTests` ✅（37.738 s）：40/40 张、虚构 0、字段级 429/440 = 97.5%、召回 237/248、缺失精度 192/192、整卡 31/40；`ocr-accuracy-report.json`（152 940 B）与运行 9 仅 `generatedAt`（07:10:20Z → 07:33:25Z）不同。截图 7 张逐张 `[通过] S01`–`[通过] S07`，工件 `ui-screenshots` 480 334 B、`ocr-accuracy-report` 13 483 B；与运行 9 逐像素比较：S01–S04、S06、S07 只有状态栏时间与搜索框光标差异，S05 表单再下垂 6 px（100 064 px，对齐后热像素 5 872）；本地 `verify_ui_screenshots.py` 复核 exit 0 |
| 11 | [41288191075](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075)（commit `2827935`） | ✅ 通过（全部步骤；job 级 09:16:53Z–09:17:02Z，步骤 08:16:54Z–08:16:58Z；11 条步骤记录） | ✅ 通过（步骤 08:17:04Z–08:28:43Z，结论 success） | §2.20「运行 10 结果落档与截图差异复算口径更正」批次的独立回归（`git diff 05c20f1 2827935`：6 个 `docs/` 文件、256 增 44 删）。步骤（job 级 API，共 19 条 step 记录）：Set up job 08:17:04–06、checkout 06–08、选择 Xcode 16.4 08、`准备模拟器` ✅（08:17:08Z–08:18:18Z，70 s；UDID `210784C8-…`）、缓存 XcodeGen 18:18–19、`安装 XcodeGen` 缓存命中跳过、生成 Xcode 工程 18:19、`build-for-testing` ✅（18:19–18:46，27 s）、`运行测试（test-without-building）` ✅（08:18:46Z–08:26:38Z）、`B 层` ✅（08:26:38Z–08:28:33Z）、准确率摘要 28:33、上传准确率报告 28:33–35、导出 UI 截图 28:35–40、上传 UI 截图 28:40–41、测试摘要 28:41、失败工件步骤 `if: failure()` 跳过、Post 缓存 XcodeGen 28:41、Post checkout 28:41–42、Complete job(=33) 28:42–43。XCTest：`CamCardCloneTests` 45/45（"Executed 45 tests, with 0 failures … 4.284 (8.262) seconds"；`FieldParserTests` 26 / 0.348 s、`FixtureParserTests` 3、`ImageCorrectionTests` 3、`OCRServiceTests` 3、`ScannerDismissalTests` 4、`VCardExporterTests` 6）、`CamCardDataTests` 12/12（0.097 (0.114) s）。XCUITest 13/13（222.892 s）：`CardListUITests` 8/8（171.491 s：Delete 22.538 / Detail 14.605 / EditName 21.128 / EditsSurviveRelaunch 24.029 / Export 13.549 / FirstLaunch 5.058 / Search 26.007 / Tag 44.577）、`ExceptionPathUITests` 5/5（51.401 s：CameraPermissionDenied 8.520 / Cancelling 12.970 / FixtureImages 0.185 / SaveAfterRecognition 16.482 / Unrecognizable 13.244）。B 层：`VisionAccuracyTests` ✅（39.680 s）：40/40 张、虚构 0、错位 0、可选字段误补 0，字段级 429/440 = 97.5%、召回 237/248、缺失精度 192/192、整卡 31/40；`ocr-accuracy-report.json`（152 940 B）与运行 10 仅 `generatedAt`（07:33:25Z → 08:28:27Z）不同。截图 7 张逐张 `[通过] S01`–`[通过] S07`，「UI 截图齐全」；工件 `ui-screenshots`（id 13076521746，467 313 B）、`ocr-accuracy-report`（id 13076108296，13 483 B），保留至 2026-12-01；本地 `verify_ui_screenshots.py .tools/ci/run11-artifacts/ui-screenshots` exit 0。与运行 10 逐像素比较：S01–S04、S06、S07 只有状态栏时钟（875–1 118 px），S03 另加搜索框光标（176 px），S05 为 0–749 列、11–1 321 行的整页差异 135 059 px，按 −11 行对齐后回到运行 8 的位置（强差异 8 553、残差 60 715）；与运行 8 比较：第 60 行以下 0 px 差异（S03 只有光标 176 px） |

记要：

- 首个公开仓库 `Asorijin/Tongji-MobileAppDev` 为唯一远端；本机 SSH 22 端口在当前网络被拦截，
  改用 GitHub 官方 443 端口通道（`ssh://git@ssh.github.com:443/...`），属于网络环境问题，与仓库配置无关。
- 运行 3 之后，CI 的模拟器设备由「准备模拟器」步骤显式创建并记录 UDID；镜像自带预置设备是否注册
  不再影响构建与测试（设备创建失败或运行版本缺失时会显式报错，不会静默跳过）。
- 运行 4 证明「YAML 能解析」不等于「GitHub 接受」：失败发生在启动 job 之前，日志、工件、Step Summary
  都不会产生，只能从运行 API 的 job 数为 0 与瞬时结束时间识别。static job 现已加入 actionlint，
  本地也可用 `.tools/actionlint/actionlint.exe` 做同样检查（下载物不提交）。
- 首轮暴露的 4 个错误全部位于 **Windows 本地无法类型检查的文件**
  （`CamCardCloneApp.swift` 的 DEBUG 示例数据、`CardDetailView` 的 UIKit 图像加载）。
  本地 `swiftc -frontend -parse` 只能验证语法，不能替代 Xcode 编译——这正是 CI 的价值，
  也解释了为什么本地通过不等于 CI 通过。
- 运行 6 说明「一次修复只解决一层问题」是常态：同一个编辑用例在运行 5、6 中因**不同原因**
  失败（二次点击 → 长按拖拽导致的空闲等待），因此每一轮都必须读日志归因，不能按「上次的原因」
  猜修复。日志里的 `t = ...` 交互记录是 UI 测试最可靠的证据。
- 运行 7 是首轮全绿：确定性层（54 个 XCTest + 13 个 XCUITest）全部通过的同时，概率性层
  （B 层 429/440 = 97.5%）与运行 6 **逐卡完全相同**——说明测试输入方式与 CI 截图步骤的改动
  没有副作用，这两类改动本来就只在测试与 CI 层。截图证据的成功导出与失败工件步骤的跳过
  （`if: failure()`）也在同一轮得到验证。
- 运行 7 的截图同时暴露了一个文档层面的问题：`xcresulttool` 导出的文件名是 UUID，
  必须靠 `manifest.json` 才能追溯到来源用例。为此新增 `scripts/verify_ui_screenshots.py`
  做结构校验，并把 7 张 PNG 从 750×1334 原字节复制进 `docs/ui-screenshots/`，
  让「截图对比」文档在仓库内即可复核，而不是只存在于 30 天保留期的 CI 工件里。
- 运行 8 验证了「纯文档增量不动被测功能」：XCTest 与 XCUITest 全绿，B 层逐卡以及整份
  `ocr-accuracy-report` 工件与运行 7 **逐字节相同**（仅 `generatedAt` / 生成时间行不同）。
  截图逐像素对比则暴露了另一类事实：7 张截图在两次全绿运行之间都有差异，但差异全部是
  **时间性伪影**——状态栏时钟（每张都有）与搜索框闪烁光标（S03）——不是页面内容回归。
  这正是 `docs/ui-screenshot-comparison.md` §7 所述「像素级基线需要固定时间与光标状态」的实据；
  同时说明 UI 测试耗时逐轮波动明显（`CardListUITests` 208.802 s → 238.531 s，其中 Tag 112.195 s
  比运行 7 的 47.843 s 慢一倍多），CI 计时不能当作性能回归指标。
- 运行 9 修正了上一轮结论的适用边界：运行 8 → 9 的 S05 截图出现**整页下垂约 5 px** 的排版抖动
  （104 237 px = 10.4185%，对齐后只剩抗锯齿级残差，暗像素 IoU 0.9256，内容逐行对齐），
  而两次提交之间 `git diff` 只有 `docs/`。因此「截图差异只来自状态栏与光标」不能推广为通则：
  截图差异必须区分「可解释伪影」与「内容回归」，后者要用对齐残差、掩码与元素行区间三项核对排除
  （过程与复算方式见 `docs/ui-screenshot-comparison.md` §7.2）。这也是本轮唯一需要更正的既有结论。
- 步骤数核对（2026-11-01）：早期把 `static` job 记为「17 个步骤」，该数字实际是**步骤编号**
  而不是步骤条数——GitHub API 对运行 7 的 `静态检查` job 返回 11 条记录（Set up job + 7 个
  检查步骤 + Post setup-python / Post checkout / Complete job），而「17」只是最后一条记录
  `Complete job` 的编号（其后的编号留给 Post 步骤与 job 级动作）。已把本文件与
  `docs/test-suite.md` 中的「17 个步骤」统一改为「全部步骤」或按 API 记录写明，避免用
  可被证伪的数字做结论。
- 运行 10 验证的是 §2.19 这一整批文档更正：结论 success，确定性层 57 + 13 例与运行 7、8、9
  完全一致，B 层 `ocr-accuracy-report` 与运行 9 仅 `generatedAt` 不同。S05 的表单在运行 9 比运行 8
  低 5 行、在运行 10 比运行 8 低 11 行。对齐方法随之固定：以 **>32 灰度级像素数最少**为对准标准；
  若改用「任何差异像素数最少」，运行 8 → 10 会误选 dy=+8（元素并未移 8 px），留下 >64 级
  32 276 px 的错位双线。这一点写进了 `docs/ui-screenshot-comparison.md` §7.3 与复算脚本。
- 运行 11 是把「S05 抖动」定性的那一次：截图采样从三次扩到五次后，S05 的内容位置只出现三种取值，
  运行 7、8、11 完全相同（基线 A），运行 9 = A + 5 行，运行 10 = A + 11 行；运行 11 相对运行 10
  的位移是**回到基线**（对齐 −11 行，强差异 8 553），而不是又漂了一段。运行 8 → 11 的 7 张截图
  除状态栏时钟与 S03 光标外**零差异**（第 60 行以下 0 px），S03 的光标在这段时间里有三种颜色
  （(60,151,251)、(119,180,248)、(0,122,255)），但位置与像素数始终是行 70–113、列 160–163、176 px。
  于是「0 → +5 → +11 是逐渐漂移」的读法被推翻：模拟器的排版抖动落在几个离散状态上，
  两次相隔约 1.5 小时、中间还隔着两轮的运行可以逐像素一致。像素基线若实现，容差仍按
  「整页竖直 ±11 px 内、按文本行对齐后比较强差异」，但不必假设漂移单调或有累积。
- 运行 11 还给出了一个工程上的观察：GitHub API 的 run 级 `created_at` / `updated_at` 比该 run 的
  job 与 step 时间晚整整 1 小时（run 级 09:16:51Z–09:28:45Z，job/step 08:17:04Z–08:28:43Z），
  而工件 `created_at` 跟着 run 级走、`expires_at` 跟着 step 走。日志时间戳内部自洽、提交的
  committer date（08:16:44Z）与外部 HTTP `Date` 都支持 08:16–08:28Z，因此本文件与
  `docs/test-suite.md` 一律引用日志与 step 的 UTC 作为步骤时间；引用运行 API 的时间时只用于链接与量级，
  不据此单独下结论。
