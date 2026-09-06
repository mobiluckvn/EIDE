import Foundation

extension HelpVI {

    static let lamSach = HelpChapter(
        id: "lam-sach",
        title: "Làm sạch dữ liệu — cả quy trình",
        summary: "Từ tệp thô người khác gửi tới bảng dùng được, và một chuẩn chạy lại được hằng tháng.",
        topics: [quyTrinhLamSach, hoSoDuLieu, banLamSach, trungLapMo, congThucLamSach,
                 chamChatLuong, cuPhapGQuality, congChatLuong]
    )

    // MARK: - Trang quy trình

    /// Trang xương sống của cả chương. Nó tồn tại vì sáu tính năng dưới đây **chỉ có nghĩa khi
    /// đứng cạnh nhau**: hồ sơ nói dữ liệu đang thế nào, bàn làm sạch sửa, công thức lặp lại,
    /// bộ luật phán xét, cổng CLI chặn. Đọc riêng từng trang thì thấy sáu nút bấm rời rạc.
    static let quyTrinhLamSach = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Quy trình làm sạch — đi từ đầu đến cuối",
        summary: "Sáu bước từ tệp lạ tới bảng tin được, và một bộ chuẩn chạy lại được tháng sau.",
        keywords: ["làm sạch", "clean", "quy trình", "flow", "chuẩn hóa", "dọn dữ liệu"],
        blocks: [
            .paragraph("""
                Việc làm sạch dữ liệu **hiếm khi làm một lần**. Người ta nhận cùng một mẫu báo cáo \
                mỗi tháng, và tháng nào cũng phải chuẩn hoá đúng ngần ấy cột theo đúng ngần ấy \
                cách. Quy trình dưới đây thiết kế cho việc ấy: lần đầu bạn làm tay, những lần sau \
                chạy lại bằng một lệnh.
                """),
            .heading("Sáu bước"),
            .steps([
                "**Nhìn cấu trúc trước.** `CSV ▸ Kiểm tra dữ liệu` — hàng nào lệch cột, ô nào sai kiểu. Bước này đứng đầu vì một hàng lệch cột làm mọi thống kê phía sau vô nghĩa.",
                "**Đọc hồ sơ dữ liệu.** Mỗi cột: bao nhiêu ô trống, bao nhiêu giá trị khác nhau, kiểu là gì, ngoại lệ ở đâu. Đây là lúc bạn hiểu tệp, chưa sửa gì.",
                "**Mở Bàn làm sạch** (`⇧⌘L`). Nó tự phát hiện ngày hỗn tạp, số kiểu Việt lẫn kiểu Âu, khoảng trắng thừa, giá trị thiếu. **Xem trước trước→sau**, rồi mới áp.",
                "**Xử lý trùng lặp mờ** nếu cột tên/địa chỉ có biến thể gõ tay. Bước này người quyết, máy chỉ đề xuất.",
                "**Lưu lại thành công thức.** Chuỗi bước vừa làm được ghi ra một tệp JSON đặt tên — đây chính là tri thức về dữ liệu của bạn.",
                "**Viết bộ luật chất lượng** `.gquality.yaml` và chấm điểm. Từ nay tệp tháng sau chạy qua công thức rồi chấm điểm, và **cổng CLI** trả mã thoát khác 0 nếu không đạt.",
            ]),
            .heading("Vì sao thứ tự này"),
            .bullets([
                "Kiểm cấu trúc **trước** hồ sơ: thống kê trên một bảng lệch cột là thống kê của cột khác.",
                "Hồ sơ **trước** làm sạch: bạn phải biết `2% ô trống` trước khi quyết định điền hay xoá.",
                "Trùng lặp mờ **sau** chuẩn hoá: `CÔNG TY  A` và `Công ty A` chỉ lộ ra là một sau khi đã cắt khoảng trắng và thống nhất hoa thường.",
                "Công thức **trước** bộ luật: công thức sửa, bộ luật phán xét — chấm điểm một bảng chưa sửa thì chỉ ra một điểm số thấp mà bạn đã biết trước.",
            ]),
            .heading("Sau lần đầu, mỗi tháng chỉ còn một lệnh"),
            .code(
                language: "bash",
                caption: "Làm sạch rồi chấm điểm, trả mã thoát cho CI",
                source: """
                    geditor --recipe chuan-ban-hang.json \\
                            --quality chuan-ban-hang.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            ban-hang-thang-09.csv
                    """
            ),
            .paragraph("""
                Mã thoát **0** là đạt, **1** là trượt, **2** là lỗi khi chạy. `--record-history` \
                nối thêm một dòng vào tệp lịch sử để lần sau so được trôi dạt.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    // MARK: - Hồ sơ dữ liệu

    static let hoSoDuLieu = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Hồ sơ dữ liệu",
        summary: "Mỗi cột một bản mô tả: kiểu, ô trống, số giá trị khác nhau, phân bố.",
        keywords: ["profile", "hồ sơ", "thống kê cột", "null", "distinct"],
        blocks: [
            .paragraph("""
                Hồ sơ **mô tả**, không phán xét. Nó nói *"cột này 2% ô trống"*; việc 2% có chấp \
                nhận được hay không là chuyện của bộ luật chất lượng.
                """),
            .table(
                headers: ["Chỉ số", "Đọc thế nào"],
                rows: [
                    ["Kiểu", "Suy ra từ chính dữ liệu, không từ tên cột"],
                    ["Ô trống", "Số và tỷ lệ ô thiếu"],
                    ["Giá trị khác nhau", "Bằng 1 nghĩa là cột hằng; bằng số hàng nghĩa là cột khoá"],
                    ["Nhỏ nhất · lớn nhất · trung bình", "Chỉ với cột số"],
                    ["Giá trị hay gặp", "Nhìn ra ngay mã lỗi hoặc giá trị mặc định bị lạm dụng"],
                ]
            ),
            .warning("""
                Số giá trị khác nhau có ngưỡng đếm. Vượt ngưỡng thì con số hiện ra là **cận dưới**, \
                và hồ sơ **nói rõ đó là ước lượng** chứ không trộn lẫn với số đếm thật.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    // MARK: - Bàn làm sạch

    static let banLamSach = HelpTopic(
        id: "ban-lam-sach",
        title: "Bàn làm sạch dữ liệu",
        summary: "Bảy phép chuẩn hoá, luôn xem trước, luôn một bước hoàn tác, không bao giờ đoán.",
        keywords: ["clean", "bàn làm sạch", "chuẩn hóa", "ngày", "số", "trim", "điền thiếu"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Mở Bàn làm sạch dữ liệu")]),
            .table(
                headers: ["Phép", "Làm gì"],
                rows: [
                    ["Chuẩn hoá ngày", "Đưa mọi dạng ngày trong cột về một dạng"],
                    ["Chuẩn hoá số", "Thống nhất dấu thập phân và dấu phân nhóm"],
                    ["Cắt khoảng trắng", "Bỏ khoảng trắng hai đầu; tuỳ chọn nén cả khoảng trắng bên trong"],
                    ["Đổi hoa thường", "Thống nhất cách viết trong cột"],
                    ["Điền giá trị cố định", "Thay ô trống bằng một giá trị bạn nhập"],
                    ["Điền theo hàng xóm", "Lấy giá trị của hàng trên hoặc hàng dưới"],
                    ["Xoá hàng có ô trống", "Bỏ hẳn hàng thiếu dữ liệu"],
                ]
            ),
            .heading("Ba bảo đảm của cả bàn"),
            .bullets([
                "**Luôn xem trước.** Bảng trước→sau, kèm số ô sẽ đổi.",
                "**Một bước hoàn tác** cho cả lượt, dù nó chạm một triệu ô.",
                "**Có báo cáo sau khi chạy**: đã đổi bao nhiêu ô, và ô nào không đọc được.",
            ]),
            .heading("Nguyên tắc: không đoán"),
            .paragraph("""
                Ô nào không đọc chắc chắn được thì được **đánh dấu và để nguyên**. Ví dụ `03/04/2026` \
                trong một cột lẫn cả hai kiểu — ngày 3 tháng 4 hay tháng 3 ngày 4? GEditor hỏi bạn \
                thứ tự ngày/tháng thay vì tự chọn.
                """),
            .warning("""
                Chuẩn hoá sai một cột ngày là kiểu hỏng dữ liệu **gần như không thể phát hiện**: \
                con số vẫn đúng khuôn, chỉ là đã thành một ngày khác. Đây là lý do bàn này thà từ \
                chối còn hơn suy diễn.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Trùng lặp mờ

    static let trungLapMo = HelpTopic(
        id: "trung-lap-mo",
        title: "Trùng lặp mờ",
        summary: "Tìm các biến thể gõ tay của cùng một tên — và không bao giờ tự gộp.",
        keywords: ["fuzzy", "trùng lặp", "dedupe", "gộp", "biến thể", "gõ sai"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — ba cách gõ \
                một khách hàng. Phép khử trùng lặp thường không thấy chúng giống nhau.
                """),
            .steps([
                "Chọn cột cần soi và ngưỡng tương đồng.",
                "GEditor gom các giá trị gần nhau thành **cụm** và hiện dạng so sánh.",
                "Với **từng cụm**, bạn chọn giữ giá trị nào — hoặc bỏ qua cụm ấy.",
                "Áp. Là một bước hoàn tác.",
            ]),
            .warning("""
                Công cụ này **không bao giờ tự gộp**, và không có nút "gộp hết". Hai chuỗi giống \
                nhau 92% có thể là một lỗi gõ, mà cũng có thể là hai công ty thật khác nhau đúng \
                một chữ — máy không phân biệt được.
                """),
            .paragraph("""
                Gộp nhầm hai bản ghi là mất dữ liệu **im lặng**: không ô nào trống đi, không dòng \
                nào đỏ lên, chỉ có hai thực thể hoá thành một và không ai biết cho tới khi đối \
                chiếu sổ sách.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    // MARK: - Công thức

    static let congThucLamSach = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Công thức làm sạch",
        summary: "Ghi chuỗi bước thành một tệp JSON, chạy lại trên tệp tháng sau.",
        keywords: ["recipe", "công thức", "lặp lại", "tự động", "hàng tháng", "batch"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Sau khi làm sạch xong, lưu các bước thành **công thức**. Đó là một tệp JSON đọc \
                được bằng mắt, đặt cạnh dữ liệu, gửi cho đồng nghiệp được, và cho vào kho mã để \
                theo dõi thay đổi được.
                """),
            .code(
                language: "json",
                caption: "chuan-ban-hang.json — rút gọn",
                source: """
                    {
                      "version": 1,
                      "name": "Chuẩn hoá báo cáo bán hàng",
                      "sourceFile": "ban-hang-thang-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """
            ),
            .paragraph("""
                Từng bước **bật tắt được** (`enabled`), nên một công thức dùng chung cho vài loại \
                tệp gần giống nhau.
                """),
            .heading("Chạy lại"),
            .bullets([
                "Trong ứng dụng: `CSV ▸ Chạy công thức làm sạch…`",
                "Từ dòng lệnh, cho cả thư mục: xem trang công cụ dòng lệnh.",
            ]),
            .code(
                language: "bash",
                caption: "Chạy thử trước khi ghi — không đụng tệp nào",
                source: """
                    geditor --recipe chuan-ban-hang.json --dry-run ban-hang-*.csv
                    """
            ),
            .note("""
                Mặc định kết quả ghi ra tệp mới cạnh tệp gốc (`ban-hang-sach.csv`). Muốn đè lên \
                tệp gốc thì phải nói rõ bằng `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Chấm chất lượng

    static let chamChatLuong = HelpTopic(
        id: "cham-chat-luong",
        title: "Chấm chất lượng dữ liệu",
        summary: "Sáu chiều, một điểm 0–100, và mọi công thức đều in ra để tính lại được.",
        keywords: ["chất lượng", "quality", "điểm", "score", "dqr", "sáu chiều"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Khác hồ sơ dữ liệu ở một chỗ căn bản: hồ sơ **mô tả**, điểm số **phán xét theo \
                chuẩn bạn khai** trong tệp `.gquality.yaml`.
                """),
            .table(
                headers: ["Chiều", "Đo gì"],
                rows: [
                    ["Đầy đủ", "Tỷ lệ ô có dữ liệu, theo các luật `not_null`"],
                    ["Hợp lệ", "Tỷ lệ luật định dạng, kiểu, khoảng, regex đạt"],
                    ["Không trùng", "Theo khoá bạn khai ở `uniqueness_key`"],
                    ["Nhất quán", "Luật liên cột và liên tệp"],
                    ["Chính xác (ước lượng)", "Ngoại lệ trên các cột số bạn chỉ định"],
                    ["Tươi mới", "Dữ liệu cũ bao nhiêu so với ngưỡng `freshness`"],
                ]
            ),
            .heading("Ba bảo đảm của điểm số"),
            .bullets([
                "**Công thức in ngay trong kết quả** — bạn tính lại được bằng tay.",
                "**Tất định**: cùng dữ liệu và cùng luật cho cùng điểm. Chỉ chiều *Tươi mới* phụ thuộc thời điểm, nên mốc `now` là **tham số** và được ghi vào kết quả.",
                "**Chiều không chấm được thì bỏ trống và nói lý do**, chứ không âm thầm cho 100.",
            ]),
            .warning("""
                Điểm cuối cùng ấy quan trọng. Một bảng chưa khai `uniqueness_key` mà được cho 100 \
                điểm \"không trùng\" là một điểm số nói dối — và nó nói dối theo hướng có lợi, tức \
                hướng nguy hiểm.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    // MARK: - Cú pháp .gquality.yaml

    static let cuPhapGQuality = HelpTopic(
        id: "cu-phap-gquality",
        title: "Cú pháp `.gquality.yaml`",
        summary: "Toàn bộ khoá của tệp bộ luật, kèm một bộ luật hoàn chỉnh chạy được.",
        keywords: ["gquality", "yaml", "luật", "rules", "cú pháp", "chuẩn dữ liệu"],
        blocks: [
            .paragraph("""
                Tệp đặt **cạnh dữ liệu**, không nằm trong ứng dụng: một bộ chuẩn dữ liệu phải \
                review được, và review là việc người ta làm với chuẩn.
                """),
            .code(
                language: "yaml",
                caption: "chuan-ban-hang.yaml — bộ luật đầy đủ",
                source: """
                    schemaVersion: 1

                    # Trọng số sáu chiều. Thiếu chiều nào thì chiều ấy trọng số 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Khoá xác định một hàng là duy nhất. Không khai thì chiều "Không trùng"
                    # KHÔNG chấm được — và điểm tổng sẽ nói ra là nó thiếu.
                    uniqueness_key: [ma_don]

                    # Cột số đem soi ngoại lệ cho chiều "Chính xác (ước lượng)".
                    accuracy_columns: [doanh_thu, so_luong]

                    # Chiều "Tươi mới".
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Cảnh báo khi lần chạy này tụt so với lần trước.
                    drift:
                      max_total_drop: 3
                      max_dimension_drop: 5
                      max_row_change_pct: 20
                      max_null_increase_pct: 1
                      warn_on_new_failure: true

                    rules:
                      - col: ma_don
                        not_null: true
                      - col: ma_don
                        unique: true
                      - col: doanh_thu
                        dtype: float
                      - col: doanh_thu
                        range: { min: 0 }
                      - col: so_luong
                        dtype: int
                        severity: warn
                      - col: ngay
                        date_format: "yyyy-MM-dd"
                      - col: email
                        regex: "^[^@ ]+@[^@ ]+\\\\.[a-z]{2,}$"
                      - col: trang_thai
                        in_set: [moi, dang_giao, hoan_tat, huy]
                      - col: ghi_chu
                        length: { max: 500 }
                      - col: ma_tinh
                        not_null: true
                        max_null_pct: 2          # cho phép 2% ô trống
                      # Luật liên cột: không cần `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Luật liên tệp: giá trị phải tồn tại ở tệp khác
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """
            ),
            .heading("Các loại luật"),
            .table(
                headers: ["Khoá", "Nghĩa", "Chiều"],
                rows: [
                    ["`not_null: true`", "Ô không được trống; `max_null_pct` nới ra được", "Đầy đủ"],
                    ["`unique: true`", "Giá trị không trùng trong cột", "Không trùng"],
                    ["`dtype: int\\|float\\|date\\|text`", "Đúng kiểu", "Hợp lệ"],
                    ["`range: { min:, max: }`", "Nằm trong khoảng số", "Hợp lệ"],
                    ["`length: { min:, max: }`", "Độ dài chuỗi", "Hợp lệ"],
                    ["`regex: \"…\"`", "Khớp biểu thức chính quy", "Hợp lệ"],
                    ["`in_set: [ … ]`", "Thuộc danh sách cho trước", "Hợp lệ"],
                    ["`date_format: \"…\"`", "Đúng dạng ngày", "Hợp lệ"],
                    ["`compare: { a:, op:, b: }`", "So hai cột; `op` là `<` `<=` `=` `>=` `>` `<>`", "Nhất quán"],
                    ["`foreign_key: { file:, column: }`", "Giá trị phải có ở tệp khác", "Nhất quán"],
                    ["`severity: error\\|warn`", "Mức của luật; mặc định `error`", "—"],
                ]
            ),
            .warning("""
                Gõ sai tên một khoá luật thì tệp **bị từ chối kèm thông báo**, chứ luật ấy không \
                bị bỏ qua trong im lặng. Bỏ qua im lặng nghĩa là bạn tưởng dữ liệu đã được kiểm \
                theo một luật mà thực ra chưa bao giờ chạy.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    // MARK: - Cổng chất lượng

    static let congChatLuong = HelpTopic(
        id: "cong-chat-luong",
        title: "Cổng chất lượng trong CI",
        summary: "Chặn dữ liệu không đạt ngay ở đường ống, bằng mã thoát.",
        keywords: ["ci", "cổng", "gate", "fail-under", "mã thoát", "tự động", "lịch sử", "trôi dạt"],
        blocks: [
            .code(
                language: "bash",
                caption: "Chấm điểm và trả mã thoát",
                source: """
                    geditor --quality chuan-ban-hang.yaml \\
                            --fail-under 90 \\
                            --json ket-qua.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            ban-hang-thang-09.csv
                    """
            ),
            .table(
                headers: ["Tuỳ chọn", "Nghĩa"],
                rows: [
                    ["`--quality <tệp.yaml>`", "Bộ luật đem chấm"],
                    ["`--fail-under <0…100>`", "Dưới ngưỡng này là TRƯỢT"],
                    ["`--json <tệp\\|->`", "Kết quả máy đọc được; `-` là in ra màn hình"],
                    ["`--record-history`", "Nối một dòng vào `chuan-ban-hang.history.jsonl`"],
                    ["`--now <YYYY-MM-DD>`", "Đóng đinh mốc thời gian của chiều *Tươi mới*"],
                    ["`--recipe <tệp.json>`", "Làm sạch **trong bộ nhớ** trước khi chấm, không ghi tệp nào"],
                ]
            ),
            .table(
                headers: ["Mã thoát", "Nghĩa"],
                rows: [["`0`", "Đạt"], ["`1`", "Trượt"], ["`2`", "Lỗi khi chạy"]],
            ),
            .heading("Vì sao nên có `--now` trong CI"),
            .paragraph("""
                Không có nó, chiều *Tươi mới* so dữ liệu với thời điểm chạy — nên cùng một tệp sẽ \
                tụt điểm dần theo ngày, và một hôm nào đó đường ống đỏ lên mà chẳng ai đổi gì cả.
                """),
            .heading("Theo dõi trôi dạt"),
            .paragraph("""
                Với `--record-history`, mỗi lần chạy nối một dòng vào tệp lịch sử JSONL. Lần sau, \
                các ngưỡng trong khối `drift:` so với lần gần nhất và cảnh báo khi tụt quá mức.
                """),
            .note("""
                Mọi ngưỡng trôi dạt **tắt theo mặc định**, trừ `warn_on_new_failure`. Một cảnh báo \
                bật sẵn với con số do ứng dụng tự chọn sẽ kêu ở lần chạy thứ hai của mọi người — \
                và thứ kêu sai ngay lần đầu thì tới lần thứ ba đã bị bỏ qua.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )
}
