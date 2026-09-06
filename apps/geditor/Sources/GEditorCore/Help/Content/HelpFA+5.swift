import Foundation

/// کتاب راهنمای فارسی — بخش پنجم: گزارش‌ها، بستهٔ دانش، خودکارسازی و خودِ برنامه.
extension HelpFA {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "گزارش‌ها و نمودارها",
        summary: "پرونده‌ای متنی که گزارش HTML می‌سازد و ارقامش بازاجرا می‌شوند، به‌علاوهٔ نمودارهای Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "گزارش‌های `.greport.md`",
        summary: "Markdown به‌علاوهٔ چهار گونه بلوک اجراشدنی — چپ می‌نویسید، راست پیش‌نمایش می‌بینید.",
        keywords: ["گزارش", "greport", "html", "برون‌بری", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                پروندهٔ `.greport.md` همان **Markdown عادی** است به‌علاوهٔ چند بلوک نرده‌دار اجراشدنی. \
                نمایاندنش پرونده‌ای HTML **خودبسنده** می‌سازد — بی شبکه، بی پروندهٔ همراه — که هر کسی \
                می‌تواند بگشاید.
                """),
            .paragraph("""
                چون متن ساده است می‌توان آن را **سنجید، ثبت کرد و به اشتراک گذاشت** — همان فلسفهٔ دستورهای \
                پاک‌سازی و مجموعه‌های قاعدهٔ کیفیت.
                """),
            .code(
                language: "markdown",
                caption: "sales-2026-08.greport.md — گزارشی کامل",
                source: """
                    ---
                    title: گزارش فروش اوت
                    source: sales-2026-08.csv
                    ---

                    # گزارش فروش اوت

                    ارقام تا ۳۱ اوت ۲۰۲۶.

                    ## درآمد بر پایهٔ استان

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: درآمد بر پایهٔ استان
                    y_label: درآمد
                    number_format: vi
                    suffix: " ₫"
                    source: منبع — sales-2026-08.csv
                    ```

                    ## کیفیت دادهٔ منبع

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("گونه‌های بلوک"),
            .table(
                headers: ["بلوک", "می‌سازد"],
                rows: [
                    ["`query`", "جدولی، از عبارتی SQL در DuckDB"],
                    ["`chart`", "نموداری"],
                    ["`quality`", "کارت نمرهٔ کیفیت داده"],
                    ["`mining`", "جدول رتبه‌بندی کاوش گروهی"],
                    ["`mermaid`", "نموداری"],
                ]
            ),
            .heading("پیش‌ماده"),
            .paragraph("""
                بلوک `---` در بالا `title` و `source` را اعلام می‌کند — `source` منبع دادهٔ پیش‌فرض هر \
                بلوکی است که منبع خودش را نام نبرد.
                """),
            .note("""
                پیش‌نمایش هرگاه نوشتن را بس کنید بازساخته می‌شود، اما تنها **تجزیه می‌کند**؛ با هر فشردن \
                کلید پرس‌وجو اجرا نمی‌کند. خطاهای سند و خطاهای داده جداگانه گزارش می‌شوند — *«بلوک chart \
                کلید `kind` را کم دارد»* خطای پرونده است، *«ستون `doanh_thu` وجود ندارد»* خطای داده.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "بلوک `query`",
        summary: "یک عبارت DuckDB به یک جدول در گزارش بدل می‌شود.",
        keywords: ["پرس‌وجو", "sql", "جدول", "گزارش", "بلوک"],
        blocks: [
            .paragraph("""
                محتوای بلوک **یک عبارت SQL** است که بر منبع گزارش اجرا می‌شود. جدول `t` نام دارد، با همان \
                گویشی که تابلوی پرس‌وجو دارد.
                """),
            .code(
                language: "text",
                caption: "بلوک پرس‌وجو با پارامتر",
                source: """
                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu
                    FROM t
                    WHERE thang = :thang
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    ```
                    """
            ),
            .paragraph("""
                `:thang` یک **پارامتر** است. هنگام نمایاندن داده می‌شود — از پوسته با `--param thang=8`، \
                یا از پرونده‌ای فهرست‌وار هنگام ساختن انبوه گزارش.
                """),
            .note("""
                جدول‌ها در گزارش داده **باید از بلوک query بیایند** نه اینکه دستی نوشته شوند. جدول دستی \
                هنگام دگرگونی ارقام بازاجرا نمی‌شود، و دیر یا زود با باقی گزارش ناسازگار می‌گردد.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "بلوک `chart`",
        summary: "پیکربندی YAML به نموداری بدل می‌شود — و مهم‌ترین قاعدهٔ این قالب.",
        keywords: ["نمودار", "yaml", "گزارش", "نگاره"],
        blocks: [
            .code(
                language: "yaml",
                caption: "هر کلید یک بلوک chart",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: درآمد بر پایهٔ استان
                    x_label: استان
                    y_label: درآمد
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: منبع — sales.csv، تا ۲۶ اوت ۲۰۲۶
                    """
            ),
            .heading("بی `query`، نتیجهٔ بلوک queryِ درست بالای خود را به کار می‌برد"),
            .paragraph("""
                این مهم‌ترین قاعدهٔ این قالب است. به لطف آن، گزارش رایج «جدولی و سپس نموداری از همان جدول» \
                SQL را تکرار نمی‌کند — و تکرار یعنی دو رونوشت سرانجام از هم دور می‌شوند، و آنگاه جدول و \
                نمودار در یک صفحه دو چیز می‌گویند.
                """),
            .warning("""
                در برابر، **ترتیب بلوک‌ها مهم است**: درج بلوک query در میان، دادهٔ نمودار زیرش را دگرگون \
                می‌کند.
                """),
            .heading("چرا `source` کلیدی جداست"),
            .paragraph("""
                یادداشت منبعی که چون نثر زیر نمودار نوشته شود عالی نمایان می‌شود — بر پرده. اما نمودار \
                چون PNG برون‌بری و جای دیگری چسبانده می‌شود، و نثر جا می‌ماند. چون کلید، **درون تصویر** \
                کشیده می‌شود و با آن سفر می‌کند.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "بلوک `quality`",
        summary: "کارت نمرهٔ کیفیت داده درون گزارش.",
        keywords: ["کیفیت", "کارت نمره", "گزارش", "بلوک"],
        blocks: [
            .code(
                language: "yaml",
                caption: "هر کلید یک بلوک quality",
                source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # تهی یعنی منبع خودِ گزارش
                    title: کیفیت دادهٔ فروش اوت
                    rules: true                 # جدول قاعده‌های قبول/رد را نشان بده
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # تاریخ مرجع «به‌روزی» را ثابت کن
                    fail_under: 90              # زیر این، کارت به رنگ هشدار درمی‌آید
                    """
            ),
            .table(
                headers: ["`chart`", "می‌کشد"],
                rows: [
                    ["`violations`", "شمار ردیف‌ها برای قاعده‌های **ردشده** — به «نخست چه را درست کنیم» پاسخ می‌دهد"],
                    ["`dimensions`", "نمرهٔ شش بُعد"],
                    ["`none`", "تنها جدول، بی نمودار"],
                ]
            ),
            .note("""
                در گزارشی دوره‌ای `now:` را تعیین کنید. بی آن، *به‌روزی* با زمان نمایاندن می‌سنجد، پس \
                بازنمایاندن گزارش ماه پیش نمره‌ای دیگر از آنچه منتشر کرده‌اید می‌سازد.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "بلوک `mining`",
        summary: "گروه‌ها را بر پایهٔ ناهنجاری، خطای پیش‌بینی یا واگرایی همبستگی رتبه دهید.",
        keywords: ["کاوش", "گزارش", "رتبه‌بندی گروه"],
        blocks: [
            .code(
                language: "yaml",
                caption: "هر کلید یک بلوک mining",
                source: """
                    group_by: tinh
                    value: doanh_thu          # ستونی برای ناهنجاری و پیش‌بینی
                    pair: chi_phi             # ستونی دوم، برای همبستگی درون هر گروه
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # تهی یعنی منبع خودِ گزارش
                    title: کاوش بر پایهٔ استان
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "بر پایهٔ چه رتبه می‌دهد"],
                rows: [
                    ["`anomalies`", "گروهی با بیشترین ردیف ناهنجار"],
                    ["`forecast_error`", "گروهی که پیش‌بینی‌اش بدترین است"],
                    ["`correlation_gap`", "گروهی که همبستگی‌اش بیش از همه از جدول یک‌جا واگرا می‌شود — پارادوکس سیمپسون را می‌گیرد"],
                ]
            ),
            .warning("""
                **هیچ کلیدی بلوک «روش» را خاموش نمی‌کند.** رتبه‌بندی گروهی بی روشش، به خواننده راهی \
                نمی‌گذارد که بداند «بیشترین ناهنجاری» در برابر کدام حصار سنجیده شده است. هر که بخواهد \
                پنهانش کند از پیش پاسخی را که می‌خواهد می‌داند.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "ساختن انبوه گزارش",
        summary: "یک قالب، یک فهرست پارامتر، گزارش‌های بسیار.",
        keywords: ["دسته", "گزارش بسیار", "پارامتر", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                یک قالب گزارش، که برای هر شعبه یا هر ماه اجرا می‌شود. فهرست پارامترها پرونده‌ای CSV یا \
                JSON است — **هر ردیف یک گزارش**.
                """),
            .code(
                language: "text",
                caption: "list.csv — هر ردیف یک گزارش",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash",
                caption: "تمام دسته را از پوسته بنمایان",
                source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """
            ),
            .code(
                language: "bash",
                caption: "یا یک گزارش با پارامترهایی که دستی داده می‌شوند",
                source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """
            ),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "نمودارهای Mermaid",
        summary: "نمودارها را با متن بکشید، با فرمان ویرایش کنید، و در دو سو هم‌گام پیش‌نمایش ببینید.",
        keywords: ["mermaid", "نمودار", "روندنما", "توالی", "کشیدن"],
        commands: [
            "Sơ đồ Mermaid: xem trước", "Sơ đồ Mermaid: chèn mẫu…",
            "Sơ đồ Mermaid: thêm phần tử…", "Sơ đồ Mermaid: nối hai phần tử đang chọn",
            "Sơ đồ Mermaid: sửa nhãn phần tử đang chọn…", "Sơ đồ Mermaid: xoá phần tử đang chọn",
            "Sơ đồ Mermaid: đưa message lên trên", "Sơ đồ Mermaid: đưa message xuống dưới",
            "Sơ đồ Mermaid: định dạng lại", "Sơ đồ Mermaid: tách khối ra tệp .mmd…",
            "Sơ đồ Mermaid: nhúng tệp tham chiếu trở lại",
        ],
        blocks: [
            .paragraph("""
                ‏Mermaid نمودارها را **از متن** می‌کشد: شما توصیفی می‌نویسید، ماشین می‌کشد. پس نموداری را \
                می‌توان سنجید و ثبت کرد — چیزی که پروندهٔ تصویری نمی‌تواند.
                """),
            .paragraph("""
                `نمودار Mermaid: پیش‌نمایش` را بگشایید تا نمایی کنار ویرایشگر داشته باشید. آن دو **در هر \
                دو سو هم‌گام‌اند**: عنصری را در تصویر برگزینید و مکان‌نما به سطرش می‌پرد.
                """),
            .heading("با فرمان ویرایش کنید نه با بازنویسی"),
            .table(
                headers: ["فرمان", "چه می‌کند"],
                rows: [
                    ["درج قالب…", "برای هر گونه نمودار اسکلتی آماده درج می‌کند"],
                    ["افزودن عنصر…", "گره یا شرکت‌کننده‌ای می‌افزاید"],
                    ["پیوند دو عنصر گزیده", "میان‌شان پیکانی می‌کشد"],
                    ["ویرایش برچسب عنصر گزیده…", "متن را بی جست‌وجوی سطر می‌گرداند"],
                    ["زدودن عنصر گزیده", "گره **و** هر یالی را که به آن می‌رسد برمی‌دارد"],
                    ["جابه‌جایی پیام به بالا / پایین", "گام‌ها را در نمودار توالی بازمی‌چیند"],
                    ["بازقالب‌بندی", "تمام بلوک را تورفتگی و هم‌ترازی می‌دهد"],
                ]
            ),
            .heading("جدا کردن به پرونده و بازجاسازی"),
            .paragraph("""
                جای نمودارهای بزرگ، پروندهٔ `.mmd` خودشان است: `جدا کردن بلوک به پروندهٔ .mmd…` آن را \
                بیرون می‌برد و ارجاعی بر جای می‌گذارد. `بازجاسازی پروندهٔ ارجاع‌شده` وارونه‌اش را می‌کند \
                آنگاه که باید یک پرونده بفرستید.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "نحو رایج Mermaid",
        summary: "چهار گونه نمودار پرکاربردتر، هر یک با قالبی که اجرا می‌شود.",
        keywords: ["mermaid", "نحو", "روندنما", "توالی", "گانت", "کلاس", "قالب"],
        blocks: [
            .code(
                language: "mermaid",
                caption: "روندنما — روند تأیید سفارش",
                source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """
            ),
            .code(
                language: "mermaid",
                caption: "نمودار توالی — روند پرداخت",
                source: """
                    sequenceDiagram
                        participant K as Khách
                        participant W as Website
                        participant T as Cổng thanh toán
                        K->>W: Đặt hàng
                        W->>T: Tạo giao dịch
                        T-->>W: Mã giao dịch
                        W-->>K: Chuyển tới trang thanh toán
                        K->>T: Xác nhận
                        T-->>W: Kết quả
                    """
            ),
            .code(
                language: "mermaid",
                caption: "نمودار کلاس — مدل داده",
                source: """
                    classDiagram
                        class DonHang {
                            +String maDon
                            +Date ngayDat
                            +tongTien() Double
                        }
                        class KhachHang {
                            +String ten
                            +String soDienThoai
                        }
                        KhachHang "1" --> "*" DonHang : đặt
                    """
            ),
            .code(
                language: "mermaid",
                caption: "گانت — برنامهٔ انتشار",
                source: """
                    gantt
                        title Kế hoạch phát hành
                        dateFormat YYYY-MM-DD
                        section Chuẩn bị
                        Viết tài liệu     :a1, 2026-09-01, 10d
                        Kiểm thử          :a2, after a1, 7d
                        section Phát hành
                        Nộp App Store     :a3, after a2, 3d
                    """
            ),
            .table(
                headers: ["شکل گره", "بنویسید"],
                rows: [
                    ["مستطیل", "`A[برچسب]`"],
                    ["گردگوشه", "`A(برچسب)`"],
                    ["ورزشگاه", "`A([برچسب])`"],
                    ["لوزی (تصمیم)", "`A{برچسب}`"],
                    ["استوانه (داده)", "`A[(برچسب)]`"],
                ]
            ),
            .table(
                headers: ["پیکان", "بنویسید"],
                rows: [
                    ["پیوسته با سر", "`A --> B`"],
                    ["نقطه‌چین", "`A -.-> B`"],
                    ["ستبر", "`A ==> B`"],
                    ["برچسب‌دار", "`A -- برچسب --> B`"],
                ]
            ),
            .note("""
                سوی روندنما درست پس از `flowchart` می‌آید: `TD` از بالا به پایین، `LR` از چپ به راست، \
                به‌علاوهٔ `BT` و `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - بستهٔ دانش

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "بستهٔ دانش",
        summary: "تکه‌کردن، نمایه‌های جست‌وجو، گراف‌های دانش، هستارها و ارزیابی بازیابی.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "بستهٔ دانش چیست",
        summary: "ابزارهایی برای آماده‌سازی و بررسی داده برای سامانه‌ای که از سندها پاسخ می‌دهد.",
        keywords: ["rag", "دانش", "تکه", "جاسازی", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                هنگام ساختن سامانه‌ای که از مجموعه‌ای سند پاسخ می‌دهد، بیشترِ کار در مدل نیست بلکه در \
                **آماده‌سازی داده** است: بریدن سندها به پاره‌های معنادار، بررسی کیفیت آن پاره‌ها، ساختن \
                نمایه، و **سنجیدن اینکه بازیابی به‌راستی چیز درست را می‌یابد یا نه**.
                """),
            .paragraph("""
                این فصل دقیقاً جعبه‌ابزار همان است. **یکسره روی دستگاه شما** اجرا می‌شود و هرگز به شبکه \
                نمی‌رود.
                """),
            .table(
                headers: ["کار", "ابزار"],
                rows: [
                    ["بریدن سندها به پاره‌ها", "پیش‌نمایش تکه‌کردن"],
                    ["بررسی و نمره‌دهی پاره‌ها", "بازرسی تکه‌های JSONL"],
                    ["گرداندن میان صورت‌های داده", "گرداندن دانش"],
                    ["ساختن و بررسی گراف پیوندها", "گراف دانش"],
                    ["یافتن نام‌های خاص در متن", "نشانه‌گذاری هستارها"],
                    ["سنجیدن کیفیت بازیابی", "آزمایشگاه بازیابی"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "تکه‌کردن و بررسی یک پیکرهٔ JSONL",
        summary: "مرز تکه‌ها را روی خودِ متن پیش‌نمایش ببینید، سپس تمام پیکره را نمره دهید.",
        keywords: ["تکه", "jsonl", "پیکره", "هم‌پوشانی", "توکن"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("پیش‌نمایش تکه‌کردن"),
            .paragraph("""
                سندی متنی یا Markdown بگشایید، راهبرد و اندازهٔ تکه‌ای برگزینید. مرزها **روی خودِ متن \
                برجسته** می‌شوند، پس پیش از برون‌بری هر چیز می‌بینید کجا برشی در میانهٔ جمله یا از میان \
                جدولی می‌افتد.
                """),
            .bullets([
                "**اندازهٔ ثابت** با هم‌پوشانی.",
                "**بر پایهٔ ساختار** — بر سرنویس‌های Markdown، با نگه داشتن روال سند.",
                "**بر پایهٔ بند**، با آمیختن تا رسیدن به اندازه.",
            ]),
            .heading("بررسی پیکرهٔ JSONL موجود"),
            .paragraph("""
                برای پیکره‌ای که از پیش دارید (هر سطر یک تکهٔ JSON)، `JSONL: بازرسی تکه‌ها…` پاسخ می‌دهد: \
                کدام سطرها JSON نامعتبرند، کدام تکه‌ها بیش‌ازاندازه کوتاه یا درازند، کدام‌ها یکدیگر را \
                تکرار می‌کنند، و کدام‌ها در میانهٔ جمله بریده شده‌اند.
                """),
            .note("""
                پیکره را می‌توان با **همان چارچوب شش‌بُعدی** دادهٔ جدولی نیز نمره داد — کلید `corpus:` را در \
                بلوک `quality` گزارش به کار برید.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "گرداندن قالب‌های دانش",
        summary: "تکه‌ها میان JSONL · CSV · Markdown، گراف‌ها میان DOT · Mermaid · فهرست یال.",
        keywords: ["گرداندن", "jsonl", "dot", "mermaid", "فهرست یال"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["از", "به"],
                rows: [
                    ["تکه‌های JSONL", "CSV · Markdown"],
                    ["تکه‌های CSV", "JSONL · Markdown"],
                    ["گراف DOT", "Mermaid · فهرست یال"],
                    ["فهرست یال", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                پیش از ساختن زبانهٔ نو **پیش‌نمایشی پنج‌ردیفی** هست، همان سازوکار گرداندن CSV.
                """),
            .paragraph("""
                `گشودن سه‌تایی‌ها/یال‌ها چون جدول` پروندهٔ سه‌تایی یا فهرست یال را چون جدولی نشان می‌دهد — \
                آن را مانند هر CSV دیگر بپالایید و مرتب کنید.
                """),
            .note("""
                سوی **Markdown ← JSONL** در این فرمان نیست: آن سو *همان* تکه‌کردن است، و فرمان شما را به \
                آنجا راهنمایی می‌کند. دو پیاده‌سازی از یک برش، دو نتیجهٔ گوناگون می‌ساخت.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "گراف‌های دانش",
        summary: "نحو را بررسی کنید، سلامت را نمره دهید، و الگوریتم‌ها را بر گراف‌های میلیون‌یالی اجرا کنید.",
        keywords: ["گراف", "dot", "cypher", "pagerank", "louvain", "بررسی نحو"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                ‏GEditor گراف‌ها را چون **DOT**، **فهرست یال** و **سه‌تایی** می‌خواند. `بررسی نحو گراف` \
                خطاهای نحوی، گره‌های آویزان و یال‌هایی را که به گره‌های ناموجود اشاره می‌کنند می‌گیرد.
                """),
            .heading("الگوریتم‌های در دسترس"),
            .table(
                headers: ["الگوریتم", "به چه پاسخ می‌دهد"],
                rows: [
                    ["همسایگی k گامی", "در k گام چه چیز با این گره مرتبط است"],
                    ["مؤلفه‌های همبند", "گراف به چند پارهٔ جدا می‌شکند"],
                    ["PageRank", "کدام گره‌ها مهم‌اند"],
                    ["Louvain", "گراف چگونه به جامعه‌ها بخش می‌شود"],
                ]
            ),
            .paragraph("""
                بر گرافی **میلیون‌یالی** هر چهار میان چند هزارم ثانیه و حدود یک ثانیه اجرا می‌شوند.
                """),
            .note("""
                گراف را نیز می‌توان با **چارچوب شش‌بُعدی** جدول‌ها و پیکره‌ها نمره داد — کلید `graph:` را در \
                بلوک `quality` به کار برید.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "نشانه‌گذاری هستارها از یک فهرست",
        summary: "فهرستی از نام‌های خاص بار کنید و هر مورد را بیابید — با سه قاعده که برای ویتنامی ساخته شده‌اند.",
        keywords: ["هستار", "نام خاص", "ner", "نشانه‌گذاری", "واژه‌نامه", "تطبیق"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                فهرستی از نام‌ها (شرکت، فرآورده، مکان) بار کنید و GEditor هر مورد را در سند برجسته \
                می‌کند، با جدولی از شمارش.
                """),
            .heading("سه قاعدهٔ تطبیق، همه از دادهٔ ویتنامی"),
            .bullets([
                "**درازترین تطبیق برنده است.** با بودن هر دو `An Phát` و `Công ty An Phát` در فهرست، جمله‌ای که عبارت درازتر را دارد باید با درازتر منطبق شود — وگرنه به دو پاره می‌شکند و دو هستار شمرده می‌شود، که آمار را **باد می‌کند**.",
                "**مرز واژه بایسته است.** `An` نباید درون `Anh` یا `Hoàn` منطبق شود. نام‌های خاص ویتنامی کوتاه‌اند و با واژه‌های عادی بی‌شماری هجا مشترک دارند.",
                "**بی‌اعتنا به بزرگی حروف، اما حساس به اعراب.** `CÔNG TY` و `Công ty` یکی‌اند؛ `má` و `ma` نه.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "یکسان‌سازی گونه‌های هستار",
        summary: "`Cty An Phát` و `Công ty An Phát` را یکی بشناسید — و تصمیم را باز هم به شما بسپارید.",
        keywords: ["یکسان‌سازی هستار", "گونه‌ها", "هنجارسازی نام", "تکرار"],
        blocks: [
            .paragraph("""
                همان خوشه‌بندی **تکرارهای مبهم** در جدول CSV — یک پیاده‌سازی مشترک، نه دو.
                """),
            .paragraph("""
                خروجی یک **پیشنهاد** است: هر خوشه را بازبینی می‌کنید و صورت معیار را برمی‌گزینید. دکمهٔ \
                «همه را بیامیز» نیست، چون دو نام که ۹۲٪ شبیه‌اند شاید دو سازمان راستین باشند.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "آزمایشگاه بازیابی",
        summary: "با مجموعه‌ای پرسش و پاسخ بسنجید که نمایه چیز درست را می‌یابد یا نه.",
        keywords: ["بازیابی", "bm25", "فراخوانی", "mrr", "ndcg", "ارزیابی", "مجموعهٔ طلایی"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                یک **مجموعهٔ ارزیابی** بار کنید — هر سطر یک پرسش با شناسهٔ تکه‌هایی که باید بازگردند — سپس \
                تمام دسته را بر نمایه اجرا کنید.
                """),
            .table(
                headers: ["سنجه", "به چه پاسخ می‌دهد"],
                rows: [
                    ["recall@k", "چه اندازه از مجموعهٔ پاسخ در k نخست پدیدار می‌شود"],
                    ["MRR", "نخستین نتیجهٔ درست چقدر پایین می‌نشیند"],
                    ["nDCG@k", "آیا رتبه‌بندی خوب است، با در نظر گرفتن جایگاه"],
                ]
            ),
            .paragraph("""
                نتیجه‌ها **برای هر پرسش** نیز می‌آیند، بدترین‌ها نخست — و همان فهرست چیزهایی است که باید در \
                پیکره درست کنید، به ترتیبی که بیش از همه ارزش درست کردن دارد.
                """),
            .warning("""
                هر سه سنجه **میانگین**اند، و میانگین بسیار پنهان می‌کند. پیش از نتیجه گرفتن که «نمایه به \
                اندازهٔ کافی خوب است»، همیشه جدول هر پرسش را بخوانید.
                """),
            .paragraph("""
                دو پیکربندی را می‌توان پهلوبه‌پهلو سنجید، و نتیجه مستقیم در گزارش `.greport.md` می‌افتد تا \
                اجرای بعدی یکسان باشد.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - ماکرو و خودکارسازی

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "ماکرو و خودکارسازی",
        summary: "کارها را ضبط کنید، انبوه اجرا کنید، اسکریپت بنویسید، و از پوسته برانید.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "ضبط و پخش ماکرو",
        summary: "دنباله‌ای را ضبط و تکرار کنید — تمام اجرا یک گام واگردانی است.",
        keywords: ["ماکرو", "ضبط", "پخش", "تکرار", "خودکارسازی"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "آغاز / پایان ضبط"),
                HelpShortcut("⌃P", "پخش"),
            ]),
            .steps([
                "`⌃R` ضبط را می‌آغازد.",
                "آنچه را می‌خواهید تکرار شود انجام دهید — بنویسید، مکان‌نما را بجنبانید، بیابید، جایگزین کنید.",
                "دوباره `⌃R` برای ایستادن.",
                "`⌃P` پخشش می‌کند، یا `ماکرو ▸ پخش تا پایان سند` تا پایان اجرایش می‌کند.",
                "`ماکرو ▸ ذخیرهٔ ماکرو…` برای نشست‌های بعدی نامش می‌دهد.",
            ]),
            .heading("فرمان‌ها را ضبط می‌کند، نه فشردن خامِ کلید"),
            .paragraph("""
                ماکرو **آنچه کرده‌اید** را نگه می‌دارد، نه اینکه کدام کلیدها را فشرده‌اید. همین آن را از \
                چیدمان صفحه‌کلید و از شیوهٔ ورودی فعال مستقل می‌کند، و پروندهٔ ماکرو را هنگام گشودن \
                **خواندنی** می‌سازد.
                """),
            .heading("ماکرو کِی می‌ایستد"),
            .table(
                headers: ["دلیل", "معنا"],
                rows: [
                    ["شمار تکرار تمام شد", "عادی"],
                    ["گام `find` چیزی نیافت", "«پخش تا پایان پرونده» بدین‌گونه خود را می‌ایستاند"],
                    ["رسیدن به پایان سند", "جای دورتری نیست"],
                    ["شما لغو کردید", "`ماکرو ▸ لغو ماکروی در حال اجرا`"],
                    ["تکراری که چیزی نگرداند و جایی نرفت", "ایستاده شد تا تا ابد نچرخد"],
                ]
            ),
            .note("""
                تمام اجرا — حتی ده هزار تکرار — **یک** گام واگردانی است.
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "اجرای انبوه ماکرو",
        summary: "بر هر زبانهٔ گشوده، یا بر پوشه‌ای از پرونده‌های نگشوده.",
        keywords: ["دسته", "همهٔ زبانه‌ها", "پوشه", "ماکرو", "نقاب"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["فرمان", "دامنه", "واگردانی‌پذیر"],
                rows: [
                    ["اجرا بر همهٔ زبانه‌ها", "زبانه‌های گشوده", "بله — یک گام واگردانی برای هر زبانه"],
                    ["اجرا بر یک پوشه…", "پرونده‌های **نگشوده** بر دیسک", "خیر"],
                ]
            ),
            .warning("""
                اجرا بر یک پوشه به پرونده‌هایی دست می‌زند که در هیچ زبانه‌ای گشوده نیستند، پس **واگردانی \
                نیست**. به‌طور پیش‌فرض GEditor **پرونده‌های نو می‌نویسد** به‌جای بازنویسی روی اصل‌ها. مگر \
                پشتیبان یا مخزنی با کنترل نسخه دارید، همان پیش‌فرض را نگه دارید.
                """),
            .heading("پالایش پرونده‌ها با نقاب"),
            .paragraph("""
                گزینندهٔ پوشه **پالایه‌ای برای نام پرونده** دارد: `*.csv;*.log` بنویسید و ماکرو تنها به \
                همان‌ها دست می‌زند. همان نحو نقابی است که `جست‌وجو در سراسر پوشه` به کار می‌برد، و چند \
                الگو با `;` یا `,` جدا می‌شوند.
                """),
            .bullets([
                "**تهی** بگذارید و هر پروندهٔ متنی را که GEditor می‌تواند بخواند می‌گیرد — رفتار پیشین.",
                "نقاب به‌جای تنگ‌تر کردن آن فهرست پسوندها، **جایش را می‌گیرد**: `*.bak` بنویسید و بر پرونده‌های `.bak` اجرا می‌شود، هرچند آن پسوند در فهرست متنی نیست.",
                "اگر چیزی منطبق نشود، پیام **نقاب شما را برایتان بازمی‌گوید** به‌جای گناهکار خواندن پوشه‌ای تهی.",
            ]),
            .paragraph("""
                این کادر دلیلی بسیار کاربردی دارد: پوشه‌ای ۴۰۰ پروندهٔ `.json` و ۱۲ پروندهٔ `.log` دارد، و \
                ماکروی شما تنها گزارش‌ها را سامان می‌دهد. بی نقاب آن ۴۰۰ تای دیگر هم پردازش می‌شوند — و \
                چون دسته پرونده‌های نو می‌نویسد، یک اشتباه ۴۰۰ تکه آشغال بر جای می‌گذارد.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "نحو پروندهٔ ماکرو",
        summary: "هفت گونه گام، قالب کامل JSON، و دو ماکرو که اجرا می‌شوند.",
        keywords: ["ماکرو", "json", "نحو", "ویرایش دستی", "هم‌رسانی"],
        blocks: [
            .paragraph("""
                هر ماکرو **پروندهٔ JSON خودش** در پوشهٔ `macros/` از آنِ GEditor است. تباهی در یک ماکرو \
                محدود می‌ماند، و هم‌رسانی یکی با همکاری یعنی فرستادن یک پرونده.
                """),
            .code(
                language: "text",
                caption: "پرونده‌ها کجا می‌زیند",
                source: """
                    ~/Library/Application Support/GEditor/macros/<نام-ماکرو>.json
                    """
            ),
            .heading("هفت گونه گام"),
            .table(
                headers: ["گام", "چنین نوشته می‌شود", "معنا"],
                rows: [
                    ["درج متن", "`{\"insert\": {\"_0\": \"متن\"}}`", "در مکان‌نما می‌نویسد؛ با گزیده، جایش را می‌گیرد"],
                    ["زدودن به عقب", "`{\"deleteBackward\": {}}`", "مانند کلید Delete"],
                    ["زدودن به جلو", "`{\"deleteForward\": {}}`", "مانند ⌦"],
                    ["جابه‌جایی", "`{\"move\": {\"_0\": \"nextLine\"}}`", "فهرست سوها را زیر ببینید"],
                    ["گزینش سطر", "`{\"selectLine\": {}}`", "بی پایان‌سطر"],
                    ["یافتن", "`{\"find\": { … }}`", "مورد بعدی را می‌یابد و **برمی‌گزیند**"],
                    ["جایگزینی گزیده", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` آنگاه کار می‌کند که گام پیشین `find` با regex بوده"],
                ]
            ),
            .heading("سوهای حرکت"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("گام `find` کامل"),
            .code(
                language: "json",
                caption: "چهار کلید یک گام find",
                source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """
            ),
            .paragraph("`mode` مقدار `normal`، `extended` یا `regex` می‌گیرد — همان سه حالت کادر جست‌وجو."),
            .heading("نمونهٔ ۱ — بزرگ کردن کد استان در آغاز هر سطر"),
            .code(
                language: "json",
                caption: "macros/uppercase-province.json",
                source: """
                    {
                      "name": "کد استان با حروف بزرگ",
                      "steps": [
                        {
                          "find": {
                            "pattern": "^([a-z]{2,3})\\\\t",
                            "mode": "regex",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "replaceSelection": { "_0": "\\\\U$1\\\\E\\t" } }
                      ]
                    }
                    """
            ),
            .paragraph("""
                با `ماکرو ▸ پخش تا پایان سند` اجرایش کنید: اینکه گام `find` دیگر چیزی نمی‌یابد دقیقاً همان \
                شرط ایستادن است.
                """),
            .heading("نمونهٔ ۲ — زدودن سطر پس از هر سطری که TODO دارد"),
            .code(
                language: "json",
                caption: "macros/delete-line-after-todo.json",
                source: """
                    {
                      "name": "زدودن سطر پس از TODO",
                      "steps": [
                        {
                          "find": {
                            "pattern": "TODO",
                            "mode": "normal",
                            "matchCase": true,
                            "wholeWord": false
                          }
                        },
                        { "move": { "_0": "nextLine" } },
                        { "move": { "_0": "lineStart" } },
                        { "selectLine": {} },
                        { "deleteForward": {} },
                        { "deleteForward": {} }
                      ]
                    }
                    """
            ),
            .warning("""
                ماکروی دستی‌ویرایش‌شده را نخست روی رونوشتی بیازمایید. گام `find`ی که غلط نوشته شده ماکرو \
                را بی‌درنگ می‌ایستاند — این حالت خوش‌خیم است. حالت بدخیم الگویی است که گسترده‌تر از پندار \
                شما منطبق می‌شود و هزاران جا را درون یک گام واگردانی ویرایش می‌کند.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "اسکریپت‌های JavaScript",
        summary: "چهار تابع، یک پروندهٔ `.js`، و هر چه می‌کند یک گام واگردانی است.",
        keywords: ["اسکریپت", "javascript", "js", "خودکارسازی", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                پروندهٔ `.js` را در پوشهٔ `scripts/` از آنِ GEditor بگذارید و از `ماکرو ▸ اسکریپت…` \
                اجرایش کنید. یک اسکریپت دقیقاً **چهار** چیز می‌بیند:
                """),
            .table(
                headers: ["فراخوان", "معنا"],
                rows: [
                    ["`doc.text`", "تمام متن سند"],
                    ["`doc.selection`", "گزیده (رشتهٔ تهی آنگاه که چیزی گزیده نیست)"],
                    ["`doc.replace(s)`", "جایگزینی **تمام سند** با `s` — یک گام واگردانی"],
                    ["`doc.log(s)`", "نوشتن سطری در تابلوی نتیجه‌ها"],
                ]
            ),
            .code(
                language: "javascript",
                caption: "scripts/number-lines.js",
                source: """
                    // هر سطر را شماره بزن.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("سطرهای شماره‌خورده: " + (lines.length - 1));
                    doc.replace(out.join("\\n"));
                    """
            ),
            .code(
                language: "javascript",
                caption: "scripts/keep-three-columns.js — نگه‌داشتن سه ستون نخست CSV",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("سطرهای کوتاه‌شده به ۳ ستون: " + out.length);
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("سه مرز که باید دانست"),
            .bullets([
                "**نه دسترسی به پرونده، نه شبکه، نه راه‌اندازی فرایند.** سطح API به‌عمد تنگ است: گشاده‌ترش کردن بعدها آسان است، تنگ‌ترش کردن هر اسکریپتی را که کاربران نوشته‌اند می‌شکند.",
                "**این مرزی امنیتی نیست.** اسکریپت‌ها در همان فرایند اجرا می‌شوند. اسکریپتی را که نخوانده‌اید اجرا نکنید.",
                "**مرزی پنج‌ثانیه‌ای هست.** فراتر از آن پیامی می‌گیرید و برنامه به‌کاربردنی می‌ماند — اما رشتهٔ آن اسکریپت **تا بیرون رفتن‌تان می‌چرخد** و هسته‌ای را می‌خورد. پیام همین را می‌گوید.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "پالایش از راه فرمانی بیرونی",
        summary: "گزیده را از فرمانی یونیکسی بگذرانید و نتیجه را بازبگیرید.",
        keywords: ["پالایه", "فرمان بیرونی", "پوسته", "لوله", "sort", "jq", "یونیکس"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                گزیده (یا تمام سند) به `stdin` فرمانی خورانده می‌شود، و `stdout` همان فرمان جایش را \
                می‌گیرد.
                """),
            .code(
                language: "bash",
                caption: "چند نمونهٔ رایج",
                source: """
                    sort -u                     # مرتب کن و تکرارها را بینداز
                    jq .                        # JSON را بازقالب‌بندی کن
                    tr 'a-z' 'A-Z'              # به حروف بزرگ بگردان
                    grep -v '^#'                # سطرهای توضیح را بینداز
                    awk -F, '{print $3","$1}'   # ترتیب ستون‌ها را عوض کن
                    """
            ),
            .note("""
                نتیجه **یک** گام واگردانی است. اگر فرمان کد خطا بازگرداند، GEditor متن را دست‌نخورده \
                می‌گذارد و `stderr` را نشان می‌دهد.
                """),
            .warning("""
                این فرمان **تنها در نسخهٔ بارگیری مستقیم** هست. App Sandbox اجرای کد بیرون از برنامه را \
                ممنوع می‌کند، پس در نسخهٔ App Store گزینهٔ منو می‌ماند و توضیح می‌دهد چرا در دسترس نیست.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "ابزار خط فرمان `geditor`",
        summary: "بگشایید، پاک کنید، بپرسید، نمره دهید و گزارش بنمایانید — بی گشودن برنامه.",
        keywords: ["cli", "خط فرمان", "پایانه", "geditor", "اسکریپت", "ci"],
        blocks: [
            .warning("""
                تنها در نسخهٔ **بارگیری مستقیم** در دسترس است. نسخهٔ App Store در جعبهٔ شنی اجرا می‌شود، \
                پس فرایند خط فرمان بیرونی نمی‌تواند به آن بپیوندد.
                """),
            .heading("گشودن پرونده‌ها"),
            .code(
                language: "bash",
                caption: "بگشا، به جایگاهی بپر، از لوله بخوان",
                source: """
                    geditor report.csv
                    geditor report.csv:120:5       # سطر ۱۲۰، ستون ۵
                    geditor -w notes.md            # پیش از بیرون رفتن تا بسته شدن پرونده صبر کن
                    geditor -r app.log             # فقط‌خواندنی بگشا
                    git diff | geditor             # stdin را در زبانه‌ای نو بخوان
                    """
            ),
            .table(
                headers: ["گزینه", "معنا"],
                rows: [
                    ["`-w`, `--wait`", "پیش از بیرون رفتن تا بسته شدن پرونده صبر کن — برای به‌کاربردن چون ویرایشگر `git`"],
                    ["`-n`, `--new-window`", "در پنجره‌ای نو بگشا"],
                    ["`-r`, `--read-only`", "فقط‌خواندنی بگشا"],
                    ["`-i`, `--info`", "کدگذاری، پایان‌سطرها و شمار سطرها را چاپ کن سپس بیرون برو — **بی** گشودن برنامه"],
                    ["`-h`, `--help`", "راهنما را نشان بده"],
                    ["`-v`, `--version`", "نسخه را نشان بده"],
                ]
            ),
            .heading("اجرا بی گشودن برنامه"),
            .paragraph("""
                چهار دستهٔ فرمان زیر **یکسره درون فرایند خط فرمان** اجرا می‌شوند، پس در CI کار می‌کنند \
                جایی که کسی در نشستی گرافیکی نیست.
                """),
            .code(
                language: "bash",
                caption: "پاک‌سازی با یک دستور",
                source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "پرس‌وجو",
                source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "دروازهٔ کیفیت — کد خروجی ۰ قبول · ۱ رد · ۲ خطا",
                source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "نمایاندن گزارش‌ها",
                source: """
                    geditor --report template.greport.md --param-list list.csv --out ./reports/
                    """
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript و منوی خدمات",
        summary: "سند را از AppleScript بخوانید و بنویسید، یا از برنامه‌ای دیگر متن به GEditor بفرستید.",
        keywords: ["applescript", "osascript", "خدمات", "خودکارسازی", "shortcuts"],
        blocks: [
            .code(
                language: "applescript",
                caption: "سند گشوده را بخوان",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "روی محتوا بنویس، و گزیده را بخوان",
                source: """
                    tell application "GEditor"
                        set selected text to "متنی که جای گزیده می‌نشیند"
                        set contents to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "پرونده‌ای بگشا",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """
            ),
            .heading("منوی خدمات"),
            .paragraph("""
                در هر برنامه‌ای متنی برگزینید، سپس با منوی `خدمات` آن را چون زبانه‌ای نو به GEditor \
                بفرستید.
                """),
            .note("""
                بار نخست که AppleScript را اجرا کنید، macOS اجازهٔ خودکارسازی می‌خواهد. آن پنجرهٔ سامانه \
                است نه GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "بسته‌های گسترش و افزونه‌ها",
        summary: "دو گونه گسترش، و اینکه هر یک در کدام نسخه اجرا می‌شود.",
        keywords: ["افزونه", "گسترش", "بسته", "بومی"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("بسته‌های گسترش"),
            .paragraph("""
                بسته **یک پروندهٔ JSON** است که پوسته‌ای، اسکریپت‌ها و زبان‌های کاربرساخته را با هم \
                می‌بندد. نصب یک پرونده رونوشت می‌کند، برداشتن یکی می‌زداید — و فهرست بسته‌ها از **دیسک** \
                برمی‌آید، نه از دفتری که می‌تواند دروغ بگوید.
                """),
            .paragraph("در **هر دو نسخه** کار می‌کند."),
            .heading("افزونه‌های بومی"),
            .paragraph("""
                افزونه‌های از پیش کامپایل‌شده در **فرایندی جدا** با سطح API‌ای تنگ اجرا می‌شوند — افزونه‌ای \
                که فرو می‌ریزد برنامه را با خود نمی‌برد.
                """),
            .warning("""
                افزونه‌های بومی **تنها در نسخهٔ بارگیری مستقیم** هستند، چون App Sandbox بار کردن کد از \
                بیرون برنامه را ممنوع می‌کند. هر افزونه باید پیش از اجرا **یک بار دستی بر پایهٔ درهم‌سازش \
                تأیید شود**.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - پیکربندی و برنامه

    static let application = HelpChapter(
        id: "ung-dung",
        title: "پیکربندی و برنامه",
        summary: "تنظیمات، میان‌برها، پوسته‌ها، به‌روزرسانی‌ها، کوچ از Notepad++، عیب‌یابی.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "تنظیمات",
        summary: "هر گزینه در یک پروندهٔ JSON خواندنی می‌زید که می‌توانید به Macی دیگر رونوشت کنید.",
        keywords: ["تنظیمات", "ترجیحات", "گزینه‌ها", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "گشودن تنظیمات")]),
            .paragraph("""
                نه تأییدی هست نه لغوی — دگرگونی بی‌درنگ اثر می‌کند و نوشته می‌شود، به شیوهٔ macOS.
                """),
            .heading("پروندهٔ پیکربندی"),
            .code(
                language: "text",
                caption: "کجا می‌زید",
                source: """
                    ~/Library/Application Support/GEditor/settings.json
                    """
            ),
            .paragraph("""
                **پروندهٔ JSON تورفته‌ای است که می‌توانید بخوانید و دستی ویرایش کنید**. به Macی دیگر \
                رونوشتش کنید و تمام پیکربندی‌تان همراهش می‌رود. دکمهٔ `گشودن پروندهٔ پیکربندی` در تنظیمات \
                یکراست شما را آنجا می‌برد.
                """),
            .heading("کلیدها"),
            .table(
                headers: ["کلید", "پیش‌فرض", "معنا"],
                rows: [
                    ["`fontSize`", "`13`", "اندازهٔ قلم ویرایشگر"],
                    ["`tabWidth`", "`4`", "TAB چند ستون پهناست"],
                    ["`usesTabsForIndent`", "`false`", "تورفتگی با TAB به‌جای فاصله"],
                    ["`languageIndent`", "`{}`", "تورفتگی برای هر زبان — صفحهٔ فاصله‌ها را ببینید"],
                    ["`smartIndent`", "`true`", "تورفتگی خودکار در سطر نو"],
                    ["`highlightAllMatches`", "`true`", "برجسته کردن هر مورد یافته"],
                    ["`ligatures`", "`false`", "پیوندنویسه‌ها — یادداشت زیر جدول را ببینید"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "بریدن فاصله‌های پایان سطر هنگام ذخیره"],
                    ["`normalizeToNFCOnSave`", "`false`", "هنجارسازی یونیکد به NFC هنگام ذخیره"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "کدگذاری پرونده‌های نو"],
                    ["`defaultEOL`", "`\"lf\"`", "پایان‌سطر پرونده‌های نو"],
                    ["`language`", "`\"system\"`", "زبان رابط"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "پوستهٔ پیش‌فرض", "کدام پوستهٔ رنگی در کار است"],
                    ["`showWelcomeOnLaunch`", "`true`", "گشودن پنجرهٔ خوش‌آمد هنگام آغاز"],
                    ["`keyBindings`", "`{}`", "تنها کلیدهایی که از پیش‌فرض گردانده‌اید"],
                ]
            ),
            .note("""
                **چرا پیوندنویسه‌ها به‌طور پیش‌فرض خاموش‌اند.** پیوندنویسه `!=` یا `->` را در **یک** \
                نگاره می‌آمیزد، پس نویسه‌هایی که بر پرده می‌بینید دیگر با نویسه‌های درون پرونده یکی نیستند \
                — حال آنکه ویرایشگر ستون، حالت ستونی و شکستن در ستون همه با ستون می‌سنجند. آنگاه روشنش \
                کنید که نثر می‌نویسید، یا قلمی برنامه‌نویسی (Fira Code، JetBrains Mono) را دقیقاً برای \
                پیوندنویسه‌هایش برگزیده‌اید.
                """),
            .heading("پوشه‌های همسایه"),
            .table(
                headers: ["پوشه", "چه دارد"],
                rows: [
                    ["`macros/`", "ماکروهای ذخیره‌شده، هر یک یک پروندهٔ JSON"],
                    ["`scripts/`", "اسکریپت‌های JavaScript"],
                    ["`themes/`", "پوسته‌های رنگی"],
                    ["`grammars/`", "زبان‌های کاربرساخته"],
                ]
            ),
            .warning("""
                پروندهٔ پیکربندی‌ای که GEditor **نوتر** نوشته باشد به دست کهنه‌تر **بازنوشته نمی‌شود** — آن \
                بر پیش‌فرض‌ها اجرا می‌شود و همین را می‌گوید. بازنویسی مطمئن‌ترین راه نابودی پیکربندی کسی \
                است که دو دستگاه را هم‌گام می‌کند، و او هرگز درنمی‌یافت چرا.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "نوار وضعیت",
        summary: "ده بخش در پایین — هر یک خواندنی، و هر یک کلیک‌پذیر.",
        keywords: ["نوار وضعیت", "نوار پایین", "جابه‌جایی", "جایگاه", "کدگذاری", "فقط‌خواندنی"],
        blocks: [
            .paragraph("""
                این بزرگ‌ترین تفاوت با نوارهای وضعیت دیگر ویرایشگران است: **هیچ بخشی فقط‌نمایشی نیست**. \
                مقداری نادرست ببینید و کلیک بر آن راه درست کردنش است، نه گشتن در منوها.
                """),
            .table(
                headers: ["بخش", "به شما می‌گوید", "کلیک بر آن"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "جایگاه مکان‌نما — ستون به نویسه، `@340` جایگاه بایت",
                     "کادر `رفتن به` را می‌گشاید"],
                    ["`11 byte · 3 dòng`", "اندازهٔ سند",
                     "بایت · نویسه · واژه · سطر می‌شمارد"],
                    ["`🔒 Chỉ đọc`", "تنها آنگاه که سند قفل است نمایان می‌شود",
                     "می‌گوید چرا قفل است، و اگر شدنی باشد بازش می‌کند"],
                    ["`View` / `Code`", "در کدام نما هستید", "جابه‌جا می‌کند (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "حالت CSV و جداکنندهٔ در کار",
                     "حالت CSV را جابه‌جا می‌کند، یا **جداکننده را دوباره برمی‌گزیند**"],
                    ["`Đang theo dõi`", "`tail -f` اجرا می‌شود", "—"],
                    ["`UTF-8`", "کدگذاری", "بازتفسیر کن، یا به کدگذاری‌ای دیگر بگردان"],
                    ["`LF`", "سبک پایان‌سطر", "میان LF · CRLF · CR جابه‌جا کن"],
                    ["`Python`", "زبان رنگ‌آمیزی نحو", "دیگری برگزین، یا به تشخیص با پسوند بازگرد"],
                    ["`Tab: 4`", "پهنای تورفتگی", "۲ · ۴ · ۸، سراسری یا **تنها برای این زبان**"],
                    ["`Ngắt: tắt`", "حالت شکستن نرم", "میان سه حالت می‌چرخد"],
                ]
            ),
            .heading("سه بخش که نگاه دوباره می‌ارزند"),
            .bullets([
                "**`@340` — جایگاه بایت.** این همان عددی است که هر ابزار دیگر در این فرآورده به آن سخن می‌گوید: خطاهای JSON و XML، خروجی `--doc-sweep`، نمایشگر دودویی، و کادر `رفتن به @340`. اینجا بخوانید، آنجا بنویسید.",
                "**`~` روی ستون** یعنی عدد بایت می‌شمارد نه ستون دیداری — این تنها در سطرهای درازتر از ۲۰۰ کیلوبایت رخ می‌دهد، جایی که شمردن نویسه هر جنبش مکان‌نما را کند می‌کرد.",
                "**`CSV · …` برای بازگزینش جداکننده کلیک‌پذیر است.** شناسایی می‌تواند نادرست باشد، و آنگاه هر عملیات ستونی بی هیچ نشانه‌ای به بیراهه می‌رود. این راه شماست برای گفتن دیگرگونه — تنها پرونده را **بازمی‌خواند** و حتی یک بایت هم نمی‌گرداند (برخلاف `CSV ▸ دگرگون کردن جداکننده…` که بازش می‌نویسد).",
            ]),
            .note("""
                بخشی که به پروندهٔ گشوده مربوط نیست **پنهان می‌شود** نه خاکستری: `فقط‌خواندنی` تنها آنگاه \
                می‌آید که سند به‌راستی قفل باشد، و `CSV · …` تنها در حالت CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "دگرگون کردن میان‌برهای صفحه‌کلید",
        summary: "کلیدهای تکی را بگردانید، یا نقشهٔ Notepad++ را یکجا بپذیرید.",
        keywords: ["میان‌بر", "پیوند کلید", "نقشهٔ کلید", "پیش‌آماده"],
        blocks: [
            .paragraph("""
                `تنظیمات…` بخشی برای میان‌برها با دو دکمهٔ تند دارد: **از پیش‌آمادهٔ Notepad++ بهره ببر** \
                و **بازگشت به پیش‌فرض‌ها**.
                """),
            .paragraph("""
                پروندهٔ پیکربندی تنها آنچه را **از پیش‌فرض‌ها گردانده‌اید** ثبت می‌کند. بدین‌گونه، وقتی \
                GEditor در نسخه‌ای نو کلیدی پیش‌فرض را می‌گرداند، شما با نقشهٔ کهنه گیر نمی‌افتید بی‌آنکه \
                کسی به شما بگوید.
                """),
            .note("""
                دو فرمان نمی‌توانند یک میان‌بر را شریک شوند. آنگاه که چنین شود، AppKit خاموشانه تنها \
                **نخستین** گزینهٔ منو را می‌راند و فرمان دیگر شکسته می‌نماید — پس در GEditor بررسی‌ای هست \
                که جلوی آن را می‌گیرد.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "پوسته‌ها، روشن و تاریک",
        summary: "پیروی از سامانه، روشن یا تاریک؛ و پوسته پروندهٔ JSON‌ای است که می‌توانید ویرایشش کنید.",
        keywords: ["پوسته", "رنگ", "حالت تاریک", "روشن", "ظاهر"],
        blocks: [
            .paragraph("""
                `تنظیمات…` میان `پیروی از سامانه`، `روشن` یا `تاریک` برمی‌گزیند، و پوسته‌ای رنگی تعیین \
                می‌کند.
                """),
            .paragraph("""
                پوسته پروندهٔ JSON‌ای در `themes/` است. دکمهٔ `برون‌بری پوستهٔ کنونی` یکی می‌نویسد تا برای \
                پوستهٔ خودتان نقطهٔ آغاز باشد.
                """),
            .note("""
                رنگی که در پروندهٔ پوسته غلط نوشته شده به رنگ **پوستهٔ پیش‌فرض** بازمی‌گردد، نه به سیاه. \
                سیاه چون تصمیمی طراحانه می‌نماید، و کاربر مشکل را جای دیگری می‌جست.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "به‌روزرسانی، نسخه‌ها و بیرون رفتن",
        summary: "به‌روزرسانی میان دو نسخه چه فرقی دارد.",
        keywords: ["به‌روزرسانی", "نسخه", "درباره", "بیرون رفتن"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["نسخه", "از این راه به‌روز می‌شود"],
                rows: [
                    ["App Store", "App Store، مانند هر برنامهٔ دیگر"],
                    ["بارگیری مستقیم", "`بررسی به‌روزرسانی…` درون برنامه"],
                ]
            ),
            .paragraph("""
                `دربارهٔ GEditor` نسخهٔ در حال اجرا و اینکه کدام نسخه است را نشان می‌دهد — هنگام گزارش \
                مشکل به کار می‌آید.
                """),
            .note("""
                در نسخهٔ App Store، `بررسی به‌روزرسانی…` **در منو می‌ماند** و توضیح می‌دهد چرا کاربرد \
                ندارد، به‌جای ناپدید شدن. گزینهٔ گمشدهٔ منو یک پرسش پشتیبانی است.
                """),
            .paragraph("""
                بیرون رفتن کاری را از دست نمی‌دهد: نشست بار دیگر که بگشایید بازمی‌گردد.
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "به‌کاربردن این پنجرهٔ راهنما",
        summary: "در کتاب بجویید، زبانش را بگردانید، و پنجرهٔ خوش‌آمد را بازگردانید.",
        keywords: ["راهنما", "دستور", "جست‌وجو", "خوش‌آمد", "زبان"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "گشودن پنجرهٔ راهنما")]),
            .bullets([
                "کادر جست‌وجوی بالا-چپ درون **متن اصلی و نمونه‌های کد** را می‌کاود — نوشتن کلیدی برهنه از تنظیمات مانند `fail_under` به صفحهٔ درست می‌رسد.",
                "نوشتن **بی اعراب** باز هم متن اعراب‌دار را می‌یابد.",
                "دکمهٔ `بازگشت` به صفحهٔ پیشین بازمی‌گردد.",
                "دکمهٔ `رونوشت` در هر بلوک کد همان بلوک را رونوشت می‌کند.",
            ]),
            .heading("خواندن به زبانی دیگر"),
            .paragraph("""
                منوی بازشو در بالا-راست این پنجره **زبان کتاب** را برمی‌گزیند، جدا از زبان رابط برنامه. \
                جابه‌جایی شما را **در همان صفحه‌ای که می‌خوانید** نگه می‌دارد — شناسه‌های صفحه به‌عمد ترجمه \
                نمی‌شوند، دقیقاً برای اینکه این کار کند.
                """),
            .note("""
                تنها زبان‌هایی فهرست می‌شوند که به‌راستی کتابی دارند. گزینه‌ای که به چیزی جابه‌جا کند و متن \
                را دست‌نخورده بگذارد، گزینه‌ای دروغ‌گو می‌بود.
                """),
            .heading("بازگرداندن پنجرهٔ خوش‌آمد"),
            .paragraph("""
                اگر **این پنجره را هنگام آغاز باز نکن** را تیک زده‌اید، با `راهنما ▸ گشت ویژگی‌ها` بازش \
                کنید — کادر تیک در پای پنجره دوباره پدیدار می‌شود و می‌توان تیکش را برداشت.
                """),
            .paragraph("""
                یا `showWelcomeOnLaunch` را در `settings.json` دوباره `true` کنید.
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "از Notepad++ به GEditor",
        summary: "کدام کلیدها جا عوض می‌کنند، چه چیز دیگرگونه کار می‌کند، و چه کم است.",
        keywords: ["notepad++", "notepad", "کوچ", "ویندوز", "میان‌بر"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                چند کلید در macOS **جای‌شان عوض می‌شود** و نه فقط `Ctrl` به `⌘` بدل می‌گردد. سنجش این است.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "چرا"],
                rows: [
                    ["`Ctrl+D` دوبرابر کردن سطر", "**⇧⌘D**", "`⌘D` اینجا چند مکان‌نماست، مانند هر ویرایشگر مکینتاش"],
                    ["`Ctrl+L` زدودن سطر", "**⌘K**", "`⌘L` در macOS یعنی «رفتن به سطر»"],
                    ["`Ctrl+G` رفتن به سطر", "**⌘L**", "این دو جای‌شان عوض می‌شود"],
                    ["`Ctrl+Q` توضیح", "**⌘/**", "عرف macOS"],
                    ["`Ctrl+Shift+↑/↓` جابه‌جایی سطر", "**⌥↑ / ⌥↓**", "`⌃` در macOS از آنِ Mission Control است"],
                    ["`F3` یافتن بعدی", "**⌘G**", "عرف macOS"],
                    ["`Ctrl+F2` نشانک", "**⌘F2**", "F2 و ⇧F2 هنوز میان نشانه‌ها می‌پرند"],
                    ["`Alt` + کشیدن برای ستون", "**⌥ + کشیدن**", "یکسان"],
                    ["`Ctrl+Alt+Shift+↓` ویرایشگر ستون", "**⌥⌘C**", "عرف macOS"],
                ]
            ),
            .note("""
                نمی‌خواهید از نو بیاموزید؟ `تنظیمات ▸ میان‌برها ▸ از پیش‌آمادهٔ Notepad++ بهره ببر`.
                """),
            .heading("چیزهایی که Notepad++ دارد و اینجا دیگرگونه کار می‌کنند"),
            .bullets([
                "**نشست‌ها** خودشان را بازمی‌گردانند، حتی زبانه‌های ذخیره‌نشده — چیزی برای روشن کردن نیست.",
                "**نشانک‌ها نُه رنگ دارند**، و یک سطر می‌تواند چند تا را با هم بردارد.",
                "**نقشهٔ سند** *تمام* پرونده را وصف می‌کند، نه فقط بخش دیدنی.",
                "**ماکروها** می‌توانند «تا پایان سند» و «بر همهٔ زبانه‌ها» پخش شوند، و تمام اجرا یک گام واگردانی است.",
            ]),
            .heading("چیزهایی که GEditor می‌افزاید"),
            .bullets([
                "**میز پاک‌سازی داده** و **نمای دادهٔ ستون‌ها** برای پرونده‌های CSV.",
                "**پرس‌وجوی SQL** مستقیم روی پروندهٔ CSV.",
                "**کدگذاری‌های کهن ویتنامی** — TCVN3، VISCII، VNI-Windows: خواندن، نوشتن و شناسایی خودکار.",
                "**جست‌وجوی بی‌اعتنا به اعراب** در هر کادر پالایش.",
                "**گزارش‌های `.greport.md`** با جدول‌ها و نمودارهایی که بازاجرا می‌شوند.",
                "**ابزار خط فرمان `geditor`** در نسخهٔ بارگیری مستقیم.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "مشکل‌های رایج",
        summary: "شش وضعیت که مردم را به گمان می‌اندازد برنامه شکسته است.",
        keywords: ["خطا", "مشکل", "کار نمی‌کند", "شکسته", "چرا"],
        blocks: [
            .table(
                headers: ["آنچه می‌بینید", "دلیل معمول"],
                rows: [
                    ["متن ویتنامی درهم می‌نماید", "کدگذاری نادرست — بر کدگذاری در نوار وضعیت کلیک کنید"],
                    ["جستن متن اعراب‌دار چیزی نمی‌یابد", "پرونده در یونیکد تجزیه‌شده است — `هنجارسازی یونیکد` به NFC اجرا کنید"],
                    ["گزینهٔ منو خاکستری است", "نسخهٔ App Store نمی‌تواند آن فرمان را اجرا کند — گزینه دلیلش را می‌گوید"],
                    ["تطبیق پرانتز از اجرا سر باز می‌زند", "سند بیش از ۱ مگابایت است — برجسته‌کردن جفت نادرست بدتر از هیچ است"],
                    ["ستون در نوار وضعیت `~` دارد", "سند بیش از ۲۰۰ کیلوبایت است، پس آن شمار بایت است نه ستون دیداری"],
                    ["پرس‌وجوی SQL می‌گوید پرونده باید نخست ذخیره شود", "DuckDB **پرونده** می‌خواند، نه میان‌گیری که ویرایش می‌کنید"],
                ]
            ),
            .heading("آنگاه که GEditor ناگهان بیرون می‌رود"),
            .paragraph("""
                در اجرای بعدی نواری همین را می‌گوید، با دکمهٔ **گشودن گزارش** — گزارش چون زبانه‌ای گشوده \
                می‌شود که مانند هر پروندهٔ متنی می‌توانید بخوانید و از آن رونوشت بگیرید.
                """),
            .bullets([
                "گزارش تنها **نسخه، انتشار macOS، معماری دستگاه، نام سیگنال و پشتهٔ فراخوانی** را دارد.",
                "**نه محتوای سند، و نه مسیر پرونده** — مسیری چون `~/Desktop/حقوق-اسفند.xlsx` پیش از آنکه کسی بگشایدش سه چیز خصوصی را لو داده است.",
                "**هیچ چیز به هیچ‌جا فرستاده نمی‌شود.** نه بارگذاری خودکاری هست و نه کارسازی که آن را بگیرد؛ پرونده در `~/Library/Application Support/GEditor/crash/` می‌ماند تا آنگاه که بگشاییدش یا بزداییدش.",
                "همین که گزارش را گشودید، اجرای بعدی دیگر از آن سخن نمی‌گوید.",
            ]),
            .heading("پس از آن کجا بنگرید"),
            .bullets([
                "نوار وضعیت کدگذاری، پایان‌سطر، زبان و حالت شکستن را نشان می‌دهد — هر بخش کلیک‌پذیر است.",
                "آنگاه که پنجرهٔ تنظیمات بس نیست، `settings.json` را می‌توان دستی ویرایش کرد.",
                "`دربارهٔ GEditor` نسخه و گونهٔ ساخت را می‌دهد، که گزارش خطا به آن‌ها نیاز دارد.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
