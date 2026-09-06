import Foundation

extension HelpVI {

    static let triThuc = HelpChapter(
        id: "tri-thuc",
        title: "Gói tri thức",
        summary: "Cắt chunk, chỉ mục tìm kiếm, đồ thị tri thức, entity và đánh giá truy hồi.",
        topics: [goiTriThuc, chunkVaJSONL, chuyenDoiTriThuc, doThiTriThuc, danhDauEntity,
                 gomBienTheEntity, phongThiNghiemTruyHoi]
    )

    // MARK: - Tổng quan

    static let goiTriThuc = HelpTopic(
        id: "goi-tri-thuc",
        title: "Gói tri thức là gì",
        summary: "Bộ công cụ chuẩn bị và kiểm tra dữ liệu cho hệ thống hỏi–đáp trên tài liệu.",
        keywords: ["rag", "tri thức", "knowledge", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Khi xây một hệ thống trả lời câu hỏi dựa trên kho tài liệu, phần lớn công sức không \
                nằm ở mô hình mà nằm ở **chuẩn bị dữ liệu**: cắt tài liệu thành đoạn hợp lý, kiểm \
                chất lượng các đoạn ấy, dựng chỉ mục, và **đo xem truy hồi có tìm đúng không**.
                """),
            .paragraph("""
                Chương này là bộ công cụ cho đúng những việc ấy. Nó chạy **hoàn toàn trên máy bạn** \
                và không gọi ra mạng.
                """),
            .table(
                headers: ["Việc", "Công cụ"],
                rows: [
                    ["Cắt tài liệu thành đoạn", "Xem trước cắt chunk"],
                    ["Soi và chấm chất lượng đoạn", "Kiểm và soi chunk JSONL"],
                    ["Đổi giữa các dạng dữ liệu", "Chuyển đổi tri thức"],
                    ["Dựng và soi đồ thị quan hệ", "Đồ thị tri thức"],
                    ["Tìm tên riêng trong văn bản", "Đánh dấu entity"],
                    ["Đo chất lượng truy hồi", "Phòng thí nghiệm truy hồi"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    // MARK: - Chunk

    static let chunkVaJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Cắt chunk và soi corpus JSONL",
        summary: "Xem trước ranh giới chunk ngay trên văn bản, rồi chấm chất lượng cả corpus.",
        keywords: ["chunk", "jsonl", "cắt", "corpus", "overlap", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Xem trước cắt chunk"),
            .paragraph("""
                Mở một tài liệu văn bản hoặc Markdown, chọn chiến lược cắt và cỡ chunk. Ranh giới \
                được **tô ngay trên văn bản**, nên bạn thấy chỗ nào bị cắt giữa câu hoặc giữa một \
                bảng trước khi xuất ra.
                """),
            .bullets([
                "Cắt theo **cỡ cố định** có phần chồng lấn.",
                "Cắt theo **cấu trúc** — theo tiêu đề Markdown, giữ nguyên mạch tài liệu.",
                "Cắt theo **đoạn văn**, gộp dần tới khi đủ cỡ.",
            ]),
            .heading("Kiểm và soi corpus JSONL"),
            .paragraph("""
                Với một corpus đã có (mỗi dòng một chunk dạng JSON), lệnh `JSONL: kiểm và soi \
                chunk…` trả lời: dòng nào sai JSON, chunk nào quá ngắn hoặc quá dài, chunk nào \
                trùng nhau, chunk nào bị cắt giữa câu.
                """),
            .note("""
                Corpus cũng chấm được bằng **cùng khung sáu chiều** của chất lượng dữ liệu — dùng \
                khoá `corpus:` trong khối `quality` của báo cáo.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    // MARK: - Chuyển đổi

    static let chuyenDoiTriThuc = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Chuyển đổi dạng tri thức",
        summary: "Chunk giữa JSONL · CSV · Markdown, và đồ thị giữa DOT · Mermaid · danh sách cạnh.",
        keywords: ["chuyển đổi", "convert", "jsonl", "dot", "mermaid", "edge list"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Từ", "Sang"],
                rows: [
                    ["Chunk JSONL", "CSV · Markdown"],
                    ["Chunk CSV", "JSONL · Markdown"],
                    ["Đồ thị DOT", "Mermaid · danh sách cạnh"],
                    ["Danh sách cạnh", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Có **xem trước năm dòng** trước khi tạo tab mới, cùng cơ chế với chuyển đổi CSV.
                """),
            .paragraph("""
                `Mở triple/edge dạng bảng` xem một tệp bộ ba hoặc danh sách cạnh dưới dạng bảng — \
                lọc và sắp xếp được như mọi bảng CSV khác.
                """),
            .note("""
                Chiều **Markdown → JSONL** không nằm ở lệnh này: nó chính là phép cắt chunk, và \
                lệnh sẽ dẫn bạn sang đó. Hai bản hiện thực của cùng một phép cắt sẽ cho ra hai kết \
                quả khác nhau.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    // MARK: - Đồ thị

    static let doThiTriThuc = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Đồ thị tri thức",
        summary: "Kiểm cú pháp, chấm sức khoẻ, và chạy thuật toán trên đồ thị hàng triệu cạnh.",
        keywords: ["đồ thị", "graph", "dot", "cypher", "pagerank", "louvain", "kiểm cú pháp"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor đọc đồ thị ở dạng **DOT**, **danh sách cạnh** và **bộ ba**. `Kiểm cú pháp \
                đồ thị` bắt lỗi cú pháp, node treo lơ lửng và cạnh trỏ tới node không tồn tại.
                """),
            .heading("Thuật toán chạy được"),
            .table(
                headers: ["Thuật toán", "Trả lời"],
                rows: [
                    ["Láng giềng k-hop", "Cái gì liên quan tới nút này, trong bán kính k bước"],
                    ["Thành phần liên thông", "Đồ thị có mấy mảng rời nhau"],
                    ["PageRank", "Nút nào quan trọng"],
                    ["Louvain", "Đồ thị tự chia thành mấy cộng đồng"],
                ]
            ),
            .paragraph("""
                Trên đồ thị **một triệu cạnh**, cả bốn đều chạy trong khoảng từ vài mili-giây tới \
                khoảng một giây.
                """),
            .note("""
                Đồ thị cũng chấm được theo **khung sáu chiều** như bảng và corpus — dùng khoá \
                `graph:` trong khối `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    // MARK: - Entity

    static let danhDauEntity = HelpTopic(
        id: "danh-dau-entity",
        title: "Đánh dấu entity từ danh sách",
        summary: "Nạp danh sách tên riêng, tìm mọi lần xuất hiện — theo ba luật hợp với tiếng Việt.",
        keywords: ["entity", "tên riêng", "ner", "đánh dấu", "danh sách", "khớp"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Nạp một danh sách tên (công ty, sản phẩm, địa danh) và GEditor tô mọi lần chúng \
                xuất hiện trong tài liệu, kèm bảng đếm.
                """),
            .heading("Ba luật khớp, và cả ba đến từ dữ liệu tiếng Việt"),
            .bullets([
                "**Khớp dài nhất thắng.** Có cả `An Phát` lẫn `Công ty An Phát` trong danh sách thì câu chứa cụm dài phải khớp cụm dài — nếu không, cụm dài bị cắt đôi và đếm thành hai entity, tức thống kê **phóng đại**.",
                "**Phải đúng biên từ.** `An` không được khớp bên trong `Anh` hay `Hoàn`. Tên riêng tiếng Việt ngắn và trùng âm tiết với vô số từ thường.",
                "**Không phân biệt hoa thường, nhưng GIỮ dấu.** `CÔNG TY` và `Công ty` là một; `má` và `ma` thì không.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    // MARK: - Gom biến thể

    static let gomBienTheEntity = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Gom biến thể của một entity",
        summary: "Nhận ra `Cty An Phát` và `Công ty An Phát` là một — vẫn để bạn quyết.",
        keywords: ["entity resolution", "gom biến thể", "chuẩn hóa tên", "trùng"],
        blocks: [
            .paragraph("""
                Cùng phép gom cụm với **trùng lặp mờ** trong bảng CSV — đúng một hiện thực dùng \
                chung, không phải hai bản.
                """),
            .paragraph("""
                Kết quả là **đề xuất**: bạn duyệt từng cụm và chọn dạng chuẩn. Không có nút gộp \
                hết, vì hai tên giống nhau 92% có thể là hai tổ chức thật.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    // MARK: - Truy hồi

    static let phongThiNghiemTruyHoi = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Phòng thí nghiệm truy hồi",
        summary: "Đo xem chỉ mục có tìm đúng không, bằng bộ câu hỏi có đáp án.",
        keywords: ["retrieval", "truy hồi", "bm25", "recall", "mrr", "ndcg", "đánh giá", "golden set"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Nạp một **bộ đánh giá** — mỗi dòng là một câu hỏi kèm danh sách id chunk đáng lẽ \
                phải trả về — rồi chạy hàng loạt trên chỉ mục.
                """),
            .table(
                headers: ["Chỉ số", "Trả lời"],
                rows: [
                    ["recall@k", "Trong k kết quả đầu, lấy được bao nhiêu phần đáp án"],
                    ["MRR", "Kết quả đúng đầu tiên nằm ở vị trí nào"],
                    ["nDCG@k", "Thứ hạng có tốt không, tính cả vị trí"],
                ]
            ),
            .paragraph("""
                Kết quả có cả **theo từng câu hỏi**, sắp câu tệ nhất lên đầu — đó là danh sách việc \
                cần sửa trong corpus, theo thứ tự đáng sửa nhất.
                """),
            .warning("""
                Ba chỉ số trên đều là **trung bình**, và một trung bình che được rất nhiều thứ. \
                Luôn xem bảng theo từng câu trước khi kết luận rằng \"chỉ mục đã đủ tốt\".
                """),
            .paragraph("""
                So được **hai cấu hình song song**, và kết quả đổ thẳng vào báo cáo `.greport.md` \
                để lần sau chạy lại y hệt.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )
}
