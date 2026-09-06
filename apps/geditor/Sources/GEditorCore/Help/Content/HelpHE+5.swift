import Foundation

/// ספר העזרה בעברית — חלק חמישי: דוחות, חבילת ידע, אוטומציה והיישום עצמו.
extension HelpHE {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "דוחות ודיאגרמות",
        summary: "קובץ טקסט שמייצר דוח HTML שהמספרים בו רצים מחדש, ובנוסף דיאגרמות Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "דוחות `.greport.md`",
        summary: "Markdown ועוד ארבעה סוגי גושים ניתנים להרצה — כותבים משמאל, מציגים מימין.",
        keywords: ["דוח", "greport", "html", "ייצוא", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                קובץ `.greport.md` הוא **Markdown רגיל** ועוד כמה גושים מגודרים שניתנים להרצה. הצגתו \
                מייצרת קובץ HTML **עצמאי** — בלי רשת, בלי קבצים נלווים — שכל אחד יכול לפתוח.
                """),
            .paragraph("""
                מכיוון שהוא טקסט פשוט אפשר **להשוות אותו, להכניס אותו למאגר ולשתף אותו** — אותה גישה כמו \
                במתכוני ניקוי ובמערכות כללי איכות.
                """),
            .code(
                language: "markdown",
                caption: "sales-2026-08.greport.md — דוח שלם",
                source: """
                    ---
                    title: דוח מכירות אוגוסט
                    source: sales-2026-08.csv
                    ---

                    # דוח מכירות אוגוסט

                    נתונים נכון ל־31 באוגוסט 2026.

                    ## הכנסה לפי מחוז

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: הכנסה לפי מחוז
                    y_label: הכנסה
                    number_format: vi
                    suffix: " ₫"
                    source: מקור — sales-2026-08.csv
                    ```

                    ## איכות נתוני המקור

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("סוגי הגושים"),
            .table(
                headers: ["גוש", "מייצר"],
                rows: [
                    ["`query`", "טבלה, מפקודת SQL של DuckDB"],
                    ["`chart`", "תרשים"],
                    ["`quality`", "כרטיס דירוג איכות נתונים"],
                    ["`mining`", "טבלת דירוג של כריית קבוצות"],
                    ["`mermaid`", "דיאגרמה"],
                ]
            ),
            .heading("קדם־מידע"),
            .paragraph("""
                גוש ה־`---` בראש מצהיר על `title` ועל `source` — מקור הנתונים כברירת מחדל לכל גוש שאינו \
                נוקב במקור משלו.
                """),
            .note("""
                התצוגה המקדימה נבנית מחדש כשאתה מפסיק להקליד, אבל היא **רק מנתחת**; היא אינה מריצה \
                שאילתות בכל הקשה. שגיאות מסמך ושגיאות נתונים מדווחות בנפרד — *\"בגוש chart חסר המפתח \
                `kind`\"* היא שגיאת קובץ, *\"העמודה `doanh_thu` אינה קיימת\"* היא שגיאת נתונים.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "גוש `query`",
        summary: "פקודת DuckDB אחת הופכת לטבלה אחת בדוח.",
        keywords: ["שאילתה", "sql", "טבלה", "דוח", "גוש"],
        blocks: [
            .paragraph("""
                תוכן הגוש הוא **פקודת SQL אחת**, שרצה מול המקור של הדוח. הטבלה נקראת `t`, באותו ניב כמו \
                בלוח השאילתות.
                """),
            .code(
                language: "text",
                caption: "גוש שאילתה עם פרמטר",
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
                `:thang` הוא **פרמטר**. הוא מסופק בזמן ההצגה — מהמעטפת עם `--param thang=8`, או מקובץ \
                רשימה כשמייצרים דוחות בכמות.
                """),
            .note("""
                טבלאות בדוח נתונים **צריכות להגיע מגוש query** ולא להיכתב ביד. טבלה שנכתבה ביד אינה רצה \
                מחדש כשהמספרים משתנים, ובמוקדם או במאוחר היא סותרת את שאר הדוח.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "גוש `chart`",
        summary: "תצורת YAML הופכת לתרשים — והכלל החשוב ביותר בפורמט.",
        keywords: ["תרשים", "yaml", "דוח", "גרף"],
        blocks: [
            .code(
                language: "yaml",
                caption: "כל מפתח בגוש chart",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: הכנסה לפי מחוז
                    x_label: מחוז
                    y_label: הכנסה
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: מקור — sales.csv, נכון ל־26 באוג' 2026
                    """
            ),
            .heading("בלי `query` הוא משתמש בתוצאה של גוש ה־query שמעליו מיד"),
            .paragraph("""
                זהו הכלל החשוב ביותר בפורמט. בזכותו הדוח הנפוץ \"טבלה ואז תרשים של אותה טבלה\" אינו חוזר \
                על ה־SQL — וחזרה פירושה ששני העותקים יתרחקו זה מזה בסופו של דבר, ואז הטבלה והתרשים אומרים \
                דברים שונים באותו עמוד.
                """),
            .warning("""
                בתמורה **סדר הגושים חשוב**: הכנסת גוש query ביניהם משנה את הנתונים של התרשים שמתחתיו.
                """),
            .heading("למה `source` הוא מפתח בפני עצמו"),
            .paragraph("""
                הערת מקור שנכתבה כפרוזה מתחת לתרשים מוצגת מצוין — על המסך. אבל התרשים ייוצא כ־PNG ויודבק \
                במקום אחר, והפרוזה תישאר מאחור. כמפתח הוא מצויר **בתוך התמונה** ונוסע איתה.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "גוש `quality`",
        summary: "כרטיס דירוג איכות נתונים בתוך הדוח.",
        keywords: ["איכות", "כרטיס דירוג", "דוח", "גוש"],
        blocks: [
            .code(
                language: "yaml",
                caption: "כל מפתח בגוש quality",
                source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # ריק פירושו המקור של הדוח עצמו
                    title: איכות נתוני מכירות אוגוסט
                    rules: true                 # הצג את טבלת הכללים שעברו/נכשלו
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # קבע את תאריך הייחוס ל"עדכניות"
                    fail_under: 90              # מתחת לזה הכרטיס עובר לצבע אזהרה
                    """
            ),
            .table(
                headers: ["`chart`", "מצייר"],
                rows: [
                    ["`violations`", "ספירת שורות לכללים **שנכשלו** — עונה על \"מה לתקן קודם\""],
                    ["`dimensions`", "ציוני ששת הממדים"],
                    ["`none`", "טבלה בלבד, בלי תרשים"],
                ]
            ),
            .note("""
                קבע `now:` בדוח מחזורי. בלעדיו *עדכניות* משווה לזמן ההצגה, ולכן הצגה מחדש של דוח החודש \
                שעבר מייצרת ציון שונה מזה שפרסמת.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "גוש `mining`",
        summary: "דרג קבוצות לפי חריגות, שגיאת תחזית או סטיית מתאם.",
        keywords: ["כרייה", "דוח", "דירוג קבוצות"],
        blocks: [
            .code(
                language: "yaml",
                caption: "כל מפתח בגוש mining",
                source: """
                    group_by: tinh
                    value: doanh_thu          # העמודה לחריגות ולתחזית
                    pair: chi_phi             # עמודה שנייה, למתאם בתוך כל קבוצה
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # ריק פירושו המקור של הדוח עצמו
                    title: כרייה לפי מחוז
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "מדרג לפי"],
                rows: [
                    ["`anomalies`", "הקבוצה עם הכי הרבה שורות חריגות"],
                    ["`forecast_error`", "הקבוצה שהתחזית שלה הגרועה ביותר"],
                    ["`correlation_gap`", "הקבוצה שהמתאם שלה סוטה הכי הרבה מהטבלה המאוחדת — תופסת את פרדוקס סימפסון"],
                ]
            ),
            .warning("""
                **אין מפתח שמכבה את גוש \"השיטה\".** דירוג קבוצות בלי השיטה שלו אינו מותיר לקורא שום דרך \
                לדעת מול איזו גדר נמדד \"הכי הרבה חריגות\". מי שרוצה להסתיר אותה כבר יודע איזו תשובה הוא \
                רוצה.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "יצירת דוחות בכמות",
        summary: "תבנית אחת, רשימת פרמטרים אחת, הרבה דוחות.",
        keywords: ["אצווה", "הרבה דוחות", "פרמטרים", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                תבנית דוח אחת, שרצה לכל סניף או לכל חודש. רשימת הפרמטרים היא קובץ CSV או JSON — **שורה \
                אחת לכל דוח**.
                """),
            .code(
                language: "text",
                caption: "list.csv — שורה אחת לכל דוח",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash",
                caption: "הצג את כל האצווה מהמעטפת",
                source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """
            ),
            .code(
                language: "bash",
                caption: "או דוח אחד עם פרמטרים שהועברו ידנית",
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
        title: "דיאגרמות Mermaid",
        summary: "צייר דיאגרמות בטקסט, ערוך אותן בפקודות, והצג תצוגה מקדימה מסונכרנת בשני הכיוונים.",
        keywords: ["mermaid", "דיאגרמה", "תרשים זרימה", "רצף", "ציור"],
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
                ‏Mermaid מצייר דיאגרמות **מטקסט**: אתה כותב תיאור, והמכונה מציירת. לכן אפשר להשוות \
                דיאגרמה ולהכניס אותה למאגר — משהו שקובץ תמונה אינו יכול.
                """),
            .paragraph("""
                פתח `דיאגרמת Mermaid: תצוגה מקדימה` לתצוגה לצד העורך. השניים **מסונכרנים בשני הכיוונים**: \
                בחר איבר בתמונה והסמן קופץ לשורה שלו.
                """),
            .heading("ערוך בפקודות, לא בהקלדה מחדש"),
            .table(
                headers: ["פקודה", "מה היא עושה"],
                rows: [
                    ["הוספת תבנית…", "מוסיפה שלד מוכן לכל סוג דיאגרמה"],
                    ["הוספת איבר…", "מוסיפה צומת או משתתף"],
                    ["חיבור שני האיברים הנבחרים", "מציירת חץ ביניהם"],
                    ["עריכת התווית של האיבר הנבחר…", "משנה את הטקסט בלי לחפש את השורה"],
                    ["מחיקת האיבר הנבחר", "מסירה את הצומת **ואת** כל קשת שנוגעת בו"],
                    ["הזזת הודעה למעלה / למטה", "מסדרת מחדש שלבים בדיאגרמת רצף"],
                    ["עיצוב מחדש", "מזיחה ומיישרת את כל הגוש"],
                ]
            ),
            .heading("הפרדה לקובץ והטמעה בחזרה"),
            .paragraph("""
                מקומן של דיאגרמות גדולות הוא בקובץ `.mmd` משלהן: `הפרדת גוש לקובץ .mmd…` מוציאה אותה \
                החוצה ומשאירה הפניה. `הטמעת הקובץ המופנה בחזרה` עושה את ההפך כשצריך לשלוח קובץ אחד.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "תחביר Mermaid נפוץ",
        summary: "ארבעת סוגי הדיאגרמות הנפוצים ביותר, לכל אחד תבנית שרצה.",
        keywords: ["mermaid", "תחביר", "תרשים זרימה", "רצף", "גאנט", "מחלקות", "תבנית"],
        blocks: [
            .code(
                language: "mermaid",
                caption: "תרשים זרימה — תהליך אישור הזמנה",
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
                caption: "דיאגרמת רצף — תהליך תשלום",
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
                caption: "דיאגרמת מחלקות — מודל נתונים",
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
                caption: "גאנט — תוכנית שחרור",
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
                headers: ["צורת צומת", "כתוב"],
                rows: [
                    ["מלבן", "`A[תווית]`"],
                    ["פינות מעוגלות", "`A(תווית)`"],
                    ["אצטדיון", "`A([תווית])`"],
                    ["מעוין (החלטה)", "`A{תווית}`"],
                    ["גליל (נתונים)", "`A[(תווית)]`"],
                ]
            ),
            .table(
                headers: ["חץ", "כתוב"],
                rows: [
                    ["מלא עם ראש", "`A --> B`"],
                    ["מקווקו", "`A -.-> B`"],
                    ["עבה", "`A ==> B`"],
                    ["עם תווית", "`A -- תווית --> B`"],
                ]
            ),
            .note("""
                הכיוון של תרשים זרימה בא מיד אחרי `flowchart`: `TD` מלמעלה למטה, `LR` משמאל לימין, \
                ובנוסף `BT` ו־`RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - חבילת הידע

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "חבילת הידע",
        summary: "חיתוך לקטעים, אינדקסי חיפוש, גרפי ידע, ישויות והערכת אחזור.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "מהי חבילת הידע",
        summary: "כלים להכנת נתונים ולבדיקתם עבור מערכת שעונה על שאלות ממסמכים.",
        keywords: ["rag", "ידע", "קטע", "הטמעה", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                כשבונים מערכת שעונה על שאלות מאוסף מסמכים, רוב העבודה אינה במודל אלא **בהכנת הנתונים**: \
                חיתוך המסמכים לקטעים הגיוניים, בדיקת איכות הקטעים, בניית אינדקס, ו**מדידה האם האחזור \
                באמת מוצא את הדבר הנכון**.
                """),
            .paragraph("""
                הפרק הזה הוא ערכת הכלים בדיוק לשם כך. הוא רץ **כולו על המחשב שלך** ולעולם אינו פונה \
                לרשת.
                """),
            .table(
                headers: ["משימה", "כלי"],
                rows: [
                    ["לחתוך מסמכים לקטעים", "תצוגה מקדימה של חיתוך"],
                    ["לבדוק ולדרג קטעים", "בדיקת קטעי JSONL"],
                    ["להמיר בין צורות נתונים", "המרת ידע"],
                    ["לבנות ולבדוק גרף קשרים", "גרף ידע"],
                    ["למצוא שמות פרטיים בטקסט", "סימון ישויות"],
                    ["למדוד איכות אחזור", "מעבדת האחזור"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "חיתוך ובדיקה של אוסף JSONL",
        summary: "הצג מראש את גבולות הקטעים על הטקסט עצמו, ואז דרג את כל האוסף.",
        keywords: ["קטע", "jsonl", "אוסף", "חפיפה", "טוקן"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("תצוגה מקדימה של חיתוך"),
            .paragraph("""
                פתח מסמך טקסט או Markdown, בחר אסטרטגיה וגודל קטע. הגבולות **מודגשים על הטקסט עצמו**, \
                כך שאפשר לראות איפה חיתוך נופל באמצע משפט או דרך טבלה עוד לפני שמייצאים משהו.
                """),
            .bullets([
                "**גודל קבוע** עם חפיפה.",
                "**לפי מבנה** — בכותרות Markdown, תוך שמירה על זרימת המסמך.",
                "**לפי פסקה**, במיזוג עד להשגת הגודל.",
            ]),
            .heading("בדיקת אוסף JSONL קיים"),
            .paragraph("""
                לאוסף שכבר יש לך (קטע JSON אחד בכל שורה), `JSONL: בדיקת קטעים…` עונה על: אילו שורות אינן \
                JSON תקין, אילו קטעים קצרים או ארוכים מדי, אילו מהם משכפלים זה את זה, ואילו נחתכו באמצע \
                משפט.
                """),
            .note("""
                אפשר לדרג אוסף גם **באותה מסגרת של שישה ממדים** כמו נתונים טבלאיים — השתמש במפתח \
                `corpus:` בגוש `quality` שבדוח.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "המרת פורמטי ידע",
        summary: "קטעים בין JSONL · CSV · Markdown, גרפים בין DOT · Mermaid · רשימות קשתות.",
        keywords: ["המרה", "jsonl", "dot", "mermaid", "רשימת קשתות"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["מ", "אל"],
                rows: [
                    ["קטעי JSONL", "CSV · Markdown"],
                    ["קטעי CSV", "JSONL · Markdown"],
                    ["גרף DOT", "Mermaid · רשימת קשתות"],
                    ["רשימת קשתות", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                יש **תצוגה מקדימה של חמש שורות** לפני יצירת הלשונית החדשה, אותו מנגנון כמו בהמרת CSV.
                """),
            .paragraph("""
                `פתיחת שלשות/קשתות כטבלה` מציגה קובץ שלשות או רשימת קשתות כרשת — סנן ומיין אותה כמו כל \
                CSV אחר.
                """),
            .note("""
                הכיוון **Markdown ← JSONL** אינו בפקודה הזאת: הכיוון הזה *הוא* החיתוך, והפקודה מפנה אותך \
                לשם. שני מימושים של אותו חיתוך היו מייצרים שתי תוצאות שונות.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "גרפי ידע",
        summary: "בדוק תחביר, דרג תקינות, והרץ אלגוריתמים על גרפים בני מיליון קשתות.",
        keywords: ["גרף", "dot", "cypher", "pagerank", "louvain", "בדיקת תחביר"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                ‏GEditor קורא גרפים כ־**DOT**, כ־**רשימות קשתות** וכ־**שלשות**. `בדיקת תחביר גרף` תופסת \
                שגיאות תחביר, צמתים תלויים וקשתות שמצביעות על צמתים שאינם קיימים.
                """),
            .heading("האלגוריתמים הזמינים"),
            .table(
                headers: ["אלגוריתם", "עונה על"],
                rows: [
                    ["שכנות במרחק k", "מה קשור לצומת הזה בתוך k צעדים"],
                    ["רכיבים קשירים", "לכמה חלקים זרים הגרף מתפרק"],
                    ["PageRank", "אילו צמתים חשובים"],
                    ["Louvain", "איך הגרף מתחלק לקהילות"],
                ]
            ),
            .paragraph("""
                על גרף בן **מיליון קשתות** כל הארבעה רצים בין כמה אלפיות שנייה לכשנייה.
                """),
            .note("""
                אפשר לדרג גרף גם ב**מסגרת ששת הממדים** המשמשת לטבלאות ולאוספים — השתמש במפתח `graph:` \
                בגוש `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "סימון ישויות מרשימה",
        summary: "טען רשימת שמות פרטיים ומצא כל מופע — לפי שלושה כללים שנבנו לווייטנאמית.",
        keywords: ["ישות", "שם פרטי", "ner", "סימון", "מילון", "התאמה"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                טען רשימת שמות (חברות, מוצרים, מקומות) ו־GEditor ידגיש כל מופע במסמך, עם טבלת ספירה.
                """),
            .heading("שלושה כללי התאמה, כולם מנתונים ווייטנאמיים"),
            .bullets([
                "**ההתאמה הארוכה ביותר מנצחת.** אם ברשימה יש גם `An Phát` וגם `Công ty An Phát`, משפט שמכיל את הביטוי הארוך חייב להתאים לארוך — אחרת הוא מתפצל לשניים ונספר כשתי ישויות, מה ש**מנפח** את הסטטיסטיקה.",
                "**גבולות מילה נדרשים.** `An` אסור שיתאים בתוך `Anh` או `Hoàn`. שמות פרטיים ווייטנאמיים קצרים וחולקים הברות עם אינספור מילים רגילות.",
                "**לא רגיש לרישיות, אבל רגיש לניקוד.** `CÔNG TY` ו־`Công ty` הם אחד; `má` ו־`ma` אינם.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "יישוב וריאציות של ישויות",
        summary: "זהה את `Cty An Phát` ואת `Công ty An Phát` כאחד — ועדיין השאר את ההחלטה לך.",
        keywords: ["יישוב ישויות", "וריאציות", "נרמול שמות", "כפילויות"],
        blocks: [
            .paragraph("""
                אותו אשכול כמו **כפילויות מעורפלות** ברשת CSV — מימוש משותף אחד, לא שניים.
                """),
            .paragraph("""
                הפלט הוא **הצעה**: אתה סוקר כל אשכול ובוחר את הצורה הקנונית. אין כפתור מזג־הכול, כי שני \
                שמות שדומים ב־92% עשויים להיות שני ארגונים אמיתיים.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "מעבדת האחזור",
        summary: "מדוד אם האינדקס מוצא את הדבר הנכון, בעזרת ערכת שאלות עם תשובות.",
        keywords: ["אחזור", "bm25", "היזכרות", "mrr", "ndcg", "הערכה", "ערכת זהב"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                טען **ערכת הערכה** — בכל שורה שאלה עם מזהי הקטעים שאמורים לחזור — ואז הרץ את כל האצווה \
                מול האינדקס.
                """),
            .table(
                headers: ["מדד", "עונה על"],
                rows: [
                    ["recall@k", "כמה מערכת התשובה מופיע ב־k הראשונים"],
                    ["MRR", "כמה נמוך יושבת התוצאה הנכונה הראשונה"],
                    ["nDCG@k", "האם הדירוג טוב, כולל המיקום"],
                ]
            ),
            .paragraph("""
                התוצאות מגיעות גם **לכל שאלה בנפרד**, הגרועות ראשונות — וזו רשימת הדברים לתיקון באוסף, \
                בסדר שהכי כדאי לתקן.
                """),
            .warning("""
                שלושת המדדים הם **ממוצעים**, וממוצע מסתיר הרבה. קרא תמיד את הטבלה לכל שאלה לפני שאתה \
                מסיק ש\"האינדקס מספיק טוב\".
                """),
            .paragraph("""
                אפשר להשוות שתי תצורות זו לצד זו, והתוצאה נופלת ישירות לדוח `.greport.md` כך שההרצה הבאה \
                תהיה זהה.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - מאקרו ואוטומציה

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "מאקרו ואוטומציה",
        summary: "הקלט פעולות, הרץ אותן בכמות, כתוב סקריפטים, והפעל מהמעטפת.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "הקלטת מאקרו והרצתו",
        summary: "הקלט רצף וחזור עליו — כל ההרצה היא צעד ביטול אחד.",
        keywords: ["מאקרו", "הקלטה", "הרצה", "חזרה", "אוטומציה"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "התחלה / עצירה של ההקלטה"),
                HelpShortcut("⌃P", "הרצה"),
            ]),
            .steps([
                "`⌃R` מתחיל את ההקלטה.",
                "עשה את מה שתרצה לחזור עליו — הקלד, הזז את הסמן, חפש, החלף.",
                "`⌃R` שוב כדי לעצור.",
                "`⌃P` מריץ, או `מאקרו ▸ הרץ עד סוף המסמך` מריץ עד הסוף.",
                "`מאקרו ▸ שמור מאקרו…` נותן לו שם להפעלות הבאות.",
            ]),
            .heading("הוא מקליט פקודות, לא הקשות גולמיות"),
            .paragraph("""
                מאקרו שומר **את מה שעשית**, לא אילו מקשים לחצת. זה הופך אותו לבלתי תלוי בפריסת המקלדת \
                ובשיטת הקלט הפעילה, וזה הופך את קובץ המאקרו ל**קריא** כשפותחים אותו.
                """),
            .heading("מתי מאקרו נעצר"),
            .table(
                headers: ["סיבה", "משמעות"],
                rows: [
                    ["מספר החזרות נגמר", "רגיל"],
                    ["שלב `find` לא מצא כלום", "כך \"הרצה עד סוף הקובץ\" עוצרת את עצמה"],
                    ["הגעה לסוף המסמך", "אין לאן להמשיך"],
                    ["ביטלת", "`מאקרו ▸ בטל מאקרו רץ`"],
                    ["איטרציה שלא שינתה דבר ולא זזה לשום מקום", "נעצר כדי שלא ילולאה לנצח"],
                ]
            ),
            .note("""
                כל ההרצה — אפילו עשרת אלפים חזרות — היא צעד ביטול **אחד**.
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "הרצת מאקרו בכמות",
        summary: "על כל לשונית פתוחה, או על תיקייה של קבצים לא פתוחים.",
        keywords: ["אצווה", "כל הלשוניות", "תיקייה", "מאקרו", "מסכה"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["פקודה", "היקף", "ניתן לביטול"],
                rows: [
                    ["הרצה על כל הלשוניות", "הלשוניות הפתוחות", "כן — צעד ביטול אחד לכל לשונית"],
                    ["הרצה על תיקייה…", "קבצים **שאינם פתוחים** בדיסק", "לא"],
                ]
            ),
            .warning("""
                הרצה על תיקייה נוגעת בקבצים שאינם פתוחים באף לשונית, ולכן **אין ביטול**. כברירת מחדל \
                GEditor **כותב קבצים חדשים** במקום לדרוס את המקוריים. השאר את ברירת המחדל אלא אם יש לך \
                גיבוי או מאגר עם ניהול גרסאות.
                """),
            .heading("סינון קבצים במסכה"),
            .paragraph("""
                בבורר התיקיות יש **מסנן שם קובץ**: הקלד `*.csv;*.log` והמאקרו יגע רק בהם. זה אותו תחביר \
                מסכה שבו משתמש `חיפוש בכל תיקייה`, וכמה תבניות מופרדות ב־`;` או ב־`,`.
                """),
            .bullets([
                "השאר **ריק** והוא לוקח כל קובץ טקסט ש־GEditor יכול לקרוא — ההתנהגות הקודמת.",
                "המסכה **מחליפה** את רשימת הסיומות ההיא ולא מצמצמת אותה עוד: הקלד `*.bak` והוא ירוץ על קובצי `.bak`, גם אם הסיומת הזאת אינה ברשימת הטקסט.",
                "אם שום דבר לא תואם, ההודעה **חוזרת עליך את המסכה שלך** במקום להאשים תיקייה ריקה.",
            ]),
            .paragraph("""
                לתיבה הזאת יש סיבה מעשית מאוד: בתיקייה יש 400 קובצי `.json` ו־12 קובצי `.log`, והמאקרו \
                שלך מסדר רק יומנים. בלי מסכה גם 400 האחרים יעובדו — ומכיוון שהאצווה כותבת קבצים חדשים, \
                טעות אחת משאירה 400 פיסות זבל.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "תחביר קובץ מאקרו",
        summary: "שבעה סוגי שלבים, פורמט JSON מלא, ושני מאקרו שרצים.",
        keywords: ["מאקרו", "json", "תחביר", "עריכה ידנית", "שיתוף"],
        blocks: [
            .paragraph("""
                כל מאקרו הוא **קובץ JSON משלו** בתיקיית `macros/` של GEditor. השחתה נשארת מוגבלת למאקרו \
                אחד, ושיתוף אחד עם עמית פירושו לשלוח קובץ אחד.
                """),
            .code(
                language: "text",
                caption: "איפה הקבצים נמצאים",
                source: """
                    ~/Library/Application Support/GEditor/macros/<שם-המאקרו>.json
                    """
            ),
            .heading("שבעת סוגי השלבים"),
            .table(
                headers: ["שלב", "נכתב כ", "משמעות"],
                rows: [
                    ["הוספת טקסט", "`{\"insert\": {\"_0\": \"טקסט\"}}`", "מקליד בסמן; עם בחירה מחליף אותה"],
                    ["מחיקה אחורה", "`{\"deleteBackward\": {}}`", "כמו מקש Delete"],
                    ["מחיקה קדימה", "`{\"deleteForward\": {}}`", "כמו ⌦"],
                    ["תזוזה", "`{\"move\": {\"_0\": \"nextLine\"}}`", "ראה את רשימת הכיוונים למטה"],
                    ["בחירת השורה", "`{\"selectLine\": {}}`", "בלי סוף השורה"],
                    ["חיפוש", "`{\"find\": { … }}`", "מוצא **ובוחר** את ההתאמה הבאה"],
                    ["החלפת הבחירה", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` עובד כשהשלב הקודם היה `find` עם regex"],
                ]
            ),
            .heading("כיווני תזוזה"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("שלב `find` מלא"),
            .code(
                language: "json",
                caption: "ארבעת המפתחות של שלב find",
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
            .paragraph("`mode` מקבל `normal`, `extended` או `regex` — אותם שלושה מצבים כמו בתיבת החיפוש."),
            .heading("דוגמה 1 — הפיכת קוד המחוז בתחילת כל שורה לאותיות גדולות"),
            .code(
                language: "json",
                caption: "macros/uppercase-province.json",
                source: """
                    {
                      "name": "קוד מחוז באותיות גדולות",
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
                הרץ אותו עם `מאקרו ▸ הרץ עד סוף המסמך`: העובדה ששלב ה־`find` אינו מוצא עוד היא בדיוק תנאי \
                העצירה.
                """),
            .heading("דוגמה 2 — מחיקת השורה שאחרי כל שורה שמכילה TODO"),
            .code(
                language: "json",
                caption: "macros/delete-line-after-todo.json",
                source: """
                    {
                      "name": "מחק שורה אחרי TODO",
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
                בדוק מאקרו שנערך ידנית קודם על עותק. שלב `find` שנכתב שגוי גורם למאקרו להיעצר מיד — זה \
                המקרה השפיר. המקרה הממאיר הוא תבנית שמתאימה רחב יותר ממה שחשבת, ועורכת אלפי מקומות בתוך \
                צעד ביטול אחד.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "סקריפטים ב־JavaScript",
        summary: "ארבע פונקציות, קובץ `.js` אחד, וכל מה שהוא עושה הוא צעד ביטול אחד.",
        keywords: ["סקריפט", "javascript", "js", "אוטומציה", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                שים קובץ `.js` בתיקיית `scripts/` של GEditor והרץ אותו מ־`מאקרו ▸ סקריפט…`. סקריפט רואה \
                בדיוק **ארבעה** דברים:
                """),
            .table(
                headers: ["קריאה", "משמעות"],
                rows: [
                    ["`doc.text`", "כל טקסט המסמך"],
                    ["`doc.selection`", "הבחירה (מחרוזת ריקה כשאין בחירה)"],
                    ["`doc.replace(s)`", "החלפת **כל המסמך** ב־`s` — צעד ביטול אחד"],
                    ["`doc.log(s)`", "כתיבת שורה ללוח התוצאות"],
                ]
            ),
            .code(
                language: "javascript",
                caption: "scripts/number-lines.js",
                source: """
                    // מספר כל שורה.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("שורות שמוספרו: " + (lines.length - 1));
                    doc.replace(out.join("\\n"));
                    """
            ),
            .code(
                language: "javascript",
                caption: "scripts/keep-three-columns.js — שמירת שלוש עמודות ה־CSV הראשונות",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("שורות שקוצרו ל־3 עמודות: " + out.length);
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("שלוש מגבלות שכדאי להכיר"),
            .bullets([
                "**אין גישה לקבצים, אין רשת, אין הפעלת תהליכים.** משטח ה־API צר במכוון: להרחיב אותו אחר כך זה קל, לצמצם אותו שובר כל סקריפט שמשתמשים כתבו.",
                "**זה אינו גבול אבטחה.** הסקריפטים רצים באותו תהליך. אל תריץ סקריפט שלא קראת.",
                "**יש מגבלה של חמש שניות.** מעבר לה תקבל הודעה והיישום נשאר שמיש — אבל התהליכון של הסקריפט ההוא **ממשיך להסתובב עד שתצא**, ואוכל ליבה. ההודעה אומרת זאת.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "סינון דרך פקודה חיצונית",
        summary: "העבר את הבחירה דרך פקודת יוניקס וקבל את התוצאה בחזרה.",
        keywords: ["מסנן", "פקודה חיצונית", "מעטפת", "צינור", "sort", "jq", "יוניקס"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                הבחירה (או כל המסמך) מוזנת ל־`stdin` של פקודה, וה־`stdout` של אותה פקודה מחליף אותה.
                """),
            .code(
                language: "bash",
                caption: "כמה נפוצות",
                source: """
                    sort -u                     # מיין והשמט כפילויות
                    jq .                        # עצב מחדש JSON
                    tr 'a-z' 'A-Z'              # אותיות גדולות
                    grep -v '^#'                # השמט שורות הערה
                    awk -F, '{print $3","$1}'   # החלף סדר עמודות
                    """
            ),
            .note("""
                התוצאה היא צעד ביטול **אחד**. אם הפקודה מחזירה קוד שגיאה, GEditor משאיר את הטקסט כמות \
                שהוא ומציג את `stderr`.
                """),
            .warning("""
                הפקודה הזאת קיימת **רק בגרסת ההורדה הישירה**. App Sandbox אוסר הרצת קוד מחוץ ליישום, \
                ולכן בגרסת App Store פריט התפריט נשאר ומסביר למה הוא אינו זמין.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "כלי שורת הפקודה `geditor`",
        summary: "פתח, נקה, שאל, דרג והצג דוחות — בלי לפתוח את היישום.",
        keywords: ["cli", "שורת פקודה", "מסוף", "geditor", "סקריפט", "ci"],
        blocks: [
            .warning("""
                זמין רק בגרסת **ההורדה הישירה**. גרסת App Store רצה בארגז חול, ולכן תהליך שורת פקודה \
                חיצוני אינו יכול להתחבר אליה.
                """),
            .heading("פתיחת קבצים"),
            .code(
                language: "bash",
                caption: "פתח, קפוץ למיקום, קרא מצינור",
                source: """
                    geditor report.csv
                    geditor report.csv:120:5       # שורה 120, עמודה 5
                    geditor -w notes.md            # המתן עד סגירת הקובץ לפני יציאה
                    geditor -r app.log             # פתח לקריאה בלבד
                    git diff | geditor             # קרא stdin ללשונית חדשה
                    """
            ),
            .table(
                headers: ["אפשרות", "משמעות"],
                rows: [
                    ["`-w`, `--wait`", "המתן עד סגירת הקובץ לפני יציאה — לשימוש כעורך של `git`"],
                    ["`-n`, `--new-window`", "פתח בחלון חדש"],
                    ["`-r`, `--read-only`", "פתח לקריאה בלבד"],
                    ["`-i`, `--info`", "הדפס קידוד, סופי שורה ומספר שורות, ואז צא — **בלי** לפתוח את היישום"],
                    ["`-h`, `--help`", "הצג עזרה"],
                    ["`-v`, `--version`", "הצג גרסה"],
                ]
            ),
            .heading("הרצה בלי לפתוח את היישום"),
            .paragraph("""
                ארבע קבוצות הפקודות שלהלן רצות **כולן בתוך תהליך שורת הפקודה**, ולכן הן עובדות ב־CI שבו \
                איש אינו מחובר לסשן גרפי.
                """),
            .code(
                language: "bash",
                caption: "ניקוי עם מתכון",
                source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "שאילתות",
                source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "שער האיכות — קוד יציאה 0 עבר · 1 נכשל · 2 שגיאה",
                source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "הצגת דוחות",
                source: """
                    geditor --report template.greport.md --param-list list.csv --out ./reports/
                    """
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript ותפריט השירותים",
        summary: "קרא וכתוב את המסמך מ־AppleScript, או שלח טקסט ל־GEditor מיישום אחר.",
        keywords: ["applescript", "osascript", "שירותים", "אוטומציה", "shortcuts"],
        blocks: [
            .code(
                language: "applescript",
                caption: "קרא את המסמך הפתוח",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "כתוב מעל התוכן, וקרא את הבחירה",
                source: """
                    tell application "GEditor"
                        set selected text to "טקסט שיבוא במקום הבחירה"
                        set contents to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "פתח קובץ",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """
            ),
            .heading("תפריט השירותים"),
            .paragraph("""
                בחר טקסט בכל יישום, ואז השתמש בתפריט `שירותים` כדי לשלוח אותו ל־GEditor כלשונית חדשה.
                """),
            .note("""
                בפעם הראשונה שתריץ AppleScript, macOS מבקש הרשאת אוטומציה. זה החלון של המערכת ולא של \
                GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "חבילות הרחבה ותוספים",
        summary: "שני סוגי הרחבה, ובאיזו גרסה כל אחד רץ.",
        keywords: ["תוסף", "הרחבה", "חבילה", "מקומי"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("חבילות הרחבה"),
            .paragraph("""
                חבילה היא **קובץ JSON אחד** שמאגד ערכת נושא, סקריפטים ושפות מוגדרות־משתמש יחד. התקנה \
                מעתיקה קובץ, הסרה מוחקת אחד — ורשימת החבילות נגזרת מה**דיסק**, לא מרישום שעלול לשקר.
                """),
            .paragraph("עובדות ב**שתי הגרסאות**."),
            .heading("תוספים מקומיים"),
            .paragraph("""
                תוספים מהודרים מראש רצים ב**תהליך נפרד** עם משטח API צר — תוסף שקורס אינו לוקח איתו את \
                היישום.
                """),
            .warning("""
                תוספים מקומיים קיימים **רק בגרסת ההורדה הישירה**, כי App Sandbox אוסר טעינת קוד מחוץ \
                ליישום. כל תוסף חייב **אישור ידני חד־פעמי** לפי חתימת גיבוב לפני שהוא ירוץ.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - תצורה והיישום

    static let application = HelpChapter(
        id: "ung-dung",
        title: "תצורה והיישום",
        summary: "הגדרות, קיצורים, ערכות נושא, עדכונים, מעבר מ־Notepad++, פתרון תקלות.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "הגדרות",
        summary: "כל אפשרות חיה בקובץ JSON אחד קריא לאדם שאפשר להעתיק ל־Mac אחר.",
        keywords: ["הגדרות", "העדפות", "אפשרויות", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "פתיחת ההגדרות")]),
            .paragraph("""
                אין אישור ואין ביטול — שינוי נכנס לתוקף ונכתב מיד, בדרך של macOS.
                """),
            .heading("קובץ התצורה"),
            .code(
                language: "text",
                caption: "איפה הוא נמצא",
                source: """
                    ~/Library/Application Support/GEditor/settings.json
                    """
            ),
            .paragraph("""
                זהו **קובץ JSON מוזח שאפשר לקרוא ולערוך ידנית**. העתק אותו ל־Mac אחר וכל התצורה שלך \
                תלך איתו. כפתור `פתח קובץ תצורה` בהגדרות לוקח אותך ישירות לשם.
                """),
            .heading("המפתחות"),
            .table(
                headers: ["מפתח", "ברירת מחדל", "משמעות"],
                rows: [
                    ["`fontSize`", "`13`", "גודל הגופן בעורך"],
                    ["`tabWidth`", "`4`", "כמה עמודות רוחב TAB"],
                    ["`usesTabsForIndent`", "`false`", "הזחה ב־TAB במקום ברווחים"],
                    ["`languageIndent`", "`{}`", "הזחה לכל שפה — ראה את דף הרווחים"],
                    ["`smartIndent`", "`true`", "הזחה אוטומטית בשורה חדשה"],
                    ["`highlightAllMatches`", "`true`", "הדגש כל תוצאת חיפוש"],
                    ["`ligatures`", "`false`", "ליגטורות — ראה את ההערה מתחת לטבלה"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "גזור רווחים בסופי שורות בשמירה"],
                    ["`normalizeToNFCOnSave`", "`false`", "נרמל יוניקוד ל־NFC בשמירה"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "קידוד לקבצים חדשים"],
                    ["`defaultEOL`", "`\"lf\"`", "סופי שורה לקבצים חדשים"],
                    ["`language`", "`\"system\"`", "שפת הממשק"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "ערכת ברירת המחדל", "איזו ערכת צבעים בשימוש"],
                    ["`showWelcomeOnLaunch`", "`true`", "פתח את חלון הפתיחה בהפעלה"],
                    ["`keyBindings`", "`{}`", "רק המקשים ששינית מברירת המחדל"],
                ]
            ),
            .note("""
                **למה הליגטורות כבויות כברירת מחדל.** ליגטורה ממזגת `!=` או `->` ל**סימן אחד**, ולכן \
                התווים שאתה רואה על המסך כבר אינם תואמים לתווים שבקובץ — בעוד עורך העמודות, מצב העמודות \
                וגלישה בעמודה מודדים בעמודות. הפעל אותה כשאתה כותב פרוזה, או כשבחרת גופן תכנות (Fira \
                Code, JetBrains Mono) דווקא בשביל הליגטורות שלו.
                """),
            .heading("התיקיות השכנות"),
            .table(
                headers: ["תיקייה", "מכילה"],
                rows: [
                    ["`macros/`", "מאקרו שמורים, קובץ JSON לכל אחד"],
                    ["`scripts/`", "סקריפטים ב־JavaScript"],
                    ["`themes/`", "ערכות צבעים"],
                    ["`grammars/`", "שפות מוגדרות־משתמש"],
                ]
            ),
            .warning("""
                קובץ תצורה שנכתב על ידי GEditor **חדש יותר** **אינו נדרס** על ידי ישן יותר — הוא רץ על \
                ברירות המחדל ואומר זאת. דריסה היא הדרך הבטוחה ביותר להשמיד את התצורה של מי שמסנכרן שני \
                מחשבים, והוא לעולם לא היה יודע למה.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "שורת המצב",
        summary: "עשרה מקטעים בתחתית — כל אחד קריא, וכל אחד ניתן ללחיצה.",
        keywords: ["שורת מצב", "סרגל תחתון", "היסט", "מיקום", "קידוד", "טאב", "קריאה בלבד"],
        blocks: [
            .paragraph("""
                זה ההבדל הגדול ביותר משורות המצב של עורכים אחרים: **אף מקטע אינו לקריאה בלבד**. אם אתה \
                רואה ערך שגוי, לחיצה עליו היא הדרך לתקן אותו, במקום לחפור בתפריטים.
                """),
            .table(
                headers: ["מקטע", "אומר לך", "לחיצה עליו"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "מיקום הסמן — עמודה בתווים, `@340` מיקום הבית",
                     "פותחת את תיבת `מעבר אל`"],
                    ["`11 byte · 3 dòng`", "גודל המסמך",
                     "סופרת בתים · תווים · מילים · שורות"],
                    ["`🔒 Chỉ đọc`", "מוצג רק כשהמסמך נעול",
                     "אומרת למה הוא נעול, ומשחררת אותו כשאפשר"],
                    ["`View` / `Code`", "באיזו תצוגה אתה", "מחליפה (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "מצב CSV והמפריד שבשימוש",
                     "מחליפה מצב CSV, או **בוחרת מחדש את המפריד**"],
                    ["`Đang theo dõi`", "`tail -f` רץ", "—"],
                    ["`UTF-8`", "הקידוד", "פרש מחדש, או המר לקידוד אחר"],
                    ["`LF`", "סגנון סוף השורה", "החלף בין LF · CRLF · CR"],
                    ["`Python`", "שפת צביעת התחביר", "בחר אחרת, או חזור לזיהוי לפי סיומת"],
                    ["`Tab: 4`", "רוחב ההזחה", "2 · 4 · 8, גלובלית או **רק לשפה הזאת**"],
                    ["`Ngắt: tắt`", "מצב הגלישה הרכה", "מחזירה בין שלושת המצבים"],
                ]
            ),
            .heading("שלושה מקטעים ששווה מבט שני"),
            .bullets([
                "**`@340` — מיקום הבית.** זה המספר שכל כלי אחר במוצר מדבר בו: שגיאות JSON ו־XML, פלט `--doc-sweep`, המציג הבינארי, ותיבת `מעבר אל @340`. קרא כאן, הקלד שם.",
                "**`~` על העמודה** פירושו שהמספר סופר בתים ולא עמודות חזותיות — זה קורה רק בשורות ארוכות מ־200 ק\"ב, שבהן ספירת תווים הייתה מאטה כל תזוזת סמן.",
                "**`CSV · …` ניתן ללחיצה כדי לבחור מחדש את המפריד.** הזיהוי עלול לטעות, וכשהוא טועה כל פעולת עמודות סוטה בלי שדבר יסמן זאת. זו הדרך שלך לומר אחרת — היא רק **קוראת מחדש** את הקובץ ואינה משנה אף בית (בניגוד ל־`CSV ▸ שינוי מפריד…`, שכותב אותו מחדש).",
            ]),
            .note("""
                מקטע שאינו רלוונטי לקובץ הפתוח **מוסתר**, לא מעומעם: `קריאה בלבד` מופיע רק כשהמסמך באמת \
                נעול, ו־`CSV · …` רק במצב CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "שינוי קיצורי מקלדת",
        summary: "שנה מקשים בודדים, או אמץ את מפת המקשים של Notepad++ כולה.",
        keywords: ["קיצור", "שיוך מקשים", "מפת מקשים", "ערכה"],
        blocks: [
            .paragraph("""
                ב־`הגדרות…` יש מקטע קיצורים עם שני כפתורים מהירים: **השתמש בערכת Notepad++** ו**חזרה \
                לברירות המחדל**.
                """),
            .paragraph("""
                קובץ התצורה מתעד רק את מה ש**שינית מברירות המחדל**. כך, כש־GEditor משנה מקש ברירת מחדל \
                בגרסה חדשה, אינך נתקע עם מפת המקשים הישנה בלי שאיש יאמר לך.
                """),
            .note("""
                שתי פקודות אינן יכולות לחלוק קיצור. כשזה קורה, AppKit מפעיל בשקט רק את **פריט התפריט \
                הראשון** והפקודה השנייה נראית שבורה — ולכן ב־GEditor יש בדיקה שמונעת זאת.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "ערכות נושא, בהיר וכהה",
        summary: "עקוב אחר המערכת, בהיר או כהה; וערכת נושא היא קובץ JSON שאפשר לערוך.",
        keywords: ["ערכת נושא", "צבעים", "מצב כהה", "בהיר", "מראה"],
        blocks: [
            .paragraph("""
                `הגדרות…` בוחר בין `עקוב אחר המערכת`, `בהיר` או `כהה`, ובוחר ערכת צבעים.
                """),
            .paragraph("""
                ערכת נושא היא קובץ JSON בתיקיית `themes/`. הכפתור `ייצא את ערכת הנושא הנוכחית` כותב אחת \
                כנקודת פתיחה לערכה משלך.
                """),
            .note("""
                צבע שנכתב שגוי בקובץ ערכת נושא נסוג לצבע של **ערכת ברירת המחדל**, לא לשחור. שחור נראה \
                כהחלטת עיצוב, והמשתמש היה מחפש את הבעיה במקום אחר.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "עדכונים, גרסאות ויציאה",
        summary: "כיצד העדכון נבדל בין שתי הגרסאות.",
        keywords: ["עדכון", "גרסה", "אודות", "יציאה"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["גרסה", "מתעדכנת דרך"],
                rows: [
                    ["App Store", "App Store, כמו כל יישום אחר"],
                    ["הורדה ישירה", "`בדוק עדכונים…` בתוך היישום"],
                ]
            ),
            .paragraph("""
                `אודות GEditor` מציג את הגרסה הרצה ואיזו גרסה זו — שימושי כשמדווחים על תקלה.
                """),
            .note("""
                בגרסת App Store הפקודה `בדוק עדכונים…` **נשארת בתפריט** ומסבירה למה היא אינה רלוונטית, \
                במקום להיעלם. פריט תפריט חסר הוא שאלה לתמיכה.
                """),
            .paragraph("""
                יציאה אינה מאבדת עבודה: ההפעלה חוזרת בפעם הבאה שתפתח.
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "שימוש בחלון העזרה הזה",
        summary: "חפש בספר, החלף את שפתו, והחזר את חלון הפתיחה.",
        keywords: ["עזרה", "מדריך", "חיפוש", "פתיחה", "שפה"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "פתיחת חלון העזרה")]),
            .bullets([
                "תיבת החיפוש בפינה השמאלית העליונה מסתכלת בתוך **גוף הטקסט ודוגמאות הקוד** — הקלדת מפתח הגדרה חשוף כמו `fail_under` מגיעה לדף הנכון.",
                "הקלדה **בלי ניקוד** עדיין מוצאת טקסט מנוקד.",
                "הכפתור `חזרה` מחזיר לדף הקודם.",
                "הכפתור `העתק` בכל גוש קוד מעתיק את הגוש ההוא.",
            ]),
            .heading("קריאה בשפה אחרת"),
            .paragraph("""
                התפריט הקופץ בפינה הימנית העליונה של החלון הזה בוחר את **שפת הספר**, בנפרד משפת הממשק של \
                היישום. ההחלפה משאירה אותך **בדף שאתה קורא** — מזהי הדפים אינם מתורגמים במכוון, בדיוק כדי \
                שזה יעבוד.
                """),
            .note("""
                רק שפות שיש להן ספר בפועל מופיעות ברשימה. פריט תפריט שמחליף למשהו ומשאיר את הטקסט ללא \
                שינוי היה פריט תפריט שמשקר.
                """),
            .heading("החזרת חלון הפתיחה"),
            .paragraph("""
                אם סימנת **אל תפתח חלון זה בהפעלה**, פתח אותו מחדש עם `עזרה ▸ סיור בתכונות` — תיבת הסימון \
                בתחתית החלון מופיעה שוב ואפשר לבטל את הסימון.
                """),
            .paragraph("""
                או החזר את `showWelcomeOnLaunch` ל־`true` ב־`settings.json`.
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "מ־Notepad++ ל־GEditor",
        summary: "אילו מקשים מחליפים מקומות, מה עובד אחרת, ומה חסר.",
        keywords: ["notepad++", "notepad", "מעבר", "חלונות", "קיצורים"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                כמה מקשים **מחליפים מקומות** ב־macOS ולא רק ש־`Ctrl` הופך ל־`⌘`. הנה ההשוואה.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "למה"],
                rows: [
                    ["`Ctrl+D` שכפול שורה", "**⇧⌘D**", "`⌘D` כאן הוא ריבוי סמנים, כמו בכל עורך Mac"],
                    ["`Ctrl+L` מחיקת שורה", "**⌘K**", "`⌘L` ב־macOS פירושו \"מעבר לשורה\""],
                    ["`Ctrl+G` מעבר לשורה", "**⌘L**", "השניים האלה מחליפים מקומות"],
                    ["`Ctrl+Q` הערה", "**⌘/**", "מוסכמת macOS"],
                    ["`Ctrl+Shift+↑/↓` הזזת שורה", "**⌥↑ / ⌥↓**", "`⌃` ב־macOS שייך ל־Mission Control"],
                    ["`F3` חפש את הבא", "**⌘G**", "מוסכמת macOS"],
                    ["`Ctrl+F2` החלפת סימנייה", "**⌘F2**", "F2 ו־⇧F2 עדיין קופצים בין סימונים"],
                    ["`Alt` + גרירה לעמודות", "**⌥ + גרירה**", "זהה"],
                    ["`Ctrl+Alt+Shift+↓` עורך עמודות", "**⌥⌘C**", "מוסכמת macOS"],
                ]
            ),
            .note("""
                מעדיף לא ללמוד מחדש? `הגדרות ▸ קיצורים ▸ השתמש בערכת Notepad++`.
                """),
            .heading("דברים שיש ב־Notepad++ ועובדים כאן אחרת"),
            .bullets([
                "**הפעלות** משחזרות את עצמן, כולל לשוניות שלא נשמרו — אין מה להפעיל.",
                "**לסימניות יש תשעה צבעים**, ושורה אחת יכולה לשאת כמה מהם בו־זמנית.",
                "**מפת המסמך** מתארת את *כל* הקובץ, לא רק את החלק הנראה.",
                "**מאקרו** יכולים לרוץ \"עד סוף המסמך\" ו\"על כל הלשוניות\", וכל הרצה היא צעד ביטול אחד.",
            ]),
            .heading("דברים ש־GEditor מוסיף"),
            .bullets([
                "**שולחן ניקוי נתונים** ו**פרופילי נתונים** לקובצי CSV.",
                "**שאילתות SQL** ישירות על קובץ CSV.",
                "**קידודי ווייטנאמית ישנים** — TCVN3, VISCII, VNI-Windows: קריאה, כתיבה וזיהוי אוטומטי.",
                "**חיפוש שאינו רגיש לניקוד** בכל תיבת סינון.",
                "**דוחות `.greport.md`** עם טבלאות ותרשימים שרצים מחדש.",
                "**כלי שורת הפקודה `geditor`** בגרסת ההורדה הישירה.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "בעיות נפוצות",
        summary: "שישה מצבים שגורמים לאנשים לחשוב שהיישום שבור.",
        keywords: ["שגיאה", "בעיה", "לא עובד", "שבור", "למה"],
        blocks: [
            .table(
                headers: ["מה אתה רואה", "הסיבה הרגילה"],
                rows: [
                    ["טקסט ווייטנאמי נראה ג'יבריש", "קידוד שגוי — לחץ על הקידוד בשורת המצב"],
                    ["חיפוש טקסט מנוקד אינו מוצא כלום", "הקובץ ביוניקוד מפורק — הרץ `נרמול יוניקוד` ל־NFC"],
                    ["פריט תפריט מעומעם", "גרסת App Store אינה יכולה להריץ את הפקודה — הפריט מסביר למה"],
                    ["התאמת סוגריים מסרבת לרוץ", "המסמך גדול מ־1 מ\"ב — הדגשת הזוג הלא נכון גרועה מכלום"],
                    ["בעמודה שבשורת המצב יש `~`", "המסמך גדול מ־200 ק\"ב, ולכן זו ספירת בתים ולא עמודה חזותית"],
                    ["שאילתת SQL אומרת שיש לשמור קודם את הקובץ", "DuckDB קורא **קבצים**, לא את המאגר שאתה עורך"],
                ]
            ),
            .heading("כש־GEditor יוצא באופן בלתי צפוי"),
            .paragraph("""
                בהפעלה הבאה כרזה אומרת זאת, עם כפתור **פתח דוח** — הדוח נפתח כלשונית שאפשר לקרוא ולהעתיק \
                ממנה כמו מכל קובץ טקסט אחר.
                """),
            .bullets([
                "הדוח נושא רק את **הגרסה, מהדורת macOS, ארכיטקטורת המכונה, שם האות ומחסנית הקריאות**.",
                "**אין תוכן מסמכים, וגם לא נתיבי קבצים** — נתיב כמו `~/Desktop/משכורת-דצמבר.xlsx` כבר חשף שלושה דברים פרטיים לפני שמישהו פתח אותו.",
                "**שום דבר אינו נשלח לשום מקום.** אין העלאה אוטומטית ואין שרת שיקבל אותה; הקובץ נשאר ב־`~/Library/Application Support/GEditor/crash/` עד שתפתח אותו או תמחק אותו.",
                "ברגע שפתחת את הדוח, ההפעלה הבאה אינה מזכירה אותו שוב.",
            ]),
            .heading("איפה לחפש הלאה"),
            .bullets([
                "שורת המצב מציגה קידוד, סופי שורה, שפה ומצב גלישה — כל מקטע ניתן ללחיצה.",
                "אפשר לערוך את `settings.json` ידנית כשחלון ההגדרות אינו מספיק.",
                "`אודות GEditor` נותן את הגרסה ואת סוג הבנייה, שדוח תקלה זקוק להם.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
