import Foundation

/// Conținut de ajutor în română — partea 1: primii pași și editare.
///
/// **Identificatorii `id` ai subiectelor NU se traduc NICIODATĂ.** Spre ei arată `.seeAlso`, pe ei îi
/// deschide meniul și datorită lor fereastra de ajutor poate schimba limba **fără a arunca cititorul
/// înapoi la cuprins**. Schimbarea unui id rupe toate legăturile — în toate cărțile deodată.
///
/// Titlurile de comenzi din `commands:` rămân în vietnameză: trebuie să se potrivească cuvânt cu
/// cuvânt cu elementele reale de meniu, lucru pe care `HelpCoverage` îl verifică chiar prin acel șir.
enum HelpRO {}

extension HelpRO {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Primii pași",
        summary: "Ce face GEditor și unde merită petrecute primele cinci minute.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Ce este GEditor",
        summary: "Un editor de text și date la scară de gigaocteți pentru macOS, care vorbește vietnameză.",
        keywords: ["introducere", "bun venit", "prezentare", "despre"],
        blocks: [
            .paragraph("""
                GEditor deschide **un fișier de 1 GB fără a încărca 1 GB în memorie**. Citește printr-o \
                fereastră glisantă peste un fișier mapat în memorie, așa că un jurnal cu 200 de \
                milioane de linii sau un CSV cu un milion de rânduri se deschide în circa o secundă și \
                derulează lin.
                """),
            .paragraph("""
                Dincolo de editare, este un **banc de lucru pentru date**: vedeți CSV-ul ca tabel, \
                curățați-l, evaluați-i calitatea, interogați-l cu SQL, căutați în el anomalii și \
                tendințe, apoi generați un raport. Și citește vechile codificări vietnameze pe care \
                majoritatea uneltelor de azi le-au uitat.
                """),
            .heading("Șase lucruri de încercat mai întâi"),
            .table(
                headers: ["Sarcină", "Unde"],
                rows: [
                    ["Să deschideți un fișier mare fără așteptare", "Trageți-l în fereastră — vedeți `Deschiderea fișierelor mari`"],
                    ["Să modificați multe locuri deodată", "`⌘D` adaugă următoarea potrivire, apoi scrieți o dată"],
                    ["Să căutați cu o expresie regulată", "`⌘F`, activați Regex — motorul este PCRE2 cu JIT"],
                    ["Să vedeți un CSV ca tabel", "`⌥⌘T` — un milion de rânduri derulează tot lin"],
                    ["Să curățați un tabel dezordonat", "`⇧⌘L` Bancul de curățare — previzualizare înainte de aplicare"],
                    ["Să deschideți un fișier vietnamez care arată aiurea", "Faceți clic pe codificare în bara de stare"],
                ]
            ),
            .note("""
                Veniți de la Notepad++? Există o pagină care compară cele două hărți de taste, pentru că \
                unele taste **își schimbă locurile** pe macOS în loc ca `Ctrl` să devină pur și simplu \
                `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Primele cinci minute",
        summary: "Douăsprezece scurtături acoperă cea mai mare parte a muncii zilnice.",
        keywords: ["scurtătură", "taste", "început", "bazele"],
        blocks: [
            .paragraph("""
                Nu trebuie să învățați totul. Cele douăsprezece taste de mai jos acoperă cea mai mare \
                parte a muncii de zi cu zi; restul le căutați când aveți nevoie.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Deschide un fișier"),
                HelpShortcut("⇧⌘O", "Deschide un dosar întreg ca spațiu de lucru"),
                HelpShortcut("⌘T", "Filă nouă"),
                HelpShortcut("⌘S", "Salvează"),
                HelpShortcut("⌘F", "Caută"),
                HelpShortcut("⌥⌘F", "Caută și înlocuiește"),
                HelpShortcut("⇧⌘F", "Caută într-un dosar întreg"),
                HelpShortcut("⌘D", "Adaugă următoarea apariție a selecției"),
                HelpShortcut("⌘L", "Mergi la linie"),
                HelpShortcut("⌘/", "Comentează linia cu semnul limbajului"),
                HelpShortcut("⌥⌘T", "Comută între tabel și text (fișiere CSV)"),
                HelpShortcut("⌘?", "Redeschide această fereastră de ajutor"),
            ]),
            .heading("Trei lucruri care îi surprind pe începători"),
            .bullets([
                "**O operație în masă este UN singur pas de anulare**, chiar dacă atinge un milion de linii. Ați sortat greșit? Un `⌘Z` și s-a dus.",
                "**Sesiunea se restaurează singură.** Ieșiți și deschideți din nou: filele revin unde erau, inclusiv cele nesalvate. Nu e nimic de apăsat.",
                "**Scrisul fără diacritice găsește totuși cuvintele cu ele** în toate câmpurile de căutare și filtrare — scrieți `hue` pentru `Huế`, `da nang` pentru `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Ce încercați să faceți?",
        summary: "Un tabel de căutare de la sarcini reale la capitolul care le acoperă.",
        keywords: ["index", "căutare", "cum"],
        blocks: [
            .paragraph("""
                Cuprinsul din stânga este ordonat după **funcție**. Acest tabel este ordonat după \
                **sarcină**, pentru că cele două ordini nu se suprapun.
                """),
            .table(
                headers: ["Am nevoie să…", "Vedeți"],
                rows: [
                    ["Modific același loc pe sute de linii", "Cursoare multiple · Selecție de bloc pe coloane"],
                    ["Reformatez în masă cu o expresie regulată", "Caută și înlocuiește · Expresii regulate"],
                    ["Repet o succesiune de acțiuni", "Macrocomenzi"],
                    ["Deschid un CSV pe care mi l-a trimis cineva", "Tabelul CSV"],
                    ["Curăț un tabel dezordonat: date amestecate, numere ca text", "Fluxul de curățare"],
                    ["Judec dacă un tabel e de încredere", "Evaluarea calității datelor"],
                    ["Găsesc anomalii, tendințe, grupuri", "Fluxul de explorare"],
                    ["Pun întrebări în SQL", "Interogarea CSV cu SQL"],
                    ["Public un raport ale cărui cifre se recalculează", "Rapoarte `.greport.md`"],
                    ["Desenez o diagramă într-un document", "Mermaid"],
                    ["Deschid un fișier vietnamez care arată aiurea", "Codificări vietnameze"],
                    ["Automatizez din shell sau AppleScript", "Automatizare"],
                    ["Colorez un format inventat de firma mea", "Limbaje proprii"],
                ]
            ),
            .note("""
                Nu găsiți? Câmpul de căutare din stânga sus se uită în **textul principal și în \
                exemplele de cod**, așa că scrierea unei chei de configurare simple, precum \
                `fail_under`, vă duce la pagina potrivită.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Deschiderea fișierelor mari",
        summary: "De ce se deschide 1 GB și unde GEditor refuză intenționat în loc să ghicească.",
        keywords: ["fișier mare", "gigaoctet", "1gb", "jurnal", "mmap", "lent", "performanță"],
        blocks: [
            .paragraph("""
                Fișierul este **mapat în memorie** și citit printr-o fereastră glisantă; partea pe care \
                o editați trăiește într-un tabel de fragmente. În practică: timpul de deschidere aproape \
                nu depinde de mărimea fișierului, și nici memoria ocupată de aplicație.
                """),
            .heading("Unde refuză intenționat"),
            .paragraph("""
                Câteva calcule ar trebui să citească tot fișierul într-un singur șir — exact ceea ce \
                evită această arhitectură. Acolo GEditor **spune că nu o va face**, în loc să se \
                târască în tăcere sau să ghicească:
                """),
            .table(
                headers: ["Operație", "Plafon", "Peste el"],
                rows: [
                    ["Potrivirea parantezelor", "1 MB", "Refuză și o spune — a evidenția perechea greșită e mai rău decât niciuna"],
                    ["Coloana vizibilă în bara de stare", "200 kO", "Revine la numărarea octeților și marchează cu `~`, ca să se vadă sensul"],
                    ["Previzualizarea Markdown", "4 MB", "Refuză și explică"],
                ]
            ),
            .warning("""
                Un număr care arată la fel dar înseamnă altceva este cel mai rău fel de greșeală. De \
                aceea o coloană peste plafon scrie `~1234`, nu `1234`.
                """),
            .heading("Sfaturi pentru fișiere de jurnal"),
            .bullets([
                "`Fișier ▸ Urmărește fișierul (tail -f)` adaugă ce se scrie la sfârșit. Documentul devine **doar pentru citire** în timpul urmăririi — a scrie în timp ce curge text nou înseamnă doi scriitori peste un document, iar cel care pierde e mereu ce tocmai ați scris.",
                "Liniile de jurnal se **colorează după gravitate** și pot fi filtrate după nivel.",
                "**Harta documentului** (`⌥⌘M`) descrie tot fișierul, nu doar partea vizibilă.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Ediția App Store față de descărcarea directă",
        summary: "Trei funcții pe care le are doar ediția directă, și de ce.",
        keywords: ["app store", "sandbox", "descărcare", "cli", "extensie", "diferență"],
        blocks: [
            .paragraph("""
                GEditor apare în două ediții. Provin din **același cod-sursă**, iar aplicația recunoaște \
                la pornire care este. Diferența ține de ce permite App Sandbox.
                """),
            .table(
                headers: ["Funcție", "App Store", "Descărcare directă"],
                rows: [
                    ["Toată editarea, CSV, curățare, explorare, rapoarte", "Da", "Da"],
                    ["Unealta de linie de comandă `geditor`", "Nu", "Da"],
                    ["Filtrarea textului printr-o comandă externă", "Nu", "Da"],
                    ["Extensii native (proces separat)", "Nu", "Da"],
                    ["Actualizare proprie", "Prin App Store", "În aplicație"],
                ]
            ),
            .paragraph("""
                Fiecare »Nu« de mai sus vine din aceeași regulă: cutia de nisip **interzice rularea de \
                cod în afara aplicației**. Acesta e prețul distribuției prin App Store, nu o scăpare.
                """),
            .note("""
                În ediția App Store acele comenzi **rămân în meniu** și explică de ce nu sunt \
                disponibile, în loc să dispară. Un element de meniu lipsă este o întrebare către \
                asistență; un răspuns pe loc, nu.
                """),
            .heading("Accesul la fișiere în ediția App Store"),
            .paragraph("""
                Ediția în cutie de nisip poate atinge doar fișierele pe care le-ați deschis sau tras \
                dumneavoastră. GEditor păstrează un **semn de carte cu domeniu de securitate** pentru \
                fiecare filă și pentru dosarul spațiului de lucru, așa că sesiunea se redeschide după \
                ieșire fără să ceară din nou permisiunea.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Editare

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Editare",
        summary: "Modificați multe locuri deodată, lucrați cu linii, și regulile ascunse pe care merită să le știți întâi.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Cursoare multiple",
        summary: "Selectați fiecare loc potrivit, scrieți o dată, schimbați-le pe toate.",
        keywords: ["multicursor", "cmd+d", "selecție multiplă"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Asta înlocuiește majoritatea momentelor în care erați pe punctul de a scrie o expresie \
                regulată. Selectați un cuvânt, apăsați `⌘D` de câteva ori ca să adunați aparițiile \
                următoare, apoi scrieți — fiecare loc se schimbă deodată.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Adaugă următoarea apariție la selecție"),
                HelpShortcut("⌘ + clic", "Pune încă un cursor unde faceți clic"),
                HelpShortcut("Esc", "Renunță la toate, înapoi la un cursor"),
                HelpShortcut("⌥ + tragere", "Selecție de bloc pe coloane (altă cale spre multe cursoare)"),
            ]),
            .heading("Reguli de știut"),
            .bullets([
                "Scrierea, ștergerea și lipirea peste multe cursoare sunt **un singur** pas de anulare, nu unul pe cursor.",
                "Cursoarele supraviețuiesc mișcării cu săgețile — tot grupul se mută împreună.",
                "`⌘D` sare peste locurile deja aflate în selecție, așa că apăsarea în exces nu stivuiește niciodată cursoare unele peste altele.",
            ]),
            .note("""
                `⌘D` pe un cuvânt dintr-un șir lung era înainte lent. Detectarea limitelor de cuvânt \
                citește acum în loturi — cam de **42× mai rapid** pe un șir de 1 MB, ceea ce face asta \
                utilizabil pe fișiere de date, nu doar pe cod-sursă.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Selecție de bloc pe coloane",
        summary: "Selectați un dreptunghi pe multe linii — cu mouse-ul sau de la tastatură.",
        keywords: ["mod coloană", "selecție bloc", "alt tragere", "dreptunghi", "tastatură"],
        blocks: [
            .paragraph("""
                Țineți `⌥` și trageți ca să selectați un **bloc dreptunghiular**. Scrierea, ștergerea și \
                lipirea urmează toate blocul. Lipirea unui bloc la un singur cursor păstrează totuși \
                dreptunghiul.
                """),
            .shortcuts([
                HelpShortcut("⌥ + tragere", "Selectează un bloc"),
                HelpShortcut("⌥⌘← →", "Lărgește blocul cu o coloană la stânga/dreapta"),
                HelpShortcut("⌥⌘↑ ↓", "Extinde blocul cu o linie sus/jos"),
            ]),
            .paragraph("""
                Calea de la tastatură nu este o soluție de rezervă pentru mouse: a selecta un bloc de 40 \
                de linii prin tragere înseamnă a trage printr-o derulare, pe când `⌥⌘` + săgeți \
                păstrează precizia coloană cu coloană. Orice **altă** tastă (sau scrierea) încheie blocul \
                pe care îl extindeați.
                """),
            .heading("Coloanele de aici sunt coloane VIZIBILE"),
            .paragraph("""
                Un TAB se extinde până la următorul prag la lățimea tabulatorului, în loc să conteze ca \
                o coloană. Tocmai asta face ca liniile indentate cu tabulatoare și cu spații să **se \
                alinieze așa cum le vedeți pe ecran**.
                """),
            .paragraph("Textul multiocteți e tot o coloană: `Nguyễn` ocupă șase coloane, nu nouă."),
            .table(
                headers: ["Situație", "Ce face GEditor"],
                rows: [
                    ["Coloana-țintă cade la mijlocul unui TAB", "Se fixează la marginea mai apropiată; la egalitate, spre stânga"],
                    ["O linie e mai scurtă decât coloana de start", "Acea linie contribuie cu o selecție goală și primește totuși text scris"],
                    ["Lipirea unui bloc la un singur cursor", "Păstrează dreptunghiul, inserând în jos pe liniile de dedesubt"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Editorul de coloane",
        summary: "Inserați text, o serie de numere sau o serie de date pe fiecare linie a unui bloc.",
        keywords: ["editor de coloane", "numerotare", "secvență", "serie"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Selectați un bloc de coloane, apoi deschideți `Editare ▸ Column Editor…` (`⌥⌘C`). \
                Dialogul are o **previzualizare** înainte să se aplice ceva.
                """),
            .table(
                headers: ["Mod", "Parametri", "Folosiți când"],
                rows: [
                    ["Text", "Un șir fix", "Adăugați același prefix/sufix pe fiecare linie"],
                    ["Serie numerică", "Start · pas · bază 2·8·10·16 · completare cu zerouri", "Numerotați rânduri sau generați coduri"],
                    ["Serie de date", "Prima dată · pas în zile", "Creați o coloană de date consecutive"],
                ]
            ),
            .code(language: "text", caption: "Numerotare cu zerouri, start 1, pas 1",
                  source: """
                    Înainte:          După (serie numerică, 3 cifre):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Un pas **negativ** este valid — numărătoarea inversă funcționează.",
                "Inserarea în 5.000 de linii este tot **un singur** pas de anulare.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Operații pe linii",
        summary: "Sortare, eliminarea duplicatelor, mutare, unire, împărțire, dublare, ștergere.",
        keywords: ["sortare", "dublare", "duplicate", "mută linia", "unire", "împărțire"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Cu o selecție, comanda rulează pe selecție; fără ea rulează pe **tot documentul**. \
                Fiecare comandă de aici este un singur pas de anulare.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Dublează linia"),
                HelpShortcut("⌘K", "Șterge linia"),
                HelpShortcut("⌥↑ / ⌥↓", "Mută linia sus / jos"),
            ]),
            .heading("Trei feluri de sortare și pe care să-l alegeți"),
            .table(
                headers: ["Fel", "`file2` față de `file10`", "Folosit pentru"],
                rows: [
                    ["A→Z / Z→A", "`file10` vine înaintea lui `file2`", "Liste simple de cuvinte"],
                    ["Naturală", "`file2` vine înaintea lui `file10`", "Nume de fișiere, identificatori codificați, versiuni"],
                ]
            ),
            .paragraph("""
                Sortarea **naturală** citește șirurile de cifre ca numere. Aproape întotdeauna asta \
                vreți când lista este numerotată.
                """),
            .heading("Eliminarea duplicatelor"),
            .bullets([
                "**Tot documentul** — aruncați fiecare linie care a apărut mai devreme, păstrați-o pe prima.",
                "**Doar vecine** — contopiți liniile vecine identice, ca `uniq` din Unix.",
            ]),
            .heading("Unire și împărțire"),
            .bullets([
                "**Unește liniile** contopește liniile selectate într-una singură.",
                "**Împarte după lungime** taie liniile lungi la un număr dat de caractere.",
                "**Împarte după caracter** taie la fiecare apariție a unui caracter pe care îl scrieți — de pildă pentru a împărți un rând CSV în celulele sale.",
            ]),
            .note("""
                Dublarea **ultimei linii** a fișierului adaugă sfârșitul de linie lipsă; ștergerea până \
                la capătul documentului înghite și sfârșitul liniei precedente. Ambele diferă de \
                implementarea naivă și ambele există ca fișierul să nu se termine cu o linie goală \
                rătăcită — sau fără una.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Spații albe și indentare",
        summary: "Curățați spațiile rătăcite, convertiți TAB ↔ spațiu, și un comutator care merită gândit.",
        keywords: ["spații albe", "tabulator", "spațiu", "indentare", "linii goale"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Comandă", "Ce face"],
                rows: [
                    ["Elimină liniile goale", "Aruncă fiecare linie pe care nu e nimic"],
                    ["Comprimă liniile goale consecutive", "Mai multe linii goale la rând devin una"],
                    ["Taie spațiile de la capăt de linie", "Elimină spațiile și tabulatoarele rătăcite de la sfârșitul fiecărei linii"],
                    ["Tab → spațiu", "Convertește TAB-urile în spații la lățimea curentă a tabulatorului"],
                    ["Spațiu → Tab", "Direcția inversă"],
                ]
            ),
            .heading("Indentare pe limbaj"),
            .paragraph("""
                Faceți clic pe `Tab: 4` din bara de stare. Partea de sus a meniului o schimbă pentru \
                **toată aplicația**; partea de jos — `Doar pentru Go`, `Doar pentru Python`… — se aplică \
                doar limbajului fișierului deschis și ține minte dacă se folosesc tabulatoare sau spații.
                """),
            .paragraph("""
                Oamenii nu aleg indentarea după gust, ci după **obiceiul comunității**: Go folosește \
                tabulatoare (`gofmt` bate orice altceva), Python patru spații conform PEP 8, JavaScript \
                și YAML de obicei două. Un singur număr pentru toate limbajele înseamnă că fiecărui \
                fișier atins îi cresc linii pe care nu le-ați editat niciodată.
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
                Declararea în `settings.json` funcționează la fel — cheia este codul limbajului (`go`, \
                `python`, `javascript`…). Limbajele care lipsesc folosesc `tabWidth` comun.
                """),
            .heading("De ce »taie la salvare« este DEZACTIVAT implicit"),
            .paragraph("""
                Comutatorul `Fișier ▸ Taie spațiile de la capăt de linie la salvare` editează **linii pe \
                care nu le-ați atins niciodată**. Activat implicit, o corectură de un cuvânt în \
                depozitul altcuiva devine o diferență de o mie de linii, iar recenzentul nu găsește \
                schimbarea reală.
                """),
            .paragraph("""
                Când este activat, tăierea este un **pas de anulare separat** plasat înainte de scriere \
                — o singură anulare readuce documentul cum era, fără să pierdeți ce tocmai ați salvat.
                """),
            .heading("Indentare automată"),
            .bullets([
                "O linie nouă moștenește indentarea liniei precedente, plus un nivel după un semn de deschidere — `{` în limbajele cu acolade, `:` în Python și YAML.",
                "Măsurarea se face în **coloane vizibile**, așa că fișierele care amestecă tabulatoare și spații se aliniază totuși pe ecran.",
                "**Nu există** regula »scrierea lui `}` reindentează linia«. Acea regulă editează o linie pe care ați terminat-o deja și este cel mai criticat comportament din orice editor care o are.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Majuscule/minuscule și convenții de denumire",
        summary: "Opt conversii, printre care camelCase, snake_case și kebab-case.",
        keywords: ["majuscule", "minuscule", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Se aplică selecției. Toate se află în meniul `Format`."),
            .table(
                headers: ["Comandă", "`tổng doanh thu` devine"],
                rows: [
                    ["MAJUSCULE", "`TỔNG DOANH THU`"],
                    ["minuscule", "`tổng doanh thu`"],
                    ["Majusculă La Fiecare Cuvânt", "`Tổng Doanh Thu`"],
                    ["Majusculă la început de frază", "`Tổng doanh thu`"],
                    ["Inversare", "Inversează fiecare caracter"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Ultimele trei elimină diacriticele vietnameze, pentru că produc **identificatori în \
                cod** — unde literele cu diacritice de obicei nu sunt permise.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Comentarii și potrivirea parantezelor",
        summary: "⌘/ folosește semnul propriu al limbajului; ⌃⌘B sare la paranteza corespunzătoare.",
        keywords: ["comentariu", "paranteză", "cmd+/", "potrivire"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` alege semnul de comentariu **după limbajul documentului**: `#` pentru Python, `//` \
                pentru Rust și C, `<!-- -->` pentru XML și HTML.
                """),
            .heading("Tot blocul merge într-o direcție"),
            .paragraph("""
                Dacă fie și o singură linie din bloc e încă necomentată, comanda comentează **tot**. A \
                decide linie cu linie ar transforma un bloc pe jumătate comentat într-o tablă de șah. \
                Semnul se introduce la indentarea cea mai mică a blocului, ca blocul să-și păstreze \
                forma.
                """),
            .heading("Săritul la paranteza corespunzătoare"),
            .bullets([
                "`⌃⌘B` sare la paranteza care se potrivește cu cea de la cursor.",
                "Parantezele din **șiruri** sau **comentarii** nu contează — un analizor lexical ușor le deosebește.",
                "Peste **1 MB** comanda refuză și o spune, în loc să se ancoreze la jumătate și să ghicească. A evidenția perechea greșită e mai rău decât a nu evidenția niciuna.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Anulare și clipboard",
        summary: "Istoric de anulare nelimitat și un clipboard cu mai multe poziții.",
        keywords: ["anulare", "refacere", "clipboard", "lipire", "istoric"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Anulează / refă"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Taie / copiază / lipește"),
                HelpShortcut("⇧⌘V", "Istoricul clipboardului"),
            ]),
            .heading("O operație în masă este UN singur pas"),
            .paragraph("""
                Sortarea unui milion de linii, înlocuirea a zece mii de potriviri, inserarea în cinci \
                mii de linii cu editorul de coloane — fiecare se anulează cu **un singur** `⌘Z`.
                """),
            .paragraph("""
                Istoricul de anulare trăiește în bufferul de text propriu al GEditor, nu în \
                `UndoManager`-ul sistemului, tocmai din acest motiv: `UndoManager` numără apăsări de \
                taste.
                """),
            .heading("Istoricul clipboardului"),
            .paragraph("""
                `⇧⌘V` deschide o listă cu ce ați copiat recent și lipește elementul ales. Util când \
                trebuie să alternați două fragmente în multe locuri.
                """),
        ]
    )
}
