import Foundation

/// Suomenkielinen ohjesisältö — osa 4: taulukkodata, datan siivous ja datan louhinta.
extension HelpFI {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Taulukkodata",
        summary: "Katso CSV taulukkona, suodata, lajittele, tarkista rakenne, kysele SQL:llä, muunna.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "CSV:n katsominen taulukkona",
        summary: "Miljoona riviä vierii yhä tasaisesti, otsikot pysyvät paikallaan, eikä lähdetekstiin kosketa.",
        keywords: ["csv", "taulukko", "ruudukko", "tsv", "excel", "sarakkeet"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Vaihda taulukon ja tekstin välillä")]),
            .paragraph("""
                Taulukko on **virtualisoitu**: vain näkyvät rivit rakennetaan, joten miljoonan rivin \
                tiedosto vierii kuin sadan rivin.
                """),
            .bullets([
                "**Otsikkorivi pysyy paikallaan** vierittäessä — rivillä 40 000 tiedät yhä, mikä yhdeksäs sarake on.",
                "Muokkaa solua taulukossa; muutos menee suoraan lähdetekstiin.",
                "Taulukko ja teksti ovat **kaksi näkymää yhteen tiedostoon**, eivät kaksi kopiota.",
                "**⌘C kopioi valitun rivin**, solut TABilla erotettuina — liitä suoraan Exceliin tai Numbersiin, ja jokainen solu osuu oikein. TABeja tai rivinvaihtoja sisältävät solut lainataan, jottei kohde jaa niitä kahtia.",
            ]),
            .note("""
                Erotin tunnistetaan avattaessa (pilkku, puolipiste, TAB, pystyviiva). Jos arvaus on \
                väärä, vaihda se komennolla `CSV ▸ Vaihda erotin…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Monitaulukkoiset laskentataulukot",
        summary: "Avaa mikä tahansa .xlsx:n taulukko, ja ⌘S kirjoittaa takaisin siihen taulukkoon, jota katsot.",
        keywords: ["excel", "xlsx", "taulukko", "työkirja", "monta taulukkoa"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Avaa `.xlsx`, ja GEditor näyttää **ensimmäisen taulukon** CSV-ruudukkona. `CSV ▸ \
                Valitse taulukko…` luettelee tiedoston jokaisen taulukon ja avaa valitsemasi samaan \
                välilehteen.
                """),
            .heading("Kirjoittaminen takaisin OIKEAAN taulukkoon"),
            .paragraph("""
                `⌘S` kirjoittaa muutoksesi **siihen taulukkoon, jota katsot**, ei ensimmäiseen. \
                Muihin taulukoihin ei kosketa ainuttakaan tavua.
                """),
            .note("""
                Taulukko muistetaan **nimellä**, ei sijainnilla. Näin taulukoiden järjestyksen \
                muuttaminen Excelissä kahden istunnon välillä ei ohjaa kirjoitusta väärään paikkaan.
                """),
            .warning("""
                Jos avattu taulukko on **nimetty uudelleen tai poistettu** Excelissä sen jälkeen kun \
                avasit sen, `⌘S` **kieltäytyy kirjoittamasta** ja sanoo sen. Ensimmäiseen taulukkoon \
                palaaminen tarkoittaisi yhden taulukon sisällön kaatamista toisen päälle — tiedosto \
                tallentuisi silti, avautuisi silti, ja pitäisi vain datan väärässä paikassa.
                """),
            .heading("Taulukon vaihtaminen tallentamattomin muutoksin"),
            .paragraph("""
                Taulukon vaihtaminen korvaa koko välilehden sisällön, joten jos jotain on \
                tallentamatta, GEditor **kysyy ensin**. `⌘Z` ei voi tuoda sitä takaisin, sillä koko \
                asiakirja vaihdettiin.
                """),
            .heading("Mitä maksaa tuoda Excel alas ruudukoksi"),
            .paragraph("""
                Säilyy **arvot** — myös kaavojen tulokset, täsmälleen ne luvut, joita Excel näyttää. \
                Ei säily: kirjasimet, värit, yhdistetyt solut, upotetut kaaviot ja itse kaavat.
                """),
            .paragraph("""
                Vastineeksi se taulukko saa koko muun tuotteen: suodatuksen, lajittelun, \
                SQL-kyselyt, siivouspöydän, laadun pisteytyksen, louhinnan, kaaviot.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Suodatus ja lajittelu taulukossa",
        summary: "Suodatinkenttä sarakkeittain, joka ymmärtää lukuvertailun ja tarkkeettoman kirjoituksen.",
        keywords: ["suodatin", "lajittele", "sarake", "haku taulukosta"],
        blocks: [
            .paragraph("Napsauta sarakeotsikkoa lajitellaksesi. Sen alla oleva suodatinkenttä ottaa vastaan:"),
            .table(
                headers: ["Kirjoita suodattimeen", "Merkitys"],
                rows: [
                    ["`hue`", "Sisältää `hue`, **tarkkeettomasti** — löytää myös `Huế`"],
                    ["`=Huế`", "Täsmälleen `Huế` (yhä tarkkeettomasti)"],
                    ["`>100`", "Suurempi kuin 100"],
                    ["`>=100`", "100 tai enemmän"],
                    ["`<0`", "Pienempi kuin 0"],
                    ["`100..200`", "Väliltä 100–200"],
                    ["tyhjä", "Ei suodatinta tälle sarakkeelle"],
                ]
            ),
            .paragraph("""
                Usean sarakkeen suodatus on **ja**: rivin on täytettävä ne kaikki. Lukuvertailu \
                ohittaa ei-numeeriset solut sen sijaan, että kohtelisi niitä nollina.
                """),
            .note("""
                Suodatus on **tapa katsoa**, ei poisto. Tyhjennä suodatin, ja jokainen rivi palaa.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Taulukon rakenteen tarkistus",
        summary: "Etsi rivit väärällä sarakemäärällä ja solut väärällä tyypillä — tee tämä ensin.",
        keywords: ["tarkista", "sarakemäärä", "väärä tyyppi", "rikkinäinen data"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                Tämä on se, mikä ajetaan **ennen** kaikkea muuta tiedostolle, jonka joku lähetti. Se \
                vastaa kahteen kysymykseen:
                """),
            .bullets([
                "**Millä riveillä on väärä sarakemäärä?** Yleensä solu, jossa on pilkku ilman lainausmerkkejä — ja se sekoittaa jokaisen sitä seuraavan rivin.",
                "**Millä soluilla on muusta sarakkeesta poikkeava tyyppi?** Esimerkiksi `n/a` lukusarakkeessa.",
            ]),
            .paragraph("Tulokset näkyvät luettelona; napsauta yhtä hypätäksesi sille riville."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Sarakkeiden poistaminen",
        summary: "Poista yksi tai useampi sarake tiedostosta kokonaan.",
        keywords: ["poista sarake", "pudota sarake"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Valitse luettelosta poistettavat sarakkeet ja käytä. Se on **yksi** kumoamisaskel \
                riippumatta siitä, montako riviä tiedostossa on.
                """),
            .warning("""
                Toisin kuin suodatus, tämä **muokkaa oikeaa tiedostoa**. Jos haluat vain piilottaa \
                sarakkeita, käytä SQL-kyselyä, jossa luettelet haluamasi sarakkeet.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "CSV:n kysely SQL:llä",
        summary: "DuckDB:n täysi SQL, ajettuna suoraan avoimeen tiedostoon — vain luku.",
        keywords: ["sql", "kysely", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                Avoin taulu on nimeltään **`t`**. Moottori on **DuckDB**, joten `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, ikkunafunktiot ja alikyselyt toimivat kaikki.
                """),
            .code(language: "sql", caption: "Liikevaihto maakunnittain, suurin ensin",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Suodatus päivämäärän ja tekstiehdon mukaan",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Kunkin maakunnan osuus kokonaisuudesta — ikkunafunktiolla",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Liitos toiseen levyllä olevaan tiedostoon",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Vain luku, ja se on kova takuu"),
            .bullets([
                "Tietokanta elää **muistissa**; lähdetiedostoa vain luetaan.",
                "Hyväksytään tasan **yksi lause**, ja sen **on oltava `SELECT`**. Kaikki muu — myös `COPY … TO 'file'`, jolla DuckDB aivan hyvin osaisi kirjoittaa levylle — estetään ennen kuin se yltää mihinkään dataan.",
            ]),
            .warning("""
                DuckDB lukee **tiedostoja**, ei muistia. Jos asiakirjassa on tallentamattomia \
                muutoksia, GEditorin on kirjoitettava väliaikainen kopio ennen kyselyä. Hyvin suuren \
                tallentamattoman tiedoston kohdalla se **pysähtyy ja sanoo sen** sen sijaan, että \
                kirjoittaisi hiljaa satoja megatavuja levylle yhtä kyselyä varten.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Pivot-taulukot ja pikakaaviot",
        summary: "Pivotoi ja piirrä suoraan kyselyn tuloksesta.",
        keywords: ["pivot", "kaavio", "ristiintaulukointi", "koonti"],
        blocks: [
            .paragraph("""
                Molemmat avautuvat **kyselyn tulostaulukosta**: aja SQL-lause ja käytä sitten \
                paneelin Pivot- tai Kaavio-painiketta.
                """),
            .heading("Pivot"),
            .paragraph("""
                Valitse **rivi**sarake, **sarake**sarake, **arvo**sarake ja koontifunktio (summa, \
                lukumäärä, keskiarvo, pienin, suurin) — kuten laskentataulukon pivot-taulukossa.
                """),
            .heading("Kaaviot"),
            .paragraph("""
                Pylväs, viiva, piirakka, hajonta. Luvut muotoiltuna vietnamilaisittain tai \
                eurooppalaisittain, ja kaavion voi viedä PNG:nä tai SVG:nä liitettäväksi muualle.
                """),
            .note("""
                Haluatko kaavion, joka **päivittyy datan mukana** jokaisella rakennuksella? Se on \
                `chart`-lohko `.greport.md`-raportissa.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Taulukon muuntaminen toiseen muotoon",
        summary: "TSV, JSON, XML, Markdown-taulukot, SQL INSERT -lauseet — esikatseluineen.",
        keywords: ["muunna", "vie", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Muoto", "Hyödyllinen"],
                rows: [
                    ["TSV", "Liittämiseen laskentataulukkoon ilman huolta soluissa olevista pilkuista"],
                    ["JSON", "API:n, skriptin tai muun työkalun syötteeksi"],
                    ["XML", "Vanhoihin järjestelmiin, jotka vaativat XML:ää"],
                    ["Markdown-taulukko", "Liittämiseen dokumentaatioon, README:hen, tikettiin"],
                    ["SQL INSERT -lauseet", "Lataamiseen tietokantaan"],
                ]
            ),
            .paragraph("""
                Valintaikkuna **esikatselee viisi ensimmäistä riviä** ennen uuden välilehden luomista \
                — viisi riviä riittää vahvistamaan taulun nimen, lainaukset ja sen, mistä sarakkeista \
                tuli lukuja.
                """),
            .note("""
                Esikatselu kutsuu **samaa funktiota**, joka tuottaa oikean tulosteen, viiteen riviin \
                rajattuna. Se ei ole jäljitelmä, joka voisi olla eri mieltä lopputuloksen kanssa.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Erottimen vaihtaminen",
        summary: "Muunna tiedosto pilkun, puolipisteen, TABin ja pystyviivan välillä.",
        keywords: ["erotin", "pilkku", "puolipiste", "tab", "eurooppalainen csv"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Vietnamilaisesta tai eurooppalaisesta Excelistä viedyt tiedostot käyttävät yleensä \
                **puolipistettä**, koska siellä pilkku on desimaalierotin.
                """),
            .warning("""
                Erottimen vaihtaminen **kirjoittaa koko tiedoston uudelleen**. Uutta erotinta \
                sisältävät solut lainataan — muuten taulukon rakenne rikkoutuu.
                """),
            .note("""
                **Jos tunnistus oli väärä, tämä ei ole haluamasi komento.** Tässä on kaksi eri \
                työtä, aivan kuten merkistöparissa »tulkitse uudelleen« / »muunna«:

                • *Tiedosto on oikeasti puolipiste-eroteltu ja arvasimme pilkun* — napsauta \
                **tilarivin** `CSV · …` -kenttää ja valitse oikea. Tiedostosta ei muutu tavuakaan; \
                vain se, miten se luetaan.

                • *Tiedosto on oikeasti pilkkueroteltu, ja haluat puolipisteet* — käytä tämän sivun \
                komentoa. Se kirjoittaa tiedoston uudelleen.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Datan siivous

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Datan siivous — koko prosessi",
        summary: "Raa'asta tiedostosta käyttökelpoiseen taulukkoon, ja standardi, jonka voi ajaa kuukausittain uudelleen.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Siivousprosessi päästä päähän",
        summary: "Kuusi askelta tuntemattomasta tiedostosta luotettavaan taulukkoon, ja standardi ensi kuulle.",
        keywords: ["siivous", "siivoa", "prosessi", "normalisoi", "siisti data"],
        blocks: [
            .paragraph("""
                Datan siivous on **harvoin kertaluontoista**. Ihmiset saavat saman raporttipohjan joka \
                kuukausi, ja joka kuukausi samat sarakkeet on normalisoitava samalla tavalla. Tämä \
                prosessi on suunniteltu juuri siihen: teet sen käsin kerran ja ajat sen sitten \
                uudelleen yhdellä komennolla.
                """),
            .heading("Kuusi askelta"),
            .steps([
                "**Katso ensin rakennetta.** `CSV ▸ Tarkista data` — millä riveillä on väärä sarakemäärä, millä soluilla väärä tyyppi. Tämä tulee ensin, koska yksi vinossa oleva rivi tekee jokaisesta myöhemmästä tilastosta merkityksettömän.",
                "**Lue dataprofiili.** Sarakkeittain: montako tyhjää solua, montako eri arvoa, mikä tyyppi, missä poikkeavat ovat. Tässä ymmärrät tiedoston ennen kuin muutat mitään.",
                "**Avaa siivouspöytä** (`⇧⌘L`). Se havaitsee sekalaiset päivämäärämuodot, vietnamilaiset luvut eurooppalaisten seassa, irralliset tyhjemerkit, puuttuvat arvot. **Esikatsele ennen→jälkeen**, ja käytä sitten.",
                "**Käsittele sumeat kaksoiskappaleet**, jos nimi- tai osoitesarakkeessa on käsin kirjoitettuja muunnelmia. Tässä päätät sinä; kone vain ehdottaa.",
                "**Tallenna se reseptinä.** Juuri suorittamasi askelsarja kirjoitetaan nimettyyn JSON-tiedostoon — se tiedosto on tietämyksesi tästä datasta.",
                "**Kirjoita laatusäännöstö** `.gquality.yaml` ja pisteytä. Tästä lähtien ensi kuun tiedosto ajetaan reseptin läpi ja pisteytetään, ja **komentoriviportti** palauttaa nollasta poikkeavan paluuarvon epäonnistuessaan.",
            ]),
            .heading("Miksi tässä järjestyksessä"),
            .bullets([
                "Rakenne **ennen** profiilia: vinossa olevan taulukon tilastot ovat tilastoja toisesta sarakkeesta.",
                "Profiili **ennen** siivousta: sinun on tiedettävä `2 % tyhjää` ennen kuin päätät täyttää tai pudottaa.",
                "Sumeat kaksoiskappaleet **normalisoinnin jälkeen**: `CÔNG TY  A` ja `Công ty A` paljastuvat samaksi vasta kun tyhjemerkit ja kirjainkoko on ratkaistu.",
                "Resepti **ennen säännöstöä**: resepti korjaa, säännöt tuomitsevat — korjaamattoman taulukon pisteytys tuottaa vain matalan luvun, jota jo odotit.",
            ]),
            .heading("Ensimmäisen kerran jälkeen kukin kuukausi on yksi komento"),
            .code(language: "bash", caption: "Siivoa ja pisteytä, paluuarvo CI:tä varten",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Paluuarvo **0** tarkoittaa läpi, **1** hylätty, **2** ajonaikainen virhe. \
                `--record-history` lisää rivin historiatiedostoon, jotta seuraava ajo voi verrata \
                ajautumaa.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Dataprofiili",
        summary: "Yksi kuvaus saraketta kohti: tyyppi, tyhjät, eri arvot, jakauma.",
        keywords: ["profiili", "saraketilasto", "null", "eri arvot"],
        blocks: [
            .paragraph("""
                Profiili **kuvaa**; se ei tuomitse. Se sanoo *»tämä sarake on 2 % tyhjä«*; onko 2 % \
                hyväksyttävää, kuuluu laatusäännöstölle.
                """),
            .table(
                headers: ["Mitta", "Miten sitä luetaan"],
                rows: [
                    ["Tyyppi", "Pääteltynä itse datasta, ei sarakkeen nimestä"],
                    ["Tyhjät solut", "Puuttuvien arvojen määrä ja osuus"],
                    ["Eri arvot", "1 tarkoittaa vakiosaraketta; rivimäärän suuruinen tarkoittaa avainsaraketta"],
                    ["Pienin · suurin · keskiarvo", "Vain lukusarakkeille"],
                    ["Yleisimmät arvot", "Huomaa virhekoodi tai liikaa käytetty oletusarvo heti"],
                ]
            ),
            .warning("""
                Eri arvojen laskennalla on kynnys. Sen yli näytetty luku on **alaraja**, ja profiili \
                **sanoo sen olevan arvio** sen sijaan, että sekoittaisi sen tarkkoihin lukuihin.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "Datan siivouspöytä",
        summary: "Seitsemän normalisointia, aina esikatseltuina, aina yksi kumoamisaskel, ei koskaan arvaten.",
        keywords: ["siivoa", "normalisoi", "päivämäärät", "luvut", "täytä puuttuvat"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Avaa siivouspöytä")]),
            .table(
                headers: ["Toimenpide", "Mitä se tekee"],
                rows: [
                    ["Normalisoi päivämäärät", "Tuo sarakkeen jokaisen päivämäärämuodon yhteen muotoon"],
                    ["Normalisoi luvut", "Ratkaisee desimaalierottimen ja tuhaterottimen"],
                    ["Leikkaa tyhjemerkit", "Poistaa ne molemmista päistä; halutessa tiivistää myös sisäiset jaksot"],
                    ["Muuta kirjainkokoa", "Yhtenäistää sarakkeen kirjainkoon"],
                    ["Täytä kiinteällä arvolla", "Korvaa tyhjät solut kirjoittamallasi arvolla"],
                    ["Täytä naapurista", "Ottaa arvon ylä- tai alapuolelta"],
                    ["Poista rivit, joissa tyhjiä soluja", "Pudottaa rivit, joilta puuttuu dataa"],
                ]
            ),
            .heading("Kolme takuuta koko pöydältä"),
            .bullets([
                "**Aina esikatseltu.** Ennen→jälkeen-taulukko ja muuttuvien solujen määrä.",
                "**Yksi kumoamisaskel** koko ajolle, vaikka se koskisi miljoonaa solua.",
                "**Raportti jälkeenpäin**: montako solua muuttui ja mitkä eivät olleet luettavissa.",
            ]),
            .heading("Periaate: älä koskaan arvaa"),
            .paragraph("""
                Solu, jota ei voi lukea varmasti, **merkitään ja jätetään rauhaan**. Otetaan \
                `03/04/2026` sarakkeessa, jossa molemmat käytännöt sekoittuvat — onko se 3. huhtikuuta \
                vai 4. maaliskuuta? GEditor kysyy sinulta päivä/kuukausi-järjestystä sen sijaan, että \
                valitsisi puolestasi.
                """),
            .warning("""
                Päivämääräsarakkeen väärä normalisointi on sellaista turmelusta, jota on **lähes \
                mahdotonta havaita**: luvut näyttävät yhä oikeilta, ne ovat vain eri päivämäärä. Siksi \
                tämä pöytä mieluummin kieltäytyy kuin päättelee.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Sumeat kaksoiskappaleet",
        summary: "Etsi saman nimen käsin kirjoitetut muunnelmat — äläkä koskaan yhdistä niitä itsestään.",
        keywords: ["sumea", "kaksoiskappaleet", "yhdistä", "muunnelmat", "kirjoitusvirheet"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — kolme tapaa \
                kirjoittaa yksi asiakas. Tavallinen kaksoiskappaleiden poisto ei näe niitä samana.
                """),
            .steps([
                "Valitse tarkasteltava sarake ja samankaltaisuuskynnys.",
                "GEditor ryhmittelee lähekkäiset arvot **ryppäiksi** ja näyttää vertailumuodon.",
                "**Kunkin ryppään** kohdalla valitset, mikä arvo säilytetään — tai ohitat ryppään.",
                "Käytä. Yksi kumoamisaskel.",
            ]),
            .warning("""
                Tämä työkalu **ei koskaan yhdistä itsestään**, eikä »yhdistä kaikki« -painiketta ole. \
                Kaksi 92-prosenttisesti samankaltaista merkkijonoa voi olla kirjoitusvirhe tai kaksi \
                aidosti eri yritystä, jotka eroavat yhdellä sanalla — kone ei voi päättää.
                """),
            .paragraph("""
                Kahden tietueen väärä yhdistäminen on **hiljaista** datan menetystä: yksikään solu ei \
                tyhjene, yksikään rivi ei muutu punaiseksi, kahdesta kohteesta tulee vain yksi eikä \
                kukaan huomaa ennen kuin kirjanpito täsmäytetään.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Siivousreseptit",
        summary: "Kirjaa askelsarja JSON-tiedostoksi ja aja se ensi kuun datalle.",
        keywords: ["resepti", "toista", "automatisoi", "kuukausittain", "erä"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Siivouksen jälkeen tallenna askeleet **reseptinä**. Se on ihmisen luettava \
                JSON-tiedosto, jonka voit pitää datan vieressä, lähettää kollegalle ja lisätä \
                arkistoon, jotta muutokset jäävät kirjatuiksi.
                """),
            .code(language: "json", caption: "sales-standard.json — lyhennettynä",
                  source: """
                    {
                      "version": 1,
                      "name": "Sales report standardisation",
                      "sourceFile": "sales-2026-08.csv",
                      "steps": [
                        { "enabled": true, "column": "ngay",       "action": "normalizeDates" },
                        { "enabled": true, "column": "doanh_thu",  "action": "normalizeNumbers" },
                        { "enabled": true, "column": "khach_hang", "action": "trim" }
                      ]
                    }
                    """),
            .paragraph("""
                Jokaisen askeleen voi **kytkeä pois** (`enabled`), joten yksi resepti voi palvella \
                useaa lähes samanlaista tiedostolajia.
                """),
            .heading("Uudelleenajo"),
            .bullets([
                "Ohjelmassa: `CSV ▸ Aja siivousresepti…`",
                "Komentotulkista koko kansiolle: katso komentorivisivu.",
            ]),
            .code(language: "bash", caption: "Kuiva-ajo ennen mitään kirjoitusta — yhteenkään tiedostoon ei kosketa",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Oletuksena tulos kirjoitetaan uuteen tiedostoon alkuperäisen viereen \
                (`sales-clean.csv`). Alkuperäisen korvaamista on pyydettävä nimenomaisesti \
                valitsimella `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Datan laadun pisteytys",
        summary: "Kuusi ulottuvuutta, yksi pistemäärä 0–100, ja jokainen kaava painettuna, jotta voit laskea sen uudelleen.",
        keywords: ["laatu", "pistemäärä", "dqr", "kuusi ulottuvuutta"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Se eroaa dataprofiilista yhdellä perustavalla tavalla: profiili **kuvaa**, pistemäärä \
                **tuomitsee sitä standardia vasten, jonka määrittelit** `.gquality.yaml`-tiedostossa.
                """),
            .table(
                headers: ["Ulottuvuus", "Mitä se mittaa"],
                rows: [
                    ["Täydellisyys", "Täytettyjen solujen osuus `not_null`-sääntöjen mukaan"],
                    ["Kelvollisuus", "Läpi menneiden muoto-, tyyppi-, väli- ja regex-sääntöjen osuus"],
                    ["Yksikäsitteisyys", "Avainta vasten, jonka määrittelit kohdassa `uniqueness_key`"],
                    ["Johdonmukaisuus", "Sarakkeiden ja tiedostojen väliset säännöt"],
                    ["Tarkkuus (arvioitu)", "Poikkeavat nimeämissäsi lukusarakkeissa"],
                    ["Ajantasaisuus", "Datan ikä `freshness`-kynnystä vasten"],
                ]
            ),
            .heading("Kolme takuuta pistemäärästä"),
            .bullets([
                "**Kaava on painettu tulokseen** — voit laskea sen käsin uudelleen.",
                "**Deterministinen**: sama data ja samat säännöt antavat saman pistemäärän. Vain *Ajantasaisuus* riippuu hetkestä, joten `now` on **parametri** ja se kirjataan tulokseen.",
                "**Ulottuvuus, jota ei voi pisteyttää, jätetään tyhjäksi perusteluineen**, ei koskaan hiljaa saa arvoa 100.",
            ]),
            .warning("""
                Tuo viimeinen takuu on tärkeä. Taulukko, jolle ei ole määritelty `uniqueness_key`iä ja \
                joka saa »yksikäsitteisyydestä« sata, on valehteleva pistemäärä — ja se valehtelee \
                imartelevaan suuntaan, joka on se vaarallinen.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "`.gquality.yaml`-syntaksi",
        summary: "Sääntötiedoston jokainen avain, yhden toimivan säännöstön kera.",
        keywords: ["gquality", "yaml", "säännöt", "syntaksi", "datastandardi"],
        blocks: [
            .paragraph("""
                Tiedosto sijaitsee **datan vieressä**, ei ohjelman sisällä: datastandardin on oltava \
                katselmoitavissa, ja katselmointi on juuri sitä, mitä ihmiset standardeille tekevät.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — täydellinen säännöstö",
                  source: """
                    schemaVersion: 1

                    # Kuuden ulottuvuuden painot. Puuttuva ulottuvuus painaa 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # Avain, joka tekee rivistä yksikäsitteisen. Ilman sitä "Yksikäsitteisyys"-
                    # ulottuvuutta EI VOI pisteyttää — ja kokonaisuus sanoo sen puuttuvan.
                    uniqueness_key: [ma_don]

                    # Lukusarakkeet, joista etsitään poikkeavia "Tarkkuus (arvioitu)" -kohtaan.
                    accuracy_columns: [doanh_thu, so_luong]

                    # "Ajantasaisuus"-ulottuvuus.
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Varoita, kun tämä ajo laskee edelliseen verrattuna.
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
                        max_null_pct: 2          # salli 2 % tyhjää
                      # Sarakkeiden välinen sääntö: `col`ia ei tarvita
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Tiedostojen välinen sääntö: arvon on löydyttävä toisesta tiedostosta
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Sääntötyypit"),
            .table(
                headers: ["Avain", "Merkitys", "Ulottuvuus"],
                rows: [
                    ["`not_null: true`", "Solun on oltava täytetty; `max_null_pct` löysentää", "Täydellisyys"],
                    ["`unique: true`", "Ei toistuvia arvoja sarakkeessa", "Yksikäsitteisyys"],
                    ["`dtype: int\\|float\\|date\\|text`", "Oikea tyyppi", "Kelvollisuus"],
                    ["`range: { min:, max: }`", "Lukuvälin sisällä", "Kelvollisuus"],
                    ["`length: { min:, max: }`", "Merkkijonon pituus", "Kelvollisuus"],
                    ["`regex: \"…\"`", "Osuu säännölliseen lausekkeeseen", "Kelvollisuus"],
                    ["`in_set: [ … ]`", "Yksi annetusta luettelosta", "Kelvollisuus"],
                    ["`date_format: \"…\"`", "Oikea päivämäärämuoto", "Kelvollisuus"],
                    ["`compare: { a:, op:, b: }`", "Vertaa kahta saraketta; `op` on `<` `<=` `=` `>=` `>` `<>`", "Johdonmukaisuus"],
                    ["`foreign_key: { file:, column: }`", "Arvon on löydyttävä toisesta tiedostosta", "Johdonmukaisuus"],
                    ["`severity: error\\|warn`", "Säännön vakavuus; oletuksena `error`", "—"],
                ]
            ),
            .warning("""
                Kirjoita sääntöavain väärin, ja tiedosto **hylätään viestin kera** sen sijaan, että se \
                sääntö ohitettaisiin hiljaa. Hiljainen ohitus tarkoittaa, että uskot datan \
                tarkistetun sääntöä vasten, joka ei koskaan ajautunut.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Laatuportti CI:ssä",
        summary: "Pysäytä kelpaamaton data putkessa paluuarvojen avulla.",
        keywords: ["ci", "portti", "fail-under", "paluuarvo", "automaatio", "historia", "ajautuma"],
        blocks: [
            .code(language: "bash", caption: "Pisteytä ja palauta paluuarvo",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Valitsin", "Merkitys"],
                rows: [
                    ["`--quality <tiedosto.yaml>`", "Säännöstö, jota vasten pisteytetään"],
                    ["`--fail-under <0…100>`", "Tämän alle jäävä pistemäärä on HYLÄTTY"],
                    ["`--json <tiedosto\\|->`", "Koneluettava tulos; `-` tulostaa vakiotulosteeseen"],
                    ["`--record-history`", "Lisää rivin tiedostoon `sales-standard.history.jsonl`"],
                    ["`--now <VVVV-KK-PP>`", "Kiinnitä *Ajantasaisuuden* viitepäivä"],
                    ["`--recipe <tiedosto.json>`", "Siivoa **muistissa** ennen pisteytystä kirjoittamatta tiedostoa"],
                ]
            ),
            .table(
                headers: ["Paluuarvo", "Merkitys"],
                rows: [["`0`", "Läpi"], ["`1`", "Hylätty"], ["`2`", "Ajonaikainen virhe"]]
            ),
            .heading("Miksi CI:n kannattaa antaa `--now`"),
            .paragraph("""
                Ilman sitä *Ajantasaisuus* vertaa dataa ajon hetkeen — joten sama tiedosto menettää \
                pisteitä päivien kuluessa, ja jonain aamuna putki muuttuu punaiseksi ilman että kukaan \
                on muuttanut mitään.
                """),
            .heading("Ajautuman seuranta"),
            .paragraph("""
                Valitsimella `--record-history` jokainen ajo lisää rivin JSONL-historiatiedostoon. \
                Seuraavalla kerralla `drift:`-lohkon kynnykset vertaavat viimeisimpään ajoon ja \
                varoittavat, kun pudotus on liian suuri.
                """),
            .note("""
                Jokainen ajautumakynnys on **oletuksena pois**, paitsi `warn_on_new_failure`. \
                Oletuksena päällä oleva varoitus ohjelman valitsemalla luvulla laukeaisi jokaisen \
                toisella ajolla — ja se, joka huutaa sutta ensimmäisenä päivänä, ohitetaan kolmantena.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Datan louhinta

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Datan louhinta — koko prosessi",
        summary: "Poikkeamat, korrelaatio, ryhmittely, ennusteet, assosiaatiosäännöt — ja miten niitä luetaan.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Louhintaprosessi päästä päähän",
        summary: "Kuusi työkalua, järjestys jossa niitä käytetään, ja yksi sääntö: ei mittausta, ei johtopäätöstä.",
        keywords: ["louhinta", "analyysi", "prosessi", "tilastot"],
        blocks: [
            .warning("""
                **Siivoa ensin, louhi sitten.** Normalisoimaton päivämääräsarake tuottaa vääriä \
                ennusteita; lukusarake, jossa on eurooppalaisia tuhaterottimia sekaisin, tuottaa \
                haamupoikkeavia. Jokainen alla oleva työkalu olettaa taulukon olevan siisti.
                """),
            .heading("Järjestys, jossa edetä"),
            .steps([
                "**Etsi poikkeamia** — vastaa kysymykseen *»onko jokin rivi outo«*. Halvin ja usein heti hyödyllinen.",
                "**Korrelaatiomatriisi** — vastaa kysymykseen *»mikä sarake liikkuu minkä kanssa«*. Se ohjaa kaikkea sen jälkeistä.",
                "**Ryhmittely** — vastaa kysymykseen *»montako luonnollista ryhmää täällä on«*.",
                "**Ennustaminen** — vain aikasarakkeella ja vähintään **kahdella täydellä jaksolla**.",
                "**Assosiaatiosäännöt** — vain koriaineistolle: yksi tapahtuma riviä kohti, tai kaksi saraketta joissa tapahtumatunnus ja tuote.",
                "**Ryhmäkohtainen louhinta** — ajaa kolme ensimmäistä uudelleen **kunkin ryhmän sisällä erikseen**. Tämä askel kääntää usein yhdistetystä taulukosta tehdyn johtopäätöksen päinvastaiseksi.",
            ]),
            .heading("Kolme sääntöä koko perheelle"),
            .bullets([
                "**Jokainen tulos kantaa »Menetelmä«-lohkon**: algoritmi, parametrit, siemen, kaava. Sitä ei voi kytkeä pois — kolmen luvun taulukkoa, joka ei kerro mistä ne tulivat, ei voi käyttää päätöksentekoon.",
                "**Ei mittausta, ei johtopäätöstä.** Liian pieni otos, nollavarianssi, singulaarinen matriisi — GEditor kieltäytyy ja kertoo syyn sen sijaan, että palauttaisi luvun joka vain näyttää oikealta.",
                "**Deterministiset tulokset.** Sama data antaa saman tuloksen; missä satunnaisuutta tarvitaan, siemen kirjataan tulosteeseen.",
            ]),
            .heading("Tuloksesta takaisin dataan"),
            .paragraph("""
                Jokainen paneeli **merkitsee takaisin lähdedataan**: napsauta poikkeavaa riviä, \
                korrelaatiosolua tai assosiaatiosääntöä, ja asiaankuuluvat rivit merkitään taulukossa. \
                Näin siirryt tilasta *»jokin on outoa«* tilaan *»outoa juuri näillä riveillä«*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Poikkeavien rivien etsiminen",
        summary: "Neljä mittaa, kolme vakavuustasoa ja selitys sille, miksi rivi on outo.",
        keywords: ["poikkeava", "poikkeama", "z-arvo", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Mitta", "Käytä kun"],
                rows: [
                    ["z-arvo", "Sarake on suunnilleen normaalijakautunut"],
                    ["IQR", "Sarake on vino pitkine häntineen — turvallinen oletus"],
                    ["MAD", "Sarakkeessa on jo paljon poikkeavia ja tarvitaan kestävä mitta"],
                    ["Mahalanobis", "**Useita sarakkeita kerralla** — nappaa rivit, jotka ovat outoja yhdistelmänä eivätkä missään yksittäisessä sarakkeessa"],
                ]
            ),
            .paragraph("""
                Tulokset väritetään **kolmen vakavuustason** mukaan yhden tasavärin sijaan — muuten \
                lievästi epätavallinen rivi ei erotu villisti epätavallisesta.
                """),
            .heading("Syyn selittäminen"),
            .paragraph("""
                Monisarakkeisella mitalla GEditor purkaa kunkin sarakkeen osuuden ja tuottaa lauseen \
                kuten *«poikkeava lähinnä yhdistelmän liikevaihto (50 %) × määrä (50 %) kautta»*.
                """),
            .note("""
                Tuo prosentti on *selitettävissä olevasta osuudesta*, ei *etäisyydestä*. \
                Menetelmä-lohko sanoo tämän suoraan taulukon alla.
                """),
            .warning("""
                Sarake, jonka IQR tai MAD on nolla, saa mitan **kieltäytymään ajosta** sen sijaan, \
                että jakaisi jollain häviävän pienellä ja tuottaisi valtavan arvon. Monisarakkeisessa \
                tapauksessa, jos kovarianssimatriisi on singulaarinen, **GEditor kertoo minkä \
                sarakkeen voi pudottaa** sen sijaan, että käyttäisi pseudokäänteismatriisia \
                »saadakseen sen toimimaan«.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Korrelaatiomatriisi",
        summary: "Pearson ja Spearman jokaiselle parille, hajontakuvio napsautuksella.",
        keywords: ["korrelaatio", "pearson", "spearman", "lämpökartta", "hajonta"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Kerroin", "Mitä se mittaa"],
                rows: [
                    ["Pearson", "**Lineaarista** yhteyttä"],
                    ["Spearman", "**Mitä tahansa monotonista** yhteyttä, myös kaarevaa — laskettuna järjestysluvuista"],
                ]
            ),
            .paragraph("""
                Napsauta lämpökartan solua nähdäksesi sen parin hajontakuvion regressiosuoran ja \
                R²:n kera.
                """),
            .heading("Neljä yksityiskohtaa, jotka muuttavat lukutapaa"),
            .bullets([
                "**Sidokset käyttävät keskimääräisiä järjestyslukuja**, joten taulukon uudelleenlajittelu ei muuta Spearmanin kerrointa.",
                "**Tyhjät solut käsitellään pareittain**, ja kunkin solun `n` on siinä taulukossa — `0,93` kuudella rivillä ei tarkoita samaa kuin `0,93` 6 000 rivillä.",
                "**Vakiosarake palauttaa tyhjän**, ei nollaa. Nolla tarkoittaa *mitattu, yhteyttä ei löytynyt*.",
                "**Väriasteikko on sininen↔oranssi**, ei puna-vihreä: 8 % miehistä näkee puna-vihreän asteikon yhtenä harmaana massana, jolloin `+0,9` ja `−0,9` näyttävät samalta.",
            ]),
            .warning("""
                **Korrelaatio ei tarkoita syy-yhteyttä.** Tuo lause piirretään **itse kuvan sisään**, \
                joten se matkustaa kuvan mukana, kun viet sen.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Ryhmittely",
        summary: "k-means ja DBSCAN, kaksi tapaa valita k — ja varoitus skaalauksesta.",
        keywords: ["rypäs", "kmeans", "dbscan", "ryhmät", "siluetti", "kyynärpää"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritmi", "Käytä kun"],
                rows: [
                    ["k-means", "Tiedät (tai haluat kokeilla) ryppäiden määrän; rypäät ovat möykkymäisiä"],
                    ["DBSCAN", "Et tiedä määrää; rypäillä on mielivaltaisia muotoja; haluat kohinan erilleen"],
                ]
            ),
            .heading("Skaalaus on oletuksena päällä — ja miksi"),
            .paragraph("""
                `liikevaihto`-sarake (miljoonina) `määrä`-sarakkeen (kappaleina) vieressä: kahden \
                rivin välisen etäisyyden ratkaisee lähes kokonaan suurempi. Se ei ole »ei aivan \
                optimaalista« — se on **vastaamista eri kysymykseen**. Käytössä oleva skaalaus \
                kirjataan tulokseen.
                """),
            .heading("Ryppäiden määrän valinta"),
            .bullets([
                "**Siluetti** — mitä korkeampi arvo, sitä paremmin erottuneet rypäät. Suurella taulukolla se **otantaa** (tasavälein, ei ensimmäiset 2 000 riviä), ja tulos ilmoittaa olevansa arvio.",
                "**Kyynärpää** — piirtää ryppäänsisäisen neliösumman k:n funktiona. Se on **tapa lukea kuviota**, ei optimointi: tuo suure laskee aina k:n kasvaessa, joten tilastollisesti »optimaalista k:ta« ei ole.",
            ]),
            .note("""
                DBSCANissa **k-etäisyys**kuvio auttaa valitsemaan säteen: käyrän polvi on yleensä \
                järkevä aloitusarvo.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Aikasarjaennusteet",
        summary: "Trendin ja kausivaihtelun erottelu, Holt-Winters, ja perustaso joka ajetaan aina rinnalla.",
        keywords: ["ennuste", "aikasarja", "kausivaihtelu", "holt-winters", "trendi"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Valitse aikasarake ja arvosarake. GEditor erottelee sarjan osiin **trendi · \
                kausivaihtelu · jäännös** ja ennustaa sitten Holt-Wintersillä (additiivinen tai \
                multiplikatiivinen) 80 %:n ja 95 %:n väleineen.
                """),
            .heading("Perustaso ajetaan aina, ja se sanoo suoraan kuka voitti"),
            .paragraph("""
                Mallin rinnalla GEditor ajaa kaksi naiivia menetelmää: *ota edellinen jakso* ja *ota \
                sama jakso viime kaudelta*. Jos malli **häviää** perustasolle, tuo lause ilmestyy \
                **ensimmäiselle riville eri värillä** — eikä lukutaulukon alle.
                """),
            .paragraph("""
                Syy: ennustetyökaluilla on tapana esittää malli tosiasiana, eikä käyttäjällä ole \
                mitään keinoa saada tietää, että »ota vain viime kuun luku« olisi ollut tarkempi.
                """),
            .heading("Kolme kohtaa, joissa GEditor kieltäytyy tai ilmoittaa itsestään"),
            .bullets([
                "**Ilman kahta täyttä jaksoa se palaa naiiviin menetelmään.** Kausivaihtelun sovittaminen yhden jakson kohinaan ja sen toistaminen tulevaisuuteen tuottaa hyvin vakuuttavan, täysin keksityn ennusteen.",
                "**Nollaan törmäävä MAPE sanoo sen**, ja jos yli 25 % jaksoista on nollia, se pidättää mitan — niiden hiljainen ohittaminen tuottaa luvun, joka on laskettu järjestelmällisesti vinoutuneesta osajoukosta.",
                "**Luottamusväli ilmoittaa olevansa likimääräinen** ja kertoo levenevänsä liian hitaasti pitkillä horisonteilla.",
            ]),
            .note("""
                Kausijakso tunnistetaan **ensimmäisestä differenssistä**, ei raakasarjasta: trendi \
                tekee jokaisesta viiveestä vahvasti korreloivan ja hukuttaa kausihuipun.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Assosiaatiosäännöt",
        summary: "Ostaa A:ta, ostaa usein B:tä — ja miksi taulukko lajitellaan liftin eikä varmuuden mukaan.",
        keywords: ["apriori", "assosiaatiosäännöt", "ostoskori", "lift", "tuki"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Kaksi datamuotoa hyväksytään:"),
            .bullets([
                "**Yksi kori riviä kohti** — sarake, joka sisältää tuoteluettelon.",
                "**Kaksi saraketta** — tapahtumatunnus ja tuote, yksi tuote riviä kohti.",
            ]),
            .table(
                headers: ["Mitta", "Merkitys"],
                rows: [
                    ["tuki", "Osuus koreista, jotka sisältävät molemmat puolet"],
                    ["varmuus", "Vasemman puolen sisältävistä koreista se osuus, jolla on oikea puoli"],
                    ["**lift**", "Varmuus jaettuna oikean puolen perustaajuudella"],
                    ["vipu", "Ero siihen, mitä riippumattomuus ennustaisi"],
                ]
            ),
            .heading("Lajiteltu liftin, ei varmuuden mukaan"),
            .paragraph("""
                Jos oikea puoli esiintyy joka tapauksessa 95 %:ssa koreista, niin **jokaisella** \
                siihen johtavalla säännöllä on noin 95 %:n varmuus — sanomatta silti yhtään mitään. \
                Varmuuden mukaan lajittelu nostaa juuri kaikkein merkityksettömimmät säännöt ylimmäksi.
                """),
            .warning("""
                `lift < 1` **merkitään itse riville**: 80 %:n varmuus kohti jotain, jonka perustaajuus \
                on 95 %, tarkoittaa **käänteistä** suhdetta — oikea luku, joka johtaa väärään \
                johtopäätökseen.
                """),
            .bullets([
                "Kahden maitopurkin ostaminen on silti **yksi** maitoa sisältävä tapahtuma: korin sisäiset kaksoiskappaleet pudotetaan, muuten tuki paisuu määrän mukana.",
                "Tukikynnyksen asettaminen liian matalaksi saa ehdokasjoukon räjähtämään kombinatorisesti; kattoon osuessaan **GEditor pysähtyy ja ilmoittaa taulukon olevan epätäydellinen**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Ryhmäkohtainen louhinta",
        summary: "Aja analyysi uudelleen ryhmittäin erikseen — se askel, joka useimmin kääntää johtopäätöksen.",
        keywords: ["ryhmittele", "ryhmittäin", "simpson", "konttorit", "vertaa ryhmiä"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Valitse tekstisarake ryhmittelyavaimeksi. Jokaiselle ryhmälle ajetaan poikkeamat, \
                ennuste ja korrelaatio **täysin erikseen**, ja ne asetetaan sitten järjestykseen \
                valitsemasi kriteerin mukaan.
                """),
            .heading("Miksi ryhmät on erotettava eikä yhdistettävä"),
            .paragraph("""
                Kaksi konttoria, toinen noin 10:n ja toinen noin 100:n tienoilla. **Yhdistetystä** \
                taulukosta laskettu poikkeavuusaita osuu noin ±135:een — ja se pettää **molempiin \
                suuntiin**:
                """),
            .bullets([
                "**Väärät negatiiviset**: arvo 20, ilmiselvästi poikkeava pienelle konttorille, on hyvin yhteisen aidan sisällä. Mitä enemmän ryhmiä, sitä sokeammaksi se käy.",
                "**Väärät positiiviset**: laajalle levinneen ryhmän normaali häntä leikkautuu yhteisellä aidalla, ja liuta aivan tavallisia rivejä merkitään.",
            ]),
            .heading("»Korrelaatioero«-sarake nappaa Simpsonin paradoksin"),
            .paragraph("""
                Kolme ryhmää, joissa **kunkin** ryhmän kaksi saraketta korreloivat arvolla `−1`, mutta \
                yhdistettynä ne korreloivat arvolla `> 0,9`. Kuka tahansa, joka lukee vain yhdistetyn \
                taulukon, päättelee **täysin päinvastoin**. Tämä sarake osoittaa juuri niihin \
                tapauksiin.
                """),
            .note("""
                Paneeli tarjoaa ryhmittelyavaimiksi vain **tekstisarakkeita** ja pysähtyy 1 000 \
                ryhmään varoituksen kera — jottei kukaan valitsisi tilaustunnussaraketta ja tekisi \
                jokaisesta rivistä omaa ryhmäänsä.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Tekstinlouhinta",
        summary: "n-grammit ja TF-IDF tekstisarakkeesta — luonteenomaisten ilmausten löytäminen.",
        keywords: ["tekstinlouhinta", "n-grammi", "tf-idf", "avainsanat", "ilmaukset"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Toimii yhteen tekstisarakkeeseen — tuotekuvauksiin, asiakaspalautteisiin, \
                huomautuskenttiin.
                """),
            .bullets([
                "**n-grammit** — yleisimmät 1, 2 ja 3 sanan ilmaukset.",
                "**TF-IDF** — sanat, jotka ovat **luonteenomaisia** kullekin asiakirjaryhmälle, siis yleisiä täällä ja harvinaisia muualla.",
            ]),
            .paragraph("""
                Ero: n-grammit kertovat *»mitä asiakkaat toistuvasti mainitsevat«*, TF-IDF kertoo \
                *»miten tämä ryhmä eroaa muista«*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
