import Foundation

/// Suomenkielinen ohjesisältö — osa 3: näkymät, vietnam sekä kielet ja muodot.
extension HelpFI {

    static let views = HelpChapter(
        id: "xem",
        title: "Tapoja katsoa asiakirjaa",
        summary: "Sivupalkki, kartta, taittaminen, jaettu näkymä, rivitys, näkymättömät merkit, väritystilat.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Sivupalkki ja funktioluettelo",
        summary: "Kansiopuu ja avoimen tiedoston funktioluettelo yhdessä sarakkeessa.",
        keywords: ["sivupalkki", "funktioluettelo", "rakenne", "tiedostopuu"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Näytä / piilota sivupalkki")]),
            .paragraph("""
                Funktioluettelo rakennetaan kielen **jäsennyspuusta**, joten se seuraa todellista \
                rakennetta eikä arvaa sisennyksestä. Napsauta kohtaa hypätäksesi sinne.
                """),
            .note("Funktioluettelon suodatinkenttä **löytää tarkkeellisen tekstin tarkkeettomasta kirjoituksesta**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Asiakirjakartta",
        summary: "Koko tiedosto kapeana sarakkeena oikealla — myös satojen megatavujen kokoisena.",
        keywords: ["pienoiskartta", "kartta", "yleiskuva"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Näytä / piilota asiakirjakartta")]),
            .paragraph("""
                Kartta kuvaa **koko tiedoston**, ei vain näytöllä olevaa. Kartalla vetäminen hyppää \
                vastaavaan kohtaan.
                """),
            .paragraph("""
                Hakuosumat ja merkityt rivit näkyvät kartalla, joten näet, ovatko ne hajallaan vai \
                ryppäinä, ennen kuin vierität sinne.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Taittaminen",
        summary: "Taita funktiot, lohkot ja taulukot rakenteen mukaan — tai taita tiedosto tasolle.",
        keywords: ["taita", "koodin taitto", "supista"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Taita / avaa lohko kohdistimen kohdalla"),
                HelpShortcut("⌥⇧⌘←", "Taita kaikki"),
                HelpShortcut("⌥⌘→", "Avaa kaikki"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Taita koko tiedosto tasolle 1…8"),
            ]),
            .paragraph("""
                Kielillä, joilla on jäsennyspuu, taittaminen seuraa **todellista rakennetta**. \
                Tiedostoilla ilman kielioppia se seuraa sisennystä.
                """),
            .paragraph("""
                `Taita tasolle` ansaitsee paikkansa syvässä JSONissa ja YAMLissa: tasolle 2 \
                taittaminen tuo koko tiedoston muodon yhdelle näytölle.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Jaettu näkymä",
        summary: "Kaksi ruutua rinnakkain, kahdelle tiedostolle — tai kahdelle kohdalle yhdessä tiedostossa.",
        keywords: ["jaa", "ruudut", "vertaa"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Jaa pystysuunnassa"),
                HelpShortcut("⌥⌘-", "Jaa vaakasuunnassa"),
                HelpShortcut("⌥⌘0", "Poista jako"),
                HelpShortcut("⌥⌘]", "Avaa tämä välilehti toisessa ruudussa"),
                HelpShortcut("⌥⌘[", "Hyppää toiseen ruutuun"),
            ]),
            .paragraph("""
                Kummallakin ruudulla on oma välilehtipalkkinsa. **Saman tiedoston** avaaminen \
                molempiin ruutuihin on sallittua — ne vierivät toisistaan riippumatta, mikä helpottaa \
                tiedoston alun ja lopun vertaamista.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Rivitys",
        summary: "Kolme tilaa: pois, ikkunan reunasta tai kiinteästä sarakkeesta.",
        keywords: ["rivitys", "pehmeä rivitys"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Tila", "Pitkä rivi"],
                rows: [
                    ["Pois", "Vierii vaakasuunnassa"],
                    ["Ikkunasta", "Rivittyy ikkunan reunasta ja seuraa sen kokoa"],
                    ["Sarakkeesta", "Rivittyy asettamastasi sarakkeesta — vaikkapa 80 tai 100"],
                ]
            ),
            .paragraph("""
                Rivitys on **tapa katsoa**, ei muokkaus: rivinvaihtoa ei lisätä, eikä se koskaan \
                päädy kumoamishistoriaan.
                """),
            .note("Nopein reitti tähän on tilarivin `Rivitys: …` -kenttä."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Kirjasinkoko",
        summary: "Zoomaa 8:n ja 32 pisteen välillä.",
        keywords: ["zoom", "kirjasinkoko", "suurempi", "pienempi"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Suurempi teksti"),
                HelpShortcut("⌘-", "Pienempi teksti"),
                HelpShortcut("⌃⌘0", "Takaisin oletuskokoon"),
            ]),
            .paragraph("""
                Rajattu 8:n ja 32 pisteen väliin. Tämäkin on **tapa katsoa**: ei muokkausta, ei \
                mitään kumoamishistoriaan. Oletuskoko on kohdassa `Asetukset…`.
                """),
            .note("`⌘0` EI ole oletuskoko — se näppäin näyttää ja piilottaa sivupalkin."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Näkymättömien merkkien näyttäminen",
        summary: "Kytke yksi ryhmä kerrallaan, sillä kaikki yhtä aikaa on yleensä liikaa.",
        keywords: ["näkymätön", "tyhjemerkki", "nbsp", "nollaleveys", "sarkain"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Näytä / piilota kaikki näkymättömät merkit")]),
            .paragraph("""
                Neljä ryhmää kytketään erikseen, sillä kaikkien yhtaikainen kytkeminen hautaa \
                sisällön pistemetsän alle.
                """),
            .table(
                headers: ["Ryhmä", "Mitä se pyydystää"],
                rows: [
                    ["Välilyönnit", "Rivinloppuiset välilyönnit, epäjohdonmukainen sisennys"],
                    ["Sarkaimet", "Tiedostot, joissa TABit ja välilyönnit sekaisin"],
                    ["Rivinvaihdot", "Tiedostot, joissa CRLF ja LF sekaisin"],
                    ["NBSP · nollaleveys · ohjausmerkit", "Näkymättömät merkit Wordista, verkosta, taulukkolaskennasta"],
                ]
            ),
            .warning("""
                Viimeinen ryhmä on se, joka pelastaa ihmisiä. Verkkosivulta liitetty sitova \
                välilyönti (NBSP) näyttää **täsmälleen** tavalliselta välilyönniltä, mutta se saa \
                jokaisen merkkijonovertailun ja jokaisen suodattimen menemään ohi — eikä sitä näe \
                mitenkään ilman tätä ryhmää.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "CSV-tila ja lokitila",
        summary: "Kaksi väritystapaa, jotka korvaavat syntaksivärityksen, kahdelle datatiedostolajille.",
        keywords: ["csv-tila", "lokitila", "korostus", "sarakkeet", "lokitaso"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("CSV-tila"),
            .paragraph("""
                Antaa kullekin sarakkeelle oman värin **teksti**näkymässä, joten näet, mikä solu on \
                liukunut sarakkeen verran, vaihtamatta taulukkoon.
                """),
            .heading("Lokitila"),
            .paragraph("""
                Värittää rivistä lukemansa **vakavuuden** mukaan: virheet punaisiksi, varoitukset \
                keltaisiksi, kun taas `debug` ja `trace` himmennetään — ne muodostavat suurimman osan \
                lokitiedostosta, ja niiden korostaminen himmentää juuri sen, mitä etsit.
                """),
            .paragraph("`Suodata loki tason mukaan…` piilottaa ne tasot, joita et lainkaan tarvitse."),
            .note("""
                Nämä kaksi värittävät syntaksivärityksen **sijaan**, eivät sen päälle. \
                Lokitiedostossa ei ole syntaksia väritettäväksi, eikä kahdesta värilähteestä samalle \
                tavualueelle jää ennustettavaa voittajaa.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Binäärinäkymä",
        summary: "Heksataulukko mille tahansa tiedostolle — myös 1 Gt:n, ja se avautuu lähes heti.",
        keywords: ["heksa", "binääri", "tavu", "siirtymä", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Näytä ▸ Binäärinäkymä` esittää jokaisen tavun kolmen sarakkeen taulukkona: \
                **siirtymä · heksa · teksti**. Se toimii **mille tahansa** levyllä olevalle \
                tiedostolle, ei vain kuville tai videolle.
                """),
            .table(
                headers: ["Sarake", "Sisältö"],
                rows: [
                    ["Siirtymä", "Tavupaikka heksadesimaalina"],
                    ["Heksa", "16 tavua rivillä, jaettuna kahdeksannen jälkeen laskemisen helpottamiseksi"],
                    ["Teksti", "Tulostuvat ASCII-tavut; kaikki muu on `.`"],
                ]
            ),
            .note("""
                Tekstisarake **ei pura UTF-8:aa**. Vietnamilainen kirjain vie kaksi tai kolme tavua, \
                joten sen esittäminen työntäisi tekstisarakkeen pois linjasta heksasarakkeen kanssa — \
                ja juuri se linja on koko sarakkeen tarkoitus. Tarkkeellisen tekstin lukemiseen käytä \
                tavallista näkymää.
                """),
            .heading("Suuret tiedostot"),
            .paragraph("""
                Tiedosto **kuvataan muistiin**, joten 1 Gt:n tiedoston avaaminen binäärinäkymässä \
                maksaa vain sen, mitä katsot. Mitattuna itsetestisarjassa: **alle millisekunnin**.
                """),
            .paragraph("""
                Näkymä näyttää **yhden 4 Mt:n ikkunan** kerrallaan, ja yläpalkki kertoo, millä \
                alueella olet. Se on järjestelmän taulukkopiirtäjän raja, ei lukemisen: 1 Gt:n \
                tiedostossa on 62,5 miljoonaa riviä, ja tietyn pisteen jälkeen rivit alkavat hypähdellä \
                vierityksessä — ja hypähtelevä heksataulukko on hyödytön.
                """),
            .heading("Sijaintiin hyppääminen"),
            .table(
                headers: ["Kirjoita siirtymäkenttään", "Merkitys"],
                rows: [
                    ["`1F400`", "Heksadesimaali — oletus"],
                    ["`0x1F400`", "Sama, selkeällä etuliitteellä"],
                    ["`#128000`", "Desimaali, kun sinulla on tavumäärä eikä heksasiirtymä"],
                ]
            ),
            .bullets([
                "`‹` ja `›` siirtävät edelliseen / seuraavaan ikkunaan.",
                "**Kopioi valitut rivit** kopioi täsmälleen sen, minkä näet — ilman valintaa se kopioi koko ikkunan.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Markdown-esikatselu",
        summary: "Esitä Markdown muotoiltuna tekstinä — ja sano suoraan, mitä se ei esitä.",
        keywords: ["markdown", "esikatselu", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Esitetään järjestelmän Markdown-tuella: lihavointi, kursivointi, koodi, linkit, \
                luettelot.
                """),
            .warning("""
                **Ei taulukoita eikä syntaksiväritystä koodilohkojen sisällä.** Esikatseluikkuna \
                sanoo sen alareunassaan. Yli **4 Mt**:n asiakirjat hylätään.
                """),
            .paragraph("""
                Tarvitsetko taulukoita ja kaavioita julkaistavaan asiakirjaan? Siihen ovat \
                `.greport.md`-raportit, ei tämä esikatselu.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Kaksi tilaa: View ja Code",
        summary: "Yksi näppäin vaihtaa esitetyn muodon ja muokattavan lähteen välillä, jokaiselle tiedostotyypille.",
        keywords: ["view", "code", "tila", "lähde", "esitetty", "esikatselu"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Vaihda View- ja Code-tilan välillä")]),
            .paragraph("""
                Säädin on **välilehtirivin alapuolisessa palkissa** — sama paikka jokaiselle \
                tiedostotyypille: `View | Code` -kytkin ja sen jälkeen sen tiedoston View-tilan nimi \
                (»Asiakirjasivut«, »Avain–arvo-puu«, »Kaavio«…). Tiedosto, jolla on vain yksi tila, \
                himmentää kytkimen, ja palkki kertoo miksi. Oikeassa reunassa ovat kunkin tyypin omat \
                painikkeet: `.xlsx`:llä on **Taulukko** (muokattava, kirjoitetaan suoraan takaisin), \
                `.pptx`:llä **Jäsennys**.
                """),
            .note("""
                **Word ja PowerPoint käyttäytyvät kuin asiakirjalukija.** Niiden View-tila rakentaa \
                oikeita sivuja — oikeat kirjasimet, koot ja värit, kuvineen, taulukoineen, ylä- ja \
                alatunnisteineen sivunumeroita myöten. Sivu on **täsmälleen kehyksen levyinen** ja \
                zoomattavissa. Excel on tietoinen poikkeus: sen View on **muokattava laskentataulukko**, \
                sillä laskentataulukolla ei ole paperikokoa ennen tulostamista.
                """),
            .note("""
                Vastineeksi sivut ovat **vain luettavia** ja esittävät **levyllä olevan kopion**: \
                muokkaa Codessa tallentamatta, ja sivut näyttävät vanhan version — palkki sanoo sen ja \
                tarjoaa `Tallenna ja esitä uudelleen` -painikkeen.
                """),
            .heading("Määritelmät"),
            .bullets([
                "**Code** on **muokattava lähde**. Tekstitiedostolle se on itse teksti. Binääritiedostolle — PDF, kuva, ääni, video — ei ole tekstimuotoista lähdettä, joten Code on **tavut**, heksana esitettyinä.",
                "**View** on se, mikä Codesta **esitetään**. Se voi olla kauniimpi, lyhyempi tai ajettava — mutta se on aina seuraus, ei koskaan alkuperäinen.",
            ]),
            .paragraph("""
                *»Tällä tyypillä ei ole Codea«* olisi PDF:stä kätevää sanoa, mutta väärin: tavut ovat \
                todella sen lähde.
                """),
            .heading("Missä muokkaus tapahtuu"),
            .paragraph("""
                Muokkaus tapahtuu **Codessa**. Poikkeuksia on tasan **kaksi**, molemmat siksi että \
                Viewissä muokkaaminen on paljon luontevampaa: **CSV-taulukon solut** ja \
                **PDF-lomakekentät**. Molemmat kirjoittavat suoraan lähteeseen, joten toista kopiota \
                ei ilmesty kiistelemään.
                """),
            .heading("Tiedostotyypeittäin"),
            .table(
                headers: ["Tiedostotyyppi", "View", "Code", "Muokkaus"],
                rows: [
                    ["CSV · TSV", "Taulukko", "Raakateksti", "**Molemmat**"],
                    ["Excel `.xlsx`", "Avoimen taulukon ruudukko", "Se taulukko CSV:nä", "**Molemmat**"],
                    ["PDF", "Esitetyt sivut", "Binääri", "**Molemmat** — huomautukset, lomakekentät, sivut"],
                    ["Markdown `.md`", "Esitetty teksti", "Markdown-lähde", "Code"],
                    ["Raportti `.greport.md`", "Raportti kyselyineen ja piirrettyine kaavioineen", "Lähde", "Code"],
                    ["JSON", "Avain–arvo-puu, taitettava", "JSON-lähde", "Code"],
                    ["XML · HTML", "Tunnistepuu, taitettava", "XML-lähde", "Code"],
                    ["YAML", "Avain–arvo-puu sisennyksen mukaan", "YAML-lähde", "Code"],
                    ["Kaaviot `.mmd` · `.dot`", "Piirretty kaavio koko välilehdellä", "mermaid- tai DOT-lähde", "Code"],
                    ["Word `.docx`", "Esitetyt asiakirjasivut", "Purettu Markdown", "Code"],
                    ["PowerPoint `.pptx`", "Esitetyt diasivut", "Markdown-jäsennys", "Code"],
                    ["Lokitiedostot", "Väritetty tason mukaan, suodatettavissa", "Raakateksti", "Code"],
                    ["Kuvat", "Kuva (animoidut toistuvat)", "Binääri", "Vain luku"],
                    ["Ääni · video", "Soitin", "Binääri", "Vain luku"],
                    ["Arkistot", "Sisältöluettelo", "Binääri", "Vain luku"],
                    ["Lähdekoodi, pelkkä teksti", "— ei mitään", "Itse teksti", "Code"],
                ]
            ),
            .note("""
                Lähdekoodilla **ei ole Viewiä**, ja se on normaalia eikä puute: Swift-tiedostolla ei \
                ole katsomisen arvoista esitettyä muotoa.
                """),
            .heading("Wordin ja PowerPointin sivulukija"),
            .paragraph("""
                Sivut pinoutuvat pystysuoraan ja vierivät jatkuvana, kukin valkoisena arkkina harmaalla \
                taustalla — kuten jokaisessa asiakirjalukijassa. Sen säätimet ovat palkin oikeassa \
                reunassa.
                """),
            .table(
                headers: ["Painike / näppäin", "Mitä se tekee"],
                rows: [
                    ["`Sovita leveyteen`", "Arkki on täsmälleen kehyksen levyinen — oletus"],
                    ["`Sovita sivu`", "Koko arkki mahtuu kehykseen"],
                    ["`−` `+`", "Zoomaa askelittain; tai nipistä, tai ⌘ + vieritys"],
                    ["`Etsi`-kenttä tai ⌘F", "Etsi sivujen sisältä, hyppää sinne ja korosta"],
                    ["Enter hakukentässä", "Seuraava osuma"],
                    ["Veto", "Valitse tekstiä; kaksoisnapsautus sanaan, kolmoisnapsautus kappaleeseen"],
                    ["⌘A · ⌘C", "Valitse kaikki · kopioi valinta"],
                    ["Page Up · Page Down · Home · End", "Liiku asiakirjassa"],
                ]
            ),
            .paragraph("""
                Hakukenttä **jättää tarkkeet ja kirjainkoon huomiotta**: `vuong quoc` löytää `Vương \
                quốc`. Palkin merkintä »Sivu 12/363« kertoo, missä olet.
                """),
            .note("""
                **Mitä ei esitetä, suoraan sanottuna:** kelluvat ankkuroidut kuvat (teksti kiertää \
                kuvan) näkyvät tekstinsisäisinä kuvina; alaviitteitä, kaavioita ja PowerPointin \
                SmartArtia ei piirretä. Kun tarvitset täsmällisen vastaavuuden painetun kanssa, avaa \
                se Wordissa.
                """),
            .heading("Solmun napsauttaminen hyppää takaisin lähteeseen"),
            .paragraph("""
                JSON-puu ei ole nätti tuloste: solmun napsauttaminen siirtää kohdistimen **sen solmun \
                ARVOON** tekstissä ja palauttaa välilehden Codeen — koska se, mitä seuraavaksi haluat, \
                on lähes aina muokata juuri napsauttamaasi.
                """),
            .bullets([
                "Säiliösolmut näyttävät **alkioidensa määrän** (`{12}`, `[340]`) sisältönsä sijaan — juuri se vastaa kysymykseen »kannattaako tämä avata«.",
                "**Kaksi ensimmäistä tasoa** on avattu: kymmenentuhannen solmun tiedoston täysi avaaminen tuottaa lähdettä pidemmän luettelon, kun taas täysi sulkeminen tarkoittaa, että mitään ei löydä ilman napsauttelua.",
                "Tiedosto, jonka **syntaksi on virheellinen**, ei saa puolikasta puuta — katkennut puu näyttää asiakirjalta, joka yksinkertaisesti sisältää niin vähän.",
                "XML-puussa attribuutit kantavat `@`-etuliitettä oikeaoppisessa XPath-merkinnässä, eikä **tunnisteiden välinen tyhjemerkki muutu solmuksi** — se on muotoilua, ei sisältöä.",
                "YAML-puu lukee **monen asiakirjan tiedostoja** (`---`): kukin asiakirja on oma juurensa. Rivillä kirjoitetut kokoelmat (`ports: [80, 443]`) pysyvät yhtenä lehtenä — näet jo kaiken, ja avaaminen maksaisi napsautuksen. **Sarkainpohjaisesta sisennyksestä** ilmoitetaan tarkka rivi: se on YAML-virhe, jota silmä ei näe.",
                "PowerPoint-jäsennys rakennetaan **avoimesta tekstistä**, ei levyllä olevasta tiedostosta: jos juuri muokkasit jäsennystä Codessa, puun on kuvattava uutta versiota ja sen solmujen hypättävä siihen uuteen versioon. Puhujan muistiinpanot supistuvat yhdeksi solmuksi, jottei paljon sanova dia näytä paljon sisältävältä.",
                "**Koko välilehden kaavio noudattaa samaa sääntöä**: napsauta solmua ja olet takaisin Codessa kohdistin sen solmun määrittelyssä. Rinnakkaisessa `Mermaid Studio` -paneelissa välilehti ei sulkeudu — muokkain on siinä vieressä, ja kohdistimen siirtäminen riittää nähtäväksi.",
                "Kaaviot myös **avautuvat siitä, missä seisot**: kohdistimen riviä vastaava elementti korostetaan heti välilehden ilmestyessä, joten sitä ei tarvitse metsästää.",
            ]),
            .heading("Suodatinkenttä: kymmenentuhannen solmun puussa haku on itse työ"),
            .paragraph("""
                Solmumäärän alapuolella on suodatinkenttä. Kirjoita siihen, ja puu säilyttää vain \
                osuvat solmut — **yhdessä juuresta niihin johtavan polun kanssa**, sillä kun avain \
                `name` esiintyy kymmenessä eri paikassa, todellinen kysymys on »mikä niistä«, ja vain \
                sen sisältävä haara vastaa siihen. Loput avataan puolestasi: jokaisen tason \
                napsaututtaminen olisi suodattamisen teettämistä uudelleen käsin.
                """),
            .bullets([
                "Se suodattaa **sekä nimikkeitä että arvoja**: `Huế`:n hakeminen on yhtä tavallista kuin avaimen `province` hakeminen.",
                "**Tarkkeeton kirjoitus osuu silti tarkkeelliseen tekstiin** — `da nang` löytää `Đà Nẵng`. Sama vertailu kuin CSV-taulukon suodattimessa ja funktioluettelossa, jottei yhdessä ohjelmassa tarvitse muistaa kolmea hakusääntöä.",
                "Ilman osumia otsikko sanoo **»Ei tuloksia«** sen sijaan, että jättäisi sinut tuijottamaan tyhjää puuta miettien, onko tiedosto rikki.",
                "Tiedoston vaihtaminen tai Viewiin palaaminen **tyhjentää suodattimen**: puu, joka avautuu jo katkaistuna ilman mitään selitystä, on kaikkein hämmentävin tila.",
            ]),
            .heading("Koko puu toimii näppäimistöltä"),
            .paragraph("""
                Viewiin siirtyminen vie kohdistuksen puuhun; sitä ei tarvitse ensin napsauttaa. Ylös ja \
                alas liikkuvat solmujen välillä, vasen ja oikea taittavat ja avaavat, ja kaksi näppäintä \
                päättää katselun — tehden **eri** asioita:
                """),
            .bullets([
                "**Enter** — siirry valittuun solmuun: takaisin Codeen kohdistin sen solmun tavualueella. Täsmälleen kuten napsauttaminen.",
                "**Tab** — siirry puun ja suodatinkentän välillä.",
                "**⌘C** — kopioi valitun solmun **polun**, ei puun takana olevaa tekstiä. JSON ja YAML tuottavat JSONPathin (`$.customer['name']`), jonka voi liittää suoraan tämän tuotteen omaan JSONPath-kenttään tai `yq`:hen; XML tuottaa XPathin (`/order/item[2]/@code`) indekseineen, kun kaksi tunnistetta jakaa nimen; PowerPoint-jäsennys kopioi rivin tekstin, sillä jäsennykselle ei ole polkukieltä keksittäväksi.",
                "**Esc** — paluutie: takaisin Codeen kohdistin **täsmälleen siellä missä se oli**. Katselit puuta, et matkustanut minnekään.",
            ]),
            .heading("Ja toiseen suuntaan: puu avautuu siitä, missä kohdistin seisoo"),
            .paragraph("""
                Viewiin siirtyminen keskeltä kymmenentuhannen rivin tiedostoa **ei** avaa puuta \
                alusta: se avaa polun alas siihen solmuun, joka vastaa kohdistimen paikkaa, ja valitsee \
                sen. Tämä on hyppää-lähteeseen -toiminnon toinen puolisko — ilman sitä View ja Code \
                olisivat kaksi näkymää yhteen asiakirjaan vain **yhteen** suuntaan.
                """),
            .bullets([
                "Se avaa tarvittaessa **kahta tasoa syvemmälle**: kahden tason sääntö vastaa kysymykseen »miltä tämä tiedosto näyttää«, kun taas tässä kysymys on toinen — »missä olen tässä puussa«.",
                "Kohdistin **avaimen** kohdalla (`\"address\":`) valitsee sen merkinnän, vaikka solmun tavualue kattaa vain arvon. Solmua välittömästi edeltävä teksti kuuluu sille solmulle.",
                "Kohdistin **lohkon alussa** — YAML-lohkon avain, dian otsikko, XML-tunnisteen nimi — valitsee sen lohkon eikä sukella sen ensimmäiseen lapseen.",
                "Viewiin siirtyminen **ei siirrä kohdistinta**. Poistu Viewistä ja olet täsmälleen siellä missä olit; View on tapa katsoa, ei komento joka muuttaa sijaintia.",
            ]),
            .heading("Yhdeltäkään tyypiltä ei enää puutu View"),
            .paragraph("""
                **Jokainen tiedostotyyppi, jolle View-tila sopii, esittää nyt sellaisen.** Puuttuvien \
                tyyppien luettelo tyhjeni ja poistettiin.

                Lähdekoodilla ja pelkällä tekstillä ei yhä ole Viewiä — se on normaalia, ei puute, \
                joten ne eivät koskaan olleet sillä listalla.

                Jos saapuu uusi tiedostotyyppi, jonka Viewiä ei ole vielä rakennettu, vaihtokomento \
                sanoo sen ja nimeää puuttuvan sen sijaan, että avaisi tyhjän kehyksen — tyhjä kehys on \
                tyhjä lupaus, kun taas nimetty kieltäytyminen on tietoa.
                """),
            .heading("Kuusi vanhempaa komentoa ovat yhä olemassa"),
            .paragraph("""
                `Taulukko-/tekstinäkymä`, `Markdown-esikatselu`, `Binäärinäkymä`, `Raportin \
                esikatselu`, `Mermaid-kaavion esikatselu`, `Lokitila` — kaikki pysyvät täsmälleen \
                siellä, missä olivat. `⌥⌘V` on **yhteinen sisäänkäynti**, ei korvaaja.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnam

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnam",
        summary: "Vanhat merkistöt, Unicode-normalisointi, tarkkeeton haku ja syöttötavat.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Vietnamilaiset merkistöt",
        summary: "Lue ja kirjoita TCVN3, VISCII, VNI-Windows ja 33 muuta, tunnistettuna itsestään.",
        keywords: ["merkistö", "tcvn3", "abc", "viscii", "vni", "mojibake"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Avasitko vanhan vietnaminkielisen tiedoston ja sait `Tr¦êng §¹i häc` odotetun \
                `Trường Đại học` sijaan? Tiedosto ei ole vioittunut — se tallennettiin Unicodea \
                edeltäneellä merkistöllä.
                """),
            .steps([
                "Napsauta merkistöä **tilarivillä** (tai `Muotoilu ▸ Merkistö…`).",
                "Valitse oikea — vanhoille vietnamilaisille tiedostoille se on yleensä `TCVN3 (ABC)`, `VNI-Windows` tai `VISCII`.",
                "Teksti korjautuu heti; tiedostoa ei tarvitse avata uudelleen.",
                "Säilyttääksesi sen niin: `Tallenna nimellä…` merkistöllä `UTF-8`.",
            ]),
            .heading("Kolme vanhaa vietnamilaista merkistöä"),
            .table(
                headers: ["Merkistö", "Löytyy yleensä"],
                rows: [
                    ["TCVN3 (ABC)", "Valtion papereista ja vanhemmista Word-asiakirjoista pohjoisessa"],
                    ["VNI-Windows", "Kustantamoista, sanomalehdistä ja painoista — yleinen etelässä"],
                    ["VISCII", "Varhaisesta sähköpostista ja Usenetistä"],
                ]
            ),
            .paragraph("""
                GEditor **tunnistaa merkistön** avattaessa. Kun se arvaa väärin, yksi napsautus \
                korjaa sen, ja sisältö puretaan uudelleen sen sijaan että sitä paikattaisiin kirjain \
                kerrallaan.
                """),
            .warning("""
                Vanhaan merkistöön kirjoittaminen menettää ne merkit, joita siinä ei ole. GEditor \
                **laskee ne ja kertoo etukäteen** — esimerkiksi *»12 merkkiä ei ole TCVN3:ssa«* — sen \
                sijaan että muuttaisi ne hiljaa kysymysmerkeiksi.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Rivinvaihdot",
        summary: "LF, CRLF, CR — muunnettuna koko tiedostolle yhdellä napsautuksella.",
        keywords: ["eol", "crlf", "lf", "rivinvaihto", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Tyyli", "Käyttäjä", "Tavut"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac ennen vuotta 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Nykyinen tyyli näkyy tilarivillä; napsauta muuttaaksesi. Kahta tyyliä **sekoittava** \
                tiedosto ilmoitetaan sielläkin — kytke `Näytä näkymättömät ▸ Rivinvaihdot` nähdäksesi \
                tarkalleen missä.
                """),
            .note("**Uusien** tiedostojen rivinvaihtotyyli asetetaan kohdassa `Asetukset…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Unicode-normalisointi",
        summary: "Miksi «ế»:n hakeminen ei joskus löydä mitään, ja miten korjata koko tiedosto.",
        keywords: ["unicode", "nfc", "nfd", "koottu", "hajotettu", "normalisoi", "ei osumia"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                Unicodessa `ế` voidaan kirjoittaa **kahdella eri tavalla**: yhtenä valmiiksi \
                koottuna koodipisteenä (NFC) tai kirjaimena `e` ja kahtena erillisenä tarkkeena \
                (NFD). Näytöllä ne näyttävät samalta; koneelle ne ovat eri merkkijonoja.
                """),
            .paragraph("""
                Seuraus: `ế`:n hakeminen NFD-tiedostosta ei löydä **mitään**, ja käyttäjä päättelee, \
                ettei data ole siellä.
                """),
            .steps([
                "`Muotoilu ▸ Normalisoi Unicode…`",
                "Valitse **NFC** (valmiiksi koottu) — muoto, jota lähes kaikki muu käyttää.",
                "Käytä. Se on yksi kumoamisaskel.",
            ]),
            .note("""
                macOS:stä tulevat tiedostot ovat usein NFD:tä, koska Applen tiedostojärjestelmä \
                tallentaa tiedostonimet niin. Tämä on ylivoimaisesti yleisin syy siihen, ettei \
                Finderista kopioitua dataa löydä enää uudelleen.
                """),
            .paragraph("""
                Kohdassa `Asetukset…` on kytkin **normalisoi NFC:hen tallennettaessa**. Oletuksena \
                pois, koska se muuttaa tiedoston tavuja.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Tarkkeeton kirjoitus löytää silti tarkkeellisen tekstin",
        summary: "Jokainen haku- ja suodatinkenttä vertaa tarkkeet poistettuina.",
        keywords: ["tarkkeet", "haku", "suodatin", "tarkkeeton"],
        blocks: [
            .paragraph("""
                Kirjoita `hue` löytääksesi `Huế`. Kirjoita `da nang` löytääksesi `Đà Nẵng`. Sääntö \
                koskee CSV-taulukon suodatinta, funktiohakua, ohjehakua ja muita suodatinkenttiä.
                """),
            .note("""
                `Đ` käsitellään erikseen, sillä Unicodessa se on **oma kirjaimensa** eikä `D` \
                tarkkeineen — tavallinen tarkkeiden poisto ei koske siihen.
                """),
            .paragraph("""
                CSV-suodatin ottaa myös `=`-etuliitteen tarkkaa vertailua varten. `=`-muoto on \
                **myös tarkkeeton**, sillä suodatin, joka erottaa tarkkeet, jättää käyttäjän \
                uskomaan, että data puuttuu.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Vietnamilaiset syöttötavat",
        summary: "EVKey, OpenKey, Unikey ja macOS:n oma syöttölähde kirjoittavat kaikki suoraan asiakirjaan.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "syöttötapa"],
        blocks: [
            .paragraph("""
                Mitään ei tarvitse asettaa. Sekä Telex että VNI toimivat, myös **usean kohdistimen** \
                yli — kirjoita kerran, ja jokainen kohdistin saa oikein tarkkeellisen kirjaimen.
                """),
            .paragraph("""
                Hakukentät, suodatinkentät ja jokainen valintaikkuna ottavat syöttötavan vastaan \
                aivan kuten muokkain.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Kielet ja muodot

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Kielet ja muodot",
        summary: "Kaksikymmentä sisäänrakennettua kieltä, omat kielimäärittelyt ja työkalut JSONille · XML:lle · YAMLille · lokeille.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Kaksikymmentä sisäänrakennettua kieltä",
        summary: "Väritys oikeasta jäsennyspuusta, kunkin kielen omine kommenttimerkkeineen.",
        keywords: ["syntaksi", "korostus", "kieli", "tree-sitter", "kielioppi"],
        blocks: [
            .paragraph("""
                Kieli tunnistetaan **tiedostopäätteestä** (sekä muutamasta erikoisnimestä kuten \
                `Makefile`, `Dockerfile`, `Gemfile`). Voit vaihtaa sen käsin tilariviltä.
                """),
            .table(
                headers: ["Kieli", "Päätteet", "Rivi- · lohkokommentti"],
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
                Viimeinen sarake on se, mitä `⌘/` käyttää. Kielet ilman rivikommenttia (JSON, CSS, \
                XML) saavat sen sijaan lohkomuodon.
                """),
            .heading("Mitä jäsennyspuun mukana tulee"),
            .bullets([
                "**Funktioluettelo** sivupalkissa seuraa todellista rakennetta, ei sisennysarvauksia.",
                "**Taittaminen** rakenteen mukaan.",
                "**Sulkumerkkien vastinparit**, jotka ohittavat merkkijonojen ja kommenttien sisällä olevat sulut.",
                "**Automaattinen sisennys**, joka lisää tason `{`:n jälkeen ja `:`:n jälkeen Pythonissa ja YAMLissa.",
            ]),
            .note("""
                Kolme raskasta kielioppia (C++, C#, Ruby) elää **laiskasti ladattavassa** kirjastossa \
                — ne ladataan vain, kun avaat noiden kielten tiedoston. Näin käynnistysaika pysyy alle \
                puolessa sekunnissa.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Omat kielimäärittelyt",
        summary: "Väritä oma muotosi yhdellä JSON-tiedostolla — kielioppia ei tarvitse kirjoittaa.",
        keywords: ["udl", "oma kieli", "mukautettu kieli", "oma loki"],
        blocks: [
            .paragraph("""
                Yrityksen sisäinen lokimuoto, oma asetuskieli, pieni DSL — millään näistä ei ole \
                tree-sitter-kielioppia, ja sellaisen kirjoittaminen vaatii kääntäjän ja jonkin verran \
                jäsennysteoriaa.
                """),
            .paragraph("""
                Sen sijaan GEditor ottaa vastaan **taulukko-ohjatun leksikaalisen jäsentäjän** \
                JSONina esitettynä. Laita tiedosto GEditorin asetushakemiston `grammars/`-kansioon ja \
                käynnistä uudelleen.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — kokonainen kieli",
                  source: """
                    {
                      "name": "Internal log",
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
                    """),
            .heading("Jokainen avain"),
            .table(
                headers: ["Avain", "Tyyppi", "Merkitys"],
                rows: [
                    ["`name`", "merkkijono", "Tilarivillä näkyvä nimi"],
                    ["`extensions`", "merkkijonotaulukko", "Tiedostopäätteet, **ilman pistettä**"],
                    ["`caseSensitive`", "totuusarvo", "Erottavatko avainsanat kirjainkoon"],
                    ["`lineComment`", "merkkijono", "Rivin loppuun ulottuvan kommentin merkki; jätä pois, jos sellaista ei ole"],
                    ["`blockComment`", "kahden merkkijonon taulukko", "`[avaa, sulje]`"],
                    ["`stringDelimiters`", "merkkijonotaulukko", "Kukin alkio on **yksi** merkki, joka avaa/sulkee merkkijonon"],
                    ["`escapeCharacter`", "merkkijono", "Ohjausmerkki merkkijonojen sisällä; tyhjä tarkoittaa, ettei kielellä ole sellaista"],
                    ["`keywordGroups`", "olio", "Ryhmän nimi → avainsanaluettelo; kolme ryhmää saa kolme väriä"],
                ]
            ),
            .paragraph("""
                Kolme ryhmänimeä, jotka saavat omat värinsä, ovat `keyword`, `type` ja `constant`.
                """),
            .warning("""
                Tämä jäsentäjä **ei ymmärrä sisäkkäisyyttä**. Rakenteellinen taittaminen, \
                funktioluettelo ja älykäs sulkumerkkien vastinparien haku pysyvät kahdenkymmenen \
                sisäänrakennetun kielen etuoikeutena. Se on tietoinen vaihtokauppa: vastineeksi \
                määrittelet kielen kymmenessä minuutissa päivän sijaan.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "JSON-työkalut",
        summary: "Muotoile uudelleen, tiivistä, lajittele avaimet ja tarkista JSON Schemaa vasten.",
        keywords: ["json", "muotoile", "tiivistä", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Komento", "Mitä se tekee"],
                rows: [
                    ["Muotoile uudelleen", "Rivittää ja sisentää luettavaksi"],
                    ["Tiivistä", "Poistaa kaikki tarpeettomat tyhjemerkit"],
                    ["Lajittele avaimet", "Järjestää jokaisen olion avaimet aakkosjärjestykseen — jotta kahta JSON-tiedostoa voi **verrata**"],
                    ["Tarkista JSON Schemaa vasten…", "Tarkistaa asiakirjan skeematiedostoa vasten ja luettelee kunkin ongelman rivinumeroineen"],
                ]
            ),
            .paragraph("""
                Sovelletut säännöt ovat **tiukka RFC 8259**: ei loppupilkkuja, ei kommentteja, ei \
                `NaN`. Syntaksivirhe osoittaa tarkan rivin ja sarakkeen.
                """),
            .note("""
                Myös **JSONL**-tiedostot (yksi olio riviä kohti) tunnistetaan, ja niillä on oma \
                työkalusarjansa tietopaketti-luvussa.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "JSONPath-kyselyt",
        summary: "Vedä suuresta JSON-tiedostosta juuri se osa, jonka tarvitset.",
        keywords: ["jsonpath", "json-kysely", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Kirjoita lauseke; tulokset ilmestyvät luettelona, johon voi hypätä."),
            .table(
                headers: ["Kirjoita", "Merkitys"],
                rows: [
                    ["`$`", "Asiakirjan juuri"],
                    ["`$.name`", "Avain `name` juuressa"],
                    ["`$.orders[0]`", "Taulukon ensimmäinen alkio"],
                    ["`$.orders[*].total`", "**Jokaisen** alkion avain `total`"],
                    ["`$..province`", "Avain `province` **millä tahansa syvyydellä**"],
                    ["`$.orders[1:3]`", "Viipale: alkiot 1 ja 2"],
                ]
            ),
            .code(language: "text", caption: "Jokaisen tilauksen maakuntakoodi, kuinka syvällä tahansa",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "XML-työkalut",
        summary: "Muotoile uudelleen, tiivistä, tarkista syntaksi ja tarkista DTD:tä tai XSD:tä vasten.",
        keywords: ["xml", "xsd", "dtd", "schema", "tarkista", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Komento", "Mitä se tekee"],
                rows: [
                    ["Muotoile uudelleen", "Sisentää tunnistesyvyyden mukaan"],
                    ["Tiivistä", "Poistaa tunnisteiden välisen tyhjemerkin"],
                    ["Tarkista syntaksi", "Puuttuvat sulkevat tunnisteet, väärä sisäkkäisyys, kelvottomat merkit"],
                    ["Tarkista DTD/XSD:tä vasten…", "Tarkistaa skeemaa vasten ja ilmoittaa kunkin ongelman rivinumeroineen"],
                    ["Suorita XPath…", "Ajaa XPath-lausekkeen; tulokset avautuvat uuteen välilehteen"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Kirjoita lauseke, ja tulokset avautuvat **tekstivälilehtenä**, yksi solmu riviä \
                kohti. Esimerkiksi: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Tulokset EIVÄT hyppää lähdetiedoston kohtaan.** Järjestelmän XPath-suoritin \
                rakentaa oman puunsa eikä säilytä kunkin solmun tavupaikkaa, joten takaisin tulee \
                SISÄLTÖÄ eikä koordinaatteja. Päästäksesi tarkkaan kohtaan käytä `⌘F`:ää juuri \
                löytämääsi merkkijonoon.
                """),
            .paragraph("""
                `.xml`- ja `.html`-tiedostoissa `>`:n kirjoittaminen avaavan tunnisteen päättämiseksi \
                saa **sulkevan tunnisteen ilmestymään** kohdistin niiden väliin. Itsesulkeutuvat \
                tunnisteet (`<br/>`), esittelyt (`<?xml …?>`) ja kommentit eivät — niillä ei ole \
                mitään suljettavaa.
                """),
            .warning("""
                XML:n uudelleenmuotoilu **muuttaa tunnisteiden välistä tyhjemerkkiä**. Asiakirjoissa, \
                joissa se tyhjemerkki on merkityksellinen — vaikkapa XHTML, jossa on tekstiä \
                tunnisteiden sisällä — tämä muuttaa näytettävää. Se on yksi kumoamisaskel, joten `⌘Z` \
                peruuttaa sen.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "YAML-tarkistus",
        summary: "Nappaa kaksi yleisintä YAML-virhettä: toistuvat avaimet ja sarkainsisennys.",
        keywords: ["yaml", "yml", "lint", "toistuva avain", "sisennys"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Toistuvat avaimet** yhdessä kuvauksessa — useimmat YAML-lukijat ottavat **viimeisen** ja pudottavat hiljaa aiemmat, joten asetustiedosto voi käyttäytyä aivan toisin kuin odotat.",
                "**Sarkainsisennys** — YAML kieltää sarkaimet sisennyksessä, ja kirjastojen virheilmoitukset siitä ovat yleensä käsittämättömiä.",
            ]),
            .note("Kytke `Näytä näkymättömät ▸ Sarkaimet` nähdäksesi heti, mikä tyhjemerkki on sarkain."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Lokitiedostot",
        summary: "Seitsemän vakavuustasoa, suodatus tason mukaan, ja miten lukea hyvin suurta lokia.",
        keywords: ["loki", "virhe", "varoitus", "suodatin", "taso"],
        blocks: [
            .paragraph("""
                Kytke `Näytä ▸ Lokitila (väritä tason mukaan)`. GEditor lukee vakavuuden **kunkin \
                rivin alusta** — aikaleiman ja prosessin nimen jälkeen.
                """),
            .table(
                headers: ["Taso", "Väri"],
                rows: [
                    ["CRITICAL · ERROR", "Punainen"],
                    ["WARNING", "Keltainen"],
                    ["NOTICE", "Korostusväri"],
                    ["INFO", "Tavallinen teksti"],
                    ["DEBUG · TRACE", "Himmennetty"],
                ]
            ),
            .paragraph("""
                `Suodata loki tason mukaan…` piilottaa alemmat tasot kokonaan. Rivit, joiden tasoa \
                **ei tunnisteta** — vaikkapa pinojäljen jatko — jätetään rauhaan sen sijaan, että \
                niille annettaisiin edellisen rivin taso.
                """),
            .heading("Suuren lokin lukeminen askel askeleelta"),
            .steps([
                "Avaa tiedosto — gigatavuluokkakin avautuu lähes heti.",
                "`Näytä ▸ Lokitila` nähdäksesi punaiset kohdat.",
                "`⌥⌘M` asiakirjakartalle: onko punainen ryppäänä yhdessä kohtaa vai levinnyt pitkin tiedostoa?",
                "`⌘F` virhekoodille, `⌘M` merkitsemään jokaisen osuvan rivin.",
                "`Haku ▸ Kopioi merkityt rivit` vetämään ne uuteen välilehteen.",
                "Vieläkö käynnissä? `Tiedosto ▸ Seuraa tiedostoa (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
