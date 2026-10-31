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
| 取消不落库 / 手动录入取消返回名片夹 | `ScannerDismissalTests`（✅）+ `ExceptionPathUITests` | 规则单测通过；UI 端到端在 CI 运行 2 真实通过（4/4 异常路径用例） |
| 识别失败可手动录入 | UI 测试 + 代码审查 | CI 运行 2 中 `testUnrecognizableImageOffersManualFallback` 真实通过 |
| 识别 → 确认 → 保存 → 列表出现 | `ExceptionPathUITests.testSaveAfterRecognitionAddsCard` | 用例于 2.11 新增，等待下一轮 CI 真实运行 |
| 删除标签不删名片 | UI 测试 + 单测 | 单测通过；UI 用例在运行 2 因工具栏菜单点击问题失败，修复后待重跑（§8） |

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
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 2](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)） | XCTest 42 + 12 通过；UI 7/12 通过（5 例失败） | 失败全部是 XCUITest 点击工具栏 `Menu` 的 AX 错误，修复见 §2.11；修复后待重跑 |
| 2026-11-01 | XCTest + XCUITest（iOS 模拟器） | GitHub Actions `build-and-test`（[运行 3](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231201327)） | ❌ 未进入测试阶段 | 镜像未注册模拟器，`build-for-testing` 报找不到 iPhone SE / iOS 18.5；环境问题，修复见 §2.12 |
| 2026-11-01 | 全部 CI job | GitHub Actions（[运行 4](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231848508)） | ❌ 未启动任何 job | job 名称使用 `${{ env.* }}` 被 GitHub 拒绝（job 数 0，瞬时结束）；修复见 §2.13 |
| 2026-11-01 | B 层端到端准确率 | CI `ocr-accuracy-report` 工件 | 待运行 | 运行 2 的提交不含 B 层步骤；运行 3 构建前失败；运行 4 未启动 job；随下一轮执行 |
| （Week 6 验收） | T01–T20 | `docs/test-suite.md` 全量 | 待运行 | 只记录真实结果 |

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
| 5 | 待运行 | 待运行 | 待运行 | 提交 §2.13 的 CI 修复；预期首次执行 UI 修复后的全量测试与 B 层准确率工件。运行完成前不写结论 |

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
