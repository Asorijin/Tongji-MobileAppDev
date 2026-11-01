#!/usr/bin/env python3
"""校验 Week 6「UI 截图对比」证据的完整性（结构校验，不做像素比对）。

输入目录来自 `xcrun xcresulttool export attachments`：

    build/ui-screenshots/
    ├── manifest.json
    └── <UUID>.png            # 原始导出；本地人工整理后也可能是 S01-*.png

检查项：

  1. manifest.json 恰好包含 7 个截图附件，S01–S07 各一张；
  2. 每张附件的来源测试用例与 docs/ui-screenshot-comparison.md 的清单一致；
  3. 每个附件文件存在、可解析为 PNG，尺寸为 750×1334（iPhone SE 3rd gen 竖屏）。

像素级 Golden 比对不在本脚本范围（见 docs/ui-screenshot-comparison.md §5 与 docs/spec.md §9）。

用法：

    python3 scripts/verify_ui_screenshots.py build/ui-screenshots

退出码：0 通过；1 不通过（缺截图 / 尺寸不符 / 来源用例变化）；2 用法错误。
"""

import json
import struct
import sys
from pathlib import Path

# S 编号 → (可读名称前缀, 产生该截图的测试用例, 期望尺寸)
EXPECTED = {
    "S01": ("S01-first-launch-empty", "CardListUITests/testFirstLaunchShowsEmptyState()", (750, 1334)),
    "S02": ("S02-card-detail", "CardListUITests/testDetailShowsAllSavedFields()", (750, 1334)),
    "S03": ("S03-search-company", "CardListUITests/testSearchByNameCompanyAndPhone()", (750, 1334)),
    "S04": ("S04-tag-filter", "CardListUITests/testTagCreateFilterAndDelete()", (750, 1334)),
    "S05": ("S05-confirm-form-c01", "ExceptionPathUITests/testSaveAfterRecognitionAddsCard()", (750, 1334)),
    "S06": ("S06-after-save-list", "ExceptionPathUITests/testSaveAfterRecognitionAddsCard()", (750, 1334)),
    "S07": ("S07-camera-permission-denied", "ExceptionPathUITests/testCameraPermissionDeniedShowsGuidance()", (750, 1334)),
}

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def png_size(path):
    """返回 (width, height)；不是有效 PNG 时返回 None。"""
    with open(path, "rb") as f:
        header = f.read(24)
    if len(header) < 24 or header[:8] != PNG_MAGIC or header[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", header[16:24])


def readable_stem(attachment):
    """从 suggestedHumanReadableName（`S01-..._0_<UUID>.png`）取可读名称。"""
    name = attachment.get("suggestedHumanReadableName") or ""
    return name.split("_0_")[0] if "_0_" in name else Path(name).stem


def resolve(base, attachment):
    """优先按 exportedFileName 找文件；本地重命名过的副本按可读名称前缀回退。"""
    exported = attachment.get("exportedFileName") or ""
    candidate = base / exported
    if exported and candidate.is_file():
        return candidate
    stem = readable_stem(attachment)
    matches = sorted(base.glob(stem + "*.png")) if stem else []
    return matches[0] if matches else None


def main(argv):
    if len(argv) != 2:
        print("用法：python3 scripts/verify_ui_screenshots.py <导出目录>", file=sys.stderr)
        return 2

    base = Path(argv[1])
    manifest_path = base / "manifest.json"
    if not manifest_path.is_file():
        print(f"[失败] 找不到 {manifest_path}（截图未导出？）")
        return 1

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    attachments = []
    for entry in manifest:
        for item in entry.get("attachments", []):
            attachments.append((entry.get("testIdentifier", ""), item))

    seen = {}
    errors = []
    for test_id, item in attachments:
        stem = readable_stem(item)
        key = stem.split("-")[0]
        if key in seen:
            errors.append(f"截图编号重复：{key}")
        seen[key] = (test_id, item, stem)

    for key, (stem, test_id, size) in EXPECTED.items():
        found = seen.get(key)
        if found is None:
            errors.append(f"缺少截图 {key}（{stem}）")
            continue
        actual_test, item, actual_stem = found
        if actual_test != test_id:
            errors.append(f"{key} 的来源用例不符：期望 {test_id}，实际 {actual_test}")
        if actual_stem != stem:
            errors.append(f"{key} 的名称不符：期望 {stem}，实际 {actual_stem}")
        path = resolve(base, item)
        if path is None:
            errors.append(f"{key} 的文件不存在：{item.get('exportedFileName')}")
            continue
        dims = png_size(path)
        if dims is None:
            errors.append(f"{key} 不是有效 PNG：{path.name}")
        elif dims != size:
            errors.append(f"{key} 尺寸不符：期望 {size[0]}×{size[1]}，实际 {dims[0]}×{dims[1]}")
        else:
            device = item.get("deviceName", "")
            print(f"[通过] {key}  {path.name}  {dims[0]}×{dims[1]}  {test_id}  {device}")

    for key in sorted(set(seen) - set(EXPECTED)):
        errors.append(f"出现清单之外的截图：{key}")

    if errors:
        print(f"[失败] UI 截图校验未通过（{len(errors)} 项）：")
        for error in errors:
            print("  -", error)
        return 1

    print(f"[通过] UI 截图齐全：{len(EXPECTED)} 张，来源用例与尺寸符合 docs/ui-screenshot-comparison.md 清单。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
