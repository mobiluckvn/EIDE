import Foundation

/// Suomenkielinen ohjesisältö — osa 1: aloitus ja muokkaus.
///
/// **Aiheiden `id`-tunnuksia EI KOSKAAN käännetä.** Niihin `.seeAlso` viittaa, ne valikko avaa, ja ne
/// antavat ohjeikkunan vaihtaa kieltä **heittämättä lukijaa takaisin sisällysluetteloon**. Tunnuksen
/// muuttaminen rikkoo kaikki linkit — kaikissa kirjoissa yhtä aikaa.
///
/// `commands:`-kentän valikkonimet jäävät vietnamiksi: niiden on täsmättävä sanasta sanaan oikeiden
/// valikkokohtien kanssa, mitä `HelpCoverage` tarkastaa juuri sen merkkijonon kautta.
enum HelpFI {}

extension HelpFI {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Aloitus",
        summary: "Mitä GEditor tekee ja mihin ensimmäiset viisi minuuttia kannattaa käyttää.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Mikä GEditor on",
        summary: "Gigatavuluokan teksti- ja datamuokkain macOS:lle, joka puhuu vietnamia.",
        keywords: ["esittely", "tervetuloa", "yleiskuva", "tietoja"],
        blocks: [
            .paragraph("""
                GEditor avaa **1 Gt:n tiedoston lataamatta 1 Gt:tä muistiin**. Se lukee liukuvan \
                ikkunan läpi muistiin kuvatusta tiedostosta, joten 200 miljoonan rivin loki tai \
                miljoonan rivin CSV avautuu noin sekunnissa ja vierii tasaisesti.
                """),
            .paragraph("""
                Muokkaamisen lisäksi se on **datan työpöytä**: katso CSV taulukkona, siivoa se, \
                arvioi sen laatu, kysele sitä SQL:llä, louhi siitä poikkeamia ja suuntauksia ja \
                laadi sitten raportti. Ja se lukee ne vanhat vietnamilaiset merkistöt, jotka \
                useimmat nykyiset työkalut ovat unohtaneet.
                """),
            .heading("Kuusi asiaa, joita kannattaa kokeilla ensin"),
            .table(
                headers: ["Tehtävä", "Minne mennä"],
                rows: [
                    ["Avata suuri tiedosto odottamatta", "Vedä se ikkunaan — katso `Suurten tiedostojen avaaminen`"],
                    ["Muokata monta kohtaa kerralla", "`⌘D` lisää seuraavan osuman, sitten kirjoitat kerran"],
                    ["Etsiä säännöllisellä lausekkeella", "`⌘F`, kytke Regex päälle — moottori on PCRE2 JIT:llä"],
                    ["Katsoa CSV taulukkona", "`⌥⌘T` — miljoona riviä vierii yhä tasaisesti"],
                    ["Siivota sekava datataulukko", "`⇧⌘L` Siivouspöytä — esikatsele ennen käyttöä"],
                    ["Avata vietnaminkielinen tiedosto, joka näyttää sotkulta", "Napsauta merkistöä tilarivillä"],
                ]
            ),
            .note("""
                Tuletko Notepad++:sta? On sivu, joka vertaa näppäinasetteluja, sillä muutama näppäin \
                **vaihtaa paikkaa** macOS:ssä sen sijaan, että `Ctrl` vain muuttuisi `⌘`:ksi.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Ensimmäiset viisi minuuttia",
        summary: "Kaksitoista pikanäppäintä kattaa suurimman osan päivittäisestä työstä.",
        keywords: ["pikanäppäin", "näppäimet", "aloitus", "perusteet"],
        blocks: [
            .paragraph("""
                Kaikkea ei tarvitse opetella. Alla olevat kaksitoista näppäintä kattavat useimmat \
                arkiset työt; muut voi katsoa silloin, kun niitä tarvitsee.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Avaa tiedosto"),
                HelpShortcut("⇧⌘O", "Avaa kokonainen kansio työtilaksi"),
                HelpShortcut("⌘T", "Uusi välilehti"),
                HelpShortcut("⌘S", "Tallenna"),
                HelpShortcut("⌘F", "Etsi"),
                HelpShortcut("⌥⌘F", "Etsi ja korvaa"),
                HelpShortcut("⇧⌘F", "Etsi koko kansiosta"),
                HelpShortcut("⌘D", "Lisää valinnan seuraava esiintymä"),
                HelpShortcut("⌘L", "Siirry riville"),
                HelpShortcut("⌘/", "Kommentoi rivi kielen omalla merkillä"),
                HelpShortcut("⌥⌘T", "Vaihda taulukon ja tekstin välillä (CSV-tiedostot)"),
                HelpShortcut("⌘?", "Avaa tämä ohjeikkuna uudelleen"),
            ]),
            .heading("Kolme asiaa, jotka yllättävät uuden käyttäjän"),
            .bullets([
                "**Massatoimenpide on YKSI kumoamisaskel**, vaikka se koskisi miljoonaa riviä. Lajittelitko väärin? Yksi `⌘Z`, ja se on poissa.",
                "**Työistunto palautuu itsestään.** Lopeta ja avaa uudelleen: välilehdet palaavat paikoilleen, myös tallentamattomat. Mitään ei tarvitse painaa.",
                "**Kirjoittaminen ilman tarkkeita löytää silti tarkkeelliset sanat** kaikissa haku- ja suodatinkentissä — kirjoita `hue` saadaksesi `Huế`, `da nang` saadaksesi `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Mitä yrität tehdä?",
        summary: "Hakutaulukko oikeista tehtävistä siihen lukuun, joka ne kattaa.",
        keywords: ["hakemisto", "haku", "miten", "kuinka teen"],
        blocks: [
            .paragraph("""
                Vasemmalla oleva sisällysluettelo on järjestetty **ominaisuuden** mukaan. Tämä \
                taulukko on järjestetty **tehtävän** mukaan, koska nämä kaksi järjestystä eivät osu \
                yhteen.
                """),
            .table(
                headers: ["Minun pitää…", "Katso"],
                rows: [
                    ["Muokata samaa kohtaa sadoilla riveillä", "Useat kohdistimet · Sarakelohkon valinta"],
                    ["Muotoilla joukolla säännöllisellä lausekkeella", "Etsi ja korvaa · Säännölliset lausekkeet"],
                    ["Toistaa toimintosarjan", "Makrot"],
                    ["Avata CSV:n, jonka joku lähetti", "CSV-taulukko"],
                    ["Siivota sekavan taulukon: sekalaiset päivämäärät, luvut tekstinä", "Siivousprosessi"],
                    ["Arvioida, voiko taulukkoon luottaa", "Datan laadun pisteytys"],
                    ["Löytää poikkeamia, suuntauksia, ryppäitä", "Louhintaprosessi"],
                    ["Esittää kysymyksiä SQL:llä", "CSV:n kysely SQL:llä"],
                    ["Julkaista raportin, jonka luvut päivittyvät", "`.greport.md`-raportit"],
                    ["Piirtää kaavion asiakirjan sisään", "Mermaid"],
                    ["Avata vietnaminkielisen tiedoston, joka näyttää sotkulta", "Vietnamilaiset merkistöt"],
                    ["Automatisoida komentotulkista tai AppleScriptistä", "Automaatio"],
                    ["Värittää muodon, jonka yritykseni keksi", "Omat kielimäärittelyt"],
                ]
            ),
            .note("""
                Eikö luettelossa? Vasemmalla ylhäällä oleva hakukenttä katsoo **leipätekstiin ja \
                koodiesimerkkeihin**, joten paljaan asetusavaimen kuten `fail_under` kirjoittaminen \
                osuu oikealle sivulle.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Suurten tiedostojen avaaminen",
        summary: "Miksi 1 Gt ylipäätään avautuu, ja missä GEditor kieltäytyy tarkoituksella arvaamisen sijaan.",
        keywords: ["suuri tiedosto", "gigatavu", "1gt", "loki", "mmap", "hidas", "suorituskyky"],
        blocks: [
            .paragraph("""
                Tiedosto **kuvataan muistiin** ja luetaan liukuvan ikkunan läpi; se osa, jota \
                muokkaat, elää palataulukossa. Käytännössä: avausaika ei juuri riipu tiedoston \
                koosta, eikä riipu ohjelman varaama muistikaan.
                """),
            .heading("Missä se kieltäytyy tarkoituksella"),
            .paragraph("""
                Muutama laskenta joutuisi lukemaan koko tiedoston yhdeksi merkkijonoksi — juuri \
                sitä tämä rakenne välttää. Siinä kohtaa GEditor **sanoo ei** sen sijaan, että \
                hiipisi hiljaa tai arvaisi:
                """),
            .table(
                headers: ["Toimenpide", "Katto", "Sen yli"],
                rows: [
                    ["Sulkumerkkien vastinparit", "1 Mt", "Kieltäytyy ja sanoo sen — väärän parin korostaminen on pahempi kuin ei mitään"],
                    ["Näkyvä sarake tilarivillä", "200 kt", "Palaa laskemaan tavuja ja merkitsee sen `~`:llä, jotta merkitys näkyy"],
                    ["Markdown-esikatselu", "4 Mt", "Kieltäytyy ja selittää"],
                ]
            ),
            .warning("""
                Luku, joka näyttää samalta mutta tarkoittaa muuta, on pahin väärän laji. Siksi katon \
                yli menevä sarake lukee `~1234`, ei `1234`.
                """),
            .heading("Vinkkejä lokitiedostoihin"),
            .bullets([
                "`Tiedosto ▸ Seuraa tiedostoa (tail -f)` liittää perään sen, mitä loppuun kirjoitetaan. Asiakirjasta tulee seurannan ajaksi **vain luettava** — kirjoittaminen samalla kun uutta tekstiä virtaa sisään tarkoittaa kahta kirjoittajaa yhdestä asiakirjasta, ja häviäjä on aina se, minkä juuri kirjoitit.",
                "Lokirivit **väritetään vakavuuden mukaan** ja niitä voi suodattaa tason mukaan.",
                "**Asiakirjakartta** (`⌥⌘M`) kuvaa koko tiedoston, ei vain näkyvää osaa.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "App Store -versio vastaan suora lataus",
        summary: "Kolme ominaisuutta, jotka vain suora versio saa, ja miksi.",
        keywords: ["app store", "hiekkalaatikko", "lataus", "cli", "liitännäinen", "ero"],
        blocks: [
            .paragraph("""
                GEditor julkaistaan kahtena versiona. Ne tulevat **samasta lähdekoodista**, ja \
                ohjelma tietää käynnistyessään, kumpi se on. Ero on siinä, mitä App Sandbox sallii.
                """),
            .table(
                headers: ["Ominaisuus", "App Store", "Suora lataus"],
                rows: [
                    ["Kaikki muokkaus, CSV, siivous, louhinta, raportointi", "Kyllä", "Kyllä"],
                    ["Komentorivityökalu `geditor`", "Ei", "Kyllä"],
                    ["Tekstin suodatus ulkoisen komennon läpi", "Ei", "Kyllä"],
                    ["Natiiviliitännäiset (oma prosessi)", "Ei", "Kyllä"],
                    ["Itsepäivitys", "App Storen kautta", "Ohjelman sisällä"],
                ]
            ),
            .paragraph("""
                Jokainen yllä oleva »Ei« tulee samasta säännöstä: hiekkalaatikko **kieltää koodin \
                ajamisen ohjelman ulkopuolella**. Se on App Store -jakelun hinta, ei huolimattomuus.
                """),
            .note("""
                App Store -versiossa nuo komennot **jäävät valikkoon** ja selittävät, miksi ne eivät \
                ole käytettävissä, sen sijaan että katoaisivat. Puuttuva valikkokohta on kysymys \
                tuelle; paikallaan oleva vastaus ei ole.
                """),
            .heading("Tiedostojen käyttö App Store -versiossa"),
            .paragraph("""
                Hiekkalaatikoitu versio voi koskea vain tiedostoihin, jotka itse avasit tai vedit \
                sisään. GEditor säilyttää **turva-alueeseen sidotun kirjanmerkin** jokaiselle \
                välilehdelle ja työtilakansiolle, joten istuntosi avautuu lopettamisen jälkeen \
                uudelleen ilman uutta lupakyselyä.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Muokkaus

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Muokkaus",
        summary: "Muokkaa montaa kohtaa kerralla, työskentele riveillä, ja piilotetut säännöt, jotka kannattaa tietää ensin.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Useat kohdistimet",
        summary: "Valitse kaikki osuvat kohdat, kirjoita kerran, muuta ne kaikki.",
        keywords: ["monikohdistin", "cmd+d", "monivalinta"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Tämä korvaa useimmat hetket, joina olit kirjoittamassa säännöllistä lauseketta. \
                Valitse sana, paina `⌘D` muutaman kerran kerätäksesi seuraavat esiintymät, ja \
                kirjoita sitten — jokainen kohta muuttuu kerralla.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Lisää seuraava esiintymä valintaan"),
                HelpShortcut("⌘ + napsautus", "Aseta toinen kohdistin napsautuskohtaan"),
                HelpShortcut("Esc", "Poista kaikki, takaisin yhteen kohdistimeen"),
                HelpShortcut("⌥ + veto", "Sarakelohkon valinta (toinen tapa saada monta kohdistinta)"),
            ]),
            .heading("Sääntöjä, jotka kannattaa tietää"),
            .bullets([
                "Kirjoittaminen, poistaminen ja liittäminen monen kohdistimen yli on **yksi** kumoamisaskel, ei yksi per kohdistin.",
                "Kohdistimet kestävät nuolinäppäinliikkeen — koko ryhmä liikkuu yhdessä.",
                "`⌘D` ohittaa kohdat, jotka ovat jo valinnassa, joten liika painaminen ei koskaan pinoa kohdistimia päällekkäin.",
            ]),
            .note("""
                `⌘D` pitkän merkkijonon sisällä olevaan sanaan oli ennen hidas. Sanarajojen \
                tunnistus lukee nyt erissä — noin **42× nopeammin** 1 Mt:n merkkijonolla, mikä tekee \
                tästä käyttökelpoisen datatiedostoilla eikä vain lähdekoodilla.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Sarakelohkon valinta",
        summary: "Valitse suorakulmio monelta riviltä — hiirellä tai näppäimistöltä.",
        keywords: ["saraketila", "lohkovalinta", "alt-veto", "suorakulmio", "näppäimistö"],
        blocks: [
            .paragraph("""
                Pidä `⌥` pohjassa ja vedä valitaksesi **suorakulmaisen lohkon**. Kirjoittaminen, \
                poistaminen ja liittäminen seuraavat kaikki lohkoa. Lohkon liittäminen yhteen \
                kohdistimeen säilyttää silti sen suorakulmion.
                """),
            .shortcuts([
                HelpShortcut("⌥ + veto", "Valitse lohko"),
                HelpShortcut("⌥⌘← →", "Levennä lohkoa yhdellä sarakkeella vasemmalle/oikealle"),
                HelpShortcut("⌥⌘↑ ↓", "Laajenna lohkoa yhdellä rivillä ylös/alas"),
            ]),
            .paragraph("""
                Näppäimistöreitti ei ole hiiren varasuunnitelma: 40 rivin lohkon valitseminen \
                vetämällä tarkoittaa vetämistä vierityksen läpi, kun taas `⌥⌘` + nuolet säilyttää \
                sarake sarakkeelta -tarkkuuden. Mikä tahansa **muu** näppäin (tai kirjoittaminen) \
                päättää laajentamasi lohkon.
                """),
            .heading("Sarakkeet ovat tässä NÄKYVIÄ sarakkeita"),
            .paragraph("""
                TAB laajenee seuraavaan pysäkkiin sarkainleveydelläsi sen sijaan, että laskisi \
                yhdeksi sarakkeeksi. Juuri se saa sarkaimilla ja välilyönneillä sisennetyt rivit \
                **asettumaan niin kuin ne näytöllä näkyvät**.
                """),
            .paragraph("Monitavuinen teksti on silti yksi sarake: `Nguyễn` vie kuusi saraketta, ei yhdeksää."),
            .table(
                headers: ["Tilanne", "Mitä GEditor tekee"],
                rows: [
                    ["Kohdesarake osuu keskelle TABia", "Napsahtaa lähempään reunaan; tasapelissä vasemmalle"],
                    ["Rivi on lyhyempi kuin aloitussarake", "Se rivi antaa tyhjän valinnan ja ottaa silti vastaan kirjoitettua tekstiä"],
                    ["Lohkon liittäminen yhteen kohdistimeen", "Säilyttää suorakulmion ja lisää alaspäin seuraaville riveille"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Sarakemuokkain",
        summary: "Lisää tekstiä, lukusarja tai päivämääräsarja lohkon jokaiselle riville.",
        keywords: ["sarakemuokkain", "numerointi", "sarja"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Valitse sarakelohko ja avaa sitten `Muokkaa ▸ Column Editor…` (`⌥⌘C`). \
                Valintaikkunassa on **esikatselu** ennen kuin mitään sovelletaan.
                """),
            .table(
                headers: ["Tila", "Parametrit", "Käytä kun"],
                rows: [
                    ["Teksti", "Kiinteä merkkijono", "Lisäät saman etu-/jälkiliitteen joka riville"],
                    ["Lukusarja", "Alku · askel · kanta 2·8·10·16 · nollatäyttö", "Numeroit rivejä tai luot koodeja"],
                    ["Päivämääräsarja", "Ensimmäinen päivä · askel päivinä", "Teet sarakkeen peräkkäisiä päiviä"],
                ]
            ),
            .code(language: "text", caption: "Numerointi nollatäytöllä, alku 1, askel 1",
                  source: """
                    Ennen:            Jälkeen (lukusarja, täytetty 3 numeroon):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "**Negatiivinen** askel on kelvollinen — alaspäin laskeminen toimii.",
                "Lisääminen 5 000 riville on silti **yksi** kumoamisaskel.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Rivitoiminnot",
        summary: "Lajittele, poista kaksoiskappaleet, siirrä, yhdistä, jaa, kahdenna, poista.",
        keywords: ["lajittele", "kahdenna", "kaksoiskappaleet", "siirrä riviä", "yhdistä", "jaa"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Valinnan kanssa komento toimii valintaan; ilman sitä se toimii **koko asiakirjaan**. \
                Jokainen tämän sivun komento on yksi kumoamisaskel.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Kahdenna rivi"),
                HelpShortcut("⌘K", "Poista rivi"),
                HelpShortcut("⌥↑ / ⌥↓", "Siirrä riviä ylös / alas"),
            ]),
            .heading("Kolme lajittelutapaa ja kumpi valita"),
            .table(
                headers: ["Laji", "`file2` vs. `file10`", "Käytä"],
                rows: [
                    ["A→Z / Z→A", "`file10` tulee ennen `file2`", "Tavallisiin sanalistoihin"],
                    ["Luonnollinen", "`file2` tulee ennen `file10`", "Tiedostonimiin, koodattuihin tunnuksiin, versioihin"],
                ]
            ),
            .paragraph("""
                **Luonnollinen** lajittelu lukee numerojaksot lukuina. Se on lähes aina se, mitä \
                haluat, kun lista on numeroitu.
                """),
            .heading("Kaksoiskappaleiden poisto"),
            .bullets([
                "**Koko asiakirja** — pudota jokainen rivi, joka on esiintynyt aiemmin, säilytä ensimmäinen.",
                "**Vain vierekkäiset** — yhdistä samanlaiset naapuririvit, kuten Unixin `uniq`.",
            ]),
            .heading("Yhdistäminen ja jakaminen"),
            .bullets([
                "**Yhdistä rivit** sulauttaa valitut rivit yhdeksi.",
                "**Jaa pituuden mukaan** katkaisee pitkät rivit annetusta merkkimäärästä.",
                "**Jaa merkin mukaan** katkaisee jokaisesta kirjoittamasi merkin esiintymästä — vaikkapa yhden CSV-rivin jakamiseksi soluikseen.",
            ]),
            .note("""
                Tiedoston **viimeisen rivin** kahdentaminen lisää puuttuvan rivinvaihdon; \
                asiakirjan lopun läpi poistaminen nielaisee myös edellisen rivin rivinvaihdon. \
                Molemmat poikkeavat naiivista toteutuksesta, ja molemmat ovat olemassa, jottei \
                tiedoston loppuun jää irrallista tyhjää riviä — tai jotta se ei jää puuttumaan.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Tyhjemerkit ja sisennys",
        summary: "Siivoa irralliset tyhjemerkit, muunna TAB ↔ välilyönti, ja yksi kytkin, jota kannattaa miettiä.",
        keywords: ["tyhjemerkki", "sarkain", "välilyönti", "sisennys", "tyhjät rivit"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Komento", "Mitä se tekee"],
                rows: [
                    ["Poista tyhjät rivit", "Pudottaa jokaisen rivin, jolla ei ole mitään"],
                    ["Tiivistä peräkkäiset tyhjät rivit", "Useasta peräkkäisestä tyhjästä rivistä tulee yksi"],
                    ["Leikkaa rivinloppuiset tyhjemerkit", "Poistaa irralliset välilyönnit ja sarkaimet rivin lopusta"],
                    ["Tab → välilyönti", "Muuntaa TABit välilyönneiksi nykyisellä sarkainleveydellä"],
                    ["Välilyönti → Tab", "Toiseen suuntaan"],
                ]
            ),
            .heading("Kielikohtainen sisennys"),
            .paragraph("""
                Napsauta `Tab: 4` tilarivillä. Valikon yläosa muuttaa sen **koko ohjelmalle**; \
                alaosa — `Vain Go:lle`, `Vain Pythonille`… — koskee vain avatun tiedoston kieltä ja \
                muistaa, käytetäänkö sarkaimia vai välilyöntejä.
                """),
            .paragraph("""
                Ihmiset eivät valitse sisennystä maun vaan **yhteisön tavan** mukaan: Go käyttää \
                sarkaimia (`gofmt` kumoaa kaiken muun), Python neljää välilyöntiä PEP 8:n mukaan, \
                JavaScript ja YAML tavallisesti kahta. Yksi luku kaikille kielille tarkoittaa, että \
                jokaiseen koskemaasi tiedostoon kasvaa rivejä, joita et koskaan muokannut.
                """),
            .code(language: "json", caption: "settings.json",
                  source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """),
            .note("""
                Myös `settings.json`-tiedostossa määrittely toimii — avain on kielikoodi (`go`, \
                `python`, `javascript`…). Kielet, joita siinä ei ole, käyttävät yhteistä `tabWidth`iä.
                """),
            .heading("Miksi »leikkaa tallennettaessa« on OLETUKSENA POIS"),
            .paragraph("""
                Kytkin `Tiedosto ▸ Leikkaa rivinloppuiset tyhjemerkit tallennettaessa` muokkaa \
                **rivejä, joihin et ole koskenut**. Oletuksena päällä yhden sanan korjaus toisen \
                ihmisen arkistossa muuttuu tuhannen rivin erotukseksi, eikä katselmoija löydä \
                todellista muutosta.
                """),
            .paragraph("""
                Kun se on päällä, leikkaus on **erillinen kumoamisaskel** ennen kirjoitusta — yksi \
                kumoaminen palauttaa asiakirjan entiselleen menettämättä sitä, minkä juuri tallensit.
                """),
            .heading("Automaattinen sisennys"),
            .bullets([
                "Uusi rivi perii edellisen rivin sisennyksen, plus yhden tason avaavan merkin jälkeen — `{` aaltosulkukielissä, `:` Pythonissa ja YAMLissa.",
                "Mittaus tapahtuu **näkyvinä sarakkeina**, joten sarkaimia ja välilyöntejä sekoittavat tiedostot asettuvat silti näytöllä.",
                "**Ei ole** sääntöä »`}`:n kirjoittaminen sisentää rivin uudelleen«. Se sääntö muokkaa riviä, jonka jo lopetit, ja se on eniten valituksia kerännyt käyttäytyminen jokaisessa muokkaimessa, jossa se on.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Kirjainkoko ja nimeämistavat",
        summary: "Kahdeksan muunnosta, mukaan lukien camelCase, snake_case ja kebab-case.",
        keywords: ["kirjainkoko", "isot", "pienet", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Sovelletaan valintaan. Kaikki löytyvät `Muotoilu`-valikosta."),
            .table(
                headers: ["Komento", "`tổng doanh thu` muuttuu"],
                rows: [
                    ["ISOT KIRJAIMET", "`TỔNG DOANH THU`"],
                    ["pienet kirjaimet", "`tổng doanh thu`"],
                    ["Iso Alkukirjain Sanoissa", "`Tổng Doanh Thu`"],
                    ["Virkkeen alkukirjain", "`Tổng doanh thu`"],
                    ["Käännä kirjainkoko", "Kääntää jokaisen merkin"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Kolme viimeistä poistavat vietnamilaiset tarkkeet, koska ne tuottavat **tunnuksia \
                koodiin** — missä tarkkeelliset kirjaimet eivät yleensä ole sallittuja.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Kommentit ja sulkumerkkien vastinparit",
        summary: "⌘/ käyttää kunkin kielen omaa merkkiä; ⌃⌘B hyppää vastaavaan sulkumerkkiin.",
        keywords: ["kommentti", "sulkumerkki", "cmd+/", "vastinpari"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` valitsee kommenttimerkin **asiakirjan kielen mukaan**: `#` Pythonille, `//` \
                Rustille ja C:lle, `<!-- -->` XML:lle ja HTML:lle.
                """),
            .heading("Koko lohko menee samaan suuntaan"),
            .paragraph("""
                Jos yksikin rivi lohkossa on yhä kommentoimatta, komento kommentoi **kaiken**. \
                Rivikohtainen päätös muuttaisi puoliksi kommentoidun lohkon shakkilaudaksi. Merkki \
                lisätään lohkon matalimpaan sisennykseen, joten lohko säilyttää muotonsa.
                """),
            .heading("Vastaavaan sulkumerkkiin hyppääminen"),
            .bullets([
                "`⌃⌘B` hyppää sulkumerkkiin, joka vastaa kohdistimen kohdalla olevaa.",
                "**Merkkijonojen** tai **kommenttien** sisällä olevat sulkumerkit eivät laske — kevyt jäsentäjä erottaa ne.",
                "Yli **1 Mt** komento kieltäytyy ja sanoo sen sen sijaan, että ankkuroituisi puoliväliin ja arvaisi. Väärän parin korostaminen on pahempaa kuin ei korostusta lainkaan.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Kumoaminen ja leikepöytä",
        summary: "Rajaton kumoamishistoria ja monipaikkainen leikepöytähistoria.",
        keywords: ["kumoa", "tee uudelleen", "leikepöytä", "liitä", "historia"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Kumoa / tee uudelleen"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Leikkaa / kopioi / liitä"),
                HelpShortcut("⇧⌘V", "Leikepöytähistoria"),
            ]),
            .heading("Massatoimenpide on YKSI askel"),
            .paragraph("""
                Miljoonan rivin lajittelu, kymmenen tuhannen osuman korvaaminen, viiteen tuhanteen \
                riviin lisääminen sarakemuokkaimella — jokainen niistä kumoutuu **yhdellä** `⌘Z`:llä.
                """),
            .paragraph("""
                Kumoamishistoria elää GEditorin omassa tekstipuskurissa järjestelmän \
                `UndoManager`in sijaan juuri siitä syystä: `UndoManager` laskee näppäinpainalluksia.
                """),
            .heading("Leikepöytähistoria"),
            .paragraph("""
                `⇧⌘V` avaa luettelon siitä, mitä olet viime aikoina kopioinut, ja liittää \
                valitsemasi. Hyödyllinen, kun joudut vuorottelemaan kahta pätkää monessa paikassa.
                """),
        ]
    )
}
