"""校验合成名片数据集（无第三方依赖，CI 的 static job 与本地共用）。

检查项：
  1. fixtures/_manifest.json 与 fixtures/Cxx.json 一一对应（41 张：C01–C40 + 空白卡 C41）。
  2. 每张名片 4 个图像变体齐全，PNG 文件头合法、尺寸符合脚本约定。
  3. ground-truth.json 覆盖全部 40 张字段准确率名片，且与每张 fixture 内的 groundTruth 一致。
  4. ocrText 与 layoutText 一致；C41 的文本与 Ground Truth 均为空。
  5. Ground Truth 的电话为归一化展示格式（无括号、无连字符、无多余空格）。

用法： python scripts/verify_test_cards.py
退出码：0 通过；1 有错误（逐条打印）。
"""
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TC = os.path.join(ROOT, "docs", "test-cards")
FIXTURES = os.path.join(TC, "fixtures")

ACCURACY_IDS = [f"C{i:02d}" for i in range(1, 41)]
EXPECTED_CARDS = ACCURACY_IDS + ["C41"]
VARIANTS = {"flat": (1012, 638), "tilt": (1012, 723), "rotate": (1012, 638), "shadow": (1012, 759)}
PHONE_KEYS = ("mobile", "officePhone", "fax")
FIELD_KEYS = {
    "name", "company", "jobTitle", "department", "address", "postalCode",
    "mobile", "officePhone", "fax", "email", "website",
}
DISPLAY_PHONE = re.compile(r"^(?:\+\d{1,3} )?[0-9]+(?: [0-9]+)*$")

errors = []


def fail(message):
    errors.append(message)


def png_size(path):
    """读取 PNG 的 IHDR，返回 (宽, 高, 位深, 颜色类型)；非 PNG 返回 None。"""
    try:
        with open(path, "rb") as fh:
            head = fh.read(33)
    except OSError:
        return None
    if len(head) < 33 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", head[16:24])
    bit_depth, color_type = head[24], head[25]
    return width, height, bit_depth, color_type


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def main():
    manifest_path = os.path.join(FIXTURES, "_manifest.json")
    if not os.path.isfile(manifest_path):
        fail("缺少 fixtures/_manifest.json（先运行 scripts/make_test_cards.py）")
        report()
        return

    manifest = load_json(manifest_path)
    ids = [entry.get("id") for entry in manifest]
    if ids != EXPECTED_CARDS:
        fail(f"_manifest.json 的 id 序列不符：{ids[:5]}...{ids[-3:]}（期望 C01–C41）")

    ground_truth = load_json(os.path.join(TC, "ground-truth.json"))
    if sorted(ground_truth) != ACCURACY_IDS:
        fail(f"ground-truth.json 应恰好覆盖 40 张准确率名片，实际 {len(ground_truth)} 张")

    total_images = 0
    for entry in manifest:
        card_id = entry["id"]
        fixture_path = os.path.join(FIXTURES, f"{card_id}.json")
        if not os.path.isfile(fixture_path):
            fail(f"{card_id}: 缺少 fixture 文件")
            continue
        fixture = load_json(fixture_path)

        for key in ("id", "kind", "layout"):
            if fixture.get(key) != entry.get(key):
                fail(f"{card_id}: fixture 的 {key} 与 _manifest.json 不一致")
        if fixture.get("images") != entry.get("images"):
            fail(f"{card_id}: fixture 的 images 与 _manifest.json 不一致")
        if fixture.get("image") != f"docs/test-cards/images/{card_id}_flat.png":
            fail(f"{card_id}: image 字段应指向 flat 变体")

        images = fixture.get("images") or {}
        for variant, (width, height) in VARIANTS.items():
            rel = images.get(variant)
            if rel != f"docs/test-cards/images/{card_id}_{variant}.png":
                fail(f"{card_id}: images.{variant} 路径不正确：{rel}")
                continue
            path = os.path.join(ROOT, rel)
            size = png_size(path)
            if size is None:
                fail(f"{card_id}: {rel} 缺失或不是合法 PNG")
                continue
            total_images += 1
            if (size[0], size[1]) != (width, height):
                fail(f"{card_id}: {variant} 尺寸 {size[0]}x{size[1]}，期望 {width}x{height}")
            if size[2:] != (8, 2):
                fail(f"{card_id}: {variant} 期望 8 位 RGB PNG，实际位深/颜色类型 {size[2:]}")

        layout_text = fixture.get("layoutText")
        if not isinstance(layout_text, list):
            fail(f"{card_id}: layoutText 应为字符串数组")
            layout_text = []
        if fixture.get("ocrText") != "\n".join(layout_text):
            fail(f"{card_id}: ocrText 与 layoutText 不一致")

        gt = fixture.get("groundTruth")
        if not isinstance(gt, dict):
            fail(f"{card_id}: groundTruth 应为对象")
            continue
        unknown = set(gt) - FIELD_KEYS
        if unknown:
            fail(f"{card_id}: groundTruth 含未知字段 {sorted(unknown)}")
        for key in PHONE_KEYS:
            if key in gt and not DISPLAY_PHONE.match(gt[key]):
                fail(f"{card_id}: {key}={gt[key]!r} 不是归一化电话格式")

        if card_id == "C41":
            if entry.get("kind") != "exception" or layout_text or gt:
                fail("C41 应为无文本、无 Ground Truth 的空白异常卡")
            if entry.get("layout") != "blank":
                fail("C41 的 layout 应为 blank")
        else:
            expected = ground_truth.get(card_id)
            if expected != gt:
                fail(f"{card_id}: fixture 内 groundTruth 与 ground-truth.json 不一致")
            if entry.get("kind") == "exception":
                fail(f"{card_id}: 非 C41 的名片不应标记为 exception")

    image_dir = os.path.join(TC, "images")
    pngs = [name for name in os.listdir(image_dir) if name.lower().endswith(".png")]
    if len(pngs) != len(EXPECTED_CARDS) * len(VARIANTS):
        fail(f"images/ 下应有 {len(EXPECTED_CARDS) * len(VARIANTS)} 张 PNG，实际 {len(pngs)}")
    unexpected = sorted(set(pngs) - {f"{cid}_{v}.png" for cid in EXPECTED_CARDS for v in VARIANTS})
    if unexpected:
        fail(f"images/ 存在多余文件：{unexpected[:5]}")

    report(total_images)


def report(total_images=None):
    if errors:
        print(f"FAILED: {len(errors)} 个问题")
        for message in errors:
            print("  -", message)
        sys.exit(1)
    print("OK: 合成名片数据集校验通过")
    print(f"  cards: {len(EXPECTED_CARDS)}（准确率 {len(ACCURACY_IDS)} + 空白异常 1）")
    if total_images:
        print(f"  images: {total_images} / {len(EXPECTED_CARDS) * len(VARIANTS)}")


if __name__ == "__main__":
    main()
