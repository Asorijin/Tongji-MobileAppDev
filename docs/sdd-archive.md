# SDD 归档说明（Week 6）

> 作业 §18 要求 Week 6 完成「SDD 归档」。本文件是归档的总目录：说明按 SDD
> （Specification-Driven Development）流程产出的每一类工件**放在哪里、证明什么、如何复核**。
> 归档原则：只收录真实存在且可复查的内容；未完成项写在 §4，不伪装成已完成。

---

## 1. 归档快照

| 项目 | 值 |
| --- | --- |
| 归档时间 | 2026-11-01 |
| 代码基线 | commit `c499448`（CI 运行 7 全绿：[41279949458](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)）；此后 `CamCardClone/`、测试与 CI 定义零改动（`git diff c499448 e24f864`、`git diff e24f864 05c20f1`、`git diff 05c20f1 2827935` 与 `git diff 2827935 109dde4` 均不含代码路径） |
| 文档基线 | 本文件与 `docs/acceptance-report.md` 所在的提交；此前五次文档批次已分别由运行 8（[41281795449](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)，commit `e28da4b`）、运行 9（[41283224211](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)，commit `e24f864`）、运行 10（[41284584464](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)，commit `05c20f1`，2026-11-01T07:23:18Z–07:33:41Z）、运行 11（[41288191075](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075)，commit `2827935`，2026-11-01T08:16:44Z–08:28:43Z，按步骤时间；API 的 run 级时间晚 1 小时，见 `ai-collaboration-log.md` §2.21）与运行 12（[41292037678](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41292037678)，commit `109dde4`，2026-11-01T09:11:38Z–09:25:13Z，run 级与步骤时间一致）独立回归，均结论 success：XCTest 45 + 12、XCUITest 13/13（运行 11 为 222.892 s、运行 12 为 291.889 s）、B 层 429/440 且工件与运行 7 仅 `generatedAt` 不同；本批（§2.22）的回归结果在推送后按同样方式补记，在此之前不写结论 |
| 仓库 | `Asorijin/Tongji-MobileAppDev`（唯一代码仓库，开发、测试、记录同仓） |
| 确定性测试 | XCTest 45 + 12、XCUITest 13/13，全部真实通过 |
| 概率性测试 | B 层 40/40 张，字段级 429/440 = 97.5%，虚构 0 |

---

## 2. 工件目录（按 SDD 流程环节）

| 环节（SDD 闭环） | 工件 | 文件 | 状态 |
| --- | --- | --- | --- |
| 产品行为（观察） | 黑盒观察记录：页面清单、状态清单、识别流程、待核对项、参考环境锁定表 | `docs/observer-log.md` | 🔶 锁定表待观察者填写 |
| Specification | 规格书：复刻边界、页面/状态规格、字段规则、异常、验收映射、已知差距 | `docs/spec.md` | ✅ |
| Specification（数据契约） | BusinessCard Schema、电话展示格式、vCard 映射 | `docs/data-model.md` | ✅ |
| 测试数据集 | 41 张合成名片 + Ground Truth + 生成/校验脚本说明 | `docs/test-cards/` | ✅ |
| Architecture → Implementation | SwiftUI MVVM 分层：App / Data / Domain / Features / Services / UI | `CamCardClone/`、`project.yml` | ✅ |
| Test（确定性） | Reference Test Suite T01–T20、测试实现与真实运行记录 | `docs/test-suite.md`、`CamCardCloneTests/`、`CamCardDataTests/`、`CamCardCloneUITests/` | ✅ |
| Test（概率性） | 准确率评价方法、多轮复跑（运行 5→12）、11 处错误归因 | `docs/ocr-accuracy.md` | ✅ |
| UI 证据 | 运行 7 的 7 张截图 + manifest + 逐张核对；运行 7→8、8→9、9→10、10→11、11→12 逐像素差异实测 | `docs/ui-screenshots/`、`docs/ui-screenshot-comparison.md` | 🔶 无像素级基线（差异数据见该文件 §7.1–§7.5；S05 的整页抖动是离散状态，运行 7、8、11、12 逐像素一致、第 60 行以下零差异；S03 光标可见时 172–176 px） |
| Difference Analysis | 缺陷与差距记录：运行 5/6 失败归因与修复、规格偏差、能力边界 | `docs/ai-collaboration-log.md` §2、`docs/spec.md` §9 | ✅ |
| Revision → Regression | 每轮修复后全量回归的真实记录 | `docs/ai-collaboration-log.md` §6、§8 | ✅ |
| Acceptance | T01–T20 逐场景验收、六维一致性、人工清单 | `docs/acceptance-report.md` | 🔶 人工项待执行 |
| AI 协作记录 | 22 个增量：Prompt / 修改范围 / 验证 / 回归 | `docs/ai-collaboration-log.md` | ✅ |
| AI 能力边界 | 实测能力边界与限制 AI 的机制 | `docs/ai-collaboration-log.md` §5 | ✅ |
| 自动化 | CI（静态检查 + macOS 构建测试 + B 层 + 截图工件）、本地脚本 | `.github/workflows/ci.yml`、`scripts/`、`Makefile` | ✅ |

---

## 3. 时间线（作业 §18 的六周安排 → 归档位置）

| 周 | 作业要求 | 本项目产出（归档位置） |
| --- | --- | --- |
| Week 1 | 黑盒观察 + Specification + 数据集 + Reference Test Suite | `observer-log.md`、`spec.md`、`data-model.md`、`test-cards/`、`test-suite.md` |
| Week 2 | 架构 + UI + 数据模型 + 第一层单测 | 工程骨架（commit `ecb5056`）、`CardStore`、`CardListView`、`CardDetailView` |
| Week 3 | Camera + OCR + 原始结果 + 准确率评价 | `VisionOCRService`、`CardImageCorrector`、`ocr-accuracy.md`、B 层 CI 步骤 |
| Week 4 | 字段抽取 + HITL + 保存 | `BusinessCardFieldParser`、`CardEditView`、`FieldParserTests` |
| Week 5 | 管理 + 持久化 + 导出 + UI Golden Test | 搜索/标签/删除/持久化/VCF（`docs/ai-collaboration-log.md` §2.7）、Golden Test 现状见 `ui-screenshot-comparison.md` §7 |
| Week 6 | Acceptance + Regression + 归档 + 演示 | 本文件、`acceptance-report.md`、运行 7 全绿、运行 5→12 回归记录（运行 7 起连续全绿六次） |

---

## 4. 归档中未完成的事项（如实保留）

| # | 事项 | 原因 | 去向 |
| --- | --- | --- | --- |
| 1 | 参考环境锁定表（CamCard 版本 / iOS / 设备 / 语言 / 登录） | 需观察者在实机填写，当前环境不可得 | `observer-log.md` §1，`acceptance-report.md` §7.1 |
| 2 | 人工验证清单 M1–M10 | 需真机或带相机环境 | `test-suite.md` §3，`acceptance-report.md` §7 |
| 3 | 像素级 UI Golden Baseline | 需要固定参考帧与状态栏遮罩策略，Week 6 未实现 | `spec.md` §9-8，`ui-screenshot-comparison.md` §7 |
| 4 | 最终演示 | 尚未进行 | `acceptance-report.md` §8 |

以上四项在完成前不影响已归档的自动化证据，但**不把它们写成已完成**。

---

## 5. 如何复核本归档

```bash
# 1) 数据集与截图结构（纯静态，本仓库即可运行）
python3 scripts/verify_test_cards.py
python3 scripts/verify_ui_screenshots.py docs/ui-screenshots

# 2) 领域与数据层（Windows / Linux 无需 Xcode）
swift test                     # 51/51

# 3) 模拟器全量 + B 层 + 截图导出（macOS + Xcode 16.4）
bash scripts/run-tests.sh      # 或 make test
```

- CI 复核：打开 [运行 7](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41279949458)（验收基线）、
  [运行 8](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41281795449)、
  [运行 9](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41283224211)、
  [运行 10](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41284584464)、
  [运行 11](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41288191075) 与
  [运行 12](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41292037678)（五次文档批次的独立回归），
  逐个 job 核对步骤结论、测试摘要与工件（`ocr-accuracy-report`、`ui-screenshots`）；
- 文档复核：`docs/` 下每个数字都能追溯到运行链接或本地命令输出；未运行的项目一律写「待运行 / 待执行」。
