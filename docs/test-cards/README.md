# 合成名片测试数据集

本目录是课程的**统一测试数据集**：41 张合成名片、164 张图像与逐字段 Ground Truth。
全部姓名、公司、电话、邮箱均为虚构数据（`example.com` / `555` 号段 / `138 0000` 号段），
不含任何真实个人信息。

## 组成

| 分组 | 张数 | 说明 |
| --- | --- | --- |
| 中文名片 | 10（C01–C10） | 经典版式 / 侧栏 / 竖排 / 深色底 |
| 英文名片 | 10（C11–C20） | 纯英文、国际电话（+1 / +44） |
| 中英双语 | 6（C21–C26） | 中英文公司名、中英字段标签 |
| 竖版 / 特殊布局 | 4（C27–C30） | 竖排姓名、侧栏、深色底、+82 国际号码 |
| 多电话 / 多 Email | 4（C31–C34） | Mobile + Office + Fax 并存 |
| 字段缺失 | 4（C35–C38） | 无电话 / 无公司 / 无邮箱等 |
| 复杂 Logo / 背景 | 2（C39–C40） | Logo 字母与文字混杂、侧栏阅读顺序复杂 |
| 空白异常卡 | 1（C41） | 无任何文字，仅用于 T20「无法识别」 |
| **合计** | **41** | C01–C40 参与字段准确率评价；C41 不参与 |

每张名片生成 4 个**拍摄变体**，命名 `Cxx_{flat,tilt,rotate,shadow}.png`：

| 变体 | 尺寸 | 用途 |
| --- | --- | --- |
| `flat` | 1012×638 | 正面拍摄：OCR、字段解析、UI 测试注入 |
| `tilt` | 1012×723 | 透视变形 + 复杂桌面背景：T06 区域检测 |
| `rotate` | 1012×638 | 轻微旋转：方向校正 |
| `shadow` | 1012×759 | 阴影 + 浅色背景：区域检测鲁棒性 |

`flat` 变体同时打包进 Debug 版 App（`TestCardFixtures/`），供 UI 测试通过
`-scanFixture Cxx` 走完整识别链路（见 `docs/spec.md` 的测试注入说明）。

## 目录与文件

```text
docs/test-cards/
├── images/                  # 41 × 4 = 164 张 PNG
├── fixtures/
│   ├── Cxx.json             # 单张名片的版式文本、ocrText、Ground Truth、图像路径
│   └── _manifest.json       # 41 张名片的索引（id / kind / layout / images）
├── ground-truth.json        # 40 张准确率名片的字段汇总（C41 不在其中）
└── README.md
```

单张 fixture（以 C11 为例，节选）：

```json
{
  "id": "C11",
  "kind": "english",
  "layout": "english",
  "images": {
    "flat": "docs/test-cards/images/C11_flat.png",
    "tilt": "docs/test-cards/images/C11_tilt.png",
    "rotate": "docs/test-cards/images/C11_rotate.png",
    "shadow": "docs/test-cards/images/C11_shadow.png"
  },
  "layoutText": ["ABC Technologies Inc.", "David Chen", "Technical Director", "Mobile: +1 (555) 010-2233", "..."],
  "ocrText": "ABC Technologies Inc.\nDavid Chen\nTechnical Director\nMobile: +1 (555) 010-2233\n...",
  "groundTruth": {
    "name": "David Chen",
    "company": "ABC Technologies Inc.",
    "jobTitle": "Technical Director",
    "mobile": "+1 555 010 2233",
    "officePhone": "555 010 8899",
    "email": "david.chen@example.com",
    "address": "500 Market Street, San Francisco, CA"
  }
}
```

### 两种文本的区别（重要）

- `layoutText`：版式上**实际绘制**的文本行，按 Vision 的阅读顺序（上→下、左→右）排列。
- `ocrText`：`layoutText` 以换行连接，作为**确定性字段解析测试**的输入（模拟端上 OCR 的行序）。

`ocrText` **不是** Vision 的真实输出。真实 Vision 的识别结果与字段准确率在 iOS 模拟器上
单独测量（T07 / T20），评价方法见 [../ocr-accuracy.md](../ocr-accuracy.md)。这样可以把
「解析规则是否正确」（确定性）与「OCR 识别得准不准」（概率性）分开评价，符合作业对两类验收的划分。

## Ground Truth 约定

- 只记录名片上**确实存在**的字段；缺失字段不出现（对应 App 输出 `nil` / 空数组）。
- 电话统一为**展示格式**（与 App 的 `BusinessCardFieldParser.normalizePhone` 契约一致）：
  - `+86` 手机去掉国家码后 3-4-4：`+86 139 0000 0026` → `139 0000 0026`
  - `+86` 座机去掉国家码并补回 0 区号：`+86 (21) 6958 9000` → `021 6958 9000`
  - 其它国际号码按 3 位分组（10 位本地号按 3-3-4）：`+1 (555) 010-2233` → `+1 555 010 2233`
  - 无国家码：去括号、连字符改空格：`(555) 016-3321` → `555 016 3321`
- 电话类字段名：`mobile`（手机）、`officePhone`（办公座机）、`fax`（传真）。

完整 Schema 与 vCard 映射见 [../data-model.md](../data-model.md)。

## 重新生成与校验

```bash
# 生成（确定性：随机种子 20261031，重复运行输出逐字节一致）
python scripts/make_test_cards.py      # 需要 Pillow；字体取 Windows 自带微软雅黑/Arial

# 校验（无第三方依赖；CI 的 static job 也会运行）
python scripts/verify_test_cards.py
```

校验内容：

1. `_manifest.json` 与 41 个 fixture 一一对应；
2. 每张名片 4 个变体齐全，PNG 文件头合法、尺寸与约定一致（8 位 RGB）；
3. `ground-truth.json` 恰好覆盖 40 张准确率名片，且与 fixture 内 `groundTruth` 一致；
4. `ocrText` 与 `layoutText` 一致；C41 文本与 Ground Truth 均为空；
5. 电话字段均为归一化展示格式。

> 字体只用于本地生成图像，不随仓库分发；图像与 Ground Truth 直接提交到仓库，
> 因此 CI 与评审无需重新生成即可复核数据集。

## 已知限制

- 合成图像的字体、清晰度、版式均比真实名片规整，真实 Vision 识别率通常高于真实拍摄场景；
  本数据集用于**可重复的回归与定量评价**，不代表真实世界分布。
- `tilt` 变体把名片贴在合成的桌面上，Vision 矩形检测的结果需在模拟器上实测（T06），
  未检测到时 App 按规格回退到整图识别（见 `docs/spec.md` §7.3）。
- 竖排姓名的合并在「姓名 | 品牌 Logo | 姓名」这类版式上存在已知缺口，记录在
  `docs/spec.md` 的风险与限制一节。
