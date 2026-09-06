import Foundation

/// Türkçe yardım kitabı — 3. bölüm: görünüm biçimleri, Vietnamca, diller ve biçimler.
extension HelpTR {

    static let views = HelpChapter(
        id: "xem",
        title: "Bir belgeye bakma biçimleri",
        summary: "Kenar çubuğu, harita, katlama, bölünmüş görünüm, satır kaydırma, görünmez karakterler, renklendirme kipleri.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Kenar çubuğu ve işlev listesi",
        summary: "Klasör ağacı ile açık dosyanın işlev listesi tek sütunda.",
        keywords: ["kenar çubuğu", "işlev listesi", "anahat", "dosya ağacı"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Kenar çubuğunu göster / gizle")]),
            .paragraph("""
                İşlev listesi dilin **sözdizimi ağacından** kurulur; böylece girintiden tahmin etmek \
                yerine gerçek yapıyı izler. Oraya atlamak için bir girdiye tıklayın.
                """),
            .note("İşlev listesindeki süzme kutusu, **aksansız yazımdan aksanlı metni bulur**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Belge haritası",
        summary: "Sağda dar bir sütunda tüm dosya — yüzlerce MB'ta bile.",
        keywords: ["mini harita", "harita", "genel bakış"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Belge haritasını göster / gizle")]),
            .paragraph("""
                Harita yalnızca ekrandakini değil, **tüm dosyayı** betimler. Üzerinde sürüklemek \
                eşleşen bölgeye atlar.
                """),
            .paragraph("""
                Arama isabetleri ve imlenmiş satırlar haritada görünür; böylece oraya kaydırmadan önce \
                dağınık mı, kümelenmiş mi olduklarını görebilirsiniz.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Katlama",
        summary: "İşlevleri, blokları ve dizileri yapıya göre katlayın — ya da dosyayı bir düzeye kadar katlayın.",
        keywords: ["katla", "kod katlama", "daralt"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "İmleçteki bloğu katla / aç"),
                HelpShortcut("⌥⇧⌘←", "Tümünü katla"),
                HelpShortcut("⌥⌘→", "Tümünü aç"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Tüm dosyayı 1…8 düzeyine katla"),
            ]),
            .paragraph("""
                Sözdizimi ağacı olan diller için katlama **gerçek yapıyı** izler. Dil bilgisi olmayan \
                dosyalarda girintiyi izler.
                """),
            .paragraph("""
                `Düzeye katla`, derin JSON ve YAML'de hakkını verir: 2. düzeye katlamak tüm dosyanın \
                biçimini tek ekrana sığdırır.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Bölünmüş görünüm",
        summary: "Yan yana iki bölme; iki dosya için — ya da bir dosyanın iki yeri için.",
        keywords: ["böl", "bölmeler", "karşılaştır"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Dikey böl"),
                HelpShortcut("⌥⌘-", "Yatay böl"),
                HelpShortcut("⌥⌘0", "Bölmeyi kaldır"),
                HelpShortcut("⌥⌘]", "Bu sekmeyi diğer bölmede aç"),
                HelpShortcut("⌥⌘[", "Diğer bölmeye atla"),
            ]),
            .paragraph("""
                Her bölmenin kendi sekme çubuğu vardır. **Aynı dosyayı** her iki bölmede açmak sorun \
                değildir — bağımsız kaydırırlar, bu da bir dosyanın başını ve sonunu karşılaştırmayı \
                kolaylaştırır.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Satır kaydırma",
        summary: "Üç kip: kapalı, pencere kenarında ya da sabit bir sütunda.",
        keywords: ["satır kaydırma", "kaydırma", "yumuşak kaydırma"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Kip", "Uzun bir satır"],
                rows: [
                    ["Kapalı", "Yatay kayar"],
                    ["Pencerede", "Pencere kenarında, boyutunu izleyerek kaydırır"],
                    ["Bir sütunda", "Belirlediğiniz sütunda kaydırır — diyelim 80 ya da 100"],
                ]
            ),
            .paragraph("""
                Kaydırma bir **bakma biçimidir**, düzenleme değil: hiçbir satır sonu eklenmez ve asla \
                geri alma geçmişine girmez.
                """),
            .note("""
                Buraya en hızlı yol, durum çubuğundaki `Ngắt: …` bölümüdür.
                """),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Yazı tipi boyutu",
        summary: "8 ile 32 pt arasında yakınlaştırın.",
        keywords: ["yakınlaştır", "yazı boyutu", "büyük", "küçük"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Daha büyük metin"),
                HelpShortcut("⌘-", "Daha küçük metin"),
                HelpShortcut("⌃⌘0", "Öntanımlı boyuta dön"),
            ]),
            .paragraph("""
                8 ile 32 pt arasında sınırlıdır. Bu da bir **bakma biçimidir**: düzenleme yok, geri alma \
                geçmişinde bir şey yok. Öntanımlı boyut `Ayarlar…` içindedir.
                """),
            .note("`⌘0` öntanımlı boyut DEĞİLDİR — o tuş kenar çubuğunu gösterip gizler."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Görünmez karakterleri göstermek",
        summary: "Her seferinde bir grubu açın; çünkü hepsi birden genellikle fazla gelir.",
        keywords: ["görünmez", "boşluk", "nbsp", "sıfır genişlik", "sekme"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Tüm görünmez karakterleri göster / gizle")]),
            .paragraph("""
                Dört grup ayrı ayrı açılır; çünkü hepsini birden açmak içeriği bir nokta ormanının \
                altına gömer.
                """),
            .table(
                headers: ["Grup", "Neyi yakalar"],
                rows: [
                    ["Boşluklar", "Satır sonu boşlukları, tutarsız girintiler"],
                    ["Sekmeler", "TAB ile boşluğu karıştıran dosyalar"],
                    ["Satır sonları", "CRLF ile LF'i karıştıran dosyalar"],
                    ["NBSP · sıfır genişlik · denetim", "Word'den, ağdan, hesap tablolarından gelen görünmez karakterler"],
                ]
            ),
            .warning("""
                İnsanları kurtaran grup sonuncusudur. Bir web sayfasından yapıştırılan bölünmez boşluk \
                (NBSP), sıradan bir boşluğa **tıpatıp** benzer; oysa her dize karşılaştırmasını ve her \
                süzmeyi ıskalatır — ve bu grup açık olmadan onu görmenin yolu yoktur.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV kipi ve Günlük kipi",
        summary: "Sözdizimi vurgulamasının yerini alan iki renklendirme düzeni, iki tür veri dosyası için.",
        keywords: ["csv kipi", "günlük kipi", "vurgulama", "sütunlar", "günlük düzeyi"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV kipi"),
            .paragraph("""
                **Metin** görünümünde her sütuna kendi rengini verir; böylece ızgaraya geçmeden hangi \
                hücrenin bir sütun kaydığını görebilirsiniz.
                """),
            .heading("Günlük kipi"),
            .paragraph("""
                Satırdan okuduğu **önem derecesine** göre renklendirir: hatalar kırmızı, uyarılar kehribar; \
                `debug` ve `trace` ise soluklaştırılır — bir günlük dosyasının çoğunu onlar oluşturur ve \
                onları vurgulamak asıl aradığınız şeyi soluklaştırır.
                """),
            .paragraph("""
                `Günlüğü düzeye göre süz…` hiç gerekmeyen düzeyleri tümüyle gizler.
                """),
            .note("""
                Bu ikisi sözdizimi vurgulamasının üstüne değil, **yerine** renklendirir. Bir günlük \
                dosyasının renklendirilecek sözdizimi yoktur ve aynı bayt aralığına yazan iki renk \
                kaynağı, öngörülebilir bir kazanan bırakmaz.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown önizlemesi",
        summary: "Markdown'ı biçimlendirilmiş metin olarak çizer — ve neyi çizmediğini açıkça söyler.",
        keywords: ["markdown", "önizleme", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Sistemin Markdown desteğiyle çizilir: kalın, italik, kod, bağlantılar, listeler.
                """),
            .warning("""
                **Tablo yok ve kod blokları içinde sözdizimi renklendirmesi yok.** Önizleme penceresi \
                bunu altında söyler. **4 MB**'tan büyük belgeler reddedilir.
                """),
            .paragraph("""
                Yayımlayabileceğiniz bir belgede tablo ve grafik mi gerekiyor? Bunun için `.greport.md` \
                raporları vardır, bu önizleme değil.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "İkili görünüm",
        summary: "Her dosya için bir onaltılık tablo — 1 GB'lık olan dahil, neredeyse anında açılır.",
        keywords: ["onaltılık", "ikili", "bayt", "kayma", "döküm"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Görünüm ▸ İkili görünüm` her baytı üç sütunlu bir tablo olarak gösterir: **kayma · \
                onaltılık · metin**. Yalnızca görüntü ya da video için değil, diskteki **her** dosya için \
                çalışır.
                """),
            .table(
                headers: ["Sütun", "İçerik"],
                rows: [
                    ["Kayma", "Bayt konumu, onaltılık olarak"],
                    ["Onaltılık", "Satır başına 16 bayt, saymayı kolaylaştırmak için sekizincinin ardından ayrılmış"],
                    ["Metin", "Yazdırılabilir ASCII baytları; geri kalan her şey `.`"],
                ]
            ),
            .note("""
                Metin sütunu **UTF-8'i çözmez**. Vietnamca bir harf iki ya da üç bayt tutar; onu çizmek \
                metin sütununu onaltılık sütunla hizasız bırakırdı — ve o hizalama sütunun bütün \
                amacıdır. Aksanlı metni okumak için olağan görünümü kullanın.
                """),
            .heading("Büyük dosyalar"),
            .paragraph("""
                Dosya **belleğe eşlenir**; dolayısıyla 1 GB'lık bir dosyayı ikili görünümde açmak \
                yalnızca baktığınız kadarına mal olur. Öz sınama takımında ölçüldü: **bir milisaniyenin \
                altında**.
                """),
            .paragraph("""
                Görünüm bir kerede **tek bir 4 MB'lık pencere** gösterir ve üst çubuk hangi aralıkta \
                olduğunuzu söyler. Bu, okumanın değil, sistemin tablo çizicisinin bir sınırıdır: 1 GB'lık \
                bir dosya 62,5 milyon satırdır ve belli bir noktadan sonra satırlar kaydırma sırasında \
                zıplamaya başlar — zıplayan bir onaltılık tablo ise işe yaramaz.
                """),
            .heading("Bir konuma atlamak"),
            .table(
                headers: ["Kayma kutusuna yazın", "Anlamı"],
                rows: [
                    ["`1F400`", "Onaltılık — öntanımlı"],
                    ["`0x1F400`", "Aynısı, açık önekle"],
                    ["`#128000`", "Ondalık; onaltılık kayma yerine bayt sayınız olduğunda"],
                ]
            ),
            .bullets([
                "`‹` ve `›` önceki / sonraki pencereye gider.",
                "**Seçili satırları kopyala** tam olarak gördüğünüzü kopyalar — hiçbir şey seçili değilse tüm pencereyi kopyalar.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "İki kip: Görünüm ve Kod",
        summary: "Tek tuş, her dosya türü için çizilmiş biçim ile düzenlenebilir kaynak arasında geçiş yapar.",
        keywords: ["görünüm", "kod", "kip", "kaynak", "çizilmiş", "önizleme"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Görünüm ile Kod arasında geçiş yap")]),
            .paragraph("""
                Denetim, **sekme şeridinin hemen altındaki çubuktadır** — her dosya türü için aynı yer: \
                bir `View | Code` anahtarı, ardından o dosyanın Görünüm kipinin adı (\"Belge sayfaları\", \
                \"Anahtar–değer ağacı\", \"Diyagram\"…). Yalnızca tek kipi olan bir dosyada anahtar \
                soluklaşır ve çubuk nedenini söyler. Sağ kenarda her türün kendi düğmeleri durur: \
                `.xlsx`'in **Izgara**'sı (düzenlenebilir, doğrudan geri yazılır), `.pptx`'in **Anahat**'ı.
                """),
            .note("""
                **Word ve PowerPoint bir belge okuyucusu gibi davranır.** Görünüm kipleri gerçek sayfalar \
                kurar — doğru yazı tipleri, boyutlar ve renkler; görüntüler, tablolar, sayfa numaraları \
                dahil üst ve alt bilgiler. Bir sayfa **tam olarak çerçeve kadar geniştir** ve \
                yakınlaştırılır. Excel bilerek bir istisnadır: Görünümü **düzenlenebilir bir hesap \
                tablosudur**, çünkü bir hesap tablosunun yazdırılana dek kâğıt boyutu yoktur.
                """),
            .note("""
                Karşılığında sayfalar **salt okunurdur** ve **diskteki kopyayı** çizer: Kod'da kaydetmeden \
                düzenleyin, sayfalar eski sürümü gösterir — çubuk bunu bir `Kaydet ve yeniden çiz` \
                düğmesiyle söyler.
                """),
            .heading("Tanımlar"),
            .bullets([
                "**Kod**, **düzenlenebilir kaynaktır**. Metin dosyası için bu metnin kendisidir. İkili bir dosya için — PDF, görüntü, ses, video — metinsel bir kaynak yoktur, dolayısıyla Kod, onaltılık olarak gösterilen **baytlardır**.",
                "**Görünüm**, Kod'dan **çizilen** şeydir. Daha güzel, daha kısa ya da çalıştırılabilir olabilir — ama her zaman bir sonuçtur, asla özgün değil.",
            ]),
            .paragraph("""
                Bir PDF için *\"bu türün Kod'u yok\"* demek kullanışlı olurdu ama yanlış olurdu: baytlar \
                gerçekten onun kaynağıdır.
                """),
            .heading("Düzenleme nerede olur"),
            .paragraph("""
                Düzenleme **Kod'da** olur. Tam olarak **iki istisna** vardır ve ikisi de Görünüm'de \
                düzenlemek çok daha doğal olduğu için: **CSV ızgara hücreleri** ve **PDF form alanları**. \
                İkisi de doğrudan kaynağa yazar; böylece tartışacak ikinci bir kopya belirmez.
                """),
            .heading("Dosya türüne göre"),
            .table(
                headers: ["Dosya türü", "Görünüm", "Kod", "Düzenleme"],
                rows: [
                    ["CSV · TSV", "Izgara", "Ham metin", "**İkisinde**"],
                    ["Excel `.xlsx`", "Açık sayfanın ızgarası", "O sayfa CSV olarak", "**İkisinde**"],
                    ["PDF", "Çizilmiş sayfalar", "İkili", "**İkisinde** — açıklamalar, form alanları, sayfalar"],
                    ["Markdown `.md`", "Çizilmiş metin", "Markdown kaynağı", "Kod"],
                    ["Rapor `.greport.md`", "Sorguları çalıştırılmış, grafikleri çizilmiş rapor", "Kaynak", "Kod"],
                    ["JSON", "Katlanabilir anahtar–değer ağacı", "JSON kaynağı", "Kod"],
                    ["XML · HTML", "Katlanabilir etiket ağacı", "XML kaynağı", "Kod"],
                    ["YAML", "Girintiye göre anahtar–değer ağacı", "YAML kaynağı", "Kod"],
                    ["Diyagramlar `.mmd` · `.dot`", "Sekmeyi dolduran çizilmiş diyagram", "mermaid ya da DOT kaynağı", "Kod"],
                    ["Word `.docx`", "Çizilmiş belge sayfaları", "Çıkarılmış Markdown", "Kod"],
                    ["PowerPoint `.pptx`", "Çizilmiş slayt sayfaları", "Markdown anahat", "Kod"],
                    ["Günlük dosyaları", "Düzeye göre renkli, süzülebilir", "Ham metin", "Kod"],
                    ["Görüntüler", "Görüntü (hareketli olanlar oynar)", "İkili", "Salt okunur"],
                    ["Ses · video", "Bir oynatıcı", "İkili", "Salt okunur"],
                    ["Arşivler", "Girdi listesi", "İkili", "Salt okunur"],
                    ["Kaynak kod, düz metin", "— yok", "Metnin kendisi", "Kod"],
                ]
            ),
            .note("""
                Kaynak kodun **Görünümü yoktur** ve bu bir eksiklik değil, olağandır: bir Swift dosyasının \
                bakmaya değer çizilmiş bir biçimi yoktur.
                """),
            .heading("Word ve PowerPoint için sayfa okuyucusu"),
            .paragraph("""
                Sayfalar dikey olarak yığılır ve sürekli kayar; her biri gri arka planda beyaz bir yaprak \
                — her belge okuyucusundaki gibi. Denetimleri çubuğun sağındadır.
                """),
            .table(
                headers: ["Düğme / tuş", "Ne yapar"],
                rows: [
                    ["`Genişliğe sığdır`", "Yaprak tam çerçeve kadar geniş — öntanımlı"],
                    ["`Sayfaya sığdır`", "Tüm yaprak çerçeveye sığar"],
                    ["`−` `+`", "Adım adım yakınlaştır; ya da kıstırma ya da ⌘ + kaydırma"],
                    ["`Bul` kutusu ya da ⌘F", "Sayfaların içinde ara, oraya atla ve vurgula"],
                    ["Bul kutusunda Enter", "Sonraki eşleşme"],
                    ["Sürükleme", "Metin seç; sözcük için çift, paragraf için üç tıklama"],
                    ["⌘A · ⌘C", "Tümünü seç · seçimi kopyala"],
                    ["Page Up · Page Down · Home · End", "Belge içinde hareket"],
                ]
            ),
            .paragraph("""
                Bul kutusu **aksanları ve harf durumunu yok sayar**: `vuong quoc` yazmak `Vương quốc`'u \
                bulur. Çubuktaki \"Sayfa 12/363\" etiketi nerede olduğunuzu söyler.
                """),
            .note("""
                **Çizilmeyenler, açıkça:** kayan bağlantılı görüntüler (metnin resmin çevresinden akması) \
                satır içi görüntü olarak görünür; dipnotlar, grafikler ve PowerPoint SmartArt çizilmez. \
                Yazdırılmış kopyayla birebir eşleşme gerektiğinde Word'de açın.
                """),
            .heading("Bir düğüme tıklamak kaynağa geri atlar"),
            .paragraph("""
                Bir JSON ağacı süslü bir çıktı değildir: bir düğüme tıklamak imleci metinde **o düğümün \
                DEĞERİNE** taşır ve sekmeyi Kod'a döndürür — çünkü sıradaki isteğiniz neredeyse her zaman \
                az önce tıkladığınızı düzenlemektir.
                """),
            .bullets([
                "Kapsayıcı düğümler içerikleri yerine **öge sayılarını** gösterir (`{12}`, `[340]`) — \"bunu açmaya değer mi\" sorusunu yanıtlayan budur.",
                "**İlk iki düzey** açıktır: on bin düğümlü bir dosyayı tümüyle açmak kaynaktan uzun bir liste üretir; tümüyle katlamak ise herhangi bir şeyi keşfetmek için tıklamak demektir.",
                "**Geçersiz sözdizimli** bir dosya yarım ağaç almaz — kırpılmış bir ağaç, gerçekten o kadar az şey içeren bir belge gibi görünür.",
                "XML ağacında öznitelikler düzgün XPath gösterimiyle `@` öneki taşır ve **etiketler arasındaki boşluk düğüm olmaz** — o biçimlendirmedir, içerik değil.",
                "YAML ağacı **çok belgeli dosyaları** (`---`) okur: her belge kendi köküdür. Satır içi yazılmış koleksiyonlar (`ports: [80, 443]`) tek yaprak kalır — zaten hepsini görüyorsunuz, açmak bir tıklamaya mal olur. **Sekmeyle girinti** tam satırıyla bildirilir: bu, gözün göremediği bir YAML hatasıdır.",
                "PowerPoint anahatı diskteki dosyadan değil, **açık metinden** kurulur: anahatı Kod'da az önce düzenlediyseniz, ağaç yeni sürümü betimlemeli ve düğümleri o yeni sürüme atlamalıdır. Sunucu notları tek düğümde toplanır; böylece çok şey söyleyen bir slayt, çok şey içeren bir slayt gibi görünmez.",
                "**Sekmeyi dolduran diyagram da aynı kuralı izler**: bir düğüme tıklayın, imleç o düğümün bildiriminde olacak biçimde Kod'a dönersiniz. Yan yana `Mermaid Studio` panelinde sekme kapanmaz — düzenleyici zaten oradadır ve imleci taşımak görmeye yeter.",
                "Diyagramlar ayrıca **durduğunuz yerde açılır**: imlecin satırıyla eşleşen öge, sekme belirdiği anda vurgulanır; böylece onu aramak zorunda kalmazsınız.",
            ]),
            .heading("Süzme kutusu: on bin düğümlü bir ağaçta iş, aramaktır"),
            .paragraph("""
                Düğüm sayısının hemen altında bir süzme kutusu vardır. Oraya yazın; ağaç yalnızca eşleşen \
                düğümleri tutar — **kökten onlara inen yolla birlikte**; çünkü bir `name` anahtarı on ayrı \
                yerde geçtiğinde asıl soru \"hangisi\"dir ve buna yalnızca onu içeren dal yanıt verir. \
                Gerisi sizin için açılır: her düzeyi tıklatarak açtırmak, elle yeniden süzdürmektir.
                """),
            .bullets([
                "Hem **etiketlere hem değerlere** göre süzer: `Huế` aramak, `province` anahtarını aramak kadar sıradandır.",
                "**Aksansız yazmak yine aksanlı metinle eşleşir** — `da nang`, `Đà Nẵng`'ı bulur. CSV ızgarasının süzmesiyle ve işlev listesininkiyle aynı karşılaştırma; böylece tek uygulamada üç arama kuralı hatırlamak zorunda kalmazsınız.",
                "Eşleşme yoksa başlık, sizi boş bir ağaca bakıp dosyanın bozuk olup olmadığını düşünmeye bırakmak yerine **\"Sonuç yok\"** der.",
                "Dosya değiştirmek ya da Görünüm'e yeniden girmek **süzmeyi temizler**: nedenini açıklayan hiçbir şey olmadan zaten kırpılmış açılan bir ağaç, en kafa karıştırıcı durumdur.",
            ]),
            .heading("Bütün ağaç klavyeden çalışır"),
            .paragraph("""
                Görünüm'e girmek odağı ağaca taşır; önce tıklamanız gerekmez. Yukarı ve aşağı düğümler \
                arasında gezinir, sol ve sağ katlar ve açar; iki tuş ise bir bakma oturumunu bitirir — \
                **farklı** işler yaparak:
                """),
            .bullets([
                "**Enter** — seçili düğüme git: imleç o düğümün bayt aralığının içinde olacak biçimde Kod'a dön. Tıklamakla tıpatıp aynı.",
                "**Tab** — ağaç ile süzme kutusu arasında geçiş.",
                "**⌘C** — ağacın arkasındaki metni değil, seçili düğümün **yolunu** kopyalar. JSON ve YAML, bu ürünün kendi JSONPath sorgu kutusuna ya da `yq`'ya doğrudan yapıştırılan JSONPath (`$.customer['name']`) üretir; XML, iki etiket bir adı paylaştığında dizinlerle XPath (`/order/item[2]/@code`) üretir; PowerPoint anahatı satırın metnini kopyalar, çünkü bir anahatın uydurulacak bir yol dili yoktur.",
                "**Esc** — dönüş yolu: imleç **tam bıraktığınız yerdeyken** Kod'a dön. Bir ağaca bakıyordunuz, bir yere yolculuk etmiyordunuz.",
            ]),
            .heading("Ve öbür yön: ağaç imlecin durduğu yerde açılır"),
            .paragraph("""
                On bin satırlık bir dosyanın ortasından Görünüm'e girmek ağacı tepeden **açmaz**: imlecin \
                bulunduğu yere karşılık gelen düğüme inen yolu açar ve onu seçer. Bu, kaynağa atlamanın \
                diğer yarısıdır — o olmadan Görünüm ve Kod, tek belgenin yalnızca **tek** yönde iki \
                görünümü olurdu.
                """),
            .bullets([
                "Gerektiğinde **iki düzeyden derine** açar: iki düzey kuralı \"bu dosya neye benziyor\" sorusunu yanıtlar; burada soru başkadır — \"bu ağaçta neredeyim\".",
                "Bir **anahtarın** üzerindeki imleç (`\"address\":`) o girdiyi seçer; düğümün bayt aralığı yalnızca değeri kapsasa bile. Bir düğümün hemen öncesindeki metin o düğüme aittir.",
                "Bir **bloğun başındaki** imleç — bir YAML bloğunun anahtarı, bir slayt başlığı, bir XML etiket adı — ilk çocuğuna dalmak yerine o bloğu seçer.",
                "Görünüm'e girmek **imleci taşımaz**. Görünüm'den çıkın, tam bıraktığınız yerdesiniz; Görünüm bir bakma biçimidir, konumu değiştiren bir komut değil.",
            ]),
            .heading("Artık hiçbir türde eksik Görünüm yok"),
            .paragraph("""
                **Görünüm kipine yeri olan her dosya türü artık bir tane çiziyor.** Eksik türler listesi \
                boşaldı ve kaldırıldı.

                Kaynak kodun ve düz metnin hâlâ Görünümü yok — bu bir eksiklik değil, olağandır; \
                dolayısıyla o listede hiç yer almamışlardı.

                Görünümü henüz kurulmamış yeni bir dosya türü gelirse, geçiş komutu boş bir çerçeve açmak \
                yerine bunu söyleyecek ve neyin eksik olduğunu adlandıracaktır — boş bir çerçeve boş bir \
                sözdür, adı konmuş bir ret ise bilgidir.
                """),
            .heading("Altı eski komut hâlâ yerinde"),
            .paragraph("""
                `Izgara / metin görünümü`, `Markdown önizlemesi`, `İkili görünüm`, `Rapor önizlemesi`, \
                `Mermaid diyagram önizlemesi`, `Günlük kipi` — hepsi tam bıraktıkları yerde duruyor. \
                `⌥⌘V` bir **ortak giriştir**, yerine geçen değil.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamca

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamca",
        summary: "Eski kodlamalar, Unicode normalleştirme, aksan duyarsız arama ve giriş yöntemleri.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamca kodlamalar",
        summary: "TCVN3, VISCII, VNI-Windows ve 33 kodlamayı daha okur ve yazar; kendiliğinden algılar.",
        keywords: ["kodlama", "tcvn3", "abc", "viscii", "vni", "bozuk metin", "bozuk yazı tipi"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Eski bir Vietnamca dosya açtınız ve `Trường Đại học` yerine `Tr¦êng §¹i häc` mi geldi? \
                Dosya bozuk değil — Unicode öncesi bir kodlamayla kaydedilmiş.
                """),
            .steps([
                "**Durum çubuğundaki** kodlamaya tıklayın (ya da `Biçim ▸ Kodlama…`).",
                "Doğrusunu seçin — eski Vietnamca dosyalarda bu genellikle `TCVN3 (ABC)`, `VNI-Windows` ya da `VISCII`'dir.",
                "Metin hemen düzelir; dosyayı yeniden açmaya gerek yoktur.",
                "Böyle kalması için `Farklı Kaydet…` ile `UTF-8` kodlamasını seçin.",
            ]),
            .heading("Üç eski Vietnamca kodlama"),
            .table(
                headers: ["Kodlama", "Genellikle nerede bulunur"],
                rows: [
                    ["TCVN3 (ABC)", "Kuzeydeki resmî evraklarda ve eski Word belgelerinde"],
                    ["VNI-Windows", "Yayıncılık, gazeteler ve matbaalar — güneyde yaygın"],
                    ["VISCII", "Erken dönem e-posta ve Usenet"],
                ]
            ),
            .paragraph("""
                GEditor açılışta **kodlamayı algılar**. Yanlış tahmin ettiğinde tek tıklama düzeltir ve \
                içerik harf harf yamanmak yerine yeniden çözülür.
                """),
            .warning("""
                Eski bir kodlamaya yazmak, o kodlamada bulunmayan karakterleri kaybettirir. GEditor \
                bunları sessizce soru işaretine çevirmek yerine **sayar ve önce size söyler** — örneğin \
                *\"12 karakter TCVN3'te yok\"*.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Satır sonları",
        summary: "LF, CRLF, CR — tek tıklamayla tüm dosya için dönüştürülür.",
        keywords: ["eol", "crlf", "lf", "satır sonu", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Biçem", "Kullanan", "Baytlar"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "2001 öncesi Mac", "`\\r`"],
                ]
            ),
            .paragraph("""
                Geçerli biçem durum çubuğunda görünür; değiştirmek için tıklayın. İki biçemi \
                **karıştıran** bir dosya da orada bildirilir — tam olarak nerede olduğunu görmek için \
                `Görünmezleri göster ▸ Satır sonları`nı açın.
                """),
            .note("""
                **Yeni** dosyalar için satır sonu biçemi `Ayarlar…` içinde belirlenir.
                """),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode normalleştirme",
        summary: "«ế» aramanın neden bazen hiçbir şey bulmadığı ve bütün bir dosyanın nasıl düzeltileceği.",
        keywords: ["unicode", "nfc", "nfd", "birleşik", "ayrışık", "normalleştir", "eşleşme yok"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                Unicode'da `ế` **iki farklı biçimde** yazılabilir: tek bir önceden birleştirilmiş kod \
                noktası olarak (NFC) ya da `e` artı iki ayrı im olarak (NFD). Ekranda birbirinin aynıdır; \
                makine için farklı dizelerdir.
                """),
            .paragraph("""
                Sonuç: NFD bir dosyada `ế` aramak **hiçbir şey** bulmaz ve kullanıcı verinin orada \
                olmadığı sonucuna varır.
                """),
            .steps([
                "`Biçim ▸ Unicode normalleştir…`",
                "**NFC**'yi seçin (önceden birleştirilmiş) — neredeyse her şeyin kullandığı biçim.",
                "Uygulayın. Tek bir geri alma adımıdır.",
            ]),
            .note("""
                macOS'tan gelen dosyalar çoğu kez NFD'dir; çünkü Apple'ın dosya sistemi dosya adlarını \
                böyle saklar. Finder'dan kopyalanan verinin bir daha bulunamamasının en yaygın nedeni \
                budur.
                """),
            .paragraph("""
                `Ayarlar…` içinde bir **kaydederken NFC'ye normalleştir** anahtarı vardır. Dosyanın \
                baytlarını değiştirdiği için öntanımlı kapalıdır.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Aksansız yazmak yine aksanlı metni bulur",
        summary: "Her arama ve süzme kutusu, aksanları sökerek karşılaştırır.",
        keywords: ["aksan", "arama", "süzme", "aksansız"],
        blocks: [
            .paragraph("""
                `Huế`'yi bulmak için `hue` yazın. `Đà Nẵng`'ı bulmak için `da nang` yazın. Kural, CSV \
                ızgara süzmesi, işlev araması, yardım araması ve diğer süzme kutuları için geçerlidir.
                """),
            .note("""
                `Đ` özel olarak ele alınır; çünkü Unicode'da bir im taşıyan `D` değil, **kendi başına bir \
                harftir** — sıradan aksan sökme ona dokunmaz.
                """),
            .paragraph("""
                CSV süzmesi, birebir karşılaştırma için `=` önekini de kabul eder. `=` biçimi de **aksan \
                duyarsızdır**; çünkü aksanları ayırt eden bir süzme, kullanıcıyı verinin eksik olduğuna \
                inandırır.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamca giriş yöntemleri",
        summary: "EVKey, OpenKey, Unikey ve macOS giriş kaynağı doğrudan belgeye yazar.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "giriş yöntemi"],
        blocks: [
            .paragraph("""
                Yapılandırılacak bir şey yok. Telex ve VNI'nin ikisi de çalışır; **çoklu imleçlerde** de \
                — bir kez yazın, her imleç doğru aksanlı harfi alır.
                """),
            .paragraph("""
                Arama kutuları, süzme kutuları ve her pencere, giriş yöntemini düzenleyici gibi kabul \
                eder.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Diller ve biçimler

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Diller ve biçimler",
        summary: "Yirmi yerleşik dil, kullanıcı tanımlı diller ve JSON · XML · YAML · günlükler için araçlar.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Yirmi yerleşik dil",
        summary: "Gerçek bir sözdizimi ağacından renklendirme, her dilin kendi yorum imleriyle.",
        keywords: ["sözdizimi", "vurgulama", "dil", "tree-sitter", "dil bilgisi"],
        blocks: [
            .paragraph("""
                Dil, **dosya uzantısından** algılanır (artı `Makefile`, `Dockerfile`, `Gemfile` gibi \
                birkaç özel ad). Durum çubuğundan elle değiştirebilirsiniz.
                """),
            .table(
                headers: ["Dil", "Uzantılar", "Satır · blok yorumu"],
                rows: [
                    ["Shell", "`sh` `bash` `zsh` `command`", "`#` · —"],
                    ["C", "`c` `h`", "`//` · `/* */`"],
                    ["C++", "`cpp` `cc` `cxx` `hpp` `hh` `hxx`", "`//` · `/* */`"],
                    ["C#", "`cs`", "`//` · `/* */`"],
                    ["CSS", "`css`", "— · `/* */`"],
                    ["Go", "`go`", "`//` · `/* */`"],
                    ["HTML", "`html` `htm` `xhtml`", "— · `<!-- -->`"],
                    ["Java", "`java`", "`//` · `/* */`"],
                    ["JavaScript", "`js` `mjs` `cjs` `jsx`", "`//` · `/* */`"],
                    ["JSON", "`json` `jsonl` `geojson`", "— · —"],
                    ["Lua", "`lua`", "`--` · `--[[ ]]`"],
                    ["PHP", "`php` `phtml`", "`//` · `/* */`"],
                    ["Python", "`py` `pyw` `pyi`", "`#` · —"],
                    ["Regex", "—", "— · —"],
                    ["Ruby", "`rb` `rake` `gemspec`", "`#` · —"],
                    ["Rust", "`rs`", "`//` · `/* */`"],
                    ["TOML", "`toml`", "`#` · —"],
                    ["TypeScript", "`ts` `mts` `cts`", "`//` · `/* */`"],
                    ["XML", "`xml` `xsd` `xsl` `svg` `plist`", "— · `<!-- -->`"],
                    ["YAML", "`yaml` `yml`", "`#` · —"],
                ]
            ),
            .paragraph("""
                Son sütun, `⌘/`'in kullandığıdır. Satır yorumu olmayan diller (JSON, CSS, XML) bunun \
                yerine blok biçimini alır.
                """),
            .heading("Sözdizimi ağacıyla gelenler"),
            .bullets([
                "Kenar çubuğundaki **işlev listesi**, girinti tahminlerini değil, gerçek yapıyı izler.",
                "Yapıya göre **katlama**.",
                "Dizeler ve yorumlar içindeki parantezleri atlayan **parantez eşleştirme**.",
                "`{` sonrası ve Python ile YAML'de `:` sonrası bir düzey ekleyen **otomatik girinti**.",
            ]),
            .note("""
                Üç ağır dil bilgisi (C++, C#, Ruby) **tembel yüklenen** bir kitaplıkta durur — yalnızca o \
                dillerden birinde bir dosya açtığınızda yüklenirler. Açılış süresinin yarım saniyenin \
                altında kalmasının yolu budur.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Kullanıcı tanımlı diller",
        summary: "Kendi biçiminizi tek bir JSON dosyasıyla renklendirin — yazılacak dil bilgisi yok.",
        keywords: ["udl", "kullanıcı tanımlı dil", "özel dil", "özel günlük"],
        blocks: [
            .paragraph("""
                Bir şirketin iç günlük biçimi, özel bir yapılandırma dili, küçük bir DSL — bunların \
                hiçbirinin tree-sitter dil bilgisi yoktur ve bir tane yazmak bir derleyici ile biraz \
                ayrıştırma kuramı ister.
                """),
            .paragraph("""
                Bunun yerine GEditor, JSON içinde bildirilen bir **tablo güdümlü sözcük çözümleyiciyi** \
                kabul eder. Dosyayı GEditor'un yapılandırma dizinindeki `grammars/` klasörüne koyup \
                yeniden başlatın.
                """),
            .code(
                language: "json",
                caption: "grammars/internal-log.json — eksiksiz bir dil",
                source: """
                    {
                      "name": "İç günlük",
                      "extensions": ["nklog", "trace"],
                      "caseSensitive": false,
                      "lineComment": ";",
                      "blockComment": ["/*", "*/"],
                      "stringDelimiters": ["\\"", "'"],
                      "escapeCharacter": "\\\\",
                      "keywordGroups": {
                        "keyword": ["BEGIN", "END", "RETRY", "COMMIT", "ROLLBACK"],
                        "type":    ["INT", "TEXT", "DATE", "MONEY"],
                        "constant": ["TRUE", "FALSE", "NULL"]
                      }
                    }
                    """
            ),
            .heading("Her anahtar"),
            .table(
                headers: ["Anahtar", "Tür", "Anlamı"],
                rows: [
                    ["`name`", "dize", "Durum çubuğunda gösterilen ad"],
                    ["`extensions`", "dize dizisi", "Dosya uzantıları, **noktasız**"],
                    ["`caseSensitive`", "mantıksal", "Anahtar sözcükler büyük/küçük harfe duyarlı mı"],
                    ["`lineComment`", "dize", "Satır sonuna kadar yorum imi; yoksa yazmayın"],
                    ["`blockComment`", "2 dizelik dizi", "`[açan, kapatan]`"],
                    ["`stringDelimiters`", "dize dizisi", "Her girdi, bir dizeyi açan/kapatan **tek** bir karakterdir"],
                    ["`escapeCharacter`", "dize", "Dizeler içindeki kaçış karakteri; boş bırakmak dilde olmadığı anlamına gelir"],
                    ["`keywordGroups`", "nesne", "Grup adı → anahtar sözcük listesi; üç grup üç renk alır"],
                ]
            ),
            .paragraph("""
                Kendi renklerini alan üç grup adı `keyword`, `type` ve `constant`'tır.
                """),
            .warning("""
                Bu sözcük çözümleyici **iç içeliği anlamaz**. Yapısal katlama, işlev listesi ve akıllı \
                parantez eşleştirme yirmi yerleşik dile özel kalır. Bu bilinçli bir takastır: karşılığında \
                bir dili bir günde değil, on dakikada bildirirsiniz.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON araçları",
        summary: "Yeniden biçimlendir, küçült, anahtarları sırala ve JSON Schema ile doğrula.",
        keywords: ["json", "biçim", "güzelleştir", "küçült", "şema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Komut", "Ne yapar"],
                rows: [
                    ["Yeniden biçimlendir", "Okumak için sarar ve girintiler"],
                    ["Küçült", "Gereksiz tüm boşlukları kaldırır"],
                    ["Anahtarları sırala", "Her nesnenin anahtarlarını alfabetik sıralar — böylece iki JSON dosyası birbiriyle **karşılaştırılabilir**"],
                    ["JSON Schema ile doğrula…", "Belgeyi bir şema dosyasına göre denetler, her sorunu satırıyla listeler"],
                ]
            ),
            .paragraph("""
                Uygulanan kurallar **katı RFC 8259**'dur: sondaki virgül yok, yorum yok, `NaN` yok. Bir \
                sözdizimi hatası tam satır ve sütunu gösterir.
                """),
            .note("""
                **JSONL** dosyaları (satır başına bir nesne) da tanınır ve bilgi paketi bölümünde kendi \
                araç takımları vardır.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath sorguları",
        summary: "Büyük bir JSON dosyasından tam olarak gereken parçayı çekin.",
        keywords: ["jsonpath", "json sorgusu", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Bir ifade yazın; sonuçlar, içine atlayabileceğiniz bir liste olarak belirir."),
            .table(
                headers: ["Yazın", "Anlamı"],
                rows: [
                    ["`$`", "Belgenin kökü"],
                    ["`$.name`", "Kökteki `name` anahtarı"],
                    ["`$.orders[0]`", "Bir dizinin ilk ögesi"],
                    ["`$.orders[*].total`", "**Her** ögenin `total` anahtarı"],
                    ["`$..province`", "**Herhangi bir derinlikteki** `province` anahtarı"],
                    ["`$.orders[1:3]`", "Bir dilim: 1. ve 2. ögeler"],
                ]
            ),
            .code(
                language: "text",
                caption: "Ne kadar derinde olursa olsun her siparişin il kodu",
                source: """
                    $..orders[*].address.province
                    """
            ),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML araçları",
        summary: "Yeniden biçimlendir, küçült, sözdizimini denetle ve DTD ya da XSD ile doğrula.",
        keywords: ["xml", "xsd", "dtd", "şema", "doğrula", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Komut", "Ne yapar"],
                rows: [
                    ["Yeniden biçimlendir", "Etiket derinliğine göre girintiler"],
                    ["Küçült", "Etiketler arasındaki boşlukları kaldırır"],
                    ["Sözdizimini denetle", "Eksik kapatma etiketleri, yanlış iç içelik, geçersiz karakterler"],
                    ["DTD/XSD ile doğrula…", "Bir şemaya göre denetler, her sorunu satırıyla bildirir"],
                    ["XPath değerlendir…", "Bir XPath ifadesi çalıştırır; sonuçlar yeni bir sekmede açılır"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Bir ifade yazın; sonuçlar satır başına bir düğüm olacak biçimde **bir metin sekmesinde** \
                açılır. Örneğin: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Sonuçlar kaynak dosyadaki bir konuma ATLAMAZ.** Sistemin XPath değerlendiricisi kendi \
                ağacını kurar ve her düğümün bayt kaymasını saklamaz; dolayısıyla geri gelen şey koordinat \
                değil, İÇERİKTİR. Tam noktaya ulaşmak için az önce bulduğunuz dize üzerinde `⌘F` kullanın.
                """),
            .paragraph("""
                `.xml` ve `.html` dosyalarında, açan bir etiketi bitirmek için `>` yazmak **kapatan \
                etiketi** belirtir ve imleci ikisinin arasına koyar. Kendini kapatan etiketler (`<br/>`), \
                bildirimler (`<?xml …?>`) ve yorumlar bunu yapmaz — kapatacak bir şeyleri yoktur.
                """),
            .warning("""
                XML'i yeniden biçimlendirmek **etiketler arasındaki boşluğu değiştirir**. O boşluğun \
                anlamlı olduğu belgelerde — diyelim etiketler içinde metin bulunan XHTML — bu, \
                görüntüleneni değiştirir. Tek bir geri alma adımıdır; `⌘Z` geri alır.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML denetimi",
        summary: "En yaygın iki YAML hatasını yakalayın: yinelenen anahtarlar ve sekmeyle girinti.",
        keywords: ["yaml", "yml", "lint", "yinelenen anahtar", "girinti"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "Bir eşlemedeki **yinelenen anahtarlar** — çoğu YAML okuyucusu **sonuncuyu** alır ve öncekini sessizce atar; dolayısıyla bir yapılandırma dosyası beklediğinizden bambaşka davranabilir.",
                "**Sekmeyle girinti** — YAML girintide sekmeyi yasaklar ve kitaplıkların bu konudaki hata iletileri genellikle anlaşılmazdır.",
            ]),
            .note("""
                Hangi boşluğun sekme olduğunu hemen görmek için `Görünmezleri göster ▸ Sekmeler`i açın.
                """),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Günlük dosyaları",
        summary: "Yedi önem düzeyi, düzeye göre süzme ve çok büyük bir günlüğün nasıl okunacağı.",
        keywords: ["günlük", "hata", "uyarı", "süz", "düzey"],
        blocks: [
            .paragraph("""
                `Görünüm ▸ Günlük kipi (düzeye göre renklendir)` açın. GEditor önem derecesini **her \
                satırın başından** okur — zaman damgası ve süreç adından sonra.
                """),
            .table(
                headers: ["Düzey", "Renk"],
                rows: [
                    ["CRITICAL · ERROR", "Kırmızı"],
                    ["WARNING", "Kehribar"],
                    ["NOTICE", "Vurgu rengi"],
                    ["INFO", "Sıradan metin"],
                    ["DEBUG · TRACE", "Soluk"],
                ]
            ),
            .paragraph("""
                `Günlüğü düzeye göre süz…` alt düzeyleri tümüyle gizler. Düzeyi **tanınmayan** satırlar — \
                örneğin bir yığın izinin devamı — bir önceki satırın düzeyine atanmak yerine olduğu gibi \
                bırakılır.
                """),
            .heading("Büyük bir günlüğü adım adım okumak"),
            .steps([
                "Dosyayı açın — gigabayt ölçeği yine neredeyse anında açılır.",
                "Kırmızı noktaları görmek için `Görünüm ▸ Günlük kipi`.",
                "Belge haritası için `⌥⌘M`: kırmızı tek bir kesitte mi kümelenmiş, yoksa dosyaya yayılmış mı?",
                "Hata kodu için `⌘F`, eşleşen her satırı imlemek için `⌘M`.",
                "Onları yeni bir sekmeye çekmek için `Ara ▸ İmlenmiş satırları kopyala`.",
                "Hâlâ çalışıyor mu? `Dosya ▸ Dosyayı izle (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
