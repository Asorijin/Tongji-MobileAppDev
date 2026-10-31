# Reference Test Suite（T01–T20）

> 依据作业 §17：T01–T20 共 20 个场景。「确定性的 20 个 Reference Test Scenarios 必须 100% 通过」。
> 本文件把每个场景映射到**具体测试用例**，并如实标注无法在模拟器上自动化的部分（人工验证清单）。
> 代码位置：`CamCardCloneTests/`（单元测试）、`CamCardDataTests/`（数据层）、`CamCardCloneUITests/`（UI 测试）。

---

## 1. 验收状态总览

| 层 | 运行环境 | 用例数 | 状态 |
| --- | --- | --- | --- |
| 解析器单元测试（`FieldParserTests`） | 任意（Windows `swift test` / iOS 模拟器） | 23 | ✅ 本地已通过 |
| 数据集字段准确率（`FixtureParserTests`） | 任意 | 3 | ✅ 本地已通过 |
| vCard 导出（`VCardExporterTests`） | 任意 | 6 | ✅ 本地已通过 |
| 数据层（`CardStoreTests`） | 任意 / iOS 模拟器 | 12 | ✅ 本地已通过 |
| 扫描关闭规则（`ScannerDismissalTests`） | 任意 | 4 | ✅ 本地已通过 |
| OCR / 区域检测（`OCRServiceTests`、`ImageCorrectionTests`） | 仅 iOS 模拟器（Vision / UIKit） | 6 | ✅ CI 运行 2 真实通过（3 + 3） |
| OCR 端到端准确率（`VisionAccuracyTests`，B 层） | 仅 iOS 模拟器（Vision） | 1（40 张 × 11 字段） | ⏳ 等待 CI 专门步骤运行（运行 2 未包含） |
| UI 路径（`ExceptionPathUITests` + `CardListUITests`） | 仅 iOS 模拟器 | 5 + 8 | 🔶 运行 2：异常路径 4/4 + 保存用例待跑；名片夹 3/8（5 例因工具栏菜单的 AX 点击问题失败，修复后待重跑） |

本地 Windows 结果（2026-11-01）：`swift test` **48/48 通过**（领域 32 + 扫描关闭规则 4 + 数据 12）；
2026-10-31 基线为 44/44（当时尚无 `ScannerDismissalTests`）。
模拟器与 CI 结果以 GitHub Actions 运行记录为准，本文件只引用真实运行结果。

CI 运行 2（[41229690851](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)，commit `96ab470`）的真实结果：

- `static` ✅；`build-for-testing` ✅；
- XCTest：`CamCardCloneTests` 42/42（含 OCR/校正 6 例）、`CamCardDataTests` 12/12 ✅；
- XCUITest：`ExceptionPathUITests` 4/4 ✅；`CardListUITests` 3/8 —— 5 个失败全部发生在
  点击详情页工具栏菜单时（XCUITest AX scroll-to-visible 报 `kAXErrorCannotComplete`），
  不是被测功能失败；测试已改用坐标点击绕开（`docs/ai-collaboration-log.md` §2.11），等待重跑；
- 该提交不含 B 层 CI 步骤，准确率工件未生成。

覆盖率边界（诚实声明）：

- Vision/UIKit 相关用例在 Windows 上按平台条件编译为空（`#if canImport(UIKit)`），因此本地统计只覆盖 48 例；
  这 6 个 Vision/校正用例已在 CI 模拟器上真实通过，12 个 UI 用例中 7 个通过、5 个待修复后重跑。
- **无法在模拟器自动化**的场景：真实相机拍摄、系统照片库选择、系统权限弹窗、系统分享面板的最终落地动作。
  这些场景以「人工验证清单」（第 3 节）验收，自动化只覆盖其可测部分（如权限拒绝的界面分支）。

---

## 2. 场景 → 测试映射

约定：
- ✅ = 已在本地真实运行并通过（Windows `swift test` 或数据集校验）；
- ⏳ = 已写好自动化用例，但尚未在模拟器/CI 上真实运行过（首次运行后改为 ✅ 或修复）；
- 🔶 = 部分自动化（关键路径自动、人工补充）；
- 👤 = 人工验证。

### T01 — First Launch

| 断言 | 测试 |
| --- | --- |
| 首次启动进入名片夹；空状态提示与扫描/手动录入入口可见 | ✅ `CardListUITests.testFirstLaunchShowsEmptyState`（CI 运行 2 通过） |

### T02 — Enter Scanner

| 断言 | 测试 |
| --- | --- |
| 名片夹 → 扫描入口 → 进入扫描页（拍照/照片库入口、取消） | ✅ `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（CI 运行 2 通过，扫描页可见） |
| 规格偏差：进入的是「拍摄/导入选择页」，不是原生相机页 | 📄 见 `docs/spec.md` §4.2、§9 第 1 条；真机相机页由 §3 人工清单覆盖 |

### T03 — Permission

| 断言 | 测试 |
| --- | --- |
| 相机权限被拒 → 说明文字 + 照片库导入；不显示拍照按钮 | ✅ `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（CI 运行 2 通过） |
| 系统权限弹窗本身（首次请求） | 👤 人工清单 |

### T04 — Capture

| 断言 | 测试 |
| --- | --- |
| 拍摄 → 进入识别流程 | 👤 人工清单（模拟器无相机） |
| 识别流程本身（校正 → OCR → 确认表单项） | ✅ `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（CI 运行 2 通过，注入图像走同一识别链路） |

### T05 — Import

| 断言 | 测试 |
| --- | --- |
| 从相册导入 → 进入识别流程 | 👤 人工清单（系统照片选择器） |
| 照片库取消 | 👤 人工清单 |
| 导入图像的解码与校正 | ✅ `ImageCorrectionTests`（CI 运行 2，3/3）、`ExceptionPathUITests.testFixtureImagesAreDecodable`（CI 运行 2 通过） |

### T06 — Card Boundary Detection

| 断言 | 测试 |
| --- | --- |
| 倾斜名片（C03_tilt）能检测到名片四边形（非整图回退） | ✅ `ImageCorrectionTests.testDetectsTiltedCardQuad`（CI 运行 2 通过） |
| 模拟器支持的 UIKit 方向归一 | ✅ `ImageCorrectionTests.testOrientedImageIsNormalized`（CI 运行 2 通过） |
| 无法解码输入的错误处理 | ✅ `ImageCorrectionTests.testUnreadableDataThrows`（CI 运行 2 通过） |
| 在 UI 中「显示检测结果」 | 复刻实现不单独展示边界框（自动校正后直接识别），差距记录于 `docs/spec.md` §9 第 3 条 |

### T07 — OCR

| 断言 | 测试 |
| --- | --- |
| 合成中文名片（C01_flat）→ Vision 产生原始文本，包含「朱宏明」「同济大学」 | ✅ `OCRServiceTests.testVisionRecognizesSyntheticChineseCard`（CI 运行 2 通过） |
| OCR 文本流入解析器 → 姓名/公司/手机正确 | ✅ `OCRServiceTests.testRecognizedTextFlowsIntoParser`（CI 运行 2 通过） |
| 非图像数据 → 错误而非崩溃 | ✅ `OCRServiceTests.testUnreadableImageThrows`（CI 运行 2 通过） |

### T08 — Structured Extraction

| 断言 | 测试 |
| --- | --- |
| 中文/英文/中英双语名片字段分类 | ✅ `FieldParserTests`（23 例，含 C01/C03/C11/C21 样式的固定文本） |
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
| 确认表单可编辑全部字段；修改后保存落库 | 🔶 ⏳ `CardListUITests.testEditNameUpdatesListAndDetail`（编辑保存路径；CI 运行 2 因工具栏菜单点击问题失败，修复后待重跑）+ ✅ `CardStoreTests.testUpdateKeepsIdentityAndMovesValues` |
| 空字段保持为空、不误填 | ✅ `ExceptionPathUITests.testUnrecognizableImageOffersManualFallback`（CI 运行 2 通过） |
| 多值字段按行编辑并拆分 | 🔶 表单规则在 `CardEditView`（代码审查通过）；数据层多值断言 ✅ |
| 实际识别错误的逐项人工修改 | 👤 人工清单（Week 4 HITL 演示） |

### T12 — Save

| 断言 | 测试 |
| --- | --- |
| 写入逻辑：新名片插入顶部并持久化 | ✅ `CardStoreTests.testAddInsertsAtTopAndPersists` |
| 识别 → 确认表单 → 保存 → 返回名片夹 → 新名片出现 | ⏳ `ExceptionPathUITests.testSaveAfterRecognitionAddsCard`（`-scanFixture C01` 端到端；用例于 CI 运行 2 之后新增，等待下一轮运行） |
| 保存前取消不写入任何数据 | ✅ `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（CI 运行 2 通过，反向路径） |

### T13 — Detail

| 断言 | 测试 |
| --- | --- |
| 详情页正确显示全部保存字段（手机/办公/传真/邮箱/网址/地址/邮编/部门） | ✅ `CardListUITests.testDetailShowsAllSavedFields`（CI 运行 2 通过） |
| 空字段不显示 | ✅ 同上（示例名片无备注 → 无备注行） |

### T14 — Edit

| 断言 | 测试 |
| --- | --- |
| 编辑姓名 → 保存 → 详情与列表更新 | ⏳ `CardListUITests.testEditNameUpdatesListAndDetail`（CI 运行 2 因工具栏菜单点击问题失败，修复后待重跑） |
| 更新保持 id、替换字段、持久化 | ✅ `CardStoreTests.testUpdateKeepsIdentityAndMovesValues`、`testUpdateIgnoresUnknownCard` |

### T15 — Search

| 断言 | 测试 |
| --- | --- |
| 按姓名 / 公司 / 电话搜索并过滤 | ✅ `CardListUITests.testSearchByNameCompanyAndPhone`（CI 运行 2 通过） |
| 无结果提示；清空后恢复 | ✅ 同上 |
| 跨字段搜索（姓名/公司/职位/电话/邮箱/传真/地址/部门） | ✅ `CardStoreTests.testSearchAcrossNameCompanyTitlePhoneEmail` |
| 正则字符按字面量处理 | ✅ `CardStoreTests.testSearchTreatsRegexCharactersLiterally` |

### T16 — Tag

| 断言 | 测试 |
| --- | --- |
| 新建标签 → 添加到名片 → 按标签筛选 → 删除标签 | ⏳ `CardListUITests.testTagCreateFilterAndDelete`（CI 运行 2 因工具栏菜单点击问题失败，修复后待重跑） |
| 标签生命周期（去重、创建、删除解除关联） | ✅ `CardStoreTests.testTagLifecycle` |
| 标签与关联在重启后保持 | ✅ `CardStoreTests.testTagsAndCardsSurviveReload` |

### T17 — Delete

| 断言 | 测试 |
| --- | --- |
| 详情页删除（含确认弹窗）→ 列表不再出现 | ⏳ `CardListUITests.testDeleteFromDetailRemovesCard`（CI 运行 2 因工具栏菜单点击问题失败，修复后待重跑） |
| 删除同时清理图像文件 | ✅ `CardStoreTests.testDeleteRemovesCardAndItsImages` |
| 删除确认取消 | 👤 人工清单（Alert 取消按钮；自动化路径已覆盖确认后的结果） |

### T18 — Persistence

| 断言 | 测试 |
| --- | --- |
| 编辑保存 → Kill App → 重启 → 修改保持 | ⏳ `CardListUITests.testEditsSurviveRelaunch`（CI 运行 2 因工具栏菜单点击问题失败，修复后待重跑） |
| 存档重载（断言写盘→新实例读取） | ✅ `CardStoreTests.testStoreReloadsFromDisk` |
| 标签与关联重启后保持 | ✅ `CardStoreTests.testTagsAndCardsSurviveReload` |
| 损坏存档不崩溃 | ✅ `CardStoreTests.testCorruptedStoreFileIsIgnoredGracefully` |
| 图像相对路径可恢复 | ✅ `CardStoreTests.testImageStoreRelativePaths` |

### T19 — Export

| 断言 | 测试 |
| --- | --- |
| 详情 → 导出 → 系统分享面板出现 | ⏳ `CardListUITests.testExportOpensShareSheet`（CI 运行 2 因工具栏菜单点击问题失败，修复后待重跑） |
| 姓名/公司/职位/电话/Email/地址映射正确 | ✅ `VCardExporterTests.testCoreFieldsAreMapped` |
| 仅公司时 FN 兜底；特殊字符转义；NOTE 回退原文；空名片拒绝；批量导出 | ✅ `VCardExporterTests`（其余 5 例） |
| 在系统联系人 App 中导入 VCF 的结果 | 👤 人工清单（模拟器可「存储到文件」，不安装第三方通讯录） |

### T20 — Exception

| 断言 | 测试 |
| --- | --- |
| 空白名片 → 无法识别 → 手动录入 → 空表单不可保存 → 取消后仍为空 | ✅ `ExceptionPathUITests.testUnrecognizableImageOffersManualFallback`（CI 运行 2 通过） |
| 扫描页关闭规则：识别成功 / 手动录入取消都回名片夹，识别失败且无表单时保留扫描页 | ✅ `ScannerDismissalTests`（4 例）；UI 端到端 ✅ `testCancellingAfterRecognitionLeavesNoCard`（CI 运行 2） |
| 相机权限拒绝 → 说明 + 替代入口 → 取消返回 | ✅ `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（CI 运行 2 通过） |
| 识别成功但取消 → 不落库 | ✅ `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（CI 运行 2 通过） |
| fixture 图像完整可解码 | ✅ `ExceptionPathUITests.testFixtureImagesAreDecodable`（CI 运行 2 通过） |
| 相册取消、扫描中途退出、删除取消、空搜索 | 🔶 UI 路径存在但未逐项写成测试；相册取消 👤 人工清单 |

---

## 3. 人工验证清单（模拟器无法自动化的部分）

> 在真机或带相机的模拟设备上逐项打勾，记录设备与日期。结果写入本表，不在 CI 中假装通过。

| # | 场景 | 步骤 | 期望结果 | 结果 |
| --- | --- | --- | --- | --- |
| M1 | 首次相机权限请求 | 全新安装 → 扫描 → 拍照 | 弹出系统相机权限；允许后进入相机 | 待填写 |
| M2 | 拍摄标准名片（T04） | 对准 C01 纸面 → 快门 | 进入识别流程，字段基本正确 | 待填写 |
| M3 | 拍摄后重拍 / 取消 | 拍摄 → 重拍；再拍摄 → 取消 | 重拍回到取景；取消不产生数据 | 待填写 |
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

- CI 的 `build-and-test`（macOS 15 / iPhone SE 3rd gen / iOS 18.5）运行 XCTest + XCUITest 全量。
- UI 测试使用固定示例数据（`-seedSampleCards`）与合成名片注入（`-scanFixture`），不依赖网络与真实个人信息。
- 失败时 CI 上传 `build/*.log` 与 `TestResults.xcresult`，可直接定位失败用例。

---

## 5. 结果记录

| 日期 | 环境 | 命令 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-10-31 | Windows 11 / Swift 6.4.2 | `swift test` | 44/44 通过（32 + 12） | 不含 Vision/UIKit 用例 |
| 2026-11-01 | Windows 11 / Swift 6.4.2 | `swift test` | 48/48 通过（32 + 4 + 12） | 新增 `ScannerDismissalTests` |
| 2026-11-01 | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 1](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229496692)） | ✅ 通过 | YAML / 数据集 41 张 / 164 图像 / py_compile |
| 2026-11-01 | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd） | CI `build-and-test`（[运行 1](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229496692)） | ❌ `build-for-testing` 失败（4 个编译错误） | 修复提交 `96ab470`；第二轮待运行 |
| 2026-10-31 | Windows 11 / Python 3.x | `python scripts/verify_test_cards.py` | 通过（41 张 / 164 图像） | 数据集一致性 |
| 2026-11-01 | GitHub Actions（Ubuntu 24.04） | CI `static` job（[运行 2](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)） | ✅ 通过 | 编译修复提交 `96ab470` |
| 2026-11-01 | GitHub Actions（macOS 15 / Xcode 16.4 / iPhone SE 3rd / iOS 18.5） | CI `build-and-test`（[运行 2](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41229690851)） | 🔶 XCTest 42+12 通过；XCUITest 7/12 通过（5 例失败） | 失败原因：XCUITest 点击工具栏菜单的 AX scroll-to-visible 错误（非功能缺陷）；修复见 `ai-collaboration-log.md` §2.11，等待重跑 |
| 2026-11-01 | 同上 | 同上（`VisionAccuracyTests` / `ocr-accuracy-report`） | 待运行 | 运行 2 提交不含 B 层步骤 |

> 原则：本表只写真实运行过的结果。未运行的一律写「待运行」，不用「预计通过」代替。
