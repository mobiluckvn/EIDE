import Foundation

/// Türkçe yardım kitabı — 4. bölüm: tablo verisi, veri temizleme ve veri madenciliği.
extension HelpTR {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Tablo verisi",
        summary: "CSV'yi ızgara olarak görün, süzün, sıralayın, yapıyı denetleyin, SQL ile sorgulayın, dönüştürün.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "CSV'yi ızgara olarak görüntülemek",
        summary: "Bir milyon satır yine akıcı kayar, başlıklar yerinde durur ve kaynak metne dokunulmaz.",
        keywords: ["csv", "ızgara", "tablo", "tsv", "excel", "sütunlar"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Izgara ile Metin arasında geçiş yap")]),
            .paragraph("""
                Izgara **sanallaştırılmıştır**: yalnızca görünür satırlar kurulur; böylece bir milyon \
                satırlık dosya yüz satırlık gibi kayar.
                """),
            .bullets([
                "Kaydırırken **başlık satırı yerinde durur** — 40.000. satırda bile dokuzuncu sütunun ne olduğunu bilirsiniz.",
                "Izgarada bir hücreyi düzenleyin; değişiklik doğrudan kaynak metne gider.",
                "Izgara ve Metin, iki kopya değil, **tek dosyanın iki görünümüdür**.",
                "**⌘C seçili satırı kopyalar**, hücreler TAB ile ayrılmış — doğrudan Excel'e ya da Numbers'a yapıştırın, her hücre doğru yere düşer. TAB ya da satır sonu içeren hücreler tırnaklanır; böylece hedef onları ikiye bölmez.",
            ]),
            .note("""
                Ayırıcı açılışta algılanır (virgül, noktalı virgül, TAB, dikey çizgi). Tahmin yanlışsa \
                `CSV ▸ Ayırıcıyı değiştir…` ile değiştirin.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Çok sayfalı çalışma kitapları",
        summary: "Bir `.xlsx`'in herhangi bir sayfasını açın; ⌘S görüntülediğiniz sayfaya geri yazar.",
        keywords: ["excel", "xlsx", "sayfa", "çalışma kitabı", "çoklu sayfa"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Bir `.xlsx` açın; GEditor **ilk sayfayı** CSV ızgarası olarak gösterir. `CSV ▸ Sayfa \
                seç…` dosyadaki her sayfayı listeler ve seçtiğinizi aynı sekmede açar.
                """),
            .heading("DOĞRU sayfaya geri yazmak"),
            .paragraph("""
                `⌘S` düzenlemelerinizi ilkine değil, **görüntülediğiniz sayfaya** yazar. Diğer sayfalara \
                tek bir bayt bile dokunulmaz.
                """),
            .note("""
                Sayfa konumuyla değil, **adıyla** hatırlanır. Böylece iki oturum arasında Excel'de \
                sayfaları yeniden sıralamak yazmayı yanlış yere yönlendirmez.
                """),
            .warning("""
                Açık sayfa, siz açtığınızdan beri Excel'de **yeniden adlandırıldıysa ya da silindiyse** \
                `⌘S` **yazmayı reddeder** ve bunu söyler. İlk sayfaya geri dönmek, bir sayfanın içeriğini \
                bir başkasının üzerine dökmek olurdu — dosya yine kaydedilir, yine açılır ve veriyi \
                yalnızca yanlış yerde tutardı.
                """),
            .heading("Kaydedilmemiş düzenlemelerle sayfa değiştirmek"),
            .paragraph("""
                Sayfa değiştirmek sekmenin tüm içeriğini değiştirir; dolayısıyla kaydedilmemiş bir şey \
                varsa GEditor **önce sorar**. Tüm belge takas edildiği için `⌘Z` onu geri getiremez.
                """),
            .heading("Excel'i ızgaraya indirmenin bedeli"),
            .paragraph("""
                Sağ çıkan şey **değerlerdir** — formül sonuçları dahil, tam olarak Excel'in gösterdiği \
                sayılar. Sağ çıkmayanlar: yazı tipleri, renkler, birleştirilmiş hücreler, gömülü \
                grafikler ve formüllerin kendisi.
                """),
            .paragraph("""
                Karşılığında o sayfa ürünün geri kalanını bütünüyle kazanır: süzme, sıralama, SQL \
                sorguları, temizlik tezgâhı, kalite puanlaması, madencilik, grafikler.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Izgarada süzme ve sıralama",
        summary: "Sütun başına bir süzme kutusu; sayısal karşılaştırmayı ve aksansız yazımı anlar.",
        keywords: ["süz", "sırala", "sütun", "ızgarada ara"],
        blocks: [
            .paragraph("Sıralamak için bir sütun başlığına tıklayın. Altındaki süzme kutusu şunları kabul eder:"),
            .table(
                headers: ["Süzmeye yazın", "Anlamı"],
                rows: [
                    ["`hue`", "`hue` içerir, **aksan duyarsız** — `Huế`'yi de bulur"],
                    ["`=Huế`", "Tam olarak `Huế` (yine aksan duyarsız)"],
                    ["`>100`", "100'den büyük"],
                    ["`>=100`", "100 ya da daha çok"],
                    ["`<0`", "0'dan küçük"],
                    ["`100..200`", "100 ile 200 arasında"],
                    ["boş", "Bu sütunda süzme yok"],
                ]
            ),
            .paragraph("""
                Birkaç sütunu süzmek bir **ve**'dir: bir satır hepsini karşılamalıdır. Sayısal \
                karşılaştırma, sayısal olmayan hücreleri sıfır saymak yerine atlar.
                """),
            .note("""
                Süzme bir **bakma biçimidir**, silme değil. Süzmeyi temizleyin, her satır geri gelir.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Tablo yapısını denetlemek",
        summary: "Yanlış sütun sayılı satırları ve yanlış türde hücreleri bulun — bunu önce yapın.",
        keywords: ["doğrula", "denetle", "sütun sayısı", "yanlış tür", "bozuk veri"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Birinin size gönderdiği bir dosyada her şeyden **önce** çalıştırılacak şey budur. İki \
                soruyu yanıtlar:
                """),
            .bullets([
                "**Hangi satırların sütun sayısı yanlış?** Genellikle tırnaklanmamış bir virgül içeren bir hücre — ve kendinden sonraki her satırı bozar.",
                "**Hangi hücrelerin türü sütununun geri kalanına benzemiyor?** Örneğin sayı sütununda oturan bir `n/a`.",
            ]),
            .paragraph("""
                Sonuçlar bir liste olarak belirir; o satıra atlamak için birine tıklayın.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Sütunları silmek",
        summary: "Bir ya da daha çok sütunu dosyadan tümüyle kaldırın.",
        keywords: ["sütun sil", "sütun kaldır"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Atılacak sütunları listeden seçin ve uygulayın. Dosyada kaç satır olursa olsun **tek** \
                geri alma adımıdır.
                """),
            .warning("""
                Süzmenin tersine bu, **gerçek dosyayı düzenler**. Sütunları yalnızca gizlemek için, \
                istediğiniz sütunları listeleyen bir SQL sorgusu kullanın.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "CSV'yi SQL ile sorgulamak",
        summary: "DuckDB'nin tam SQL'i, doğrudan açık dosya üzerinde — salt okunur.",
        keywords: ["sql", "sorgu", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Açık tablonun adı **`t`**'dir. Motor **DuckDB**'dir; dolayısıyla `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, pencere işlevleri ve alt sorgular çalışır.
                """),
            .code(
                language: "sql",
                caption: "İllere göre gelir, en büyükten başlayarak",
                source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """
            ),
            .code(
                language: "sql",
                caption: "Tarihe ve bir metin koşuluna göre süzme",
                source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """
            ),
            .code(
                language: "sql",
                caption: "Her ilin toplam içindeki payı — bir pencere işleviyle",
                source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """
            ),
            .code(
                language: "sql",
                caption: "Diskteki başka bir dosyayla birleştirme",
                source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """
            ),
            .heading("Salt okunur, ve bu sert bir güvencedir"),
            .bullets([
                "Veritabanı **bellekte** yaşar; kaynak dosya yalnızca okunur.",
                "Tam olarak **tek bir deyim** kabul edilir ve **`SELECT` olmak zorundadır**. Geri kalan her şey — DuckDB'nin diske yazmak için pekâlâ kullanabileceği `COPY … TO 'file'` dahil — herhangi bir veriye ulaşmadan engellenir.",
            ]),
            .warning("""
                DuckDB **dosyaları** okur, belleği değil. Belgede kaydedilmemiş düzenlemeler varsa \
                GEditor sorgulamadan önce geçici bir kopya yazmak zorundadır. Kaydedilmemiş \
                düzenlemeleri olan çok büyük bir dosyada, tek bir sorgu için sessizce yüzlerce megabaytı \
                diske yazmak yerine **durur ve bunu söyler**.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Özet tablolar ve hızlı grafikler",
        summary: "Doğrudan bir sorgu sonucundan özetleyin ve çizin.",
        keywords: ["özet tablo", "grafik", "çizim", "çapraz tablo", "toplama"],
        blocks: [
            .paragraph("""
                İkisi de **sorgu sonucu tablosundan** açılır: bir SQL deyimi çalıştırın, sonra paneldeki \
                Özet ya da Grafik düğmesini kullanın.
                """),
            .heading("Özet tablo"),
            .paragraph("""
                **Satır** sütununu, **sütun** sütununu, **değer** sütununu ve toplama işlevini (toplam, \
                sayım, ortalama, en küçük, en büyük) seçin — bir hesap tablosunun özet tablosu gibi.
                """),
            .heading("Grafikler"),
            .paragraph("""
                Çubuk, çizgi, pasta, dağılım. Sayılar Vietnamca ya da Avrupa biçiminde; grafik başka bir \
                yere yapıştırmak üzere PNG ya da SVG olarak dışa aktarılır.
                """),
            .note("""
                Her yeniden kurulumda **veriyle birlikte tazelenen** bir grafik mi istiyorsunuz? Bu, bir \
                `.greport.md` raporundaki `chart` bloğudur.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Bir tabloyu başka bir biçime dönüştürmek",
        summary: "TSV, JSON, XML, Markdown tabloları, SQL INSERT deyimleri — önizlemeli.",
        keywords: ["dönüştür", "dışa aktar", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Biçim", "Ne için yararlı"],
                rows: [
                    ["TSV", "Hücrelerdeki virgülleri dert etmeden bir hesap tablosuna yapıştırmak"],
                    ["JSON", "Bir API'yi, bir betiği ya da başka bir aracı beslemek"],
                    ["XML", "XML dayatan eski sistemler"],
                    ["Markdown tablosu", "Belgelendirmeye, bir README'ye, bir işe yapıştırmak"],
                    ["SQL INSERT deyimleri", "Bir veritabanına yüklemek"],
                ]
            ),
            .paragraph("""
                Pencere, yeni sekmeyi oluşturmadan önce **ilk beş satırı önizler** — beş satır; tablo \
                adını, tırnaklamayı ve hangi sütunların sayıya dönüştüğünü doğrulamaya yeter.
                """),
            .note("""
                Önizleme, gerçek çıktıyı üreten **işlevin aynısını** beş satırla sınırlı olarak çağırır. \
                Sonuçla çelişebilecek bir benzetim değildir.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Ayırıcıyı değiştirmek",
        summary: "Bir dosyayı virgül, noktalı virgül, TAB ve dikey çizgi arasında dönüştürün.",
        keywords: ["ayırıcı", "virgül", "noktalı virgül", "sekme", "avrupa csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Vietnamca ya da Avrupa Excel'inden dışa aktarılan dosyalar genellikle **noktalı virgül** \
                kullanır; çünkü orada virgül ondalık ayırıcıdır.
                """),
            .warning("""
                Ayırıcıyı değiştirmek **dosyanın tamamını yeniden yazar**. Yeni ayırıcıyı içeren hücreler \
                tırnaklanır — yoksa tablonun yapısı bozulur.
                """),
            .note("""
                **Algılama yanlışsa istediğiniz komut bu değildir.** Burada tam olarak kodlamadaki \
                «yeniden yorumla» / «dönüştür» ikilisi gibi iki ayrı iş vardır:

                • *Dosya gerçekten noktalı virgülle ayrılmış ve biz virgül sandık* — **durum \
                çubuğundaki** `CSV · …` bölümüne tıklayıp doğrusunu seçin. Dosyanın tek baytı bile \
                değişmez; yalnızca nasıl okunduğu değişir.

                • *Dosya gerçekten virgülle ayrılmış ve siz noktalı virgül istiyorsunuz* — bu sayfadaki \
                komutu kullanın. O, dosyayı yeniden yazar.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Veri temizleme

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Veri temizleme — bütün akış",
        summary: "Birinin gönderdiği ham dosyadan kullanılabilir bir tabloya ve her ay yeniden çalıştırabileceğiniz bir ölçüte.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Temizleme akışı, baştan sona",
        summary: "Bilinmeyen bir dosyadan güvenilir bir tabloya altı adım ve gelecek ay için bir ölçüt.",
        keywords: ["temizleme", "temizle", "akış", "normalleştir", "düzenli veri"],
        blocks: [
            .paragraph("""
                Veri temizleme **nadiren tek seferliktir**. İnsanlar her ay aynı rapor şablonunu alır ve \
                her ay aynı sütunların aynı biçimde normalleştirilmesi gerekir. Bu akış tam da bunun için \
                tasarlandı: bir kez elle yaparsınız, sonra tek bir komutla yeniden çalıştırırsınız.
                """),
            .heading("Altı adım"),
            .steps([
                "**Önce yapıya bakın.** `CSV ▸ Veriyi denetle` — hangi satırların sütun sayısı yanlış, hangi hücrelerin türü yanlış. Bu ilk gelir; çünkü hizası kaymış tek bir satır sonraki her istatistiği anlamsız kılar.",
                "**Veri profilini okuyun.** Sütun başına: kaç boş hücre, kaç ayrık değer, hangi tür, aykırılıklar nerede. Burada, hiçbir şeyi değiştirmeden önce dosyayı anlarsınız.",
                "**Temizlik tezgâhını açın** (`⇧⌘L`). Karışık tarih biçimlerini, Avrupa biçimiyle karışmış Vietnamca sayıları, başıboş boşlukları, eksik değerleri algılar. **Önce→sonra önizleyin**, sonra uygulayın.",
                "Bir ad ya da adres sütununda elle yazılmış türevler varsa **bulanık yinelenenleri ele alın**. Burada siz karar verirsiniz; makine yalnızca önerir.",
                "**Bunu bir tarif olarak kaydedin.** Az önce uyguladığınız sıra, adlandırılmış bir JSON dosyasına yazılır — o dosya, bu veriye ilişkin bilginizdir.",
                "**Bir kalite kural kümesi** `.gquality.yaml` yazın ve puanlayın. Bundan sonra gelecek ayın dosyası tariften geçer ve puanlanır; **CLI kapısı** başarısızlıkta sıfırdan farklı bir çıkış kodu döndürür.",
            ]),
            .heading("Bu sıra neden"),
            .bullets([
                "Yapı **profilden önce**: hizası kaymış bir tablodaki istatistikler başka bir sütuna ilişkin istatistiklerdir.",
                "Profil **temizlemeden önce**: doldurmaya mı atmaya mı karar vermeden önce `%2 boş` bilgisine ihtiyacınız var.",
                "Bulanık yinelenenler **normalleştirmeden sonra**: `CÔNG TY  A` ile `Công ty A` ancak boşluk ve harf durumu düzeldikten sonra kendilerini tek şey olarak gösterir.",
                "Tarif **kural kümesinden önce**: tarif düzeltir, kurallar yargılar — düzeltilmemiş bir tabloyu puanlamak, zaten beklediğiniz düşük bir sayı üretir yalnızca.",
            ]),
            .heading("İlk seferden sonra her ay tek komut"),
            .code(
                language: "bash",
                caption: "Temizle, sonra puanla; CI için bir çıkış kodu döndür",
                source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """
            ),
            .paragraph("""
                Çıkış kodu **0** geçti, **1** kaldı, **2** çalışma zamanı hatası demektir. \
                `--record-history`, geçmiş dosyasına bir satır ekler; böylece sonraki çalıştırma sapmayı \
                karşılaştırabilir.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Veri profili",
        summary: "Sütun başına bir betimleme: tür, boşluklar, ayrık değerler, dağılım.",
        keywords: ["profil", "sütun istatistiği", "boş", "ayrık"],
        blocks: [
            .paragraph("""
                Bir profil **betimler**; yargılamaz. *\"Bu sütun %2 boş\"* der; %2'nin kabul edilebilir \
                olup olmadığı kalite kural kümesine aittir.
                """),
            .table(
                headers: ["Ölçü", "Nasıl okunur"],
                rows: [
                    ["Tür", "Sütun adından değil, verinin kendisinden çıkarılır"],
                    ["Boş hücreler", "Eksik değerlerin sayısı ve oranı"],
                    ["Ayrık değerler", "1 sabit bir sütun demektir; satır sayısına eşitse anahtar sütun"],
                    ["En küçük · en büyük · ortalama", "Yalnızca sayısal sütunlar"],
                    ["En sık değerler", "Bir hata kodunu ya da aşırı kullanılmış bir öntanımlıyı hemen fark ettirir"],
                ]
            ),
            .warning("""
                Ayrık sayımın bir eşiği vardır. Ötesinde gösterilen sayı bir **alt sınırdır** ve profil, \
                bunu kesin sayımlara karıştırmak yerine **bir tahmin olduğunu söyler**.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Veri temizlik tezgâhı",
        summary: "Yedi normalleştirme; hep önizlemeli, hep tek geri alma adımı, asla tahmin yok.",
        keywords: ["temizle", "normalleştir", "tarihler", "sayılar", "kırp", "eksik doldur"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Temizlik tezgâhını aç")]),
            .table(
                headers: ["İşlem", "Ne yapar"],
                rows: [
                    ["Tarihleri normalleştir", "Sütundaki her tarih biçimini tek biçime getirir"],
                    ["Sayıları normalleştir", "Ondalık ayırıcı ile gruplama ayırıcısını düzene sokar"],
                    ["Boşlukları kırp", "İki uçtan kaldırır; istenirse içerideki dizileri de daraltır"],
                    ["Harf durumunu değiştir", "Sütunun büyük harf kullanımını tutarlı kılar"],
                    ["Sabit bir değerle doldur", "Boş hücreleri yazdığınız bir değerle değiştirir"],
                    ["Komşudan doldur", "Değeri üstteki ya da alttaki satırdan alır"],
                    ["Boş hücreli satırları sil", "Verisi eksik satırları atar"],
                ]
            ),
            .heading("Bütün tezgâhtan üç güvence"),
            .bullets([
                "**Her zaman önizlemeli.** Değişecek hücre sayısıyla birlikte bir önce→sonra tablosu.",
                "Bir milyon hücreye dokunsa bile tüm geçiş için **tek geri alma adımı**.",
                "**Sonrasında bir rapor**: kaç hücre değişti ve hangileri okunamadı.",
            ]),
            .heading("İlke: asla tahmin etme"),
            .paragraph("""
                Kesin olarak okunamayan bir hücre **imlenir ve olduğu gibi bırakılır**. Her iki geleneği \
                karıştıran bir sütundaki `03/04/2026`'yı düşünün — 3 Nisan mı, 4 Mart mı? GEditor sizin \
                yerinize seçmek yerine gün/ay sırasını size sorar.
                """),
            .warning("""
                Bir tarih sütununu yanlış normalleştirmek, **fark edilmesi neredeyse olanaksız** türden \
                bir bozulmadır: sayılar hâlâ doğru görünür, yalnızca başka bir tarihtir. Bu tezgâhın \
                çıkarım yapmaktansa reddetmeyi yeğlemesinin nedeni budur.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Bulanık yinelenenler",
        summary: "Aynı adın elle yazılmış türevlerini bulun — ve onları asla kendiliğinden birleştirmeyin.",
        keywords: ["bulanık", "yinelenen", "birleştir", "türevler", "yazım yanlışları"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — tek bir müşteriyi \
                yazmanın üç yolu. Sıradan yineleme kaldırma onları aynı görmez.
                """),
            .steps([
                "İncelenecek sütunu ve bir benzerlik eşiğini seçin.",
                "GEditor yakın değerleri **kümelere** ayırır ve karşılaştırma biçimini gösterir.",
                "**Her küme için** hangi değerin tutulacağını siz seçersiniz — ya da o kümeyi atlarsınız.",
                "Uygulayın. Tek geri alma adımı.",
            ]),
            .warning("""
                Bu araç **kendi başına asla birleştirmez** ve bir \"hepsini birleştir\" düğmesi yoktur. \
                %92 benzeyen iki dize bir yazım yanlışı olabilir ya da tek sözcükle ayrılan iki gerçekten \
                farklı şirket — makine bunu ayırt edemez.
                """),
            .paragraph("""
                İki kaydı yanlış birleştirmek **sessiz** bir veri kaybıdır: hiçbir hücre boşalmaz, hiçbir \
                satır kızarmaz; iki varlık öylece bire iner ve defterler denkleştirilene kadar kimse fark \
                etmez.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Temizleme tarifleri",
        summary: "Sırayı bir JSON dosyası olarak kaydedin ve gelecek ayın verisinde yeniden çalıştırın.",
        keywords: ["tarif", "yinele", "otomatikleştir", "aylık", "toplu"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Temizlikten sonra adımları bir **tarif** olarak kaydedin. Bu, verinin yanında \
                tutabileceğiniz, bir iş arkadaşınıza gönderebileceğiniz ve değişiklikleri izlensin diye \
                bir depoya işleyebileceğiniz, insanın okuyabildiği bir JSON dosyasıdır.
                """),
            .code(
                language: "json",
                caption: "sales-standard.json — kısaltılmış",
                source: """
                    {
                      "version": 1,
                      "name": "Satış raporu standartlaştırma",
                      "sourceFile": "sales-2026-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """
            ),
            .paragraph("""
                Her adım **kapatılabilir** (`enabled`); böylece tek bir tarif, birbirine çok benzeyen \
                birkaç dosya türüne hizmet edebilir.
                """),
            .heading("Yeniden çalıştırma"),
            .bullets([
                "Uygulamada: `CSV ▸ Temizleme tarifini çalıştır…`",
                "Kabuktan, bir klasörün tamamında: komut satırı sayfasına bakın.",
            ]),
            .code(
                language: "bash",
                caption: "Hiçbir şey yazmadan bir kuru çalıştırma — hiçbir dosyaya dokunulmaz",
                source: """
                    geditor --recipe sales-standard.json --dry-run sales-*.csv
                    """
            ),
            .note("""
                Öntanımlı olarak sonuç, aslının yanına yeni bir dosyaya yazılır (`sales-clean.csv`). \
                Aslının üzerine yazmak `--overwrite` ile açıkça istenmelidir.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Veri kalitesi puanlaması",
        summary: "Altı boyut, 0–100 arası tek bir puan ve yeniden hesaplayabilesiniz diye basılan her formül.",
        keywords: ["kalite", "puan", "dqr", "altı boyut"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Veri profilinden temelde bir noktada ayrılır: profil **betimler**, puan ise bir \
                `.gquality.yaml` dosyasında **bildirdiğiniz ölçüte göre yargılar**.
                """),
            .table(
                headers: ["Boyut", "Neyi ölçer"],
                rows: [
                    ["Tamlık", "`not_null` kurallarına göre dolu hücre oranı"],
                    ["Geçerlilik", "Geçen biçim, tür, aralık ve regex kurallarının oranı"],
                    ["Benzersizlik", "`uniqueness_key` içinde bildirdiğiniz anahtara göre"],
                    ["Tutarlılık", "Sütunlar arası ve dosyalar arası kurallar"],
                    ["Doğruluk (tahmini)", "Belirlediğiniz sayısal sütunlardaki aykırı değerler"],
                    ["Güncellik", "`freshness` eşiğine göre verinin ne kadar eski olduğu"],
                ]
            ),
            .heading("Puan hakkında üç güvence"),
            .bullets([
                "**Formül sonuçta basılır** — elle yeniden hesaplayabilirsiniz.",
                "**Belirlenimci**: aynı veri ve aynı kurallar aynı puanı verir. Yalnızca *Güncellik* ana bağlıdır; bu yüzden `now` bir **parametredir** ve sonuca kaydedilir.",
                "**Puanlanamayan bir boyut, gerekçesiyle boş bırakılır**, asla sessizce 100 verilmez.",
            ]),
            .warning("""
                O son güvence önemlidir. `uniqueness_key` bildirilmemiş bir tabloya \"benzersizlik\" için \
                100 vermek, yalan söyleyen bir puandır — üstelik gurur okşayan yönde yalan söyler ki \
                tehlikeli olan da budur.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "`.gquality.yaml` sözdizimi",
        summary: "Kural dosyasının her anahtarı ve çalışan eksiksiz bir kural kümesi.",
        keywords: ["gquality", "yaml", "kurallar", "sözdizimi", "veri ölçütü"],
        blocks: [
            .paragraph("""
                Dosya uygulamanın içinde değil, **verinin yanında** durur: bir veri ölçütünün \
                incelenebilir olması gerekir ve insanların ölçütlerle yaptığı şey incelemektir.
                """),
            .code(
                language: "yaml",
                caption: "sales-standard.yaml — eksiksiz bir kural kümesi",
                source: """
                    schemaVersion: 1

                    # Altı boyutun ağırlıkları. Eksik bir boyut 1 ağırlıktadır.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Bir satırı benzersiz kılan anahtar. O olmadan "Benzersizlik" boyutu
                    # PUANLANAMAZ — ve toplam, eksik olduğunu söyler.
                    uniqueness_key: [ma_don]

                    # "Doğruluk (tahmini)" içinde aykırı değer için incelenen sayısal sütunlar.
                    accuracy_columns: [doanh_thu, so_luong]

                    # "Güncellik" boyutu.
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Bu çalıştırma bir öncekine göre düştüğünde uyar.
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
                        max_null_pct: 2          # %2 boşluğa izin ver
                      # Sütunlar arası kural: `col` gerekmez
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Dosyalar arası kural: değer başka bir dosyada bulunmalı
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """
            ),
            .heading("Kural türleri"),
            .table(
                headers: ["Anahtar", "Anlamı", "Boyut"],
                rows: [
                    ["`not_null: true`", "Hücre dolu olmalı; `max_null_pct` bunu gevşetir", "Tamlık"],
                    ["`unique: true`", "Sütunda yinelenen değer yok", "Benzersizlik"],
                    ["`dtype: int\\|float\\|date\\|text`", "Doğru tür", "Geçerlilik"],
                    ["`range: { min:, max: }`", "Sayısal aralık içinde", "Geçerlilik"],
                    ["`length: { min:, max: }`", "Dize uzunluğu", "Geçerlilik"],
                    ["`regex: \"…\"`", "Bir düzenli ifadeyle eşleşir", "Geçerlilik"],
                    ["`in_set: [ … ]`", "Verilen bir listeden biri", "Geçerlilik"],
                    ["`date_format: \"…\"`", "Doğru tarih biçimi", "Geçerlilik"],
                    ["`compare: { a:, op:, b: }`", "İki sütunu karşılaştır; `op` şunlardır: `<` `<=` `=` `>=` `>` `<>`", "Tutarlılık"],
                    ["`foreign_key: { file:, column: }`", "Değer başka bir dosyada bulunmalı", "Tutarlılık"],
                    ["`severity: error\\|warn`", "Kuralın önem derecesi; öntanımlı `error`", "—"],
                ]
            ),
            .warning("""
                Bir kural anahtarını yanlış yazarsanız, o kural sessizce atlanmak yerine dosya **bir \
                iletiyle reddedilir**. Sessizce atlamak, verinin hiç çalışmamış bir kurala göre \
                denetlendiğine inanmanız demektir.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "CI'da bir kalite kapısı",
        summary: "Çıkış kodlarını kullanarak bozuk veriyi boru hattında durdurun.",
        keywords: ["ci", "kapı", "fail-under", "çıkış kodu", "otomasyon", "geçmiş", "sapma"],
        blocks: [
            .code(
                language: "bash",
                caption: "Puanla ve bir çıkış kodu döndür",
                source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """
            ),
            .table(
                headers: ["Seçenek", "Anlamı"],
                rows: [
                    ["`--quality <file.yaml>`", "Puanlamada kullanılacak kural kümesi"],
                    ["`--fail-under <0…100>`", "Bu puanın altı KALDI'dır"],
                    ["`--json <file\\|->`", "Makine okunur sonuç; `-` stdout'a yazar"],
                    ["`--record-history`", "`sales-standard.history.jsonl` dosyasına bir satır ekler"],
                    ["`--now <YYYY-MM-DD>`", "*Güncellik* için başvuru tarihini sabitler"],
                    ["`--recipe <file.json>`", "Puanlamadan önce **bellekte** temizler, dosya yazmaz"],
                ]
            ),
            .table(
                headers: ["Çıkış kodu", "Anlamı"],
                rows: [["`0`", "Geçti"], ["`1`", "Kaldı"], ["`2`", "Çalışma zamanı hatası"]]
            ),
            .heading("CI neden `--now` geçmeli"),
            .paragraph("""
                O olmadan *Güncellik*, veriyi çalıştırma anıyla karşılaştırır — böylece aynı dosya günler \
                geçtikçe puan kaybeder ve bir sabah kimse hiçbir şeyi değiştirmemişken boru hattı \
                kızarır.
                """),
            .heading("Sapma izleme"),
            .paragraph("""
                `--record-history` ile her çalıştırma bir JSONL geçmiş dosyasına satır ekler. Bir sonraki \
                sefer `drift:` bloğundaki eşikler en son çalıştırmayla karşılaştırır ve düşüş çok \
                büyükse uyarır.
                """),
            .note("""
                `warn_on_new_failure` dışında her sapma eşiği **öntanımlı kapalıdır**. Uygulamanın sizin \
                için seçtiği bir sayıyla kutudan açık gelen bir uyarı, herkesin ikinci çalıştırmasında \
                tetiklenirdi — ve birinci gün kurt masalı anlatan bir şey, üçüncü gün göz ardı edilir.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Veri madenciliği

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Veri madenciliği — bütün akış",
        summary: "Aykırılıklar, ilinti, kümeleme, öngörü, birliktelik kuralları — ve bunların nasıl okunacağı.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Madencilik akışı, baştan sona",
        summary: "Altı araç, kullanılacakları sıra ve tek kural: ölçüm yoksa sonuç da yok.",
        keywords: ["madencilik", "çözümleme", "akış", "istatistik"],
        blocks: [
            .warning("""
                **Önce temizleyin, sonra madenleyin.** Normalleştirilmemiş bir tarih sütunu yanlış \
                öngörüler üretir; Avrupa gruplama ayırıcılarını karıştıran bir sayısal sütun hayalî \
                aykırı değerler üretir. Aşağıdaki her araç tablonun temiz olduğunu varsayar.
                """),
            .heading("Gidilecek sıra"),
            .steps([
                "**Aykırılıkları bul** — *\"herhangi bir satır tuhaf mı\"* sorusunu yanıtlar. En ucuzu ve çoğu kez hemen yararlı olanı.",
                "**İlinti matrisi** — *\"hangi sütun hangisiyle birlikte hareket ediyor\"* sorusunu yanıtlar. Sonrasındaki her şeyi yönlendirir.",
                "**Kümeleme** — *\"burada kaç doğal grup var\"* sorusunu yanıtlar.",
                "**Öngörü** — yalnızca bir zaman sütunu ve en az **iki tam çevrim** varsa.",
                "**Birliktelik kuralları** — yalnızca sepet biçimli veri için: satır başına bir işlem ya da işlem kimliği ve ürün olmak üzere iki sütun.",
                "**Grup madenciliği** — ilk üçünü **her grubun içinde bağımsız olarak** yeniden çalıştırır. Bu adım, birleştirilmiş tablodan çıkarılan sonucu sıkça tersine çevirir.",
            ]),
            .heading("Bütün aile için üç kural"),
            .bullets([
                "**Her sonuç bir \"Yöntem\" bloğu taşır**: algoritma, parametreler, tohum, formül. Bunu kapatmanın yolu yoktur — nereden geldiğini söylemeyen üç sayılık bir tablo bir karar için kullanılamaz.",
                "**Ölçüm yoksa sonuç da yok.** Örneklem çok küçük, varyans sıfır, matris tekil — GEditor yalnızca doğru görünen bir sayı döndürmek yerine reddeder ve nedenini söyler.",
                "**Belirlenimci sonuçlar.** Aynı veri aynı sonucu verir; rastgelelik gerektiği her yerde tohum çıktıya kaydedilir.",
            ]),
            .heading("Bir sonuçtan veriye geri dönmek"),
            .paragraph("""
                Her panel **kaynak veriye geri imler**: aykırı bir satıra, bir ilinti hücresine ya da bir \
                birliktelik kuralına tıklayın; ilgili satırlar ızgarada imlenir. *\"Bir şey tuhaf\"*tan \
                *\"tam olarak şu satırlarda tuhaf\"*a böyle geçilir.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Aykırı satırları bulmak",
        summary: "Dört ölçü, üç önem düzeyi ve bir satırın neden tuhaf olduğunun açıklaması.",
        keywords: ["aykırı değer", "aykırılık", "z-skoru", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Ölçü", "Ne zaman kullanılır"],
                rows: [
                    ["z-skoru", "Sütun kabaca normal dağılmışsa"],
                    ["IQR", "Sütun uzun kuyruklu ve çarpıksa — güvenli öntanımlı"],
                    ["MAD", "Sütun zaten çok aykırı değer içeriyorsa ve dayanıklı bir ölçü gerekiyorsa"],
                    ["Mahalanobis", "**Aynı anda birkaç sütun** — tek bir sütunda değil, birleşimde tuhaf olan satırları yakalar"],
                ]
            ),
            .paragraph("""
                Sonuçlar tek düz renk yerine **üç önem düzeyine** göre renklendirilir — yoksa hafifçe \
                sıra dışı bir satır, çılgınca sıra dışı olandan ayırt edilemez.
                """),
            .heading("Nedenini açıklamak"),
            .paragraph("""
                Çok sütunlu ölçüde GEditor her sütunun katkısını ayrıştırır ve şuna benzer bir cümle \
                üretir: *«başlıca gelir (%50) × miktar (%50) birleşimi üzerinden aykırı»*.
                """),
            .note("""
                O yüzde, *uzaklığın* değil, *açıklanabilir kısmın* yüzdesidir. Yöntem bloğu bunu tablonun \
                hemen altında açıkça söyler.
                """),
            .warning("""
                IQR ya da MAD'i sıfır olan bir sütun, ölçünün minicik bir şeye bölüp devasa bir puan \
                üretmesi yerine **çalışmayı reddetmesine** yol açar. Çok sütunlu durumda kovaryans \
                matrisi tekilse GEditor, \"çalışsın diye\" sözde ters kullanmak yerine **hangi sütunun \
                çıkarılacağını söyler**.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "İlinti matrisi",
        summary: "Her çift için Pearson ve Spearman, tıklamada dağılım grafiğiyle.",
        keywords: ["ilinti", "pearson", "spearman", "ısı haritası", "dağılım"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Katsayı", "Neyi ölçer"],
                rows: [
                    ["Pearson", "**Doğrusal** bir ilişkiyi"],
                    ["Spearman", "Eğrisel olanlar dahil **her tekdüze** ilişkiyi — sıralar üzerinden hesaplanır"],
                ]
            ),
            .paragraph("""
                O çiftin dağılım grafiğini, bir bağlanım doğrusu ve R² ile görmek için ısı haritasındaki \
                bir hücreye tıklayın.
                """),
            .heading("Okuma biçimini değiştiren dört ayrıntı"),
            .bullets([
                "**Eşitlikler ortalama sıraları kullanır**; böylece tabloyu yeniden sıralamak Spearman katsayısını değiştirmez.",
                "**Boş hücreler ikili olarak ele alınır** ve her hücrenin `n`'i tablonun içindedir — 6 satır üzerinden `0,93`, 6.000 satır üzerinden `0,93` ile aynı anlama gelmez.",
                "**Sabit bir sütun boş döndürür**, 0 değil. Sıfır, *ölçüldü, ilişki bulunamadı* demektir.",
                "**Renk ölçeği mavi↔turuncudur**, kırmızı–yeşil değil: erkeklerin %8'i kırmızı–yeşil bir ölçeği tek bir gri kütle olarak görür ve bu, `+0,9` ile `−0,9`'u aynı gösterir.",
            ]),
            .warning("""
                **İlinti nedensellik anlamına gelmez.** Bu cümle **grafiğin kendi içine** çizilir; böylece \
                dışa aktardığınızda görüntüyle birlikte yolculuk eder.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Kümeleme",
        summary: "k-means ve DBSCAN, k'yi seçmenin iki yolu — ve ölçekleme hakkında bir uyarı.",
        keywords: ["küme", "kmeans", "dbscan", "gruplar", "siluet", "dirsek"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritma", "Ne zaman kullanılır"],
                rows: [
                    ["k-means", "Küme sayısını biliyorsanız (ya da denemek istiyorsanız); kümeler yumak biçimliyse"],
                    ["DBSCAN", "Sayıyı bilmiyorsanız; kümeler gelişigüzel biçimliyse; gürültünün ayrılmasını istiyorsanız"],
                ]
            ),
            .heading("Ölçekleme öntanımlı açık — ve nedeni"),
            .paragraph("""
                Bir `gelir` sütunu (milyonlarla) ile bir `miktar` sütunu (adetle) yan yana: iki satır \
                arasındaki uzaklığa neredeyse tümüyle büyük olan karar verir. Bu \"en iyi olmayan\" değil, \
                **başka bir soruyu yanıtlamaktır**. Yürürlükteki ölçekleme sonuca kaydedilir.
                """),
            .heading("Küme sayısını seçmek"),
            .bullets([
                "**Siluet** — puan ne kadar yüksekse kümeler o kadar iyi ayrılmıştır. Büyük bir tabloda **örneklem alır** (ilk 2.000 satır değil, eşit aralıklı) ve sonuç kendini bir tahmin olarak bildirir.",
                "**Dirsek** — küme içi kareler toplamını k'ye karşı çizer. Bu bir **grafik okuma biçimidir**, bir eniyileme değil: o nicelik k arttıkça hep düşer; dolayısıyla istatistiksel olarak \"en uygun k\" diye bir şey yoktur.",
            ]),
            .note("""
                DBSCAN için **k-uzaklık** grafiği bir yarıçap seçmeye yardım eder: eğrinin dizi genellikle \
                makul bir başlangıç değeridir.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Zaman serisi öngörüsü",
        summary: "Eğilim ve mevsimsellik ayrıştırması, Holt-Winters ve yanında hep çalışan bir taban çizgisi.",
        keywords: ["öngörü", "zaman serisi", "mevsimsellik", "holt-winters", "eğilim"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Bir zaman sütunu ve bir değer sütunu seçin. GEditor seriyi **eğilim · mevsimsellik · \
                artık** olarak ayrıştırır, sonra Holt-Winters ile (toplamsal ya da çarpımsal) %80 ve %95 \
                aralıklarıyla öngörür.
                """),
            .heading("Taban çizgisi hep çalışır ve kimin kazandığını açıkça söyler"),
            .paragraph("""
                Modelin yanında GEditor iki saf yöntem çalıştırır: *önceki dönemi al* ve *geçen mevsimin \
                aynı dönemini al*. Model bir taban çizgisine **yenilirse** o cümle bir sayı tablosunun \
                altında değil, **farklı bir renkte, ilk satırda** belirir.
                """),
            .paragraph("""
                Nedeni: öngörü araçları modeli olgu gibi sunmaya eğilimlidir ve kullanıcının \"geçen ayın \
                rakamını al\"ın daha isabetli olacağını öğrenmesinin bir yolu yoktur.
                """),
            .heading("GEditor'un reddettiği ya da kendini bildirdiği üç yer"),
            .bullets([
                "**İki tam çevrim olmadan saf yönteme döner.** Tek bir çevrimin gürültüsüne mevsimsellik uydurup bunu geleceğe yinelemek, çok inandırıcı ama tümüyle uydurma bir öngörü üretir.",
                "**Sıfırla karşılaşan MAPE bunu söyler** ve dönemlerin %25'inden çoğu sıfırsa ölçütü vermez — onları sessizce atlamak, dizgesel olarak yanlı bir altkümede hesaplanmış bir sayı üretir.",
                "**Güven aralığı kendini yaklaşık ilan eder** ve uzun ufuklarda çok yavaş genişlediğini belirtir.",
            ]),
            .note("""
                Mevsimsel dönem ham seri üzerinde değil, **birinci fark** üzerinde algılanır: bir eğilim \
                her gecikmeyi yüksek ilintili kılar ve mevsimsel tepeyi boğar.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Birliktelik kuralları",
        summary: "A alan çoğu kez B alır — ve tablo neden güvene değil, kaldıraca göre sıralanır.",
        keywords: ["apriori", "birliktelik kuralları", "pazar sepeti", "kaldıraç", "destek"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("İki veri biçimi kabul edilir:"),
            .bullets([
                "**Satır başına bir sepet** — ürün listesi içeren bir sütun.",
                "**İki sütun** — işlem kimliği ve ürün, satır başına bir ürün.",
            ]),
            .table(
                headers: ["Ölçüt", "Anlamı"],
                rows: [
                    ["destek", "Her iki yanı da içeren sepetlerin oranı"],
                    ["güven", "Sol yanı içeren sepetlerin ne kadarında sağ yan var"],
                    ["**kaldıraç**", "Güvenin, sağ yanın taban oranına bölümü"],
                    ["kaldıraç farkı", "Bağımsızlığın öngöreceğinden sapma"],
                ]
            ),
            .heading("Güvene göre değil, kaldıraca göre sıralı"),
            .paragraph("""
                Sağ yan zaten sepetlerin %95'inde geçiyorsa ona götüren **her** kuralın güveni yaklaşık \
                %95'tir — üstelik hiçbir şey söylemeden. Güvene göre sıralamak, tam da en anlamsız \
                kuralları en üste koyar.
                """),
            .warning("""
                `kaldıraç < 1` **satırın kendisinde imlenir**: taban oranı %95 olan bir şeye doğru %80 \
                güven, **ters** bir ilişki demektir — yanlış bir sonuca götüren doğru bir sayı.
                """),
            .bullets([
                "İki kutu süt almak yine süt içeren **tek** bir işlemdir: sepet içindeki yinelemeler atılır; yoksa destek miktarla şişer.",
                "Destek eşiğini fazla düşük tutmak aday kümesini birleşimsel olarak patlatır; tavana çarpınca GEditor **durur ve tablonun eksik olduğunu bildirir**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Gruba göre madencilik",
        summary: "Çözümlemeyi grup başına bağımsız yeniden çalıştırın — bir sonucu en sık tersine çeviren adım.",
        keywords: ["grupla", "grup başına", "simpson", "şubeler", "grupları karşılaştır"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Gruplama anahtarı olarak bir metin sütunu seçin. Her grup için aykırılıklar, öngörü ve \
                ilinti **tümüyle bağımsız** çalıştırılır, sonra seçtiğiniz ölçüte göre sıralanır.
                """),
            .heading("Gruplar neden birleştirilmemeli, ayrılmalı"),
            .paragraph("""
                İki şube; biri 10 dolayında, diğeri 100 dolayında. **Birleştirilmiş** tabloda hesaplanan \
                bir aykırı değer çiti ±135 dolayına düşer — ve **iki yönde de** başarısız olur:
                """),
            .bullets([
                "**Yanlış negatifler**: küçük şube için apaçık aykırı olan 20 değeri, ortak çitin epeyce içinde kalır. Grup sayısı arttıkça daha da körleşir.",
                "**Yanlış pozitifler**: geniş yayılan bir grubun normal kuyruğu ortak çitle kesilir ve bir yığın sıradan satır imlenir.",
            ]),
            .heading("\"İlinti ayrışması\" sütunu Simpson paradoksunu yakalar"),
            .paragraph("""
                **Her** grubunda iki sütunun `−1` ilintili olduğu, ama birleştirildiğinde `> 0,9` ilintili \
                çıkan üç grup. Yalnızca birleştirilmiş tabloyu okuyan biri **tam tersi** sonuca varır. Bu \
                sütun tam da bu durumları gösterir.
                """),
            .note("""
                Panel gruplama anahtarı olarak yalnızca **metin sütunları** sunar ve bir uyarıyla 1.000 \
                grupta durur — bir sipariş numarası sütununu seçip her satırı kendi başına bir gruba \
                çevirmeyi önlemek için.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Metin madenciliği",
        summary: "Bir metin sütunu üzerinde n-gramlar ve TF-IDF — ayırt edici öbekleri bulmak.",
        keywords: ["metin madenciliği", "n-gram", "tf-idf", "anahtar sözcükler", "öbekler"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Tek bir metin sütununda çalışır — ürün açıklamaları, müşteri geri bildirimleri, not \
                alanları.
                """),
            .bullets([
                "**n-gramlar** — en sık geçen 1, 2 ve 3 sözcüklük öbekler.",
                "**TF-IDF** — her belge grubu için **ayırt edici** sözcükler; yani burada sık, başka yerde seyrek olanlar.",
            ]),
            .paragraph("""
                Fark: n-gramlar size *\"müşterilerin sürekli neyden söz ettiğini\"* söyler, TF-IDF ise *\"bu \
                grubun ötekilerden nasıl ayrıldığını\"*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
