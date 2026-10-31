# 课程作业规格书（Specification）

> 依据：`移动应用开发课程作业-v2.docx`（§3 复刻流程、§5 概率性验收、§6 参考环境、§7 功能要求、§9–§13）、
> 对 CamCard 的黑盒观察记录（`docs/observer-log.md`）以及教师数据集（`docs/test-cards/`）。
> 本文件是开发的唯一依据：**先写规格，再改代码；规格变更必须同步测试。**

- 版本：v1.0（Week 1 定稿）
- 产品名：名片全能王（CamCard）功能切片复刻
- App 名：名片全能王复刻（`com.tongji.mobileappdev.camcardclone`）
- 平台：iOS 16.0+，iPhone 竖屏
- 参考环境：见 `docs/observer-log.md` 的「参考环境锁定」一节

---

## 1. 复刻边界

### 1.1 复刻对象

只复刻一个完整、封闭、可测试的核心业务切片：

```text
名片夹 / Home
   ↓
扫描名片
   ↓
拍摄 / 图片导入
   ↓
名片区域检测
   ↓
透视 / 方向校正
   ↓
OCR 文字识别
   ↓
联系人字段解析
   ↓
人工确认与修改
   ↓
保存名片
   ↓
名片夹
   ↓
搜索 / 标签 / 查看详情
   ↓
联系人导出
```

要求形成真正的 End-to-End Workflow，不接受「拍照 → OCR → 显示一段文字」的演示式实现。

### 1.2 明确不做的功能（作业 §15）

用户注册、会员、订阅支付、广告、云端账户同步、多设备同步、团队名片库、Salesforce/CRM 同步、
企业权限、数字名片设计与模板、QR 名片交换、Email Signature、Virtual Background、
AI 企业情报/公司分析/财务分析/商务建议、会议录音与总结、销售漏斗。

### 1.3 「100%」的定义（作业 §4）

在本规格给定的功能边界、参考环境与测试用例范围内，实现 **100% 可观察行为等价**；
不获取、不反编译、不复制 CamCard 的源码、内部模型、专有 OCR 算法与服务器端系统。

---

## 2. 两类功能的验收方式（作业 §5）

| 类别 | 包含 | 验收标准 |
| --- | --- | --- |
| **确定性** | UI、页面导航、状态转换、保存、编辑、删除、搜索、标签、导出 | Reference Test Suite（T01–T20 中的确定性部分）**100% 通过**，见 `docs/test-suite.md` |
| **概率性** | OCR、姓名/公司/职位/电话/Email/地址识别 | 用固定合成名片集 + Ground Truth 定量评价；保存原始 AI 输出与解析结果；计算字段级准确率；分析错误；允许人工校正。见 `docs/ocr-accuracy.md` |

约束：
- 概率性功能不要求 OCR 逐字符与 CamCard 相同，但**字段解析（OCR 文本 → 结构化字段）对本数据集必须 100% 正确**——
  同一输入永远得到同一输出（解析器是确定性规则引擎，不是模型）。
- AI（解析器）**不得编造名片上不存在的字段**，无法确认时返回 `nil` / 空数组（§8）。

---

## 3. 信息架构与页面清单

```text
名片夹（NavigationStack 根）
├── 搜索（.searchable，系统搜索栏）
├── 标签筛选横幅（选中标签时出现，可清除）
├── 名片列表 / 空状态
│   └── 名片详情（push）
│       ├── 编辑名片（sheet）
│       └── 分享面板（系统 UIActivityViewController，VCF 文件）
├── 扫描名片（sheet）
│   ├── 拍摄或导入选择页
│   ├── 相机 / 照片库（系统 UIImagePickerController）
│   ├── 识别进度浮层（校正 → OCR → 失败时可重试/手动录入）
│   └── 确认名片表单（sheet，保存后回到名片夹）
├── 手动录入（sheet，空状态与工具栏均可进入）
└── 标签管理（sheet：新建 / 选择筛选 / 滑动删除）
```

| 页面 | 文件 | 主要 Accessibility Identifier |
| --- | --- | --- |
| 名片夹 | `Features/CardList/CardListView.swift` | `card-list`、`card-row-<displayName>`、`scan-button`、`tags-button`、`empty-state-title`、`empty-state-scan`、`empty-state-manual`、`search-empty-title`、`clear-tag-filter` |
| 扫描名片 | `Features/Scanner/ScannerView.swift` | `scanner-cancel`、`scanner-camera`、`scanner-library`、`scanner-open-settings`、`camera-permission-denied`、`camera-unavailable`、`scan-stage-correcting`、`scan-stage-recognizing`、`scan-error`、`scan-manual-fallback` |
| 确认 / 编辑名片 | `Features/CardDetail/CardEditView.swift` | `raw-ocr-text`、`field-name|company|jobTitle|department|mobiles|officePhones|faxes|emails|websites|address|postalCode|notes`、`new-tag-field`、`add-tag-button`、`edit-cancel`、`edit-save` |
| 名片详情 | `Features/CardDetail/CardDetailView.swift` | `detail-menu`、`detail-name`、`detail-image`、`detail-mobile|office|fax|email|website|address|postalCode|department|notes` |
| 标签管理 | `Features/Tags/TagManagementView.swift` | `tag-name-field`、`tag-add`、`tag-row-<name>` |

> 无障碍标识符是 UI 测试（XCUITest）定位元素的契约；修改标识符等同于修改规格，必须同步测试。

---

## 4. 页面与状态规格

### 4.1 名片夹首页（T01 / T12 / T15 / T17）

- **空状态**：无任何名片时显示「名片夹为空」+ 说明 + 「扫描名片」「手动录入」两个入口。
- **列表**：每行显示姓名首字/首字母圆形头像、`displayName`、副标题（`职位 · 公司`，都为空时显示第一个电话）。
- 列表按保存时间**倒序**（最新名片在最上）。
- 导航栏：左「标签」、右「扫描名片」、标题「名片夹」；搜索框常驻。
- 新增或删除名片后列表即时更新。
- 滑动删除（行内）与详情页菜单删除（带确认弹窗）两种方式并存。

### 4.2 扫描名片（T02 / T03 / T04 / T05 / T06 / T20）

进入扫描页后的状态机：

| 状态 | 界面 | 说明 |
| --- | --- | --- |
| 选择页 | 「拍摄或导入一张名片」+ 拍照 / 从照片库导入 | 相机可用时的默认界面 |
| 权限被拒 | 说明文字 + 「前往设置」+ 照片库导入 | `camera-permission-denied` |
| 无相机 | 提示文字 + 照片库导入 | 模拟器默认状态 |
| 识别中 | 浮层：正在检测并校正名片区域 → 正在识别文字 | 不可重复触发 |
| 识别失败 | 错误信息 + 「重试」「手动录入」 | 失败不丢原图；手动录入打开空表单 |
| 识别完成 | 关闭浮层，弹出「确认名片」表单 | 原始文本与字段已填充 |
| 取消 | 返回名片夹，不产生任何数据 | `scanner-cancel` |

**规格偏差（已记录）**：T02 的描述是「正确进入相机页面」。本实现进入的是**拍摄/导入选择页**，
因为 iOS 模拟器无法提供真实的相机预览与系统相机界面自动化；选择页是复刻 CamCard
「扫描入口 → 来源选择」的可测试子集。真实相机与照片库由系统 `UIImagePickerController` 提供，
其行为需在真机上人工验证（见 `docs/test-suite.md` 的 T04/T05 说明）。

### 4.3 图像校正（§7.3）

1. 对输入图像做方向归一（`.up`）。
2. 用 `VNDetectRectanglesRequest` 检测名片四边形（`minimumConfidence 0.6`，宽高比 0.3–1.0）。
3. 检测到 → `CIPerspectiveCorrection` 裁剪+透视校正；未检测到 → **回退整图**继续识别（不阻断流程）。
4. 校正接口保留手动四角覆盖能力（`CardImageCorrector.correct(_:quad:)`），UI 暂不提供手动拖角；
   这是与 CamCard 的已知差距，记录于第 9 节。

测试数据覆盖：正面（flat）、倾斜+复杂桌面背景（tilt）、轻微旋转 4°（rotate）、阴影+浅色背景（shadow）。
规范要求的「深色背景 / 边缘部分遮挡」由深色版式名片与 tilt 的桌面遮挡近似覆盖。

### 4.4 OCR（§7.4）

- Apple Vision `VNRecognizeTextRequest`，accurate 模式，`usesLanguageCorrection = true`，
  语言 `zh-Hans` + `en-US`，`minimumTextHeight = 0.01`。
- 输出按 Vision 返回顺序拼接的行文本（`\n` 分隔），并保留每块的置信度与归一化包围盒（供错误分析）。
- 无任何文字 → 抛 `OCRError.emptyResult`，UI 显示「未能从名片中识别出文字，请重拍或手动录入」。
- **必须保留完整链路**：原始名片图像 → OCR 原始文本 → 结构化字段 → 人工校正 → 最终联系人。
  原始文本随名片保存（`rawOCRText`），确认表单顶部以「识别原文」展示。

### 4.5 字段结构化（§7.5 / §8）

必填字段（语义上必测，值可缺失）：姓名、公司、职位、手机、办公电话、Email、网址、地址。
可选字段：部门、传真、邮编、备注。另有未分类行列表（不展示，供分析与调试）。

解析器 `BusinessCardFieldParser` 三遍规则：

1. **强模式**：Email、网址、电话（按标签或号码形态归类：手机/座机/传真）。
2. **显式标签**：「姓名：」「公司：」「职位：」「地址：」「邮编：」「手机：」「电话：」「传真：」
   「邮箱：」「网址：」等，支持全角冒号与中英文标签；**标签值为空或为占位符**
   （无 / 暂无 / 没有 / n/a / na / none / null / - / --）时，该字段保持为空，
   **后续启发式不得再填**（这是「不得凭空产生 Website」的机制保障）。
3. **启发式**：职位关键词 → 部门 → 姓名 → 公司 → 地址；优先级从高到低，字段一旦分配不再被覆盖。
   - 竖排姓名碎片可跨「公司 / 部门 / 职位」行合并；
   - 2–5 个大写字母的纯字母行视为 Logo，不参与分类；
   - 歧义单行（如单独的 `Apple`）保留为未分类，不强行归入公司/姓名。

电话展示格式契约见 `docs/data-model.md` §4（与 `normalizePhone` 和数据集 Ground Truth 一致）。

### 4.6 人工确认与修改（§9，HITL）

- AI 结果**不能直接保存**：识别完成 → 弹出「确认名片」表单 → 用户检查/修改 → 保存。
- 可修改：姓名、公司、职位、部门、手机、办公电话、传真、Email、Website、地址、邮编、备注、标签。
- 多值字段（电话/传真/Email/网址）每行一个，保存时同时按 `\n` 与半角逗号拆分。
- 表头「取消」放弃全部修改不落库；「保存」在**所有字段均为空时禁用**（T20）。
- 识别失败时可「手动录入」：空白表单 + 已获得的原文（若有），保存时同样走完整流程。

### 4.7 保存与详情（§10）

保存内容：

```text
BusinessCard
 ├── originalImage      （相对路径，图像文件存储在沙盒 Application Support/CamCardClone/images）
 ├── processedImage     （校正后的图像；无校正时为原图）
 ├── name / company / jobTitle / department
 ├── mobiles / officePhones / faxes
 ├── emails / websites
 ├── address / postalCode / notes
 ├── tagIDs
 ├── rawOCRText
 └── createdAt / updatedAt
```

详情页支持：查看名片图像（有图像时）、查看全部已填字段、编辑、删除（确认弹窗）、返回、
电话 → `tel:`、Email → `mailto:`、Website → 浏览器链接。空字段不显示行。

### 4.8 搜索与标签（§11）

- 搜索范围：姓名、公司、职位、部门、地址、手机、办公电话、传真、Email（大小写不敏感的子串匹配，
  关键词按字面量处理，不解释正则）。空白关键词返回全部。
- 标签：新建（去空白、大小写不敏感去重）→ 给名片勾选 → 按标签筛选（横幅显示当前标签，可清除）→
  滑动删除标签（同时从所有名片移除该标签，名片保留）。
- 备注：确认表单/编辑表单中的备注字段，详情页展示。

### 4.9 持久化（§12）

- 数据文件：`Application Support/CamCardClone/store.json`（ISO8601 日期、排序键、原子写入）。
- 图像：`Application Support/CamCardClone/images/<uuid>-original.jpg`、`<uuid>-processed.jpg`。
- 损坏的 JSON 视为空存档（不崩溃），图片路径为相对路径（沙盒迁移安全）。
- 验收：扫描 → 识别 → 修改 → 保存 → Kill App → 重启 → 名片、修改后的字段、图像、标签、备注全部仍在。
- 删除名片时同时删除其图像文件。

### 4.10 联系人导出（§13）

- 实现方式：导出 vCard 3.0（`.vcf` 文件）→ 系统分享面板（可「存储到文件」「AirDrop」「拷贝」等），
  等价于「导出 VCF」选项；不实现 CRM/云同步。
- 映射：姓名→`FN`/`N`（仅有公司时 `FN` 用公司名）、公司→`ORG`、职位→`TITLE`、
  手机→`TEL;TYPE=CELL`、办公电话→`TEL;TYPE=WORK`、传真→`TEL;TYPE=FAX`、
  Email→`EMAIL;TYPE=INTERNET`、网址→`URL`、地址→`ADR;TYPE=WORK`、邮编→`X-POSTAL-CODE`、
  部门→`X-DEPARTMENT`、备注→`NOTE`（备注为空时用原始 OCR 文本，换行转空格）。
- 特殊字符转义 `\ ; ,` 与换行；文件名 `<displayName>.vcf`；内容为空时拒绝导出并提示。
- 逐字段映射与转义规则见 `docs/data-model.md` §5。

---

## 5. 异常与边界（T20）

| 场景 | 期望行为 |
| --- | --- |
| 相机权限拒绝 | 扫描页说明 + 前往设置 + 照片库导入；不静默失败 |
| 相册取消 | 回到选择页，不产生数据 |
| 扫描中取消 | 关闭扫描页，不产生数据 |
| 识别失败 | 显示错误 + 重试 / 手动录入；原图保留 |
| 空白名片（C41） | OCR 无文本 → 错误 → 手动录入 → 空表单不可保存 → 取消后名片夹仍为空 |
| 表单全空 | 保存按钮禁用 |
| 保存前取消 | 不写入任何数据 |
| 删除前取消 | 名片保留 |
| 删除后打开 | 不会发生（详情页随导航返回），若卡不存在显示「名片不存在」 |
| 存档损坏 | 视为空存档启动，不崩溃 |
| 搜索无结果 | 「没有匹配的名片」占位 |
| 无标签时筛选 | 不会发生（只有存在的标签可点）；删除当前筛选标签后筛选自动清除 |

---

## 6. 测试注入机制（仅 Debug，UI 测试用）

模拟器无法操作真实相机，也无法在每个用例里手动构造照片库图像。为此提供 Debug-only 启动参数：

| 参数 | 作用 |
| --- | --- |
| `-resetStore` | 启动前清空存档（Release 也生效，见 `CamCardCloneApp.makeForLaunch`） |
| `-seedSampleCards` | 存档为空时写入 3 张虚构示例名片（朱宏明 / 赵敏 / David Chen）与 2 个标签 |
| `-keepStore` | 与 `-seedSampleCards` 同用，保留已有存档，模拟 Kill → Relaunch |
| `-scanFixture Cxx` | 跳过相机，直接用 App 包内的合成名片图像走完整识别链路 |
| `-scanFixtureVariant flat|tilt|rotate|shadow` | 选择拍摄变体（默认 flat） |
| `-cameraAuthorization denied|authorized` | 模拟相机权限结果 |

- 全部为 Debug 构建与显式启动参数控制；Release 构建忽略（`#if DEBUG`）。
- 注入图像来自 `docs/test-cards/images/`，在 Debug 构建时由 `project.yml` 的构建脚本复制进
  `TestCardFixtures/`，不改动 App 的识别代码路径——注入的只是「一张照片」。
- 注入只自动发生一次：用户取消保存后再次进入扫描页，看到正常的选择页。

---

## 7. 验收映射（T01–T20）

详细到测试类与用例的对应关系见 `docs/test-suite.md`。摘要：

| 编号 | 场景 | 验收方式 |
| --- | --- | --- |
| T01 | 首次启动空状态 | UI 测试 `CardListUITests.testFirstLaunchShowsEmptyState` |
| T02 | 进入扫描 | UI 测试（选择页）+ 规格偏差说明 |
| T03 | 相机权限 | UI 测试 `ExceptionPathUITests.testCameraPermissionDeniedShowsGuidance` |
| T04 / T05 | 拍摄 / 导入 | 模拟器无法自动化，**人工验证清单** |
| T06 | 区域检测 | 单元测试 `ImageCorrectionTests.testDetectsTiltedCardQuad`（模拟器） |
| T07 | OCR | 单元测试 `OCRServiceTests`（模拟器，Vision 实际识别合成名片） |
| T08 | 字段结构化 | `FieldParserTests`（23 例）+ `FixtureParserTests`（40/40 字段准确率 100%） |
| T09 | 缺失字段 | `FieldParserTests.testMissingWebsiteIsNotFabricated` 等 |
| T10 | 多电话 | `FieldParserTests.testMultiplePhonesCategorizedByLabel` 等 |
| T11 | 人工校正 | 表单逻辑 + UI 路径（T12/T14 的保存路径覆盖修改后落库） |
| T12 | 保存 | UI 测试 + `CardStoreTests` + 识别→确认→保存端到端 UI 测试 |
| T13 | 详情 | UI 测试 `testDetailShowsAllSavedFields` |
| T14 | 编辑 | UI 测试 `testEditNameUpdatesListAndDetail` + 数据层测试 |
| T15 | 搜索 | UI 测试 `testSearchByNameCompanyAndPhone` + `testSearchAcross...` |
| T16 | 标签 | UI 测试 `testTagCreateFilterAndDelete` + `testTagLifecycle` |
| T17 | 删除 | UI 测试 `testDeleteFromDetailRemovesCard` + `testDeleteRemovesCardAndItsImages` |
| T18 | 持久化 | UI 测试 `testEditsSurviveRelaunch` + `testStoreReloadsFromDisk` |
| T19 | 导出 | UI 测试 `testExportOpensShareSheet` + `VCardExporterTests`（6 例映射/转义） |
| T20 | 异常 | `ExceptionPathUITests` 4 例 |

---

## 8. AI 能力边界（作业 §8）

1. **不编造**：解析器只为名片上真实出现的文本赋值；字段无法确认时返回 `nil`/空数组。
2. **不补全**：不会根据公司名推断网站、根据姓名推断邮箱、根据区号推断地址。
3. **有歧义就保留**：单行歧义文本（`Apple`、`Jordan Lee` vs `Lee Consulting`）按规则处理，
   无法归属的行进入未分类列表，由用户在确认表单中人工决定。
4. **保留证据**：原始 OCR 文本、置信度、包围盒、字段解析结果全部可追溯。
5. **概率性是可评价的**：对 40 张 Ground Truth 名片统计字段级准确率并对错误分类归因，
   见 `docs/ocr-accuracy.md`。

---

## 9. 已知差距、风险与限制

| # | 差距 / 限制 | 影响 | 处置 |
| --- | --- | --- | --- |
| 1 | T02 进入的是拍摄/导入选择页，而非原生相机预览页 | 与 T02 字面描述有一处偏差 | 规格偏差记录于 §4.2；真机人工验证相机与照片库 |
| 2 | 模拟器无法自动化真实拍摄、照片库选择、系统权限弹窗 | T04/T05 无法进入 CI | 人工验证清单 + 权限用启动参数模拟（T03） |
| 3 | 无手动拖拽四角校正 UI | §7.3「手动调整」仅接口就绪 | 记录差距，作为 Week 6 可选增强 |
| 4 | Vision 对合成图像的识别率高于真实拍摄（字体规整） | 准确率数字偏乐观 | 在 `docs/ocr-accuracy.md` 中明确声明适用边界 |
| 5 | 竖排姓名「姓名 | Logo | 姓名」版式的合并存在已知缺口 | 极端版式可能出现姓名不完整 | 保留原文本与人工校正通道；数据集 C27–C30 覆盖常见竖排情形 |
| 6 | 导出为 VCF 文件分享，而非直接写入系统通讯录 | §13 允许二者之一 | 选择可自动化验证的 VCF 方案 |
| 7 | 参考 App 版本、iOS、设备、语言、登录状态需由观察者填写锁定 | 不锁定则「等价」无从谈起 | `docs/observer-log.md` 留出锁定表待填写 |

---

## 10. 需求可追溯

| 规格 | 作业出处 | 实现 | 测试 |
| --- | --- | --- | --- |
| 名片夹首页 / 空状态 / 列表更新 | §7.1 | `CardListView` | `CardListUITests` T01/T12 |
| 拍摄 / 导入 / 权限 | §7.2 | `ScannerView`、`CameraPicker` | 人工 + T03 自动化 |
| 区域检测 / 透视 / 方向 | §7.3 | `CardImageCorrector` | `ImageCorrectionTests` |
| OCR + 原始输出保留 | §7.4 | `VisionOCRService`、`rawOCRText` | `OCRServiceTests` |
| 结构化字段 | §7.5 | `BusinessCardFieldParser` | `FieldParserTests`、`FixtureParserTests` |
| 人工确认 / 修改 | §9 | `CardEditView` | UI 测试 + 表单规则 |
| 保存 / 详情 | §10 | `CardStore`、`CardDetailView` | `CardStoreTests`、T13 UI |
| 搜索 / 标签 / 备注 | §11 | `CardStore.search`、`TagManagementView` | T15/T16 |
| 本地持久化 | §12 | `CardStore` 原子 JSON、`ImageStore` | `CardStoreTests`、T18 UI |
| 联系人导出 | §13 | `VCardExporter` | `VCardExporterTests`、T19 UI |
| AI 不编造 | §8 | 解析器占位符机制与未分类行 | `FieldParserTests` T09 |
