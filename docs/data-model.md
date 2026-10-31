# 数据模型（BusinessCard Schema 与 vCard 映射）

> 实现：`CamCardClone/Domain/Models/BusinessCard.swift`、`ParsedContactFields.swift`、`Tag.swift`、
> `CamCardClone/Data/CardStore.swift`、`CamCardClone/Data/ImageStore.swift`、`CamCardClone/Services/Export/VCardExporter.swift`。
> 数据集 Ground Truth 的字段约定见 `docs/test-cards/README.md`。

---

## 1. 设计原则

1. **只记录名片上真实存在的信息**：空字段是 `nil` 或空数组，不用空字符串占位，不根据语义补全（作业 §8）。
2. **多值字段用数组**：真实名片常见多个手机、座机、传真、邮箱、网址。
3. **AI 证据链完整**：原始图像、校正图像、OCR 原始文本与结构化字段一起保存，便于复核与错误分析（作业 §5）。
4. **可序列化、可迁移**：JSON 只存相对路径；图像单独落盘，删除名片时一并清理。
5. **确定性**：同一条记录编码结果稳定（ISO8601 日期、`sortedKeys`），便于 diff 与回归。

---

## 2. BusinessCard

```swift
public struct BusinessCard: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String?          // 姓名
    public var company: String?       // 公司
    public var jobTitle: String?      // 职位
    public var department: String?    // 部门（可选）
    public var mobiles: [String]      // 手机（可多个）
    public var officePhones: [String] // 办公电话（可多个）
    public var faxes: [String]        // 传真（可多个，可选）
    public var emails: [String]       // 邮箱（可多个）
    public var websites: [String]     // 网址（可多个）
    public var address: String?       // 地址
    public var postalCode: String?    // 邮编（可选）
    public var notes: String?         // 备注（可选）
    public var tagIDs: [UUID]         // 关联标签

    public var originalImagePath: String?   // 原始图像，相对 store 目录
    public var processedImagePath: String?  // 校正后图像，相对 store 目录
    public var rawOCRText: String?          // OCR 原始文本（AI 输出证据）

    public var createdAt: Date
    public var updatedAt: Date
}
```

### 2.1 字段与作业 §7.5 的对应

| 作业字段 | 模型字段 | 必填 | 说明 |
| --- | --- | --- | --- |
| Name | `name` | 是 | |
| Company | `company` | 是 | |
| Job Title | `jobTitle` | 是 | |
| Mobile Phone | `mobiles` | 是 | 数组 |
| Office Phone | `officePhones` | 是 | 数组（解析器内部称 `phone`） |
| Email | `emails` | 是 | 数组 |
| Website | `websites` | 是 | 数组 |
| Address | `address` | 是 | |
| Department | `department` | 否 | |
| Fax | `faxes` | 否 | 数组 |
| Postal Code | `postalCode` | 否 | |
| Notes | `notes` | 否 | |
| Tags | `tagIDs` | — | 作业 §11 |
| — | `originalImagePath` / `processedImagePath` | 否 | 作业 §10 要求保存原图与处理图 |
| — | `rawOCRText` | 否 | 作业 §5 要求保留 AI 原始输出 |
| — | `createdAt` / `updatedAt` | 是 | 作业 §10 要求 `createdAt` |

「必填」指**字段必须被系统支持且必须尝试抽取**，不指名片上一定存在——缺失字段保持 `nil`/空数组。

### 2.2 派生属性

| 属性 | 规则 |
| --- | --- |
| `displayName` | 姓名 → 公司 → 第一个邮箱 → `"未命名名片"` |
| `displayInitials` | 中文取姓名（或公司）的第一个汉字；英文取前两个单词首字母（大写） |
| `allPhones` | `mobiles + officePhones + faxes` |
| `hasStructuredContent` | 任一文本字段非空，或任一数组非空（用于「空名片不可导出」） |

### 2.3 ParsedContactFields（解析中间结果）

```swift
public struct ParsedContactFields: Equatable {
    public var name, company, jobTitle, department, address, postalCode: String?
    public var mobiles, officePhones, faxes, emails, websites: [String]
    public var unclassifiedLines: [String]   // 无法归属的行，不展示、不入库为主要字段
}
```

- 解析器输出先进入该结构，**经人工确认表单后才转成 `BusinessCard`**（HITL）。
- `unclassifiedLines` 保留歧义行（如单独的 `Apple`），证明系统没有强行归类。
- 内部维护「已显式声明为空」的字段集合（`exhausted`，不参与编码），
  显式标签值为占位符（无 / 暂无 / n/a / - 等）时阻止后续启发式填充，落实「不得虚构」。

### 2.4 Tag

```swift
public struct Tag: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
}
```

- 新建时去首尾空白；名称大小写不敏感去重。
- 删除标签只解除与名片的关联，不删除名片。

---

## 3. 持久化布局

```text
Application Support/CamCardClone/
├── store.json          # { cards: [BusinessCard], tags: [Tag] }
└── images/
    ├── <cardUUID>-original.jpg
    └── <cardUUID>-processed.jpg
```

- **编码**：`JSONEncoder` + `dateEncodingStrategy = .iso8601` + `outputFormatting = [.sortedKeys]`。
- **写入**：`Data.write(options: .atomic)`——先写临时文件再原子替换，避免半写文件。
- **读取**：文件不存在或 JSON 损坏时按空存档处理，App 正常启动（T20）。
- **图像**：字段只存文件名（相对 `images/`，`ImageStore` 负责拼接），记录可整体迁移。
- 列表顺序即数组顺序：新增名片插入下标 0（最新在最上）；删除同时删除两张图像。

---

## 4. 电话展示格式契约

**同一份规则**同时存在于 Swift（`BusinessCardFieldParser.normalizePhone`）与 Python
（`scripts/make_test_cards.py` 的 `display_phone`，写入 Ground Truth），并由
`scripts/verify_test_cards.py` 校验数据集符合该格式；`CamCardCloneTests/FieldParserTests.swift`
的 `testInternationalPhoneDisplayContract` 断言 Swift 侧一致。

| 输入形态 | 规则 | 示例 |
| --- | --- | --- |
| `+86` 手机（11 位 `1` 开头） | 去掉国家码，3-4-4 分组 | `+86 139 0000 0026` → `139 0000 0026` |
| `+86` 座机 | 去掉国家码，补回前导 `0`，去括号 | `+86 (21) 6958 9000` → `021 6958 9000` |
| `0086` / `86` 前缀（超过 11 位） | 去掉前缀；11 位 `1` 开头按 3-4-4 | `86 13800000001` → `138 0000 0001` |
| 其它 `+` 国际码 | 去括号/连字符；国家码后分组：10 位本地号按 3-3-4，否则每 3 位一组 | `+1 (555) 010-2233` → `+1 555 010 2233` |
| 无国家码的 11 位 `1` 开头 | 3-4-4 | `13800000001` → `138 0000 0001` |
| 无国家码的其它号码（如区号+座机） | 去括号与 `-`，压缩空格 | `(021) 6598-1234` → `021 6598 1234` |

- 存储与导出使用**展示格式**；拨号时（详情页 `tel:`）再去除空格。
- `+1` 号码在 Ground Truth 中的示例：`+1 555 010 2233`；无国家码的示例：`555 010 8899`。

> 说明：`+86 021 6958 9000` 这种「国家码 + 带 0 区号」的写法按上表第二条处理时不会重复补 `0`。

---

## 5. vCard 映射（vCard 3.0，CRLF 换行）

| BusinessCard | vCard 行 | 备注 |
| --- | --- | --- |
| `name` | `N:<family>;<given>;;;` + `FN:<name>` | 姓名按空格拆分：**最后一个单词为姓**，其余为名（`David Chen` → `N:Chen;David;;;`） |
| `company`（无姓名时） | `FN:<company>` | 用公司名兜底显示名 |
| `company` | `ORG:<company>` | |
| `jobTitle` | `TITLE:<jobTitle>` | |
| `department` | `X-DEPARTMENT:<department>` | vCard 3.0 无标准部门字段，用 X- 扩展 |
| `mobiles[]` | `TEL;TYPE=CELL:<phone>` | 每个号码一行 |
| `officePhones[]` | `TEL;TYPE=WORK:<phone>` | |
| `faxes[]` | `TEL;TYPE=FAX:<fax>` | |
| `emails[]` | `EMAIL;TYPE=INTERNET:<email>` | |
| `websites[]` | `URL:<url>` | |
| `address` | `ADR;TYPE=WORK:;;<address>;;;;` | 地址整体放入「街道」字段（第 3 段），其余段为空 |
| `postalCode` | `X-POSTAL-CODE:<code>` | 3.0 无独立邮编行，用 X- 扩展 |
| `notes` | `NOTE:<notes>` | |
| `rawOCRText`（备注为空时） | `NOTE:<rawOCRText>`（换行→空格） | 保证 AI 原始输出可追溯 |
| 固定行 | `BEGIN:VCARD` / `VERSION:3.0` / `END:VCARD` | |

- **转义**（RFC 6350 / vCard 3.0）：`\` → `\\`，`;` → `\;`，`,` → `\,`，换行 → `\n`。
- **空名片**（`hasStructuredContent == false`）导出抛 `nothingToExport`，国际提示「名片没有任何可导出的字段」。
- **文件**：单张 `<displayName>.vcf`（文件名中的 `/` 替换为 `-`）；批量 `BusinessCards.vcf`（多张 VCARD 直接拼接）。
- 导出后通过系统分享面板（`UIActivityViewController`）交给用户，可「存储到文件」或交给系统联系人 App。

---

## 6. 确定性约束（测试相关）

| 约束 | 保证 |
| --- | --- |
| 同一 OCR 文本 → 同一 ParsedContactFields | `FieldParserTests.testParsingIsDeterministic`、`FixtureParserTests.testEveryFixtureParsesDeterministically` |
| 同一记录 → 同一 JSON 字节 | `.sortedKeys` + ISO8601；`CardStoreTests` 的 reload 用例 |
| 同一名片 → 同一 vCard 文本 | `VCardExporterTests` 6 例（映射、兜底、转义、NOTE 回退、空名片、批量） |
| 数据集格式一致 | Python 生成与 Swift 解析共享展示格式契约；`verify_test_cards.py` 在 CI static 阶段校验 |
