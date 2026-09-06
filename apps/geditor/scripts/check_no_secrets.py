#!/usr/bin/env python3
"""Bộ dò khoá riêng — phần ruột của `scripts/check-no-secrets.sh`.

Đọc lý do tồn tại ở đầu tệp shell ấy. Chỗ này chỉ nói về CÁCH LÀM.

BA LUẬT KHI THÊM MẪU DÒ MỚI

1. **Mẫu phải bắt được thứ THẬT, và bài `--tu-kiem` phải chứng minh điều đó.** Một bộ dò không
   bao giờ kêu và một bộ dò hỏng cho ra cùng một kết quả: im lặng. Mỗi mẫu vì thế đi kèm một
   mẫu vật giả trong `MAU_VAT`, và `--tu-kiem` đòi từng mẫu bắt được đúng mẫu vật của nó.

2. **Chính tệp này không được kích hoạt mẫu của nó.** Nếu mẫu vật viết thẳng thành chuỗi ký tự
   thì cổng sẽ đỏ vì chính nó — và cách sửa dễ nhất khi ấy là loại trừ tệp này khỏi phạm vi
   quét, tức đục một lỗ ngay giữa cổng. Nên mẫu vật được GHÉP lúc chạy, và KHÔNG tệp nào được
   loại trừ, kể cả tệp này.

3. **Ngoại lệ phải KHAI TÊN và TỰ DỌN.** `NGOAI_LE` giữ những chỗ trúng mẫu mà không phải khoá
   thật (mẫu vật trong test của thư viện vendor chẳng hạn). Cổng đỏ cả khi một dòng trong
   `NGOAI_LE` KHÔNG còn trúng nữa — nếu không, danh sách chỉ phình ra và không ai dọn.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# Tệp lớn hơn ngần này thì bỏ qua: khoá riêng đều nhỏ, còn kho có `libduckdb` 94 MB và các bảng
# tra grammar. Quét chúng chỉ tốn thời gian cho một câu trả lời đã biết.
TRAN_BYTE = 2 * 1024 * 1024


def ghep(*phan):
    """Ghép chuỗi lúc CHẠY để mẫu vật không nằm nguyên văn trong tệp này (luật 2)."""
    return "".join(phan)


# (tên, mẫu dò, mẫu vật để `--tu-kiem` bắn thử)
MAU = [
    (
        "khoá riêng dạng PEM",
        re.compile(r"-{5}BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-{5}"),
        ghep("-----BEGIN ", "OPENSSH", " PRIVATE ", "KEY-----\nb3BlbnNzaC1r\n"),
    ),
    (
        # Khoá riêng EdDSA của Sparkle là 64 byte base64 = 88 ký tự kết thúc bằng "==". Đòi có
        # TỪ KHOÁ ở gần để một chuỗi base64 dài bất kỳ (ảnh nhúng, dữ liệu kiểm thử) không bị
        # kêu oan — mẫu không kèm ngữ cảnh sẽ kêu sai ngay lần chạy thứ hai, và thứ kêu sai thì
        # lần thứ ba đã bị bỏ qua.
        "khoá riêng EdDSA (Sparkle)",
        re.compile(
            r"(?i)(sparkle|eddsa|ed25519|private[_\- ]?key|khoa[_\- ]?rieng)"
            r"[^\n]{0,80}[A-Za-z0-9+/]{80,}={0,2}"
        ),
        ghep("SPARKLE_PRIVATE_KEY=", "A" * 86, "=="),
    ),
    (
        # DÒNG chỉ toàn base64, dài đúng cỡ một khoá ed25519 (khoá riêng 64 byte → 88 ký tự;
        # khoá công khai 32 byte → 44 ký tự) và đứng MỘT MÌNH trên dòng ấy.
        #
        # Mẫu này thêm ngày 28/08/2026 vì mẫu "EdDSA (Sparkle)" ở trên ĐỂ LỌT một tệp khoá
        # thật: nó đòi từ khoá nằm cùng DÒNG với chuỗi base64 (`[^\n]{0,80}`), mà một tệp khoá
        # thật thì để chú thích ở mấy dòng đầu và khoá trần ở dòng cuối. Bắt được nó chỉ vì
        # đem một khoá thật ra thử — đọc mã thì không thấy.
        "dòng khoá ed25519 trần (88 hoặc 44 ký tự base64)",
        re.compile(r"^[A-Za-z0-9+/]{43}=$|^[A-Za-z0-9+/]{86}==$", re.M),
        ghep("A" * 86, "=="),
    ),
    (
        "mật khẩu riêng cho ứng dụng (notarytool)",
        re.compile(r"(?i)(notary|app[_\- ]?specific|altool)[^\n]{0,60}\b[a-z]{4}(?:-[a-z]{4}){3}\b"),
        # Bốn mảnh chứ không một chuỗi: viết liền thì chính dòng này trúng mẫu ngay trên nó.
        # Đây KHÔNG phải chuyện giả định — móc pre-commit đã bắt đúng dòng này ở lần commit đầu.
        ghep("NOTARY_PASSWORD=", "abcd", "-efgh", "-ijkl", "-mnop"),
    ),
    (
        # Đường ống ký đọc hai biến này từ MÔI TRƯỜNG. Gán thẳng một giá trị vào mã nguồn là
        # đúng cái nó sinh ra để tránh. `$…` và `${…}` là tham chiếu, không phải giá trị.
        "danh tính ký gán cứng trong mã",
        re.compile(
            r"GEDITOR_(?:SIGN_IDENTITY|NOTARY_PROFILE)\s*=\s*[\"']?(?![\"']?\s*$)(?![$\"'])"
            r"[^\n$]{3,}"
        ),
        ghep("GEDITOR_SIGN_", "IDENTITY=Developer ID Application: Ai Do (ABCDE12345)"),
    ),
]

# Đuôi tệp là vật chứa khoá, bắt theo TÊN chứ không theo nội dung — chúng là nhị phân.
DUOI_CAM = (".p12", ".pfx", ".jks", ".keystore", ".mobileprovision", ".keychain", ".key")
TEN_CAM = re.compile(r"(?i)^(?:AuthKey_[A-Z0-9]+\.p8|id_(?:rsa|ed25519|ecdsa))$")

# Chỗ trúng mẫu mà cổng vẫn cho đi qua. Khai theo "đường dẫn::tên mẫu".
#
# ⚠️ HAI DÒNG DƯỚI ĐÂY KHÔNG PHẢI BÁO NHẦM. Chúng là khoá THẬT, và chúng nằm trong kho vì chủ
# sản phẩm đã quyết định như vậy ngày 28/08/2026 sau khi được trình bày đánh đổi ba lần. Lý do
# của anh: kho private, và cần sao lưu phòng khi máy hỏng. Đánh đổi ghi ở `docs/khoa-va-ky.md`
# §2bis — đọc mục ấy trước khi động vào.
#
# Đây là ngoại lệ HẸP nhất có thể: đúng hai đường dẫn, đúng một mẫu. Mọi khoá khác — kể cả một
# khoá Sparkle thứ hai đặt tên khác — vẫn bị chặn, và điều đó đã được kiểm chứ không phải tin.
# Trong kho EIDE, `secrets/sparkle_eddsa_private.txt` KHÔNG tồn tại: nó bị chặn ở
# `.gitignore` gốc (`secrets/*_private*`) và không bao giờ được đưa vào. Ngoại lệ cho nó
# đã bị gỡ theo đúng luật §3 ở đầu tệp — một dòng không còn trúng thì phải xoá.
# Bản gốc trong kho Geditor vẫn giữ ngoại lệ ấy; xem DEVIATIONS DEV-004.
NGOAI_LE: set[str] = {
    "secrets/sparkle_eddsa_public.txt::đường dẫn có từ khoá của tệp khoá",
}


def tep_can_soi(staged):
    if staged:
        out = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"],
            cwd=ROOT, capture_output=True, text=True, check=True).stdout
    else:
        out = subprocess.run(["git", "ls-files", "-z"],
                             cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [p for p in out.split("\0") if p]


# Từ khoá trong ĐƯỜNG DẪN. Mẫu dò nội dung chỉ nhìn được từng dòng, mà một tệp khoá thật hay
# đặt chú thích ở đầu và khoá trần ở cuối — lúc ấy tên tệp là manh mối rõ nhất còn lại.
DUONG_DAN_NGHI = re.compile(r"(?i)(secret|private[_\-]?key|khoa[_\-]?rieng|eddsa|signing[_\-]?key)")


def soi(duong_dan):
    """[(tên mẫu, số dòng)] — mọi chỗ trúng trong một tệp."""
    ten = os.path.basename(duong_dan)
    if ten.lower().endswith(DUOI_CAM) or TEN_CAM.match(ten):
        return [("tệp chứa khoá theo ĐUÔI/TÊN", 0)]
    if DUONG_DAN_NGHI.search(duong_dan) and not duong_dan.startswith("scripts/"):
        # `scripts/` được trừ vì chính bộ dò và tài liệu của nó phải nhắc những từ ấy để làm
        # việc. Không trừ tệp nào ngoài đó — trừ rộng hơn là đục lỗ giữa cổng.
        return [("đường dẫn có từ khoá của tệp khoá", 0)]

    that = os.path.join(ROOT, duong_dan)
    try:
        if os.path.getsize(that) > TRAN_BYTE:
            return []
        with open(that, encoding="utf8") as tay:
            noi_dung = tay.read()
    except (OSError, UnicodeDecodeError):
        # Nhị phân hoặc đã bị xoá khỏi cây làm việc — không có gì đọc được để kết luận.
        return []

    trung = []
    for ten_mau, mau, _ in MAU:
        for khop in mau.finditer(noi_dung):
            trung.append((ten_mau, noi_dung.count("\n", 0, khop.start()) + 1))
    return trung


def tu_kiem():
    """Đối chứng ÂM: bắn mẫu vật giả vào từng mẫu và đòi nó kêu."""
    hong = []
    for ten_mau, mau, mau_vat in MAU:
        if not mau.search(mau_vat):
            hong.append(ten_mau)
    if hong:
        print("❌ bộ dò KHÔNG bắt được mẫu vật của chính nó: " + ", ".join(hong), file=sys.stderr)
        return 1
    # Và chiều ngược lại: một dòng mã bình thường không được làm nó kêu.
    lanh = "let version = MermaidAsset.manifest?.version ?? \"khong ro\"\n"
    for ten_mau, mau, _ in MAU:
        if mau.search(lanh):
            print(f"❌ mẫu «{ten_mau}» kêu oan trên một dòng mã bình thường", file=sys.stderr)
            return 1
    print(f"✅ đối chứng âm: cả {len(MAU)} mẫu đều bắt được mẫu vật, và không mẫu nào kêu oan")
    return 0


def main():
    if "--tu-kiem" in sys.argv:
        return tu_kiem()

    staged = "--staged" in sys.argv
    thay = []
    for duong_dan in tep_can_soi(staged):
        for ten_mau, dong in soi(duong_dan):
            khoa = f"{duong_dan}::{ten_mau}"
            if khoa in NGOAI_LE:
                continue
            thay.append((duong_dan, dong, ten_mau))

    if thay:
        print("❌ NFR-SEC-01: có khoá riêng trong thứ sắp vào kho — commit là KHÔNG hoàn tác được",
              file=sys.stderr)
        for duong_dan, dong, ten_mau in thay:
            vi_tri = f"{duong_dan}:{dong}" if dong else duong_dan
            print(f"   {vi_tri} — {ten_mau}", file=sys.stderr)
        print("   Chỗ đúng để cất khoá: `docs/khoa-va-ky.md`.", file=sys.stderr)
        print("   Nếu đây là báo nhầm, khai vào `NGOAI_LE` trong scripts/check_no_secrets.py.",
              file=sys.stderr)
        return 1

    # Ngoại lệ TỰ DỌN: một dòng khai mà không còn trúng nữa là một dòng phải xoá.
    con_dung = set()
    for duong_dan in tep_can_soi(staged=False):
        for ten_mau, _ in soi(duong_dan):
            con_dung.add(f"{duong_dan}::{ten_mau}")
    thua = NGOAI_LE - con_dung
    if thua:
        print("❌ NGOẠI LỆ đã hết tác dụng, xoá khỏi `NGOAI_LE`: " + ", ".join(sorted(thua)),
              file=sys.stderr)
        return 1

    pham_vi = "phần đã `git add`" if staged else "các tệp git đang theo dõi"
    print(f"✅ NFR-SEC-01: không có khoá riêng nào trong {pham_vi}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
