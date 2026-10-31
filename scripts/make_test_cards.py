"""生成合成名片图像 + Ground Truth（本地一次静态完成）。

共 41 张：C01–C40 用于字段级准确率评价（40 张，满足作业 30–50 张要求），
C41 为空白卡片，仅用于 T20「无法识别 → 手动录入」异常路径。
所有姓名、公司、电话、邮箱均为虚构数据（示例域名 example.com / 555 号段 / 138 0000 号段），
不含任何真实个人信息。输出：
  docs/test-cards/images/Cxx_{flat,tilt,rotate,shadow}.png
  docs/test-cards/fixtures/Cxx.json     （App 单元测试 / UI 测试读取）
  docs/test-cards/fixtures/_manifest.json
  docs/test-cards/ground-truth.json     （汇总，OCR 准确率评价用）

用法： python scripts/make_test_cards.py
依赖： Pillow；字体使用 Windows 自带微软雅黑 / Arial，仅用于本地生成，不随仓库分发。
"""
import json
import os
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_IMAGES = os.path.join(ROOT, "docs", "test-cards", "images")
OUT_FIXTURES = os.path.join(ROOT, "docs", "test-cards", "fixtures")
FONT_DIR = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")

W, H = 1012, 638  # 85.6mm x 54mm ≈ 1.58:1
M = 64


def font(size, bold=False, chinese=True):
    if chinese:
        name = "msyhbd.ttc" if bold else "msyh.ttc"
    else:
        name = "arialbd.ttf" if bold else "arial.ttf"
    try:
        return ImageFont.truetype(os.path.join(FONT_DIR, name), size)
    except OSError:
        return ImageFont.load_default()


def new_card(bg="#FFFFFF", fg="#1A1A1A", accent="#1F4E8C"):
    img = Image.new("RGB", (W, H), bg)
    return img, ImageDraw.Draw(img), fg, accent


def text_line(draw, xy, text, size, color, bold=False, chinese=True):
    if text:
        draw.text(xy, text, font=font(size, bold, chinese), fill=color)


def divider(draw, y, color, x0=M, x1=W - M):
    draw.line([(x0, y), (x1, y)], fill=color, width=2)


class CardText:
    """收集版式上真正绘制的文本行，并按 Vision 的阅读顺序（上→下、左→右）输出。

    输出用于 fixtures 里的 `ocrText`：模拟端上 OCR 的行序。真实 Vision 的结果由
    T20 用例在模拟器上另行测量，二者分开报告。
    """

    def __init__(self, draw):
        self.draw = draw
        self.items = []

    def put(self, xy, text, size, color, bold=False, chinese=True):
        if not text:
            return
        self.draw.text(xy, text, font=font(size, bold, chinese), fill=color)
        self.items.append((xy[1], xy[0], text))

    def ordered(self):
        return [text for _, _, text in sorted(self.items, key=lambda item: (item[0] // 22, item[1]))]


def logo_block(ct, accent, short):
    d = ct.draw
    d.rounded_rectangle([M, M - 16, M + 92, M + 56], radius=14, outline=accent, width=4)
    tw = d.textlength(short, font=font(34, True, False))
    ct.put((M + 46 - tw / 2, M - 4), short, 34, accent, True, False)


# ---------------------------------------------------------------- 版式（未提供的字段不绘制）

def layout_classic(fields):
    """白底经典版式：姓名 / 职位 / 公司 / 部门 + 左列电话、右列邮箱网址地址。"""
    img, d, fg, accent = new_card()
    ct = CardText(d)
    logo_block(ct, accent, fields.get("logo") or "CO")

    y = M + 76
    ct.put((M, y), fields.get("name"), 64, fg, True)
    y += 84
    ct.put((M, y), fields.get("jobTitle"), 34, accent)
    y += 48
    ct.put((M, y), fields.get("company"), 34, fg)
    y += 44
    ct.put((M, y), fields.get("department"), 26, "#555555")

    divider(d, H - 196, accent)
    y = H - 176
    for label, key in [("手机", "mobile"), ("电话", "officePhone"), ("传真", "fax")]:
        if fields.get(key):
            ct.put((M, y), f"{label} {fields[key]}", 28, fg)
            y += 40
    x2, y2 = W // 2 + 10, H - 176
    for label, key in [("邮箱", "email"), ("网址", "website"), ("地址", "address"), ("邮编", "postalCode")]:
        if fields.get(key):
            ct.put((x2, y2), f"{label} {fields[key]}", 24, fg)
            y2 += 36
    return img, ct.ordered()


def layout_english(fields):
    img, d, fg, accent = new_card()
    ct = CardText(d)
    if fields.get("logo"):
        logo_block(ct, accent, fields["logo"])
    else:
        d.ellipse([M, M - 8, M + 80, M + 72], outline=accent, width=4)
    y = M + 88
    ct.put((M, y), fields.get("company"), 34, accent, True, False)
    y += 52
    ct.put((M, y), fields.get("name"), 56, fg, True, False)
    y += 70
    ct.put((M, y), fields.get("jobTitle"), 32, fg, False, False)
    divider(d, H - 224, accent, x0=M, x1=380)
    y = H - 204
    lines = []
    if fields.get("mobile"):
        lines.append("Mobile: " + fields["mobile"])
    if fields.get("officePhone"):
        lines.append("Office: " + fields["officePhone"])
    if fields.get("fax"):
        lines.append("Fax: " + fields["fax"])
    if fields.get("email"):
        lines.append("Email: " + fields["email"])
    if fields.get("website"):
        lines.append("Web: " + fields["website"])
    if fields.get("address"):
        lines.append(fields["address"])
    for line in lines:
        ct.put((M, y), line, 26, fg, False, False)
        y += 34
    return img, ct.ordered()


def layout_vertical(fields):
    """竖版：左侧色条 + 竖排姓名 + 右侧信息列。"""
    img, d, fg, accent = new_card(bg="#F7F5EF")
    ct = CardText(d)
    d.rectangle([0, 0, 150, H], fill=accent)
    yy = M + 20
    for ch in fields.get("name", ""):
        ct.put((44, yy), ch, 50, "#FFFFFF", True)
        yy += 58
    x = 200
    ct.put((x, M + 10), fields.get("company"), 40, fg, True)
    y = M + 90
    for line in fields.get("infoLines", []):
        ct.put((x, y), line, 28, fg)
        y += 44
    return img, ct.ordered()


def layout_dark(fields):
    img, d, fg, accent = new_card(bg="#17233A", fg="#F2F2F2", accent="#5EC8F2")
    ct = CardText(d)
    d.rectangle([0, 0, W, 8], fill=accent)
    ct.put((M, M), fields.get("company"), 36, accent, True, False)
    ct.put((M, M + 70), fields.get("name"), 62, "#FFFFFF", True)
    ct.put((M, M + 150), fields.get("jobTitle"), 32, "#FFFFFF", False, False)
    y = H - 200
    lines = []
    if fields.get("mobile"):
        lines.append("Mobile: " + fields["mobile"])
    if fields.get("officePhone"):
        lines.append("Tel: " + fields["officePhone"])
    if fields.get("email"):
        lines.append("Email: " + fields["email"])
    if fields.get("website"):
        lines.append("Web: " + fields["website"])
    if fields.get("address"):
        lines.append(fields["address"])
    for line in lines:
        ct.put((M, y), line, 30, "#FFFFFF", False, False)
        y += 40
    d.polygon([(W - 260, H), (W, H - 260), (W, H)], fill=accent)
    return img, ct.ordered()


def layout_blank(fields):
    """空白卡片：没有任何可识别文字，用于 T20「无法识别」异常路径。"""
    img, d, fg, accent = new_card()
    return img, []


def layout_sidebar(fields):
    img, d, fg, accent = new_card()
    ct = CardText(d)
    d.rectangle([0, 0, 380, H], fill="#EAF1F8")
    d.rectangle([372, 0, 380, H], fill=accent)
    ct.put((48, M + 40), fields.get("company"), 38, accent, True)
    ct.put((48, M + 110), fields.get("name"), 56, fg, True)
    ct.put((48, M + 190), fields.get("jobTitle"), 30, fg)
    y = M + 20
    x = 440
    for line in fields.get("infoLines", []):
        ct.put((x, y), line, 30, fg)
        y += 46
    return img, ct.ordered()


LAYOUTS = {
    "classic": layout_classic,
    "english": layout_english,
    "vertical": layout_vertical,
    "dark": layout_dark,
    "sidebar": layout_sidebar,
    "blank": layout_blank,
}


# ---------------------------------------------------------------- 测试名片（虚拟数据）

def card(cid, kind, layout, logo, name, job_title, company, department=None,
         mobile=None, office=None, fax=None, email=None, website=None,
         address=None, postal=None, note=""):
    return dict(id=cid, kind=kind, layout=layout, logo=logo, name=name,
                jobTitle=job_title, company=company, department=department,
                mobile=mobile, officePhone=office, fax=fax, email=email,
                website=website, address=address, postalCode=postal, note=note)


def sidebar_info(f):
    lines = []
    if f.get("department"):
        lines.append("部门 " + f["department"])
    if f.get("mobile"):
        lines.append("手机 " + f["mobile"])
    if f.get("officePhone"):
        lines.append("电话 " + f["officePhone"])
    if f.get("fax"):
        lines.append("传真 " + f["fax"])
    if f.get("email"):
        lines.append("邮箱 " + f["email"])
    if f.get("address"):
        lines.append("地址 " + f["address"])
    return lines


def vertical_info(f):
    lines = []
    if f.get("department"):
        lines.append(f["department"])
    if f.get("jobTitle"):
        lines.append(f["jobTitle"])
    if f.get("mobile"):
        lines.append("手机 " + f["mobile"])
    if f.get("officePhone"):
        lines.append("电话 " + f["officePhone"])
    if f.get("email"):
        lines.append("邮箱 " + f["email"])
    if f.get("website"):
        lines.append("网址 " + f["website"])
    if f.get("address"):
        lines.append("地址 " + f["address"])
    return lines


CARDS = [
    # ---- 中文名片 10 张
    card("C01", "chinese", "classic", "TJ", "朱宏明", "教授", "同济大学", "计算机科学与技术学院",
         mobile="138 0000 0001", office="021-6598 1234", fax="021-6598 1235",
         email="zhuhm@example.edu.cn", website="www.example.edu.cn",
         address="上海市杨浦区四平路1239号", postal="200092"),
    card("C02", "chinese", "classic", "XC", "赵敏", "产品经理", "星辰科技有限公司",
         mobile="138 0000 0002", office="010-5888 0002", email="zhaomin@example.com",
         address="北京市海淀区中关村大街1号"),
    card("C03", "chinese", "sidebar", "HY", "孙立", "技术总监", "华宇信息集团", "研发中心",
         mobile="138 0000 0003", email="sunli@example.com.cn", address="杭州市西湖区文三路90号"),
    card("C04", "chinese", "classic", "NF", "周伟", "设计师", "南风工作室",
         mobile="138 0000 0004", email="zhouwei@example.cn"),
    card("C05", "chinese", "vertical", "QY", "吴芳", "副研究员", "启元研究院", "材料研究部",
         mobile="138 0000 0005", email="wufang@example.org", website="www.example.org"),
    card("C06", "chinese", "classic", "HT", "郑建国", "总经理", "恒通建设集团",
         mobile="138 0000 0006", office="028-8666 0006", fax="028-8666 0007",
         email="zhengjg@example.com"),
    card("C07", "chinese", "sidebar", "MD", "陈晨", "护士长", "明德医院", "护理部",
         office="021-6222 0007", address="上海市徐汇区漕溪北路88号"),
    card("C08", "chinese", "classic", "RC", "林晓", "编辑", "人民城出版社",
         office="010-6555 0008", email="linxiao@example.net"),
    card("C09", "chinese", "classic", "SX", "黄河", "律师", "盛信律师事务所",
         mobile="138 0000 0009", email="huanghe@example.com",
         address="广州市天河区珠江新城5号", website="www.example-law.cn"),
    card("C10", "chinese", "sidebar", "KJ", "马丽", "财务主管", "康健医疗集团", "财务部",
         office="0755-8333 0010", fax="0755-8333 0011", email="mali@example.com"),
    # ---- 英文名片 10 张
    card("C11", "english", "english", "AT", "David Chen", "Technical Director",
         "ABC Technologies Inc.", mobile="+1 (555) 010-2233", office="555-010-8899",
         email="david.chen@example.com", address="500 Market Street, San Francisco, CA"),
    card("C12", "english", "english", "NW", "Michael Brown", "Senior Software Engineer",
         "Northwind Systems", office="555-014-7788", email="m.brown@example.org",
         website="www.example-systems.com"),
    card("C13", "english", "english", None, "Sarah Johnson", "Marketing Manager",
         "BrightPath Media", mobile="(555) 016-3321", email="sarah.j@example.com"),
    card("C14", "english", "dark", "OL", "James Wilson", "Chief Executive Officer",
         "Orion Labs", mobile="+1 555 018 4410", email="jwilson@example.io",
         website="https://www.example-labs.io"),
    card("C15", "english", "english", "PM", "Emily Zhang", "Product Manager",
         "Nova Robotics Lab", mobile="(555) 020-1188", office="(555) 020-1199",
         email="emily.zhang@example.com"),
    card("C16", "english", "english", "GC", "Robert Taylor", "Consultant",
         "GreenCell Consulting", office="+44 20 7946 0102", email="r.taylor@example.co.uk",
         address="12 Baker Street, London"),
    card("C17", "english", "dark", "SF", "Anna Miller", "Data Scientist",
         "Summit Financial Group", mobile="(555) 022-6677", email="anna.m@example.com",
         address="88 Pine Avenue, New York, NY"),
    card("C18", "english", "english", None, "Kevin Lee", "Architect",
         "BlueRock Studio", mobile="(555) 024-9001", website="www.example-studio.net"),
    card("C19", "english", "english", "UC", "Linda Davis", "Professor",
         "University of California, Berkeley", office="555-026-3344", email="l.davis@example.edu",
         address="1 University Drive, Berkeley, CA"),
    card("C20", "english", "english", "LM", "Peter Harris", "Operations Lead",
         "LogiMax Group", office="555-028-5522", mobile="(555) 028-5533",
         email="pharris@example.com", fax="555-028-5544"),
    # ---- 中英双语 6 张
    card("C21", "bilingual", "classic", "TJ", "李娜", "Associate Professor", "Tongji University",
         "School of Software Engineering", mobile="139 0000 0021", office="+86 (21) 6958 9000",
         email="lina@example.edu.cn"),
    card("C22", "bilingual", "sidebar", "IB", "王强", "Project Manager", "华建集团 ChinaBuild Group",
         "工程管理部", mobile="139 0000 0022", office="021-5888 1234", fax="021-5888 5678",
         email="wangqiang@example.com"),
    card("C23", "bilingual", "classic", "ZX", "刘洋", "Software Engineer", "中兴达科技 Zhongxingda Tech",
         mobile="139 0000 0023", email="liuyang@example.com", website="www.example-tech.com"),
    card("C24", "bilingual", "vertical", "GH", "张伟", "HR Director", "国华人力资源 GuoHua HR",
         "人力资源部", mobile="139 0000 0024", email="zhangwei@example.cn"),
    card("C25", "bilingual", "classic", "SH", "陈静", "Research Scientist", "上海生命科学研究院 SIBCB",
         mobile="139 0000 0025", email="chenjing@example.org", address="上海市岳阳路320号"),
    card("C26", "bilingual", "dark", "TA", "杨帆", "Business Analyst", "天安咨询 TianAn Consulting",
         mobile="+86 139 0000 0026", email="yangfan@example.com", website="www.example-ta.cn"),
    # ---- 竖版 / 特殊布局 4 张
    card("C27", "special", "vertical", "LS", "高远", "建筑师", "蓝图设计院",
         mobile="137 0000 0027", email="gaoyuan@example.com"),
    card("C28", "special", "vertical", "YH", "许晴", "研究员", "云和科技", "人工智能部",
         mobile="137 0000 0028", website="www.example-yh.com"),
    card("C29", "special", "sidebar", "QC", "何军", "销售总监", "青创投资", "投资部",
         mobile="137 0000 0029", office="0571-8777 0029", email="hejun@example.com"),
    card("C30", "special", "dark", "VX", "Alex Kim", "Engineering Manager", "Vertex Cloud Systems",
         mobile="+82 10 0000 0030", email="alex.kim@example.com", website="www.example-vertex.com"),
    # ---- 多电话 / 多 Email 4 张
    card("C31", "multi", "classic", "JZ", "罗成", "项目经理", "九洲贸易有限公司",
         mobile="136 0000 0031", office="020-8777 0031", fax="020-8777 0032",
         email="luocheng@example.com", address="广州市越秀区中山路100号"),
    card("C32", "multi", "english", "TW", "Rachel Green", "Account Executive",
         "Tidewater Partners", mobile="(555) 032-1111", office="(555) 032-2222",
         email="rachel@example.com", address="77 Harbor Lane, Boston, MA"),
    card("C33", "multi", "sidebar", "WF", "唐悦", "客服经理", "万丰物流", "客户服务部",
         office="021-6444 0033", fax="021-6444 0034", email="tangyue@example.com"),
    card("C34", "multi", "english", "MA", "Thomas Reed", "Sales Director",
         "Metro Auto Group", mobile="(555) 034-7777", office="(555) 034-8888",
         email="treed@example.com", website="www.example-metro.com"),
    # ---- 字段缺失 4 张
    card("C35", "missing", "classic", None, "冯雪", "自由译者", "星火翻译工作室"),
    card("C36", "missing", "english", None, "Oliver Stone", "Writer", "Independent Writers Studio",
         email="oliver@example.com"),
    card("C37", "missing", "vertical", "XL", "秦岚", "音乐人", "星旅文化",
         mobile="136 0000 0037"),
    card("C38", "missing", "english", None, "Grace Kim", "Student", "Example University"),
    # ---- 复杂 Logo / 背景 2 张
    card("C39", "complex", "dark", "BR", "Sean Parker", "Creative Director",
         "BlackRiver Creative Studio", mobile="(555) 039-2020", email="sean@example.com",
         website="www.example-br.com"),
    card("C40", "complex", "sidebar", "GC", "邓超", "供应链总监", "广诚集团", "供应链中心",
         mobile="136 0000 0040", email="dengchao@example.com", address="深圳市南山区科技园路8号"),
    # ---- 空白卡片 1 张（异常路径，不计入字段准确率）
    card("C41", "exception", "blank", None, None, None, None,
         note="空白卡片：无任何可识别文字，用于 T20 无法识别 → 手动录入路径"),
]

# C41 是异常路径用例，不参与字段级准确率统计。
ACCURACY_CARDS = [f for f in CARDS if f["kind"] != "exception"]


def prepare(f):
    f = dict(f)
    if f["layout"] == "sidebar":
        f["infoLines"] = sidebar_info(f)
    elif f["layout"] == "vertical":
        f["infoLines"] = vertical_info(f)
    return f


def display_phone(value):
    """电话号码的展示格式契约（与 BusinessCardFieldParser.normalizePhone 一致）。

    名片上印的格式千差万别，App 统一成一种可比较的展示格式：
      +86 手机 → 去掉国家码后 3-4-4；+86 座机 → 去掉国家码并补回 0 区号；
      0086 / 86 前缀 → 相当于不带国家码处理；
      其它 +国际码 → 国家码后按 3 位一组（10 位本地号按 3-3-4）；
      无国家码 → 去括号、连字符换空格。
    Ground truth 记录的是 App 应当输出的格式，而不是卡片上的原始排版。
    """
    import re
    cleaned = " ".join(re.sub(r"[()-]", lambda m: " " if m.group() == "-" else "", value).split())
    digits = re.sub(r"\D", "", value)
    compact = value.replace(" ", "")
    if compact.startswith("+86"):
        rest = digits[2:] if digits.startswith("86") else digits
        if len(rest) == 11 and rest.startswith("1"):
            return f"{rest[:3]} {rest[3:7]} {rest[7:]}"
        body = cleaned[3:].strip() if cleaned.startswith("+86") else cleaned
        return body if body.startswith("0") else "0" + body
    if digits.startswith("0086") or (digits.startswith("86") and len(digits) > 11):
        rest = digits[4:] if digits.startswith("0086") else digits[2:]
        if len(rest) == 11 and rest.startswith("1"):
            return f"{rest[:3]} {rest[3:7]} {rest[7:]}"
        return cleaned
    if compact.startswith("+"):
        parts = cleaned[1:].split(" ", 1)
        if len(parts) != 2:
            return cleaned
        code = re.sub(r"\D", "", parts[0])
        national = re.sub(r"\D", "", parts[1])
        if not code or not national:
            return cleaned
        if len(national) == 10:
            groups = [national[:3], national[3:6], national[6:]]
        else:
            groups = [national[i:i + 3] for i in range(0, len(national), 3)]
        return f"+{code} " + " ".join(groups)
    if len(digits) == 11 and digits.startswith("1") and not compact.startswith("+"):
        return f"{digits[:3]} {digits[3:7]} {digits[7:]}"
    return cleaned


def ground_truth(f):
    gt = {}
    for key in ["name", "company", "jobTitle", "department", "address", "postalCode",
                "mobile", "officePhone", "fax", "email", "website"]:
        if f.get(key):
            gt[key] = display_phone(f[key]) if key in ("mobile", "officePhone", "fax") else f[key]
    return gt


# ---------------------------------------------------------------- 拍摄变体

def desk_background(rng, size=(1400, 1000)):
    bg = Image.new("RGB", size, "#8C7B6B")
    d = ImageDraw.Draw(bg)
    for _ in range(70):
        x0, y0 = rng.randint(0, size[0]), rng.randint(0, size[1])
        d.ellipse([x0, y0, x0 + rng.randint(30, 160), y0 + rng.randint(20, 110)],
                  fill=rng.choice(["#7A6A5C", "#9B8A79", "#6E5F52", "#A99A88"]))
    return bg


def tilt_variant(card_img, rng):
    """把名片做轻微透视变形后放到复杂桌面上 —— T06 区域检测用例。"""
    warped = card_img.transform(
        (W, H), Image.Transform.QUAD,
        (28, 10, 14, H - 6, W - 22, H - 20, W - 6, 26),
        Image.Resampling.BICUBIC)
    bg = desk_background(rng)
    bg.paste(warped, (200, 190))
    return bg.resize((1012, 723))


def shadow_variant(card_img):
    bg = Image.new("RGB", (1200, 900), "#D9D2C7")
    shadow = Image.new("RGBA", (W + 40, H + 40), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rectangle([30, 30, W + 10, H + 10], fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    bg.paste(shadow, (120, 130), shadow)
    bg.paste(card_img, (140, 150))
    return bg.resize((1012, 759))


def main():
    os.makedirs(OUT_IMAGES, exist_ok=True)
    os.makedirs(OUT_FIXTURES, exist_ok=True)
    rng = random.Random(20261031)
    summary, manifest = {}, []
    for raw in CARDS:
        f = prepare(raw)
        card_img, text_lines = LAYOUTS[f["layout"]](f)
        variants = {
            "flat": card_img,
            "tilt": tilt_variant(card_img, rng),
            "rotate": card_img.rotate(4, expand=True, fillcolor="#FFFFFF").resize((W, H)),
            "shadow": shadow_variant(card_img),
        }
        for name, v in variants.items():
            v.save(os.path.join(OUT_IMAGES, f"{f['id']}_{name}.png"))
        gt = ground_truth(f)
        image_paths = {
            "flat": f"docs/test-cards/images/{f['id']}_flat.png",
            "tilt": f"docs/test-cards/images/{f['id']}_tilt.png",
            "rotate": f"docs/test-cards/images/{f['id']}_rotate.png",
            "shadow": f"docs/test-cards/images/{f['id']}_shadow.png",
        }
        fixture = {
            "id": f["id"], "kind": f["kind"], "layout": f["layout"], "note": f["note"],
            "image": image_paths["flat"],
            "tiltImage": image_paths["tilt"],
            "images": image_paths,
            "layoutText": text_lines,
            "ocrText": "\n".join(text_lines),
            "groundTruth": gt,
        }
        with open(os.path.join(OUT_FIXTURES, f"{f['id']}.json"), "w", encoding="utf-8") as fh:
            json.dump(fixture, fh, ensure_ascii=False, indent=2)
        summary[f["id"]] = gt
        manifest.append({"id": f["id"], "kind": f["kind"], "layout": f["layout"],
                         "images": image_paths})
    # ground-truth.json 只汇总参与字段准确率评价的 40 张名片；
    # 空白异常卡 C41 的期望值（空字段）记录在它自己的 fixture 里。
    summary.pop("C41", None)
    with open(os.path.join(ROOT, "docs", "test-cards", "ground-truth.json"), "w", encoding="utf-8") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=2)
    with open(os.path.join(OUT_FIXTURES, "_manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
    accuracy = len(ACCURACY_CARDS)
    print(f"generated {len(CARDS)} cards x 4 variants -> {OUT_IMAGES}")
    print(f"field-accuracy set: {accuracy} cards (excluded: {len(CARDS) - accuracy} exception cards)")


if __name__ == "__main__":
    main()
