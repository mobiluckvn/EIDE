import Foundation

/// Türkçe yardım kitabı — 5. bölüm: raporlar, bilgi paketi, otomasyon ve uygulamanın kendisi.
extension HelpTR {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Raporlar ve diyagramlar",
        summary: "Rakamları yeniden çalışan bir HTML raporu üreten bir metin dosyası, artı Mermaid diyagramları.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md` raporları",
        summary: "Markdown artı dört çalıştırılabilir blok türü — solda yazın, sağda önizleyin.",
        keywords: ["rapor", "greport", "html", "dışa aktar", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Bir `.greport.md` dosyası, **sıradan Markdown** artı birkaç çalıştırılabilir çitli \
                bloktur. Çizilmesi, herkesin açabileceği **kendi kendine yeten** bir HTML dosyası üretir \
                — ağ yok, yanında dosya yok.
                """),
            .paragraph("""
                Düz metin olduğu için **karşılaştırılabilir, işlenebilir ve paylaşılabilir** — temizleme \
                tarifleri ve kalite kural kümeleriyle aynı yaklaşım.
                """),
            .code(
                language: "markdown",
                caption: "sales-2026-08.greport.md — eksiksiz bir rapor",
                source: """
                    ---
                    title: Ağustos satış raporu
                    source: sales-2026-08.csv
                    ---

                    # Ağustos satış raporu

                    31 Ağustos 2026 itibarıyla rakamlar.

                    ## İllere göre gelir

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: İllere göre gelir
                    y_label: Gelir
                    number_format: vi
                    suffix: " ₫"
                    source: Kaynak — sales-2026-08.csv
                    ```

                    ## Kaynak verinin kalitesi

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """
            ),
            .heading("Blok türleri"),
            .table(
                headers: ["Blok", "Üretir"],
                rows: [
                    ["`query`", "Bir DuckDB SQL deyiminden bir tablo"],
                    ["`chart`", "Bir grafik"],
                    ["`quality`", "Bir veri kalitesi karnesi"],
                    ["`mining`", "Bir grup madenciliği sıralama tablosu"],
                    ["`mermaid`", "Bir diyagram"],
                ]
            ),
            .heading("Ön bilgi"),
            .paragraph("""
                Baştaki `---` bloğu `title` ve `source`'u bildirir — `source`, kendi kaynağını \
                belirtmeyen her blok için öntanımlı veri kaynağıdır.
                """),
            .note("""
                Önizleme siz yazmayı bıraktığınızda yeniden kurulur, ama yalnızca **ayrıştırır**; her tuş \
                vuruşunda sorgu çalıştırmaz. Belge hataları ve veri hataları ayrı bildirilir — *\"chart \
                bloğunda `kind` anahtarı eksik\"* bir dosya hatasıdır, *\"`doanh_thu` sütunu yok\"* bir \
                veri hatasıdır.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "`query` bloğu",
        summary: "Tek bir DuckDB deyimi, raporda tek bir tabloya dönüşür.",
        keywords: ["sorgu", "sql", "tablo", "rapor", "blok"],
        blocks: [
            .paragraph("""
                Bloğun içeriği, raporun kaynağı üzerinde çalıştırılan **tek bir SQL deyimidir**. Tablonun \
                adı `t`'dir ve sorgu panelindeki lehçenin aynısı geçerlidir.
                """),
            .code(
                language: "text",
                caption: "Parametreli bir sorgu bloğu",
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
                `:thang` bir **parametredir**. Çizim sırasında verilir — kabuktan `--param thang=8` ile ya \
                da toplu rapor üretirken bir liste dosyasından.
                """),
            .note("""
                Bir veri raporundaki tablolar elle yazılmak yerine **bir query bloğundan gelmelidir**. \
                Elle yazılmış bir tablo, rakamlar değiştiğinde yeniden çalışmaz ve er geç raporun geri \
                kalanıyla çelişir.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "`chart` bloğu",
        summary: "YAML yapılandırması bir grafiğe dönüşür — ve biçimin en önemli kuralı.",
        keywords: ["grafik", "yaml", "rapor", "çizim"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Bir chart bloğunun her anahtarı",
                source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: İllere göre gelir
                    x_label: İl
                    y_label: Gelir
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Kaynak — sales.csv, 26 Ağu 2026 itibarıyla
                    """
            ),
            .heading("`query` yoksa HEMEN ÜSTÜNDEKİ query bloğunun sonucunu kullanır"),
            .paragraph("""
                Bu, biçimin en önemli kuralıdır. Onun sayesinde yaygın \"bir tablo, sonra o tablonun \
                grafiği\" raporu SQL'i yinelemez — ve yinelemek, iki kopyanın er geç birbirinden \
                ayrılması demektir; o noktada tablo ile grafik aynı sayfada farklı şeyler söyler.
                """),
            .warning("""
                Karşılığında **blok sırası önemlidir**: araya bir query bloğu eklemek, altındaki grafiğin \
                verisini değiştirir.
                """),
            .heading("`source` neden kendi anahtarı"),
            .paragraph("""
                Grafiğin altına düzyazıyla yazılmış bir kaynak notu gayet iyi görünür — ekranda. Ama \
                grafik PNG olarak dışa aktarılıp başka bir yere yapıştırılacaktır ve düzyazı geride \
                kalır. Bir anahtar olarak ise **görüntünün içine** çizilir ve onunla yolculuk eder.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "`quality` bloğu",
        summary: "Rapor içinde bir veri kalitesi karnesi.",
        keywords: ["kalite", "karne", "rapor", "blok"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Bir quality bloğunun her anahtarı",
                source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # boş bırakmak raporun kendi kaynağı demektir
                    title: Ağustos satış verisi kalitesi
                    rules: true                 # geçti/kaldı kural tablosunu göster
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # "Güncellik" için başvuru tarihini sabitle
                    fail_under: 90              # bunun altında kart uyarı rengine döner
                    """
            ),
            .table(
                headers: ["`chart`", "Çizer"],
                rows: [
                    ["`violations`", "**Kalan** kurallar için satır sayıları — \"önce neyi düzeltmeli\" sorusunu yanıtlar"],
                    ["`dimensions`", "Altı boyutun puanları"],
                    ["`none`", "Yalnızca tablo, grafik yok"],
                ]
            ),
            .note("""
                Dönemsel bir raporda `now:` belirleyin. O olmadan *Güncellik*, çizim anıyla karşılaştırır; \
                dolayısıyla geçen ayın raporunu yeniden çizmek yayımladığınızdan farklı bir puan üretir.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "`mining` bloğu",
        summary: "Grupları aykırılıklara, öngörü hatasına ya da ilinti ayrışmasına göre sıralayın.",
        keywords: ["madencilik", "rapor", "grup sıralaması"],
        blocks: [
            .code(
                language: "yaml",
                caption: "Bir mining bloğunun her anahtarı",
                source: """
                    group_by: tinh
                    value: doanh_thu          # aykırılık ve öngörü için sütun
                    pair: chi_phi             # grup başına ilinti için ikinci sütun
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # boş bırakmak raporun kendi kaynağı demektir
                    title: İllere göre madencilik
                    chart: true
                    """
            ),
            .table(
                headers: ["`rank`", "Neye göre sıralar"],
                rows: [
                    ["`anomalies`", "En çok aykırı satırı olan grup"],
                    ["`forecast_error`", "Öngörüsü en kötü olan grup"],
                    ["`correlation_gap`", "İlintisi birleştirilmiş tablodan en çok ayrılan grup — Simpson paradoksunu yakalar"],
                ]
            ),
            .warning("""
                **Hiçbir anahtar \"Yöntem\" bloğunu kapatmaz.** Yöntemi olmayan bir grup sıralaması, \
                okuyucuya \"en çok aykırılık\"ın hangi çite göre ölçüldüğünü bilme olanağı bırakmaz. Onu \
                gizlemek isteyen, istediği yanıtı zaten biliyordur.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Toplu rapor üretmek",
        summary: "Tek şablon, tek parametre listesi, çok sayıda rapor.",
        keywords: ["toplu", "çok rapor", "parametreler", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Tek bir rapor şablonu, her şube ya da her ay için çalıştırılır. Parametre listesi bir CSV \
                ya da JSON dosyasıdır — **rapor başına bir satır**.
                """),
            .code(
                language: "text",
                caption: "list.csv — rapor başına bir satır",
                source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """
            ),
            .code(
                language: "bash",
                caption: "Bütün yığını kabuktan çiz",
                source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """
            ),
            .code(
                language: "bash",
                caption: "Ya da parametreleri elle verilen tek bir rapor",
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
        title: "Mermaid diyagramları",
        summary: "Diyagramları metinle çizin, komutlarla düzenleyin, iki yönde eşzamanlı önizleyin.",
        keywords: ["mermaid", "diyagram", "akış şeması", "sıra", "çiz"],
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
                Mermaid diyagramları **metinden** çizer: siz bir betimleme yazarsınız, makine çizer. \
                Dolayısıyla bir diyagram karşılaştırılabilir ve işlenebilir — bir görüntü dosyasının \
                yapamayacağı bir şey.
                """),
            .paragraph("""
                Düzenleyicinin yanında bir görünüm için `Mermaid diyagramı: önizle` açın. İkisi **iki \
                yönde de eşzamanlıdır**: resimde bir ögeyi seçin, imleç onun satırına atlar.
                """),
            .heading("Yeniden yazarak değil, komutlarla düzenleyin"),
            .table(
                headers: ["Komut", "Ne yapar"],
                rows: [
                    ["Şablon ekle…", "Her diyagram türü için hazır bir iskelet ekler"],
                    ["Öge ekle…", "Bir düğüm ya da katılımcı ekler"],
                    ["Seçili iki ögeyi bağla", "Aralarına bir ok çizer"],
                    ["Seçili ögenin etiketini düzenle…", "Satırı aramadan metni değiştirir"],
                    ["Seçili ögeyi sil", "Düğümü **ve** ona değen her kenarı kaldırır"],
                    ["İletiyi yukarı / aşağı taşı", "Bir sıra diyagramındaki adımları yeniden sıralar"],
                    ["Yeniden biçimlendir", "Tüm bloğu girintiler ve hizalar"],
                ]
            ),
            .heading("Bir dosyaya ayırmak ve geri gömmek"),
            .paragraph("""
                Büyük diyagramların yeri kendi `.mmd` dosyasıdır: `Bloğu bir .mmd dosyasına ayır…` onu \
                dışarı taşır ve geride bir başvuru bırakır. Tek bir dosya göndermeniz gerektiğinde \
                `Başvurulan dosyayı geri göm` bunun tersini yapar.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Yaygın Mermaid sözdizimi",
        summary: "En çok kullanılan dört diyagram türü, her biri çalışan bir şablonla.",
        keywords: ["mermaid", "sözdizimi", "akış şeması", "sıra", "gantt", "sınıf", "şablon"],
        blocks: [
            .code(
                language: "mermaid",
                caption: "Akış şeması — bir sipariş onay süreci",
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
                caption: "Sıra diyagramı — bir ödeme akışı",
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
                caption: "Sınıf diyagramı — bir veri modeli",
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
                caption: "Gantt — bir yayım planı",
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
                headers: ["Düğüm biçimi", "Yazın"],
                rows: [
                    ["Dikdörtgen", "`A[Etiket]`"],
                    ["Yuvarlatılmış", "`A(Etiket)`"],
                    ["Stadyum", "`A([Etiket])`"],
                    ["Eşkenar dörtgen (karar)", "`A{Etiket}`"],
                    ["Silindir (veri)", "`A[(Etiket)]`"],
                ]
            ),
            .table(
                headers: ["Ok", "Yazın"],
                rows: [
                    ["Düz, uçlu", "`A --> B`"],
                    ["Noktalı", "`A -.-> B`"],
                    ["Kalın", "`A ==> B`"],
                    ["Etiketli", "`A -- etiket --> B`"],
                ]
            ),
            .note("""
                Bir akış şemasının yönü `flowchart`'ın hemen ardından gelir: `TD` yukarıdan aşağı, `LR` \
                soldan sağa; ayrıca `BT` ve `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Bilgi paketi

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Bilgi paketi",
        summary: "Parçalara ayırma, arama dizinleri, bilgi grafikleri, varlıklar ve erişim değerlendirmesi.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Bilgi paketi nedir",
        summary: "Belgeler üzerinde soru yanıtlama sistemi için veriyi hazırlama ve denetleme araçları.",
        keywords: ["rag", "bilgi", "parça", "gömme", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Bir belge derlemesinden soruları yanıtlayan bir sistem kurarken işin çoğu modelde değil, \
                **veriyi hazırlamaktadır**: belgeleri anlamlı parçalara kesmek, o parçaların kalitesini \
                denetlemek, bir dizin kurmak ve **erişimin gerçekten doğru şeyi bulup bulmadığını \
                ölçmek**.
                """),
            .paragraph("""
                Bu bölüm tam olarak bunun araç takımıdır. **Tümüyle sizin makinenizde** çalışır ve asla \
                bir ağa çıkmaz.
                """),
            .table(
                headers: ["Görev", "Araç"],
                rows: [
                    ["Belgeleri parçalara kesmek", "Parça önizlemesi"],
                    ["Parçaları incelemek ve puanlamak", "JSONL parça incelemesi"],
                    ["Veri biçimleri arasında dönüştürmek", "Bilgi dönüşümü"],
                    ["Bir ilişki grafiği kurmak ve incelemek", "Bilgi grafiği"],
                    ["Metinde özel adları bulmak", "Varlık imleme"],
                    ["Erişim kalitesini ölçmek", "Erişim laboratuvarı"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Bir JSONL derlemesini parçalara ayırmak ve incelemek",
        summary: "Parça sınırlarını metnin kendisi üzerinde önizleyin, sonra tüm derlemeyi puanlayın.",
        keywords: ["parça", "jsonl", "derlem", "örtüşme", "belirteç"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Parça önizlemesi"),
            .paragraph("""
                Bir metin ya da Markdown belgesi açın, bir strateji ve bir parça boyutu seçin. Sınırlar \
                **metnin kendisi üzerinde vurgulanır**; böylece bir kesiğin cümlenin ortasına ya da bir \
                tablonun içine düştüğünü, dışa aktarmadan önce görebilirsiniz.
                """),
            .bullets([
                "Örtüşmeli **sabit boyut**.",
                "**Yapıya göre** — Markdown başlıklarında, belgenin akışını bozmadan.",
                "**Paragrafa göre**, boyuta ulaşana dek birleştirerek.",
            ]),
            .heading("Var olan bir JSONL derlemesini incelemek"),
            .paragraph("""
                Zaten sahip olduğunuz bir derlem için (satır başına bir JSON parçası), `JSONL: parçaları \
                incele…` şunları yanıtlar: hangi satırlar geçersiz JSON, hangi parçalar çok kısa ya da \
                çok uzun, hangileri birbirini yineliyor ve hangileri cümlenin ortasından kesilmiş.
                """),
            .note("""
                Bir derlem, tablo verisiyle **aynı altı boyutlu çerçeveyle** de puanlanabilir — bir \
                raporun `quality` bloğundaki `corpus:` anahtarını kullanın.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Bilgi biçimlerini dönüştürmek",
        summary: "Parçalar JSONL · CSV · Markdown arasında, grafikler DOT · Mermaid · kenar listeleri arasında.",
        keywords: ["dönüştür", "jsonl", "dot", "mermaid", "kenar listesi"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Şundan", "Şuna"],
                rows: [
                    ["JSONL parçaları", "CSV · Markdown"],
                    ["CSV parçaları", "JSONL · Markdown"],
                    ["DOT grafiği", "Mermaid · kenar listesi"],
                    ["Kenar listesi", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Yeni sekme oluşturulmadan önce, CSV dönüşümündeki mekanizmanın aynısıyla **beş satırlık \
                bir önizleme** vardır.
                """),
            .paragraph("""
                `Üçlüleri/kenarları tablo olarak aç`, bir üçlü dosyasını ya da kenar listesini bir ızgara \
                olarak gösterir — onu başka herhangi bir CSV gibi süzün ve sıralayın.
                """),
            .note("""
                **Markdown → JSONL** yönü bu komutta yoktur: o yön parçalara ayırmanın *ta kendisidir* ve \
                komut sizi oraya yönlendirir. Tek bir kesmenin iki uygulaması, iki farklı sonuç üretirdi.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Bilgi grafikleri",
        summary: "Sözdizimini denetleyin, sağlığı puanlayın ve milyon kenarlı grafiklerde algoritma çalıştırın.",
        keywords: ["grafik", "dot", "cypher", "pagerank", "louvain", "sözdizimi denetimi"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor grafikleri **DOT**, **kenar listeleri** ve **üçlüler** olarak okur. `Grafik \
                sözdizimini denetle`, sözdizimi hatalarını, sarkan düğümleri ve var olmayan düğümleri \
                gösteren kenarları yakalar.
                """),
            .heading("Kullanılabilir algoritmalar"),
            .table(
                headers: ["Algoritma", "Neyi yanıtlar"],
                rows: [
                    ["k-adım komşuluğu", "Bu düğümle k adım içinde ne ilişkili"],
                    ["Bağlı bileşenler", "Grafiğin kaç ayrık parçası var"],
                    ["PageRank", "Hangi düğümler önemli"],
                    ["Louvain", "Grafik topluluklara nasıl ayrılıyor"],
                ]
            ),
            .paragraph("""
                **Milyon kenarlı** bir grafikte dördü de birkaç milisaniye ile yaklaşık bir saniye \
                arasında çalışır.
                """),
            .note("""
                Bir grafik, tablolar ve derlemler için kullanılan **altı boyutlu çerçeveyle** de \
                puanlanabilir — bir `quality` bloğundaki `graph:` anahtarını kullanın.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Bir listeden varlıkları imlemek",
        summary: "Özel adlardan bir liste yükleyin ve her geçtiği yeri bulun — Vietnamca için kurulmuş üç kuralla.",
        keywords: ["varlık", "özel ad", "ner", "imleme", "sözlük", "eşleştirme"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Bir adlar listesi (şirketler, ürünler, yerler) yükleyin; GEditor belgede geçtiği her yeri \
                bir sayım tablosuyla birlikte vurgular.
                """),
            .heading("Üçü de Vietnamca veriden gelen üç eşleştirme kuralı"),
            .bullets([
                "**En uzun eşleşme kazanır.** Listede hem `An Phát` hem `Công ty An Phát` varsa, daha uzun öbeği içeren bir cümle uzun olanla eşleşmelidir — yoksa ikiye bölünür ve iki varlık sayılır, bu da istatistikleri **şişirir**.",
                "**Sözcük sınırları zorunludur.** `An`, `Anh` ya da `Hoàn` içinde eşleşmemelidir. Vietnamca özel adlar kısadır ve sayısız sıradan sözcükle hece paylaşır.",
                "**Büyük/küçük harfe duyarsız, ama aksana DUYARLI.** `CÔNG TY` ile `Công ty` tektir; `má` ile `ma` değildir.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Varlık türevlerini çözümlemek",
        summary: "`Cty An Phát` ile `Công ty An Phát`'ı tek olarak tanıyın — kararı yine size bırakarak.",
        keywords: ["varlık çözümleme", "türevler", "ad normalleştirme", "yinelenenler"],
        blocks: [
            .paragraph("""
                Bir CSV ızgarasındaki **bulanık yinelenenlerle** aynı kümeleme — iki değil, tek bir ortak \
                uygulama.
                """),
            .paragraph("""
                Çıktı bir **öneridir**: her kümeyi gözden geçirir ve kanonik biçimi seçersiniz. \
                Hepsini-birleştir düğmesi yoktur; çünkü %92 benzeyen iki ad, iki gerçek kuruluş olabilir.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Erişim laboratuvarı",
        summary: "Yanıtlı bir soru kümesiyle dizinin doğru şeyi bulup bulmadığını ölçün.",
        keywords: ["erişim", "bm25", "anma", "mrr", "ndcg", "değerlendirme", "altın küme"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Bir **değerlendirme kümesi** yükleyin — her satırda bir soru ve dönmesi gereken parça \
                kimlikleri — sonra tüm yığını dizine karşı çalıştırın.
                """),
            .table(
                headers: ["Ölçüt", "Neyi yanıtlar"],
                rows: [
                    ["recall@k", "Yanıt kümesinin ne kadarı ilk k'de görünüyor"],
                    ["MRR", "İlk doğru sonuç ne kadar aşağıda"],
                    ["nDCG@k", "Sıralama iyi mi, konum dahil"],
                ]
            ),
            .paragraph("""
                Sonuçlar **soru başına** da gelir, en kötüsü başta — bu, derlemde düzeltilecek şeylerin \
                listenizdir; üstelik düzeltmeye en değer olandan başlayarak.
                """),
            .warning("""
                Üç ölçütün de üçü **ortalamadır** ve bir ortalama çok şey gizler. \"Dizin yeterince iyi\" \
                sonucuna varmadan önce her zaman soru başına tabloyu okuyun.
                """),
            .paragraph("""
                İki yapılandırma yan yana karşılaştırılabilir ve sonuç doğrudan bir `.greport.md` \
                raporuna düşer; böylece bir sonraki çalıştırma birebir aynı olur.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makrolar ve otomasyon

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makrolar ve otomasyon",
        summary: "Eylemleri kaydedin, toplu çalıştırın, betik yazın ve kabuktan yönetin.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Makro kaydetmek ve oynatmak",
        summary: "Bir diziyi kaydedin ve yineleyin — bütün çalıştırma tek bir geri alma adımıdır.",
        keywords: ["makro", "kayıt", "oynatma", "yinele", "otomatikleştir"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Kaydı başlat / durdur"),
                HelpShortcut("⌃P", "Oynat"),
            ]),
            .steps([
                "`⌃R` kaydı başlatır.",
                "Yinelenmesini istediğiniz şeyi yapın — yazın, imleci taşıyın, bulun, değiştirin.",
                "Durdurmak için yeniden `⌃R`.",
                "`⌃P` oynatır; `Makro ▸ Belgenin sonuna kadar oynat` ise sona kadar çalıştırır.",
                "`Makro ▸ Makroyu kaydet…` ona sonraki oturumlar için bir ad verir.",
            ]),
            .heading("Ham tuş vuruşlarını değil, KOMUTLARI kaydeder"),
            .paragraph("""
                Bir makro, hangi tuşlara bastığınızı değil, **ne yaptığınızı** saklar. Bu onu klavye \
                düzeninden ve hangi giriş yönteminin etkin olduğundan bağımsız kılar; ayrıca açtığınızda \
                makro dosyasını **okunur** yapar.
                """),
            .heading("Bir makro ne zaman durur"),
            .table(
                headers: ["Neden", "Anlamı"],
                rows: [
                    ["Yineleme sayısı tükendi", "Olağan"],
                    ["Bir `find` adımı hiçbir şey bulamadı", "\"Dosyanın sonuna kadar oynat\" kendini böyle durdurur"],
                    ["Belgenin sonuna ulaşıldı", "Gidilecek başka yer yok"],
                    ["Siz iptal ettiniz", "`Makro ▸ Çalışan makroyu iptal et`"],
                    ["Bir yineleme hiçbir şeyi değiştirmedi ve hiçbir yere gitmedi", "Sonsuza dek dönmesin diye durduruldu"],
                ]
            ),
            .note("""
                Bütün çalıştırma — on bin yineleme bile olsa — **tek** bir geri alma adımıdır.
                """),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Bir makroyu toplu çalıştırmak",
        summary: "Açık her sekmede ya da açılmamış dosyalardan oluşan bir klasörde.",
        keywords: ["toplu", "tüm sekmeler", "klasör", "makro", "maske"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Komut", "Kapsam", "Geri alınır"],
                rows: [
                    ["Tüm sekmelerde çalıştır", "Açık sekmeler", "Evet — sekme başına bir geri alma adımı"],
                    ["Bir klasörde çalıştır…", "Diskte **açık olmayan** dosyalar", "Hayır"],
                ]
            ),
            .warning("""
                Bir klasörde çalıştırmak hiçbir sekmede açık olmayan dosyalara dokunur; dolayısıyla \
                **geri alma yoktur**. Öntanımlı olarak GEditor asılların üzerine yazmak yerine **yeni \
                dosyalar yazar**. Bir yedeğiniz ya da sürüm denetimli bir deponuz yoksa bu öntanımlıya \
                bağlı kalın.
                """),
            .heading("Dosyaları maskeyle süzmek"),
            .paragraph("""
                Klasör seçicide bir **dosya adı süzgeci** vardır: `*.csv;*.log` yazın, makro yalnızca \
                onlara dokunur. `Bir klasörün tamamında bul`un kullandığı maske sözdiziminin aynısıdır ve \
                birkaç örüntü `;` ya da `,` ile ayrılır.
                """),
            .bullets([
                "**Boş** bırakın, GEditor'un okuyabildiği her metin dosyasını alır — önceki davranış.",
                "Maske o uzantı listesini daha da daraltmak yerine **onun yerine geçer**: `*.bak` yazın; o uzantı metin listesinde olmasa bile `.bak` dosyalarında çalışır.",
                "Hiçbir şey eşleşmezse ileti, boş klasörü suçlamak yerine **maskeyi size geri okur**.",
            ]),
            .paragraph("""
                Bu kutunun çok pratik bir nedeni var: bir klasörde 400 `.json` ve 12 `.log` dosyası var ve \
                makronuz yalnızca günlükleri düzeltiyor. Maske olmadan öteki 400'ü de işlenir — ve toplu \
                iş yeni dosyalar yazdığı için bir yanlış, geride 400 parça çöp bırakır.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Makro dosyası sözdizimi",
        summary: "Yedi adım türü, eksiksiz JSON biçimi ve çalışan iki makro.",
        keywords: ["makro", "json", "sözdizimi", "biçim", "elle düzenleme", "paylaş"],
        blocks: [
            .paragraph("""
                Her makro, GEditor'un `macros/` klasöründe **kendi JSON dosyasıdır**. Bozulma tek bir \
                makroyla sınırlı kalır ve bir makroyu bir iş arkadaşınızla paylaşmak, tek bir dosya \
                göndermek demektir.
                """),
            .code(
                language: "text",
                caption: "Dosyaların bulunduğu yer",
                source: """
                    ~/Library/Application Support/GEditor/macros/<makro-adı>.json
                    """
            ),
            .heading("Yedi adım türü"),
            .table(
                headers: ["Adım", "Yazılışı", "Anlamı"],
                rows: [
                    ["Metin ekle", "`{\"insert\": {\"_0\": \"metin\"}}`", "İmleçte yazar; seçim varsa onun yerine geçer"],
                    ["Geri sil", "`{\"deleteBackward\": {}}`", "Delete tuşu gibi"],
                    ["İleri sil", "`{\"deleteForward\": {}}`", "⌦ gibi"],
                    ["Taşı", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Aşağıdaki yön listesine bakın"],
                    ["Satırı seç", "`{\"selectLine\": {}}`", "Satır sonu hariç"],
                    ["Bul", "`{\"find\": { … }}`", "Sonraki eşleşmeyi bul ve **seç**"],
                    ["Seçimi değiştir", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "Önceki adım regex `find` ise `$1` çalışır"],
                ]
            ),
            .heading("Hareket yönleri"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Tam `find` adımı"),
            .code(
                language: "json",
                caption: "Bir find adımının dört anahtarı",
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
            .paragraph("`mode`, `normal`, `extended` ya da `regex` alır — arama kutusundaki üç kipin aynısı."),
            .heading("Örnek 1 — her satırın başındaki il kodunu büyüt"),
            .code(
                language: "json",
                caption: "macros/uppercase-province.json",
                source: """
                    {
                      "name": "İl kodunu büyüt",
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
                `Makro ▸ Belgenin sonuna kadar oynat` ile çalıştırın: `find` adımının artık bir şey \
                bulamaması tam olarak durma koşuludur.
                """),
            .heading("Örnek 2 — TODO içeren her satırın ardındaki satırı sil"),
            .code(
                language: "json",
                caption: "macros/delete-line-after-todo.json",
                source: """
                    {
                      "name": "TODO'dan sonraki satırı sil",
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
                Elle düzenlenmiş bir makroyu önce bir kopyada sınayın. Yanlış yazılmış bir `find` adımı \
                makroyu hemen durdurur — bu iyicil durumdur. Kötücül durum, sandığınızdan geniş eşleşen \
                ve tek bir geri alma adımı içinde binlerce yeri düzenleyen bir örüntüdür.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript betikleri",
        summary: "Dört işlev, bir `.js` dosyası ve yaptığı her şey tek bir geri alma adımı.",
        keywords: ["betik", "javascript", "js", "otomatikleştir", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                GEditor'un `scripts/` klasörüne bir `.js` dosyası koyun ve `Makro ▸ Betik…` ile \
                çalıştırın. Bir betik tam olarak **dört** şey görür:
                """),
            .table(
                headers: ["Çağrı", "Anlamı"],
                rows: [
                    ["`doc.text`", "Belgenin tüm metni"],
                    ["`doc.selection`", "Seçim (hiçbir şey seçili değilse boş dize)"],
                    ["`doc.replace(s)`", "**Belgenin tamamını** `s` ile değiştir — tek geri alma adımı"],
                    ["`doc.log(s)`", "Sonuç paneline bir satır yaz"],
                ]
            ),
            .code(
                language: "javascript",
                caption: "scripts/number-lines.js",
                source: """
                    // Her satırı numarala.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numaralanan satır: " + (lines.length - 1));
                    doc.replace(out.join("\\n"));
                    """
            ),
            .code(
                language: "javascript",
                caption: "scripts/keep-three-columns.js — ilk üç CSV sütununu tut",
                source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("3 sütuna indirilen satır: " + out.length);
                    doc.replace(out.join("\\n"));
                    """
            ),
            .heading("Bilinmesi gereken üç sınır"),
            .bullets([
                "**Dosya erişimi yok, ağ yok, süreç başlatma yok.** API yüzeyi bilerek dardır: sonradan genişletmek kolaydır, daraltmak kullanıcıların yazdığı her betiği bozar.",
                "**Bu bir güvenlik sınırı değildir.** Betikler aynı süreçte çalışır. Okumadığınız bir betiği çalıştırmayın.",
                "**Beş saniyelik bir sınır vardır.** Ötesinde bir ileti alırsınız ve uygulama kullanılabilir kalır — ama o betiğin iş parçacığı **siz çıkana dek dönmeyi sürdürür** ve bir çekirdeği yer. İleti bunu söyler.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Dış bir komuttan geçirerek süzmek",
        summary: "Seçimi bir Unix komutundan geçirin ve sonucu geri alın.",
        keywords: ["süzgeç", "dış komut", "kabuk", "boru", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Seçim (ya da belgenin tamamı) bir komutun `stdin`'ine verilir ve o komutun `stdout`'u \
                onun yerine geçer.
                """),
            .code(
                language: "bash",
                caption: "Birkaç yaygın örnek",
                source: """
                    sort -u                     # sırala ve yinelenenleri at
                    jq .                        # JSON'u yeniden biçimlendir
                    tr 'a-z' 'A-Z'              # büyük harfe çevir
                    grep -v '^#'                # yorum satırlarını at
                    awk -F, '{print $3","$1}'   # sütun sırasını değiştir
                    """
            ),
            .note("""
                Sonuç **tek** bir geri alma adımıdır. Komut bir hata kodu döndürürse GEditor metne \
                dokunmaz ve `stderr`'i gösterir.
                """),
            .warning("""
                Bu komut **yalnızca doğrudan indirme sürümünde** vardır. App Sandbox uygulama dışında kod \
                çalıştırmayı yasakladığı için App Store sürümünde menü ögesi kalır ve neden \
                kullanılamadığını açıklar.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "`geditor` komut satırı aracı",
        summary: "Uygulamayı açmadan açın, temizleyin, sorgulayın, puanlayın ve rapor çizin.",
        keywords: ["cli", "komut satırı", "terminal", "geditor", "betik", "ci"],
        blocks: [
            .warning("""
                Yalnızca **doğrudan indirme sürümünde** kullanılabilir. App Store sürümü bir kum \
                havuzunda çalıştığı için dışarıdaki bir komut satırı süreci ona bağlanamaz.
                """),
            .heading("Dosya açma"),
            .code(
                language: "bash",
                caption: "Aç, bir konuma atla, bir borudan oku",
                source: """
                    geditor report.csv
                    geditor report.csv:120:5       # 120. satır, 5. sütun
                    geditor -w notes.md            # çıkmadan önce dosya kapanana dek bekle
                    geditor -r app.log             # salt okunur aç
                    git diff | geditor             # stdin'i yeni bir sekmeye oku
                    """
            ),
            .table(
                headers: ["Seçenek", "Anlamı"],
                rows: [
                    ["`-w`, `--wait`", "Çıkmadan önce dosya kapanana dek bekle — `git`'in düzenleyicisi olarak kullanmak için"],
                    ["`-n`, `--new-window`", "Yeni pencerede aç"],
                    ["`-r`, `--read-only`", "Salt okunur aç"],
                    ["`-i`, `--info`", "Kodlamayı, satır sonlarını ve satır sayısını yaz, sonra çık — uygulamayı **açmadan**"],
                    ["`-h`, `--help`", "Yardımı göster"],
                    ["`-v`, `--version`", "Sürümü göster"],
                ]
            ),
            .heading("Uygulamayı açmadan çalıştırmak"),
            .paragraph("""
                Aşağıdaki dört komut kümesi **tümüyle komut satırı sürecinde** çalışır; dolayısıyla \
                kimsenin grafik bir oturuma girmediği CI'da işe yararlar.
                """),
            .code(
                language: "bash",
                caption: "Bir tarifle temizleme",
                source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Sorgulama",
                source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Kalite kapısı — çıkış kodu 0 geçti · 1 kaldı · 2 hata",
                source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """
            ),
            .code(
                language: "bash",
                caption: "Rapor çizme",
                source: """
                    geditor --report template.greport.md --param-list list.csv --out ./reports/
                    """
            ),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript ve Servisler menüsü",
        summary: "Belgeyi AppleScript'ten okuyup yazın ya da başka bir uygulamadan GEditor'a metin gönderin.",
        keywords: ["applescript", "osascript", "servisler", "otomasyon", "shortcuts"],
        blocks: [
            .code(
                language: "applescript",
                caption: "Açık belgeyi oku",
                source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "İçeriğin üzerine yaz ve seçimi oku",
                source: """
                    tell application "GEditor"
                        set selected text to "seçimin yerine konacak metin"
                        set contents to document text
                        get document path
                    end tell
                    """
            ),
            .code(
                language: "applescript",
                caption: "Bir dosya aç",
                source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """
            ),
            .heading("Servisler menüsü"),
            .paragraph("""
                Herhangi bir uygulamada metin seçin, sonra `Servisler` menüsüyle onu yeni bir sekme \
                olarak GEditor'a gönderin.
                """),
            .note("""
                AppleScript'i ilk çalıştırdığınızda macOS Otomasyon izni ister. Bu, GEditor'un değil, \
                sistemin penceresidir.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Uzantı paketleri ve eklentiler",
        summary: "İki tür uzantı ve her birinin hangi sürümde çalıştığı.",
        keywords: ["eklenti", "uzantı", "paket", "yerel"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Uzantı paketleri"),
            .paragraph("""
                Bir paket; bir temayı, betikleri ve kullanıcı tanımlı dilleri bir arada toplayan **tek \
                bir JSON dosyasıdır**. Kurmak bir dosya kopyalar, kaldırmak bir dosya siler — ve paket \
                listesi yalan söyleyebilecek bir kayıt defterinden değil, **diskten** türetilir.
                """),
            .paragraph("**Her iki sürümde** de çalışır."),
            .heading("Yerel eklentiler"),
            .paragraph("""
                Önceden derlenmiş eklentiler, dar bir API yüzeyiyle **ayrı bir süreçte** çalışır — çöken \
                bir eklenti uygulamayı da beraberinde götürmez.
                """),
            .warning("""
                Yerel eklentiler **yalnızca doğrudan indirme sürümünde** vardır; çünkü App Sandbox \
                uygulama dışından kod yüklemeyi yasaklar. Her eklenti, çalışmadan önce karmasına göre \
                **bir kez elle onaylanmalıdır**.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Yapılandırma ve uygulama

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Yapılandırma ve uygulama",
        summary: "Ayarlar, kısayollar, temalar, güncellemeler, Notepad++'tan geçiş, sorun giderme.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Ayarlar",
        summary: "Her seçenek, başka bir Mac'e kopyalayabileceğiniz insan okunur tek bir JSON dosyasındadır.",
        keywords: ["ayarlar", "tercihler", "seçenekler", "yapılandırma", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Ayarları aç")]),
            .paragraph("""
                Tamam ya da İptal yoktur — bir değişiklik macOS geleneğine uygun olarak hemen etkinleşir \
                ve yazılır.
                """),
            .heading("Yapılandırma dosyası"),
            .code(
                language: "text",
                caption: "Bulunduğu yer",
                source: """
                    ~/Library/Application Support/GEditor/settings.json
                    """
            ),
            .paragraph("""
                **Okuyabildiğiniz ve elle düzenleyebildiğiniz, girintili bir JSON dosyasıdır.** Onu başka \
                bir Mac'e kopyalayın, bütün yapılandırmanız onunla gider. Ayarlardaki `Yapılandırma \
                dosyasını aç` düğmesi sizi doğrudan oraya götürür.
                """),
            .heading("Anahtarlar"),
            .table(
                headers: ["Anahtar", "Öntanımlı", "Anlamı"],
                rows: [
                    ["`fontSize`", "`13`", "Düzenleyici yazı tipi boyutu"],
                    ["`tabWidth`", "`4`", "Bir TAB kaç sütun genişliğinde"],
                    ["`usesTabsForIndent`", "`false`", "Boşluk yerine TAB ile girintile"],
                    ["`languageIndent`", "`{}`", "Dile göre girinti — boşluk sayfasına bakın"],
                    ["`smartIndent`", "`true`", "Yeni satırda otomatik girinti"],
                    ["`highlightAllMatches`", "`true`", "Her arama isabetini vurgula"],
                    ["`ligatures`", "`false`", "Bitişik harfler — tablonun altındaki nota bakın"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Kaydederken satır sonu boşluklarını kırp"],
                    ["`normalizeToNFCOnSave`", "`false`", "Kaydederken Unicode'u NFC'ye normalleştir"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Yeni dosyaların kodlaması"],
                    ["`defaultEOL`", "`\"lf\"`", "Yeni dosyaların satır sonları"],
                    ["`language`", "`\"system\"`", "Arayüz dili"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "öntanımlı tema", "Hangi renk teması kullanımda"],
                    ["`showWelcomeOnLaunch`", "`true`", "Açılışta karşılama penceresini aç"],
                    ["`keyBindings`", "`{}`", "Yalnızca öntanımlılardan değiştirdiğiniz tuşlar"],
                ]
            ),
            .note("""
                **Bitişik harfler neden KAPALI geliyor.** Bir bitişik harf `!=` ya da `->`'yi **tek** bir \
                glife birleştirir; böylece ekranda gördüğünüz karakterler artık dosyadaki karakterlerle \
                örtüşmez — üstelik Sütun Düzenleyici, sütun kipi ve sütunda kaydırma sütunla ölçer. \
                Düzyazı yazarken ya da bir programlama yazı tipini (Fira Code, JetBrains Mono) tam da \
                bitişik harfleri için seçtiyseniz açın.
                """),
            .heading("Komşu klasörler"),
            .table(
                headers: ["Klasör", "Ne tutar"],
                rows: [
                    ["`macros/`", "Kaydedilmiş makrolar, her biri bir JSON dosyası"],
                    ["`scripts/`", "JavaScript betikleri"],
                    ["`themes/`", "Renk temaları"],
                    ["`grammars/`", "Kullanıcı tanımlı diller"],
                ]
            ),
            .warning("""
                **Daha yeni** bir GEditor'un yazdığı bir yapılandırma dosyasının üzerine daha eskisi \
                **yazmaz** — öntanımlılarla çalışır ve bunu söyler. Üzerine yazmak, iki makineyi \
                eşitleyen birinin yapılandırmasını yok etmenin en kestirme yoludur ve o kişi bunun \
                nedenini asla öğrenemezdi.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Durum çubuğu",
        summary: "Altta on bölüm — her biri okunur ve her biri tıklanabilir.",
        keywords: ["durum çubuğu", "alt çubuk", "kayma", "konum",
                   "kodlama", "sekme", "salt okunur", "dosya boyutu"],
        blocks: [
            .paragraph("""
                Bu, diğer düzenleyicilerin durum çubuklarından en büyük farktır: **hiçbir bölüm salt \
                okunur değildir**. Yanlış bir değer görürseniz, menülerde dolaşmak yerine ona tıklamak \
                onu düzeltmenin yoludur.
                """),
            .table(
                headers: ["Bölüm", "Ne söyler", "Tıklamak"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "imleç konumu — sütun KARAKTER cinsinden, `@340` bayt konumu",
                     "`Git` kutusunu açar"],
                    ["`11 byte · 3 dòng`", "belge boyutu",
                     "bayt · karakter · sözcük · satır sayar"],
                    ["`🔒 Chỉ đọc`", "yalnızca belge kilitliyken görünür",
                     "NEDEN kilitli olduğunu söyler ve olanaklıysa kilidi açar"],
                    ["`View` / `Code`", "hangi görünümde olduğunuz", "geçiş yapar (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV kipi ve kullanımdaki ayırıcı",
                     "CSV kipini açar/kapatır ya da **ayırıcıyı yeniden seçer**"],
                    ["`Đang theo dõi`", "`tail -f` çalışıyor", "—"],
                    ["`UTF-8`", "kodlama", "yeniden yorumla ya da başka bir kodlamaya dönüştür"],
                    ["`LF`", "satır sonu biçemi", "LF · CRLF · CR arasında geçiş"],
                    ["`Python`", "sözdizimi renklendirme dili", "başkasını seç ya da uzantıya göreye dön"],
                    ["`Tab: 4`", "girinti genişliği", "2 · 4 · 8, genel olarak ya da **yalnızca bu dil için**"],
                    ["`Ngắt: tắt`", "yumuşak kaydırma kipi", "üç kip arasında döner"],
                ]
            ),
            .heading("İkinci bir bakışa değer üç bölüm"),
            .bullets([
                "**`@340` — bayt konumu.** Bu, üründeki diğer her aracın konuştuğu sayıdır: JSON ve XML hataları, `--doc-sweep` çıktısı, ikili görüntüleyici ve `Git @340` kutusu. Burada okuyun, orada yazın.",
                "**Sütundaki bir `~`**, sayının görsel sütun değil, BAYT saydığı anlamına gelir — yalnızca 200 KB'tan uzun satırlarda olur; orada karakter saymak her imleç hareketini yavaşlatırdı.",
                "**`CSV · …` ayırıcıyı yeniden seçmek için tıklanabilir.** Algılama yanlış olabilir ve olduğunda her sütun işlemi, bunu bildiren hiçbir şey olmadan kayar. Aksini söylemenin yolu budur — dosyayı yalnızca YENİDEN OKUR, tek bir bayt bile değiştirmez (dosyayı yeniden yazan `CSV ▸ Ayırıcıyı değiştir…`in tersine).",
            ]),
            .note("""
                Açık dosyaya uygulanmayan bir bölüm soluklaştırılmaz, **gizlenir**: `Salt okunur` yalnızca \
                belge gerçekten kilitliyken, `CSV · …` yalnızca CSV kipinde görünür.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Klavye kısayollarını değiştirmek",
        summary: "Tek tek tuşları değiştirin ya da Notepad++ tuş düzenini toptan benimseyin.",
        keywords: ["kısayol", "tuş ataması", "tuş düzeni", "hazır küme"],
        blocks: [
            .paragraph("""
                `Ayarlar…` içinde iki hızlı düğmeli bir Kısayollar bölümü vardır: **Notepad++ hazır \
                kümesini kullan** ve **Öntanımlılara dön**.
                """),
            .paragraph("""
                Yapılandırma dosyası yalnızca **öntanımlılardan değiştirdiğinizi** kaydeder. Böylece \
                GEditor yeni bir sürümde öntanımlı bir tuşu değiştirdiğinde, kimse size söylemeden eski \
                tuş düzeninde takılı kalmazsınız.
                """),
            .note("""
                İki komut bir kısayolu paylaşamaz. Paylaştıklarında AppKit sessizce yalnızca **ilk** menü \
                ögesini tetikler ve diğer komut bozuk görünür — bu yüzden GEditor'da bunu önleyen bir \
                denetim vardır.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Temalar, aydınlık ve karanlık",
        summary: "Sistemi izle, aydınlık ya da karanlık; ve bir tema, düzenleyebileceğiniz bir JSON dosyasıdır.",
        keywords: ["tema", "renkler", "karanlık kip", "aydınlık", "görünüm"],
        blocks: [
            .paragraph("""
                `Ayarlar…` `Sistemi izle`, `Aydınlık` ya da `Karanlık` seçer ve bir renk teması belirler.
                """),
            .paragraph("""
                Bir tema, `themes/` içinde bir JSON dosyasıdır. `Geçerli temayı dışa aktar` düğmesi, \
                kendinizinkine başlangıç noktası olsun diye bir tane yazar.
                """),
            .note("""
                Bir tema dosyasındaki yanlış yazılmış bir renk, siyaha değil, **öntanımlı temanın** \
                rengine geri döner. Siyah bir tasarım kararı gibi görünür ve kullanıcı sorunu başka bir \
                yerde arardı.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Güncellemeler, sürümler ve çıkış",
        summary: "Güncellemenin iki sürüm arasında nasıl ayrıldığı.",
        keywords: ["güncelleme", "sürüm", "hakkında", "çık"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Sürüm", "Şununla güncellenir"],
                rows: [
                    ["App Store", "Diğer her uygulama gibi App Store"],
                    ["Doğrudan indirme", "Uygulama içindeki `Güncellemeleri denetle…`"],
                ]
            ),
            .paragraph("""
                `GEditor Hakkında`, çalışan sürümü ve hangi yapı olduğunu gösterir — bir sorun \
                bildirirken işe yarar.
                """),
            .note("""
                App Store sürümünde `Güncellemeleri denetle…` **menüde kalır** ve kaybolmak yerine neden \
                geçerli olmadığını açıklar. Eksik bir menü ögesi destek sorusudur.
                """),
            .paragraph("""
                Çıkmak hiçbir işi kaybettirmez: oturum, bir dahaki açışınızda geri gelir.
                """),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Bu yardım penceresini kullanmak",
        summary: "Kitapta arayın, dilini değiştirin ve karşılama penceresini geri getirin.",
        keywords: ["yardım", "kılavuz", "arama", "karşılama", "dil"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Yardım penceresini aç")]),
            .bullets([
                "Sol üstteki arama kutusu **gövde metnine ve kod örneklerine** bakar — `fail_under` gibi çıplak bir ayar anahtarını yazmak doğru sayfaya götürür.",
                "**Aksansız** yazmak yine aksanlı metni bulur.",
                "`Geri` düğmesi önceki sayfaya döner.",
                "Her kod bloğundaki `Kopyala` düğmesi o bloğu kopyalar.",
            ]),
            .heading("Başka bir dilde okumak"),
            .paragraph("""
                Bu pencerenin sağ üstündeki açılır menü, uygulamanın arayüz dilinden bağımsız olarak \
                **kitabın dilini** seçer. Değiştirmek sizi **okuduğunuz sayfada** tutar — sayfa \
                kimlikleri tam da bu işlesin diye bilerek çevrilmez.
                """),
            .note("""
                Yalnızca gerçekten kitabı olan diller listelenir. Bir şeye geçip metni değiştirmeyen bir \
                menü girdisi, yalan söyleyen bir menü girdisi olurdu.
                """),
            .heading("Karşılama penceresini geri getirmek"),
            .paragraph("""
                **Bu pencereyi açılışta açma** kutusunu işaretlediyseniz, `Yardım ▸ Özellik turu` ile \
                yeniden açın — pencerenin altındaki onay kutusu yeniden belirir ve işareti \
                kaldırılabilir.
                """),
            .paragraph("""
                Ya da `settings.json` içinde `showWelcomeOnLaunch`'ı yeniden `true` yapın.
                """),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Notepad++'tan GEditor'a",
        summary: "Hangi tuşlar yer değiştirir, ne farklı çalışır ve ne eksiktir.",
        keywords: ["notepad++", "notepad", "geçiş", "windows", "kısayollar"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                macOS'ta birkaç tuş, yalnızca `Ctrl`'ün `⌘` olmasıyla kalmayıp **yer değiştirir**. \
                Karşılaştırma şöyle.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Neden"],
                rows: [
                    ["`Ctrl+D` Satırı çoğalt", "**⇧⌘D**", "Burada `⌘D`, her Mac düzenleyicisindeki gibi çoklu imleçtir"],
                    ["`Ctrl+L` Satırı sil", "**⌘K**", "macOS'ta `⌘L` \"satıra git\" demektir"],
                    ["`Ctrl+G` Satıra git", "**⌘L**", "Bu ikisi yer değiştirir"],
                    ["`Ctrl+Q` Yorum", "**⌘/**", "macOS geleneği"],
                    ["`Ctrl+Shift+↑/↓` Satır taşı", "**⌥↑ / ⌥↓**", "macOS'ta `⌃` Mission Control'e aittir"],
                    ["`F3` Sonrakini bul", "**⌘G**", "macOS geleneği"],
                    ["`Ctrl+F2` Yer imini değiştir", "**⌘F2**", "F2 ve ⇧F2 yine imler arasında atlar"],
                    ["Sütunlar için `Alt` + sürükleme", "**⌥ + sürükleme**", "Aynı"],
                    ["`Ctrl+Alt+Shift+↓` Column Editor", "**⌥⌘C**", "macOS geleneği"],
                ]
            ),
            .note("""
                Yeniden öğrenmemeyi mi yeğlersiniz? `Ayarlar ▸ Kısayollar ▸ Notepad++ hazır kümesini \
                kullan`.
                """),
            .heading("Notepad++'ta olup burada farklı çalışan şeyler"),
            .bullets([
                "**Oturumlar** kaydedilmemiş sekmeler dahil kendini geri yükler — açılacak bir şey yok.",
                "**Yer imlerinin dokuz rengi vardır** ve bir satır aynı anda birkaçını taşıyabilir.",
                "**Belge haritası** yalnızca görünen kısmı değil, dosyanın *tamamını* betimler.",
                "**Makrolar** \"belgenin sonuna kadar\" ve \"tüm sekmelerde\" oynatılabilir; bütün bir çalıştırma tek geri alma adımıdır.",
            ]),
            .heading("GEditor'un eklediği şeyler"),
            .bullets([
                "CSV dosyaları için bir **veri temizlik tezgâhı** ve **veri profilleri**.",
                "Doğrudan bir CSV dosyası üzerinde **SQL sorguları**.",
                "**Eski Vietnamca kodlamalar** — TCVN3, VISCII, VNI-Windows: okunur, yazılır ve kendiliğinden algılanır.",
                "Her süzme kutusunda **aksan duyarsız arama**.",
                "Yeniden çalışan tablo ve grafiklerle **`.greport.md` raporları**.",
                "Doğrudan indirme sürümünde **`geditor` komut satırı aracı**.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Sık karşılaşılan sorunlar",
        summary: "İnsanlara uygulamanın bozuk olduğunu düşündüren altı durum.",
        keywords: ["hata", "sorun", "çalışmıyor", "bozuk", "sorun giderme", "neden"],
        blocks: [
            .table(
                headers: ["Belirti", "Olağan nedeni"],
                rows: [
                    ["Vietnamca metin anlamsız görünüyor", "Yanlış kodlama — durum çubuğundaki kodlamaya tıklayın"],
                    ["Aksanlı metin araması hiçbir şey bulmuyor", "Dosya ayrışık Unicode'da — `Unicode normalleştir` ile NFC'ye çevirin"],
                    ["Bir menü ögesi soluk", "App Store sürümü o komutu çalıştıramaz — öge nedenini açıklar"],
                    ["Parantez eşleştirme çalışmayı reddediyor", "Belge 1 MB'ın üzerinde — yanlış çifti vurgulamak hiç vurgulamamaktan kötüdür"],
                    ["Durum çubuğundaki sütunda bir `~` var", "Belge 200 KB'ın üzerinde; dolayısıyla bu bir bayt sayımı, görsel sütun değil"],
                    ["Bir SQL sorgusu dosyanın önce kaydedilmesi gerektiğini söylüyor", "DuckDB düzenlediğiniz arabelleği değil, **dosyaları** okur"],
                ]
            ),
            .heading("GEditor beklenmedik biçimde kapandığında"),
            .paragraph("""
                Bir sonraki açılışta bir şerit bunu söyler ve bir **Raporu aç** düğmesi sunar — rapor, \
                başka herhangi bir metin dosyası gibi okuyup kopyalayabileceğiniz bir sekme olarak açılır.
                """),
            .bullets([
                "Rapor yalnızca **sürüm, macOS yayımı, makine mimarisi, sinyal adı ve çağrı yığınını** taşır.",
                "**Belge içeriği yok, dosya yolları da yok** — `~/Desktop/maas-aralik.xlsx` gibi bir yol, daha kimse açmadan üç özel şeyi ele vermiştir.",
                "**Hiçbir yere hiçbir şey gönderilmez.** Otomatik yükleme yoktur ve alacak bir sunucu da yoktur; dosya siz açana ya da silene dek `~/Library/Application Support/GEditor/crash/` içinde kalır.",
                "Raporu bir kez açtıktan sonra sonraki açılış ondan bir daha söz etmez.",
            ]),
            .heading("Sonra nereye bakmalı"),
            .bullets([
                "Durum çubuğu kodlamayı, satır sonlarını, dili ve kaydırma kipini gösterir — her bölüm tıklanabilir.",
                "Ayarlar penceresi yetmediğinde `settings.json` elle düzenlenebilir.",
                "`GEditor Hakkında`, bir hata bildiriminin gerektirdiği sürümü ve yapıyı verir.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
