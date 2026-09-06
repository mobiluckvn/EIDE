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
01_SRS_GEditor_macOS_v1.7.docx
    Đặc tả yêu cầu (IEEE 830): 82 yêu cầu chức năng (FR-*) +
    31 phi chức năng (NFR-*), ưu tiên P0/P1/P2, phân bổ Phase 1/2/3;
    Phụ lục D: Knowledge Pack Phase 4 (12 FR + 2 NFR) — phân tích/thiết kế
    Graph, RAG, GraphRAG dưới dạng plugin, KHÔNG chạm lõi Phase 1-3.
    => Đây là "luật". Mọi mã FR/NFR ở các tài liệu khác trỏ về đây.

02_SAD_GEditor_macOS_v1.8.docx
    Kiến trúc (ISO 42010, view 4+1): kiến trúc 4 lớp, 16 module,
    10 quyết định ADR (engine, buffer, regex, XPC...), API surface
    cho scripting/plugin, kế hoạch PoC tuần 1-4.
    => Đọc kỹ Chương 3 (ADR) và Chương 8 (PoC) trước khi viết code.

03_STP_GEditor_macOS_v1.8.docx
    Kế hoạch kiểm thử (IEEE 829): 57 test case đại diện, fixtures,
    KPI hiệu năng có ngưỡng Pass, tiêu chí phát hành từng Phase.
    => Benchmark NFR-PERF là bước CHẶN MERGE trong CI.

04_UIUX_GEditor_macOS_v1.8.html
    Đặc tả UI/UX — mở bằng trình duyệt. 7 mockup HTML/CSS dựng đúng
    design token, có nút chuyển Sáng/Tối. Keymap chuẩn ở mục 9.
    => Mockup là tham chiếu trực quan; giá trị pt/px trong bảng là chuẩn.

05_RTM_RaSoat_DongBo_GEditor_v1.8.xlsx
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
- Knowledge Pack (Phase 4): thiết kế đã đồng bộ đủ 4 tài liệu ngay từ đầu
  (SRS Phụ lục D - SAD Chương 9 + ADR-11 - STP suite TC-KNW - UI/UX mục 14).
  RANH GIỚI CỨNG của Pack: không embedding, không vector DB, không gọi LLM,
  không agent runtime - chỉ là tầng chuẩn bị & kiểm dữ liệu tri thức.
  Zero-cost khi tắt: TC-KNW-07 là bài bắt buộc khi phát hành Pack.
- Agent Pack (Phase 5, BYOK): SRS Phụ lục E - SAD Chương 10 + ADR-12 -
  STP suite TC-AGT - UI/UX mục 15. Người dùng tự nhập key (LƯU KEYCHAIN,
  không bao giờ nằm trong file cấu hình/log - TC-AGT-01 là bài CHẶN
  PHÁT HÀNH) và chọn model. Agent hành động qua Editor API nên xử lý
  được file hàng GB không cần nạp context. Ba lớp phanh: cổng diff duyệt,
  checkpoint hoàn tác cả phiên, quyền cấp theo phiên. Không proxy qua
  máy chủ MOBILUCK; Ollama local = hoạt động offline hoàn toàn.
- Làm sạch & chuẩn hóa dữ liệu (FR-CLN, Phase 2-4): SRS 3.2.10 -
  SAD DataCleanService/RecipeEngine/FuzzyDeduper - STP TC-CLN-01...06 -
  UI/UX 6.2 "Bàn làm sạch". Gồm: chuẩn hóa ngày/số theo cột, xử lý null,
  Data Profile (thay FR-CSV-408, kéo lên Phase 2), fuzzy dedup (Phase 4),
  Cleaning Recipe chạy batch/CLI. Bất biến NFR-CLN-02: mọi thao tác làm
  sạch phải có preview + 1 bước undo + báo cáo.
- Truy vấn & phân tích (FR-QRY, Phase 2-3): SRS 3.2.11 - SAD
  QueryWorkbench/VirtualCatalog/ChartRenderer/FilterBar - STP
  TC-QRY-01...06 - UI/UX 6.3. Gồm: filter theo cột không cần SQL,
  Query Workbench hợp nhat (thay console FR-CSV-407), Pivot keo-tha
  sinh SQL xem duoc, Quick Charts co downsample, join da file (bang ao),
  saved query chay CLI. Bat bien NFR-QRY-03: moi truy van CHI-DOC -
  ket qua luon ra tab/file moi, file nguon kiem checksum khong doi.
- Visualization Report (FR-RPT, Phase 3-4): SRS 3.2.12 - SAD
  ReportEngine/ReportRenderer/BatchReporter - STP TC-RPT-01...06 -
  UI/UX 6.4. Bao cao la file .greport.md THUAN VAN BAN (Markdown +
  fenced block query/chart): diff/Git duoc, tham so hoa, chay CLI
  geditor --report, batch theo danh sach (vd 63 tinh). Xuat HTML tu
  chua / PDF (dong luon khoang trong FR-DOC-313 In an) / Markdown.
  NFR-RPT-02: report chi-doc voi nguon; khong BI server/cloud.

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
