import Foundation

/// Suomenkielinen ohjesisältö — osa 5: raportit, tieto, automaatio ja ohjelma.
extension HelpFI {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Raportit ja kaaviot",
        summary: "Tekstitiedosto, joka tuottaa HTML-raportin jonka luvut lasketaan uudelleen, sekä Mermaid-kaaviot.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "`.greport.md`-raportit",
        summary: "Markdown ja neljä ajettavaa lohkotyyppiä — kirjoita vasemmalle, esikatsele oikealla.",
        keywords: ["raportti", "greport", "html", "vienti", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                `.greport.md`-tiedosto on **tavallista Markdownia** ja lisäksi muutama ajettava \
                aidattu lohko. Sen esittäminen tuottaa **itsenäisen** HTML-tiedoston — ei verkkoa, ei \
                oheistiedostoja — jonka kuka tahansa voi avata.
                """),
            .paragraph("""
                Koska se on pelkkää tekstiä, sitä voi **verrata, versioida ja jakaa** — sama ajatus \
                kuin siivousresepteissä ja laatusäännöstöissä.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — täydellinen raportti",
                  source: """
                    ---
                    title: Elokuun myyntiraportti
                    source: sales-2026-08.csv
                    ---

                    # Elokuun myyntiraportti

                    Luvut 31. elokuuta 2026.

                    ## Liikevaihto maakunnittain

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Liikevaihto maakunnittain
                    y_label: Liikevaihto
                    number_format: vi
                    suffix: " ₫"
                    source: Lähde — sales-2026-08.csv
                    ```

                    ## Lähdedatan laatu

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Lohkotyypit"),
            .table(
                headers: ["Lohko", "Tuottaa"],
                rows: [
                    ["`query`", "Taulukon, DuckDB:n SQL-lauseesta"],
                    ["`chart`", "Kaavion"],
                    ["`quality`", "Datan laadun tuloskortin"],
                    ["`mining`", "Ryhmälouhinnan järjestystaulukon"],
                    ["`mermaid`", "Kaavion"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Ylin `---`-lohko määrittelee avaimet `title` ja `source` — oletusdatalähteen \
                jokaiselle lohkolle, joka ei nimeä omaansa.
                """),
            .note("""
                Esikatselu rakennetaan uudelleen, kun lopetat kirjoittamisen, mutta se vain \
                **jäsentää**; se ei aja kyselyitä joka näppäinpainalluksella. Asiakirjavirheet ja \
                datavirheet ilmoitetaan erikseen — *»chart-lohkosta puuttuu avain `kind`«* on \
                tiedostovirhe, *»saraketta `doanh_thu` ei ole«* on datavirhe.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "`query`-lohko",
        summary: "Yksi DuckDB-lause muuttuu yhdeksi taulukoksi raportissa.",
        keywords: ["kysely", "sql", "taulukko", "raportti", "lohko"],
        blocks: [
            .paragraph("""
                Lohkon sisältö on **yksi SQL-lause**, ajettuna raportin lähteeseen. Taulu on nimeltään \
                `t`, samalla murteella kuin kyselypaneelissa.
                """),
            .code(language: "text", caption: "Parametroitu query-lohko",
                  source: """
                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu
                    FROM t
                    WHERE thang = :thang
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    ```
                    """),
            .paragraph("""
                `:thang` on **parametri**. Se annetaan esitysvaiheessa — komentotulkista valitsimella \
                `--param thang=8` tai luettelotiedostosta, kun raportteja tuotetaan erissä.
                """),
            .note("""
                Dataraportin taulukoiden **pitäisi tulla query-lohkosta**, ei käsin kirjoitettuina. \
                Käsin kirjoitettu taulukko ei laske uudelleen lukujen muuttuessa, ja ennen pitkää se \
                on eri mieltä raportin muun osan kanssa.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "`chart`-lohko",
        summary: "YAML-asetus muuttuu kaavioksi — ja muodon tärkein sääntö.",
        keywords: ["kaavio", "yaml", "raportti", "piirrä"],
        blocks: [
            .code(language: "yaml", caption: "Chart-lohkon jokainen avain",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Liikevaihto maakunnittain
                    x_label: Maakunta
                    y_label: Liikevaihto
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Lähde — sales.csv, 26.8.2026
                    """),
            .heading("Ilman `query`ä se käyttää VÄLITTÖMÄSTI YLLÄ olevan query-lohkon tulosta"),
            .paragraph("""
                Tämä on muodon tärkein sääntö. Sen ansiosta tavallinen »taulukko ja sitten kaavio \
                siitä taulukosta« -raportti ei toista SQL:ää — ja toistaminen tarkoittaa, että kaksi \
                kopiota lopulta erkanevat, jolloin taulukko ja kaavio sanovat samalla sivulla eri \
                asioita.
                """),
            .warning("""
                Vastineeksi **lohkojen järjestyksellä on merkitystä**: query-lohkon lisääminen väliin \
                muuttaa alapuolisen kaavion dataa.
                """),
            .heading("Miksi `source` on oma avaimensa"),
            .paragraph("""
                Kaavion alle leipätekstinä kirjoitettu lähdemerkintä näkyy aivan hyvin — näytöllä. \
                Mutta kaavio viedään PNG:nä ja liitetään muualle, ja leipäteksti jää jälkeen. \
                Avaimena se piirretään **kuvan sisään** ja matkustaa sen mukana.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "`quality`-lohko",
        summary: "Datan laadun tuloskortti raportin sisällä.",
        keywords: ["laatu", "tuloskortti", "raportti", "lohko"],
        blocks: [
            .code(language: "yaml", caption: "Quality-lohkon jokainen avain",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # tyhjä tarkoittaa raportin omaa lähdettä
                    title: Elokuun myyntidatan laatu
                    rules: true                 # näytä sääntökohtainen läpi/hylätty-taulukko
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # kiinnitä "Ajantasaisuuden" viitepäivä
                    fail_under: 90              # tämän alle kortti muuttuu varoitusväriseksi
                    """),
            .table(
                headers: ["`chart`", "Piirtää"],
                rows: [
                    ["`violations`", "Rivimäärät **hylätyille** säännöille — vastaa kysymykseen »mikä korjataan ensin«"],
                    ["`dimensions`", "Kuuden ulottuvuuden pisteet"],
                    ["`none`", "Vain taulukko, ei kaaviota"],
                ]
            ),
            .note("""
                Aseta `now:` toistuvassa raportissa. Ilman sitä *Ajantasaisuus* vertaa esityshetkeen, \
                joten viime kuun raportin uudelleenesittäminen antaa eri pistemäärän kuin se, jonka \
                julkaisit.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "`mining`-lohko",
        summary: "Järjestä ryhmät poikkeamien, ennustevirheen tai korrelaatioeron mukaan.",
        keywords: ["louhinta", "raportti", "ryhmäjärjestys"],
        blocks: [
            .code(language: "yaml", caption: "Mining-lohkon jokainen avain",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # sarake poikkeamille ja ennusteelle
                    pair: chi_phi             # toinen sarake, ryhmäkohtaiseen korrelaatioon
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # tyhjä tarkoittaa raportin omaa lähdettä
                    title: Louhinta maakunnittain
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Järjestää"],
                rows: [
                    ["`anomalies`", "Sen ryhmän mukaan, jolla on eniten poikkeavia rivejä"],
                    ["`forecast_error`", "Sen ryhmän mukaan, jonka ennuste on huonoin"],
                    ["`correlation_gap`", "Sen ryhmän mukaan, jonka korrelaatio poikkeaa eniten yhdistetystä taulukosta — nappaa Simpsonin paradoksin"],
                ]
            ),
            .warning("""
                **Mikään avain ei kytke »Menetelmä«-lohkoa pois.** Ryhmäjärjestys ilman menetelmäänsä \
                ei anna lukijalle mitään keinoa tietää, mitä aitaa vasten »eniten poikkeamia« \
                mitattiin. Se, joka haluaa sen piiloon, tietää jo haluamansa vastauksen.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Raporttien tuottaminen erissä",
        summary: "Yksi pohja, yksi parametriluettelo, monta raporttia.",
        keywords: ["erä", "monta", "parametrit", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Yksi raporttipohja, ajettuna kullekin konttorille tai kullekin kuukaudelle. \
                Parametriluettelo on CSV- tai JSON-tiedosto — **yksi rivi raporttia kohti**.
                """),
            .code(language: "text", caption: "list.csv — yksi rivi raporttia kohti",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Esitä koko erä komentotulkista",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Tai yksi raportti käsin annetuin parametrein",
                  source: """
                    geditor --report template.greport.md \\
                            --param thang=8 --param tinh="Hà Nội" \\
                            --out ./reports/
                    """),
            .seeAlso(["khoi-query", "dong-lenh"]),
        ]
    )

    static let mermaid = HelpTopic(
        id: "mermaid",
        title: "Mermaid-kaaviot",
        summary: "Piirrä kaaviot tekstinä, muokkaa niitä komennoin, esikatsele molempiin suuntiin tahdissa.",
        keywords: ["mermaid", "kaavio", "vuokaavio", "sekvenssi", "piirrä"],
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
                Mermaid piirtää kaaviot **tekstistä**: kirjoitat kuvauksen, kone piirtää sen. Kaaviota \
                voi siis verrata ja versioida — mitä kuvatiedosto ei voi.
                """),
            .paragraph("""
                Avaa `Mermaid-kaavio: esikatselu` saadaksesi näkymän muokkaimen viereen. Ne kaksi ovat \
                **tahdissa molempiin suuntiin**: valitse elementti kuvasta, ja kohdistin hyppää sen \
                riville.
                """),
            .heading("Muokkaa komennoin, älä kirjoittamalla uudelleen"),
            .table(
                headers: ["Komento", "Mitä se tekee"],
                rows: [
                    ["Lisää pohja…", "Lisää valmiin rungon kullekin kaaviotyypille"],
                    ["Lisää elementti…", "Lisää solmun tai osallistujan"],
                    ["Yhdistä kaksi valittua elementtiä", "Piirrä nuolen niiden välille"],
                    ["Muokkaa valitun elementin nimikettä…", "Muuta tekstiä etsimättä riviä"],
                    ["Poista valittu elementti", "Poista solmun **ja** jokaisen siihen koskevan kaaren"],
                    ["Siirrä viestiä ylös / alas", "Järjestä sekvenssikaavion askeleet uudelleen"],
                    ["Muotoile uudelleen", "Sisennä ja suorista koko lohko"],
                ]
            ),
            .heading("Erottaminen tiedostoon ja upottaminen takaisin"),
            .paragraph("""
                Suuret kaaviot kuuluvat omaan `.mmd`-tiedostoonsa: `Erota lohko .mmd-tiedostoon…` \
                siirtää sen pois ja jättää viittauksen. `Upota viitattu tiedosto takaisin` tekee \
                päinvastoin, kun on lähetettävä yksi tiedosto.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Yleinen Mermaid-syntaksi",
        summary: "Neljä käytetyintä kaaviotyyppiä, kukin toimivine pohjineen.",
        keywords: ["mermaid", "syntaksi", "vuokaavio", "sekvenssi", "gantt", "luokka", "pohja"],
        blocks: [
            .code(language: "mermaid", caption: "Vuokaavio — tilauksen hyväksyntäprosessi",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Sekvenssikaavio — maksuprosessi",
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
                    """),
            .code(language: "mermaid", caption: "Luokkakaavio — datamalli",
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
                    """),
            .code(language: "mermaid", caption: "Gantt — julkaisusuunnitelma",
                  source: """
                    gantt
                        title Kế hoạch phát hành
                        dateFormat YYYY-MM-DD
                        section Chuẩn bị
                        Viết tài liệu     :a1, 2026-09-01, 10d
                        Kiểm thử          :a2, after a1, 7d
                        section Phát hành
                        Nộp App Store     :a3, after a2, 3d
                    """),
            .table(
                headers: ["Solmun muoto", "Kirjoita"],
                rows: [
                    ["Suorakulmio", "`A[Label]`"],
                    ["Pyöristetty", "`A(Label)`"],
                    ["Stadion", "`A([Label])`"],
                    ["Vinoneliö (päätös)", "`A{Label}`"],
                    ["Lieriö (data)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Nuoli", "Kirjoita"],
                rows: [
                    ["Yhtenäinen, kärjellä", "`A --> B`"],
                    ["Pisteviiva", "`A -.-> B`"],
                    ["Paksu", "`A ==> B`"],
                    ["Nimikkeellinen", "`A -- label --> B`"],
                ]
            ),
            .note("""
                Vuokaavion suunta tulee heti sanan `flowchart` jälkeen: `TD` ylhäältä alas, `LR` \
                vasemmalta oikealle, sekä `BT` ja `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Tietopaketti

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Tietopaketti",
        summary: "Paloittelu, hakuindeksit, tietograafit, entiteetit ja haun arviointi.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Mikä tietopaketti on",
        summary: "Työkaluja datan valmisteluun ja tarkistamiseen asiakirjoista vastaavaa kysymysjärjestelmää varten.",
        keywords: ["rag", "tieto", "chunk", "upotus", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Kun rakennetaan järjestelmää, joka vastaa kysymyksiin asiakirjakokoelmasta, suurin osa \
                työstä ei ole mallissa vaan **datan valmistelussa**: asiakirjojen leikkaamisessa \
                järkeviksi katkelmiksi, näiden katkelmien laadun tarkistamisessa, indeksin \
                rakentamisessa ja **sen mittaamisessa, löytääkö haku todella oikean asian**.
                """),
            .paragraph("""
                Tämä luku on juuri sen työkalusarja. Se toimii **täysin omalla koneellasi** eikä \
                koskaan koske verkkoon.
                """),
            .table(
                headers: ["Tehtävä", "Työkalu"],
                rows: [
                    ["Leikata asiakirjat katkelmiksi", "Paloittelun esikatselu"],
                    ["Tarkastella ja pisteyttää katkelmia", "JSONL-katkelmien tarkastelu"],
                    ["Muuntaa datamuotojen välillä", "Tiedon muunnos"],
                    ["Rakentaa ja tarkastella suhdegraafia", "Tietograafi"],
                    ["Löytää erisnimiä tekstistä", "Entiteettien merkintä"],
                    ["Mitata haun laatua", "Hakulaboratorio"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "JSONL-kokoelman paloittelu ja tarkastelu",
        summary: "Esikatsele katkelmarajat itse tekstillä ja pisteytä sitten koko kokoelma.",
        keywords: ["chunk", "jsonl", "kokoelma", "limitys", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Paloittelun esikatselu"),
            .paragraph("""
                Avaa teksti- tai Markdown-asiakirja, valitse tapa ja katkelman koko. Rajat \
                **korostetaan itse tekstillä**, joten näet, mihin leikkaus osuu kesken lauseen tai \
                taulukon läpi, ennen kuin viet mitään.
                """),
            .bullets([
                "**Kiinteä koko** limityksen kera.",
                "**Rakenteen mukaan** — Markdown-otsikoista, asiakirjan juoni ehjänä.",
                "**Kappaleittain**, yhdistäen kunnes koko täyttyy.",
            ]),
            .heading("Olemassa olevan JSONL-kokoelman tarkastelu"),
            .paragraph("""
                Kokoelmalle, joka sinulla jo on (yksi JSON-katkelma riviä kohti), `JSONL: tarkastele \
                katkelmia…` vastaa: mitkä rivit eivät ole kelvollista JSONia, mitkä katkelmat ovat \
                liian lyhyitä tai pitkiä, mitkä toistavat toisiaan ja mitkä on leikattu kesken \
                lauseen.
                """),
            .note("""
                Kokoelman voi myös pisteyttää **samalla kuuden ulottuvuuden kehyksellä** kuin \
                taulukkodatan — käytä avainta `corpus:` raportin `quality`-lohkossa.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Tietomuotojen muuntaminen",
        summary: "Katkelmat JSONL · CSV · Markdown -muotojen välillä, graafit DOT · Mermaid · kaariluettelo.",
        keywords: ["muunna", "jsonl", "dot", "mermaid", "kaariluettelo"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["Mistä", "Mihin"],
                rows: [
                    ["JSONL-katkelmat", "CSV · Markdown"],
                    ["CSV-katkelmat", "JSONL · Markdown"],
                    ["DOT-graafi", "Mermaid · kaariluettelo"],
                    ["Kaariluettelo", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Ennen uuden välilehden luomista on **viiden rivin esikatselu**, sama mekanismi kuin \
                CSV-muunnoksessa.
                """),
            .paragraph("""
                `Avaa kolmikot/kaaret taulukkona` näyttää kolmikkotiedoston tai kaariluettelon \
                taulukkona — suodata ja lajittele kuten mitä tahansa muuta CSV:tä.
                """),
            .note("""
                Suunta **Markdown → JSONL** ei ole tässä komennossa: se suunta *on* paloittelu, ja \
                komento ohjaa sinut sinne. Kahdesta saman leikkauksen toteutuksesta tulisi kaksi eri \
                tulosta.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Tietograafit",
        summary: "Tarkista syntaksi, pisteytä terveys ja aja algoritmeja miljoonan kaaren graafeilla.",
        keywords: ["graafi", "dot", "cypher", "pagerank", "louvain", "syntaksitarkistus"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor lukee graafit muodoissa **DOT**, **kaariluettelo** ja **kolmikot**. `Tarkista \
                graafin syntaksi` nappaa syntaksivirheet, irralliset solmut ja kaaret, jotka \
                osoittavat olemattomiin solmuihin.
                """),
            .heading("Käytettävissä olevat algoritmit"),
            .table(
                headers: ["Algoritmi", "Vastaa"],
                rows: [
                    ["k-askeleen naapurusto", "Mikä liittyy tähän solmuun k askeleen sisällä"],
                    ["Yhtenäiset komponentit", "Montako erillistä palaa graafissa on"],
                    ["PageRank", "Mitkä solmut ovat tärkeitä"],
                    ["Louvain", "Miten graafi jakautuu yhteisöihin"],
                ]
            ),
            .paragraph("""
                **Miljoonan kaaren** graafilla kaikki neljä ajautuvat muutamasta millisekunnista noin \
                sekuntiin.
                """),
            .note("""
                Graafin voi myös pisteyttää **kuuden ulottuvuuden kehyksellä**, jota käytetään \
                taulukoille ja kokoelmille — käytä avainta `graph:` `quality`-lohkossa.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Entiteettien merkitseminen luettelosta",
        summary: "Lataa erisnimiluettelo ja löydä jokainen esiintymä — kolmen vietnamia varten tehdyn säännön mukaan.",
        keywords: ["entiteetti", "erisnimi", "ner", "merkintä", "täsmäytys"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Lataa nimiluettelo (yritykset, tuotteet, paikat), ja GEditor korostaa jokaisen \
                esiintymän asiakirjassa lukumäärätaulukon kera.
                """),
            .heading("Kolme täsmäytyssääntöä, kaikki vietnamilaisesta datasta"),
            .bullets([
                "**Pisin osuma voittaa.** Kun luettelossa on sekä `An Phát` että `Công ty An Phát`, pidemmän ilmauksen sisältävän lauseen on osuttava pidempään — muuten se halkeaa kahtia ja lasketaan kahdeksi entiteetiksi, mikä **paisuttaa** tilastoa.",
                "**Sanarajat vaaditaan.** `An` ei saa osua sanojen `Anh` tai `Hoàn` sisään. Vietnamilaiset erisnimet ovat lyhyitä ja jakavat tavuja lukemattomien tavallisten sanojen kanssa.",
                "**Kirjainkoosta riippumaton, mutta TARKKEISTA riippuvainen.** `CÔNG TY` ja `Công ty` ovat yhtä; `má` ja `ma` eivät.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Entiteettimuunnelmien selvittäminen",
        summary: "Tunnista `Cty An Phát` ja `Công ty An Phát` samaksi — mutta jätä päätös silti sinulle.",
        keywords: ["entiteettien selvitys", "muunnelmat", "nimien normalisointi", "kaksoiskappaleet"],
        blocks: [
            .paragraph("""
                Sama ryhmittely kuin **sumeat kaksoiskappaleet** CSV-taulukossa — yksi yhteinen \
                toteutus, ei kahta.
                """),
            .paragraph("""
                Tuloste on **ehdotus**: käyt läpi kunkin ryppään ja valitset vakiomuodon. »Yhdistä \
                kaikki« -painiketta ei ole, sillä kaksi 92-prosenttisesti samankaltaista nimeä voi \
                olla kaksi todellista organisaatiota.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Hakulaboratorio",
        summary: "Mittaa, löytääkö indeksi oikean asian, vastauksin varustetun kysymysjoukon avulla.",
        keywords: ["haku", "bm25", "recall", "mrr", "ndcg", "arviointi"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Lataa **arviointijoukko** — kukin rivi kysymys ja niiden katkelmien tunnukset, joiden \
                pitäisi palautua — ja aja sitten koko erä indeksiä vasten.
                """),
            .table(
                headers: ["Mitta", "Vastaa"],
                rows: [
                    ["recall@k", "Kuinka paljon vastausjoukosta ilmestyy k parhaan joukkoon"],
                    ["MRR", "Kuinka alhaalla ensimmäinen oikea tulos on"],
                    ["nDCG@k", "Onko järjestys hyvä, sijainti mukaan luettuna"],
                ]
            ),
            .paragraph("""
                Tulokset tulevat myös **kysymyksittäin**, huonoimmat ensin — se on luettelosi siitä, \
                mitä kokoelmassa on korjattava, siinä järjestyksessä joka eniten kannattaa.
                """),
            .warning("""
                Kaikki kolme mittaa ovat **keskiarvoja**, ja keskiarvo kätkee paljon. Lue aina \
                kysymyskohtainen taulukko ennen kuin päätät, että »indeksi on kyllin hyvä«.
                """),
            .paragraph("""
                Kahta kokoonpanoa voi verrata rinnakkain, ja tulos putoaa suoraan \
                `.greport.md`-raporttiin, jotta seuraava ajo on samanlainen.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Makrot ja automaatio

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Makrot ja automaatio",
        summary: "Nauhoita toimintoja, aja ne erissä, kirjoita skriptejä ja ohjaa kaikkea komentotulkista.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Makrojen nauhoitus ja toisto",
        summary: "Nauhoita sarja ja toista se — koko ajo on yksi kumoamisaskel.",
        keywords: ["makro", "nauhoita", "toisto", "toista", "automatisoi"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Aloita / lopeta nauhoitus"),
                HelpShortcut("⌃P", "Toista"),
            ]),
            .steps([
                "`⌃R` aloittaa nauhoituksen.",
                "Tee se, minkä haluat toistettavan — kirjoita, siirrä kohdistinta, etsi, korvaa.",
                "`⌃R` uudelleen lopettaaksesi.",
                "`⌃P` toistaa sen, tai `Makro ▸ Toista asiakirjan loppuun` ajaa sen loppuun asti.",
                "`Makro ▸ Tallenna makro…` nimeää sen myöhempiä istuntoja varten.",
            ]),
            .heading("Se nauhoittaa KOMENTOJA, ei raakoja näppäinpainalluksia"),
            .paragraph("""
                Makro tallentaa **sen, mitä teit**, ei sitä, mitä näppäimiä painoit. Se tekee siitä \
                riippumattoman näppäinasettelusta ja siitä, mikä syöttötapa on käytössä, ja tekee \
                makrotiedostosta **luettavan**, kun avaat sen.
                """),
            .heading("Milloin makro pysähtyy"),
            .table(
                headers: ["Syy", "Merkitys"],
                rows: [
                    ["Toistojen määrä loppui", "Normaali"],
                    ["`find`-askel ei löytänyt mitään", "Näin »toista tiedoston loppuun« pysähtyy itsestään"],
                    ["Asiakirjan loppu saavutettu", "Ei enää minne mennä"],
                    ["Peruutit", "`Makro ▸ Peruuta käynnissä oleva makro`"],
                    ["Kierros ei muuttanut mitään eikä liikkunut minnekään", "Pysäytetty, jottei se voi kiertää ikuisesti"],
                ]
            ),
            .note("Koko ajo — myös kymmenentuhannen toiston — on **yksi** kumoamisaskel."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Makron ajaminen erissä",
        summary: "Jokaisen avoimen välilehden yli tai avaamattomien tiedostojen kansion yli.",
        keywords: ["erä", "kaikki välilehdet", "kansio", "makro", "maski"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Komento", "Laajuus", "Kumottavissa"],
                rows: [
                    ["Aja kaikilla välilehdillä", "Avoimet välilehdet", "Kyllä — yksi kumoamisaskel välilehteä kohti"],
                    ["Aja koko kansiolla…", "Levyllä olevat tiedostot, jotka **eivät ole auki**", "Ei"],
                ]
            ),
            .warning("""
                Koko kansion yli ajaminen koskee tiedostoihin, jotka eivät ole auki millään \
                välilehdellä, joten **kumoamista ei ole**. Oletuksena GEditor **kirjoittaa uusia \
                tiedostoja** eikä korvaa alkuperäisiä. Pidä se oletus, ellei sinulla ole \
                varmuuskopiota tai versionhallittua arkistoa.
                """),
            .heading("Tiedostojen suodatus maskilla"),
            .paragraph("""
                Kansiovalitsimessa on **tiedostonimisuodatin**: kirjoita `*.csv;*.log`, ja makro koskee \
                vain niihin. Se on sama maskisyntaksi kuin `Etsi koko kansiosta` käyttää, ja useat \
                kuviot erotetaan merkillä `;` tai `,`.
                """),
            .bullets([
                "Jätä se **tyhjäksi**, ja se ottaa jokaisen tekstitiedoston, jonka GEditor osaa lukea — entinen käyttäytyminen.",
                "Maski **korvaa** tuon päätelistan sen sijaan, että kaventaisi sitä edelleen: kirjoita `*.bak`, ja se ajautuu `.bak`-tiedostoilla, vaikka pääte ei ole tekstilistalla.",
                "Jos mikään ei osu, viesti **toistaa maskisi takaisin** sen sijaan, että syyttäisi tyhjää kansiota.",
            ]),
            .paragraph("""
                Tällä kentällä on hyvin käytännöllinen syy: kansiossa on 400 `.json`-tiedostoa ja 12 \
                `.log`-tiedostoa, ja makrosi siistii vain lokeja. Ilman maskia myös nuo 400 muuta \
                käsitellään — ja koska erä kirjoittaa uusia tiedostoja, virhe jättää jälkeensä 400 \
                roskaa.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Makrotiedoston syntaksi",
        summary: "Seitsemän askeltyyppiä, täydellinen JSON-muoto ja kaksi toimivaa makroa.",
        keywords: ["makro", "json", "syntaksi", "muoto", "käsin muokkaus", "jaa"],
        blocks: [
            .paragraph("""
                Kukin makro on **oma JSON-tiedostonsa** GEditorin `macros/`-kansiossa. Vaurio pysyy \
                yhdessä makrossa, ja yhden jakaminen kollegalle on yhden tiedoston lähettämistä.
                """),
            .code(language: "text", caption: "Missä tiedostot ovat",
                  source: "~/Library/Application Support/GEditor/macros/<makron-nimi>.json"),
            .heading("Seitsemän askeltyyppiä"),
            .table(
                headers: ["Askel", "Kirjoitetaan", "Merkitys"],
                rows: [
                    ["Lisää teksti", "`{\"insert\": {\"_0\": \"text\"}}`", "Kirjoita kohdistimen kohdalle; valinnan kanssa korvaa sen"],
                    ["Poista taaksepäin", "`{\"deleteBackward\": {}}`", "Kuten poistonäppäin"],
                    ["Poista eteenpäin", "`{\"deleteForward\": {}}`", "Kuten ⌦"],
                    ["Siirry", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Katso suuntaluettelo alta"],
                    ["Valitse rivi", "`{\"selectLine\": {}}`", "Ilman rivinvaihtoa"],
                    ["Etsi", "`{\"find\": { … }}`", "Etsii ja **valitsee** seuraavan osuman"],
                    ["Korvaa valinta", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` toimii, jos edellinen askel oli regex-`find`"],
                ]
            ),
            .heading("Siirtymissuunnat"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("Täydellinen `find`-askel"),
            .code(language: "json", caption: "Find-askeleen neljä avainta",
                  source: """
                    {
                      "find": {
                        "pattern": "^([a-z]{2})\\\\t",
                        "mode": "regex",
                        "matchCase": false,
                        "wholeWord": false
                      }
                    }
                    """),
            .paragraph("`mode` ottaa arvot `normal`, `extended` tai `regex` — samat kolme tilaa kuin hakukentässä."),
            .heading("Esimerkki 1 — muuta rivin alun maakuntakoodi isoiksi"),
            .code(language: "json", caption: "macros/uppercase-province.json",
                  source: """
                    {
                      "name": "Uppercase province code",
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
                    """),
            .paragraph("""
                Aja se komennolla `Makro ▸ Toista asiakirjan loppuun`: se, ettei `find`-askel löydä \
                enempää, on juuri pysäytysehto.
                """),
            .heading("Esimerkki 2 — poista rivi jokaisen TODO-rivin jälkeen"),
            .code(language: "json", caption: "macros/delete-line-after-todo.json",
                  source: """
                    {
                      "name": "Delete line after TODO",
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
                    """),
            .warning("""
                Kokeile käsin muokattua makroa ensin kopiolla. Väärin kirjoitettu `find`-askel saa \
                makron pysähtymään heti — se on vaaraton tapaus. Vaarallinen on kuvio, joka osuu \
                laajemmin kuin luulit, muokaten tuhansia kohtia yhden kumoamisaskeleen sisällä.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "JavaScript-skriptit",
        summary: "Neljä funktiota, yksi `.js`-tiedosto, ja kaikki mitä se tekee on yksi kumoamisaskel.",
        keywords: ["skripti", "javascript", "js", "automatisoi", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Laita `.js`-tiedosto GEditorin `scripts/`-kansioon ja aja se komennolla `Makro ▸ \
                Skripti…`. Skripti näkee tasan **neljä** asiaa:
                """),
            .table(
                headers: ["Kutsu", "Merkitys"],
                rows: [
                    ["`doc.text`", "Koko asiakirjan teksti"],
                    ["`doc.selection`", "Valinta (tyhjä merkkijono, kun mitään ei ole valittu)"],
                    ["`doc.replace(s)`", "Korvaa **koko asiakirja** arvolla `s` — yksi kumoamisaskel"],
                    ["`doc.log(s)`", "Kirjoita rivi tulospaneeliin"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numeroi jokainen rivi.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — säilytä kolme ensimmäistä CSV-saraketta",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Kolme rajaa tiedettäväksi"),
            .bullets([
                "**Ei tiedostojen käyttöä, ei verkkoa, ei prosessien käynnistystä.** API-pinta on tarkoituksella kapea: sen laajentaminen myöhemmin on helppoa, kaventaminen rikkoo jokaisen skriptin, jonka käyttäjät ovat kirjoittaneet.",
                "**Tämä ei ole turvaraja.** Skriptit ajautuvat samassa prosessissa. Älä aja skriptiä, jota et ole lukenut.",
                "**Raja on viisi sekuntia.** Sen yli saat viestin ja ohjelma pysyy käyttökelpoisena — mutta sen skriptin säie **pyörii kunnes lopetat**, syöden yhden ytimen. Viesti sanoo sen.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Suodatus ulkoisen komennon läpi",
        summary: "Putkita valinta Unix-komennon läpi ja ota tulos takaisin.",
        keywords: ["suodatin", "ulkoinen komento", "komentotulkki", "putki", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                Valinta (tai koko asiakirja) syötetään komennon `stdin`iin, ja sen komennon `stdout` \
                korvaa sen.
                """),
            .code(language: "bash", caption: "Muutama tavallinen",
                  source: """
                    sort -u                     # lajittele ja poista kaksoiskappaleet
                    jq .                        # muotoile JSON uudelleen
                    tr 'a-z' 'A-Z'              # isoiksi kirjaimiksi
                    grep -v '^#'                # poista kommenttirivit
                    awk -F, '{print $3","$1}'   # vaihda sarakkeiden järjestys
                    """),
            .note("""
                Tulos on **yksi** kumoamisaskel. Jos komento palauttaa virhekoodin, GEditor jättää \
                tekstin rauhaan ja näyttää `stderr`in.
                """),
            .warning("""
                Tämä komento on olemassa **vain suoran latauksen versiossa**. App Sandbox kieltää \
                koodin ajamisen ohjelman ulkopuolella, joten App Store -versiossa valikkokohta jää \
                paikalleen ja selittää, miksei se ole käytettävissä.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "Komentorivityökalu `geditor`",
        summary: "Avaa, siivoa, kysele, pisteytä ja esitä raportteja — avaamatta ohjelmaa.",
        keywords: ["cli", "komentorivi", "pääte", "geditor", "skripti", "ci"],
        blocks: [
            .warning("""
                Käytettävissä vain **suoran latauksen versiossa**. App Store -versio ajautuu \
                hiekkalaatikossa, joten ulkoinen komentoriviprosessi ei voi yhdistyä siihen.
                """),
            .heading("Tiedostojen avaaminen"),
            .code(language: "bash", caption: "Avaa, hyppää sijaintiin, lue putkesta",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # rivi 120, sarake 5
                    geditor -w notes.md            # odota tiedoston sulkemista ennen poistumista
                    geditor -r app.log             # avaa vain luettavaksi
                    git diff | geditor             # lue vakiosyöte uuteen välilehteen
                    """),
            .table(
                headers: ["Valitsin", "Merkitys"],
                rows: [
                    ["`-w`, `--wait`", "Odota tiedoston sulkemista ennen poistumista — `git`in muokkaimena toimimiseen"],
                    ["`-n`, `--new-window`", "Avaa uuteen ikkunaan"],
                    ["`-r`, `--read-only`", "Avaa vain luettavaksi"],
                    ["`-i`, `--info`", "Tulosta merkistö, rivinvaihdot ja rivimäärä, poistu sitten — **avaamatta** ohjelmaa"],
                    ["`-h`, `--help`", "Näytä ohje"],
                    ["`-v`, `--version`", "Näytä versio"],
                ]
            ),
            .heading("Ajaminen avaamatta ohjelmaa"),
            .paragraph("""
                Alla olevat neljä komentoryhmää ajautuvat **kokonaan komentoriviprosessissa**, joten ne \
                toimivat CI:ssä, jossa kukaan ei ole kirjautunut graafiseen istuntoon.
                """),
            .code(language: "bash", caption: "Siivous reseptillä",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Kysely",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Laatuportti — paluuarvo 0 läpi · 1 hylätty · 2 virhe",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Raporttien esittäminen",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript ja Palvelut-valikko",
        summary: "Lue ja kirjoita asiakirjaa AppleScriptistä, tai lähetä tekstiä GEditoriin toisesta ohjelmasta.",
        keywords: ["applescript", "osascript", "palvelut", "automaatio", "oikopolut"],
        blocks: [
            .code(language: "applescript", caption: "Lue avoin asiakirja",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Kirjoita sisällön päälle ja lue valinta",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Avaa tiedosto",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Palvelut-valikko"),
            .paragraph("""
                Valitse tekstiä missä tahansa ohjelmassa ja lähetä se `Palvelut`-valikosta GEditoriin \
                uutena välilehtenä.
                """),
            .note("""
                Ensimmäisellä kerralla, kun ajat AppleScriptiä, macOS pyytää automaatio-oikeutta. Se on \
                järjestelmän ikkuna, ei GEditorin.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Laajennuspaketit ja liitännäiset",
        summary: "Kaksi laajennuslajia, ja kummassa versiossa kumpikin toimii.",
        keywords: ["liitännäinen", "laajennus", "paketti", "natiivi"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Laajennuspaketit"),
            .paragraph("""
                Paketti on **yksi JSON-tiedosto**, joka niputtaa teeman, skriptit ja omat \
                kielimäärittelyt yhteen. Asentaminen kopioi tiedoston, poistaminen poistaa yhden — ja \
                pakettiluettelo johdetaan **levyltä**, ei rekisteristä joka voisi valehdella.
                """),
            .paragraph("Toimii **molemmissa versioissa**."),
            .heading("Natiiviliitännäiset"),
            .paragraph("""
                Esikäännetyt liitännäiset ajautuvat **omassa prosessissaan** kapealla API-pinnalla — \
                kaatuva liitännäinen ei vie ohjelmaa mukanaan.
                """),
            .warning("""
                Natiiviliitännäisiä on **vain suoran latauksen versiossa**, koska App Sandbox kieltää \
                koodin lataamisen ohjelman ulkopuolelta. Kukin liitännäinen on **hyväksyttävä käsin \
                kerran**, tiivisteensä perusteella, ennen kuin se ajautuu.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Asetukset ja ohjelma

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Asetukset ja ohjelma",
        summary: "Asetukset, pikanäppäimet, teemat, päivitykset, siirtyminen Notepad++:sta, vianetsintä.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Asetukset",
        summary: "Jokainen valinta elää yhdessä luettavassa JSON-tiedostossa, jonka voi kopioida toiselle Macille.",
        keywords: ["asetukset", "valinnat", "konfiguraatio", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Avaa asetukset")]),
            .paragraph("""
                OK- tai Peruuta-painiketta ei ole — muutos astuu voimaan ja kirjoitetaan heti, macOSin \
                tapaan.
                """),
            .heading("Asetustiedosto"),
            .code(language: "text", caption: "Missä se on",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                Se on **sisennetty JSON-tiedosto, jota voit lukea ja muokata käsin**. Kopioi se \
                toiselle Macille, ja koko kokoonpanosi seuraa mukana. Asetusten painike `Avaa \
                asetustiedosto` vie sinut suoraan sinne.
                """),
            .heading("Avaimet"),
            .table(
                headers: ["Avain", "Oletus", "Merkitys"],
                rows: [
                    ["`fontSize`", "`13`", "Muokkaimen kirjasinkoko"],
                    ["`tabWidth`", "`4`", "Montako saraketta leveä TAB on"],
                    ["`usesTabsForIndent`", "`false`", "Sisennä TABeilla välilyöntien sijaan"],
                    ["`languageIndent`", "`{}`", "Kielikohtainen sisennys — katso tyhjemerkkisivu"],
                    ["`smartIndent`", "`true`", "Automaattinen sisennys uudelle riville"],
                    ["`highlightAllMatches`", "`true`", "Korosta jokainen hakuosuma"],
                    ["`ligatures`", "`false`", "Ligatuurit — katso taulukon alla oleva huomautus"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Leikkaa rivinloppuiset tyhjemerkit tallennettaessa"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normalisoi Unicode NFC:hen tallennettaessa"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Uusien tiedostojen merkistö"],
                    ["`defaultEOL`", "`\"lf\"`", "Uusien tiedostojen rivinvaihdot"],
                    ["`language`", "`\"system\"`", "Käyttöliittymän kieli"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "oletusteema", "Mikä väriteema on käytössä"],
                    ["`showWelcomeOnLaunch`", "`true`", "Avaa tervetuloikkuna käynnistyksessä"],
                    ["`keyBindings`", "`{}`", "Vain ne näppäimet, joita olet muuttanut"],
                ]
            ),
            .note("""
                **Miksi ligatuurit ovat OLETUKSENA POIS.** Ligatuuri sulattaa merkit `!=` tai `->` \
                **yhdeksi** kuvioksi, joten näytöllä näkemäsi merkit eivät enää vastaa tiedoston \
                merkkejä — ja sarakemuokkain, saraketila ja sarakkeesta rivittäminen mittaavat kaikki \
                sarakkeina. Kytke ne päälle, kun kirjoitat leipätekstiä, tai jos valitsit \
                ohjelmointikirjasimen (Fira Code, JetBrains Mono) juuri sen ligatuurien vuoksi.
                """),
            .heading("Naapurikansiot"),
            .table(
                headers: ["Kansio", "Sisältää"],
                rows: [
                    ["`macros/`", "Tallennetut makrot, kukin omana JSON-tiedostonaan"],
                    ["`scripts/`", "JavaScript-skriptit"],
                    ["`themes/`", "Väriteemat"],
                    ["`grammars/`", "Omat kielimäärittelyt"],
                ]
            ),
            .warning("""
                **Uudemman** GEditorin kirjoittamaa asetustiedostoa **ei korvata** vanhemmalla — \
                vanhempi ajautuu oletusarvoilla ja sanoo sen. Korvaaminen on varmin tapa tuhota kahta \
                konetta synkronoivan kokoonpano, eikä hän saisi koskaan tietää miksi.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "Tilarivi",
        summary: "Kymmenen kenttää alhaalla — jokainen luettava ja jokainen napsautettava.",
        keywords: ["tilarivi", "sijainti", "merkistö", "vain luku", "koko"],
        blocks: [
            .paragraph("""
                Tämä on suurin ero muiden muokkainten tilariveihin: **yksikään kenttä ei ole vain \
                luettava**. Jos näet väärän arvon, sen napsauttaminen on tapa korjata se sen sijaan, \
                että etsisit valikoista.
                """),
            .table(
                headers: ["Kenttä", "Kertoo", "Napsautettaessa"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "kohdistimen sijainti — sarake MERKKEINÄ, `@340` tavupaikka",
                     "avaa `Siirry`-kentän"],
                    ["`11 byte · 3 dòng`", "asiakirjan koko",
                     "laskee tavut · merkit · sanat · rivit"],
                    ["`🔒 Chỉ đọc`", "näkyy vain, kun asiakirja on lukittu",
                     "kertoo MIKSI se on lukittu, ja avaa lukituksen kun se on mahdollista"],
                    ["`View` / `Code`", "missä näkymässä olet", "vaihtaa (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "CSV-tila ja käytössä oleva erotin",
                     "kytkee CSV-tilan, tai **valitsee erottimen uudelleen**"],
                    ["`Đang theo dõi`", "`tail -f` on käynnissä", "—"],
                    ["`UTF-8`", "merkistö", "tulkitse uudelleen, tai muunna toiseen merkistöön"],
                    ["`LF`", "rivinvaihtotyyli", "vaihda LF · CRLF · CR"],
                    ["`Python`", "syntaksivärityksen kieli", "valitse toinen, tai takaisin päätetunnistukseen"],
                    ["`Tab: 4`", "sisennyksen leveys", "2 · 4 · 8, yleisesti tai **vain tälle kielelle**"],
                    ["`Ngắt: tắt`", "rivitystila", "kiertää kolme tilaa"],
                ]
            ),
            .heading("Kolme kenttää, jotka ansaitsevat toisen silmäyksen"),
            .bullets([
                "**`@340` — tavupaikka.** Se on se luku, jota jokainen muu tuotteen työkalu puhuu: JSON- ja XML-virheet, `--doc-sweep`-tuloste, binäärikatselin ja `Siirry @340` -kenttä. Lue se täältä, kirjoita se tuonne.",
                "**`~` sarakkeen kohdalla** tarkoittaa, että luku laskee TAVUJA eikä näkyviä sarakkeita — sitä tapahtuu vain yli 200 kt:n riveillä, joissa merkkien laskeminen hidastaisi jokaista kohdistimen liikettä.",
                "**`CSV · …` on napsautettavissa erottimen uudelleenvalintaan.** Tunnistus voi mennä väärin, ja silloin jokainen sarakeoperaatio on vinossa ilman mitään merkkiä. Näin sanot toisin — se vain **LUKEE tiedoston UUDELLEEN** muuttamatta tavuakaan (toisin kuin `CSV ▸ Vaihda erotin…`, joka kirjoittaa sen uudelleen).",
            ]),
            .note("""
                Kenttä, joka ei koske avattua tiedostoa, on **piilotettu**, ei harmaana: `Vain luku` \
                näkyy vain, kun asiakirja on todella lukittu, ja `CSV · …` vain CSV-tilassa.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Pikanäppäinten muuttaminen",
        summary: "Muuta yksittäisiä näppäimiä tai ota Notepad++:n asettelu kokonaisuudessaan.",
        keywords: ["pikanäppäin", "näppäinasettelu", "esiasetus"],
        blocks: [
            .paragraph("""
                Kohdassa `Asetukset…` on Pikanäppäimet-osio kahdella pikapainikkeella: **Käytä \
                Notepad++-esiasetusta** ja **Takaisin oletuksiin**.
                """),
            .paragraph("""
                Asetustiedosto kirjaa vain sen, mitä olet **muuttanut oletuksista**. Näin kun GEditor \
                muuttaa oletusnäppäintä uudessa versiossa, et jää vanhaan asetteluun kenenkään \
                kertomatta.
                """),
            .note("""
                Kaksi komentoa ei saa jakaa pikanäppäintä. Kun ne jakavat, AppKit laukaisee hiljaa \
                vain **ensimmäisen** valikkokohdan ja toinen komento vaikuttaa rikkinäiseltä — siksi \
                GEditorissa on tarkistus, joka estää sen.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Teemat, vaalea ja tumma",
        summary: "Seuraa järjestelmää, vaalea tai tumma; ja teema on JSON-tiedosto, jota voit muokata.",
        keywords: ["teema", "värit", "tumma tila", "vaalea", "ulkoasu"],
        blocks: [
            .paragraph("`Asetukset…` valitsee `Seuraa järjestelmää`, `Vaalea` tai `Tumma` ja poimii väriteeman."),
            .paragraph("""
                Teema on JSON-tiedosto kansiossa `themes/`. Painike `Vie nykyinen teema` kirjoittaa \
                yhden lähtökohdaksi omallesi.
                """),
            .note("""
                Väärin kirjoitettu väri teematiedostossa palautuu **oletusteeman** väriin, ei mustaan. \
                Musta näyttää suunnittelupäätökseltä, ja käyttäjä lähtisi etsimään vikaa muualta.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Päivitykset, versiot ja lopettaminen",
        summary: "Miten päivittäminen eroaa kahden version välillä.",
        keywords: ["päivitys", "versio", "tietoja", "lopeta"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Versio", "Päivittyy"],
                rows: [
                    ["App Store", "App Storen kautta, kuten mikä tahansa muu ohjelma"],
                    ["Suora lataus", "`Tarkista päivitykset…` ohjelman sisällä"],
                ]
            ),
            .paragraph("""
                `Tietoja GEditorista` näyttää käynnissä olevan version ja sen, kumpi versio on \
                kyseessä — hyödyllistä ongelmaa ilmoitettaessa.
                """),
            .note("""
                App Store -versiossa `Tarkista päivitykset…` **jää valikkoon** ja selittää, miksei se \
                koske tähän, sen sijaan että katoaisi. Puuttuva valikkokohta on kysymys tuelle.
                """),
            .paragraph("Lopettaminen ei menetä työtä: istunto palaa seuraavalla avauskerralla."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Tämän ohjeikkunan käyttö",
        summary: "Hae kirjasta, vaihda sen kieltä ja tuo tervetuloikkuna takaisin.",
        keywords: ["ohje", "opas", "haku", "tervetuloa", "kieli"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Avaa ohjeikkuna")]),
            .bullets([
                "Vasemmalla ylhäällä oleva hakukenttä katsoo **leipätekstiin ja koodiesimerkkeihin** — paljaan asetusavaimen kuten `fail_under` kirjoittaminen osuu oikealle sivulle.",
                "**Tarkkeeton** kirjoitus löytää silti tarkkeellisen tekstin.",
                "`Takaisin`-painike palaa edelliselle sivulle.",
                "Kunkin koodilohkon `Kopioi`-painike kopioi sen lohkon.",
            ]),
            .heading("Lukeminen toisella kielellä"),
            .paragraph("""
                Tämän ikkunan oikeassa yläkulmassa oleva valikko valitsee **kirjan kielen** ohjelman \
                käyttöliittymäkielestä riippumatta. Vaihto pitää sinut **sillä sivulla, jota luet** — \
                sivujen tunnuksia ei tarkoituksella käännetä juuri siksi, että tämä toimisi.
                """),
            .note("""
                Vain ne kielet, joilla todella on kirja, luetellaan. Valikkokohta, joka vaihtaa \
                johonkin ja jättää tekstin ennalleen, olisi valehteleva valikkokohta.
                """),
            .heading("Tervetuloikkunan tuominen takaisin"),
            .paragraph("""
                Jos rastitit kohdan **Älä avaa tätä ikkunaa käynnistyksessä**, avaa se uudelleen \
                komennolla `Ohje ▸ Ominaisuuskierros` — ikkunan alalaidan valintaruutu ilmestyy \
                takaisin ja sen voi poistaa.
                """),
            .paragraph("Tai aseta `showWelcomeOnLaunch` takaisin arvoon `true` tiedostossa `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "Notepad++:sta GEditoriin",
        summary: "Mitkä näppäimet vaihtavat paikkaa, mikä toimii toisin ja mikä puuttuu.",
        keywords: ["notepad++", "siirtymä", "windows", "pikanäppäimet"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Muutama näppäin **vaihtaa paikkaa** macOS:ssä sen sijaan, että `Ctrl` vain muuttuisi \
                `⌘`:ksi. Tässä vertailu.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Miksi"],
                rows: [
                    ["`Ctrl+D` Kahdenna rivi", "**⇧⌘D**", "Täällä `⌘D` on monikohdistin, kuten jokaisessa Mac-muokkaimessa"],
                    ["`Ctrl+L` Poista rivi", "**⌘K**", "macOS:ssä `⌘L` tarkoittaa »siirry riville«"],
                    ["`Ctrl+G` Siirry riville", "**⌘L**", "Nämä kaksi vaihtavat paikkaa"],
                    ["`Ctrl+Q` Kommentoi", "**⌘/**", "macOS-käytäntö"],
                    ["`Ctrl+Shift+↑/↓` Siirrä riviä", "**⌥↑ / ⌥↓**", "macOS:ssä `⌃` kuuluu Mission Controlille"],
                    ["`F3` Etsi seuraava", "**⌘G**", "macOS-käytäntö"],
                    ["`Ctrl+F2` Kirjanmerkki päälle/pois", "**⌘F2**", "F2 ja ⇧F2 hyppäävät yhä merkintöjen välillä"],
                    ["`Alt` + veto sarakkeille", "**⌥ + veto**", "Sama"],
                    ["`Ctrl+Alt+Shift+↓` Sarakemuokkain", "**⌥⌘C**", "macOS-käytäntö"],
                ]
            ),
            .note("Etkö haluaisi opetella uudelleen? `Asetukset ▸ Pikanäppäimet ▸ Käytä Notepad++-esiasetusta`."),
            .heading("Asioita, jotka Notepad++:ssa toimivat täällä toisin"),
            .bullets([
                "**Istunnot** palautuvat itsestään, myös tallentamattomat välilehdet — mitään ei tarvitse kytkeä.",
                "**Kirjanmerkeillä on yhdeksän väriä**, ja yksi rivi voi kantaa useaa kerralla.",
                "**Asiakirjakartta** kuvaa *koko* tiedoston, ei vain näkyvää osaa.",
                "**Makroja** voi toistaa »asiakirjan loppuun« ja »kaikilla välilehdillä«, ja koko ajo on yksi kumoamisaskel.",
            ]),
            .heading("Mitä GEditor lisää"),
            .bullets([
                "**Datan siivouspöytä** ja **dataprofiilit** CSV-tiedostoille.",
                "**SQL-kyselyt** suoraan CSV-tiedostoon.",
                "**Vanhat vietnamilaiset merkistöt** — TCVN3, VISCII, VNI-Windows, luettuina, kirjoitettuina ja itsestään tunnistettuina.",
                "**Tarkkeeton haku** jokaisessa suodatinkentässä.",
                "**`.greport.md`-raportit** taulukoineen ja kaavioineen, jotka lasketaan uudelleen.",
                "**Komentorivityökalu `geditor`** suoran latauksen versiossa.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Yleisiä ongelmia",
        summary: "Kuusi tilannetta, jotka saavat ihmiset luulemaan ohjelmaa rikkinäiseksi.",
        keywords: ["virhe", "ongelma", "ei toimi", "vianetsintä", "miksi"],
        blocks: [
            .table(
                headers: ["Oire", "Tavallinen syy"],
                rows: [
                    ["Vietnaminkielinen teksti näkyy sotkuna", "Väärä merkistö — napsauta merkistöä tilarivillä"],
                    ["Tarkkeellisen tekstin hakeminen ei löydä mitään", "Tiedosto on hajotetussa Unicodessa — aja `Normalisoi Unicode` NFC:hen"],
                    ["Valikkokohta on harmaana", "App Store -versio ei voi ajaa sitä komentoa — kohta selittää miksi"],
                    ["Sulkumerkkien vastinparihaku kieltäytyy", "Asiakirja on yli 1 Mt — väärän parin korostaminen on pahempi kuin ei mitään"],
                    ["Tilarivin sarakkeessa on `~`", "Asiakirja on yli 200 kt, joten se on tavumäärä eikä näkyvä sarake"],
                    ["SQL-kysely sanoo, että tiedosto on tallennettava ensin", "DuckDB lukee **tiedostoja**, ei muokattavaa puskuria"],
                ]
            ),
            .heading("Kun GEditor lopettaa odottamatta"),
            .paragraph("""
                Seuraavassa käynnistyksessä palkki sanoo sen ja tarjoaa **Avaa raportti** -painikkeen — \
                raportti avautuu välilehtenä, jota voi lukea ja josta voi kopioida kuten mistä tahansa \
                tekstitiedostosta.
                """),
            .bullets([
                "Raportti kantaa vain **version, macOS-julkaisun, koneen arkkitehtuurin, signaalin nimen ja kutsupinon**.",
                "**Ei asiakirjan sisältöä eikä tiedostopolkujakaan** — polku kuten `~/Työpöytä/palkat-joulukuu.xlsx` on jo paljastanut kolme yksityisasiaa ennen kuin kukaan avaa sitä.",
                "**Mitään ei lähetetä minnekään.** Automaattista lähetystä ei ole eikä palvelinta vastaanottamassa; tiedosto jää kansioon `~/Library/Application Support/GEditor/crash/` kunnes avaat tai poistat sen.",
                "Kun olet avannut raportin, seuraava käynnistys ei mainitse sitä enää.",
            ]),
            .heading("Mistä katsoa seuraavaksi"),
            .bullets([
                "Tilarivi näyttää merkistön, rivinvaihdot, kielen ja rivitystilan — jokainen kenttä on napsautettavissa.",
                "`settings.json`ia voi muokata käsin, kun asetusikkuna ei riitä.",
                "`Tietoja GEditorista` antaa version ja rakenteen, joita virheilmoitus tarvitsee.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
