# 100% Acceptance 验收报告（T01–T20）

> 依据作业 §17：「确定性的 20 个 Reference Test Scenarios 必须 100% 通过」；Week 6 的目标不是
> 「功能已经有了」，而是「可以用规格和测试证明，这些功能真的按照要求工作」。
> 本报告把每个场景对应到**具体测试用例与真实运行证据**，并把**无法自动化的部分**如实列出。
>
> 证据基线：[CI 运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)
> （commit `c499448`，2026-11-01T06:13:31Z–06:26:39Z，结论 **success**）、
> 本地 `swift test` 51/51（2026-11-01）、人工验证清单 M1–M10（**未执行**，见 §7）；
> 其后的运行 8、9、10、11 为四次独立全绿回归（§6），确定性层与概率性层结果与基线一致。
> 本报告不给「通过」加任何前缀：要么有运行记录，要么写待执行。

---

## 1. 验收结论（先给结论，再给证据）

| 层 | 真实结果 | 证据 |
| --- | --- | --- |
| 确定性自动化测试（XCTest 45 + CamCardDataTests 12） | ✅ 57/57 通过 | 运行 7 `test-without-building` 步骤判定 success |
| 确定性自动化测试（XCUITest 13） | ✅ 13/13 通过（252.850 s） | 运行 7，逐例耗时见 `docs/test-suite.md` §1 |
| T01–T20 的**自动化可测部分** | ✅ 20 个场景的可自动化部分全部真实通过；真实相机/相册/权限弹窗/通讯录导入见 §7 | 本节 §2 |
| 概率性功能（OCR + 字段抽取） | ✅ 40/40 张完成识别，虚构 0；字段级 **429/440 = 97.5%** | 运行 7 B 层，`docs/ocr-accuracy.md` §5.5 |
| UI 截图对比 | 🔶 7 张截图 + 35 项目视核对（30 ✅ / 5 ⚠️ / 0 ❌）；**无像素级基线** | `docs/ui-screenshot-comparison.md` §7 |
| 人工验证清单 M1–M10（真实相机 / 相册 / 权限弹窗 / 通讯录导入） | 👤 **未执行** | 本报告 §7 |

**诚实边界**（对照作业 §4 的「100% 可观察行为等价」）：

1. 20 个场景的**自动化可测部分**在运行 7 中全部真实通过；T04 的拍摄动作与 T05 的系统照片选择器
   只能自动化到「图像已获得之后」的识别流程，拍摄与选图需人工（模拟器无相机，系统选择器不可控）。
   拍摄后的「使用照片 / 重拍」位于系统 `UIImagePickerController` 界面，App 内不设复核页，
   差距记录于 `docs/spec.md` §9-9。
2. 「100% 等价」的范围是**规格给定的功能边界与测试用例范围**（作业 §4），对照片是 `docs/spec.md`，
   **不是**与参考 App 的像素对比（参考 App 锁定表尚未填写，见 `docs/observer-log.md` §1）；
   本报告不写「与 CamCard 完全一致」这类未观察的说法。
3. 概率性部分不设「等同于 CamCard 的准确率」标准（作业 §5）：保存原始输出、对比 Ground Truth、
   计算字段级准确率、分析错误、允许人工校正均已具备；§5 要求的「与参考 App 的结果比较」
   在当前环境无法自动化，如实标为 🔶（见 §4）。

---

## 2. 逐场景验收表（T01–T20）

标记：✅ 真实运行通过；🔶 部分自动化 / 有受控边界；👤 人工清单待执行。

| # | 场景（作业 §17） | 测试用例 | 运行 7 证据 | 状态 |
| --- | --- | --- | --- | --- |
| T01 | First Launch：首次启动 → 名片夹 → 空状态 | `CardListUITests.testFirstLaunchShowsEmptyState` | 6.750 s ✅；截图 S01 | ✅ |
| T02 | Enter Scanner：名片夹 → 扫描 → 进入相机页 | `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance`（验证扫描页可达） | 9.755 s ✅ | 🔶 进入的是「拍摄/导入选择页」（规格偏差，`spec.md` §4.2 / §9-1） |
| T03 | Permission：允许/拒绝相机权限 → 行为符合规格 | 同上（拒绝分支自动化） | 9.755 s ✅；截图 S07 | 🔶 系统首次权限弹窗为 👤 M1 |
| T04 | Capture：拍摄标准名片 → 进入识别流程 | `ExceptionPathUITests.testCancellingAfterRecognitionLeavesNoCard`（注入图像走同一识别链路） | 10.227 s ✅ | 🔶 真实拍摄 👤 M2；「使用照片/重拍」在系统界面 👤 M3；App 内无复核页（`spec.md` §9-9） |
| T05 | Import：相册导入 → 进入识别流程 | `ImageCorrectionTests` 3 例 ✅ + `testFixtureImagesAreDecodable`（0.109 s） | ✅ | 🔶 系统照片选择器 👤 M4/M5；选图确认在系统界面（`spec.md` §9-9） |
| T06 | Card Boundary Detection：倾斜名片 → 识别并显示区域 | `ImageCorrectionTests.testDetectsTiltedCardQuad`、`testOrientedImageIsNormalized`、`testUnreadableDataThrows` | 3/3 ✅ | 🔶 边界框不在 UI 单独展示（自动校正，`spec.md` §9-3）；实拍 👤 M7 |
| T07 | OCR：标准测试名片 → 产生原始文本 | `OCRServiceTests` 3 例 + 运行 7 B 层 40/40 张 | 3/3 ✅；40/40 ✅ | ✅ |
| T08 | Structured Extraction：OCR → 字段正确分类 | `FieldParserTests` 26 例 + `FixtureParserTests.testAllFixturesMatchGroundTruth`（40 张） | 26/26 ✅；440/440 ✅ | ✅ |
| T09 | Missing Field：无 Website → 不得虚构 | `FieldParserTests.testMissingWebsiteIsNotFabricated`、`testExplicitAbsentLabelBlocksHeuristics` 等；B 层缺省精度 192/192 | ✅；虚构 0 | ✅ |
| T10 | Multiple Phones：Mobile / Office / Fax 分类 | `FieldParserTests.testMultiplePhonesCategorizedByLabel`、`testMultipleEmailsAllPreserved`；数据集 C31–C34 | ✅ | ✅ |
| T11 | Manual Correction：修改错误识别字段 → 保存修改 | `CardListUITests.testEditNameUpdatesListAndDetail`（28.750 s）+ `CardStoreTests.testUpdateKeepsIdentityAndMovesValues` | ✅ | 🔶 表单可编辑；逐项真实人工修改 👤（Week 4 HITL） |
| T12 | Save：确认 → 保存 → 返回名片夹 → 新名片出现 | `ExceptionPathUITests.testSaveAfterRecognitionAddsCard` + `CardStoreTests.testAddInsertsAtTopAndPersists` | 13.292 s ✅；截图 S05→S06 | ✅ |
| T13 | Detail：打开名片 → 显示全部保存字段 | `CardListUITests.testDetailShowsAllSavedFields` | 33.538 s ✅；截图 S02 | ✅ |
| T14 | Edit：编辑 → 保存 → 页面正确更新 | `testEditNameUpdatesListAndDetail`（28.750 s）+ `CardStoreTests` 2 例 | ✅ | ✅ |
| T15 | Search：姓名/公司 → 返回正确名片 | `CardListUITests.testSearchByNameCompanyAndPhone` + `CardStoreTests` 3 例 | 24.594 s ✅；截图 S03 | ✅ |
| T16 | Tag：加标签 → 筛选 → 返回正确结果 | `testTagCreateFilterAndDelete` + `CardStoreTests.testTagLifecycle`、`testTagsAndCardsSurviveReload` | 47.843 s ✅；截图 S04 | ✅ |
| T17 | Delete：删除 → 从列表消失 | `testDeleteFromDetailRemovesCard` + `CardStoreTests.testDeleteRemovesCardAndItsImages` | 27.384 s ✅ | ✅（删除确认弹窗的「取消」分支 👤） |
| T18 | Persistence：Kill → Relaunch → 修改保持 | `testEditsSurviveRelaunch` + `CardStoreTests.testStoreReloadsFromDisk`、`testCorruptedStoreFileIsIgnoredGracefully` | 24.658 s ✅ | ✅（真机任务管理器 👤 M10） |
| T19 | Export：导出 VCF → 字段映射正确 | `testExportOpensShareSheet` + `VCardExporterTests` 6 例 | 15.286 s ✅ | 🔶 分享面板出现已自动化；系统通讯录导入 👤 M9 |
| T20 | Exception：取消 / 返回 / 权限拒绝 / 无法识别 / 空字段 | `ExceptionPathUITests` 5 例 + `ScannerDismissalTests` 4 例 | 5/5 ✅；4/4 ✅ | 🔶 相册取消、扫描中途退出 👤 |

汇总：**20 个场景的自动化可测部分全部真实通过、0 个 ❌**；其中 12 个可判为 ✅，
8 个标为 🔶（T02/T03/T04/T05/T06/T11/T19/T20：缺口全部来自模拟器物理限制、系统控件
或需要真实人工操作的环节，其自动化部分同样在运行 7 通过）；人工清单 0/10 执行。

### 2.1 UI 测试逐例耗时（运行 7 真实数据）

| 套件 | 用例 | 耗时 |
| --- | --- | --- |
| CardListUITests | 8 例 | 合计 208.802 s（Delete 27.384 / Detail 33.538 / EditName 28.750 / EditsSurviveRelaunch 24.658 / Export 15.286 / FirstLaunch 6.750 / Search 24.594 / Tag 47.843） |
| ExceptionPathUITests | 5 例 | 合计 44.047 s（CameraPermissionDenied 9.755 / Cancelling 10.227 / FixtureImages 0.109 / SaveAfterRecognition 13.292 / Unrecognizable 10.665） |
| **合计** | **13 例** | **252.850 s** |

---

## 3. 六个一致性维度：证据与声明边界

作业 §4 把「100% 可观察行为等价」拆成六个维度。逐维度给出**证据来源**与**不能证明的部分**：

| 维度 | 证据 | 覆盖情况 | 声明边界 |
| --- | --- | --- | --- |
| **UI 一致性** | `docs/ui-screenshot-comparison.md` §5 逐张核对（35 项：30 ✅ / 5 ⚠️ / 0 ❌）；XCUITest 的 accessibility 断言 | 7 个关键页面（空状态、详情、搜索、标签筛选、确认表单、保存后列表、权限被拒） | 对照片是**本项目规格**，不是参考 App 截图；无像素级 Golden Baseline（`spec.md` §9-8） |
| **交互一致性** | 13 个 XCUITest 断言（点击/输入/滑动/菜单/分享面板/重启）；运行 7 全部通过 | 主路径 + 异常路径 | 断言的是元素存在、值变化与页面切换，**不是**动画与手势手感 |
| **状态一致性** | S01 空 → S06 非空；S04 筛选横幅；S07 权限被拒；`ScannerDismissalTests` 4 例规则 | 状态机各分支 | 空/有/筛选/失败/权限五种状态有直接证据；其余状态由断言间接证明 |
| **数据一致性** | S05「识别原文 ↔ 字段」逐字段一致；`CardStoreTests` 12 例（写入/重载/损坏存档/图片路径）；B 层逐卡原始 OCR 与解析结果入库 | 全链路 | 字段值与 Ground Truth 的比较仅针对 40 张合成名片 |
| **异常一致性** | `ExceptionPathUITests` 5 例 + `ScannerDismissalTests` 4 例 + `CardStoreTests` 损坏存档 + `ImageCorrectionTests.testUnreadableDataThrows` | 取消、无法识别、权限拒绝、空表单、坏文件 | 系统级异常（磁盘满、低内存）不在覆盖范围 |
| **流程一致性** | 扫描 → 识别 → 确认 → 保存 → 列表 → 详情 → 编辑 → 重启 → 导出，各环节均有端到端用例串起（T12/T13/T14/T18/T19） | 完整闭环 | T04/T05 的「拍摄/选图」一环由人工清单覆盖，自动化从「图像已获得」开始 |

**「100%」的声明方式**（与 `docs/spec.md` §1.3、作业 §4 一致）：

> 在本项目给定的功能边界（作业 §3、§7）、参考环境（作业 §6，观察者锁定表待填写）、
> 测试用例范围（T01–T20 + 41 张合成名片）内，确定性功能 100% 通过自动化测试；
> 概率性功能按 §5 的方法定量评价（97.5% 字段级准确率、虚构 0），不宣称与 CamCard 的识别结果逐字符相同。
> 模拟器无法覆盖的真实设备场景（§7 的 M1–M10）列为人工清单，在完成前不计入「已证明」。

---

## 4. 概率性功能的验收记录（作业 §5）

| 要求 | 完成情况 | 位置 |
| --- | --- | --- |
| 保存 AI/OCR 原始输出 | ✅ 每张名片的 `rawOCRText` + 置信度 + 包围盒 | B 层工件 `ocr-accuracy-report.json`；`rawOCRText` 随名片持久化 |
| 保存字段解析结果 | ✅ 逐卡 `parsed` 字段 | 同上 |
| 与 Ground Truth 比较 | ✅ 40 张 × 11 字段 = 440 项逐项比较 | `docs/ocr-accuracy.md` §3 |
| 计算字段级准确率 | ✅ 429/440 = 97.5%；召回 237/248 = 95.6%；缺省精度 192/192 | `docs/ocr-accuracy.md` §5.5 |
| 与参考 App 的结果比较 | 🔶 参考 App 在当前环境中无法自动化运行，比较以规格与 Ground Truth 为准 | 诚实缺口，不虚报 |
| 分析错误原因 | ✅ 11 处错误逐项归因（竖排姓名 5 处、字符误识 6 处） | `docs/ocr-accuracy.md` §5.4 |
| 允许人工校正 | ✅ 确认表单可编辑全部字段；编辑保存有端到端用例 | T11 / T14 |
| 不得编造（作业 §8） | ✅ 虚构字段 0、错位 0、可选字段误补 0 | 运行 7 B 层 |

---

## 5. Week 6 交付物对照（作业 §18）

| 交付物 | 状态 | 位置 |
| --- | --- | --- |
| Reference Test Suite（T01–T20） | ✅ 自动化部分全部真实通过 | `docs/test-suite.md`、本报告 §2 |
| 30–50 张名片统一测试 | ✅ 41 张（40 张评价 + 1 张空白卡），运行 7 B 层 40/40 | `docs/test-cards/`、`docs/ocr-accuracy.md` §5.5 |
| OCR 错误分析 | ✅ 11 处逐项归因 | `docs/ocr-accuracy.md` §5.3–§5.5 |
| Field Extraction 错误分析 | ✅ 解析粘连 2 处已修复（427→429）；其余为 OCR 侧 | `docs/ocr-accuracy.md` §4.4、§5.4 |
| UI 截图对比 | 🔶 7 张截图 + 35 项核对；像素级 Golden Test 未实现 | `docs/ui-screenshot-comparison.md` |
| Regression Test | ✅ 运行 5→6→7→8→9→10→11 七轮全量回归，每轮记录在案 | `docs/ai-collaboration-log.md` §6、§8 |
| 边界条件修复 | ✅ 运行 5 的三处（编辑输入、标签滚动、粘连标签）在运行 7 验证通过 | `docs/ai-collaboration-log.md` §2.14–§2.16 |
| SDD 归档 | ✅ 归档总目录（按观察→规格→实现→测试→差异→回归→验收组织） | `docs/sdd-archive.md` |
| AI 协作记录 | ✅ 21 个增量（§2.1–§2.21），逐个 Prompt / 修改 / 回归 | `docs/ai-collaboration-log.md` §2 |
| AI 能力边界分析 | ✅ 定性边界（§5.1–§5.3）+ 七项实测数字表（§5.4，均注明来源运行） | `docs/ai-collaboration-log.md` §5 |
| 最终演示 | 👤 未执行 | 计划：按本报告 §2 顺序现场演示 T01→T20 |

---

## 6. 回归测试结论

| 轮次 | 结论 | 关键变化 |
| --- | --- | --- |
| 运行 5（`016e0e8`） | ❌ UI 10/13、XCTest 42+12、B 层 427/440 | 发现 3 个 UI 失败与 2 处解析粘连 |
| 运行 6（`08c1730`） | ❌ UI 11/13、XCTest 45+12、B 层 429/440 | 标签滚动与解析粘连修复生效；编辑用例仍失败 |
| 运行 7（`c499448`） | ✅ **首次全绿**：UI 13/13、XCTest 45+12、B 层 429/440 且逐卡与运行 6 一致 | 输入方式替换生效；UI 截图 7 张入库 |
| 运行 8（`e28da4b`） | ✅ 全绿复现：UI 13/13（288.092 s）、XCTest 45+12、B 层 429/440 且 `ocr-accuracy-report` 与运行 7 逐字节相同 | Week 6 文档批次的独立回归（[41281795449](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)），证明纯文档增量未动摇任何结果 |
| 运行 9（`e24f864`） | ✅ 全绿复现：UI 13/13（204.497 s）、XCTest 45+12、B 层 429/440 且工件与运行 7 仅 `generatedAt` 不同 | §2.18 验收报告与 SDD 归档批次的独立回归（[41283224211](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)）；对比运行 8 截图，唯一的运行时差异是 S05 约 5 px 的模拟器排版抖动（内容一致，见 `docs/ui-screenshot-comparison.md` §7.2） |
| 运行 10（`05c20f1`） | ✅ 全绿复现：UI 13/13（321.292 s）、XCTest 45+12、B 层 429/440 且工件与运行 9 仅 `generatedAt` 不同 | §2.19 文档更正批次的独立回归（[41284584464](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)）；S05 相对运行 9 再下移约 6 px（相对运行 8 累计约 11 px），其余 6 张只有状态栏与光标差异（详见 `docs/ui-screenshot-comparison.md` §7.3） |
| 运行 11（`2827935`） | ✅ 全绿复现：UI 13/13（222.892 s）、XCTest 45+12、B 层 429/440 且工件与运行 10 仅 `generatedAt` 不同 | §2.20/§2.21 文档批次的独立回归（[41288191075](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075)）；S05 **回到运行 8 的基线**（第 60 行以下逐像素一致），S03 只有搜索框光标差异，其余 6 张只有状态栏时钟差异（详见 `docs/ui-screenshot-comparison.md` §7.4） |

回归原则：每轮只改测试辅助函数或单条解析规则，断言一条未放宽；B 层逐卡比对证明
识别链路未被触碰（`docs/ocr-accuracy.md` §5.5）。本报告的验收基线是运行 7；运行 8、9、10、11 是在其
之后的**四次独立回归**，确定性层与概率性层结果均与基线一致。截图逐像素对比显示：运行 7 → 8 的
差异只有状态栏时钟与搜索框光标这类时间性伪影；运行 8 → 9 另出现 S05 表单整体下移约 5 px、
运行 9 → 10 再下移约 6 px（相对运行 8 累计约 11 px）、运行 10 → 11 又回升 11 px **回到运行 8 的基线**
（第 60 行以下与运行 8 逐像素一致）——五次采样（运行 7、8、9、10、11）里 S05 的内容位置只有三种取值，
是**离散状态**而不是单调漂移（`docs/ui-screenshot-comparison.md` §7.3、§7.4）。
四次回归的提交之间 `CamCardClone/` 源码零改动（`git diff e28da4b e24f864`、`git diff e24f864 05c20f1`
与 `git diff 05c20f1 2827935` 均仅文档），因此该差异归因于模拟器排版，不归因于 App。

---

## 7. 人工验证清单（未执行，如实列出）

模拟器无法自动化的 10 项场景，需要真机或带相机环境。**当前状态：0/10 执行**，
完成前本报告不计入「已证明」。详细步骤与期望结果见 `docs/test-suite.md` §3。

| # | 场景 | 结果 |
| --- | --- | --- |
| M1 | 首次相机权限请求（系统弹窗） | 待执行 |
| M2 | 拍摄标准名片（T04） | 待执行 |
| M3 | 拍摄后「使用照片 / 重拍」与取消（系统界面上核对） | 待执行 |
| M4 | 从相册导入（T05） | 待执行 |
| M5 | 相册权限拒绝 | 待执行 |
| M6 | 权限拒绝后「前往设置」 | 待执行 |
| M7 | 倾斜名片实拍（T06） | 待执行 |
| M8 | 低光/模糊名片 | 待执行 |
| M9 | VCF 导入系统通讯录（T19 落地） | 待执行 |
| M10 | 真实任务管理器 Kill → Relaunch（T18） | 待执行 |

### 7.1 参考环境锁定表（阻塞项）

「与参考 App 等价」的前提是参考环境锁定（作业 §6）。`docs/observer-log.md` §1 的
CamCard 版本 / iOS / 设备 / 语言 / 登录状态**尚未填写**——这是 Week 6 剩下的最大缺口：
在锁定表签字前，本报告的「等效」仅相对本项目规格成立。

---

## 8. 待办（按优先级）

1. 👤 填写参考环境锁定表（`observer-log.md` §1），观察者实机核对；
2. 👤 在真机上完成 M1–M10，结果填回 `test-suite.md` §3 与本报告 §7；
3. 👤 最终演示（T01→T20 顺序），演示前重跑一次 CI 确认全绿；
4. 🔶（可选增强）为 7 个截图建立像素级 Golden Baseline，补上 `spec.md` §9-8 的差距。

SDD 存档总目录见 [sdd-archive.md](sdd-archive.md)。

---

> 本报告只写真实运行过的结果：运行链接可点开核对，用例名可在 `.xcresult` / 日志中检索，
> 人工项在完成前一律写「待执行」。
