import Foundation

/// Türkçe yardım kitabı — 2. bölüm: arama, dosyalar ve oturumlar.
extension HelpTR {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Arama",
        summary: "Bul, değiştir, düzenli ifadeler, klasör genelinde arama ve satır imleri.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Bul ve değiştir",
        summary: "Üç arama kipi ve ^ neden öntanımlı olarak SATIR başı anlamına gelir.",
        keywords: ["bul", "değiştir", "arama", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Bul"),
                HelpShortcut("⌥⌘F", "Bul ve değiştir"),
                HelpShortcut("⌘G / ⇧⌘G", "Sonraki / önceki eşleşme"),
            ]),
            .heading("Üç kip"),
            .table(
                headers: ["Kip", "Anladığı", "Ne için"],
                rows: [
                    ["Normal", "Düz metin, hiç özel karakter yok", "Aramaların çoğu"],
                    ["Genişletilmiş", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Satır sonu, TAB, belirli baytları bulmak"],
                    ["Regex", "Tam PCRE2", "Örüntüye göre eşleştirmek"],
                ]
            ),
            .note("""
                **Genişletilmiş** kip regex sözdizimini anlamaz. Yalnızca birkaç kaçış dizisini açar — \
                dolayısıyla orada `a.b` aramak tam olarak bu üç karakteri bulur; nokta bir joker değildir.
                """),
            .heading("İki anahtar"),
            .bullets([
                "**Büyük/küçük harf eşleştir** — öntanımlı kapalı.",
                "**Tam sözcük** — yalnızca iki uç da sözcük sınırıysa eşleşir.",
            ]),
            .heading("`^` ve `$` her SATIRIN uçlarında eşleşir"),
            .paragraph("""
                Öntanımlı açık. Notepad++'tan gelenler `^`'in \"satır başı\" demesini bekler; kapalıyken \
                `^abc` yalnızca belgenin tamamı `abc` ile başlıyorsa eşleşirdi — bir metin \
                düzenleyicisinde bunu neredeyse kimse istemez.
                """),
            .heading("Kötü bir ifade uygulamayı kilitlemez"),
            .paragraph("""
                Motor **JIT derlemeli PCRE2**'dir ve bir geri izleme bütçesi vardır. Birleşimsel olarak \
                patlayan bir örüntü, pencereyi dondurmak yerine durdurulur ve bildirilir.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Düzenli ifadeler",
        summary: "Gerçekten kullandığınız PCRE2 sözdizimi, Vietnamca veriler üzerinde çalışan örneklerle.",
        keywords: ["regex", "regexp", "pcre", "örüntü"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor, PHP ile birçok komut satırı aracıyla aynı motor olan **PCRE2**'yi kullanır. Bir \
                örüntüyü örnek metin üzerinde denemek ve her grubun neyi yakaladığını gerçek bir belgeye \
                uygulamadan **önce** görmek için `Ara ▸ Düzenli ifadeyi dene…` açın.
                """),
            .heading("Karakter sınıfları"),
            .table(
                headers: ["Yazın", "Eşleşen"],
                rows: [
                    ["`.`", "Satır sonu dışında herhangi bir karakter"],
                    ["`\\d` · `\\D`", "Bir rakam · rakam olmayan"],
                    ["`\\w` · `\\W`", "Bir sözcük karakteri (harf, rakam, `_`) · tersi"],
                    ["`\\s` · `\\S`", "Boşluk · boşluk olmayan"],
                    ["`[abc]`", "Ayraç içindeki karakterlerden biri"],
                    ["`[^abc]`", "Ayraç içinde OLMAYAN bir karakter"],
                    ["`[a-z]`", "Aralıktaki bir karakter"],
                ]
            ),
            .heading("Yineleme"),
            .table(
                headers: ["Yazın", "Anlamı"],
                rows: [
                    ["`*`", "Sıfır ya da daha çok"],
                    ["`+`", "Bir ya da daha çok"],
                    ["`?`", "Sıfır ya da bir"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Tam 3 · 2 ile 5 arası · 2 ya da daha çok"],
                    ["`*?` `+?` `??`", "**Tembel** biçimler — olabildiğince az al"],
                ]
            ),
            .warning("""
                `.*` **açgözlüdür**: satırın sonuna kadar yer, sonra geri çekilir. Bir satır içindeki \
                alanları ayırırken neredeyse her zaman `.*?` ya da `[^,]*` gibi dar bir karakter sınıfı \
                gerekir.
                """),
            .heading("Çıpalar ve gruplar"),
            .table(
                headers: ["Yazın", "Anlamı"],
                rows: [
                    ["`^` · `$`", "Satır başı · satır sonu"],
                    ["`\\b`", "Sözcük sınırı"],
                    ["`(…)`", "**Yakalayan** grup — değiştirmede yeniden kullanılabilir"],
                    ["`(?:…)`", "Yakalamayan grup"],
                    ["`(?<name>…)`", "Adlandırılmış grup"],
                    ["`a|b`", "a ya da b"],
                    ["`(?=…)` · `(?!…)`", "İleri bakış: izlemeli · izlememeli"],
                    ["`(?<=…)` · `(?<!…)`", "Geri bakış: öncelemeli · öncelememeli"],
                ]
            ),
            .heading("Çalışan örnekler"),
            .code(language: "regex", caption: "Her 10 haneli Vietnam telefon numarası",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "31/12/2026 gibi bir tarihi üç gruba ayır",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Basit bir CSV satırının üçüncü hücresi (tırnaksız)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "ERROR ya da FATAL düzeyindeki günlük satırları, zaman damgasıyla",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Boş satırlar ya da yalnızca boşluk içeren satırlar",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Aksanlı Vietnamca harfler — Unicode sınıfını kullanın, tek tek listelemeyin",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` \"herhangi bir Unicode harfi\" demektir; `ế` ve `đ` ile de eşleşir. Aksanlı her \
                ünlüyü elle listelemek, bazılarını kaçırmanın garanti yoludur.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Değiştirme dizeleri",
        summary: "Yakalanan grupları yeniden kullanın ve değiştirirken harf durumunu değiştirin.",
        keywords: ["değiştir", "geri başvuru", "grup", "$1", "\\U"],
        blocks: [
            .heading("Yakalanan bir grubu geri çağırmak"),
            .table(
                headers: ["Yazın", "Anlamı"],
                rows: [
                    ["`$1` … `$9`", "n numaralı grubun içeriği"],
                    ["`${1}`", "Aynısı, açık sınırlarla — ardından rakam geldiğinde kullanın"],
                    ["`\\1`", "Bu da kabul edilir; GEditor onu `${1}` olarak yeniden yazar"],
                    ["`$0`", "Eşleşmenin tamamı"],
                ]
            ),
            .note("""
                Sonraki karakter bir rakamsa `$1` yerine `${1}` yazın. `$123`, 123 numaralı grup olarak \
                okunur; `${1}23` ise 1. grup ve ardından iki rakamdır.
                """),
            .heading("Değiştirme sırasında harf durumunu değiştirmek"),
            .table(
                headers: ["Yazın", "Anlamı"],
                rows: [
                    ["`\\U`", "Buradan itibaren BÜYÜK HARF"],
                    ["`\\L`", "Buradan itibaren küçük harf"],
                    ["`\\u`", "Yalnızca sonraki karakter büyük"],
                    ["`\\l`", "Yalnızca sonraki karakter küçük"],
                    ["`\\E`", "`\\U` ya da `\\L` bölgesini bitirir"],
                ]
            ),
            .heading("Örnekler"),
            .code(language: "text", caption: "31/12/2026'yı 2026-12-31 yap",
                  source: """
                    Bul:      (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Değiştir: $3-$2-$1
                    """),
            .code(language: "text", caption: "Her satırın başındaki il kodunu büyüt, gerisini koru",
                  source: """
                    Bul:      ^([a-z]{2,3})(\\s)
                    Değiştir: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Her satırı JSON dizesi olarak sar",
                  source: """
                    Bul:      ^(.+)$
                    Değiştir: "$1",
                    """),
            .paragraph("""
                Eşleşmeye **katılmayan** bir grup hata değil, boş dize olur — böylece `(a)|(b)` gibi \
                seçenekli bir örüntü, iki kez yazmaya gerek kalmadan temiz biçimde değiştirir.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Bir klasörün tamamında bul ve değiştir",
        summary: "Birçok dosyayı aynı anda tarayın ve hiçbir şey yazılmadan sonuçları görün.",
        keywords: ["dosyalarda bul", "grep", "toplu değiştirme", "klasör"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Bir klasörün tamamında ara")]),
            .paragraph("""
                Kök klasörü seçin, dosya adı örüntüsüyle süzün, sonra tarayın. Sonuçlar dosyaya göre \
                gruplanmış bir liste hâlinde çıkar; bir satıra tıklamak o dosyayı o konumda açar.
                """),
            .bullets([
                "Belge içi arama kutusuyla aynı üç arama kipi ve aynı regex motoru.",
                "Klasör genelinde değiştirme, yazmadan önce kaç dosyanın ve kaç eşleşmenin değişeceğini **önizler**.",
                "Tarama paralel yürür ve yarıda **iptal edilebilir**.",
            ]),
            .warning("""
                Klasör genelinde değiştirme, **açık olmayan** dosyalara doğrudan yazar. O dosyalar açık \
                belgenin geri alma geçmişinde yoktur — önce önizleyin ve bir yedek ya da sürüm \
                denetimli bir depo bulundurun.
                """),
            .heading("Önceki aramalar ve sonuçları dışa aktarmak"),
            .paragraph("""
                Sonuç paneli **bu oturumun aramalarını saklar**. Panelin üstündeki açılır menü, onları \
                eşleşme sayılarıyla birlikte listeler — `TODO` arayın, bir süre okuyun, karşılaştırmak \
                için `FIXME` arayın, sonra klasörü baştan taramadan ilk listeye dönün.
                """),
            .paragraph("""
                **Dışa aktar** düğmesi, geçerli aramayı bir metin sekmesi olarak açar; satır başına bir \
                sonuç, `yol:satır:sütun: metin` biçiminde — `grep -n`'in kullandığı ve derleyicilerin \
                hatalar için kullandığı biçim. Her satır bu ürünün kendi `Git` kutusuna doğrudan \
                yapıştırılır ve `grep`, `awk`, `sed` onu özel bir ayrıştırıcı olmadan okur.
                """),
            .note("""
                Geçmiş **bellekte** yaşar ve asla diske yazılmaz: arama sonuçları eşleşen her satırın \
                içeriğini taşır ve bu, pano geçmişinin bilerek kalıcılaştırmadığı veri sınıfının aynısıdır.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Satır imleri",
        summary: "Dokuz im rengi ve imlenmiş satırları sonuca çeviren dört komut.",
        keywords: ["yer imi", "im", "f2", "satır süz"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                İmleme, bir belgeyi **değiştirmeden** süzme yoludur. Bir örüntüyle eşleşen her satırı \
                imleyin, sonra yalnızca onları kopyalayın ya da yalnızca onları tutun.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Geçerli aramayla eşleşen her satırı imle"),
                HelpShortcut("⌘F2", "Geçerli satırı imle / imi kaldır"),
                HelpShortcut("F2 / ⇧F2", "Sonraki / önceki ime atla"),
            ]),
            .heading("Sık kullanılan bir akış"),
            .steps([
                "Süzmek istediğiniz örüntü için `⌘F`, örneğin `\\bERROR\\b`.",
                "`⌘M` eşleşen her satırı imler.",
                "`Ara ▸ İmlenmiş satırları kopyala` onları yeni bir sekmeye çeker — ya da `Yalnızca imlenmiş satırları tut` yerinde süzer.",
            ]),
            .heading("Dokuz renk"),
            .paragraph("""
                Bir satır **aynı anda birkaç renk** taşıyabilir. Farklı ölçütler için farklı renkler \
                kullanın ve birleştirin: hata satırları için kırmızı, tek bir sipariş numarasına ait \
                satırlar için sarı; sonra ikisini birden taşıyan satırlara bakın.
                """),
            .bullets([
                "`İmleri ters çevir` — imli satırlar imsiz olur, tersi de geçerli.",
                "`Tüm imleri temizle` — içeriğe dokunmadan her imi kaldırır.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Satıra git",
        summary: "Bir satıra, bir sütuna ya da bir bayt konumuna atlayın.",
        keywords: ["git", "satır numarası", "cmd+l", "konum", "sütun"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Satıra git")]),
            .paragraph("""
                Alan **üç gösterimi** anlar ve yazdığınızdan onları ayırt eder — tıklanacak fazladan bir \
                seçici yoktur.
                """),
            .table(
                headers: ["Yazın", "Gider"],
                rows: [
                    ["`120`", "120. satırın başına"],
                    ["`120,5` ya da `120:5`", "120. satır, 5. sütun — sütun KARAKTER sayar"],
                    ["`@1024`", "dosyadaki 1024. bayt konumuna"],
                ]
            ),
            .note("""
                `satır:sütun`, derleyici ve tüy toplayıcıların konumu tam olarak bu şekilde yazdığı \
                biçimdir; terminalden az önce kopyaladığınız bir satır doğrudan yapıştırılır.

                Bayt konumları için `@` işaretinin bir nedeni var: `1234` bir satır mı, bayt mı? Doğru \
                yanıt yoktur ve yanlış tahmin, hiçbir işaret vermeden imleci bambaşka bir yere gönderir. \
                O bayt sayısı, durum çubuğunun konum bölümünde gösterdiğinin de aynısıdır (`@1024`); \
                orada okuduğunuzu buraya yazarsınız.
                """),
            .bullets([
                "**Satır uzunluğunu aşan** bir sütun o satırın sonunda durur; bir sonrakine taşmaz.",
                "**Dosyayı aşan** bir bayt konumu sizi sona götürür — o sayıyı genellikle önceki bir çalıştırmadan kopyalamışsınızdır ve dosya küçülmüş olabilir.",
                "Okuyamadığı metin **bildirilir** ve imleç yerinde kalır; dosyanın başına atlamaz.",
            ]),
            .paragraph("""
                Çok büyük dosyalarda GEditor oraya varmak için tüm dosyayı okumaz — satır dizini arka \
                planda aşamalı olarak kurulur.
                """),
            .note("""
                Komut satırı aracı da bir konum alır: `geditor report.csv:120:5` dosyayı imleç 120. \
                satır, 5. sütunda olacak biçimde açar.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Dosyalar ve oturumlar

    static let files = HelpChapter(
        id: "tep",
        title: "Dosyalar ve oturumlar",
        summary: "Açma, kaydetme, sekmeler, pencereler, çalışma alanları ve oturumun nasıl geri geldiği.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Açma ve kaydetme",
        summary: "Her boyutta dosya açın ve farklı bir kodlama ya da satır sonuyla kaydedin.",
        keywords: ["aç", "kaydet", "farklı kaydet", "çoğalt", "yeniden adlandır", "taşı"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Yeni belge"),
                HelpShortcut("⌘O", "Dosya aç"),
                HelpShortcut("⌘S", "Kaydet"),
                HelpShortcut("⇧⌘S", "Farklı kaydet"),
            ]),
            .paragraph("""
                Bir dosyayı pencereye sürüklemek de açar. `Dosya ▸ Son Kullanılanları Aç`, az önce \
                çalıştığınız dosyaların listesini tutar.
                """),
            .heading("Farklı kaydet: değiştirebileceğiniz üç şey"),
            .table(
                headers: ["Değişiklik", "Anlamı"],
                rows: [
                    ["Kodlama", "UTF-8, TCVN3, VNI-Windows… olarak yaz — 36 kodlama"],
                    ["Satır sonları", "LF (Unix) · CRLF (Windows) · CR (klasik Mac)"],
                    ["Ad ve konum", "Her macOS kaydetme penceresi gibi"],
                ]
            ),
            .paragraph("""
                Durum çubuğu her zaman kodlamayı, satır sonu biçemini ve algılanan dili gösterir. \
                **Herhangi birine tıklamak, bir pencereden geçmeden hemen değiştirir**.
                """),
            .heading("Çoğalt · yeniden adlandır · taşı"),
            .paragraph("""
                Bu üçü içerik yerine DOSYA üzerinde çalışır — ve açık sekme dosyayı izler, dolayısıyla \
                yerinizi asla kaybetmezsiniz.
                """),
            .table(
                headers: ["Komut", "Ne yapar"],
                rows: [
                    ["`Dosyayı Çoğalt`",
                     "Aslının yanına `ad 2.txt` olarak kopyalar ve **kopyayı açar** — çünkü insanlar kopyayı düzenlemek için çoğaltır"],
                    ["`Dosyayı Yeniden Adlandır…`", "Diskte yeniden adlandırır; sekme yeni adı izler"],
                    ["`Dosyayı Şuraya Taşı…`", "Başka klasöre taşır; sekme onu izler"],
                ]
            ),
            .note("""
                Üçü de hedefte **aynı adda bir dosya varsa reddeder**; asla üzerine yazmaz. Ayrıca üçü de \
                en az bir kez kaydedilmiş bir dosya gerektirir — hiç diske yazılmamış bir belgenin \
                çoğaltılacak ya da taşınacak bir şeyi yoktur.
                """),
            .heading("Güvenli yazma"),
            .bullets([
                "Yazma **atomiktir**: yarıda güç kesilmesi asla kırpılmış bir dosya bırakmaz.",
                "Siz açıkken başka bir program dosyayı değiştirirse GEditor bunu fark eder ve üzerine yazmadan önce sorar.",
                "iCloud Drive'daki ya da ağ birimindeki dosyalar sistemin dosya eşgüdümcüsünden geçer; böylece iki makine birbirinin ayağına basmaz.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Sekmeler, pencereler ve bölünmüş görünüm",
        summary: "Pencere başına çok sekme, çok pencere ve aralarında sürükleyebileceğiniz sekmeler.",
        keywords: ["sekme", "pencere", "böl", "bölme"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Yeni sekme"),
                HelpShortcut("⌘W", "Sekmeyi kapat"),
                HelpShortcut("⇧⌘T", "Son kapatılan sekmeyi yeniden aç"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Sonraki / önceki sekme"),
                HelpShortcut("⌥⌘N", "Yeni pencere"),
                HelpShortcut("⌃⌘N", "Geçerli sekmeyi kendi penceresine ayır"),
            ]),
            .paragraph("""
                Bir sekmeyi başka bir pencereye sürükleyebilir ya da yeni pencere yapmak için boş alana \
                bırakabilirsiniz. **Sabitlenmiş sekme yolculuk etmez** — sabitlemek \"bunu burada tut\" \
                demektir.
                """),
            .note("""
                `⇧⌘T`, **kaydedilmemiş** olan dahil son kapatılan sekmeyi yeniden açar: içeriği yerinde \
                durur.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Bir klasörü çalışma alanı olarak açmak",
        summary: "Kenar çubuğunda dosya ağacı, proje genelinde arama ve tek tıkla açma.",
        keywords: ["çalışma alanı", "klasör", "proje", "kenar çubuğu"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Bir klasörü çalışma alanı olarak aç")]),
            .paragraph("""
                Ağaç kenar çubuğunda görünür (`⌘0`). Açmak için bir dosyaya tıklayın; `⇧⌘F` ise klasörün \
                tamamında arar.
                """),
            .note("""
                App Store sürümünde klasöre erişim bir **güvenlik kapsamlı yer imiyle** tutulur; böylece \
                bir sonraki açılış, klasörü yeniden seçmenizi istemeden ona erişebilir.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Oturum kendini geri yükler",
        summary: "Çıkın ve yeniden açın: kaydedilmemişler dahil her sekme geri gelir.",
        keywords: ["oturum", "geri yükleme", "kaydedilmemiş", "kurtarma"],
        blocks: [
            .paragraph("""
                Açılacak bir şey yok. GEditor'dan çıkıp yeniden açın: sekmeler, sıraları, imleç \
                konumları ve kaydırma konumları geri gelir.
                """),
            .heading("Peki kaydedilmemiş sekmeler"),
            .paragraph("""
                İçerikleri ayrı bir anlık görüntüde tutulur, dolayısıyla onlar da geri gelir. Uygulama \
                olağandışı biçimde kapanırsa bir sonraki açılış, öksüz taslakları geri yüklemeden önce \
                **sorar** — hatırlamadığınız bir sekme yığınını sessizce yeniden kurmak yerine.
                """),
            .warning("""
                Oturum bir **yedek değildir**. Çalışma durumunu korur, geçmişi değil. Önemli olan her \
                şeyin yine de bir dosyaya kaydedilmesi gerekir.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Daha önce kaydedilmiş sürümler",
        summary: "Bir dosyanın eski sürümlerine göz atın ve geri yükleyin.",
        keywords: ["sürümler", "geçmiş", "geri yükle", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Her kaydetmede GEditor, üzerine yazmadan önce **önceki** sürümü kaydeder. `Makro ▸ \
                Kaydedilmiş sürümler…` onların tarayıcısını açar.
                """),
            .bullets([
                "Sürüm deposu **işletim sisteminindir**; Apple'ın kendi uygulamalarının kullandığı mekanizmanın aynısı.",
                "Eski bir sürümü geri yüklemek **sıradan bir düzenlemedir** — `⌘Z` onu geri alır.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Hâlâ yazılmakta olan bir dosyayı izlemek",
        summary: "`tail -f` gibi: sona eklenen her şey geldikçe görünür.",
        keywords: ["tail", "izle", "günlük", "gerçek zamanlı"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Dosya ▸ Dosyayı izle (tail -f)`, dosyanın sonunda beliren her şeyi yükler ve birlikte \
                kaydırır.
                """),
            .warning("""
                İzleme sırasında belge **salt okunur** olur. Diskten yeni metin yüklenirken yazmak, tek \
                belge üzerinde iki yazıcı demektir ve kaybeden hep az önce yazdığınızdır.
                """),
            .note("""
                Durum çubuğu boyunca **İzleniyor** yazar; böylece dakikalar sonra bile dosyanın neden \
                yazı kabul etmediğini bilirsiniz. **Salt okunur** bölümüne tıklamak nedeni açıkça söyler.

                İzleme, pencereye değil, **onu başlatan sekmeye** aittir: başka bir sekme açıp yazmayı \
                sürdürün; yeni günlük satırları düzenlediğiniz dosyaya dokunmadan kendi sekmesine akmayı \
                sürdürür.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Yazdırma",
        summary: "Standart macOS yazdırma penceresinden yazdırın.",
        keywords: ["yazdır", "kâğıt", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Yazdır")]),
            .paragraph("""
                Sistem yazdırma penceresini kullanır; dolayısıyla PDF'e aktarma da orada olur — sol \
                alttaki `PDF` düğmesi.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Görüntüler, PDF'ler, Office dosyaları, ses, video ve arşivler",
        summary: "Sekiz tür dosya, başka bir uygulama olmadan GEditor içinde açılır.",
        keywords: ["görüntü", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arşiv",
                   "ses", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Tür", "Yapabilecekleriniz"],
                rows: [
                    ["Görüntüler", "Görüntüle, yakınlaştır, döndür; **hareketli görüntüler oynar** ve duraklatılabilir"],
                    ["Ses", "Çal, sar, ses düzeyini değiştir"],
                    ["Video", "Oynat, sar, tam ekran, resim içinde resim"],
                    ["PDF", "Oku, ara, **açıklama ekle**"],
                    ["Word · Excel · PowerPoint", "Görüntüle **ve düzenle** — `⌘S` doğrudan dosyaya geri yazar"],
                    ["ZIP · TAR · GZ · XZ", "Girdileri listele ve her birini sekme olarak aç"],
                    ["7z · RAR ve yedi biçim daha", "Aynısı, libarchive ile"],
                ]
            ),
            .paragraph("""
                Bir arşivin içindeki girdiyi açmak, o girdinin içeriğiyle yeni bir sekme oluşturur. \
                Vietnamca aksanlar hem adlarda hem içerikte sağ çıkar.
                """),
            .note("""
                Üç Office biçiminden birini düzenleyin, `⌘S`'ye basın; dosyaya geri yazılır — sonucu \
                LibreOffice okur. Bu yol baştan sona sınanmıştır, yalnızca bir kopyaya aktarılmış \
                değildir.
                """),
            .heading("Ses ve video macOS oynatıcılarını kullanır"),
            .paragraph("""
                Oynatma sistemin kendi çözücülerinden geçer; böylece fazladan hiçbir şey indirilmez ve \
                fazladan hiçbir şey dağıtılmaz. Karşılığında birkaç biçim **oynatılmaz** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — çünkü macOS'ta bunlar için yerleşik çözücü yoktur.
                """),
            .paragraph("""
                Böyle bir dosya için GEditor siyah bir dikdörtgen göstermek yerine **nedenini söyler** ve \
                ikili görüntüleyiciyi ya da başka bir uygulamayı önerir.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF araçları",
        summary: "Okuma, açıklama ve bütün bir sayfa katmanı: döndür · taşı · sil · çıkar · birleştir.",
        keywords: ["pdf", "sayfa", "döndür", "sayfa sil", "çıkar", "birleştir", "böl",
                   "açıklama", "vurgula", "imzala"],
        blocks: [
            .paragraph("""
                PDF görünümünün **iki araç çubuğu** vardır ve farklı sorulara yanıt verirler. Üst sıra \
                tek bir sayfanın **içeriği** üzerinde çalışır; alt sıra **sayfa kümesi** üzerinde.
                """),
            .heading("Üst sıra — okuma ve açıklama"),
            .table(
                headers: ["Düğme", "Ne yapar"],
                rows: [
                    ["Vurgula · Altını çiz", "Seçili metni imler"],
                    ["Not…", "Sayfaya bir not iliştirir"],
                    ["Açıklamaları kaldır", "Geçerli sayfadaki her açıklamayı temizler"],
                    ["Metni yeni sekmeye çıkar", "Tüm metni bir sekmeye taşır; böylece arayabilir, süzebilir, başka araçlar çalıştırabilirsiniz"],
                    ["Arama alanı", "PDF içinde arar — **aksansız yazmak yine aksanlı metni bulur**"],
                ]
            ),
            .note("""
                Taranmış bir PDF'te metin katmanı yoktur. Çıkarma komutu boş bir sekme açıp sizi tahmine \
                bırakmak yerine **bunu söyler**.
                """),
            .heading("Alt sıra — sayfa işlemleri"),
            .table(
                headers: ["Düğme", "Ne yapar", "Geri alınır"],
                rows: [
                    ["Sola · sağa döndür", "Geçerli sayfayı 90° çevirir", "Evet"],
                    ["Sayfayı yukarı · aşağı", "Geçerli sayfayı komşusuyla değiştirir", "Evet"],
                    ["Sayfaları sil…", "Aralığa göre siler, örn. `2-4,7`", "Evet"],
                    ["Sayfaları çıkar…", "Bir sayfa aralığını **yeni bir dosya** olarak yazar", "Açık dosyaya dokunmaz"],
                    ["Bir PDF birleştir…", "Başka bir PDF'i geçerli sayfanın hemen ardına ekler", "Evet"],
                    ["İmzala…", "Geçerli sayfaya bir imza görüntüsü yerleştirir", "Evet"],
                    ["Metni düzenle…", "Seçimin üzerine yerine geçecek metni çizer", "Evet"],
                    ["Sonraki boş alan", "Doldurulmamış bir sonraki form alanına atlar", "—"],
                    ["Doldurulmuş değerleri temizle", "Her form alanını boşaltır", "Evet"],
                    ["Sayfa değişikliğini geri al", "Bir sayfa işlemi geri gider", "—"],
                    ["Düzenlenmiş kopyayı kaydet…", "Yeni bir dosya yazar, sonra **doğrulamak için yeniden açar**", "—"],
                ]
            ),
            .heading("Doldurulabilir formlar"),
            .paragraph("""
                Form alanları olan bir PDF açın; durum çubuğu **kaç tane** olduğunu söyler. Sayfadaki \
                alanlara doğrudan yazın, sonra `Düzenlenmiş kopyayı kaydet…`.
                """),
            .bullets([
                "Değerler düzleştirilmiş metin olarak değil, **canlı form alanları** olarak saklanır — böylece alıcının Acrobat'ı yine doldurulmuş bir form görür ve düzeltebilir.",
                "Vietnamca aksanlar yaz-ve-yeniden-aç turunu sağ atlatır. Bunu tam olarak `Nguyễn Văn Anh` adıyla bir sınama korur.",
                "`Sonraki boş alan` bir sonraki boşluğa atlar — uzun bir formda doğal yol.",
            ]),
            .heading("İmzalama"),
            .paragraph("""
                Bir imza görüntüsü hazırlayın (saydam arka planlı bir PNG en iyisidir), **imzalanacak \
                yeri seçin** — genellikle çizgi ya da \"İmza\" sözcüğü — sonra `İmzala…`'ya basın. Hiçbir \
                şey seçili değilse imza sağ alta gelir.
                """),
            .note("""
                İmza, görüntünün **en-boy oranını** korur: ezilmiş ya da gerilmiş bir imza anında sahte \
                görünür.
                """),
            .heading("Metni düzenlemek — ve önce bilinmesi gereken üç şey"),
            .paragraph("""
                Değiştirilecek metni seçin ve `Metni düzenle…`'ye basın. GEditor **o alanı, hemen \
                yanından örneklenmiş bir arka plan rengiyle örter**, sonra yeni metni üstüne çizer.
                """),
            .warning("""
                **Eski metin ÖRTÜLÜR, KALDIRILMAZ.** Hâlâ dosyadadır ve `Metni yeni sekmeye çıkar` ya da \
                başka herhangi bir araçla hâlâ çıkarılabilir. Bu **karartma değildir** — bir kimlik \
                numarasını böyle gizlemek, onu insan gözünden gizler, makineden değil.
                """),
            .bullets([
                "**Yeni metin `⌘F` ile hâlâ bulunabilir.** Görüntü olarak değil, gerçek metin olarak çizilir — varsayılmadı, sınamayla ölçüldü.",
                "**Yazı tipi bir sistem yazı tipidir**, belgenin özgün yazı tipi değil. Bilerek: PDF'e gömülü yazı tiplerinde çoğu kez Vietnamca aksanlar yoktur ve `Nguyễn`, `Nguy?n` olarak gelirdi.",
                "**Desenli bir arka planda yama belli olur** — örtme rengi, seçimin hemen solundaki tek bir noktadan örneklenir.",
            ]),
            .heading("İçerik akışını düzenlemek yerine neden üzerine çizmek"),
            .paragraph("""
                Bir PDF içerik akışını doğrudan düzenlemek; kendi kodlamasını taşıyan alt küme yazı \
                tipleriyle, harf aralığı yüzünden üç parçaya bölünmüş cümlelerle ve yeniden hesaplanması \
                gereken karakter genişliği tablolarıyla uğraşmak demektir. Bunu **her** dosya için doğru \
                yapmak başlı başına bir projedir; yanlış yapmak birinin belgesini bozar.
                """),
            .paragraph("""
                Karşılığında sayfanın geri kalanı **tek bir bayt bile değişmez** ve sayfa sayfa olarak \
                kalır — metin hâlâ seçilir, kopyalanır ve aranır. Yeniden çizmek onu bir görüntüye \
                **dönüştürmez**.
                """),
            .heading("Sayfa aralığı sözdizimi"),
            .table(
                headers: ["Yazın", "Anlamı"],
                rows: [
                    ["`5`", "Yalnızca 5. sayfa"],
                    ["`2-4`", "2., 3., 4. sayfalar"],
                    ["`-3`", "Baştan 3. sayfaya kadar"],
                    ["`8-`", "8. sayfadan sona kadar"],
                    ["`1-3,5,9-`", "Virgülle birleştirilmiş birkaç parça"],
                ]
            ),
            .paragraph("Sayfalar ekranda gördüğünüz sayı olan **1'den** başlar."),
            .warning("""
                Ters bir aralık (`5-2`) ve sonu aşan bir aralık (`1-999`) ikisi de **gerekçesiyle \
                reddedilir**, asla sessizce yakın bir şeye düzeltilmez. Sayfa silme komutunda yanlış \
                tahmin sayfa kaybetmek demektir ve sessizce kırpmak bir yazım yanlışını geçerli bir \
                komuta çevirir.
                """),
            .heading("Özgün dosyanın üzerine asla yazılmaz"),
            .paragraph("""
                Yukarıdakilerin tümü belgeyi **bellekte** değiştirir. Ancak `Düzenlenmiş kopyayı \
                kaydet…`'e basıp bir konum seçtiğinizde bir dosya yazılır — ve yazdıktan sonra GEditor, \
                tüm sayfalarının hâlâ yerinde olduğunu doğrulamak için **tam da o dosyayı yeniden açar**.
                """),
            .paragraph("""
                Nedeni: kötü yazılmış bir dosya diskte gayet normal görünerek durur ve kullanıcı bunu \
                ancak gönderdikten sonra öğrenir.
                """),
            .note("""
                Görünümün durum satırı, belge diskteki dosyadan farklı olduğu her an **· düzenlendi, \
                kaydedilmedi** yazar.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
