import Foundation

/// Suomenkielinen ohjesisältö — osa 2: haku sekä tiedostot ja istunnot.
extension HelpFI {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Haku",
        summary: "Etsi, korvaa, säännölliset lausekkeet, koko kansion haku ja rivimerkinnät.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Etsi ja korvaa",
        summary: "Kolme hakutilaa, ja miksi ^ tarkoittaa oletuksena RIVIN alkua.",
        keywords: ["etsi", "korvaa", "haku", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Etsi"),
                HelpShortcut("⌥⌘F", "Etsi ja korvaa"),
                HelpShortcut("⌘G / ⇧⌘G", "Seuraava / edellinen osuma"),
            ]),
            .heading("Kolme tilaa"),
            .table(
                headers: ["Tila", "Ymmärtää", "Käytä"],
                rows: [
                    ["Tavallinen", "Pelkkää tekstiä, ei erikoismerkkejä lainkaan", "Useimpiin hakuihin"],
                    ["Laajennettu", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Rivinvaihtojen, TABien ja tiettyjen tavujen etsimiseen"],
                    ["Regex", "Täysi PCRE2", "Kuvion mukaan hakemiseen"],
                ]
            ),
            .note("""
                **Laajennettu** tila ei ymmärrä regex-syntaksia. Se laajentaa vain muutaman \
                ohjausmerkin — joten haku `a.b` löytää siellä juuri nuo kolme merkkiä; piste ei ole \
                jokerimerkki.
                """),
            .heading("Kaksi kytkintä"),
            .bullets([
                "**Sama kirjainkoko** — oletuksena pois.",
                "**Kokonainen sana** — osuu vain, kun molemmat päät ovat sanarajoja.",
            ]),
            .heading("`^` ja `$` osuvat kunkin RIVIN reunoihin"),
            .paragraph("""
                Oletuksena päällä. Notepad++:sta tulevat odottavat, että `^` tarkoittaa »rivin \
                alkua«; ilman sitä `^abc` osuisi vain, jos koko asiakirja alkaisi merkeillä `abc` — \
                sitä ei tekstimuokkaimessa halua juuri kukaan.
                """),
            .heading("Huono lauseke ei jumita ohjelmaa"),
            .paragraph("""
                Moottori on **PCRE2 JIT-käännöksellä**, ja sillä on takaisinpaluubudjetti. Kuvio, \
                joka räjähtää kombinatorisesti, pysäytetään ja ilmoitetaan sen sijaan, että ikkuna \
                jäätyisi.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Säännölliset lausekkeet",
        summary: "Se PCRE2-syntaksi, jota oikeasti käytät, esimerkkeineen vietnamilaisella datalla.",
        keywords: ["regex", "regexp", "pcre", "kuvio"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor käyttää **PCRE2**:ta, samaa moottoria kuin PHP ja monet komentorivityökalut. \
                Avaa `Haku ▸ Kokeile säännöllistä lauseketta…` kokeillaksesi kuviota esimerkkitekstiä \
                vasten ja nähdäksesi, mitä kukin ryhmä kaappaa, **ennen** kuin sovellat sitä oikeaan \
                asiakirjaan.
                """),
            .heading("Merkkiluokat"),
            .table(
                headers: ["Kirjoita", "Osuu"],
                rows: [
                    ["`.`", "Mihin tahansa merkkiin paitsi rivinvaihtoon"],
                    ["`\\d` · `\\D`", "Numero · ei numero"],
                    ["`\\w` · `\\W`", "Sanamerkki (kirjain, numero, `_`) · päinvastoin"],
                    ["`\\s` · `\\S`", "Tyhjemerkki · ei tyhjemerkki"],
                    ["`[abc]`", "Yksi hakasulkeiden merkeistä"],
                    ["`[^abc]`", "Yksi merkki, joka EI ole hakasulkeissa"],
                    ["`[a-z]`", "Yksi merkki väliltä"],
                ]
            ),
            .heading("Toisto"),
            .table(
                headers: ["Kirjoita", "Merkitys"],
                rows: [
                    ["`*`", "Nolla tai useampi"],
                    ["`+`", "Yksi tai useampi"],
                    ["`?`", "Nolla tai yksi"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Tasan 3 · 2–5 · 2 tai enemmän"],
                    ["`*?` `+?` `??`", "**Laiskat** muodot — ota mahdollisimman vähän"],
                ]
            ),
            .warning("""
                `.*` on **ahne**: se syö rivin loppuun asti ja peruuttaa sitten. Kenttiä rivin \
                sisällä jaettaessa tarvitset lähes aina `.*?` tai kapean merkkiluokan kuten `[^,]*`.
                """),
            .heading("Ankkurit ja ryhmät"),
            .table(
                headers: ["Kirjoita", "Merkitys"],
                rows: [
                    ["`^` · `$`", "Rivin alku · rivin loppu"],
                    ["`\\b`", "Sanaraja"],
                    ["`(…)`", "**Kaappaava** ryhmä — käytettävissä korvauksessa"],
                    ["`(?:…)`", "Kaappaamaton ryhmä"],
                    ["`(?<name>…)`", "Nimetty ryhmä"],
                    ["`a|b`", "a tai b"],
                    ["`(?=…)` · `(?!…)`", "Eteenpäinkatsonta: pitää seurata · ei saa seurata"],
                    ["`(?<=…)` · `(?<!…)`", "Taaksepäinkatsonta: pitää edeltää · ei saa edeltää"],
                ]
            ),
            .heading("Toimivia esimerkkejä"),
            .code(language: "regex", caption: "Jokainen 10-numeroinen vietnamilainen puhelinnumero",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Jaa päivämäärä 31/12/2026 kolmeen ryhmään",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "Yksinkertaisen CSV-rivin kolmas solu (ilman lainausmerkkejä)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "ERROR- tai FATAL-tason lokirivit aikaleimoineen",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Tyhjät rivit tai vain tyhjemerkkejä sisältävät rivit",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Tarkkeelliset vietnamilaiset kirjaimet — käytä Unicode-luokkaa, älä luettele niitä",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` tarkoittaa »mitä tahansa Unicode-kirjainta«, joten se osuu myös merkkeihin \
                `ế` ja `đ`. Jokaisen tarkkeellisen vokaalin luettelointi käsin on varma tapa jättää \
                joitakin huomaamatta.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Korvausmerkkijonot",
        summary: "Käytä kaapattuja ryhmiä uudelleen ja muuta kirjainkokoa korvatessasi.",
        keywords: ["korvaa", "takaisinviittaus", "ryhmä", "$1", "\\U"],
        blocks: [
            .heading("Kaapatun ryhmän kutsuminen takaisin"),
            .table(
                headers: ["Kirjoita", "Merkitys"],
                rows: [
                    ["`$1` … `$9`", "Ryhmän n sisältö"],
                    ["`${1}`", "Sama, selkein rajoin — käytä, kun perässä on numero"],
                    ["`\\1`", "Hyväksytään myös; GEditor kirjoittaa sen muotoon `${1}`"],
                    ["`$0`", "Koko osuma"],
                ]
            ),
            .note("""
                Kirjoita `${1}` mieluummin kuin `$1`, kun seuraava merkki on numero. `$123` luetaan \
                ryhmäksi 123; `${1}23` on ryhmä 1 ja sen perässä kaksi numeroa.
                """),
            .heading("Kirjainkoon muuttaminen korvauksen aikana"),
            .table(
                headers: ["Kirjoita", "Merkitys"],
                rows: [
                    ["`\\U`", "ISOT KIRJAIMET tästä eteenpäin"],
                    ["`\\L`", "pienet kirjaimet tästä eteenpäin"],
                    ["`\\u`", "Vain seuraava merkki isoksi"],
                    ["`\\l`", "Vain seuraava merkki pieneksi"],
                    ["`\\E`", "Päätä `\\U`- tai `\\L`-alue"],
                ]
            ),
            .heading("Esimerkkejä"),
            .code(language: "text", caption: "Muuta 31/12/2026 muotoon 2026-12-31",
                  source: """
                    Etsi:    (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Korvaa:  $3-$2-$1
                    """),
            .code(language: "text", caption: "Muuta rivin alun maakuntakoodi isoiksi, säilytä loput",
                  source: """
                    Etsi:    ^([a-z]{2,3})(\\s)
                    Korvaa:  \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Käännä jokainen rivi JSON-merkkijonoksi",
                  source: """
                    Etsi:    ^(.+)$
                    Korvaa:  "$1",
                    """),
            .paragraph("""
                Ryhmästä, joka **ei osallistunut** osumaan, tulee tyhjä merkkijono eikä virhe — joten \
                kuvio, jossa on vaihtoehtoja kuten `(a)|(b)`, korvaa silti siististi ilman että sitä \
                pitäisi kirjoittaa kahdesti.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Etsi ja korvaa koko kansiossa",
        summary: "Käy läpi monta tiedostoa kerralla ja näe tulokset ennen kuin mitään kirjoitetaan.",
        keywords: ["etsi tiedostoista", "grep", "massakorvaus", "kansio"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Etsi koko kansiosta")]),
            .paragraph("""
                Valitse juurikansio, suodata tiedostonimikuviolla ja käy läpi. Tulokset näkyvät \
                tiedostoittain ryhmiteltynä luettelona; rivin napsauttaminen avaa sen tiedoston \
                kyseisestä kohdasta.
                """),
            .bullets([
                "Samat kolme hakutilaa ja sama regex-moottori kuin asiakirjan hakukentässä.",
                "Koko kansion korvaus **esikatselee**, montako tiedostoa ja montako osumaa muuttuu ennen kirjoitusta.",
                "Läpikäynti tapahtuu rinnakkain ja **voidaan keskeyttää** kesken.",
            ]),
            .warning("""
                Koko kansion korvaus kirjoittaa suoraan tiedostoihin, jotka **eivät ole auki**. Ne \
                tiedostot eivät ole avatun asiakirjan kumoamishistoriassa — esikatsele ensin ja pidä \
                varmuuskopio tai versionhallittu arkisto.
                """),
            .heading("Aiemmat haut ja tulosten vienti"),
            .paragraph("""
                Tulospaneeli **säilyttää tämän istunnon haut**. Paneelin yläreunan ponnahdusvalikko \
                luettelee ne osumamäärineen — hae `TODO`, lue puoleenväliin, hae `FIXME` \
                vertaillaksesi ja palaa ensimmäiseen luetteloon käymättä koko kansiota uudelleen läpi.
                """),
            .paragraph("""
                **Vie**-painike avaa nykyisen haun tekstivälilehtenä, yksi tulos riviä kohti muodossa \
                `polku:rivi:sarake: teksti` — se muoto, jota `grep -n` käyttää ja jota kääntäjät \
                käyttävät virheisiin. Jokaisen rivin voi liittää suoraan tämän tuotteen omaan \
                `Siirry`-kenttään, ja sinun `grep`, `awk` ja `sed` lukevat sen ilman omaa jäsentäjää.
                """),
            .note("""
                Historia elää **muistissa** eikä sitä koskaan kirjoiteta levylle: hakutulokset \
                kantavat kunkin osuvan rivin sisällön, ja se on samaa dataluokkaa, jota \
                leikepöytähistoria ei tarkoituksella säilytä.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Rivimerkinnät",
        summary: "Yhdeksän merkintäväriä ja neljä komentoa, jotka tekevät merkityistä riveistä tuloksen.",
        keywords: ["kirjanmerkki", "merkintä", "f2", "suodata rivejä"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Merkintä on tapa suodattaa asiakirjaa **muuttamatta sitä**. Merkitse jokainen \
                kuvioon osuva rivi ja kopioi sitten vain ne pois — tai säilytä vain ne.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Merkitse jokainen nykyiseen hakuun osuva rivi"),
                HelpShortcut("⌘F2", "Merkitse / poista merkintä nykyiseltä riviltä"),
                HelpShortcut("F2 / ⇧F2", "Hyppää seuraavaan / edelliseen merkintään"),
            ]),
            .heading("Tavallinen työnkulku"),
            .steps([
                "`⌘F` sillä kuviolla, jolla haluat suodattaa, esim. `\\bERROR\\b`.",
                "`⌘M` merkitsee jokaisen osuvan rivin.",
                "`Haku ▸ Kopioi merkityt rivit` vetää ne uuteen välilehteen — tai `Säilytä vain merkityt rivit` suodattaa paikallaan.",
            ]),
            .heading("Yhdeksän väriä"),
            .paragraph("""
                Rivi voi kantaa **useaa väriä kerralla**. Käytä eri värejä eri ehdoille ja yhdistä \
                niitä: punainen virheriveille, keltainen yhteen tilaustunnukseen kuuluville riveille, \
                ja etsi sitten rivejä, joilla on molemmat.
                """),
            .bullets([
                "`Käännä merkinnät` — merkityistä riveistä tulee merkitsemättömiä ja päinvastoin.",
                "`Poista kaikki merkinnät` — poistaa jokaisen merkinnän koskematta sisältöön.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Siirry riville",
        summary: "Hyppää riville, sarakkeeseen tai tavupaikkaan.",
        keywords: ["siirry", "rivinumero", "cmd+l", "sijainti", "sarake"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Siirry riville")]),
            .paragraph("""
                Kenttä ymmärtää **kolme merkintätapaa** ja erottaa ne kirjoittamastasi — erillistä \
                valitsinta ei tarvitse napsauttaa.
                """),
            .table(
                headers: ["Kirjoita", "Siirtyy"],
                rows: [
                    ["`120`", "rivin 120 alkuun"],
                    ["`120,5` tai `120:5`", "riville 120, sarakkeeseen 5 — sarake laskee MERKKEJÄ"],
                    ["`@1024`", "tavupaikkaan 1024 tiedostossa"],
                ]
            ),
            .note("""
                `rivi:sarake` on täsmälleen se, miten kääntäjät ja tarkistimet tulostavat sijainnin, \
                joten päätteestä juuri kopioimasi rivin voi liittää suoraan.

                Tavupaikkojen `@` on olemassa syystä: onko `1234` rivi vai tavu? Oikeaa vastausta ei \
                ole, ja väärä arvaus vie kohdistimen aivan muualle ilman mitään merkkiä. Tuo \
                tavuluku on myös se, minkä tilarivi näyttää sijaintikentässä (`@1024`), joten minkä \
                luet siellä, voit kirjoittaa tänne.
                """),
            .bullets([
                "**Rivin pituuden yli** menevä sarake pysähtyy sen rivin loppuun; se ei vuoda seuraavalle.",
                "**Tiedoston yli** menevä tavupaikka vie loppuun — yleensä kopioit sen luvun aiemmasta ajosta, ja tiedosto on voinut kutistua.",
                "Teksti, jota se ei osaa lukea, **ilmoitetaan**, ja kohdistin pysyy paikallaan; se ei hyppää tiedoston alkuun.",
            ]),
            .paragraph("""
                Hyvin suurilla tiedostoilla GEditor ei lue koko tiedostoa päästäkseen perille — \
                riviluettelo rakennetaan vähitellen taustalla.
                """),
            .note("""
                Komentorivityökalu ottaa myös sijainnin: `geditor report.csv:120:5` avaa tiedoston \
                kohdistin rivillä 120, sarakkeessa 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Tiedostot ja istunnot

    static let files = HelpChapter(
        id: "tep",
        title: "Tiedostot ja istunnot",
        summary: "Avaaminen, tallentaminen, välilehdet, ikkunat, työtilat ja miten istunto palaa.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Avaaminen ja tallentaminen",
        summary: "Avaa minkä kokoinen tiedosto tahansa ja tallenna se toisella merkistöllä tai rivinvaihdolla.",
        keywords: ["avaa", "tallenna", "tallenna nimellä", "kahdenna", "nimeä uudelleen", "siirrä"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Uusi asiakirja"),
                HelpShortcut("⌘O", "Avaa tiedosto"),
                HelpShortcut("⌘S", "Tallenna"),
                HelpShortcut("⇧⌘S", "Tallenna nimellä"),
            ]),
            .paragraph("""
                Tiedoston vetäminen ikkunaan avaa sen myös. `Tiedosto ▸ Avaa viimeaikaiset` pitää \
                luettelon tiedostoista, joiden parissa juuri työskentelit.
                """),
            .heading("Tallenna nimellä: kolme asiaa, joita voit muuttaa"),
            .table(
                headers: ["Muutos", "Merkitys"],
                rows: [
                    ["Merkistö", "Kirjoita ulos UTF-8, TCVN3, VNI-Windows… — 36 merkistöä"],
                    ["Rivinvaihdot", "LF (Unix) · CRLF (Windows) · CR (klassinen Mac)"],
                    ["Nimi ja sijainti", "Kuten jokaisessa macOS-tallennusikkunassa"],
                ]
            ),
            .paragraph("""
                Tilarivi näyttää aina merkistön, rivinvaihtotyylin ja tunnistetun kielen. **Minkä \
                tahansa napsauttaminen muuttaa sen heti**, ilman valintaikkunaa.
                """),
            .heading("Kahdenna · nimeä uudelleen · siirrä"),
            .paragraph("""
                Nämä kolme koskevat TIEDOSTOA eivätkä sen sisältöä — ja avoin välilehti seuraa \
                tiedostoa, joten et koskaan menetä paikkaasi.
                """),
            .table(
                headers: ["Komento", "Mitä se tekee"],
                rows: [
                    ["`Kahdenna tiedosto`",
                     "Kopioi sen nimellä `nimi 2.txt` alkuperäisen viereen ja **avaa kopion** — koska ihmiset kahdentavat muokatakseen kopiota"],
                    ["`Nimeä tiedosto uudelleen…`", "Nimeää levyllä; välilehti seuraa uutta nimeä"],
                    ["`Siirrä tiedosto…`", "Siirtää toiseen kansioon; välilehti seuraa"],
                ]
            ),
            .note("""
                Kaikki kolme **kieltäytyvät, kun samanniminen tiedosto on jo** kohteessa; ne eivät \
                koskaan korvaa. Ja kaikki kolme tarvitsevat tiedoston, joka on tallennettu ainakin \
                kerran — asiakirjalla, joka ei ole koskaan ollut levyllä, ei ole mitään kahdennettavaa \
                tai siirrettävää.
                """),
            .heading("Turvallinen kirjoittaminen"),
            .bullets([
                "Kirjoitus on **atominen**: sähkökatko kesken ei koskaan jätä katkennutta tiedostoa.",
                "Jos toinen ohjelma muuttaa tiedostoa sen ollessa auki, GEditor huomaa ja kysyy ennen korvaamista.",
                "iCloud Drivessa tai verkkolevyllä olevat tiedostot kulkevat järjestelmän tiedostokoordinaattorin kautta, jotteivät kaksi konetta astu toistensa varpaille.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Välilehdet, ikkunat ja jaettu näkymä",
        summary: "Monta välilehteä ikkunassa, monta ikkunaa, ja välilehtiä voi vetää niiden välillä.",
        keywords: ["välilehti", "ikkuna", "jaa", "ruutu"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Uusi välilehti"),
                HelpShortcut("⌘W", "Sulje välilehti"),
                HelpShortcut("⇧⌘T", "Avaa viimeksi suljettu välilehti uudelleen"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Seuraava / edellinen välilehti"),
                HelpShortcut("⌥⌘N", "Uusi ikkuna"),
                HelpShortcut("⌃⌘N", "Irrota nykyinen välilehti omaan ikkunaansa"),
            ]),
            .paragraph("""
                Voit vetää välilehden toiseen ikkunaan tai pudottaa sen tyhjään tilaan tehdäksesi \
                uuden ikkunan. **Kiinnitetty välilehti ei matkusta** — kiinnittäminen tarkoittaa \
                »pidä tämä täällä«.
                """),
            .note("""
                `⇧⌘T` avaa viimeksi suljetun välilehden uudelleen, myös **tallentamattoman**: sen \
                sisältö on yhä tallessa.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Kansion avaaminen työtilaksi",
        summary: "Tiedostopuu sivupalkissa, koko projektin haku ja avaaminen yhdellä napsautuksella.",
        keywords: ["työtila", "kansio", "projekti", "sivupalkki"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Avaa kansio työtilaksi")]),
            .paragraph("""
                Puu ilmestyy sivupalkkiin (`⌘0`). Napsauta tiedostoa avataksesi sen, ja `⇧⌘F` etsii \
                koko kansiosta.
                """),
            .note("""
                App Store -versiossa pääsyä kansioon pitää **turva-alueeseen sidottu kirjanmerkki**, \
                joten seuraava käynnistys yltää siihen yhä pyytämättä sinua valitsemaan kansiota \
                uudelleen.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Istunto palautuu itsestään",
        summary: "Lopeta ja avaa uudelleen: jokainen välilehti palaa, myös tallentamattomat.",
        keywords: ["istunto", "palautus", "tallentamaton"],
        blocks: [
            .paragraph("""
                Mitään ei tarvitse kytkeä päälle. Lopeta GEditor ja avaa se uudelleen: välilehdet, \
                niiden järjestys, kohdistinten paikat ja vierityskohdat palaavat kaikki.
                """),
            .heading("Entä tallentamattomat välilehdet"),
            .paragraph("""
                Niiden sisältö säilytetään erillisessä tilannekuvassa, joten nekin palaavat. Jos \
                ohjelma päättyy poikkeavasti, seuraava käynnistys **kysyy** ennen orpojen luonnosten \
                palauttamista — sen sijaan että rakentaisi hiljaa kasan välilehtiä, joita et muista.
                """),
            .warning("""
                Istunto **ei ole varmuuskopio**. Se säilyttää työtilanteen, ei historiaa. Kaikki \
                merkityksellinen on silti tallennettava tiedostoon.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Aiemmin tallennetut versiot",
        summary: "Selaa ja palauta tiedoston vanhempia versioita.",
        keywords: ["versiot", "historia", "palauta", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                Jokaisella tallennuksella GEditor merkitsee **edellisen** version muistiin ennen \
                korvaamista. `Makro ▸ Tallennetut versiot…` avaa niiden selaimen.
                """),
            .bullets([
                "Versiovarasto on **käyttöjärjestelmän**, sama mekanismi jota Applen omat ohjelmat käyttävät.",
                "Vanhemman version palauttaminen on **tavallinen muokkaus** — `⌘Z` kumoaa sen.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Yhä kirjoitettavan tiedoston seuraaminen",
        summary: "Kuten `tail -f`: perään kirjoitettu ilmestyy sitä mukaa kuin se saapuu.",
        keywords: ["tail", "seuraa", "loki", "reaaliaika"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Tiedosto ▸ Seuraa tiedostoa (tail -f)` lataa sen, mitä tiedoston loppuun ilmestyy, \
                ja vierii mukana.
                """),
            .warning("""
                Seurannan aikana asiakirjasta tulee **vain luettava**. Kirjoittaminen samalla kun \
                uutta tekstiä ladataan levyltä tarkoittaa kahta kirjoittajaa yhdestä asiakirjasta, ja \
                häviäjä on aina se, minkä juuri kirjoitit.
                """),
            .note("""
                Tilarivillä lukee **Seurataan** koko ajan, joten minuutteja myöhemminkin tiedät, \
                miksi tiedosto ei ota vastaan kirjoitusta. **Vain luettava** -kentän napsauttaminen \
                kertoo syyn suoraan.

                Seuranta kuuluu **sille välilehdelle, joka sen aloitti**, ei ikkunalle: avaa toinen \
                välilehti ja kirjoita, ja uudet lokirivit virtaavat yhä omaan välilehteensä \
                koskematta muokkaamaasi tiedostoon.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Tulostus",
        summary: "Tulosta macOS:n tavallisen tulostusikkunan kautta.",
        keywords: ["tulosta", "paperi", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Tulosta")]),
            .paragraph("""
                Se käyttää järjestelmän tulostusikkunaa, joten PDF:ksi vieminen tapahtuu myös siellä \
                — `PDF`-painike vasemmalla alhaalla.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Kuvat, PDF:t, Office-tiedostot, ääni, video ja arkistot",
        summary: "Kahdeksan tiedostolajia avautuu GEditorin sisällä ilman toista ohjelmaa.",
        keywords: ["kuva", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arkisto",
                   "ääni", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Laji", "Mitä voit tehdä"],
                rows: [
                    ["Kuvat", "Katsella, zoomata, kiertää; **animoidut kuvat toistuvat** ja ne voi pysäyttää"],
                    ["Ääni", "Toistaa, kelata, säätää äänenvoimakkuutta"],
                    ["Video", "Toistaa, kelata, koko näyttö, kuva kuvassa"],
                    ["PDF", "Lukea, hakea, **merkitä huomautuksia**"],
                    ["Word · Excel · PowerPoint", "Katsella **ja muokata** — `⌘S` kirjoittaa suoraan takaisin tiedostoon"],
                    ["ZIP · TAR · GZ · XZ", "Listata sisällön ja avata kunkin kohteen välilehtenä"],
                    ["7z · RAR ja seitsemän muuta muotoa", "Sama, libarchiven kautta"],
                ]
            ),
            .paragraph("""
                Arkiston sisällä olevan kohteen avaaminen luo uuden välilehden sen sisällöllä. \
                Vietnamilaiset tarkkeet säilyvät sekä nimissä että sisällöissä.
                """),
            .note("""
                Muokkaa jotain kolmesta Office-muodosta, paina `⌘S`, ja se kirjoitetaan takaisin \
                tiedostoon — LibreOffice lukee tuloksen. Tämä reitti on testattu päästä päähän, ei \
                pelkästään viety kopioon.
                """),
            .heading("Ääni ja video käyttävät macOS:n soittimia"),
            .paragraph("""
                Toisto kulkee järjestelmän omien purkajien kautta, joten mitään ylimääräistä ei \
                ladata eikä mitään ylimääräistä tule mukana. Vastineeksi muutama muoto **ei toistu** \
                — `.mkv`, `.webm`, `.avi`, `.wmv` — koska macOS:ssä ei ole niille sisäänrakennettua \
                purkajaa.
                """),
            .paragraph("""
                Tällaisesta tiedostosta GEditor **kertoo syyn** sen sijaan, että näyttäisi mustaa \
                suorakulmiota, ja tarjoaa binäärikatselinta tai toista ohjelmaa.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "PDF-työkalut",
        summary: "Lue, merkitse huomautuksia, ja kokonainen sivukerros: kierrä · siirrä · poista · pura · yhdistä.",
        keywords: ["pdf", "sivu", "kierrä", "poista sivu", "pura", "yhdistä",
                   "huomautus", "korostus", "allekirjoitus"],
        blocks: [
            .paragraph("""
                PDF-näkymässä on **kaksi työkalupalkkia**, ja ne vastaavat eri kysymyksiin. Ylärivi \
                toimii yhden sivun **sisältöön**; alarivi toimii **sivujen joukkoon**.
                """),
            .heading("Ylärivi — lukeminen ja huomautukset"),
            .table(
                headers: ["Painike", "Mitä se tekee"],
                rows: [
                    ["Korosta · Alleviivaa", "Merkitse valittu teksti"],
                    ["Huomautus…", "Liitä huomautus sivulle"],
                    ["Poista huomautukset", "Poista jokainen huomautus nykyiseltä sivulta"],
                    ["Pura teksti uuteen välilehteen", "Siirrä koko teksti välilehteen, jotta voit hakea, suodattaa ja käyttää muita työkaluja"],
                    ["Hakukenttä", "Etsi PDF:n sisältä — **kirjoittaminen ilman tarkkeita löytää silti tarkkeellisen tekstin**"],
                ]
            ),
            .note("""
                Skannatussa PDF:ssä ei ole tekstikerrosta. Purkukomento **kertoo sen** sen sijaan, \
                että avaisi tyhjän välilehden ja jättäisi sinut arvailemaan.
                """),
            .heading("Alarivi — sivutoiminnot"),
            .table(
                headers: ["Painike", "Mitä se tekee", "Kumottavissa"],
                rows: [
                    ["Kierrä vasemmalle · oikealle", "Käännä nykyistä sivua 90°", "Kyllä"],
                    ["Sivu ylös · sivu alas", "Vaihda nykyinen sivu naapurinsa kanssa", "Kyllä"],
                    ["Poista sivuja…", "Poista väliltä, esim. `2-4,7`", "Kyllä"],
                    ["Pura sivuja…", "Kirjoita sivuväli **uudeksi tiedostoksi**", "Ei koske avattuun tiedostoon"],
                    ["Yhdistä PDF…", "Lisää toinen PDF heti nykyisen sivun perään", "Kyllä"],
                    ["Allekirjoita…", "Aseta allekirjoituskuva nykyiselle sivulle", "Kyllä"],
                    ["Muokkaa tekstiä…", "Piirrä korvaava teksti valinnan päälle", "Kyllä"],
                    ["Seuraava tyhjä kenttä", "Hyppää seuraavaan täyttämättömään lomakekenttään", "—"],
                    ["Tyhjennä täytetyt arvot", "Tyhjennä jokainen lomakekenttä", "Kyllä"],
                    ["Kumoa sivumuutos", "Peruuta yksi sivutoimenpide", "—"],
                    ["Tallenna muokattu kopio…", "Kirjoita uusi tiedosto ja **avaa se uudelleen tarkistukseksi**", "—"],
                ]
            ),
            .heading("Täytettävät lomakkeet"),
            .paragraph("""
                Avaa PDF, jossa on lomakekenttiä, ja tilarivi kertoo **montako** niitä on. Kirjoita \
                suoraan sivun kenttiin ja käytä sitten `Tallenna muokattu kopio…`.
                """),
            .bullets([
                "Arvot tallennetaan **elävinä lomakekenttinä**, ei litistettynä tekstinä — joten vastaanottajan Acrobat näkee yhä täytetyn lomakkeen ja voi korjata sitä.",
                "Vietnamilaiset tarkkeet kestävät kirjoita-ja-avaa-uudelleen -kierroksen. Testi vartioi juuri sitä nimellä `Nguyễn Văn Anh`.",
                "`Seuraava tyhjä kenttä` hyppää seuraavaan tyhjään — luonteva reitti pitkän lomakkeen läpi.",
            ]),
            .heading("Allekirjoittaminen"),
            .paragraph("""
                Valmistele allekirjoituskuva (läpinäkyvätaustainen PNG toimii parhaiten), **valitse \
                allekirjoituskohta** — yleensä viivoitettu rivi tai sana »Allekirjoitus« — ja paina \
                sitten `Allekirjoita…`. Ilman valintaa allekirjoitus laskeutuu oikeaan alanurkkaan.
                """),
            .note("""
                Allekirjoitus säilyttää kuvan **kuvasuhteen**: litistetty tai venytetty allekirjoitus \
                näyttää heti väärennetyltä.
                """),
            .heading("Tekstin muokkaus — ja kolme asiaa, jotka on tiedettävä ensin"),
            .paragraph("""
                Valitse muutettava teksti ja paina `Muokkaa tekstiä…`. GEditor **peittää alueen \
                taustavärillä, joka on otettu aivan sen vierestä**, ja piirtää sitten uuden tekstin \
                päälle.
                """),
            .warning("""
                **Vanha teksti on PEITETTY, ei POISTETTU.** Se on yhä tiedostossa ja yhä \
                purettavissa komennolla `Pura teksti uuteen välilehteen` tai millä tahansa muulla \
                työkalulla. Tämä **ei ole sensurointia**: henkilötunnuksen piilottaminen näin \
                piilottaa sen ihmissilmältä, ei koneelta.
                """),
            .bullets([
                "**Uusi teksti löytyy yhä `⌘F`:llä.** Se piirretään oikeana tekstinä, ei kuvana — testillä mitattuna, ei oletettuna.",
                "**Kirjasin on järjestelmäkirjasin**, ei asiakirjan alkuperäinen. Tarkoituksella: PDF:ään upotetuista kirjasimista puuttuvat usein vietnamilaiset tarkkeet, ja `Nguyễn` saapuisi muodossa `Nguy?n`.",
                "**Kuvioidulla taustalla paikka näkyy** — peiteväri otetaan yhdestä kohdasta juuri valinnan vasemmalta puolelta.",
            ]),
            .heading("Miksi piirtää päälle sisältövirran muokkaamisen sijaan"),
            .paragraph("""
                PDF:n sisältövirran suora muokkaus tarkoittaa osajoukkokirjasimia omine koodauksineen, \
                parivälistyksen kolmeen palaan katkaisemia lauseita ja merkkileveystaulukoita, jotka \
                on laskettava uudelleen. Sen tekeminen oikein **jokaiselle** tiedostolle on oma \
                hankkeensa; sen tekeminen väärin turmelee jonkun asiakirjan.
                """),
            .paragraph("""
                Vastineeksi sivun loppuosa **ei muutu ainuttakaan tavua**, ja sivu pysyy sivuna — \
                teksti valitaan, kopioidaan ja haetaan yhä. Päälle piirtäminen **ei** muuta sitä \
                kuvaksi.
                """),
            .heading("Sivuvälin syntaksi"),
            .table(
                headers: ["Kirjoita", "Merkitys"],
                rows: [
                    ["`5`", "Vain sivu 5"],
                    ["`2-4`", "Sivut 2, 3, 4"],
                    ["`-3`", "Alusta sivuun 3"],
                    ["`8-`", "Sivusta 8 loppuun"],
                    ["`1-3,5,9-`", "Useita osia pilkuilla yhdistettynä"],
                ]
            ),
            .paragraph("Sivut lasketaan **ykkösestä**, siitä numerosta jonka näet näytöllä."),
            .warning("""
                Käänteinen väli (`5-2`) ja lopun yli menevä väli (`1-999`) molemmat **hylätään \
                syineen**, ei koskaan hiljaa korjata joksikin lähelle osuvaksi. Sivunpoistokomennolle \
                väärä arvaus tarkoittaa menetettyjä sivuja, ja hiljainen rajaus tekee \
                kirjoitusvirheestä kelvollisen komennon.
                """),
            .heading("Alkuperäistä tiedostoa ei koskaan korvata"),
            .paragraph("""
                Kaikki edellä muuttaa asiakirjaa **muistissa**. Vasta kun painat `Tallenna muokattu \
                kopio…` ja valitset sijainnin, tiedosto kirjoitetaan — ja kirjoituksen jälkeen GEditor \
                **avaa juuri sen tiedoston uudelleen** varmistaakseen, että siinä on yhä kaikki \
                sivunsa.
                """),
            .paragraph("""
                Syy: huonosti kirjoitettu tiedosto makaa levyllä täysin normaalin näköisenä, ja \
                käyttäjä saa tietää vasta lähetettyään sen.
                """),
            .note("""
                Näkymän tilarivillä lukee **· muokattu, ei tallennettu** aina kun asiakirja poikkeaa \
                levyllä olevasta tiedostosta.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
