import Foundation

extension HelpVI {

    static let khaiPha = HelpChapter(
        id: "khai-pha",
        title: "Khai phá dữ liệu — cả quy trình",
        summary: "Bất thường, tương quan, phân cụm, dự báo, luật kết hợp — và cách đọc chúng cho đúng.",
        topics: [quyTrinhKhaiPha, timBatThuong, maTranTuongQuan, phanCum, duBao, luatKetHop,
                 khaiPhaTheoNhom, khaiPhaVanBan]
    )

    // MARK: - Trang quy trình

    static let quyTrinhKhaiPha = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Quy trình khai phá — đi từ đầu đến cuối",
        summary: "Sáu công cụ, thứ tự nên dùng, và luật chung: không đo được thì không kết luận.",
        keywords: ["khai phá", "mining", "phân tích", "quy trình", "flow", "thống kê"],
        blocks: [
            .warning("""
                **Làm sạch trước, khai phá sau.** Một cột ngày chưa chuẩn hoá sẽ cho dự báo sai; \
                một cột số lẫn dấu phân nhóm kiểu Âu sẽ cho ngoại lệ giả. Mọi công cụ dưới đây \
                giả định bảng đã sạch.
                """),
            .heading("Thứ tự nên đi"),
            .steps([
                "**Tìm bất thường** — trả lời *\"có hàng nào lạ không\"*. Rẻ nhất và hay ra kết quả dùng được ngay.",
                "**Ma trận tương quan** — trả lời *\"cột nào đi cùng cột nào\"*. Định hướng cho mọi bước sau.",
                "**Phân cụm** — trả lời *\"dữ liệu tự chia thành mấy nhóm\"*.",
                "**Dự báo** — chỉ dùng khi có cột thời gian và đủ ít nhất **hai chu kỳ**.",
                "**Luật kết hợp** — chỉ dùng với dữ liệu dạng giỏ hàng: mỗi hàng một giao dịch, hoặc hai cột mã giao dịch và mặt hàng.",
                "**Khai phá theo nhóm** — chạy lại ba việc đầu **độc lập trong từng nhóm**. Bước này hay lật ngược kết luận của bảng gộp.",
            ]),
            .heading("Ba luật chung của cả cụm"),
            .bullets([
                "**Mọi kết quả kèm khối \"Phương pháp\"**: thuật toán, tham số, seed, công thức. Không có cách nào tắt nó đi — một bảng ba con số không nói chúng ở đâu ra thì không dùng để ra quyết định được.",
                "**Không đo được thì KHÔNG kết luận.** Mẫu quá ít, phương sai bằng 0, ma trận suy biến — GEditor từ chối và nói lý do, thay vì trả một con số trông có vẻ đúng.",
                "**Kết quả tất định.** Cùng dữ liệu cho cùng kết quả; chỗ nào cần số ngẫu nhiên thì seed được ghi vào kết quả.",
            ]),
            .heading("Từ kết quả quay về dữ liệu"),
            .paragraph("""
                Mọi panel đều **tô ngược vào dữ liệu gốc**: bấm một hàng bất thường, một ô tương \
                quan, một luật kết hợp là những dòng liên quan được đánh dấu trong bảng. Đó là \
                cách đi từ *"có gì đó lạ"* sang *"lạ ở đúng những dòng này"*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    // MARK: - Bất thường

    static let timBatThuong = HelpTopic(
        id: "tim-bat-thuong",
        title: "Tìm hàng bất thường",
        summary: "Bốn phép đo, ba mức nặng, và một lời giải thích vì sao hàng ấy lạ.",
        keywords: ["outlier", "bất thường", "anomaly", "ngoại lệ", "z-score", "iqr", "mad"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Phép đo", "Dùng khi"],
                rows: [
                    ["z-score", "Cột phân bố gần chuẩn"],
                    ["IQR", "Cột lệch, có đuôi dài — mặc định an toàn"],
                    ["MAD", "Cột đã có sẵn nhiều ngoại lệ, cần phép đo bền"],
                    ["Mahalanobis", "**Nhiều cột cùng lúc** — bắt hàng lạ ở tổ hợp chứ không lạ ở từng cột"],
                ]
            ),
            .paragraph("""
                Kết quả tô theo **ba mức nặng**, không phải một màu cho tất cả — nếu không thì \
                không phân biệt được hàng hơi lệch với hàng lệch hẳn.
                """),
            .heading("Giải thích vì sao"),
            .paragraph("""
                Với phép đo nhiều cột, GEditor phân rã đóng góp của từng cột và sinh một câu kiểu \
                *«bất thường chủ yếu do tổ hợp doanh_thu (50%) × so_luong (50%)»*.
                """),
            .note("""
                Phần trăm ấy là *trong phần giải thích được*, không phải *phần trăm khoảng cách*. \
                Khối Phương pháp nói rõ điều đó ngay dưới bảng.
                """),
            .warning("""
                Cột có IQR bằng 0 hoặc MAD bằng 0 thì phép đo **từ chối chạy**, chứ không chia cho \
                một số rất nhỏ để ra một điểm số khổng lồ. Với nhiều cột, nếu ma trận hiệp phương \
                sai suy biến thì GEditor **nói rõ nên bỏ cột nào** thay vì dùng nghịch đảo giả để \
                \"chạy được\".
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Tương quan

    static let maTranTuongQuan = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Ma trận tương quan",
        summary: "Pearson và Spearman cho mọi cặp cột, bấm một ô ra biểu đồ phân tán.",
        keywords: ["correlation", "tương quan", "pearson", "spearman", "heatmap", "scatter"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Hệ số", "Đo cái gì"],
                rows: [
                    ["Pearson", "Quan hệ **tuyến tính**"],
                    ["Spearman", "Quan hệ **đồng biến bất kỳ**, kể cả cong — chạy trên hạng"],
                ]
            ),
            .paragraph("""
                Bấm một ô trong bản đồ nhiệt để xem biểu đồ phân tán của cặp ấy, kèm đường hồi quy \
                và R².
                """),
            .heading("Bốn chi tiết ảnh hưởng tới cách đọc"),
            .bullets([
                "**Giá trị trùng dùng hạng trung bình**, nên sắp lại bảng không làm đổi hệ số Spearman.",
                "**Ô trống tính theo từng cặp**, và `n` của từng ô nằm ngay trong bảng — `0,93` trên 6 hàng không cùng nghĩa với `0,93` trên 6.000 hàng.",
                "**Cột hằng trả về trống**, không trả về 0. Số 0 có nghĩa là *đã đo, không thấy liên hệ*.",
                "**Thang màu lam↔cam**, không phải đỏ–lục: 8% nam giới đọc thang đỏ–lục thành một mảng xám, tức `+0,9` và `−0,9` trông y hệt nhau.",
            ]),
            .warning("""
                **Tương quan không hàm ý nhân quả.** Câu này nằm **trong chính hình vẽ**, nên nó \
                đi theo cả khi bạn xuất ảnh ra dán chỗ khác.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    // MARK: - Phân cụm

    static let phanCum = HelpTopic(
        id: "phan-cum",
        title: "Phân cụm",
        summary: "k-means và DBSCAN, kèm hai cách chọn số cụm — và một cảnh báo về chuẩn hoá.",
        keywords: ["cluster", "phân cụm", "kmeans", "dbscan", "nhóm", "silhouette", "elbow"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Thuật toán", "Dùng khi"],
                rows: [
                    ["k-means", "Bạn biết (hoặc muốn thử) số cụm; cụm dạng cầu"],
                    ["DBSCAN", "Không biết số cụm; cụm hình dạng bất kỳ; muốn tách hẳn điểm nhiễu"],
                ]
            ),
            .heading("Chuẩn hoá bật sẵn — và vì sao"),
            .paragraph("""
                Cột `doanh_thu` (hàng triệu) đứng cạnh cột `so_luong` (hàng đơn vị): khoảng cách \
                giữa hai hàng gần như hoàn toàn do cột lớn quyết định. Đó không phải \"kém tối \
                ưu\" — đó là **trả lời một câu hỏi khác**. Cách chuẩn hoá đang dùng được ghi vào \
                kết quả.
                """),
            .heading("Chọn số cụm"),
            .bullets([
                "**Silhouette** — điểm càng cao thì cụm càng tách bạch. Trên bảng lớn nó **lấy mẫu** (mẫu theo bước đều, không lấy 2.000 hàng đầu), và kết quả tự khai là ước lượng.",
                "**Elbow** — vẽ đường cong tổng bình phương trong cụm theo k. Đây là **mẹo đọc đồ thị**, không phải một phép chọn tối ưu: đại lượng ấy luôn giảm khi k tăng, nên không có \"k tối ưu\" theo nghĩa thống kê.",
            ]),
            .note("""
                Với DBSCAN, biểu đồ **k-distance** giúp chọn bán kính: chỗ đường cong gãy thường là \
                một giá trị khởi đầu hợp lý.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Dự báo

    static let duBao = HelpTopic(
        id: "du-bao",
        title: "Dự báo chuỗi thời gian",
        summary: "Phân rã xu hướng và mùa vụ, Holt-Winters, và một baseline luôn chạy cùng.",
        keywords: ["forecast", "dự báo", "chuỗi thời gian", "mùa vụ", "holt-winters", "xu hướng"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Chọn cột thời gian và cột giá trị. GEditor phân rã chuỗi thành **xu hướng · mùa vụ \
                · phần dư**, rồi dự báo bằng Holt-Winters (dạng cộng hoặc nhân), kèm dải tin cậy \
                80% và 95%.
                """),
            .heading("Baseline luôn chạy, và nó nói thẳng ai thắng"),
            .paragraph("""
                Cùng lúc với mô hình, GEditor chạy hai phép ngây thơ: *lấy giá trị kỳ trước* và \
                *lấy giá trị cùng kỳ mùa trước*. Nếu mô hình **thua** baseline thì câu ấy nằm ở \
                **dòng đầu và đổi màu**, không nằm dưới bảng số.
                """),
            .paragraph("""
                Lý do: công cụ dự báo thường trình bày mô hình như một sự thật, và người dùng không \
                có cách nào biết rằng \"lấy giá trị tháng trước\" còn chính xác hơn.
                """),
            .heading("Ba chỗ GEditor từ chối hoặc tự khai"),
            .bullets([
                "**Không đủ hai chu kỳ thì lùi về phép ngây thơ.** Khớp mùa vụ vào nhiễu của một chu kỳ rồi lặp ra tương lai cho một dự báo trông rất thuyết phục và hoàn toàn bịa.",
                "**MAPE gặp giá trị 0 thì nói ra**, và nếu quá 25% số kỳ bằng 0 thì không trả chỉ số ấy — bỏ qua trong im lặng cho ra một con số tính trên tập con lệch có hệ thống.",
                "**Khoảng tin cậy tự khai là xấp xỉ**, và nói rõ nó nới ra quá chậm ở tầm xa.",
            ]),
            .note("""
                Chu kỳ mùa vụ được dò trên **sai phân bậc một**, không trên chuỗi gốc: xu hướng làm \
                mọi độ trễ đều tương quan cao và đỉnh mùa vụ chìm hẳn.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Luật kết hợp

    static let luatKetHop = HelpTopic(
        id: "luat-ket-hop",
        title: "Luật kết hợp",
        summary: "Mua A thì hay mua B — và vì sao bảng sắp theo lift chứ không theo confidence.",
        keywords: ["apriori", "luật kết hợp", "giỏ hàng", "market basket", "lift", "support"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Nhận hai dạng dữ liệu:"),
            .bullets([
                "**Một hàng một giỏ** — cột chứa danh sách mặt hàng.",
                "**Hai cột** — mã giao dịch và mặt hàng, mỗi hàng một mặt hàng.",
            ]),
            .table(
                headers: ["Chỉ số", "Nghĩa"],
                rows: [
                    ["support", "Tỷ lệ giỏ chứa cả hai vế"],
                    ["confidence", "Trong các giỏ có vế trái, bao nhiêu phần trăm có vế phải"],
                    ["**lift**", "Confidence chia cho tỷ lệ nền của vế phải"],
                    ["leverage", "Chênh lệch so với trường hợp hai vế độc lập"],
                ]
            ),
            .heading("Bảng sắp theo lift, không theo confidence"),
            .paragraph("""
                Nếu vế phải vốn có mặt trong 95% số giỏ thì **mọi** luật dẫn tới nó đều có \
                confidence khoảng 95% — mà chẳng nói lên điều gì. Sắp theo confidence sẽ đưa đúng \
                những luật vô nghĩa nhất lên đầu.
                """),
            .warning("""
                `lift < 1` được **cảnh báo ngay trong hàng**: confidence 80% với vế phải có tỷ lệ \
                nền 95% nghĩa là liên hệ **ngược chiều** — một con số đúng dẫn tới một kết luận sai.
                """),
            .bullets([
                "Mua hai hộp sữa vẫn là **một** giao dịch có sữa: trùng lặp trong cùng giỏ được bỏ, nếu không thì support phồng theo số lượng mua.",
                "Đặt ngưỡng support quá thấp làm số ứng viên nổ theo tổ hợp; khi chạm trần, GEditor **dừng và nói rõ bảng chưa đầy đủ**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Theo nhóm

    static let khaiPhaTheoNhom = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Khai phá theo nhóm",
        summary: "Chạy lại phân tích độc lập trong từng nhóm — bước hay lật ngược kết luận nhất.",
        keywords: ["group by", "theo nhóm", "phân nhóm", "simpson", "chi nhánh", "so sánh nhóm"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Chọn một cột chữ làm nhóm. Mỗi nhóm được chạy bất thường, dự báo và tương quan \
                **hoàn toàn độc lập**, rồi xếp hạng theo tiêu chí bạn chọn.
                """),
            .heading("Vì sao phải tách nhóm, không gộp"),
            .paragraph("""
                Hai chi nhánh, một quanh mức 10 và một quanh mức 100. Hàng rào ngoại lệ tính trên \
                bảng **gộp** rơi vào khoảng ±135 — và nó hỏng theo **cả hai chiều**:
                """),
            .bullets([
                "**Bỏ sót**: giá trị 20 rõ ràng bất thường ở nhóm nhỏ vẫn nằm trong hàng rào chung. Càng nhiều nhóm càng mù.",
                "**Báo nhầm**: nhóm phân tán rộng bị hàng rào chung cắt mất đuôi bình thường, và hàng loạt hàng bình thường bị gắn cờ.",
            ]),
            .heading("Cột \"lệch tương quan\" bắt nghịch lý Simpson"),
            .paragraph("""
                Ba nhóm mà trong **mỗi** nhóm hai cột tương quan `−1`, nhưng gộp lại thì tương quan \
                `> 0,9`. Ai chỉ đọc bảng gộp sẽ kết luận **ngược hẳn**. Cột này chỉ ra đúng những \
                chỗ ấy.
                """),
            .note("""
                Panel chỉ đưa **cột chữ** vào danh sách nhóm, và cắt ở 1.000 nhóm kèm cảnh báo — \
                để chặn tình huống chọn nhầm cột mã đơn hàng và mỗi hàng thành một nhóm.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    // MARK: - Khai phá văn bản

    static let khaiPhaVanBan = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Khai phá văn bản",
        summary: "n-gram và TF-IDF trên một cột chữ — tìm cụm từ đặc trưng.",
        keywords: ["text mining", "n-gram", "tf-idf", "văn bản", "từ khóa", "cụm từ"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Chạy trên một cột chữ — mô tả sản phẩm, phản hồi khách hàng, nội dung ghi chú.
                """),
            .bullets([
                "**n-gram** — cụm 1, 2, 3 từ hay gặp nhất.",
                "**TF-IDF** — từ **đặc trưng** cho từng nhóm tài liệu, tức từ hay gặp ở đây mà hiếm ở chỗ khác.",
            ]),
            .paragraph("""
                Khác nhau ở chỗ: n-gram cho bạn *\"khách hay nhắc tới gì\"*, TF-IDF cho bạn *\"nhóm \
                này khác các nhóm kia ở chỗ nào\"*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
