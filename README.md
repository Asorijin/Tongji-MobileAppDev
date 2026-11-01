# 移动应用开发课程作业：CamCard 功能切片黑盒复刻

> 课程作业仓库：SDD（Specification-Driven Development）+ TRAE 的 AI-Native 移动应用工程实践。
> 复刻对象：**名片全能王（CamCard）** 的「名片数字化与联系人管理」完整闭环。
> 本仓库同时是最终代码仓库、测试仓库与开发记录仓库。

## 一句话说明

把一张名片从「图像」变成「可搜索、可编辑、可导出、重启不丢」的结构化联系人：
扫描 → 区域检测/透视校正 → OCR → 字段结构化 → 人工确认 → 保存 → 详情/编辑/搜索/标签 → 持久化 → 导出 VCF。

## 技术栈与约束

| 项目 | 选择 | 原因 |
| --- | --- | --- |
| UI | SwiftUI（iOS 16.0+） | 课程要求移动应用，SwiftUI 便于用 Accessibility Identifier 做 UI 测试 |
| OCR | Apple Vision（`VNRecognizeTextRequest`，zh-Hans + en-US） | 端上离线、零调用费用、无第三方登录 |
| 区域检测/校正 | Vision `VNDetectRectanglesRequest` + Core Image `CIPerspectiveCorrection` | 系统框架，稳定可测试 |
| 持久化 | JSON 原子写 + 应用沙盒图像存储 | 可单元测试、无外部依赖 |
| 导出 | vCard 3.0（VCF）文件 + 系统分享面板 | 作业允许「保存到联系人 或 导出 VCF」，VCF 可在模拟器上完整自动化验证 |
| 工程生成 | XcodeGen（`project.yml`） | 工程文件可读、可 diff，避免 `.pbxproj` 冲突 |
| CI | GitHub Actions：macOS 15 + Xcode 16.4 + iPhone SE (3rd generation) / iOS 18.5 | 公开仓库免费额度；镜像默认 Xcode，无需切换；SE 模拟器最轻量 |
| 本地纯 Swift 校验 | Swift 6.4.2 + Windows（`swift test`），同一份源码 | 领域层/解析器/导出/存储不依赖 UIKit，可在没有 Mac 的机器上先跑通 |

## 目录结构

```text
.
├── CamCardClone/               # iOS App 源码（MVVM + 分层）
│   ├── App/                    # 入口、AppEnvironment、启动参数（UI 测试注入）
│   ├── Data/                   # CardStore（JSON 持久化）、ImageStore
│   ├── Domain/                 # BusinessCard / ParsedContactFields / 解析器 / 文本清洗
│   ├── Features/               # CardList / Scanner / CardDetail / CardEdit / Tags
│   ├── Services/               # Vision OCR、图像校正、VCardExporter
│   └── UI/                     # FlowLayout 等通用视图
├── CamCardCloneTests/          # XCTest：解析器 26 例 + 数据集 3 例 + 导出 6 例 + 扫描规则 4 例 + Vision/校正（模拟器）+ B 层准确率报告（模拟器）
├── CamCardCloneUITests/        # XCUITest：名片夹主路径（T01/T13–T19）、异常路径（T20）、权限（T03）、识别→确认→保存/取消
├── CamCardDataTests/           # 数据层 12 例（增删改查/搜索/标签/持久化/图片）
├── docs/
│   ├── spec.md                 # 规格书（页面、状态、流程、字段规则、验收）
│   ├── observer-log.md         # 黑盒观察记录（参考版本、环境、状态清单、待核对项）
│   ├── test-suite.md           # Reference Test Suite T01–T20
│   ├── data-model.md           # BusinessCard Schema 与 vCard 映射
│   ├── ai-collaboration-log.md # 与 TRAE 的增量协作记录（Prompt / 修改 / 回归）
│   ├── ocr-accuracy.md         # OCR/字段准确率评价方法（结果见 CI 报告）
│   └── test-cards/             # 41 张合成名片 + Ground Truth + 生成/校验脚本说明
├── scripts/
│   ├── make_test_cards.py      # 生成合成名片与 Ground Truth（本地一次完成）
│   ├── verify_test_cards.py    # 数据集静态校验（CI 与本地共用）
│   └── run-tests.sh            # 与 CI 一致的本地测试入口
├── Package.swift               # 纯 Swift 校验包（Domain/Export/Data，Windows 可跑）
├── project.yml                 # XcodeGen 工程定义
└── .github/workflows/ci.yml    # 静态检查 + iOS 构建与测试
```

## 本地运行

### 有 macOS + Xcode 16.4

```bash
brew install xcodegen          # 或使用本机自备的 XcodeGen 2.46.0（与 CI 相同）
make test                      # 数据集校验 + build-for-testing + 全部 XCTest/XCUITest + B 层准确率报告
make verify                    # 同上，但从 build/ 清空开始（等价 CI）
```

模拟器为 iPhone SE (3rd generation) / iOS 18.5；无需签名（`CODE_SIGNING_ALLOWED=NO`）。
B 层报告输出到 `build/ocr-accuracy-report.md` / `.json`（逐张原始 OCR 文本、解析字段、判定与汇总）。

### 只有 Windows / Linux（无 Xcode）

```bash
swift test                     # 领域层解析器 + 导出 + 扫描规则 + 数据层（39 + 12 = 51 例）
python scripts/verify_test_cards.py
```

> 说明：`Package.swift` 仅用于本地纯 Swift 校验，同一份源码也在 Xcode 工程中编译；
> Vision / UIKit 相关用例在非 Apple 平台上编译为空，由 CI 在 iOS 模拟器上执行。
> Windows 上运行 `swift test` 需要设置 `SDKROOT` 指向 Swift 的 `Windows.sdk`（否则找不到标准库）。
> 本机当前没有 macOS / Xcode，模拟器全量测试由 GitHub Actions 完成，运行记录见
> [docs/test-suite.md](docs/test-suite.md) §5 与 [docs/ai-collaboration-log.md](docs/ai-collaboration-log.md) §8。

## CI

- `static`（Ubuntu）：workflow YAML 语法、actionlint 语义检查（GitHub Actions 表达式与上下文）、
  数据集完整性（41 张 × 4 变体、Ground Truth 契约）、Python 脚本可解析。
- `build-and-test`（macOS 15）：`simctl` 创建 iPhone SE (3rd generation) / iOS 18.5 模拟器（规避镜像预置设备偶发未注册，
  `actions/runner-images#12948`）→ XcodeGen 生成工程 → `build-for-testing` → `test-without-building`（按模拟器 UDID 选取目标）。
- B 层准确率报告：单独以 `-only-testing:CamCardCloneTests/VisionAccuracyTests` 运行（复用同一构建产物），
  汇总写入 Job Summary，完整 Markdown/JSON 作为 `ocr-accuracy-report` 工件保留 30 天。
- 失败时上传 `build/*.log` 与 `.xcresult`；同一分支新推送自动取消旧运行。

## 测试与数据

- **Reference Test Suite T01–T20**：见 [docs/test-suite.md](docs/test-suite.md)，确定性场景要求 100% 通过。
- **合成名片数据集**：41 张（40 张参与字段准确率 + 1 张空白异常卡），164 张图像（每张 4 个拍摄变体），
  全部为虚构数据（`example.com` / `555` / `138 0000` 号段）。见 [docs/test-cards/README.md](docs/test-cards/README.md)。
- **AI 边界**：解析器只为「名片上确实存在」的字段赋值；无法确认的字段保持 `nil` / 空数组，
  绝不根据语义补全。见 [docs/spec.md §8](docs/spec.md)。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [spec.md](docs/spec.md) | 复刻范围、页面与状态、交互流程、字段规则、异常与验收标准 |
| [observer-log.md](docs/observer-log.md) | 参考环境锁定、观察记录、规格假设与待核对项 |
| [test-suite.md](docs/test-suite.md) | T01–T20 场景 → 测试实现的对应关系 |
| [data-model.md](docs/data-model.md) | BusinessCard 字段、电话展示格式契约、vCard 映射 |
| [ai-collaboration-log.md](docs/ai-collaboration-log.md) | 增量 Prompt、AI 修改范围、人工验证与回归结果 |
| [ocr-accuracy.md](docs/ocr-accuracy.md) | 准确率指标定义、评价流程、结果记录方式 |
