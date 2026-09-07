"""Chuỗi thu nhận: ingest.* → extract.svd/atdf → passport.import → passport.query.

Spec: CDS-12.2 (ARCHIVE-05..07, EXTRACT-01/02, PASSPORT-01/02/03/07); KAD-07 §5.1 bảng gộp
theo tier; DDD-14 §2 Source/Fact/Passport/PassportFact.

tc: TC-01 "phân loại ≥ 95% đúng"; TC-09 SVD; TC-10 ATDF; TC-13/TC-16 merge và supersede;
TC-15 query.

Đây là vòng khép kín cuối cùng còn thiếu: trước nhóm này, `req.ground_hw` và `arch.*` đọc bảng
`fact` mà không có đường nào đưa fact vào ngoài chèn tay.
"""
from __future__ import annotations

import json

import pytest

from eide.caps.archive import _nhan_dang, bam_tep
from eide_core import store
from eide_core.ledger import Ledger
from eide_core.policy import PolicyGate
from eide_core.router import Context, Router

# SVD tối thiểu nhưng có ĐỦ bốn cơ chế mà bước 1 của EXTRACT-01 nêu tên: derivedFrom (I2C2),
# dim (TIM kênh), cluster (nhóm CH), enum (PE). Thiếu bất kỳ cái nào thì test không nói được gì
# về cái ấy.
SVD = """<?xml version="1.0" encoding="utf-8"?>
<device>
  <vendor>STMicroelectronics</vendor>
  <name>STM32F411</name>
  <peripherals>
    <peripheral>
      <name>SRAM</name>
      <baseAddress>0x20000000</baseAddress>
      <addressBlock><offset>0</offset><size>0x20000</size><usage>buffer</usage></addressBlock>
    </peripheral>
    <peripheral>
      <name>I2C1</name>
      <baseAddress>0x40005400</baseAddress>
      <interrupt><name>I2C1_EV</name><value>31</value></interrupt>
      <registers>
        <register>
          <name>CR1</name>
          <addressOffset>0x00</addressOffset>
          <resetValue>0x00000000</resetValue>
          <description>Control  register   1</description>
          <fields>
            <field>
              <name>PE</name>
              <bitRange>[0:0]</bitRange>
              <enumeratedValues>
                <enumeratedValue><name>Disabled</name><value>0</value></enumeratedValue>
                <enumeratedValue><name>Enabled</name><value>1</value></enumeratedValue>
              </enumeratedValues>
            </field>
            <field><name>SPE</name><bitOffset>3</bitOffset><bitWidth>2</bitWidth></field>
          </fields>
        </register>
        <cluster>
          <name>CH</name>
          <addressOffset>0x100</addressOffset>
          <register><name>CH_CFG</name><addressOffset>0x08</addressOffset></register>
        </cluster>
        <register>
          <name>DR%s</name>
          <dim>4</dim>
          <dimIncrement>0x20</dimIncrement>
          <dimIndex>0-3</dimIndex>
          <addressOffset>0x40</addressOffset>
        </register>
      </registers>
    </peripheral>
    <peripheral derivedFrom="I2C1">
      <name>I2C2</name>
      <baseAddress>0x40005800</baseAddress>
    </peripheral>
  </peripherals>
</device>
"""

ATDF = """<?xml version="1.0" encoding="utf-8"?>
<avr-tools-device-file>
  <devices>
    <device name="ATmega328P" architecture="AVR8">
      <address-spaces>
        <address-space id="prog" size="0x8000">
          <memory-segment name="FLASH" start="0x0000" size="0x8000"/>
        </address-space>
        <address-space id="data" size="0x900">
          <memory-segment name="MAPPED_IO" start="0x0020" size="0x00E0"/>
        </address-space>
      </address-spaces>
    </device>
  </devices>
  <modules>
    <module name="TWI">
      <register-group name="MAPPED_IO">
        <register name="TWCR" offset="0x36" size="1" initval="0x00">
          <bitfield name="TWEN" mask="0x04"/>
          <bitfield name="TWPS" mask="0x03"/>
        </register>
      </register-group>
      <interrupts><interrupt index="24" name="TWI"/></interrupts>
    </module>
  </modules>
</avr-tools-device-file>
"""


@pytest.fixture
def du_an(tmp_path, workspace):
    r = Router(gate=PolicyGate(), ledger=Ledger(tmp_path / "l.jsonl"))
    res = r.invoke("project.create", {"text": "dự án tri thức"}, Context(project_dir=workspace)).result
    root = workspace / res["project_id"]
    store.migrate(store.store_path(root), ledger=r.ledger)
    ctx = Context(project_dir=root, extra={"gate": PolicyGate(), "ledger": r.ledger})
    return r, ctx, root


@pytest.fixture
def svd_file(tmp_path):
    p = tmp_path / "STM32F411.svd"
    p.write_text(SVD, encoding="utf-8")
    return p


def _nguon(root, sid="s_t", h="hash_t"):
    with store.open_store(store.store_path(root)) as c:
        c.execute("INSERT OR REPLACE INTO source (id, uri, sha256, kind, tier) "
                  "VALUES (?,?,?,'datasheet','silver')", (sid, f"{sid}.pdf", h))
        c.commit()
    return sid


def _fact(subject, predicate, value, tier="gold", sid="s_t", **kw):
    return {"subject": subject, "predicate": predicate, "value": value, "source_id": sid,
            "method": "parser", "tier": tier, "confidence": 1.0, **kw}


# ---------- ARCHIVE-05 ingest.classify (TC-01)


def test_chu_ky_noi_dung_thang_phan_mo_rong(tmp_path):
    """Bước 1 nêu rõ thứ tự. Một SVD tải về tên `.xml`, hay một ATDF thực chất là trang lỗi 404
    — tin phần mở rộng nghĩa là gán `tier: gold` cho trang lỗi ấy, và từ đó mọi fact "trích" từ
    nó vào thẳng store không qua ai duyệt."""
    svd = tmp_path / "stm32f411.xml"           # tên nói .xml
    svd.write_text(SVD, encoding="utf-8")
    assert _nhan_dang(svd)[0] == "svd"

    gia = tmp_path / "attiny.atdf"             # tên nói .atdf, ruột là HTML
    gia.write_text("<!DOCTYPE html><html><body>404 Not Found</body></html>", encoding="utf-8")
    assert _nhan_dang(gia)[0] != "atdf"


@pytest.mark.parametrize(("ten", "noi_dung", "kind"), [
    ("a.svd", SVD, "svd"),
    ("b.atdf", ATDF, "atdf"),
    ("c.pdf", "%PDF-1.7\nDatasheet STM32F411", "pdf"),
    ("README.md", "# Robot\nMô tả", "readme"),
    ("d.h", "#ifndef X\n#define X 1\n#endif", "header"),
    ("e.md", "# ghi chú", "md"),
])
def test_TC01_phan_loai_dung(tmp_path, ten, noi_dung, kind):
    """tc TC-01: "≥ 95% đúng trên bộ 10 tệp"."""
    p = tmp_path / ten
    p.write_text(noi_dung, encoding="utf-8")
    assert _nhan_dang(p)[0] == kind


def test_confidence_noi_that_ve_can_cu(tmp_path, du_an):
    """Một bảng phân loại toàn `confidence: 1.0` thì cột ấy vô dụng. Chữ ký nội dung khẳng định
    thì 1.0; chỉ có phần mở rộng làm chứng thì thấp hơn."""
    r, ctx, _ = du_an
    a = tmp_path / "a.svd"
    a.write_text(SVD, encoding="utf-8")
    b = tmp_path / "b.dts"
    b.write_text("/dts-v1/;\n/ { };", encoding="utf-8")
    out = r.invoke("ingest.classify", {"files": [str(a), str(b)]}, ctx).result["classification"]
    theo = {x["kind"]: x for x in out}
    assert theo["svd"]["confidence"] == 1.0
    assert theo["binding"]["confidence"] < 1.0


def test_tier_va_extractor_theo_bang_buoc_2(tmp_path, du_an):
    """Bước 2: "svd/atdf/edc/binding/header: gold; pdf hãng: silver". `tier` gán ở đây quyết
    định sau này fact có tự qua G-FACT hay phải hỏi người."""
    r, ctx, _ = du_an
    a = tmp_path / "a.svd"
    a.write_text(SVD, encoding="utf-8")
    b = tmp_path / "b.pdf"
    b.write_text("%PDF-1.7 Datasheet", encoding="utf-8")
    out = {x["kind"]: x for x in
           r.invoke("ingest.classify", {"files": [str(a), str(b)]}, ctx).result["classification"]}
    assert (out["svd"]["tier"], out["svd"]["extractor"]) == ("gold", "extract.svd")
    assert out["pdf"]["tier"] == "silver"


def test_docx_khong_bi_xep_nham_thanh_archive(tmp_path):
    """docx/xlsx cũng là zip. Không phân biệt thì một .docx bị đẩy sang `archive.list` và người
    dùng nhận về danh sách `word/document.xml` thay vì nội dung tài liệu."""
    import zipfile
    p = tmp_path / "a.docx"
    with zipfile.ZipFile(p, "w") as z:
        z.writestr("[Content_Types].xml", "<x/>")
        z.writestr("word/document.xml", "<x/>")
    assert _nhan_dang(p)[0] == "docx"


# ---------- ARCHIVE-06 ingest.hash_dedupe


def test_tep_da_co_thi_bao_dup_kem_source_id(tmp_path, du_an):
    """tc: "Tệp đã có → dup kèm source_id". Cùng một datasheet tải hai lần vào hai chỗ là cùng
    một nguồn; trích lại lần hai sinh ra một bộ fact trùng, mỗi cái là một mục nữa phải duyệt."""
    r, ctx, root = du_an
    p = tmp_path / "ds.pdf"
    p.write_text("%PDF-1.7 nội dung", encoding="utf-8")
    _nguon(root, "s_cu", bam_tep(p))
    out = r.invoke("ingest.hash_dedupe", {"files": [str(p)]}, ctx).result
    assert out["new"] == []
    assert out["dup"][0]["source_id"] == "s_cu"


def test_hai_ban_sao_trong_cung_lo_cung_la_trung(tmp_path, du_an):
    """Nếu chỉ so với store thì hai bản sao trong CÙNG lô đều lọt vào `new`, và bước sau trích
    cùng một tệp hai lần."""
    r, ctx, _ = du_an
    a = tmp_path / "a.pdf"
    a.write_text("%PDF giống nhau", encoding="utf-8")
    b = tmp_path / "b.pdf"
    b.write_text("%PDF giống nhau", encoding="utf-8")
    out = r.invoke("ingest.hash_dedupe", {"files": [str(a), str(b)]}, ctx).result
    assert len(out["new"]) == 1 and len(out["dup"]) == 1


def test_bam_theo_noi_dung_khong_theo_ten(tmp_path):
    a = tmp_path / "x.bin"
    a.write_bytes(b"abc")
    b = tmp_path / "y.bin"
    b.write_bytes(b"abc")
    assert bam_tep(a) == bam_tep(b)


# ---------- ARCHIVE-07 ingest.index_text


def test_chi_lap_chi_muc_tai_lieu_ngu_canh(tmp_path, du_an):
    """Bước 1: "CHỈ tài liệu ngữ cảnh (README, ghi chú)". Đổ datasheet vào FTS5 sẽ khiến
    `memory.retrieve` trả về đoạn văn không trích dẫn được, cạnh tranh chỗ với fact CÓ trích
    dẫn — và bên gọi không phân biệt được hai loại."""
    r, ctx, _ = du_an
    rm = tmp_path / "README.md"
    rm.write_text("# Robot\n\nRobot hai bánh tự cân bằng dùng MPU6050.\n", encoding="utf-8")
    svd = tmp_path / "a.svd"
    svd.write_text(SVD, encoding="utf-8")
    n = r.invoke("ingest.index_text", {"files": [str(rm), str(svd)]}, ctx).result["indexed"]
    assert n >= 1
    from eide_core.rag import RagIndex
    assert RagIndex(ctx.project_dir).tim("MPU6050")


# ---------- EXTRACT-01 extract.svd (TC-09)


def test_TC09_svd_sinh_fact_va_ghi_ho_chieu(du_an, svd_file):
    r, ctx, root = du_an
    out = r.invoke("extract.svd", {"file": str(svd_file)}, ctx).result
    assert out["part"] == "chip:stmicroelectronics.stm32f411"
    assert out["n_facts"] > 10
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM passport").fetchone()[0] == 1
        assert c.execute("SELECT COUNT(*) FROM passport_fact").fetchone()[0] == out["n_facts"]


def _gia_tri(root, subject, predicate):
    with store.open_store(store.store_path(root)) as c:
        rs = c.execute("SELECT value FROM fact WHERE subject=? AND predicate=?",
                       (subject, predicate)).fetchall()
    return [json.loads(x[0]) for x in rs]


def test_derivedFrom_ke_thua_thanh_ghi(du_an, svd_file):
    """`I2C2` chỉ khai `baseAddress` rồi kế thừa toàn bộ thanh ghi từ `I2C1`. Không giải thì
    I2C2 có đúng một fact — và mã sinh cho I2C2 không biết CR1 nằm ở đâu."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    part = "chip:stmicroelectronics.stm32f411"
    assert _gia_tri(root, f"{part}/periph:I2C2", "base_address") == [0x40005800]
    assert _gia_tri(root, f"{part}/periph:I2C2/reg:CR1", "offset") == [0]


def test_dim_gian_thanh_bon_thanh_ghi(du_an, svd_file):
    """`<dim>4</dim>` với `dimIncrement 0x20`: DR0..DR3 ở 0x40, 0x60, 0x80, 0xA0. Không giãn thì
    bốn kênh thành một."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    part = "chip:stmicroelectronics.stm32f411/periph:I2C1"
    off = [_gia_tri(root, f"{part}/reg:DR{i}", "offset") for i in range(4)]
    assert off == [[0x40], [0x60], [0x80], [0xA0]]


def test_cluster_cong_don_offset(du_an, svd_file):
    """Cluster CH ở 0x100, thanh ghi CH_CFG ở 0x08 ⇒ 0x108. Quên cộng thì mọi thanh ghi trong
    cluster trỏ sai địa chỉ."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    assert _gia_tri(root, "chip:stmicroelectronics.stm32f411/periph:I2C1/reg:CH_CFG",
                    "offset") == [0x108]


def test_enum_giu_y_nghia_tung_gia_tri(du_an, svd_file):
    """Đây là thứ làm khác biệt giữa "bit 3" và "bit 3 = 1 nghĩa là bật"."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    e = _gia_tri(root, "chip:stmicroelectronics.stm32f411/periph:I2C1/reg:CR1/field:PE", "enum")
    assert {"name": "Enabled", "value": 1} in e


@pytest.mark.parametrize(("truong", "dai"), [("PE", [0, 0]), ("SPE", [3, 4])])
def test_bit_range_doc_duoc_ca_hai_cach_khai(du_an, svd_file, truong, dai):
    """SVD cho ba cách khai vị trí bit (`bitRange`, `lsb/msb`, `bitOffset/bitWidth`). Đọc thiếu
    một cách nghĩa là mất trường của cả một họ chip."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    part = "chip:stmicroelectronics.stm32f411/periph:I2C1/reg:CR1"
    assert _gia_tri(root, f"{part}/field:{truong}", "bit_range") == [dai]


def test_ram_tu_svd_dung_duoc_cho_arch(du_an, svd_file):
    """Khép vòng: fact `memory_size` sinh ở đây chính là thứ `arch.style_select` đọc để quyết
    có được dùng RTOS không."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    assert _gia_tri(root, "chip:stmicroelectronics.stm32f411/mem:RAM", "memory_size") == [0x20000]
    from eide.caps.arch import _ram_tu_passport
    assert _ram_tu_passport(root, "stmicroelectronics.stm32f411@1.0.0") == 0x20000


def test_svd_cong_dong_la_silver(du_an, tmp_path):
    """"*-Community → silver": tệp không phải của hãng không được hưởng quyền tự duyệt của
    tầng vàng ở cổng G-FACT."""
    r, ctx, root = du_an
    p = tmp_path / "STM32F411-Community.svd"
    p.write_text(SVD, encoding="utf-8")
    r.invoke("extract.svd", {"file": str(p)}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert {x[0] for x in c.execute("SELECT DISTINCT tier FROM fact")} == {"silver"}


def test_svd_hong_bao_E6001_chu_khong_sinh_fact_rong(du_an, tmp_path):
    r, ctx, _ = du_an
    p = tmp_path / "hong.svd"
    p.write_text("<device><peripherals>", encoding="utf-8")
    run = r.invoke("extract.svd", {"file": str(p)}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E6001"


def test_khong_doc_duoc_so_thi_khong_sinh_fact(du_an, tmp_path):
    """`_so` trả None chứ không trả 0: 0x00000000 là địa chỉ hợp lệ (vector table), nên dùng 0
    làm giá trị "không đọc được" sẽ sinh fact `base_address = 0` trông hoàn toàn bình thường."""
    from eide.caps.extract import _so
    assert _so("không phải số") is None
    assert _so("0x00000000") == 0
    assert _so("#0101") == 5
    assert _so("2k") == 2048


# ---------- EXTRACT-02 extract.atdf (TC-10)


def test_TC10_atdf_sinh_fact(du_an, tmp_path):
    """Năng lực đầu tiên trong kho chạm tới AVR (xem DEV-055)."""
    r, ctx, root = du_an
    p = tmp_path / "ATmega328P.atdf"
    p.write_text(ATDF, encoding="utf-8")
    out = r.invoke("extract.atdf", {"file": str(p)}, ctx).result
    assert out["n_facts"] > 3
    part = "chip:microchip.atmega328p"
    assert _gia_tri(root, f"{part}/mem:FLASH", "memory_size") == [0x8000]
    assert _gia_tri(root, f"{part}/periph:TWI", "irq") == [24]


def test_atdf_mask_doi_thanh_bit_range(du_an, tmp_path):
    """ATDF khai bit bằng mặt nạ, SVD khai bằng dải. Đổi sang CÙNG vị từ `bit_range` để `kg.*`
    không phải biết fact này từ parser nào — mask 0x04 là bit 2, mask 0x03 là bit 0–1."""
    r, ctx, root = du_an
    p = tmp_path / "a.atdf"
    p.write_text(ATDF, encoding="utf-8")
    r.invoke("extract.atdf", {"file": str(p)}, ctx)
    reg = "chip:microchip.atmega328p/periph:TWI/reg:TWCR"
    assert _gia_tri(root, f"{reg}/field:TWEN", "bit_range") == [[2, 2]]
    assert _gia_tri(root, f"{reg}/field:TWPS", "bit_range") == [[0, 1]]


def test_atdf_offset_cong_nen_cua_segment(du_an, tmp_path):
    """TWCR offset 0x36 trong segment MAPPED_IO bắt đầu ở 0x20 ⇒ 0x56 — địa chỉ thật trên
    ATmega328P."""
    r, ctx, root = du_an
    p = tmp_path / "a.atdf"
    p.write_text(ATDF, encoding="utf-8")
    r.invoke("extract.atdf", {"file": str(p)}, ctx)
    assert _gia_tri(root, "chip:microchip.atmega328p/periph:TWI/reg:TWCR",
                    "offset") == [0x36 + 0x20]


# ---------- PASSPORT-01 import: bảng gộp KAD-07 §5.1


def test_cung_gia_tri_thi_gop_khong_tao_fact_moi(du_an):
    """Dòng 1: "Trùng lặp: giữ fact hiện hành, thêm liên kết hộ chiếu, KHÔNG tạo fact mới"."""
    r, ctx, root = du_an
    _nguon(root)
    f = _fact("chip:x/periph:I2C1", "base_address", 0x40005400)
    r.invoke("passport.import", {"batch": {"facts": [f]}, "actor": "agent"}, ctx)
    out = r.invoke("passport.import", {"batch": {"facts": [f]}, "actor": "agent"}, ctx).result
    assert (out["written"], out["merged"], out["conflicts"]) == (0, 1, 0)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 1


def test_thu_tu_khoa_JSON_khong_lam_ra_xung_dot_gia(du_an):
    """`{"a":1,"b":2}` và `{"b":2,"a":1}` là cùng một giá trị. So chuỗi thô sẽ đẩy người dùng đi
    giải quyết một xung đột không tồn tại."""
    r, ctx, root = du_an
    _nguon(root)
    a = _fact("chip:x/periph:P", "enum", {"a": 1, "b": 2})
    b = _fact("chip:x/periph:P", "enum", {"b": 2, "a": 1})
    r.invoke("passport.import", {"batch": {"facts": [a]}, "actor": "agent"}, ctx)
    out = r.invoke("passport.import", {"batch": {"facts": [b]}, "actor": "agent"}, ctx).result
    assert out["conflicts"] == 0 and out["merged"] == 1


def test_TC16_tier_cao_hon_thi_thay_the(du_an):
    """Dòng 2: "Fact mới thay thế (supersedes); fact cũ → superseded"."""
    r, ctx, root = du_an
    _nguon(root)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:I2C1", "base_address", 0x1000, tier="silver")]},
        "actor": "agent"}, ctx)
    out = r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:I2C1", "base_address", 0x2000, tier="gold")]},
        "actor": "agent"}, ctx).result
    assert (out["written"], out["conflicts"]) == (1, 0)
    with store.open_store(store.store_path(root)) as c:
        rows = dict(c.execute("SELECT tier, status FROM fact").fetchall())
    assert rows == {"silver": "superseded", "gold": "normalized"}


def test_supersedes_tro_ve_fact_cu(du_an):
    """Cột `supersedes` là đường truy nguyên duy nhất sau khi fact cũ chuyển `superseded` —
    để trống thì lịch sử đứt."""
    r, ctx, root = du_an
    _nguon(root)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:P", "offset", 1, tier="bronze")]}, "actor": "agent"}, ctx)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:P", "offset", 2, tier="gold")]}, "actor": "agent"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        moi = c.execute("SELECT supersedes FROM fact WHERE tier='gold'").fetchone()[0]
        cu = c.execute("SELECT id FROM fact WHERE tier='bronze'").fetchone()[0]
    assert moi == cu


def test_TC13_cung_tier_gia_tri_khac_thi_conflict_chu_khong_de(du_an):
    """Dòng 3, và là dòng dễ làm sai nhất. Cám dỗ là để fact mới cùng tier ghi đè ("mới hơn thì
    đúng hơn"). Nhưng hai nguồn cùng tầng nói khác nhau về CÙNG một thanh ghi là thông tin: một
    trong hai sai, và im lặng chọn cái mới thì quăng mất bằng chứng rằng có gì đó không khớp."""
    r, ctx, root = du_an
    _nguon(root)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:I2C1", "base_address", 0x1000)]}, "actor": "agent"}, ctx)
    out = r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:I2C1", "base_address", 0x9999)]}, "actor": "agent"}, ctx).result
    assert (out["written"], out["conflicts"]) == (0, 1)
    with store.open_store(store.store_path(root)) as c:
        assert sorted(x[0] for x in c.execute("SELECT status FROM fact")) == \
               ["conflict", "normalized"]


def test_gold_khong_bao_gio_bi_tier_thap_ghi_de(du_an):
    """Quy tắc R1 của KAD-07: fact tầng vàng của hãng KHÔNG BAO GIỜ bị ghi đè bởi tầng thấp hơn."""
    r, ctx, root = du_an
    _nguon(root)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:P", "offset", 0x10, tier="gold")]}, "actor": "agent"}, ctx)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:P", "offset", 0x99, tier="bronze")]}, "actor": "agent"}, ctx)
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT status FROM fact WHERE tier='gold'").fetchone()[0] == "normalized"
        assert c.execute("SELECT status FROM fact WHERE tier='bronze'").fetchone()[0] == "conflict"


def test_kiem_schema_truoc_khi_ghi_dong_nao(du_an):
    """Ghi được nửa lô rồi mới phát hiện fact thứ 300 sai sẽ để store ở trạng thái nửa vời: một
    hộ chiếu 299 fact trông như đã nạp xong."""
    r, ctx, root = du_an
    _nguon(root)
    tot = _fact("chip:x/periph:A", "offset", 1)
    hong = _fact("chip:x/periph:B", "khong_co_vi_tu_nay", 2)
    run = r.invoke("passport.import", {"batch": {"facts": [tot, hong]}, "actor": "agent"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E6001"
    with store.open_store(store.store_path(root)) as c:
        assert c.execute("SELECT COUNT(*) FROM fact").fetchone()[0] == 0


def test_lo_rong_bao_E6001(du_an):
    r, ctx, _ = du_an
    run = r.invoke("passport.import", {"batch": {"facts": []}, "actor": "agent"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E6001"


def test_import_ghi_ledger_store_write(du_an):
    """SDD-04 §4.1 gọi đây là "CỔNG GHI DUY NHẤT: kiểm schema, merge, ledger". Không ghi ledger
    thì fact vào store mà không ai truy nguyên được ai đưa vào lúc nào."""
    r, ctx, root = du_an
    _nguon(root)
    r.invoke("passport.import", {"batch": {"facts": [_fact("chip:x/periph:P", "offset", 1)],
                                           "reason": "thử"}, "actor": "agent"}, ctx)
    recs = [x for x in r.ledger.records() if x["kind"] == "store.write"]
    assert recs and recs[-1]["data"]["n_facts"] == 1
    assert r.ledger.verify() == (True, 0)


# ---------- PASSPORT-02 query (TC-15)


def test_TC15_query_theo_part_tra_ca_cay_con(du_an, svd_file):
    """Lọc theo TIỀN TỐ IRI, không so bằng: hỏi về một chip phải trả cả fact của ngoại vi và
    thanh ghi bên trong. So bằng thì câu hỏi "chip này có gì" trả về đúng một fact."""
    r, ctx, _ = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    out = r.invoke("passport.query", {"part": "stmicroelectronics.stm32f411"}, ctx).result
    assert len(out["facts"]) > 10
    assert any("/reg:" in f["subject"] for f in out["facts"])


def test_query_loc_theo_ngoai_vi(du_an, svd_file):
    r, ctx, _ = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    out = r.invoke("passport.query",
                   {"part": "stmicroelectronics.stm32f411", "peripheral": "I2C2"}, ctx).result
    assert out["facts"] and all("I2C2" in f["subject"] for f in out["facts"])


def test_query_tra_citations_va_tiers(du_an, svd_file):
    """`citations` tách khỏi `facts` để bên gọi KHÔNG phải tự nối fact với nguồn: `req.ground_hw`
    cần trả lời "vì sao anh nói ADC đạt 2,4 MSPS" kèm số hiệu tài liệu."""
    r, ctx, _ = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    out = r.invoke("passport.query", {"part": "stmicroelectronics.stm32f411"}, ctx).result
    assert out["citations"] and out["citations"][0]["uri"].endswith(".svd")
    assert out["tiers"]["gold"] == len(out["facts"])


def test_query_khong_tra_fact_superseded(du_an):
    """Mặc định chỉ trả fact hiện hành. Trả cả bản đã bị thay thế nghĩa là bên gọi nhận hai giá
    trị cho cùng một thanh ghi và không biết chọn cái nào."""
    r, ctx, root = du_an
    _nguon(root)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:P", "offset", 1, tier="silver")]}, "actor": "agent"}, ctx)
    r.invoke("passport.import", {"batch": {"facts": [
        _fact("chip:x/periph:P", "offset", 2, tier="gold")]}, "actor": "agent"}, ctx)
    out = r.invoke("passport.query", {"part": "x"}, ctx).result
    assert [f["value"] for f in out["facts"]] == [2]
    lich_su = r.invoke("passport.query", {"part": "x", "include_history": True}, ctx).result
    assert len(lich_su["facts"]) == 2


def test_query_do_va_tra_latency(du_an, svd_file):
    """`latency_ms` nằm trong hợp đồng. Bước 1 đòi < 200 ms — `passport.query` nằm trong vòng
    lặp của `req.ground_hw` và `arch.*`, nên chậm ở đây là chậm ở mọi nơi."""
    from eide.caps.passport import NGUONG_MS
    r, ctx, _ = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    out = r.invoke("passport.query", {"part": "stmicroelectronics.stm32f411"}, ctx).result
    assert out["latency_ms"] < NGUONG_MS


# ---------- PASSPORT-03 list / PASSPORT-07 export


def test_list_dem_dung_so_fact(du_an, svd_file):
    r, ctx, _ = du_an
    n = r.invoke("extract.svd", {"file": str(svd_file)}, ctx).result["n_facts"]
    ds = r.invoke("passport.list", {}, ctx).result["passports"]
    assert len(ds) == 1 and ds[0]["n_facts"] == n
    assert ds[0]["kind"] == "chip"


def test_export_nap_lai_duoc(du_an, svd_file):
    """tc: "Tệp nạp lại được" — bản xuất phải là FactBatch hợp lệ cho `passport.import`, không
    phải một định dạng riêng."""
    r, ctx, _ = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    pid = "stmicroelectronics.stm32f411@1.0.0"
    f = r.invoke("passport.export", {"id": pid, "format": "json"}, ctx).result["file"]
    from pathlib import Path
    d = json.loads(Path(f).read_text(encoding="utf-8"))
    assert d["facts"] and set(d["facts"][0]) >= {"subject", "predicate", "value", "source_id",
                                                 "method", "tier"}
    from eide.caps.passport import _kiem_schema
    _kiem_schema(d["facts"])          # nạp lại được = qua đúng phép kiểm của import


def test_export_khong_nhung_tai_lieu_chi_tro_con_tro(du_an, svd_file):
    """Bước 1: "Xuất fact + Source CON TRỎ (không PDF)". Nhúng cả datasheet vừa phình tệp vừa
    phát tán lại tài liệu có bản quyền; `uri + sha256` đủ để người nhận tự lấy và kiểm."""
    r, ctx, _ = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    f = r.invoke("passport.export", {"id": "stmicroelectronics.stm32f411@1.0.0",
                                     "format": "json"}, ctx).result["file"]
    from pathlib import Path
    d = json.loads(Path(f).read_text(encoding="utf-8"))
    assert d["sources"][0]["sha256"]
    assert "content" not in d["sources"][0] and "data" not in d["sources"][0]


def test_export_ho_chieu_la_bao_E2000(du_an):
    r, ctx, _ = du_an
    run = r.invoke("passport.export", {"id": "khong.co@1.0.0"}, ctx)
    assert run.status == "failed" and run.error["eide_code"] == "E2000"


# ---------- khép vòng: SVD → req.ground_hw


def test_chuoi_day_du_svd_toi_ground_hw(du_an, svd_file):
    """Đây là lý do nhóm này tồn tại. Trước nó, `req.ground_hw` đọc bảng `fact` mà không có
    đường nào đưa fact vào ngoài chèn tay — tức mọi kết luận khả thi đều dựa trên dữ liệu do
    người gõ."""
    r, ctx, root = du_an
    r.invoke("extract.svd", {"file": str(svd_file)}, ctx)
    with store.open_store(store.store_path(root)) as c:
        c.execute("UPDATE fact SET status='verified' WHERE predicate='memory_size'")
        c.commit()
    from eide.caps.req import _ghi_requirement
    _ghi_requirement(root, [{"id": "UR-SNS-01", "kind": "HW",
                             "text": "Bộ nhớ RAM tối thiểu 64 kb cho vùng đệm"}])
    rep = r.invoke("req.ground_hw",
                   {"reqset_ids": ["UR-SNS-01"],
                    "passport": "stmicroelectronics.stm32f411@1.0.0"}, ctx).result["report"]
    assert rep[0]["ok"] is True, rep
    assert rep[0]["facts"], "kết luận phải kèm fact id để truy nguyên"
