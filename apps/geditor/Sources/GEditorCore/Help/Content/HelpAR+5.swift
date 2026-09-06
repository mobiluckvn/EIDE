import Foundation

/// كتاب المساعدة بالعربية — الجزء الخامس: التقارير وحزمة المعرفة والأتمتة والبرنامج نفسه.
extension HelpAR {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "التقارير والمخطّطات",
        summary: "ملف نصي يُنتج تقرير HTML تُعاد فيه الأرقام، إضافةً إلى مخطّطات Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "تقارير `.greport.md`",
        summary: "‏Markdown مع أربعة أنواع من الكتل القابلة للتنفيذ — تكتب على اليسار وتعاين على اليمين.",
        keywords: ["تقرير", "greport", "html", "تصدير", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                ملف `.greport.md` هو **Markdown عادي** مع بضع كتل مسيَّجة قابلة للتنفيذ. وإخراجه يُنتج ملف \
                HTML **مكتفيًا بذاته** — بلا شبكة وبلا ملفات مرافقة — يستطيع أي أحد فتحه.
                """),
            .paragraph("""
                ولأنه نصّ صِرف يمكن **مقارنته وإيداعه ومشاركته** — الفلسفة نفسها التي في وصفات التنظيف \
                ومجموعات قواعد الجودة.
                """),
            .code(
                language: "markdown",
                caption: "sales-2026-08.greport.md — تقرير كامل",
                source: """
                    ---
                    title: تقرير مبيعات أغسطس
                    source: sales-2026-08.csv
                    ---

                    # تقرير مبيعات أغسطس

                    الأرقام حتى 31 أغسطس 2026.

                    ## الإيراد حسب المحافظة

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: الإيراد حسب المحافظة
                    y_label: الإيراد
                    number_format: vi
                    suffix: " ₫"
                    source: المصدر — sales-2026-08.csv
                    ```

                    ## جودة البيانات المصدرية

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("أنواع الكتل"),
            .table(
                headers: ["الكتلة", "تُنتج"],
                rows: [
                    ["`query`", "جدولًا، من عبارة SQL في DuckDB"],
                    ["`chart`", "مخطّطًا"],
                    ["`quality`", "بطاقة تقييم جودة بيانات"],
                    ["`mining`", "جدول ترتيب لمجموعات التنقيب"],
                    ["`mermaid`", "مخطّطًا"],
                ]
            ),
            .heading("المقدّمة الأمامية"),
            .paragraph("""
                كتلة `---` في الأعلى تصرّح بـ`title` و`source` — وهو مصدر البيانات الافتراضي لكل كتلة لا \
                تسمّي مصدرها.
                """),
            .note("""
                تُعاد المعاينة كلما توقّفت عن الكتابة، لكنها **تُحلّل فقط**؛ فهي لا تنفّذ الاستعلامات مع كل \
                ضغطة مفتاح. ويُبلَّغ عن أخطاء المستند وأخطاء البيانات منفصلةً — *\"كتلة chart ينقصها \
                المفتاح `kind`\"* خطأ ملف، و*\"العمود `doanh_thu` غير موجود\"* خطأ بيانات.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "كتلة `query`",
        summary: "عبارة DuckDB واحدة تصير جدولًا واحدًا في التقرير.",
        keywords: ["استعلام", "sql", "جدول", "تقرير", "كتلة"],
        blocks: [
            .paragraph("""
                محتوى الكتلة **عبارة SQL واحدة** تُنفَّذ على مصدر التقرير. واسم الجدول `t`، وباللهجة نفسها \
                المستعملة في لوحة الاستعلام.
                """),
            .code(
                language: "text",
                caption: "كتلة استعلام ذات معامل",
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
                `:thang` **معامل**. يُمرَّر وقت الإخراج — من الصدفة بـ`--param thang=8`، أو من ملف قائمة \
                عند توليد التقارير بالجملة.
                """),
            .note("""
                الجداول في تقرير بيانات **ينبغي أن تأتي من كتلة query** لا أن تُكتب يدويًا. فالجدول \
                المكتوب يدويًا لا يُعاد حسابه حين تتغيّر الأرقام، وعاجلًا أو آجلًا يخالف بقية التقرير.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "كتلة `chart`",
        summary: "إعداد YAML يصير مخطّطًا — وأهمّ قاعدة في الصيغة.",
        keywords: ["مخطط", "yaml", "تقرير", "رسم"],
        blocks: [
            .code(
                language: "yaml",
                caption: "كل مفتاح في كتلة chart",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: الإيراد حسب المحافظة
                    x_label: المحافظة
                    y_label: الإيراد
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: المصدر — sales.csv، حتى 26 أغسطس 2026
                    """
            ),
            .heading("بلا `query` يستعمل نتيجة كتلة query التي فوقه مباشرةً"),
            .paragraph("""
                هذه أهمّ قاعدة في الصيغة. وبفضلها لا يكرّر التقرير الشائع \"جدول ثم مخطّط لذلك الجدول\" \
                عبارة SQL — والتكرار يعني أن النسختين ستتباعدان يومًا ما، وعندها يقول الجدول والمخطّط \
                شيئين مختلفين في الصفحة نفسها.
                """),
            .warning("""
                وفي المقابل **ترتيب الكتل مهمّ**: فإدراج كتلة query بينهما يغيّر بيانات المخطّط الذي تحته.
                """),
            .heading("لماذا `source` مفتاح قائم بذاته"),
            .paragraph("""
                ملاحظة المصدر المكتوبة نثرًا تحت المخطّط تُعرض جيدًا تمامًا — على الشاشة. لكن المخطّط \
                سيُصدَّر PNG ويُلصق في مكان آخر، فيتخلّف النثر وراءه. أما كمفتاح فهو يُرسم **داخل الصورة** \
                ويسافر معها.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "كتلة `quality`",
        summary: "بطاقة تقييم جودة بيانات داخل التقرير.",
        keywords: ["جودة", "بطاقة", "تقرير", "كتلة"],
        blocks: [
            .code(
                language: "yaml",
                caption: "كل مفتاح في كتلة quality",
                source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # الفراغ يعني مصدر التقرير نفسه
                    title: جودة بيانات مبيعات أغسطس
                    rules: true                 # اعرض جدول القواعد الناجحة/الفاشلة
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # ثبّت التاريخ المرجعي لـ"الحداثة"
                    fail_under: 90              # دون هذا تتحوّل البطاقة إلى لون تحذيري
                    """
            ),
            .table(
                headers: ["`chart`", "يرسم"],
                rows: [
                    ["`violations`", "عدد الصفوف للقواعد **الفاشلة** — يجيب عن \"ما الذي يُصلَح أولًا\""],
                    ["`dimensions`", "درجات الأبعاد الستة"],
                    ["`none`", "جدول فقط، بلا مخطّط"],
                ]
            ),
            .note("""
                اضبط `now:` في تقرير دوري. فبدونه تقارن *الحداثة* بلحظة الإخراج، وإعادة إخراج تقرير الشهر \
                الماضي تُنتج درجة مختلفة عن التي نشرتها.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "كتلة `mining`",
        summary: "رتّب المجموعات حسب الشذوذ أو خطأ التنبّؤ أو تباعد الارتباط.",
        keywords: ["تنقيب", "تقرير", "ترتيب المجموعات"],
        blocks: [
            .code(
                language: "yaml",
                caption: "كل مفتاح في كتلة mining",
                source: """
                    group_by: tinh
                    value: doanh_thu          # العمود المستعمل للشذوذ والتنبّؤ
                    pair: chi_phi             # عمود ثانٍ، للارتباط داخل كل مجموعة
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # الفراغ يعني مصدر التقرير نفسه
                    title: التنقيب حسب المحافظة
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "يرتّب حسب"],
                rows: [
                    ["`anomalies`", "المجموعة ذات أكثر الصفوف شذوذًا"],
                    ["`forecast_error`", "المجموعة التي تنبّؤها هو الأسوأ"],
                    ["`correlation_gap`", "المجموعة التي يتباعد ارتباطها أكثر عن الجدول المجمَّع — تلتقط مفارقة سيمبسون"],
                ]
            ),
            .warning("""
                **لا مفتاح يُعطّل كتلة \"الطريقة\".** فترتيب مجموعات بلا طريقته لا يترك للقارئ سبيلًا \
                لمعرفة أي سياج قِيس عليه \"أكثر شذوذًا\". ومن يريد إخفاءها يعرف أصلًا الجواب الذي يريده.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "توليد التقارير بالجملة",
        summary: "قالب واحد، وقائمة معاملات واحدة، وتقارير كثيرة.",
        keywords: ["دفعة", "تقارير كثيرة", "معاملات", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                قالب تقرير واحد، يُنفَّذ لكل فرع أو كل شهر. وقائمة المعاملات ملف CSV أو JSON — **صفٌّ لكل \
                تقرير**.
                """),
            .code(
                language: "text",
                caption: "list.csv — صفّ لكل تقرير",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash",
                caption: "أخرِج الدفعة كلها من الصدفة",
                source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """
            ),
            .code(
                language: "bash",
                caption: "أو تقرير واحد بمعاملات مُمرَّرة يدويًا",
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
        title: "مخطّطات Mermaid",
        summary: "ارسم المخطّطات نصًا، وحرّرها بأوامر، وعاينها متزامنةً في الاتجاهين.",
        keywords: ["mermaid", "مخطط", "مخطط انسيابي", "تسلسل", "رسم"],
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
                يرسم Mermaid المخطّطات **من نصّ**: تكتب وصفًا، وترسمه الآلة. ولذلك يمكن مقارنة المخطّط \
                وإيداعه — وهو ما لا يستطيعه ملف صورة.
                """),
            .paragraph("""
                افتح `مخطّط Mermaid: معاينة` لعرض بجوار المحرّر. والاثنان **متزامنان في الاتجاهين**: حدّد \
                عنصرًا في الصورة فيقفز المؤشر إلى سطره.
                """),
            .heading("حرّر بالأوامر لا بإعادة الكتابة"),
            .table(
                headers: ["الأمر", "ما يفعله"],
                rows: [
                    ["إدراج قالب…", "يُدرج هيكلًا جاهزًا لكل نوع مخطّط"],
                    ["إضافة عنصر…", "يضيف عقدة أو مشاركًا"],
                    ["وصل العنصرين المحدَّدين", "يرسم سهمًا بينهما"],
                    ["تحرير تسمية العنصر المحدَّد…", "يغيّر النص دون البحث عن السطر"],
                    ["حذف العنصر المحدَّد", "يزيل العقدة **وكل** حافة تمسّها"],
                    ["نقل الرسالة لأعلى / لأسفل", "يعيد ترتيب الخطوات في مخطّط تسلسل"],
                    ["إعادة التنسيق", "يزيح ويحاذي الكتلة كلها"],
                ]
            ),
            .heading("الفصل إلى ملف والإعادة إلى الداخل"),
            .paragraph("""
                مكان المخطّطات الكبيرة ملفّ `.mmd` خاص بها: فـ`فصل الكتلة إلى ملف .mmd…` ينقلها خارجًا \
                ويترك مرجعًا. و`إعادة تضمين الملف المرجَعي` يفعل العكس حين تحتاج إلى إرسال ملف واحد.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "صيغة Mermaid الشائعة",
        summary: "أكثر أربعة أنواع مخطّطات استعمالًا، ولكلٍّ قالب يعمل.",
        keywords: ["mermaid", "صيغة", "مخطط انسيابي", "تسلسل", "غانت", "صنف", "قالب"],
        blocks: [
            .code(
                language: "mermaid",
                caption: "مخطّط انسيابي — عملية اعتماد طلب",
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
                caption: "مخطّط تسلسل — مسار دفع",
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
                caption: "مخطّط أصناف — نموذج بيانات",
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
                caption: "غانت — خطة إصدار",
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
                headers: ["شكل العقدة", "اكتب"],
                rows: [
                    ["مستطيل", "`A[التسمية]`"],
                    ["مستدير الزوايا", "`A(التسمية)`"],
                    ["ملعب", "`A([التسمية])`"],
                    ["معيّن (قرار)", "`A{التسمية}`"],
                    ["أسطوانة (بيانات)", "`A[(التسمية)]`"],
                ]
            ),
            .table(
                headers: ["السهم", "اكتب"],
                rows: [
                    ["متّصل برأس", "`A --> B`"],
                    ["منقّط", "`A -.-> B`"],
                    ["غليظ", "`A ==> B`"],
                    ["بتسمية", "`A -- تسمية --> B`"],
                ]
            ),
            .note("""
                اتجاه المخطّط الانسيابي يأتي بعد `flowchart` مباشرةً: `TD` من أعلى لأسفل، و`LR` من اليسار \
                إلى اليمين، إضافةً إلى `BT` و`RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - حزمة المعرفة

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "حزمة المعرفة",
        summary: "التقطيع، وفهارس البحث، ورسوم المعرفة، والكيانات، وتقييم الاسترجاع.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "ما هي حزمة المعرفة",
        summary: "أدوات لتحضير البيانات وفحصها لنظام يجيب عن أسئلة من مستندات.",
        keywords: ["rag", "معرفة", "قطعة", "تضمين", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                حين تبني نظامًا يجيب عن أسئلة من مجموعة مستندات، فمعظم العمل ليس في النموذج بل في \
                **تحضير البيانات**: تقطيع المستندات إلى مقاطع معقولة، وفحص جودة تلك المقاطع، وبناء فهرس، \
                و**قياس ما إذا كان الاسترجاع يجد الشيء الصحيح فعلًا**.
                """),
            .paragraph("""
                وهذا الفصل هو طقم الأدوات لذلك بالضبط. وهو يعمل **كليًا على جهازك** ولا يتّصل بشبكة أبدًا.
                """),
            .table(
                headers: ["المهمة", "الأداة"],
                rows: [
                    ["تقطيع المستندات إلى مقاطع", "معاينة التقطيع"],
                    ["فحص المقاطع وتقييمها", "فحص قطع JSONL"],
                    ["التحويل بين أشكال البيانات", "تحويل المعرفة"],
                    ["بناء رسم علاقات وفحصه", "رسم المعرفة"],
                    ["إيجاد أسماء الأعلام في النص", "تعليم الكيانات"],
                    ["قياس جودة الاسترجاع", "مختبر الاسترجاع"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "تقطيع مجموعة JSONL وفحصها",
        summary: "عايِن حدود القطع على النص نفسه، ثم قيّم المجموعة كلها.",
        keywords: ["قطعة", "jsonl", "مجموعة نصوص", "تداخل", "رمز"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("معاينة التقطيع"),
            .paragraph("""
                افتح مستند نصّ أو Markdown، واختر استراتيجية وحجم قطعة. تُبرَز الحدود **على النص نفسه**، \
                فترى أين يقع القطع في منتصف جملة أو عبر جدول قبل تصدير أي شيء.
                """),
            .bullets([
                "**حجم ثابت** مع تداخل.",
                "**حسب البنية** — عند عناوين Markdown، مع إبقاء انسياب المستند سليمًا.",
                "**حسب الفقرة**، بالدمج حتى بلوغ الحجم.",
            ]),
            .heading("فحص مجموعة JSONL موجودة"),
            .paragraph("""
                لمجموعة لديك أصلًا (قطعة JSON في كل سطر)، يجيب `JSONL: افحص القطع…` عن: أي الأسطر ليست \
                JSON صالحة، وأي القطع أقصر أو أطول من اللازم، وأيّها يكرّر بعضها بعضًا، وأيّها قُطع في \
                منتصف جملة.
                """),
            .note("""
                يمكن تقييم مجموعة نصوص بـ**إطار الأبعاد الستة نفسه** المستعمل مع البيانات الجدولية — \
                استعمل المفتاح `corpus:` في كتلة `quality` داخل تقرير.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "تحويل صيغ المعرفة",
        summary: "القطع بين JSONL · CSV · Markdown، والرسوم بين DOT · Mermaid · قوائم الحواف.",
        keywords: ["تحويل", "jsonl", "dot", "mermaid", "قائمة حواف"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["من", "إلى"],
                rows: [
                    ["قطع JSONL", "CSV · Markdown"],
                    ["قطع CSV", "JSONL · Markdown"],
                    ["رسم DOT", "Mermaid · قائمة حواف"],
                    ["قائمة حواف", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                هناك **معاينة بخمسة صفوف** قبل إنشاء اللسان الجديد، وهي الآلية نفسها المستعملة في تحويل \
                CSV.
                """),
            .paragraph("""
                `فتح الثلاثيات/الحواف كجدول` يعرض ملف ثلاثيات أو قائمة حواف كشبكة — رشّحها ورتّبها كأي \
                ملف CSV آخر.
                """),
            .note("""
                اتجاه **Markdown ← JSONL** ليس في هذا الأمر: فذلك الاتجاه *هو* التقطيع، والأمر يوجّهك \
                إليه. وتنفيذان لقطع واحد كانا سيُنتجان نتيجتين مختلفتين.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "رسوم المعرفة",
        summary: "افحص الصياغة، وقيّم السلامة، وشغّل خوارزميات على رسوم بمليون حافة.",
        keywords: ["رسم", "dot", "cypher", "pagerank", "louvain", "فحص الصياغة"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                يقرأ GEditor الرسوم بصيغ **DOT** و**قوائم الحواف** و**الثلاثيات**. و`فحص صياغة الرسم` \
                يلتقط أخطاء الصياغة والعقد المعلَّقة والحواف التي تشير إلى عقد غير موجودة.
                """),
            .heading("الخوارزميات المتاحة"),
            .table(
                headers: ["الخوارزمية", "تجيب عن"],
                rows: [
                    ["الجوار بمسافة k", "ما المرتبط بهذه العقدة خلال k خطوات"],
                    ["المكوّنات المتّصلة", "كم قطعة منفصلة في الرسم"],
                    ["PageRank", "أي العقد مهمّ"],
                    ["Louvain", "كيف ينقسم الرسم إلى مجتمعات"],
                ]
            ),
            .paragraph("""
                على رسم بـ**مليون حافة** تعمل الأربع كلها في ما بين بضعة أجزاء من الألف من الثانية ونحو \
                ثانية.
                """),
            .note("""
                يمكن تقييم الرسم أيضًا بـ**إطار الأبعاد الستة** المستعمل مع الجداول ومجموعات النصوص — \
                استعمل المفتاح `graph:` في كتلة `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "تعليم الكيانات من قائمة",
        summary: "حمّل قائمة أسماء أعلام واعثر على كل ورود — وفق ثلاث قواعد وُضعت للفيتنامية.",
        keywords: ["كيان", "اسم علم", "ner", "تعليم", "معجم", "مطابقة"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                حمّل قائمة أسماء (شركات، منتجات، أماكن) فيُبرز GEditor كل ورود في المستند، مع جدول \
                أعداد.
                """),
            .heading("ثلاث قواعد مطابقة، كلها من بيانات فيتنامية"),
            .bullets([
                "**أطول مطابقة تفوز.** فمع وجود `An Phát` و`Công ty An Phát` معًا في القائمة، يجب أن تطابق الجملةُ التي تحوي العبارة الأطول العبارةَ الأطول — وإلا انشطرت إلى اثنتين وحُسبت كيانين، وهو ما **ينفخ** الإحصاءات.",
                "**حدود الكلمات إلزامية.** فـ `An` يجب ألّا يطابق داخل `Anh` أو `Hoàn`. فأسماء الأعلام الفيتنامية قصيرة وتشترك في مقاطع مع كلمات عادية لا تُحصى.",
                "**بلا حساسية لحالة الأحرف، لكن بحساسية للتشكيل.** فـ `CÔNG TY` و`Công ty` واحد؛ أما `má` و`ma` فلا.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "حلّ صيغ الكيانات",
        summary: "تعرَّف على `Cty An Phát` و`Công ty An Phát` ككيان واحد — مع ترك القرار لك.",
        keywords: ["حل الكيانات", "صيغ", "توحيد الأسماء", "تكرارات"],
        blocks: [
            .paragraph("""
                العنقدة نفسها المستعملة في **التكرارات الضبابية** في شبكة CSV — تنفيذ واحد مشترك، لا \
                اثنان.
                """),
            .paragraph("""
                والخرج **اقتراح**: تراجع كل عنقود وتختار الصيغة المعيارية. ولا زرّ لدمج الكل، لأن اسمين \
                متشابهين بنسبة 92% قد يكونان مؤسّستين حقيقيتين مختلفتين.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "مختبر الاسترجاع",
        summary: "قِس ما إذا كان الفهرس يجد الشيء الصحيح، بمجموعة أسئلة مع إجاباتها.",
        keywords: ["استرجاع", "bm25", "استدعاء", "mrr", "ndcg", "تقييم", "مجموعة ذهبية"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                حمّل **مجموعة تقييم** — في كل سطر سؤال مع معرّفات القطع التي ينبغي أن تعود — ثم شغّل \
                الدفعة كلها على الفهرس.
                """),
            .table(
                headers: ["المقياس", "يجيب عن"],
                rows: [
                    ["recall@k", "كم من مجموعة الإجابة يظهر في أول k"],
                    ["MRR", "كم ينخفض موضع أول نتيجة صحيحة"],
                    ["nDCG@k", "هل الترتيب جيّد، مع مراعاة الموضع"],
                ]
            ),
            .paragraph("""
                وتأتي النتائج **لكل سؤال** أيضًا، والأسوأ أولًا — وتلك قائمتك بما يُصلَح في المجموعة، \
                مرتَّبةً بما يستحقّ الإصلاح أكثر.
                """),
            .warning("""
                المقاييس الثلاثة كلها **متوسّطات**، والمتوسّط يخفي الكثير. اقرأ دائمًا جدول كل سؤال قبل أن \
                تستنتج أن \"الفهرس جيّد بما يكفي\".
                """),
            .paragraph("""
                ويمكن مقارنة إعدادين جنبًا إلى جنب، وتسقط النتيجة مباشرةً في تقرير `.greport.md` فيكون \
                التشغيل التالي مطابقًا.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - المايكرو والأتمتة

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "المايكرو والأتمتة",
        summary: "سجّل الإجراءات، وشغّلها بالجملة، واكتب نصوصًا برمجية، وقُد البرنامج من الصدفة.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "تسجيل المايكرو وتشغيله",
        summary: "سجّل تسلسلًا وكرّره — والتشغيل كله خطوة تراجع واحدة.",
        keywords: ["مايكرو", "تسجيل", "تشغيل", "تكرار", "أتمتة"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "بدء / إيقاف التسجيل"),
                HelpShortcut("⌃P", "تشغيل"),
            ]),
            .steps([
                "`⌃R` يبدأ التسجيل.",
                "افعل ما تريد تكراره — اكتب، وحرّك المؤشر، وابحث، واستبدل.",
                "`⌃R` مرة أخرى للإيقاف.",
                "`⌃P` يشغّله، أو `مايكرو ▸ التشغيل حتى نهاية المستند` ينفّذه حتى النهاية.",
                "`مايكرو ▸ حفظ المايكرو…` يسمّيه للجلسات اللاحقة.",
            ]),
            .heading("يسجّل الأوامر، لا ضغطات المفاتيح الخام"),
            .paragraph("""
                يخزّن المايكرو **ما فعلتَه**، لا أي المفاتيح ضغطتَ. وهذا يجعله مستقلًا عن تخطيط لوحة \
                المفاتيح وعن طريقة الإدخال المفعَّلة، ويجعل ملف المايكرو **مقروءًا** حين تفتحه.
                """),
            .heading("متى يتوقّف المايكرو"),
            .table(
                headers: ["السبب", "المعنى"],
                rows: [
                    ["نفد عدد التكرارات", "طبيعي"],
                    ["خطوة `find` لم تجد شيئًا", "هكذا يوقف \"التشغيل حتى نهاية الملف\" نفسه"],
                    ["بلوغ نهاية المستند", "لا مكان أبعد"],
                    ["ألغيتَ أنت", "`مايكرو ▸ إلغاء المايكرو الجاري`"],
                    ["تكرار لم يغيّر شيئًا ولم يتحرّك", "أُوقف كي لا يدور إلى الأبد"],
                ]
            ),
            .note("""
                التشغيل كله — ولو عشرة آلاف تكرار — خطوة تراجع **واحدة**.
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "تشغيل مايكرو بالجملة",
        summary: "على كل لسان مفتوح، أو على مجلد من ملفات غير مفتوحة.",
        keywords: ["دفعة", "كل الألسنة", "مجلد", "مايكرو", "قناع"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["الأمر", "النطاق", "قابل للتراجع"],
                rows: [
                    ["التشغيل على كل الألسنة", "الألسنة المفتوحة", "نعم — خطوة تراجع لكل لسان"],
                    ["التشغيل عبر مجلد…", "ملفات **غير مفتوحة** على القرص", "لا"],
                ]
            ),
            .warning("""
                التشغيل عبر مجلد يمسّ ملفات غير مفتوحة في أي لسان، فـ**لا تراجع**. وافتراضيًا **يكتب \
                GEditor ملفات جديدة** بدل الكتابة فوق الأصول. التزم بذلك الافتراضي ما لم يكن لديك نسخة \
                احتياطية أو مستودع خاضع لإدارة الإصدارات.
                """),
            .heading("ترشيح الملفات بقناع"),
            .paragraph("""
                في مُنتقي المجلد **مرشّح لاسم الملف**: اكتب `*.csv;*.log` فلا يمسّ المايكرو سواها. وهي صيغة \
                القناع نفسها التي يستعملها `البحث عبر مجلد`، وتُفصل عدة أنماط بـ`;` أو `,`.
                """),
            .bullets([
                "اتركه **فارغًا** فيأخذ كل ملف نصّي يستطيع GEditor قراءته — وهو السلوك السابق.",
                "القناع **يحلّ محلّ** قائمة الامتدادات تلك لا يضيّقها أكثر: اكتب `*.bak` فيعمل على ملفات `.bak`، ولو لم يكن ذلك الامتداد في قائمة النصوص.",
                "وإن لم يطابق شيء، **تعيد الرسالة عليك قناعك** بدل لوم مجلد فارغ.",
            ]),
            .paragraph("""
                ولهذا المربّع سبب عملي جدًا: في مجلد 400 ملف `.json` و12 ملف `.log`، ومايكروك لا يرتّب سوى \
                السجلات. وبلا قناع تُعالَج الأربعمئة الأخرى أيضًا — ولأن الدفعة تكتب ملفات جديدة، فإن \
                خطأً واحدًا يترك 400 قطعة نفاية.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "صيغة ملف المايكرو",
        summary: "سبعة أنواع خطوات، وصيغة JSON كاملة، ومايكروان يعملان.",
        keywords: ["مايكرو", "json", "صيغة", "تحرير يدوي", "مشاركة"],
        blocks: [
            .paragraph("""
                كل مايكرو **ملف JSON خاص به** في مجلد `macros/` التابع لـ GEditor. فيبقى الفساد محصورًا في \
                مايكرو واحد، ومشاركة واحد مع زميل تعني إرسال ملف واحد.
                """),
            .code(
                language: "text",
                caption: "أين تعيش الملفات",
                source: """
                    ~/Library/Application Support/GEditor/macros/<اسم-المايكرو>.json
                    """
            ),
            .heading("أنواع الخطوات السبعة"),
            .table(
                headers: ["الخطوة", "تُكتب", "المعنى"],
                rows: [
                    ["إدراج نص", "`{\"insert\": {\"_0\": \"نص\"}}`", "يكتب عند المؤشر؛ ومع تحديد يستبدله"],
                    ["حذف للخلف", "`{\"deleteBackward\": {}}`", "مثل مفتاح Delete"],
                    ["حذف للأمام", "`{\"deleteForward\": {}}`", "مثل ⌦"],
                    ["تحرّك", "`{\"move\": {\"_0\": \"nextLine\"}}`", "انظر قائمة الاتجاهات أدناه"],
                    ["تحديد السطر", "`{\"selectLine\": {}}`", "من دون نهاية السطر"],
                    ["بحث", "`{\"find\": { … }}`", "يجد المطابقة التالية و**يحدّدها**"],
                    ["استبدال التحديد", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` تعمل حين تكون الخطوة السابقة `find` بـ regex"],
                ]
            ),
            .heading("اتجاهات الحركة"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("خطوة `find` كاملة"),
            .code(
                language: "json",
                caption: "المفاتيح الأربعة لخطوة find",
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
            .paragraph("`mode` يأخذ `normal` أو `extended` أو `regex` — الأوضاع الثلاثة نفسها في مربّع البحث."),
            .heading("مثال 1 — جعل رمز المحافظة في أول كل سطر بحروف كبيرة"),
            .code(
                language: "json",
                caption: "macros/uppercase-province.json",
                source: """
                    {
                      "name": "رمز المحافظة بحروف كبيرة",
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
                شغّله بـ`مايكرو ▸ التشغيل حتى نهاية المستند`: فعدم عثور خطوة `find` على شيء بعد ذلك هو \
                شرط التوقّف بالضبط.
                """),
            .heading("مثال 2 — حذف السطر التالي لكل سطر يحوي TODO"),
            .code(
                language: "json",
                caption: "macros/delete-line-after-todo.json",
                source: """
                    {
                      "name": "حذف السطر بعد TODO",
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
                جرّب مايكرو حُرّر يدويًا على نسخة أولًا. فخطوة `find` مكتوبة خطأً تجعل المايكرو يتوقّف \
                فورًا — وتلك هي الحالة الحميدة. أما الخبيثة فنمطٌ يطابق أوسع مما ظننت، فيحرّر آلاف \
                المواضع داخل خطوة تراجع واحدة.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "نصوص JavaScript",
        summary: "أربع دوال، وملف `.js` واحد، وكل ما يفعله خطوة تراجع واحدة.",
        keywords: ["نص برمجي", "javascript", "js", "أتمتة", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                ضع ملف `.js` في مجلد `scripts/` التابع لـ GEditor وشغّله من `مايكرو ▸ نصّ برمجي…`. ويرى \
                النصّ **أربعة** أشياء بالضبط:
                """),
            .table(
                headers: ["الاستدعاء", "المعنى"],
                rows: [
                    ["`doc.text`", "نصّ المستند كله"],
                    ["`doc.selection`", "التحديد (سلسلة فارغة حين لا شيء محدَّد)"],
                    ["`doc.replace(s)`", "استبدال **المستند كله** بـ `s` — خطوة تراجع واحدة"],
                    ["`doc.log(s)`", "كتابة سطر في لوحة النتائج"],
                ]
            ),
            .code(
                language: "javascript",
                caption: "scripts/number-lines.js",
                source: """
                    // ترقيم كل سطر.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("عدد الأسطر المرقّمة: " + (lines.length - 1));
                    doc.replace(out.join("\\n"));
                    """
            ),
            .code(
                language: "javascript",
                caption: "scripts/keep-three-columns.js — الإبقاء على أول ثلاثة أعمدة CSV",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("أسطر اختُصرت إلى 3 أعمدة: " + out.length);
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("ثلاثة حدود ينبغي معرفتها"),
            .bullets([
                "**لا وصول إلى الملفات، ولا شبكة، ولا إطلاق عمليات.** سطح الواجهة ضيّق عن قصد: فتوسيعه لاحقًا سهل، أما تضييقه فيكسر كل نصّ كتبه المستخدمون.",
                "**هذا ليس حدًّا أمنيًا.** فالنصوص تعمل في العملية نفسها. لا تشغّل نصًا لم تقرأه.",
                "**هناك حدّ خمس ثوانٍ.** وبعده تحصل على رسالة ويبقى البرنامج قابلًا للاستعمال — لكن خيط ذلك النصّ **يظلّ يدور حتى تخرج**، فيلتهم نواة. والرسالة تقول ذلك.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "الترشيح عبر أمر خارجي",
        summary: "مرّر التحديد عبر أمر يونكس وخذ النتيجة.",
        keywords: ["مرشّح", "أمر خارجي", "صدفة", "أنبوب", "sort", "jq", "يونكس"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                يُغذّى التحديد (أو المستند كله) إلى `stdin` لأمر، ويحلّ `stdout` ذلك الأمر محلّه.
                """),
            .code(
                language: "bash",
                caption: "بضعة أوامر شائعة",
                source: """
                    sort -u                     # رتّب وأسقط التكرارات
                    jq .                        # أعد تنسيق JSON
                    tr 'a-z' 'A-Z'              # حوّل إلى حروف كبيرة
                    grep -v '^#'                # أسقط أسطر التعليقات
                    awk -F, '{print $3","$1}'   # بدّل ترتيب الأعمدة
                    """
            ),
            .note("""
                النتيجة خطوة تراجع **واحدة**. وإن أرجع الأمر رمز خطأ، ترك GEditor النصّ كما هو وعرض \
                `stderr`.
                """),
            .warning("""
                هذا الأمر موجود **في نسخة التنزيل المباشر وحدها**. فـ App Sandbox يمنع تشغيل شيفرة خارج \
                البرنامج، فيبقى عنصر القائمة في نسخة App Store ويشرح سبب عدم توفّره.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "أداة سطر الأوامر `geditor`",
        summary: "افتح ونظّف واستعلم وقيّم وأخرِج التقارير — دون فتح البرنامج.",
        keywords: ["cli", "سطر الأوامر", "طرفية", "geditor", "نص برمجي", "ci"],
        blocks: [
            .warning("""
                متاحة في **نسخة التنزيل المباشر** وحدها. فنسخة App Store تعمل داخل صندوق رملي، فلا \
                تستطيع عملية سطر أوامر خارجية الاتصال بها.
                """),
            .heading("فتح الملفات"),
            .code(
                language: "bash",
                caption: "افتح، واقفز إلى موضع، واقرأ من أنبوب",
                source: """
                    geditor report.csv
                    geditor report.csv:120:5       # السطر 120، العمود 5
                    geditor -w notes.md            # انتظر إغلاق الملف قبل الخروج
                    geditor -r app.log             # افتح للقراءة فقط
                    git diff | geditor             # اقرأ stdin في لسان جديد
                    """
            ),
            .table(
                headers: ["الخيار", "المعنى"],
                rows: [
                    ["`-w`, `--wait`", "انتظر إغلاق الملف قبل الخروج — لاستعماله محرّرًا لـ`git`"],
                    ["`-n`, `--new-window`", "افتح في نافذة جديدة"],
                    ["`-r`, `--read-only`", "افتح للقراءة فقط"],
                    ["`-i`, `--info`", "اطبع الترميز ونهايات الأسطر وعدد الأسطر ثم اخرج — **دون** فتح البرنامج"],
                    ["`-h`, `--help`", "اعرض المساعدة"],
                    ["`-v`, `--version`", "اعرض الإصدار"],
                ]
            ),
            .heading("التشغيل دون فتح البرنامج"),
            .paragraph("""
                مجموعات الأوامر الأربع أدناه تعمل **كليًا داخل عملية سطر الأوامر**، فتعمل في CI حيث لا \
                أحد داخل جلسة رسومية.
                """),
            .code(
                language: "bash",
                caption: "التنظيف بوصفة",
                source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "الاستعلام",
                source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "بوابة الجودة — رمز الخروج 0 نجاح · 1 فشل · 2 خطأ",
                source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "إخراج التقارير",
                source: """
                    geditor --report template.greport.md --param-list list.csv --out ./reports/
                    """
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript وقائمة الخدمات",
        summary: "اقرأ المستند واكتبه من AppleScript، أو أرسل نصًا إلى GEditor من برنامج آخر.",
        keywords: ["applescript", "osascript", "خدمات", "أتمتة", "shortcuts"],
        blocks: [
            .code(
                language: "applescript",
                caption: "اقرأ المستند المفتوح",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "اكتب فوق المحتوى، واقرأ التحديد",
                source: """
                    tell application "GEditor"
                        set selected text to "نصّ يحلّ محلّ التحديد"
                        set contents to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "افتح ملفًا",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """
            ),
            .heading("قائمة الخدمات"),
            .paragraph("""
                حدّد نصًا في أي برنامج، ثم استعمل قائمة `الخدمات` لإرساله إلى GEditor في لسان جديد.
                """),
            .note("""
                عند أول تشغيل لـ AppleScript يطلب macOS إذن الأتمتة. وتلك نافذة النظام لا نافذة GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "حزم التوسعة والإضافات",
        summary: "نوعان من التوسعة، وفي أي نسخة يعمل كلٌّ منهما.",
        keywords: ["إضافة", "توسعة", "حزمة", "أصلية"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("حزم التوسعة"),
            .paragraph("""
                الحزمة **ملف JSON واحد** يجمع سمةً ونصوصًا برمجية ولغات معرَّفة من المستخدم معًا. \
                والتثبيت ينسخ ملفًا، والإزالة تحذف ملفًا — وقائمة الحزم مشتقّة من **القرص**، لا من سجلّ \
                قد يكذب.
                """),
            .paragraph("تعمل في **النسختين**."),
            .heading("الإضافات الأصلية"),
            .paragraph("""
                تعمل الإضافات المترجَمة مسبقًا في **عملية منفصلة** بسطح واجهة ضيّق — فالإضافة التي تنهار \
                لا تأخذ البرنامج معها.
                """),
            .warning("""
                الإضافات الأصلية موجودة **في نسخة التنزيل المباشر وحدها**، لأن App Sandbox يمنع تحميل \
                شيفرة من خارج البرنامج. ويجب **اعتماد كل إضافة يدويًا مرة واحدة** بحسب بصمتها قبل أن \
                تعمل.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - الإعدادات والبرنامج

    static let application = HelpChapter(
        id: "ung-dung",
        title: "الإعدادات والبرنامج",
        summary: "الإعدادات والاختصارات والسمات والتحديثات والانتقال من Notepad++ وحلّ المشكلات.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "الإعدادات",
        summary: "كل خيار يعيش في ملف JSON واحد مقروء للإنسان يمكنك نسخه إلى Mac آخر.",
        keywords: ["إعدادات", "تفضيلات", "خيارات", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "فتح الإعدادات")]),
            .paragraph("""
                لا يوجد \"موافق\" ولا \"إلغاء\" — فالتغيير يسري ويُكتب فورًا، على طريقة macOS.
                """),
            .heading("ملف الإعدادات"),
            .code(
                language: "text",
                caption: "أين يعيش",
                source: """
                    ~/Library/Application Support/GEditor/settings.json
                    """
            ),
            .paragraph("""
                إنه **ملف JSON مُزاح تستطيع قراءته وتحريره يدويًا**. انسخه إلى Mac آخر فتذهب إعداداتك كلها \
                معه. وزرّ `فتح ملف الإعدادات` في الإعدادات يأخذك إليه مباشرةً.
                """),
            .heading("المفاتيح"),
            .table(
                headers: ["المفتاح", "الافتراضي", "المعنى"],
                rows: [
                    ["`fontSize`", "`13`", "حجم خط المحرّر"],
                    ["`tabWidth`", "`4`", "كم عمودًا يعرض TAB"],
                    ["`usesTabsForIndent`", "`false`", "الإزاحة بـ TAB بدل المسافات"],
                    ["`languageIndent`", "`{}`", "إزاحة لكل لغة — انظر صفحة المسافات"],
                    ["`smartIndent`", "`true`", "إزاحة تلقائية في السطر الجديد"],
                    ["`highlightAllMatches`", "`true`", "إبراز كل إصابة بحث"],
                    ["`ligatures`", "`false`", "الرُّبَط — انظر الملاحظة تحت الجدول"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "قصّ المسافات في نهايات الأسطر عند الحفظ"],
                    ["`normalizeToNFCOnSave`", "`false`", "توحيد يونيكود إلى NFC عند الحفظ"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "ترميز الملفات الجديدة"],
                    ["`defaultEOL`", "`\"lf\"`", "نهايات أسطر الملفات الجديدة"],
                    ["`language`", "`\"system\"`", "لغة الواجهة"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "السمة الافتراضية", "أي سمة لونية مستعملة"],
                    ["`showWelcomeOnLaunch`", "`true`", "فتح نافذة الترحيب عند الإقلاع"],
                    ["`keyBindings`", "`{}`", "المفاتيح التي غيّرتها عن الافتراضي وحدها"],
                ]
            ),
            .note("""
                **لماذا الرُّبَط معطَّلة افتراضيًا.** فالرابطة تدمج `!=` أو `->` في محرف **واحد**، فلا تعود \
                الحروف التي تراها على الشاشة مطابقةً للحروف في الملف — بينما يقيس محرّر الأعمدة ووضع \
                الأعمدة واللفّ عند عمود كلُّها بالأعمدة. فعّلها حين تكتب نثرًا، أو حين تختار خطّ برمجة \
                (Fira Code، JetBrains Mono) من أجل رُبَطه بالتحديد.
                """),
            .heading("المجلدات المجاورة"),
            .table(
                headers: ["المجلد", "يحوي"],
                rows: [
                    ["`macros/`", "المايكروهات المحفوظة، ملف JSON لكل واحد"],
                    ["`scripts/`", "نصوص JavaScript"],
                    ["`themes/`", "السمات اللونية"],
                    ["`grammars/`", "اللغات المعرَّفة من المستخدم"],
                ]
            ),
            .warning("""
                ملف الإعدادات المكتوب بنسخة **أحدث** من GEditor **لا تكتب فوقه** نسخة أقدم — بل تعمل على \
                الافتراضيات وتقول ذلك. فالكتابة فوقه أضمن طريقة لتدمير إعدادات من يزامن جهازين، ولما عرف \
                السبب أبدًا.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "شريط الحالة",
        summary: "عشرة أقسام في الأسفل — كلٌّ منها مقروء، وكلٌّ منها قابل للنقر.",
        keywords: ["شريط الحالة", "الشريط السفلي", "إزاحة", "موضع",
                   "ترميز", "جدولة", "للقراءة فقط", "حجم الملف"],
        blocks: [
            .paragraph("""
                هذا أكبر فرق عن أشرطة حالة المحرّرات الأخرى: **لا قسم فيه للعرض فقط**. فإن رأيت قيمة \
                خاطئة كان النقر عليها هو طريقك لإصلاحها، بدل التنقيب في القوائم.
                """),
            .table(
                headers: ["القسم", "يخبرك", "والنقر عليه"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "موضع المؤشر — العمود بالحروف، و`@340` موضع البايت",
                     "يفتح مربّع `الذهاب إلى`"],
                    ["`11 byte · 3 dòng`", "حجم المستند",
                     "يعدّ البايتات · الحروف · الكلمات · الأسطر"],
                    ["`🔒 Chỉ đọc`", "يظهر فقط حين يكون المستند مقفلًا",
                     "يذكر سبب القفل، ويفتحه حين يكون ذلك ممكنًا"],
                    ["`View` / `Code`", "في أي عرض أنت", "يبدّل (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "وضع CSV والفاصل المستعمل",
                     "يبدّل وضع CSV، أو **يعيد اختيار الفاصل**"],
                    ["`Đang theo dõi`", "‏`tail -f` يعمل", "—"],
                    ["`UTF-8`", "الترميز", "أعد التفسير، أو حوّل إلى ترميز آخر"],
                    ["`LF`", "نمط نهاية السطر", "بدّل بين LF · CRLF · CR"],
                    ["`Python`", "لغة تلوين الصياغة", "اختر أخرى، أو عُد إلى التحديد بالامتداد"],
                    ["`Tab: 4`", "عرض الإزاحة", "‏2 · 4 · 8، عامًّا أو **لهذه اللغة وحدها**"],
                    ["`Ngắt: tắt`", "وضع اللفّ الليّن", "يدور بين الأوضاع الثلاثة"],
                ]
            ),
            .heading("ثلاثة أقسام تستحق نظرة ثانية"),
            .bullets([
                "**`@340` — موضع البايت.** وهذا هو الرقم الذي تتكلّمه كل أداة أخرى في المنتج: أخطاء JSON و XML، وخرج `--doc-sweep`، والعارض الثنائي، ومربّع `الذهاب إلى @340`. اقرأه هنا واكتبه هناك.",
                "**وجود `~` على العمود** يعني أن الرقم يعدّ البايتات لا الأعمدة المرئية — ولا يحدث ذلك إلا في الأسطر الأطول من 200 كيلوبايت، حيث كان عدّ الحروف سيُبطئ كل حركة للمؤشر.",
                "**`CSV · …` قابل للنقر لإعادة اختيار الفاصل.** فالاكتشاف قد يخطئ، وحين يخطئ تنحرف كل عملية على الأعمدة دون ما ينبّه. وهذه طريقتك في قول العكس — فهو **يعيد قراءة** الملف فقط ولا يغيّر بايتًا واحدًا (خلافًا لـ`CSV ▸ تغيير الفاصل…` الذي يعيد كتابته).",
            ]),
            .note("""
                القسم الذي لا ينطبق على الملف المفتوح **يُخفى** لا يُخفَّت: فـ`للقراءة فقط` لا يظهر إلا حين \
                يكون المستند مقفلًا حقًا، و`CSV · …` لا يظهر إلا في وضع CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "تغيير اختصارات لوحة المفاتيح",
        summary: "غيّر مفاتيح مفردة، أو تبنَّ خريطة Notepad++ كاملةً.",
        keywords: ["اختصار", "ربط مفاتيح", "خريطة مفاتيح", "طقم جاهز"],
        blocks: [
            .paragraph("""
                في `الإعدادات…` قسم للاختصارات فيه زرّان سريعان: **استعمل طقم Notepad++** و**العودة إلى \
                الافتراضيات**.
                """),
            .paragraph("""
                يسجّل ملف الإعدادات ما **غيّرته عن الافتراضيات** فقط. وبذلك حين يغيّر GEditor مفتاحًا \
                افتراضيًا في نسخة جديدة، لا تعلق بالخريطة القديمة دون أن يخبرك أحد.
                """),
            .note("""
                لا يجوز لأمرين أن يتشاركا اختصارًا. وحين يحدث ذلك يطلق AppKit بصمت **أول** عنصر قائمة \
                فقط، فيبدو الأمر الآخر معطّلًا — ولذلك في GEditor فحصٌ يمنع ذلك.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "السمات، الفاتحة والداكنة",
        summary: "اتّبع النظام، أو فاتح أو داكن؛ والسمة ملف JSON تستطيع تحريره.",
        keywords: ["سمة", "ألوان", "الوضع الداكن", "فاتح", "مظهر"],
        blocks: [
            .paragraph("""
                تختار `الإعدادات…` بين `اتّباع النظام` و`فاتح` و`داكن`، وتحدّد سمة لونية.
                """),
            .paragraph("""
                السمة ملف JSON في `themes/`. وزرّ `تصدير السمة الحالية` يكتب واحدًا لتبدأ منه سمتك الخاصة.
                """),
            .note("""
                اللون المكتوب خطأً في ملف سمة يرتدّ إلى لون **السمة الافتراضية** لا إلى الأسود. فالأسود \
                يبدو قرارًا تصميميًا، وكان المستخدم سيبحث عن المشكلة في مكان آخر.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "التحديثات والإصدارات والخروج",
        summary: "كيف يختلف التحديث بين النسختين.",
        keywords: ["تحديث", "إصدار", "حول", "خروج"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["النسخة", "تتحدّث عبر"],
                rows: [
                    ["App Store", "‏App Store، كأي برنامج آخر"],
                    ["التنزيل المباشر", "`التحقّق من التحديثات…` داخل البرنامج"],
                ]
            ),
            .paragraph("""
                `حول GEditor` يعرض الإصدار العامل وأي نسخة هي — وهذا مفيد عند الإبلاغ عن مشكلة.
                """),
            .note("""
                في نسخة App Store يبقى `التحقّق من التحديثات…` **في القائمة** ويشرح لماذا لا ينطبق، بدل \
                أن يختفي. فعنصر القائمة الغائب سؤال دعم.
                """),
            .paragraph("""
                الخروج لا يُفقد شيئًا: فالجلسة تعود في المرة القادمة التي تفتح فيها البرنامج.
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "استعمال نافذة المساعدة هذه",
        summary: "ابحث في الكتاب، وبدّل لغته، وأعِد نافذة الترحيب.",
        keywords: ["مساعدة", "دليل", "بحث", "ترحيب", "لغة"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "فتح نافذة المساعدة")]),
            .bullets([
                "مربّع البحث أعلى اليسار ينظر داخل **متن النص وأمثلة الشيفرة** — فكتابة مفتاح إعداد مجرّد مثل `fail_under` تصل إلى الصفحة الصحيحة.",
                "الكتابة **بلا علامات تشكيل** تجد النص المشكول.",
                "زرّ `رجوع` يعود إلى الصفحة السابقة.",
                "زرّ `نسخ` في كل كتلة شيفرة ينسخ تلك الكتلة.",
            ]),
            .heading("القراءة بلغة أخرى"),
            .paragraph("""
                القائمة المنبثقة أعلى يمين هذه النافذة تختار **لغة الكتاب**، مستقلةً عن لغة واجهة \
                البرنامج. والتبديل يُبقيك **على الصفحة التي تقرؤها** — فمعرّفات الصفحات لا تُترجم عمدًا، \
                لكي يعمل هذا بالضبط.
                """),
            .note("""
                لا تُسرد إلا اللغات التي لها كتاب فعلًا. فمدخلة قائمة تبدّل إلى شيء وتترك النص كما هو \
                ستكون مدخلة قائمة تكذب.
                """),
            .heading("إعادة نافذة الترحيب"),
            .paragraph("""
                إن أشّرت على **لا تفتح هذه النافذة عند الإقلاع**، فأعد فتحها بـ`مساعدة ▸ جولة الميزات` — \
                فيظهر مربّع التأشير أسفل النافذة من جديد ويمكن إلغاؤه.
                """),
            .paragraph("""
                أو أعِد `showWelcomeOnLaunch` إلى `true` في `settings.json`.
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "من Notepad++ إلى GEditor",
        summary: "أي المفاتيح تتبادل مواقعها، وما الذي يعمل بشكل مختلف، وما المفقود.",
        keywords: ["notepad++", "notepad", "انتقال", "ويندوز", "اختصارات"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                بضعة مفاتيح **تتبادل مواقعها** في macOS بدل أن يتحوّل `Ctrl` إلى `⌘` وحسب. وهذه المقارنة.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "لماذا"],
                rows: [
                    ["`Ctrl+D` تكرار السطر", "**⇧⌘D**", "`⌘D` هنا للمؤشرات المتعددة، كما في كل محرّر Mac"],
                    ["`Ctrl+L` حذف السطر", "**⌘K**", "`⌘L` في macOS تعني \"الذهاب إلى سطر\""],
                    ["`Ctrl+G` الذهاب إلى سطر", "**⌘L**", "هذان يتبادلان مواقعهما"],
                    ["`Ctrl+Q` تعليق", "**⌘/**", "عُرف macOS"],
                    ["`Ctrl+Shift+↑/↓` نقل السطر", "**⌥↑ / ⌥↓**", "`⌃` في macOS ملكٌ لـ Mission Control"],
                    ["`F3` البحث عن التالي", "**⌘G**", "عُرف macOS"],
                    ["`Ctrl+F2` تبديل الإشارة", "**⌘F2**", "‏F2 و⇧F2 لا يزالان يقفزان بين العلامات"],
                    ["`Alt` + سحب للأعمدة", "**⌥ + سحب**", "متطابقان"],
                    ["`Ctrl+Alt+Shift+↓` محرّر الأعمدة", "**⌥⌘C**", "عُرف macOS"],
                ]
            ),
            .note("""
                أتفضّل ألّا تتعلّم من جديد؟ `الإعدادات ▸ الاختصارات ▸ استعمل طقم Notepad++`.
                """),
            .heading("أشياء في Notepad++ تعمل هنا بشكل مختلف"),
            .bullets([
                "**الجلسات** تستعيد نفسها، بما فيها الألسنة غير المحفوظة — ولا شيء تفعّله.",
                "**للإشارات تسعة ألوان**، ويمكن للسطر الواحد أن يحمل عدة ألوان معًا.",
                "**خريطة المستند** تصف *الملف كله* لا الجزء الظاهر فقط.",
                "**المايكروهات** يمكن تشغيلها \"حتى نهاية المستند\" و\"على كل الألسنة\"، والتشغيل كله خطوة تراجع واحدة.",
            ]),
            .heading("أشياء يضيفها GEditor"),
            .bullets([
                "**طاولة تنظيف بيانات** و**ملفات تعريف بيانات** لملفات CSV.",
                "**استعلامات SQL** مباشرةً على ملف CSV.",
                "**ترميزات الفيتنامية القديمة** — TCVN3 و VISCII و VNI-Windows: قراءةً وكتابةً واكتشافًا تلقائيًا.",
                "**بحث غير حسّاس للتشكيل** في كل مربّع ترشيح.",
                "**تقارير `.greport.md`** بجداول ومخطّطات تُعاد.",
                "**أداة سطر الأوامر `geditor`** في نسخة التنزيل المباشر.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "مشكلات شائعة",
        summary: "ستّ حالات تجعل الناس يظنّون أن البرنامج معطوب.",
        keywords: ["خطأ", "مشكلة", "لا يعمل", "معطوب", "لماذا"],
        blocks: [
            .table(
                headers: ["ما تراه", "السبب المعتاد"],
                rows: [
                    ["النص الفيتنامي يظهر طلاسم", "ترميز خاطئ — انقر الترميز في شريط الحالة"],
                    ["البحث عن نصّ مشكول لا يجد شيئًا", "الملف بيونيكود مفكّك — نفّذ `توحيد يونيكود` إلى NFC"],
                    ["عنصر قائمة مخفَّت", "نسخة App Store لا تستطيع تنفيذ ذلك الأمر — والعنصر يشرح لماذا"],
                    ["مطابقة الأقواس ترفض العمل", "المستند أكبر من 1 ميغابايت — وإبراز الزوج الخطأ أسوأ من لا شيء"],
                    ["العمود في شريط الحالة عليه `~`", "المستند أكبر من 200 كيلوبايت، فذلك عدد بايتات لا عمود مرئي"],
                    ["استعلام SQL يقول إن الملف يجب حفظه أولًا", "‏DuckDB يقرأ **ملفات** لا المخزن الذي تحرّره"],
                ]
            ),
            .heading("حين يخرج GEditor على نحو غير متوقّع"),
            .paragraph("""
                في الإقلاع التالي يقول شريط ذلك، مع زرّ **فتح التقرير** — ويُفتح التقرير لسانًا تستطيع \
                قراءته والنسخ منه كأي ملف نصّي آخر.
                """),
            .bullets([
                "لا يحمل التقرير إلا **الإصدار وإصدار macOS ومعمارية الجهاز واسم الإشارة ومكدّس الاستدعاء**.",
                "**لا محتوى مستندات، ولا مسارات ملفات أيضًا** — فمسار مثل `~/Desktop/رواتب-ديسمبر.xlsx` كشف ثلاثة أمور خاصة قبل أن يفتحه أحد.",
                "**لا يُرسل شيء إلى أي مكان.** فلا رفع تلقائي ولا خادم يستقبله؛ ويبقى الملف في `~/Library/Application Support/GEditor/crash/` حتى تفتحه أو تحذفه.",
                "وبمجرد أن تفتح التقرير، لا يذكره الإقلاع التالي مرة أخرى.",
            ]),
            .heading("أين تنظر بعد ذلك"),
            .bullets([
                "يعرض شريط الحالة الترميز ونهايات الأسطر واللغة ووضع اللفّ — وكل قسم قابل للنقر.",
                "يمكن تحرير `settings.json` يدويًا حين لا تكفي نافذة الإعدادات.",
                "`حول GEditor` يعطي الإصدار والنسخة، وهما ما يحتاجه بلاغ الخطأ.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
