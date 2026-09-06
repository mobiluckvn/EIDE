import Foundation

/// Türkçe yardım kitabı — 1. bölüm: başlangıç ve düzenleme.
///
/// **Konu `id`'leri ÇEVRİLMEZ.** `.seeAlso` onları gösterir, menü onları açar ve yardım penceresinin
/// dilini değiştirirken okuyucuyu içindekiler listesine geri fırlatmamasını sağlayan şey onlardır.
/// Bir id'yi değiştirmek, tüm kitaplardaki bağlantıları aynı anda kırar.
///
/// `commands:` içindeki komut adları Vietnamca kalır: `HelpCoverage` onları gerçek menü
/// başlıklarıyla harfi harfine karşılaştırır.
enum HelpTR {}

extension HelpTR {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Başlangıç",
        summary: "GEditor ne yapar ve ilk beş dakikanızı nereye harcamalısınız.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "GEditor nedir",
        summary: "macOS için gigabayt ölçekli, Vietnamca konuşan bir metin ve veri düzenleyicisi.",
        keywords: ["giriş", "hoş geldiniz", "genel bakış", "hakkında"],
        blocks: [
            .paragraph("""
                GEditor **1 GB'lık bir dosyayı, 1 GB'ı belleğe yüklemeden** açar. Belleğe eşlenmiş bir \
                dosya üzerinde kayan bir pencereyle okur; böylece 200 milyon satırlık bir günlük ya da \
                bir milyon satırlık bir CSV yaklaşık bir saniyede açılır ve akıcı kaydırılır.
                """),
            .paragraph("""
                Düzenlemenin ötesinde bir **veri tezgâhıdır**: CSV'yi ızgara olarak görün, temizleyin, \
                kalitesini puanlayın, SQL ile sorgulayın, aykırılıklar ve eğilimler için madenleyin, \
                sonra bir rapor üretin. Ayrıca bugün çoğu aracın unuttuğu eski Vietnamca kodlamaları \
                okur.
                """),
            .heading("Önce denemeye değer altı şey"),
            .table(
                headers: ["Görev", "Nereye gidilir"],
                rows: [
                    ["Büyük bir dosyayı beklemeden açmak", "Pencereye sürükleyin — `Büyük dosyaları açmak` sayfasına bakın"],
                    ["Aynı anda birçok yeri düzenlemek", "`⌘D` bir sonraki eşleşmeyi ekler, sonra bir kez yazarsınız"],
                    ["Düzenli ifadeyle aramak", "`⌘F`, Regex'i açın — motor JIT'li PCRE2"],
                    ["CSV'yi ızgara olarak görmek", "`⌥⌘T` — bir milyon satır yine akıcı kayar"],
                    ["Dağınık bir veri tablosunu temizlemek", "`⇧⌘L` Temizlik tezgâhı — uygulamadan önce önizleyin"],
                    ["Bozuk görünen Vietnamca bir dosyayı açmak", "Durum çubuğundaki kodlamaya tıklayın"],
                ]
            ),
            .note("""
                Notepad++'tan mı geliyorsunuz? İki tuş düzenini karşılaştıran bir sayfa var; çünkü \
                macOS'ta birkaç tuş yalnızca `Ctrl`'ün `⌘` olmasıyla kalmayıp **yer değiştirir**.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "İlk beş dakikanız",
        summary: "On iki kısayol, günlük işin çoğunu karşılar.",
        keywords: ["kısayol", "tuşlar", "başlangıç", "temeller", "hızlı başlangıç"],
        blocks: [
            .paragraph("""
                Her şeyi öğrenmeniz gerekmez. Aşağıdaki on iki tuş günlük işin çoğunu karşılar; \
                gerisine ihtiyaç duyduğunuzda bakarsınız.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Dosya aç"),
                HelpShortcut("⇧⌘O", "Bütün bir klasörü çalışma alanı olarak aç"),
                HelpShortcut("⌘T", "Yeni sekme"),
                HelpShortcut("⌘S", "Kaydet"),
                HelpShortcut("⌘F", "Bul"),
                HelpShortcut("⌥⌘F", "Bul ve değiştir"),
                HelpShortcut("⇧⌘F", "Bir klasörün tamamında ara"),
                HelpShortcut("⌘D", "Seçimin bir sonraki geçtiği yeri ekle"),
                HelpShortcut("⌘L", "Satıra git"),
                HelpShortcut("⌘/", "Satırı, dilin kendi sözdizimiyle yorum yap"),
                HelpShortcut("⌥⌘T", "Izgara ile Metin arasında geçiş (CSV dosyaları)"),
                HelpShortcut("⌘?", "Bu yardım penceresini yeniden aç"),
            ]),
            .heading("Yeni gelenleri şaşırtan üç şey"),
            .bullets([
                "**Toplu bir işlem TEK geri alma adımıdır**, bir milyon satıra dokunsa bile. Yanlış mı sıraladınız? Tek `⌘Z` yeter.",
                "**Oturum kendini geri yükler.** Çıkın ve yeniden açın: sekmeler kaydedilmemiş olanlar dahil bıraktığınız yere döner. Basılacak bir şey yok.",
                "**Aksansız yazmak yine aksanlı sözcükleri bulur** — her arama ve süzme kutusunda: `Huế` için `hue`, `Đà Nẵng` için `da nang` yazın.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Ne yapmaya çalışıyorsunuz?",
        summary: "Gerçek görevlerden onları kapsayan bölüme bir arama tablosu.",
        keywords: ["dizin", "arama", "nasıl yapılır"],
        blocks: [
            .paragraph("""
                Soldaki içindekiler **özelliğe** göre düzenlidir. Bu tablo ise **göreve** göre; çünkü iki \
                sıralama örtüşmez.
                """),
            .table(
                headers: ["Şunu yapmam gerek…", "Bakınız"],
                rows: [
                    ["Yüzlerce satırda aynı noktayı düzenlemek", "Çoklu imleç · Sütun bloğu seçimi"],
                    ["Regex ile toplu biçimlendirme", "Bul ve değiştir · Düzenli ifadeler"],
                    ["Bir eylem dizisini yinelemek", "Makrolar"],
                    ["Birinin gönderdiği CSV'yi açmak", "CSV ızgarası"],
                    ["Dağınık bir tabloyu temizlemek: karışık tarihler, metin hâlinde sayılar", "Veri temizleme akışı"],
                    ["Bir tabloya güvenilip güvenilemeyeceğine karar vermek", "Veri kalitesi puanlaması"],
                    ["Aykırılıkları, eğilimleri, kümeleri bulmak", "Veri madenciliği akışı"],
                    ["SQL ile soru sormak", "CSV'yi SQL ile sorgulamak"],
                    ["Rakamları tazelenen bir rapor yayımlamak", "`.greport.md` raporları"],
                    ["Belge içinde diyagram çizmek", "Mermaid"],
                    ["Bozuk görünen Vietnamca bir dosyayı açmak", "Vietnamca kodlamalar"],
                    ["Kabuktan ya da AppleScript'ten otomatikleştirmek", "Otomasyon"],
                    ["Şirketimin uydurduğu bir biçimi renklendirmek", "Kullanıcı tanımlı diller"],
                ]
            ),
            .note("""
                Listede yok mu? Sol üstteki arama kutusu **gövde metnine ve kod örneklerine** bakar; \
                dolayısıyla `fail_under` gibi çıplak bir ayar anahtarını yazmak doğru sayfaya götürür.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Büyük dosyaları açmak",
        summary: "1 GB'ın neden hiç açılabildiği ve GEditor'un tahmin etmek yerine bilerek nerede reddettiği.",
        keywords: ["büyük dosya", "gigabayt", "1gb", "günlük", "mmap", "yavaş", "başarım"],
        blocks: [
            .paragraph("""
                Dosya **belleğe eşlenir** ve kayan bir pencereyle okunur; düzenlediğiniz kısım bir parça \
                tablosunda yaşar. Uygulamada: açılış süresi dosya boyutuna neredeyse hiç bağlı değildir, \
                uygulamanın tuttuğu bellek de öyle.
                """),
            .heading("Bilerek reddettiği yerler"),
            .paragraph("""
                Birkaç hesaplama, tüm dosyayı tek bir dizeye okumak zorunda kalırdı — bu mimarinin tam da \
                kaçındığı şey. Oralarda GEditor sessizce sürünmek ya da tahmin etmek yerine **yapmayacağını \
                söyler**:
                """),
            .table(
                headers: ["İşlem", "Tavan", "Ötesinde"],
                rows: [
                    ["Parantez eşleştirme", "1 MB", "Reddeder ve söyler — yanlış çifti vurgulamak hiç vurgulamamaktan kötüdür"],
                    ["Durum çubuğundaki görsel sütun", "200 KB", "Bayt saymaya döner ve anlamı görünsün diye `~` ile işaretler"],
                    ["Markdown önizlemesi", "4 MB", "Reddeder ve açıklar"],
                ]
            ),
            .warning("""
                Aynı görünüp başka bir şey ifade eden bir sayı, yanlışın en kötüsüdür. Bu yüzden tavanı \
                aşan sütun `1234` değil, `~1234` yazar.
                """),
            .heading("Günlük dosyaları için ipuçları"),
            .bullets([
                "`Dosya ▸ Dosyayı izle (tail -f)` sona yazılan her şeyi ekler. İzleme sırasında belge **salt okunur** olur — yeni metin akarken yazmak, tek belge üzerinde iki yazıcı demektir ve kaybeden hep az önce yazdığınızdır.",
                "Günlük satırları **önem derecesine göre renklenir** ve düzeye göre süzülebilir.",
                "**Belge haritası** (`⌥⌘M`) yalnızca ekrandakini değil, tüm dosyayı betimler.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store sürümü ile doğrudan indirme",
        summary: "Yalnızca doğrudan sürümde bulunan üç özellik ve nedeni.",
        keywords: ["app store", "kum havuzu", "indirme", "cli", "eklenti", "fark"],
        blocks: [
            .paragraph("""
                GEditor iki sürüm hâlinde dağıtılır. İkisi de **aynı kaynaktan** gelir ve uygulama \
                açılışta hangisi olduğunu tanır. Fark, App Sandbox'ın neye izin verdiğidir.
                """),
            .table(
                headers: ["Özellik", "App Store", "Doğrudan indirme"],
                rows: [
                    ["Tüm düzenleme, CSV, temizlik, madencilik, raporlama", "Evet", "Evet"],
                    ["`geditor` komut satırı aracı", "Hayır", "Evet"],
                    ["Metni dış bir komuttan geçirmek", "Hayır", "Evet"],
                    ["Yerel eklentiler (ayrı süreç)", "Hayır", "Evet"],
                    ["Kendini güncelleme", "App Store üzerinden", "Uygulama içinde"],
                ]
            ),
            .paragraph("""
                Yukarıdaki her "Hayır" aynı kuraldan gelir: kum havuzu **uygulama dışında kod \
                çalıştırmayı yasaklar**. Bu, App Store dağıtımının bedelidir; bir gözden kaçırma değil.
                """),
            .note("""
                App Store sürümünde bu komutlar **menüde kalır** ve kaybolmak yerine neden \
                kullanılamadıklarını açıklar. Eksik bir menü ögesi destek sorusudur; yerinde duran bir \
                yanıt değildir.
                """),
            .heading("App Store sürümünde dosya erişimi"),
            .paragraph("""
                Kum havuzundaki sürüm yalnızca kendinizin açtığı ya da sürüklediği dosyalara \
                dokunabilir. GEditor her sekme ve çalışma alanı klasörü için bir **güvenlik kapsamlı yer \
                imi** tutar; böylece çıktıktan sonra oturumunuz yeniden izin sormadan açılır.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Düzenleme

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Düzenleme",
        summary: "Aynı anda birçok yeri düzenleyin, satırlar üzerinde çalışın ve önce bilinmeye değer gizli kurallar.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Çoklu imleç",
        summary: "Eşleşen her noktayı seçin, bir kez yazın, hepsini değiştirin.",
        keywords: ["çoklu imleç", "cmd+d", "çoklu seçim"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Bu, düzenli ifade yazmaya niyetlendiğiniz anların çoğunun yerini alır. Bir sözcük seçin, \
                sonraki geçtiği yerleri toplamak için birkaç kez `⌘D` basın, sonra yazın — her nokta aynı \
                anda değişir.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Bir sonraki geçtiği yeri seçime ekle"),
                HelpShortcut("⌘ + tıklama", "Tıkladığınız yere başka bir imleç koy"),
                HelpShortcut("Esc", "Hepsini bırak, tek imlece dön"),
                HelpShortcut("⌥ + sürükleme", "Sütun bloğu seçimi (çok imleç elde etmenin başka bir yolu)"),
            ]),
            .heading("Bilinmeye değer kurallar"),
            .bullets([
                "Birçok imleçte yazmak, silmek ve yapıştırmak imleç başına bir değil, **tek** geri alma adımıdır.",
                "İmleçler ok tuşu hareketinden sağ çıkar — bütün grup birlikte hareket eder.",
                "`⌘D` seçimin içinde zaten olan yerleri atlar; bu yüzden fazla basmak imleçleri üst üste yığmaz.",
            ]),
            .note("""
                Uzun bir dize içindeki sözcükte `⌘D` eskiden yavaştı. Sözcük sınırı algılama artık \
                yığınlar hâlinde okuyor — 1 MB'lık bir dizede yaklaşık **42 kat hızlı**; bu da onu \
                yalnızca kaynak kodda değil, veri dosyalarında da kullanılabilir kılıyor.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Sütun bloğu seçimi",
        summary: "Birçok satır boyunca bir dikdörtgen seçin — fareyle ya da klavyeden.",
        keywords: ["sütun kipi", "blok seçimi", "alt sürükleme", "dikdörtgen", "klavye", "oklar"],
        blocks: [
            .paragraph("""
                `⌥` tuşunu basılı tutup sürükleyerek **dikdörtgen bir blok** seçin. Yazmak, silmek ve \
                yapıştırmak bloğu izler. Tek imleçte bir blok yapıştırmak yine dikdörtgenini korur.
                """),
            .shortcuts([
                HelpShortcut("⌥ + sürükleme", "Blok seç"),
                HelpShortcut("⌥⌘← →", "Bloğu bir sütun sola/sağa genişlet"),
                HelpShortcut("⌥⌘↑ ↓", "Bloğu bir satır yukarı/aşağı uzat"),
            ]),
            .paragraph("""
                Klavye yolu, farenin yedeği değildir: 40 satırlık bir bloğu sürükleyerek seçmek, bir \
                kaydırmanın içinden sürüklemek demektir; `⌥⌘` + oklar ise sütun sütun kesinliği korur. \
                **Başka herhangi** bir tuşa basmak (ya da yazmak) uzattığınız bloğu bitirir.
                """),
            .heading("Buradaki sütunlar GÖRSEL sütunlardır"),
            .paragraph("""
                Bir TAB, tek sütun saymak yerine sizin sekme genişliğinizde bir sonraki durağa kadar \
                genişler. Sekmeyle ve boşlukla girintilenmiş satırların **ekranda göründükleri gibi hizalanmasını** \
                sağlayan budur.
                """),
            .paragraph("Çok baytlı metin yine tek sütundur: `Nguyễn` dokuz değil, altı sütun kaplar."),
            .table(
                headers: ["Durum", "GEditor ne yapar"],
                rows: [
                    ["Hedef sütun bir TAB'ın ortasına düşer", "Yakın kenara yapışır; eşitlikte sola gider"],
                    ["Bir satır başlangıç sütunundan kısadır", "O satır boş bir seçim katar ve yine de yazılan metni kabul eder"],
                    ["Tek imleçte blok yapıştırmak", "Dikdörtgeni korur, aşağıdaki satırlara doğru ekler"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Sütun Düzenleyici",
        summary: "Bir bloğun her satırına metin, sayı dizisi ya da tarih dizisi ekleyin.",
        keywords: ["sütun düzenleyici", "numaralama", "dizi", "seri"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Bir sütun bloğu seçin, sonra `Düzen ▸ Column Editor…` (`⌥⌘C`) açın. Pencerede, hiçbir şey \
                uygulanmadan önce bir **önizleme** vardır.
                """),
            .table(
                headers: ["Kip", "Parametreler", "Ne zaman"],
                rows: [
                    ["Metin", "Sabit bir dize", "Her satıra aynı öneki/soneki eklerken"],
                    ["Sayı dizisi", "Başlangıç · adım · taban 2·8·10·16 · sıfır doldurma", "Satırları numaralarken, kod üretirken"],
                    ["Tarih dizisi", "İlk tarih · gün cinsinden adım", "Ardışık tarihlerden bir sütun üretirken"],
                ]
            ),
            .code(
                language: "text",
                caption: "1'den başlayıp 1 adımla, sıfır doldurmalı numaralama",
                source: """
                    Önce:             Sonra (sayı dizisi, 3 haneye doldurulmuş):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """
            ),
            .bullets([
                "**Negatif** adım geçerlidir — geriye doğru saymak işler.",
                "5.000 satıra ekleme yapmak yine **tek** geri alma adımıdır.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Satır işlemleri",
        summary: "Sırala, yinelenenleri kaldır, taşı, birleştir, böl, çoğalt, sil.",
        keywords: ["sırala", "çoğalt", "yinelenen", "satır taşı", "birleştir", "böl"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Seçim varsa komut seçim üzerinde çalışır; yoksa **belgenin tamamında** çalışır. Buradaki \
                her komut tek bir geri alma adımıdır.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Satırı çoğalt"),
                HelpShortcut("⌘K", "Satırı sil"),
                HelpShortcut("⌥↑ / ⌥↓", "Satırı yukarı / aşağı taşı"),
            ]),
            .heading("Üç tür sıralama ve hangisini seçmeli"),
            .table(
                headers: ["Tür", "`file2` ile `file10`", "Ne için"],
                rows: [
                    ["A→Z / Z→A", "`file10`, `file2`'den önce gelir", "Düz sözcük listeleri"],
                    ["Doğal", "`file2`, `file10`'dan önce gelir", "Dosya adları, kodlu kimlikler, sürümler"],
                ]
            ),
            .paragraph("""
                **Doğal** sıralama, rakam dizilerini sayı olarak okur. Liste numaralıysa neredeyse her \
                zaman istediğiniz budur.
                """),
            .heading("Yinelenenleri kaldırma"),
            .bullets([
                "**Belgenin tamamı** — daha önce görülen her satırı at, ilkini tut.",
                "**Yalnızca komşular** — Unix `uniq` gibi, birbirine komşu aynı satırları tek satıra indir.",
            ]),
            .heading("Birleştirme ve bölme"),
            .bullets([
                "**Satırları birleştir**, seçili satırları tek satırda toplar.",
                "**Uzunluğa göre böl**, uzun satırları verilen karakter sayısında keser.",
                "**Karaktere göre böl**, yazdığınız karakterin her geçtiği yerde keser — örneğin bir CSV satırını hücrelerine ayırmak için.",
            ]),
            .note("""
                Bir dosyanın **son satırını** çoğaltmak eksik satır sonunu ekler; belgenin sonuna kadar \
                silmek ise bir önceki satırın satır sonunu da yutar. İkisi de saf uygulamadan ayrılır ve \
                ikisi de dosyanın başıboş bir boş satırla bitmemesi — ya da hiç bitmemesi — için vardır.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Boşluk ve girinti",
        summary: "Başıboş boşlukları temizleyin, TAB ↔ Boşluk dönüştürün ve üzerinde düşünmeye değer bir anahtar.",
        keywords: ["boşluk", "sekme", "boşluk karakteri", "kırp", "girinti", "boş satırlar"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Komut", "Ne yapar"],
                rows: [
                    ["Boş satırları kaldır", "Üzerinde hiçbir şey olmayan her satırı atar"],
                    ["Ardışık boş satırları daralt", "Arka arkaya birkaç boş satır tek satır olur"],
                    ["Satır sonundaki boşlukları kırp", "Her satırın sonundaki başıboş boşluk ve sekmeleri kaldırır"],
                    ["Tab → Boşluk", "TAB'ları geçerli sekme genişliğinde boşluğa çevirir"],
                    ["Boşluk → Tab", "Diğer yön"],
                ]
            ),
            .heading("Dile göre girinti"),
            .paragraph("""
                Durum çubuğundaki `Tab: 4`'e tıklayın. Menünün üst kısmı bunu **tüm uygulama** için \
                değiştirir; alt kısmı — `Yalnızca Go için`, `Yalnızca Python için`… — yalnızca açık \
                dosyanın diline uygulanır ve sekme mi boşluk mu kullanılacağını hatırlar.
                """),
            .paragraph("""
                İnsanlar girintiyi zevkle değil, **topluluk geleneğiyle** seçer: Go sekme kullanır \
                (`gofmt` her şeyi geçersiz kılar), Python PEP 8 uyarınca dört boşluk, JavaScript ve YAML \
                genelde iki. Her dil için tek bir sayı, dokunduğunuz her dosyada hiç düzenlemediğiniz \
                satırların değişmesi demektir.
                """),
            .code(
                language: "json", caption: "settings.json",
                source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """
            ),
            .note("""
                Bunu `settings.json` içinde bildirmek de işe yarar — anahtar dil kodudur (`go`, \
                `python`, `javascript`…). Orada bulunmayan diller ortak `tabWidth` değerini kullanır.
                """),
            .heading("\"Kaydederken kırp\" neden KAPALI geliyor"),
            .paragraph("""
                `Dosya ▸ Kaydederken satır sonu boşluklarını kırp` anahtarı **hiç dokunmadığınız \
                satırları** düzenler. Varsayılan açık olsaydı, başkasının deposundaki tek sözcüklük bir \
                düzeltme bin satırlık bir farka dönüşür ve inceleyen kişi gerçek değişikliği bulamazdı.
                """),
            .paragraph("""
                Açıkken kırpma, yazmadan önce yerleştirilen **ayrı bir geri alma adımıdır** — tek geri \
                alma, belgeyi eski hâline döndürür ve az önce kaydettiğinizi kaybetmez.
                """),
            .heading("Otomatik girinti"),
            .bullets([
                "Yeni satır, önceki satırın girintisini devralır; açan bir simgeden sonra bir düzey ekler — kaşlı ayraç dillerinde `{`, Python ve YAML'de `:`.",
                "Ölçüm **görsel sütunlarla** yapılır; böylece sekme ve boşluğu karıştıran dosyalar ekranda yine hizalanır.",
                "\"`}` yazmak satırı yeniden girintiler\" diye bir kural **yoktur**. O kural, bitirdiğiniz bir satırı düzenler ve sahip olduğu her düzenleyicide en çok şikâyet edilen davranıştır.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Büyük/küçük harf ve adlandırma gelenekleri",
        summary: "camelCase, snake_case ve kebab-case dahil sekiz dönüşüm.",
        keywords: ["harf", "büyük harf", "küçük harf", "camel", "snake", "kebab", "başlık"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Seçime uygulanır. Hepsi `Biçim` menüsünde bulunur."),
            .table(
                headers: ["Komut", "`tổng doanh thu` şuna dönüşür"],
                rows: [
                    ["BÜYÜK HARF", "`TỔNG DOANH THU`"],
                    ["küçük harf", "`tổng doanh thu`"],
                    ["Her Sözcük Büyük", "`Tổng Doanh Thu`"],
                    ["Cümle başı büyük", "`Tổng doanh thu`"],
                    ["Harf durumunu ters çevir", "Her karakteri ters çevirir"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Son üçü Vietnamca aksanları söker; çünkü **koddaki tanımlayıcıları** üretirler — aksanlı \
                harflere orada genellikle izin verilmez.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Yorumlar ve parantez eşleştirme",
        summary: "⌘/ her dilin kendi imini kullanır; ⌃⌘B eşleşen paranteze atlar.",
        keywords: ["yorum", "parantez", "cmd+/", "eşleştirme"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` yorum imini **belgenin diline göre** seçer: Python için `#`, Rust ve C için `//`, \
                XML ve HTML için `<!-- -->`.
                """),
            .heading("Bütün blok tek yöne gider"),
            .paragraph("""
                Blokta tek bir satır bile hâlâ yorumlanmamışsa komut **her şeyi** yorumlar. Satır satır \
                karar vermek, yarı yorumlanmış bir bloğu satranç tahtasına çevirirdi. İm, bloğun en sığ \
                girintisine eklenir; böylece blok biçimini korur.
                """),
            .heading("Eşleşen paranteze atlamak"),
            .bullets([
                "`⌃⌘B`, imleçteki parantezle eşleşene atlar.",
                "**Dize** ya da **yorum** içindeki parantezler sayılmaz — hafif bir sözcük çözümleyici onları ayırt eder.",
                "**1 MB**'ı aşınca komut, yarı yolda demirleyip tahmin etmek yerine reddeder ve söyler. Yanlış çifti vurgulamak, hiç vurgulamamaktan kötüdür.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Geri alma ve pano",
        summary: "Sınırsız geri alma geçmişi ve çok yuvalı bir pano geçmişi.",
        keywords: ["geri al", "yinele", "pano", "yapıştır", "geçmiş"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Geri al / Yinele"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Kes / Kopyala / Yapıştır"),
                HelpShortcut("⇧⌘V", "Pano geçmişi"),
            ]),
            .heading("Toplu bir işlem TEK adımdır"),
            .paragraph("""
                Bir milyon satırı sıralamak, on bin eşleşmeyi değiştirmek, Sütun Düzenleyici ile beş bin \
                satıra ekleme yapmak — her biri **tek** `⌘Z` ile geri alınır.
                """),
            .paragraph("""
                Geri alma geçmişi, sistemin `UndoManager`'ı yerine GEditor'un kendi metin arabelleğinde \
                yaşar; tam da bu nedenle: `UndoManager` tuş vuruşlarını sayar.
                """),
            .heading("Pano geçmişi"),
            .paragraph("""
                `⇧⌘V`, yakın zamanda kopyaladıklarınızın listesini açar ve seçtiğinizi yapıştırır. İki \
                parçayı birçok yerde dönüşümlü kullanmanız gerektiğinde işe yarar.
                """),
        ]
    )
}
