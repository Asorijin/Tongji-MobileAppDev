# Reference Test Suite（T01–T20）

> 依据作业 §17：T01–T20 共 20 个场景。「确定性的 20 个 Reference Test Scenarios 必须 100% 通过」。
> 本文件把每个场景映射到**具体测试用例**，并如实标注无法在模拟器上自动化的部分（人工验证清单）。
> 逐场景的验收结论（运行链接、耗时、六个一致性维度、人工项状态）汇总在
> [acceptance-report.md](acceptance-report.md)。
> 代码位置：`CamCardCloneTests/`（单元测试）、`CamCardDataTests/`（数据层）、`CamCardCloneUITests/`（UI 测试）。

---

## 1. 验收状态总览

| 层 | 运行环境 | 用例数 | 状态 |
| --- | --- | --- | --- |
| 解析器单元测试（`FieldParserTests`） | 任意（Windows `swift test` / iOS 模拟器） | 26 | ✅ 本地已通过 |
| 数据集字段准确率（`FixtureParserTests`） | 任意 | 3 | ✅ 本地已通过 |
| vCard 导出（`VCardExporterTests`） | 任意 | 6 | ✅ 本地已通过 |
| 数据层（`CardStoreTests`） | 任意 / iOS 模拟器 | 12 | ✅ 本地已通过 |
| 扫描关闭规则（`ScannerDismissalTests`） | 任意 | 4 | ✅ 本地已通过 |
| OCR / 区域检测（`OCRServiceTests`、`ImageCorrectionTests`） | 仅 iOS 模拟器（Vision / UIKit） | 6 | ✅ CI 运行 5、6、7、8、9 均真实通过（3 + 3） |
| OCR 端到端准确率（`VisionAccuracyTests`，B 层） | 仅 iOS 模拟器（Vision） | 1（40 张 × 11 字段） | ✅ CI 运行 7、8、9 真实通过（40/40 张完成识别，虚构 0，字段级 429/440 = 97.5%；运行 6、7、8、9 数字与逐卡结果相同） |
| UI 路径（`ExceptionPathUITests` + `CardListUITests`） | 仅 iOS 模拟器 | 5 + 8 | ✅ CI 运行 7、8、9：13/13 全部通过（名片夹 8/8、异常路径 5/5） |

本地 Windows 结果（2026-11-01）：`swift test` **51/51 通过**（领域 39 + 数据 12）；
领域 39 = `FieldParserTests` 26 + `FixtureParserTests` 3 + `VCardExporterTests` 6 + `ScannerDismissalTests` 4。
2026-11-01 稍早的基线为 48/48（当时 `FieldParserTests` 为 23 例），2026-10-31 为 44/44。
模拟器与 CI 结果以 GitHub Actions 运行记录为准，本文件只引用真实运行结果。

CI 运行 2（[41229690851](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)，commit `96ab470`）的真实结果：

- `static` ✅；`build-for-testing` ✅；
- XCTest：`CamCardCloneTests` 42/42（含 OCR/校正 6 例）、`CamCardDataTests` 12/12 ✅；
- XCUITest：`ExceptionPathUITests` 4/4 ✅；`CardListUITests` 3/8 —— 5 个失败全部发生在
  点击详情页工具栏菜单时（XCUITest AX scroll-to-visible 报 `kAXErrorCannotComplete`），
  不是被测功能失败；测试已改用坐标点击绕开（`docs/ai-collaboration-log.md` §2.11），等待重跑；
- 该提交不含 B 层 CI 步骤，准确率工件未生成。

CI 运行 5（[41232174313](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41232174313)，commit `016e0e8`，2026-10-31T19:01:05Z–19:09:24Z）的真实结果：

- `static` ✅（全部步骤：checkout、setup-python、PyYAML、YAML 校验、actionlint、数据集校验、py_compile 预检）；
- `build-for-testing` ✅；
- XCTest：`CamCardCloneTests` 42/42 ✅、`CamCardDataTests` 12/12 ✅；
- XCUITest：`ExceptionPathUITests` 5/5 ✅（含 `testSaveAfterRecognitionAddsCard`；该套件 5 例合计 64.233 s）；
  `CardListUITests` 5/8（201.457 s）——通过：`testFirstLaunchShowsEmptyState`（4.733 s）、
  `testDetailShowsAllSavedFields`（12.110 s）、`testSearchByNameCompanyAndPhone`（19.888 s）、
  `testDeleteFromDetailRemovesCard`（83.092 s）、`testExportOpensShareSheet`（13.220 s）；
  失败为 `testEditNameUpdatesListAndDetail`（25.639 s）、
  `testEditsSurviveRelaunch`（22.710 s）、`testTagCreateFilterAndDelete`（20.065 s）；
- B 层：`VisionAccuracyTests` ✅（31.049 s，40/40 张完成识别，虚构字段 0，字段级 427/440 = 97.0%）；
  `ocr-accuracy-report` 工件已生成并上传；
- 结论：该轮在 `运行测试（test-without-building）` 步骤判定为失败（XCTest 断言失败导致步骤失败），
  其余步骤均成功。3 个 UI 失败的根因与修复见 `docs/ai-collaboration-log.md` §2.14；
  B 层数字与错误归因见 `docs/ocr-accuracy.md` §5.2–§5.3。

CI 运行 6（[41234214941](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)，commit `08c1730`，2026-10-31T19:26:17Z–19:46:33Z）的真实结果：

- `static` ✅（全部步骤：checkout、setup-python、PyYAML、YAML 校验、actionlint、数据集校验、py_compile 预检）；
- `build-for-testing` ✅；
- XCTest：`CamCardCloneTests` 45/45 ✅（`FieldParserTests` 26 例，含运行 5 修复新增的 3 例粘连标签）、
  `CamCardDataTests` 12/12 ✅；
- XCUITest：`ExceptionPathUITests` 5/5 ✅（53.508 s）；`CardListUITests` 6/8（399.827 s）——
  通过：`testFirstLaunchShowsEmptyState`（7.407 s）、`testDetailShowsAllSavedFields`（13.570 s）、
  `testSearchByNameCompanyAndPhone`（28.064 s）、`testTagCreateFilterAndDelete`（89.438 s，
  §2.14 的滚动修复生效）、`testDeleteFromDetailRemovesCard`（35.587 s）、
  `testExportOpensShareSheet`（23.845 s）；
  失败为 `testEditNameUpdatesListAndDetail`（99.747 s）、`testEditsSurviveRelaunch`（102.165 s）：
  日志显示两次 1 s 长按拖拽后，`typeText` 前的「等待 App 空闲」拖到 60 s 超时才继续，
  只键入了部分字符——输入方式已在 §2.16 替换，待运行 7 验证；
- B 层：`VisionAccuracyTests` ✅（42.633 s，40/40 张完成识别，虚构 0，字段级 429/440 = 97.5%，
  整卡全对 31/40 = 77.5%）；`ocr-accuracy-report` 工件已生成并上传；
- 结论：该轮仍判定失败，失败点全部在 UI 测试的输入辅助函数；被测功能与解析器改动均按预期工作。

CI 运行 7（[41279949458](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)，commit `c499448`，2026-11-01T06:13:31Z–06:26:39Z，结论 **success**）的真实结果：

- `static` ✅（全部步骤：checkout、setup-python、PyYAML、YAML 校验、actionlint、数据集校验、py_compile 预检）；
- `build-for-testing` ✅、`test-without-building` ✅（首次全绿）；
- XCTest：`CamCardCloneTests` 45/45 ✅（`FieldParserTests` 26、`FixtureParserTests` 3、
  `ImageCorrectionTests` 3、`OCRServiceTests` 3、`ScannerDismissalTests` 4、`VCardExporterTests` 6）、
  `CamCardDataTests` 12/12 ✅；
- XCUITest：`ExceptionPathUITests` 5/5 ✅（44.047 s）；`CardListUITests` 8/8 ✅（208.802 s，合计 208.811 s）——
  `testFirstLaunchShowsEmptyState`（6.750 s）、`testDetailShowsAllSavedFields`（33.538 s）、
  `testEditNameUpdatesListAndDetail`（28.750 s，§2.16 的输入方式替换生效）、
  `testEditsSurviveRelaunch`（24.658 s，同样生效）、`testSearchByNameCompanyAndPhone`（24.594 s）、
  `testTagCreateFilterAndDelete`（47.843 s）、`testDeleteFromDetailRemovesCard`（27.384 s）、
  `testExportOpensShareSheet`（15.286 s）；
  `ExceptionPathUITests` 逐例：`testCameraPermissionDeniedShowsGuidance`（9.755 s）、
  `testCancellingAfterRecognitionLeavesNoCard`（10.227 s）、`testFixtureImagesAreDecodable`（0.109 s）、
  `testSaveAfterRecognitionAddsCard`（13.292 s）、`testUnrecognizableImageOffersManualFallback`（10.665 s）；
  UI 总计 13 例、252.850 s；
- B 层：`VisionAccuracyTests` ✅（51.344 s，40/40 张完成识别，虚构 0，字段级 429/440 = 97.5%，
  召回 237/248 = 95.6%，整卡全对 31/40 = 77.5%，与运行 6 逐卡结果完全一致）；
- UI 截图：`导出 UI 截图（Week 6 截图对比）` 步骤日志 `PNG 数量：       7`，
  工件 `ui-screenshots`（467 225 B）已上传；7 张截图与规格的逐项对比见
  [docs/ui-screenshot-comparison.md](ui-screenshot-comparison.md)；
- 结论：T01–T20 中可自动化的部分在运行 7 全部真实通过；人工清单（§3）未执行，仍为待填写。

CI 运行 8（[41281795449](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)，commit `e28da4b`，2026-11-01T06:40:48Z 起，结论 **success**）的真实结果
（§2.17「UI 截图对比」与截图入库批次的独立回归）：

- `static` ✅（全部步骤：checkout、setup-python、PyYAML、YAML 校验、actionlint、数据集校验、py_compile 预检；06:40:52Z–06:41:01Z）；
- `build-for-testing` ✅（06:41:35Z–06:42:09Z）、`运行测试（test-without-building）` ✅（06:42:09Z–06:52:29Z）；
- XCTest：`CamCardCloneTests` 45/45 ✅、`CamCardDataTests` 12/12 ✅；
- XCUITest 13/13 ✅（288.092 s）：`CardListUITests` 8/8（238.531 s）——
  `testDeleteFromDetailRemovesCard`（25.495 s）、`testDetailShowsAllSavedFields`（13.806 s）、
  `testEditNameUpdatesListAndDetail`（20.570 s）、`testEditsSurviveRelaunch`（20.044 s）、
  `testExportOpensShareSheet`（14.397 s）、`testFirstLaunchShowsEmptyState`（7.716 s）、
  `testSearchByNameCompanyAndPhone`（24.307 s）、`testTagCreateFilterAndDelete`（112.195 s）；
  `ExceptionPathUITests` 5/5（49.561 s）：`testCameraPermissionDeniedShowsGuidance`（12.106 s）、
  `testCancellingAfterRecognitionLeavesNoCard`（11.267 s）、`testFixtureImagesAreDecodable`（0.113 s）、
  `testSaveAfterRecognitionAddsCard`（14.586 s）、`testUnrecognizableImageOffersManualFallback`（11.490 s）；
  逐例耗时与运行 7 不同属模拟器运行波动（Tag 112.195 s 对 47.843 s），不是代码回归；
- B 层：`VisionAccuracyTests` ✅（39.442 s；B 层步骤 06:52:29Z–06:54:33Z）：40/40 张完成识别，
  虚构 0、错位 0、可选字段误补 0；字段级 429/440 = 97.5%、召回 237/248 = 95.6%、
  缺失精度 192/192、整卡全对 31/40 = 77.5%；与运行 7 的 `ocr-accuracy-report` **逐字节相同**
  （仅生成时间行 / `generatedAt` 不同）；
- UI 截图：`导出 UI 截图` ✅，日志 `PNG 数量：       7`，步骤内置的结构校验逐张打印
  `[通过] S01`–`[通过] S07`（均为 750×1334、来源用例与清单一致），最后输出
  「UI 截图齐全：7 张，来源用例与尺寸符合 docs/ui-screenshot-comparison.md 清单。」；
  `上传 UI 截图` ✅，工件 `ui-screenshots`（467 054 B，保留至 2026-12-01）；
  本地再以 `scripts/verify_ui_screenshots.py .tools/ci/run8/ui-screenshots` 复核 exit 0；
  `ocr-accuracy-report` 工件 13 482 B；
- 失败工件步骤（`if: failure()`）跳过，属预期；
- 结论：Week 6 文档批次未动摇任何真实运行结果；确定性层 57 + 13 例与运行 7 一致全部通过，
  概率性层逐字节复现。

CI 运行 9（[41283224211](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)，commit `e24f864`，2026-11-01T07:03:15Z–07:10:35Z，结论 **success**）的真实结果
（Week 6 文档批次 §2.18 的独立回归：T01–T20 验收报告与 SDD 归档）：

- `static` ✅（07:03:17Z–07:03:24Z；API 同运行 8 记为 **11 条步骤记录**：Set up job、checkout、setup-python、
  安装 PyYAML、校验 workflow YAML、actionlint、数据集校验、py_compile、Post setup-python、Post checkout、
  Complete job=17 号；日志中「17 个步骤」是 Complete job 的步骤序号，不是步骤总数）；
- `build-for-testing` ✅（07:03:48Z–07:04:05Z）、`运行测试（test-without-building）` ✅（07:04:05Z–07:08:52Z）；
- XCTest：`CamCardCloneTests` 45/45 ✅（"Executed 45 tests, with 0 failures … 5.033 s"：`FieldParserTests` 26、
  `FixtureParserTests` 3、`ImageCorrectionTests` 3、`OCRServiceTests` 3、`ScannerDismissalTests` 4、
  `VCardExporterTests` 6）、`CamCardDataTests` 12/12 ✅（0.038 s）；日志内 71 个不同用例名、0 失败；
- XCUITest 13/13 ✅（204.497 s）：`CardListUITests` 8/8（164.348 s）——`testDeleteFromDetailRemovesCard`（25.325 s）、
  `testDetailShowsAllSavedFields`（13.470 s）、`testEditNameUpdatesListAndDetail`（21.424 s）、
  `testEditsSurviveRelaunch`（21.192 s）、`testExportOpensShareSheet`（12.789 s）、
  `testFirstLaunchShowsEmptyState`（4.886 s）、`testSearchByNameCompanyAndPhone`（21.752 s）、
  `testTagCreateFilterAndDelete`（43.509 s）；`ExceptionPathUITests` 5/5（40.149 s）：
  `testCameraPermissionDeniedShowsGuidance`（8.521 s）、`testCancellingAfterRecognitionLeavesNoCard`（9.263 s）、
  `testFixtureImagesAreDecodable`（0.067 s）、`testSaveAfterRecognitionAddsCard`（12.011 s）、
  `testUnrecognizableImageOffersManualFallback`（10.288 s）；逐例波动同运行 8，属模拟器运行波动；
- B 层：`VisionAccuracyTests` ✅（30.892 s，B 层步骤 07:08:52Z–07:10:24Z）：40/40 张完成识别，虚构 0、
  错位 0、可选字段误补 0；字段级 429/440 = 97.5%、召回 237/248 = 95.6%、缺失精度 192/192、
  整卡全对 31/40 = 77.5%；`ocr-accuracy-report.json`（152 940 B）与运行 7 的差异**只有** `generatedAt`
  （06:26:19Z → 07:10:20Z），运行 6→7→8→9 四轮逐卡结果完全相同；
- UI 截图：`导出 UI 截图` ✅（07:10:26Z–07:10:28Z），日志 `PNG 数量：       7` 且逐张 `[通过] S01`–`[通过] S07`；
  `上传 UI 截图` ✅，工件 `ui-screenshots`（480 239 B，保留至 2026-12-01）；`上传准确率报告` ✅
  （工件 `ocr-accuracy-report`，13 482 B）；失败工件步骤（`if: failure()`）跳过，属预期；
- 与运行 8 的逐像素对比：S01–S04、S06、S07 的差异只在状态栏时间区（582–1 256 px）；
  **S05 因表单整体下垂约 5 px 相差 104 237 px（10.4185%）**，内容一致，属界面记录的模拟器排版抖动
  （`docs/ui-screenshot-comparison.md` §7.2）；
- 结论：确定性层 57 + 13 例与运行 7、8 一致全部通过，概率性层逐字节复现；本轮为纯文档增量，
  唯一变化的运行时行为是 S05 的模拟器排版抖动。

覆盖率边界（诚实声明）：

- Vision/UIKit 相关用例在 Windows 上按平台条件编译为空（`#if canImport(UIKit)`），因此本地统计只覆盖 51 例；
  这 6 个 Vision/校正用例与 1 个 B 层用例已在 CI 模拟器上真实通过（运行 5、6、7、8、9）；13 个 UI 用例在运行 7、8、9 中均 13/13 通过。
- **无法在模拟器自动化**的场景：真实相机拍摄、系统照片库选择、系统权限弹窗、系统分享面板的最终落地动作。
  这些场景以「人工验证清单」（第 3 节）验收，自动化只覆盖其可测部分（如权限拒绝的界面分支）。

---

## 2. 场景 → 测试映射

约定：
- ✅ = 已在本地真实运行并通过（Windows `swift test` 或数据集校验），或在 CI 上真实运行并通过（注明确切轮次）；
- ⏳ = 已写好自动化用例，但尚未在模拟器/CI 上真实运行过（首次运行后改为 ✅ 或修复）——截至运行 7 已无此项；
- 🔶 = 部分自动化（关键路径自动、人工补充）；
- 👤 = 人工验证。

### T01 — First Launch

| 断言 | 测试 |
| --- | --- |
| 首次启动进入名片夹；空状态提示与扫描/手动录入入口可见 | ✅ `CardListUITests.testFirstLaunchShowsEmptyState`（CI 运行 5、6、7 均通过） |

### T02 — Enter Scanner

| 断言 | 测试 |
| --- | --- |
| 名片夹 → 扫描入口 → 进入扫描页（拍照/照片库入口、取消） | ✅ `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（CI 运行 5、6、7 均通过，扫描页可见） |
| 规格偏差：进入的是「拍摄/导入选择页」，不是原生相机页 | 📄 见 `docs/spec.md` §4.2、§9 第 1 条；真机相机页由 §3 人工清单覆盖 |

### T03 — Permission

| 断言 | 测试 |
| --- | --- |
| 相机权限被拒 → 说明文字 + 照片库导入；不显示拍照按钮 | ✅ `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（CI 运行 5、6、7 均通过） |
| 系统权限弹窗本身（首次请求） | 👤 人工清单 |

### T04 — Capture

| 断言 | 测试 |
| --- | --- |
| 拍摄 → 进入识别流程 | 👤 人工清单（模拟器无相机） |
| 拍摄后「使用照片 / 重拍」 | 📄 位于系统 `UIImagePickerController` 界面；App 内无复核页（差距见 `docs/spec.md` §9-9），真机核对见 M3 |
| 识别流程本身（校正 → OCR → 确认表单项） | ✅ `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（CI 运行 5、6、7 均通过，注入图像走同一识别链路） |

### T05 — Import

| 断言 | 测试 |
| --- | --- |
| 从相册导入 → 进入识别流程 | 👤 人工清单（系统照片选择器） |
| 照片库取消 | 👤 人工清单 |
| 选图确认 | 📄 位于系统照片选择器界面，选图后直接进入识别（`spec.md` §9-9） |
| 导入图像的解码与校正 | ✅ `ImageCorrectionTests`（CI 运行 5、6、7，3/3）、`ExceptionPathUITests.testFixtureImagesAreDecodable`（CI 运行 5、6、7 均通过） |

### T06 — Card Boundary Detection

| 断言 | 测试 |
| --- | --- |
| 倾斜名片（C03_tilt）能检测到名片四边形（非整图回退） | ✅ `ImageCorrectionTests.testDetectsTiltedCardQuad`（CI 运行 5、6、7 均通过） |
| 模拟器支持的 UIKit 方向归一 | ✅ `ImageCorrectionTests.testOrientedImageIsNormalized`（CI 运行 5、6、7 均通过） |
| 无法解码输入的错误处理 | ✅ `ImageCorrectionTests.testUnreadableDataThrows`（CI 运行 5、6、7 均通过） |
| 在 UI 中「显示检测结果」 | 复刻实现不单独展示边界框（自动校正后直接识别），差距记录于 `docs/spec.md` §9 第 3 条 |

### T07 — OCR

| 断言 | 测试 |
| --- | --- |
| 合成中文名片（C01_flat）→ Vision 产生原始文本，包含「朱宏明」「同济大学」 | ✅ `OCRServiceTests.testVisionRecognizesSyntheticChineseCard`（CI 运行 5、6、7 均通过） |
| OCR 文本流入解析器 → 姓名/公司/手机正确 | ✅ `OCRServiceTests.testRecognizedTextFlowsIntoParser`（CI 运行 5、6、7 均通过） |
| 非图像数据 → 错误而非崩溃 | ✅ `OCRServiceTests.testUnreadableImageThrows`（CI 运行 5、6、7 均通过） |

### T08 — Structured Extraction

| 断言 | 测试 |
| --- | --- |
| 中文/英文/中英双语名片字段分类 | ✅ `FieldParserTests`（26 例，含 C01/C03/C11/C21 样式的固定文本与 OCR 粘连标签样例） |
| 40 张数据集逐字段与 Ground Truth 100% 一致 | ✅ `FixtureParserTests.testAllFixturesMatchGroundTruth`（40/40） |
| 同一输入重复解析结果一致 | ✅ `FixtureParserTests.testEveryFixtureParsesDeterministically` |
| 老师示例（Dr. David Chen / Professor / School of CS / ABC University） | ✅ `FieldParserTests.testTeacherExampleFromAssignment` |

### T09 — Missing Field

| 断言 | 测试 |
| --- | --- |
| 名片无 Website → 不得虚构 Website | ✅ `FieldParserTests.testMissingWebsiteIsNotFabricated` |
| 显式「网址：无」→ 阻止后续启发式填充 | ✅ `FieldParserTests.testExplicitAbsentLabelBlocksHeuristics` |
| 极简名片只保留出现的字段 | ✅ `FieldParserTests.testMinimalCardKeepsOnlyPresentFields` |
| 纯 Logo 文本不产出字段 | ✅ `FieldParserTests.testLogoOnlyTextIsKeptAsUnclassifiedWithoutInvention` |
| 空白卡片 → 无任何字段 | ✅ `FixtureParserTests.testBlankCardProducesNoFields` |

### T10 — Multiple Phones

| 断言 | 测试 |
| --- | --- |
| Mobile / Office / Fax 按标签分类，互不混淆 | ✅ `FieldParserTests.testMultiplePhonesCategorizedByLabel` |
| 多个 Email 全部保留 | ✅ `FieldParserTests.testMultipleEmailsAllPreserved` |
| 无标签的 11 位 `1` 开头号码推断为手机 | ✅ `FieldParserTests.testUnlabeledElevenDigitNumberInferredAsMobile` |
| 数据集 C31–C34 多号码名片逐字段一致 | ✅ `FixtureParserTests.testAllFixturesMatchGroundTruth` |

### T11 — Manual Correction

| 断言 | 测试 |
| --- | --- |
| 确认表单可编辑全部字段；修改后保存落库 | ✅ `CardListUITests.testEditNameUpdatesListAndDetail`（CI 运行 7 真实通过，28.750 s；运行 5/6 的两轮失败与修复见 `ai-collaboration-log.md` §2.14/§2.16）+ ✅ `CardStoreTests.testUpdateKeepsIdentityAndMovesValues` |
| 空字段保持为空、不误填 | ✅ `ExceptionPathUITests.testUnrecognizableImageOffersManualFallback`（CI 运行 5、6、7 均通过） |
| 多值字段按行编辑并拆分 | 🔶 表单规则在 `CardEditView`（代码审查通过）；数据层多值断言 ✅ |
| 实际识别错误的逐项人工修改 | 👤 人工清单（Week 4 HITL 演示） |

### T12 — Save

| 断言 | 测试 |
| --- | --- |
| 写入逻辑：新名片插入顶部并持久化 | ✅ `CardStoreTests.testAddInsertsAtTopAndPersists` |
| 识别 → 确认表单 → 保存 → 返回名片夹 → 新名片出现 | ✅ `ExceptionPathUITests.testSaveAfterRecognitionAddsCard`（CI 运行 5、6、7 均通过；`-scanFixture C01` 端到端；运行 5 该套件 5 例合计 64.233 s，运行 7 该用例 13.292 s） |
| 保存前取消不写入任何数据 | ✅ `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（CI 运行 5、6、7 均通过，反向路径） |

### T13 — Detail

| 断言 | 测试 |
| --- | --- |
| 详情页正确显示全部保存字段（手机/办公/传真/邮箱/网址/地址/邮编/部门） | ✅ `CardListUITests.testDetailShowsAllSavedFields`（CI 运行 5、6、7 均通过）；页面见 `ui-screenshot-comparison.md` S02 |
| 空字段不显示 | 🔶 同上（注释行断言 `detail-notes` 不存在；该行在固定示例数据下成立，不是由数据变化触发的动态断言） |

### T14 — Edit

| 断言 | 测试 |
| --- | --- |
| 编辑姓名 → 保存 → 详情与列表更新 | ✅ `CardListUITests.testEditNameUpdatesListAndDetail`（CI 运行 7 真实通过，28.750 s；运行 5/6 的失败与修复见 §2.14/§2.16）；界面状态见 `ui-screenshot-comparison.md` S02 |
| 更新保持 id、替换字段、持久化 | ✅ `CardStoreTests.testUpdateKeepsIdentityAndMovesValues`、`testUpdateIgnoresUnknownCard` |

### T15 — Search

| 断言 | 测试 |
| --- | --- |
| 按姓名 / 公司 / 电话搜索并过滤 | ✅ `CardListUITests.testSearchByNameCompanyAndPhone`（CI 运行 5、6、7 均通过） |
| 无结果提示；清空后恢复 | ✅ 同上 |
| 跨字段搜索（姓名/公司/职位/电话/邮箱/传真/地址/部门） | ✅ `CardStoreTests.testSearchAcrossNameCompanyTitlePhoneEmail` |
| 正则字符按字面量处理 | ✅ `CardStoreTests.testSearchTreatsRegexCharactersLiterally` |

### T16 — Tag

| 断言 | 测试 |
| --- | --- |
| 新建标签 → 添加到名片 → 按标签筛选 → 删除标签 | ✅ `CardListUITests.testTagCreateFilterAndDelete`（CI 运行 6 真实通过 89.438 s、运行 7 47.843 s；§2.14 的滚动修复生效）；筛选状态见 `ui-screenshot-comparison.md` S04 |
| 标签生命周期（去重、创建、删除解除关联） | ✅ `CardStoreTests.testTagLifecycle` |
| 标签与关联在重启后保持 | ✅ `CardStoreTests.testTagsAndCardsSurviveReload` |

### T17 — Delete

| 断言 | 测试 |
| --- | --- |
| 详情页删除（含确认弹窗）→ 列表不再出现 | ✅ `CardListUITests.testDeleteFromDetailRemovesCard`（CI 运行 5、6、7 均通过） |
| 删除同时清理图像文件 | ✅ `CardStoreTests.testDeleteRemovesCardAndItsImages` |
| 删除确认取消 | 👤 人工清单（Alert 取消按钮；自动化路径已覆盖确认后的结果） |

### T18 — Persistence

| 断言 | 测试 |
| --- | --- |
| 编辑保存 → Kill App → 重启 → 修改保持 | ✅ `CardListUITests.testEditsSurviveRelaunch`（CI 运行 7 真实通过，24.658 s；运行 6 失败原因见 §2.16） |
| 存档重载（断言写盘→新实例读取） | ✅ `CardStoreTests.testStoreReloadsFromDisk` |
| 标签与关联重启后保持 | ✅ `CardStoreTests.testTagsAndCardsSurviveReload` |
| 损坏存档不崩溃 | ✅ `CardStoreTests.testCorruptedStoreFileIsIgnoredGracefully` |
| 图像相对路径可恢复 | ✅ `CardStoreTests.testImageStoreRelativePaths` |

### T19 — Export

| 断言 | 测试 |
| --- | --- |
| 详情 → 导出 → 系统分享面板出现 | ✅ `CardListUITests.testExportOpensShareSheet`（CI 运行 5、6、7 均通过） |
| 姓名/公司/职位/电话/Email/地址映射正确 | ✅ `VCardExporterTests.testCoreFieldsAreMapped` |
| 仅公司时 FN 兜底；特殊字符转义；NOTE 回退原文；空名片拒绝；批量导出 | ✅ `VCardExporterTests`（其余 5 例） |
| 在系统联系人 App 中导入 VCF 的结果 | 👤 人工清单（模拟器可「存储到文件」，不安装第三方通讯录） |

### T20 — Exception

| 断言 | 测试 |
| --- | --- |
| 空白名片 → 无法识别 → 手动录入 → 空表单不可保存 → 取消后仍为空 | ✅ `ExceptionPathUITests.testUnrecognizableImageOffersManualFallback`（CI 运行 5、6、7 均通过） |
| 扫描页关闭规则：识别成功 / 手动录入取消都回名片夹，识别失败且无表单时保留扫描页 | ✅ `ScannerDismissalTests`（4 例）；UI 端到端 ✅ `testCancellingAfterRecognitionLeavesNoCard`（CI 运行 5、6、7 均通过） |
| 相机权限拒绝 → 说明 + 替代入口 → 取消返回 | ✅ `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（CI 运行 5、6、7 均通过） |
| 识别成功但取消 → 不落库 | ✅ `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（CI 运行 5、6、7 均通过） |
| fixture 图像完整可解码 | ✅ `ExceptionPathUITests.testFixtureImagesAreDecodable`（CI 运行 5、6、7 均通过） |
| 相册取消、扫描中途退出、删除取消、空搜索 | 🔶 UI 路径存在但未逐项写成测试；相册取消 👤 人工清单 |

---

## 3. 人工验证清单（模拟器无法自动化的部分）

> 在真机或带相机的模拟设备上逐项打勾，记录设备与日期。结果写入本表，不在 CI 中假装通过。

| # | 场景 | 步骤 | 期望结果 | 结果 |
| --- | --- | --- | --- | --- |
| M1 | 首次相机权限请求 | 全新安装 → 扫描 → 拍照 | 弹出系统相机权限；允许后进入相机 | 待填写 |
| M2 | 拍摄标准名片（T04） | 对准 C01 纸面 → 快门 | 进入识别流程，字段基本正确 | 待填写 |
| M3 | 拍摄后「使用照片 / 重拍」与取消 | 拍摄 → 点「重拍」再拍 → 点「使用照片」；另一次拍摄 → 点「取消」 | 重拍回到系统取景；「使用照片」进入识别流程；取消不产生数据（App 内无复核页，见 `spec.md` §9-9） | 待填写 |
| M4 | 从相册导入（T05） | 相册选 C11_flat → 确认 | 进入识别流程；取消返回扫描页 | 待填写 |
| M5 | 相册权限拒绝 | 设置中关闭照片权限 → 导入 | 系统提示/受限选择器，不崩溃 | 待填写 |
| M6 | 权限拒绝后的「前往设置」 | 拒绝相机权限 → 扫描 → 前往设置 | 跳转系统设置页 | 待填写 |
| M7 | 倾斜名片实拍（T06） | 拍摄倾斜名片 | 自动检测并校正（或整图回退后仍识别） | 待填写 |
| M8 | 低光/模糊名片 | 模糊拍摄 | 识别失败提示 + 手动录入可进入 | 待填写 |
| M9 | VCF 导入联系人 App | 导出 → 存储到文件 → 用系统联系人打开 | 姓名/公司/职位/电话/Email/地址导入正确 | 待填写 |
| M10 | 真实日程中的 Kill → Relaunch | 编辑保存后从任务管理器杀掉 App | 重启后全部数据保持 | 待填写 |

---

## 4. 运行方式

```bash
# 1) 数据集校验（无第三方依赖，CI static job 也跑）
python3 scripts/verify_test_cards.py

# 2) 纯 Swift 校验（Windows / Linux；无需 Xcode）
swift test

# 3) iOS 模拟器全量测试（macOS + Xcode 16.4）
bash scripts/run-tests.sh          # 或 make test
```

- CI 的 `build-and-test`（macOS 15）先用 `simctl` 创建 iPhone SE 3rd gen / iOS 18.5 模拟器
  （规避镜像预置设备偶发未注册，`actions/runner-images#12948`），再运行 XCTest + XCUITest 全量。
- CI 的 `static`（Ubuntu）在 YAML 解析之后运行 actionlint，校验 GitHub Actions 表达式与语义
  （YAML 语法正确但表达式上下文非法时，workflow 会在启动 job 前被拒绝且没有日志，见运行 4）。
- UI 测试使用固定示例数据（`-seedSampleCards`）与合成名片注入（`-scanFixture`），不依赖网络与真实个人信息。
- 通过时 CI 上传 `ui-screenshots` 工件（UI 测试导出的页面截图，Week 6 截图对比的证据），
  本地 `scripts/run-tests.sh` 同样导出到 `build/ui-screenshots/`；
  `python3 scripts/verify_ui_screenshots.py <导出目录>` 校验截图数量、来源用例与尺寸；
  逐项对比见 [docs/ui-screenshot-comparison.md](ui-screenshot-comparison.md)。
- 失败时 CI 上传 `build/*.log`、`TestResults.xcresult` 与已导出的 `build/ui-screenshots`，可直接定位失败用例。
  运行 7、8、9 全绿时该步骤按 `if: failure()` 跳过，属预期行为。

---

## 5. 结果记录

| 日期 | 环境 | 命令 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-10-31 | Windows 11 / Swift 6.4.2 | `swift test` | 44/44 通过（32 + 12） | 不含 Vision/UIKit 用例 |
| 2026-11-01 | Windows 11 / Swift 6.4.2 | `swift test` | 48/48 通过（32 + 4 + 12） | 新增 `ScannerDismissalTests` |
| 2026-11-01 | Windows 11 / Swift 6.4.2（`SDKROOT` 指向 Windows.sdk） | `swift test` | 51/51 通过（39 + 12） | 新增 3 例 OCR 粘连标签单测（§2.14） |
| 2026-11-01 | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 1](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229496692)） | ✅ 通过 | YAML / 数据集 41 张 / 164 图像 / py_compile |
| 2026-11-01 | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd） | CI `build-and-test`（[运行 1](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229496692)） | ❌ `build-for-testing` 失败（4 个编译错误） | 修复提交 `96ab470`；第二轮待运行 |
| 2026-10-31 | Windows 11 / Python 3.x | `python scripts/verify_test_cards.py` | 通过（41 张 / 164 图像） | 数据集一致性 |
| 2026-11-01 | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 2](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)） | ✅ 通过 | 编译修复提交 `96ab470` |
| 2026-11-01 | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 2](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)） | 🔶 XCTest 42+12 通过；XCUITest 7/12 通过（5 例失败） | 失败原因：XCUITest 点击工具栏菜单的 AX scroll-to-visible 错误（非功能缺陷）；修复见 `ai-collaboration-log.md` §2.11，等待重跑 |
| 2026-11-01 | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 3](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231201327)） | ✅ 通过 | 提交 `e4c805c` |
| 2026-11-01 | GitHub Actions（macOS 15 / Xcode 16.4） | CI `build-and-test`（[运行 3](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231201327)） | ❌ `build-for-testing` 失败（环境，未编译） | 镜像未注册预置模拟器，报找不到 iPhone SE / iOS 18.5 目的地；运行 1、2 同镜像正常。修复：CI 用 `simctl` 显式创建模拟器并按 UDID 选取（`ai-collaboration-log.md` §2.12），等待重跑 |
| 2026-11-01 | GitHub Actions | CI 全部 job（[运行 4](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41231848508)） | ❌ 未启动任何 job | job 名称使用 `${{ env.* }}`，GitHub 在接受 workflow 时拒绝（job 数 0）。本地 actionlint 复现；修复见 `ai-collaboration-log.md` §2.13（static job 现含 actionlint） |
| 2026-11-01 | 同上 | 同上（`VisionAccuracyTests` / `ocr-accuracy-report`） | 待运行 | 运行 2 提交不含 B 层步骤；运行 3 构建前失败；运行 4 未启动 job |
| 2026-11-01 | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 5](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41232174313)） | ✅ 通过（全部步骤） | 提交 `016e0e8`；API 记为 11 条步骤记录：Set up job + 7 个检查步骤 + Post setup-python / Post checkout / Complete job |
| 2026-11-01 | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 5](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41232174313)） | 🔶 XCTest 42+12 通过；XCUITest 10/13 通过（3 例失败）；B 层 40/40 | 失败为编辑类 2 例（输入框重选文本）与标签 1 例（首屏之下未滚动）；修复见 `ai-collaboration-log.md` §2.14，待运行 6 |
| 2026-11-01（工件时间 2026-10-31T19:09Z） | 同上（模拟器 iPhone14,6 / iOS 18.5 22F77） | `VisionAccuracyTests`（B 层） | ✅ 字段级 427/440 = 97.0%；召回 235/248 = 94.8%；缺失精度 192/192；虚构 0；名片级全对 29/40 | 工件 `ocr-accuracy-report`；错误分析见 `docs/ocr-accuracy.md` §5.3 |
| 2026-11-01（运行时间 2026-10-31T19:26Z） | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 6](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)） | ✅ 通过（全部步骤） | 提交 `08c1730`；与运行 8 同一 static job 定义 |
| 2026-11-01（运行时间 2026-10-31T19:26Z） | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 6](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)） | 🔶 XCTest 45+12 通过；XCUITest 11/13 通过（名片夹 6/8）；B 层 40/40 | 标签用例已通过；两例编辑用例因键入前等待 App 空闲超时失败（§2.16），待运行 7 |
| 2026-11-01（工件时间 2026-10-31T19:46Z） | 同上（模拟器 iPhone14,6 / iOS 18.5 22F77） | `VisionAccuracyTests`（B 层，[运行 6](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41234214941)） | ✅ 字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；名片级全对 31/40 = 77.5% | C02/C03 解析粘连已消除；工件 `ocr-accuracy-report`；明细见 `docs/ocr-accuracy.md` §5.4 |
| 2026-11-01（运行时间 2026-11-01T06:13Z） | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)） | ✅ 通过（全部步骤） | 提交 `c499448`；API 记为 11 条步骤记录（同运行 8） |
| 2026-11-01（运行时间 2026-11-01T06:13Z） | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)） | ✅ XCTest 45 + 12 通过；XCUITest 13/13 通过；B 层 40/40 | 首次全绿：两例编辑用例通过（28.750 s / 24.658 s），截图导出 7 张；`ui-screenshots` 工件已上传 |
| 2026-11-01（工件时间 2026-11-01T06:26Z） | 同上（模拟器 iPhone14,6 / iOS 18.5 22F77） | `VisionAccuracyTests`（B 层，[运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)） | ✅ 字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；名片级全对 31/40 = 77.5% | 51.344 s；逐卡结果与运行 6 完全一致（40/40 张的 OCR 原文与字段判定相同）；明细见 `docs/ocr-accuracy.md` §5.5 |
| 2026-11-01（运行时间 2026-11-01T06:40Z） | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 8](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)） | ✅ 通过（全部步骤） | 提交 `e28da4b`；06:40:52Z–06:41:01Z；含 actionlint 与新脚本 `verify_ui_screenshots.py` 的 py_compile |
| 2026-11-01（运行时间 2026-11-01T06:40Z） | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 8](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)） | ✅ XCTest 45 + 12 通过；XCUITest 13/13 通过（288.092 s）；B 层 40/40 | Week 6 文档批次的独立回归，结论 success；截图导出 7 张并上传 `ui-screenshots`（467 054 B）；逐例耗时见 §1 |
| 2026-11-01（工件时间 2026-11-01T06:54Z） | 同上（模拟器 CamCardClone-CI / iOS 18.5） | `VisionAccuracyTests`（B 层，[运行 8](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)） | ✅ 字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；名片级全对 31/40 = 77.5% | 39.442 s；`ocr-accuracy-report` 与运行 7 逐字节相同（仅生成时间行不同） |
| 2026-11-01 | Windows 11 / Python 3.9 + PyYAML | `python scripts/verify_ui_screenshots.py .tools/ci/run8/ui-screenshots` | ✅ 通过（7 张齐全，来源用例与尺寸符合清单，exit 0） | 用运行 8 的真实导出工件验证；CI 的导出步骤内置校验同样逐张 `[通过]`（S01–S07）；运行 7 的同一校验见下一行 |
| 2026-11-01 | Windows 11 / Python 3.9 + PyYAML | `python scripts/verify_ui_screenshots.py .tools/ci/run7-artifacts/ui-screenshots` | ✅ 通过（7 张，来源用例与尺寸符合清单） | 用运行 7 的真实导出工件验证；脚本见 `scripts/verify_ui_screenshots.py` |
| 2026-11-01（运行时间 2026-11-01T07:03Z） | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 9](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)） | ✅ 通过（全部步骤） | 提交 `e24f864`；07:03:17Z–07:03:24Z；API 记为 11 条步骤记录（Complete job 为第 17 号步骤）；数据集 41 张 / 164 图像校验通过 |
| 2026-11-01（运行时间 2026-11-01T07:03Z） | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 9](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)） | ✅ XCTest 45 + 12 通过；XCUITest 13/13 通过（204.497 s）；B 层 40/40 | 纯文档增量回归，结论 success；截图导出 7 张并上传 `ui-screenshots`（480 239 B）；逐例耗时见 §1 |
| 2026-11-01（工件时间 2026-11-01T07:10Z） | 同上（模拟器 CamCardClone-CI / iOS 18.5） | `VisionAccuracyTests`（B 层，[运行 9](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)） | ✅ 字段级 429/440 = 97.5%；召回 237/248 = 95.6%；缺失精度 192/192；虚构 0；名片级全对 31/40 = 77.5% | 30.892 s；`ocr-accuracy-report` 与运行 7 的差异只有 `generatedAt`（152 940 B） |

> 原则：本表只写真实运行过的结果。未运行的一律写「待运行」，不用「预计通过」代替。
