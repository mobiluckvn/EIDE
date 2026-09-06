================================================================
BỘ TÀI LIỆU DỰ ÁN MOBITEXT FOR MACOS — v1.1 (19/08/2026)
CÔNG TY TNHH MOBILUCK · code247.ai · Nội bộ
================================================================

Sản phẩm: GEditor — trình soạn thảo file text/CSV hàng Gigabyte cho macOS,
năng lực tương đương Notepad++,
Universal Binary (Intel x86_64 + Apple Silicon arm64), Swift + AppKit,
lõi C++/Swift độc lập UI.

----------------------------------------------------------------
DANH SÁCH FILE (đọc theo đúng thứ tự này)
----------------------------------------------------------------
01_SRS_GEditor_macOS_v1.2.docx
    Đặc tả yêu cầu (IEEE 830): 82 yêu cầu chức năng (FR-*) +
    31 phi chức năng (NFR-*), ưu tiên P0/P1/P2, phân bổ Phase 1/2/3.
    => Đây là "luật". Mọi mã FR/NFR ở các tài liệu khác trỏ về đây.

02_SAD_GEditor_macOS_v1.3.docx
    Kiến trúc (ISO 42010, view 4+1): kiến trúc 4 lớp, 16 module,
    10 quyết định ADR (engine, buffer, regex, XPC...), API surface
    cho scripting/plugin, kế hoạch PoC tuần 1-4.
    => Đọc kỹ Chương 3 (ADR) và Chương 8 (PoC) trước khi viết code.

03_STP_GEditor_macOS_v1.3.docx
    Kế hoạch kiểm thử (IEEE 829): 57 test case đại diện, fixtures,
    KPI hiệu năng có ngưỡng Pass, tiêu chí phát hành từng Phase.
    => Benchmark NFR-PERF là bước CHẶN MERGE trong CI.

04_UIUX_GEditor_macOS_v1.3.html
    Đặc tả UI/UX — mở bằng trình duyệt. 7 mockup HTML/CSS dựng đúng
    design token, có nút chuyển Sáng/Tối. Keymap chuẩn ở mục 9.
    => Mockup là tham chiếu trực quan; giá trị pt/px trong bảng là chuẩn.

05_RTM_RaSoat_DongBo_GEditor_v1.3.xlsx
    Ma trận rà soát đồng bộ 4 tài liệu: trạng thái từng yêu cầu,
    findings, danh sách hành động còn lại (A-04, A-07...A-10).
    => Lọc cột "Trạng thái" để biết mục nào còn thiếu tài liệu.

----------------------------------------------------------------
TRẠNG THÁI ĐỒNG BỘ (sau khắc phục v1.1)
----------------------------------------------------------------
- 100% yêu cầu P0 đã "Đồng bộ đủ" ở cả 4 tài liệu (0 khoảng trống P0).
- Còn 24 FR "thiếu một phần" + 6 FR "thiếu" — toàn bộ là P1/P2 của
  Phase 2/3, đã có hành động và thời hạn trong sheet "Hành động khắc phục".
- Các việc tài liệu còn lại trước Phase 2: A-04 (UI công cụ JSON/XML/MD),
  A-08 (đợt TC P1), A-09 (Style Configurator), A-10 (regex explainer).

----------------------------------------------------------------
BẮT ĐẦU CODE TỪ ĐÂU (tuần 1-4 — theo SAD Chương 8)
----------------------------------------------------------------
1. PoC-A: dựng song song Scintilla-Cocoa và TextKit 2, đo latency gõ
   p95 trên file 500 MB + test gõ tiếng Việt Telex (EVKey) + multi-caret
   + column mode. Kết quả chốt ADR-01.
2. PoC-B: piece table trên mmap — mở file 1 GB, dựng line index,
   sửa 10.000 vị trí, đo RAM/thời gian. Chốt ADR-02.
3. PoC-C: PCRE2 JIT hai kiến trúc — throughput 100 MB + hành vi
   deadline với pattern backtracking độc. Chốt ADR-03.
Tiêu chí Pass của từng PoC nằm trong STP mục 4.1 (TC-PERF) và
SAD mục 8. Ghi số liệu PoC vào ADR tương ứng.

Ràng buộc không thương lượng khi code:
- Main thread không I/O, không parse khối lớn (SAD 4.1).
- Mọi thao tác hàng loạt = 1 bước undo (FR-CORE-004).
- Lưu file luôn atomic: temp + rename + fsync (NFR-REL-02).
- Target Core cấm import AppKit/UI — CI sẽ chặn (NFR-MNT-01).
- IME tiếng Việt là tiêu chí CHẶN PHÁT HÀNH (NFR-USE-02, TC-IME-*).

LƯU Ý THƯƠNG HIỆU: tên CLI dùng "geditor" (KHÔNG dùng "gedit" — trùng
trình soạn thảo gedit của GNOME, rủi ro nhầm lẫn và tranh chấp tên).
Bảng màu GEditor — CAM CHỦ ĐẠO: ORANGE #ED6A1F (nhận diện, nhấn),
EMBER #A34309 (heading/chrome đậm), ACTION #C24E08 (nút chính theme sáng)
/ #FF9E5E (theme tối), GOLD #F8B942 (phụ trợ: chấm chưa lưu, banner).
Token chi tiết + selection/caret trong UI/UX mục 2 — đây là nguồn chuẩn.

Liên hệ phê duyệt thay đổi phạm vi: Vũ Trí Công (Founder).
