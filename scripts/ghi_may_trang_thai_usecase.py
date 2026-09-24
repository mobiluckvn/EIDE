"""Ghi thiết kế MÁY TRẠNG THÁI v1.3 vào `docs/Usecase_Test_Agent_Ky_Su_Nhung.xlsx`. [DEV-218]

Chủ sản phẩm chốt 24/09/2026 sau khi đọc review kiến trúc:
  (1) thiếu tiền đề → HỎI MỘT CỤM rồi mới chạy;
  (2) pha LÀM RÕ quyết định bằng MỘT lời gọi LLM khảo sát;
  (3) chốt phạm vi khi `is_big` hoặc chuỗi > 7 nút;
  (4) chi tiết viết vào chính file usecase.

Script sinh lại được: chạy nhiều lần thì ghi đè đúng phần của nó, không đụng phần khác.
"""
from __future__ import annotations

from pathlib import Path

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill

GOC = Path(__file__).resolve().parent.parent
XLSX = GOC / "docs/Usecase_Test_Agent_Ky_Su_Nhung.xlsx"

TEN_SHEET = "May trang thai"

#: Ngưỡng chốt phạm vi. Rút TỪ DỮ LIỆU, không chọn tròn số: 17/22 chuỗi mẫu có ≤ 7 nút
#: (việc thường), 5 chuỗi còn lại là việc lớn nhiều pha — Z-07 24 nút, Z-05 16, Z-01 14,
#: Z-10 10, P7 8. Cắt ở 7 tách đúng hai nhóm ấy mà không phải đặt tay một con số.
N_NUT_CHOT_PHAM_VI = 7

TIEU_DE = [
    "Pha", "Tên", "Việc làm", "Gọi mô hình?", "Vào", "Ra",
    "Chuyển sang", "Lỗi nó chữa (đo được)",
]

PHA = [
    ("S0", "CHẶN XÁC ĐỊNH",
     "Dừng khẩn; trỏ ngược ('làm lại', 'tiếp tục'); thao tác không đảo ngược "
     "(xoá flash, option bytes, RDP); ba trục soát yêu cầu (pháp lý / an toàn / hạ chuẩn). "
     "ĐỌC CHÍNH CÂU NGƯỜI GÕ, không đọc ý định.",
     "KHÔNG",
     "câu người dùng gõ",
     "hoặc chặn hẳn, hoặc cho đi tiếp",
     "S1",
     "Giữ nguyên. Đây là phòng thủ lớp hai — vẫn nổ kể cả khi định tuyến sai. "
     "An toàn không được nằm sau một phép đoán."),

    ("S1", "HIỂU",
     "`chat.parse_intent` → ý định + độ tự tin. ĐỔI: độ tự tin chia BA DẢI thay vì "
     "nhị phân hoá ở 0,60 rồi vứt đi.  < 0,60 → chưa hiểu, sang S3 hỏi thẳng.  "
     "0,60–0,85 → DẢI NGỜ: sang S3 và đưa cả việc xác nhận ý định vào cụm câu hỏi.  "
     "> 0,85 → sang S2.",
     "CÓ (đã có sẵn)",
     "câu người dùng gõ + ngữ cảnh phiên",
     "intent{intent, slots, is_big, confidence, mentions}",
     "S2 nếu > 0,85; S3 nếu ≤ 0,85",
     "Hiện `< 0,6 → unknown`, `≥ 0,6 → coi như chắc chắn`. Một câu đạt 0,62 và một câu "
     "đạt 0,98 đi cùng một đường, không có dải giữa nào để ngờ."),

    ("S2", "KIỂM KÊ",
     "Đọc store một lượt, dựng bảng 'dự án ĐANG CÓ GÌ': số yêu cầu · số module · số ADR · "
     "hộ chiếu chip đã ghim chưa (chip nào) · tài liệu đã nạp/chỉ mục (bao nhiêu, những gì) · "
     "toolchain + ISA · netlist/bo mạch · lượt chạy gần nhất. Kết quả dùng chung cho cả lượt.",
     "KHÔNG — 0 token, xác định, lặp lại được",
     "đường dẫn dự án",
     "bảng kiểm kê",
     "S3",
     "PHA MỚI. Hiện chuỗi phát hiện sự trống rỗng TỪNG NÚT MỘT lúc đang chạy. Đo TC008: "
     "`view.artifacts` trả 0 yêu cầu, chuỗi vẫn chạy tiếp style_select → decompose → "
     "interface_spec → adr → review trên tập rỗng, và mô hình BỊA ra REQ_HW_I2C, "
     "REQ_FR_READ_TEMP, REQ_FR_PRINT_UART — những mã không có trong store."),

    ("S3", "LÀM RÕ",
     "MỘT lời gọi mô hình: đưa câu người dùng + ý định + BẢNG KIỂM KÊ của S2 + tiền đề mà "
     "chuỗi mẫu cần. Mô hình chỉ quyết một việc: khoảng trống nào ĐÁNG HỎI. Trả "
     "{du_thong_tin, gaps[{khoa, cau_hoi, lua_chon, vi_sao, bat_buoc}], gia_dinh_neu_bo_qua}. "
     "Thiếu thì in MỘT CỤM câu hỏi (không hỏi lắt nhắt từng nút), chờ trả lời, trộn vào slots, "
     "quay lại S2. TỐI ĐA 2 vòng — hết vòng thì đi tiếp và NÓI RÕ giả định đang dùng.",
     "CÓ — đúng một lời gọi",
     "câu người dùng + intent + bảng kiểm kê",
     "cụm câu hỏi, hoặc 'đủ thông tin'",
     "S2 (sau khi người trả lời) hoặc S4",
     "PHA MỚI. `chat.clarify` ĐÃ hiện thực và ĐÃ được nối — nhưng nối trong "
     "`src/eide/orchestrator.py`, tệp 69 dòng KHÔNG AI IMPORT. Mã chết. Đường sống "
     "`rpc.py::_chat_send` đi thẳng ground → fill_defaults → orchestrate, không hỏi câu nào. "
     "Chính tệp chết ấy viết: 'đoán một ý định gần đúng rồi chạy còn tệ hơn thú nhận là "
     "chưa hiểu'."),

    ("S4", "CHỐT PHẠM VI",
     f"Dựng chuỗi. Nếu `is_big` HOẶC số nút > {N_NUT_CHOT_PHAM_VI}: in kế hoạch "
     "(các bước, thứ tự, ước lượng chi phí/thời gian, giả định đang dùng) rồi CHỜ người gật. "
     "Việc nhỏ: in ý hiểu rồi chạy thẳng, không chặn.",
     "KHÔNG",
     "intent đã đủ + bảng kiểm kê",
     "chuỗi + (kế hoạch chờ gật nếu việc lớn)",
     "S5",
     "`is_big` đang được ghi vào ledger rồi KHÔNG DÙNG Ở ĐÂU CẢ. 'Làm hết đi' và "
     f"'viết hàm đọc I2C' xuống cùng một đường. Ngưỡng {N_NUT_CHOT_PHAM_VI} rút từ dữ liệu: "
     "17/22 chuỗi mẫu ≤ 7 nút, 5 chuỗi lớn còn lại từ 8 đến 24 nút."),

    ("S5", "CHẠY",
     "Chạy chuỗi qua Router như hiện nay. ĐỔI: một nút hỏng vì THIẾU TIỀN ĐỀ (khác với hỏng "
     "vì lỗi thật) thì quay về S3 để hỏi, thay vì chết tại chỗ — có chặn số vòng. "
     "Nút `on_ask: skip` hỏng vẫn không kéo cả lượt xuống (DEV-216).",
     "CÓ — theo từng nút",
     "chuỗi",
     "kết quả từng nút + hiện vật vào store",
     "S3 (thiếu tiền đề) hoặc S6",
     "Giữ phần DEV-216 đã sửa: chỉ nút BẮT BUỘC hỏng mới làm lượt chạy `failed`. "
     "Đo được 11 ca thôi bị tuyên hỏng oan."),

    ("S6", "BÁO CÁO",
     "`chat.report_back`: đã làm gì, bỏ gì và vì sao, giả định nào đang dùng, hoàn tác được "
     "tới đâu, hết bao nhiêu tiền. Giả định phải in RA — không để nằm ngầm trong hiện vật.",
     "CÓ",
     "báo cáo lượt chạy",
     "câu trả lời cho người",
     "kết thúc lượt",
     "Giữ nguyên, thêm mục 'giả định đang dùng' lấy từ `gia_dinh_neu_bo_qua` của S3."),
]

GHI_CHU = [
    ("NGUYÊN TẮC 1", "Kiểm kê thì XÁC ĐỊNH, phán đoán thì mới gọi mô hình.",
     "S2 đọc store ra bảng 'có gì' — 0 token, chạy lại cho cùng kết quả. Mô hình ở S3 chỉ "
     "quyết 'khoảng trống nào đáng hỏi', KHÔNG tự mô tả tình trạng dự án. Để mô hình tự "
     "đoán dự án có gì là mở lại đúng cửa đã sinh ra REQ_HW_I2C bịa ở TC008."),
    ("NGUYÊN TẮC 2", "Hỏi MỘT CỤM, không hỏi lắt nhắt.",
     "Gom mọi khoảng trống của cả chuỗi vào một lần hỏi. Đo 23/09: chuỗi hỏi 'Đọc những tệp "
     "nào?' ở `ingest.classify` rồi hỏi lại y hệt ở `ingest.index_text` — hai câu cho cùng "
     "một thứ, trong một lượt."),
    ("NGUYÊN TẮC 3", "Chặn số vòng hỏi.",
     "Tối đa 2 vòng S3. Hết vòng thì chạy với giả định và NÓI RA giả định. Một tác tử hỏi mãi "
     "cũng vô dụng ngang một tác tử đoán bừa."),
    ("NGUYÊN TẮC 4", "Mỗi pha phải lưu được trạng thái (UC19).",
     "Sự cố ở bất kỳ pha nào: dừng an toàn, ghi lại đang ở pha nào và đã biết gì, tiếp tục "
     "được khi sự cố hết."),
    ("NGOÀI PHẠM VI", "UC15 (chuẩn bị sản xuất, Gerber/DRC) — chủ sản phẩm quyết 24/09/2026 "
     "để phần PCB ra ngoài sản phẩm này.", ""),
]

#: Với mỗi usecase: S2 kiểm kê gì, và S3 hỏi gì khi thiếu.
THEO_UC = {
    "UC01": ("Đã có dự án chưa · đã có yêu cầu nào chưa",
             "CHÍNH LÀ usecase mà S3 phục vụ: mục tiêu · môi trường dùng · ràng buộc "
             "chi phí/kích thước/nguồn điện · số lượng. Hỏi một cụm, không tra tấn từng câu."),
    "UC02": ("Số yêu cầu · hộ chiếu chip đã ghim chưa · datasheet đã nạp chưa",
             "Chip đích (kèm gợi ý từ câu người dùng) · nguồn cấp · ràng buộc kích thước/giá · "
             "có nạp datasheet không hay dùng tri thức chung (nhãn tầng đồng)."),
    "UC03": ("Có module/thiết kế chưa · MCU · toolchain + ISA có trong máy không",
             "MCU nào nếu chưa ghim · toolchain ở đâu nếu thiếu · mức tối ưu/ngân sách flash."),
    "UC04": ("Đã nhập tệp thiết kế/mã nào chưa",
             "Đường dẫn tệp (ĐẦY ĐỦ) · định dạng · phần nào cần đọc trước. "
             "Không hỏi khi câu người dùng đã có đường dẫn — S2 bắt được `${_path}`."),
    "UC05": ("Probe có cắm không · hộ chiếu bo mạch · firmware đã build chưa",
             "Xác nhận bo mạch + bộ nạp. LƯU Ý: việc nạp luôn qua S0 (UC18) — xác nhận nạp "
             "KHÔNG phải câu hỏi của S3 mà là cổng an toàn, không gộp vào cụm."),
    "UC06": ("Có schematic/BOM/mã nguồn nào trong store không",
             "Rà cái nào · theo chuẩn/checklist nào · mức nghiêm khắc."),
    "UC07": ("Chỉ mục RAG có tài liệu khớp câu hỏi không",
             "Nếu KHÔNG có nguồn: nạp tài liệu, hay trả lời bằng tri thức chung có nhãn "
             "tầng đồng (K9, VIEW-15). Nếu CÓ nguồn thì không hỏi — trả lời kèm trích dẫn."),
    "UC08": ("BOM có chưa · linh kiện cần thay có trong BOM không",
             "Linh kiện nào · chấp nhận sửa mạch hay bắt buộc pin-to-pin · ngân sách. "
             "GIỚI HẠN: chưa có nguồn dữ liệu vòng đời linh kiện — nói thẳng, không đoán."),
    "UC09": ("Mã nguồn có chưa · nền tảng cũ nhận ra được không",
             "MCU/RTOS/HAL đích · giữ API cũ hay cho đổi · phạm vi chuyển."),
    "UC10": ("Có tệp log/capture/dump nào đã nạp không",
             "Đường dẫn tệp · giao thức · tốc độ/baud · triệu chứng đang thấy."),
    "UC11": ("Mã nguồn · test hiện có · bàn thử HIL có không",
             "Chạy host hay HIL · khung test nào · phạm vi cần phủ."),
    "UC12": ("Map file · ngân sách flash/RAM trong constraints.yaml · số đo hiện tại",
             "Tối ưu cái gì (bộ nhớ / tốc độ / điện) · ngân sách đích · được đổi kiến trúc không."),
    "UC13": ("Thông số nào đã có trong store (hộ chiếu, yêu cầu, fact)",
             "Đúng các số CÒN THIẾU của bài toán, kèm đơn vị. Không hỏi lại số đã có."),
    "UC14": ("Có bootloader/phân vùng/khoá chưa · dung lượng flash",
             "Mô hình đe doạ · cơ chế ký · có chỗ cho A/B không · yêu cầu chứng nhận."),
    "UC15": ("— NGOÀI PHẠM VI (quyết định 24/09/2026: phần PCB để ngoài sản phẩm này)", "—"),
    "UC16": ("Yêu cầu · thiết kế · mã · kết quả test — đủ tới đâu",
             "Tài liệu nào · theo mẫu nào · mức chi tiết. Nêu rõ phần nào chưa truy vết được."),
    "UC17": ("Dự án đang mở · lượt chạy gần nhất · điểm dừng",
             "Hiếm khi hỏi — đây là đường XÁC ĐỊNH (S0 giải 'làm lại'/'tiếp tục' bằng tra bảng "
             "`run`, không tốn token và không đoán)."),
    "UC18": ("— S0 xử lý, KHÔNG đi qua S3",
             "Xác nhận thao tác không đảo ngược là CỔNG AN TOÀN, không phải câu hỏi làm rõ. "
             "Không bao giờ gộp vào cụm S3: gộp là để một câu 'Có' trả lời cả hai thứ."),
    "UC19": ("Xuyên suốt mọi pha", "Mỗi pha ghi lại đang ở đâu và đã biết gì, để tiếp tục "
             "được sau sự cố. Quá hạn lượt (300s) thả người dùng ra và nói thật."),
}


def _dat_tieu_de(ws, hang: int, cot: int, chu: str) -> None:
    o = ws.cell(row=hang, column=cot, value=chu)
    o.font = Font(bold=True, color="FFFFFF")
    o.fill = PatternFill("solid", fgColor="2F5597")
    o.alignment = Alignment(vertical="center", wrap_text=True)


def viet_sheet_may(w) -> None:
    if TEN_SHEET in w.sheetnames:
        del w[TEN_SHEET]
    ws = w.create_sheet(TEN_SHEET, 2)

    ws.cell(row=1, column=1, value="MÁY TRẠNG THÁI XỬ LÝ MỘT LƯỢT GÕ — EIDE v1.3").font = \
        Font(bold=True, size=14)
    ws.cell(row=2, column=1,
            value="Chủ sản phẩm chốt 24/09/2026: (1) thiếu tiền đề thì HỎI MỘT CỤM rồi mới "
                  "chạy; (2) pha LÀM RÕ quyết bằng một lời gọi LLM khảo sát; "
                  f"(3) chốt phạm vi khi is_big hoặc chuỗi > {N_NUT_CHOT_PHAM_VI} nút.")
    ws.cell(row=3, column=1,
            value="Đường hiện tại (rpc.py::_chat_send): chặn xác định → parse_intent → ground "
                  "→ fill_defaults → orchestrate → CHẠY. Không có cổng làm rõ nào.")

    for i, t in enumerate(TIEU_DE, 1):
        _dat_tieu_de(ws, 5, i, t)
    for j, hang in enumerate(PHA, 6):
        for i, v in enumerate(hang, 1):
            o = ws.cell(row=j, column=i, value=v)
            o.alignment = Alignment(vertical="top", wrap_text=True)
            if i == 1:
                o.font = Font(bold=True)

    r = 6 + len(PHA) + 2
    ws.cell(row=r, column=1, value="NGUYÊN TẮC VÀ GIỚI HẠN").font = Font(bold=True, size=12)
    for j, (ma, tieu, giai) in enumerate(GHI_CHU, r + 1):
        ws.cell(row=j, column=1, value=ma).font = Font(bold=True)
        o = ws.cell(row=j, column=2, value=tieu)
        o.alignment = Alignment(vertical="top", wrap_text=True)
        o2 = ws.cell(row=j, column=3, value=giai)
        o2.alignment = Alignment(vertical="top", wrap_text=True)

    for cot, rong in zip("ABCDEFGH", (6, 18, 62, 16, 26, 26, 18, 70), strict=False):
        ws.column_dimensions[cot].width = rong
    for j in range(6, 6 + len(PHA)):
        ws.row_dimensions[j].height = 120


def viet_cot_usecase(w) -> None:
    ws = w["Usecase"]
    cot_kk = ws.max_column + 1
    cot_hoi = cot_kk + 1
    # Ghi đè đúng phần của mình nếu chạy lại.
    for c in range(1, ws.max_column + 1):
        if str(ws.cell(row=1, column=c).value or "").startswith("S2 kiểm kê"):
            cot_kk, cot_hoi = c, c + 1
            break
    _dat_tieu_de(ws, 1, cot_kk, "S2 kiểm kê gì (không tốn token)")
    _dat_tieu_de(ws, 1, cot_hoi, "S3 hỏi gì khi thiếu (một cụm)")
    for r in range(2, ws.max_row + 1):
        ma = str(ws.cell(row=r, column=1).value or "")
        if ma in THEO_UC:
            kk, hoi = THEO_UC[ma]
            for c, v in ((cot_kk, kk), (cot_hoi, hoi)):
                o = ws.cell(row=r, column=c, value=v)
                o.alignment = Alignment(vertical="top", wrap_text=True)
    from openpyxl.utils import get_column_letter
    ws.column_dimensions[get_column_letter(cot_kk)].width = 52
    ws.column_dimensions[get_column_letter(cot_hoi)].width = 62


def main() -> int:
    w = openpyxl.load_workbook(XLSX)
    viet_sheet_may(w)
    viet_cot_usecase(w)
    w.save(XLSX)
    print(f"đã ghi {XLSX.name}: sheet '{TEN_SHEET}' ({len(PHA)} pha) "
          f"+ 2 cột mới trên sheet Usecase ({len(THEO_UC)} usecase)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
