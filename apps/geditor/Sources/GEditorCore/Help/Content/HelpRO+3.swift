import Foundation

/// Conținut de ajutor în română — partea 3: vederi, vietnameză, limbaje și formate.
extension HelpRO {

    static let views = HelpChapter(
        id: "xem",
        title: "Feluri de a vedea un document",
        summary: "Bară laterală, hartă, pliere, vedere împărțită, încadrare, caractere invizibile, moduri de colorare.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Bara laterală și lista de funcții",
        summary: "Arborele de dosare și lista de funcții a fișierului deschis, într-o coloană.",
        keywords: ["bară laterală", "listă de funcții", "structură", "arbore de fișiere"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Arată / ascunde bara laterală")]),
            .paragraph("""
                Lista de funcții se construiește din **arborele sintactic** al limbajului, așa că urmează \
                structura reală în loc să ghicească din indentare. Un clic pe o intrare sare acolo.
                """),
            .note("Câmpul de filtrare din lista de funcții **găsește text cu diacritice scriind fără ele**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Harta documentului",
        summary: "Tot fișierul într-o coloană îngustă la dreapta — chiar și la sute de MB.",
        keywords: ["minihartă", "hartă", "privire de ansamblu"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Arată / ascunde harta documentului")]),
            .paragraph("""
                Harta descrie **tot fișierul**, nu doar ce e pe ecran. Tragerea pe ea sare la zona \
                corespunzătoare.
                """),
            .paragraph("""
                Potrivirile de căutare și liniile marcate apar pe hartă, ca să vedeți dacă sunt \
                împrăștiate sau grupate înainte de a derula acolo.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Pliere",
        summary: "Pliați funcții, blocuri și tablouri după structură — sau pliați fișierul până la un nivel.",
        keywords: ["pliere", "plierea codului", "restrângere"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Pliază / depliază blocul de la cursor"),
                HelpShortcut("⌥⇧⌘←", "Pliază tot"),
                HelpShortcut("⌥⌘→", "Depliază tot"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Pliază tot fișierul la nivelul 1…8"),
            ]),
            .paragraph("""
                Pentru limbajele cu arbore sintactic, plierea urmează **structura reală**. Pentru \
                fișierele fără gramatică, urmează indentarea.
                """),
            .paragraph("""
                `Pliază la nivel` își arată valoarea la JSON și YAML adânci: plierea la nivelul 2 pune \
                forma întregului fișier pe un singur ecran.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Vedere împărțită",
        summary: "Două panouri alăturate, pentru două fișiere — sau pentru două locuri dintr-un fișier.",
        keywords: ["împărțire", "panouri", "comparare"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Împarte pe verticală"),
                HelpShortcut("⌥⌘-", "Împarte pe orizontală"),
                HelpShortcut("⌥⌘0", "Elimină împărțirea"),
                HelpShortcut("⌥⌘]", "Deschide această filă în celălalt panou"),
                HelpShortcut("⌥⌘[", "Sari în celălalt panou"),
            ]),
            .paragraph("""
                Fiecare panou are propria bară de file. A deschide **același fișier** în ambele panouri \
                e în regulă — derulează independent, ceea ce ușurează compararea începutului cu sfârșitul \
                unui fișier.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Încadrarea liniilor",
        summary: "Trei moduri: dezactivat, la marginea ferestrei sau la o coloană fixă.",
        keywords: ["încadrare", "încadrare moale"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Mod", "O linie lungă"],
                rows: [
                    ["Dezactivat", "Derulează pe orizontală"],
                    ["La fereastră", "Se încadrează la marginea ferestrei, urmându-i mărimea"],
                    ["La o coloană", "Se încadrează la coloana pe care o setați — să zicem 80 sau 100"],
                ]
            ),
            .paragraph("""
                Încadrarea este un **fel de a privi**, nu o editare: nu se inserează niciun sfârșit de \
                linie și nu ajunge niciodată în istoricul de anulare.
                """),
            .note("Calea rapidă până aici este segmentul `Încadrare: …` din bara de stare."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Mărimea fontului",
        summary: "Mărire între 8 și 32 de puncte.",
        keywords: ["mărire", "mărimea fontului", "mai mare", "mai mic"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Text mai mare"),
                HelpShortcut("⌘-", "Text mai mic"),
                HelpShortcut("⌃⌘0", "Înapoi la mărimea implicită"),
            ]),
            .paragraph("""
                Limitat între 8 și 32 de puncte. Și acesta e un **fel de a privi**: nicio editare, nimic \
                în istoricul de anulare. Mărimea implicită se află în `Setări…`.
                """),
            .note("`⌘0` NU este mărimea implicită — acea tastă arată și ascunde bara laterală."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Afișarea caracterelor invizibile",
        summary: "Activați câte un grup pe rând, pentru că toate deodată sunt de obicei prea mult.",
        keywords: ["invizibil", "spații albe", "nbsp", "lățime zero", "tabulator"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Arată / ascunde toate caracterele invizibile")]),
            .paragraph("""
                Patru grupuri se activează separat, pentru că activarea tuturor deodată îngroapă \
                conținutul sub o pădure de puncte.
                """),
            .table(
                headers: ["Grup", "Ce prinde"],
                rows: [
                    ["Spații", "Spații la capăt de linie, indentare inconsecventă"],
                    ["Tabulatoare", "Fișiere care amestecă TAB cu spații"],
                    ["Sfârșituri de linie", "Fișiere care amestecă CRLF cu LF"],
                    ["NBSP · lățime zero · control", "Caractere invizibile din Word, din web, din foi de calcul"],
                ]
            ),
            .warning("""
                Ultimul grup este cel care salvează oameni. Un spațiu neseparator (NBSP) lipit dintr-o \
                pagină web arată **exact** ca un spațiu obișnuit, dar face ca fiecare comparație de șiruri \
                și fiecare filtru să rateze — și nu există cale de a-l vedea fără acest grup activat.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Modul CSV și modul jurnal",
        summary: "Două scheme de colorare care înlocuiesc evidențierea sintaxei, pentru două feluri de fișiere de date.",
        keywords: ["mod csv", "mod jurnal", "evidențiere", "coloane", "nivel de jurnal"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Modul CSV"),
            .paragraph("""
                Dă fiecărei coloane propria culoare în vederea **text**, ca să vedeți ce celulă a alunecat \
                cu o coloană, fără a trece la tabel.
                """),
            .heading("Modul jurnal"),
            .paragraph("""
                Colorează după **gravitatea** citită din linie: erorile roșu, avertismentele chihlimbariu, \
                iar `debug` și `trace` se estompează — ele formează cea mai mare parte a unui jurnal, iar \
                evidențierea lor estompează tocmai ce căutați.
                """),
            .paragraph("`Filtrează jurnalul după nivel…` ascunde de tot nivelurile de care nu aveți nevoie."),
            .note("""
                Aceste două colorează **în locul** evidențierii sintaxei, nu peste ea. Un jurnal nu are \
                sintaxă de colorat, iar două surse de culoare care scriu în același interval de octeți nu \
                lasă un câștigător previzibil.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Vedere binară",
        summary: "Un tabel hexazecimal pentru orice fișier — chiar și unul de 1 GB, se deschide aproape instantaneu.",
        keywords: ["hex", "binar", "octet", "deplasament", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Vizualizare ▸ Vedere binară` arată fiecare octet ca tabel cu trei coloane: **deplasament \
                · hex · text**. Funcționează pentru **orice** fișier de pe disc, nu doar pentru imagini \
                sau video.
                """),
            .table(
                headers: ["Coloană", "Conținut"],
                rows: [
                    ["Deplasament", "Poziția în octeți, în hexazecimal"],
                    ["Hex", "16 octeți pe rând, despărțiți după al optulea pentru numărare mai ușoară"],
                    ["Text", "Octeți ASCII tipăribili; restul este `.`"],
                ]
            ),
            .note("""
                Coloana de text **nu decodează UTF-8**. O literă vietnameză ocupă doi sau trei octeți, \
                așa că redarea ei ar scoate coloana de text din alinierea cu cea hexazecimală — iar acea \
                aliniere e tot rostul coloanei. Ca să citiți text cu diacritice, folosiți vederea normală.
                """),
            .heading("Fișiere mari"),
            .paragraph("""
                Fișierul este **mapat în memorie**, așa că deschiderea unui fișier de 1 GB în vedere \
                binară costă doar cât priviți. Măsurat în suita de autoteste: **sub o milisecundă**.
                """),
            .paragraph("""
                Vederea arată **o fereastră de 4 MB** o dată, iar bara de sus spune în ce interval vă \
                aflați. Este o limită a randorului de tabele al sistemului, nu a citirii: un fișier de 1 \
                GB are 62,5 milioane de rânduri, iar dincolo de un punct rândurile încep să sară la \
                derulare — și un tabel hexazecimal care sare e inutil.
                """),
            .heading("Săritul la o poziție"),
            .table(
                headers: ["Scrieți în câmpul de deplasament", "Sens"],
                rows: [
                    ["`1F400`", "Hexazecimal — implicit"],
                    ["`0x1F400`", "Același lucru, cu prefix explicit"],
                    ["`#128000`", "Zecimal, când aveți un număr de octeți, nu un deplasament hex"],
                ]
            ),
            .bullets([
                "`‹` și `›` trec la fereastra precedentă / următoare.",
                "**Copiază rândurile selectate** copiază exact ce vedeți — fără selecție, copiază toată fereastra.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Previzualizare Markdown",
        summary: "Redă Markdown ca text formatat — și spune deschis ce nu redă.",
        keywords: ["markdown", "previzualizare", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("""
                Redat cu suportul Markdown al sistemului: aldin, cursiv, cod, legături, liste.
                """),
            .warning("""
                **Fără tabele și fără colorarea sintaxei în blocurile de cod.** Fereastra de \
                previzualizare o spune la bază. Documentele mai mari de **4 MB** sunt refuzate.
                """),
            .paragraph("""
                Aveți nevoie de tabele și grafice într-un document publicabil? Pentru asta sunt \
                rapoartele `.greport.md`, nu această previzualizare.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Două moduri: View și Code",
        summary: "O tastă comută între forma redată și sursa editabilă, pentru fiecare tip de fișier.",
        keywords: ["view", "code", "mod", "sursă", "redat", "previzualizare"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Comută între View și Code")]),
            .paragraph("""
                Comanda se află în **bara de sub șirul de file** — în același loc pentru fiecare tip de \
                fișier: un comutator `View | Code`, apoi numele modului View al acelui fișier (»Pagini de \
                document«, »Arbore cheie–valoare«, »Diagramă«…). Un fișier cu un singur mod estompează \
                comutatorul, iar bara spune de ce. La marginea din dreapta stau butoanele proprii \
                fiecărui tip: `.xlsx` are **Tabel** (editabil, scris direct înapoi), `.pptx` are **Schiță**.
                """),
            .note("""
                **Word și PowerPoint se comportă ca un cititor de documente.** Modul lor View construiește \
                pagini reale — fonturi, mărimi și culori corecte, cu imagini, tabele, antete și subsoluri, \
                inclusiv numere de pagină. O pagină este **exact atât de lată cât cadrul** și se poate \
                mări. Excel e o excepție intenționată: View-ul lui e o **foaie de calcul editabilă**, \
                pentru că o foaie nu are format de hârtie până nu se tipărește.
                """),
            .note("""
                În schimb, paginile sunt **doar pentru citire** și redau **copia de pe disc**: editați în \
                Code fără să salvați, iar paginile arată versiunea veche — bara o spune, cu un buton \
                `Salvează și redă din nou`.
                """),
            .heading("Definiții"),
            .bullets([
                "**Code** este **sursa editabilă**. Pentru un fișier text, textul însuși. Pentru un fișier binar — PDF, imagine, sunet, video — nu există sursă textuală, așa că Code sunt **octeții**, arătați în hexazecimal.",
                "**View** este ceea ce se **redă** din Code. Poate fi mai frumos, mai scurt sau rulabil — dar este mereu o consecință, niciodată originalul.",
            ]),
            .paragraph("""
                A spune despre un PDF *»acest tip nu are Code«* ar fi comod, dar greșit: octeții chiar \
                sunt sursa lui.
                """),
            .heading("Unde se face editarea"),
            .paragraph("""
                Editarea se face în **Code**. Există exact **două excepții**, ambele pentru că editarea în \
                View e mult mai firească: **celulele tabelului CSV** și **câmpurile de formular PDF**. \
                Amândouă scriu direct în sursă, așa că nu apare o a doua copie cu care să te contrazici.
                """),
            .heading("După tipul de fișier"),
            .table(
                headers: ["Tip de fișier", "View", "Code", "Editare în"],
                rows: [
                    ["CSV · TSV", "Tabel", "Text brut", "**Ambele**"],
                    ["Excel `.xlsx`", "Tabelul foii deschise", "Acea foaie ca CSV", "**Ambele**"],
                    ["PDF", "Pagini redate", "Binar", "**Ambele** — adnotări, câmpuri de formular, pagini"],
                    ["Markdown `.md`", "Text redat", "Sursă Markdown", "Code"],
                    ["Raport `.greport.md`", "Raport cu interogări rulate și grafice desenate", "Sursă", "Code"],
                    ["JSON", "Arbore cheie–valoare, pliabil", "Sursă JSON", "Code"],
                    ["XML · HTML", "Arbore de etichete, pliabil", "Sursă XML", "Code"],
                    ["YAML", "Arbore cheie–valoare după indentare", "Sursă YAML", "Code"],
                    ["Diagrame `.mmd` · `.dot`", "Diagrama desenată, umplând fila", "Sursă mermaid sau DOT", "Code"],
                    ["Word `.docx`", "Pagini de document redate", "Markdown extras", "Code"],
                    ["PowerPoint `.pptx`", "Pagini de diapozitive redate", "Schiță Markdown", "Code"],
                    ["Fișiere de jurnal", "Colorate după nivel, filtrabile", "Text brut", "Code"],
                    ["Imagini", "Imaginea (cele animate rulează)", "Binar", "Doar citire"],
                    ["Sunet · video", "Un redor", "Binar", "Doar citire"],
                    ["Arhive", "Lista intrărilor", "Binar", "Doar citire"],
                    ["Cod-sursă, text simplu", "— niciunul", "Textul însuși", "Code"],
                ]
            ),
            .note("""
                Codul-sursă **nu are View**, iar asta e normal, nu o lipsă: un fișier Swift nu are o formă \
                redată care să merite privită.
                """),
            .heading("Cititorul de pagini pentru Word și PowerPoint"),
            .paragraph("""
                Paginile se așază vertical și derulează continuu, fiecare o coală albă pe fundal gri — ca \
                în orice cititor de documente. Comenzile lui stau la dreapta barei.
                """),
            .table(
                headers: ["Buton / tastă", "Ce face"],
                rows: [
                    ["`Potrivește lățimea`", "Coala e exact atât de lată cât cadrul — implicit"],
                    ["`Potrivește pagina`", "Toată coala încape în cadru"],
                    ["`−` `+`", "Mărire în pași; sau ciupire, sau ⌘ + derulare"],
                    ["Câmpul `Caută` sau ⌘F", "Caută în pagini, sare acolo și evidențiază"],
                    ["Enter în câmpul de căutare", "Potrivirea următoare"],
                    ["Tragere", "Selectează text; dublu clic pentru un cuvânt, triplu pentru un paragraf"],
                    ["⌘A · ⌘C", "Selectează tot · copiază selecția"],
                    ["Page Up · Page Down · Home · End", "Deplasare prin document"],
                ]
            ),
            .paragraph("""
                Câmpul de căutare **ignoră diacriticele și majusculele**: scriind `vuong quoc` găsiți \
                `Vương quốc`. Eticheta »Pagina 12/363« din bară vă spune unde sunteți.
                """),
            .note("""
                **Ce nu se redă, spus deschis:** imaginile ancorate plutitoare (text care înconjoară o \
                imagine) apar ca imagini în linie; notele de subsol, graficele și SmartArt-ul din \
                PowerPoint nu se desenează. Când aveți nevoie de potrivire exactă cu tipăritul, \
                deschideți-l în Word.
                """),
            .heading("Un clic pe un nod sare înapoi în sursă"),
            .paragraph("""
                Un arbore JSON nu e o tipăritură frumoasă: un clic pe un nod mută cursorul **la VALOAREA \
                acelui nod** în text și readuce fila în Code — pentru că ce vreți în continuare este \
                aproape întotdeauna să editați ce tocmai ați apăsat.
                """),
            .bullets([
                "Nodurile-container arată **numărul de elemente** (`{12}`, `[340]`) în loc de conținut — tocmai asta răspunde la »merită deschis?«.",
                "**Primele două niveluri** sunt desfăcute: a desface complet un fișier cu zece mii de noduri dă o listă mai lungă decât sursa, iar a-l plia complet înseamnă că nu descoperiți nimic fără clicuri.",
                "Un fișier cu **sintaxă nevalidă** nu primește jumătate de arbore — un arbore trunchiat arată ca un document care pur și simplu conține atât de puțin.",
                "Într-un arbore XML, atributele poartă prefixul `@` în notație XPath corectă, iar **spațiile dintre etichete nu devin nod** — sunt formatare, nu conținut.",
                "Un arbore YAML citește **fișiere cu mai multe documente** (`---`): fiecare document e propria rădăcină. Colecțiile scrise pe o linie (`ports: [80, 443]`) rămân o singură frunză — deja vedeți tot, iar desfacerea ar costa un clic. **Indentarea cu tabulatoare** se raportează cu linia exactă: e o eroare YAML pe care ochiul nu o vede.",
                "Schița PowerPoint se construiește din **textul deschis**, nu din fișierul de pe disc: dacă tocmai ați editat schița în Code, arborele trebuie să descrie versiunea nouă, iar nodurile lui trebuie să sară în acea versiune. Notele vorbitorului se pliază într-un singur nod, ca un diapozitiv care spune mult să nu pară un diapozitiv care conține mult.",
                "**O diagramă pe toată fila urmează aceeași regulă**: apăsați un nod și sunteți înapoi în Code, cu cursorul pe declarația acelui nod. În panoul alăturat `Mermaid Studio` fila nu se închide — editorul e chiar acolo, și e destul să mutați cursorul.",
                "Diagramele **se deschid și acolo unde stați**: elementul corespunzător liniei cursorului este evidențiat în clipa în care apare fila, ca să nu-l vânați.",
            ]),
            .heading("Câmpul de filtrare: într-un arbore de zece mii de noduri, căutarea e munca"),
            .paragraph("""
                Chiar sub numărul de noduri stă un câmp de filtrare. Scrieți în el, iar arborele păstrează \
                doar nodurile potrivite — **împreună cu calea de la rădăcină până la ele**, pentru că \
                atunci când o cheie `name` apare în zece locuri diferite, întrebarea reală este »care«, \
                iar la asta răspunde doar ramura care o conține. Restul se desface pentru \
                dumneavoastră: a vă pune să deschideți fiecare nivel ar însemna să vă puneți să filtrați \
                iar, manual.
                """),
            .bullets([
                "Filtrează **atât etichetele, cât și valorile**: a căuta `Huế` e la fel de obișnuit ca a căuta cheia `province`.",
                "**Scrisul fără diacritice se potrivește totuși cu text cu diacritice** — `da nang` găsește `Đà Nẵng`. Aceeași comparație ca la filtrul tabelului CSV și la lista de funcții, ca să nu țineți minte trei reguli de căutare într-o singură aplicație.",
                "Fără potriviri, antetul spune **»Niciun rezultat«** în loc să vă lase privind un arbore gol și întrebându-vă dacă fișierul e stricat.",
                "Schimbarea fișierului sau reintrarea în View **golește filtrul**: un arbore care se deschide deja trunchiat, fără ca ceva să explice de ce, e starea cea mai derutantă dintre toate.",
            ]),
            .heading("Tot arborele funcționează de la tastatură"),
            .paragraph("""
                Intrarea în View mută focalizarea pe arbore; nu trebuie să faceți întâi clic pe el. Sus și \
                jos se deplasează între noduri, stânga și dreapta pliază și depliază, iar două taste \
                încheie o vizualizare — făcând lucruri **diferite**:
                """),
            .bullets([
                "**Enter** — mergi la nodul selectat: înapoi în Code cu cursorul în intervalul de octeți al acelui nod. Exact ca un clic pe el.",
                "**Tab** — comută între arbore și câmpul de filtrare.",
                "**⌘C** — copiază **calea** nodului selectat, nu textul din spatele arborelui. JSON și YAML dau JSONPath (`$.customer['name']`), care se lipește direct în câmpul JSONPath al produsului sau în `yq`; XML dă XPath (`/order/item[2]/@code`) cu indici când două etichete împart un nume; o schiță PowerPoint copiază textul liniei, pentru că o schiță nu are un limbaj de căi de inventat.",
                "**Esc** — calea înapoi: revenirea în Code cu cursorul **exact unde era**. Priveați un arbore, nu călătoreați nicăieri.",
            ]),
            .heading("Și în cealaltă direcție: arborele se deschide unde stă cursorul"),
            .paragraph("""
                Intrarea în View din mijlocul unui fișier de zece mii de linii **nu** deschide arborele la \
                început: desface calea până la nodul corespunzător locului cursorului și îl selectează. \
                Aceasta e cealaltă jumătate a saltului-în-sursă — fără ea, View și Code ar fi două vederi \
                ale unui document doar într-**o singură** direcție.
                """),
            .bullets([
                "Desface **mai adânc de două niveluri** când e nevoie: regula celor două niveluri răspunde la »cum arată acest fișier«, pe când aici întrebarea e alta — »unde mă aflu în acest arbore«.",
                "Un cursor pe o **cheie** (`\"address\":`) selectează acea intrare, deși intervalul de octeți al nodului acoperă doar valoarea. Textul imediat dinaintea unui nod aparține acelui nod.",
                "Un cursor la **începutul unui bloc** — cheia unui bloc YAML, titlul unui diapozitiv, numele unei etichete XML — selectează acel bloc în loc să coboare la primul copil.",
                "Intrarea în View **nu mută cursorul**. Ieșiți din View și sunteți exact unde erați; View este un fel de a privi, nu o comandă care schimbă poziția.",
            ]),
            .heading("Niciun tip nu mai duce lipsă de View"),
            .paragraph("""
                **Fiecare tip de fișier cu loc pentru un mod View redă acum unul.** Lista tipurilor lipsă \
                s-a golit și a fost eliminată.

                Codul-sursă și textul simplu tot nu au View — asta e normal, nu o lipsă, așa că nu au fost \
                niciodată pe acea listă.

                Dacă apare un tip nou de fișier al cărui View nu e încă făcut, comanda de comutare o va \
                spune și va numi ce lipsește, în loc să deschidă un cadru gol — un cadru gol este o \
                promisiune goală, pe când un refuz cu un nume este informație.
                """),
            .heading("Cele șase comenzi mai vechi există în continuare"),
            .paragraph("""
                `Vedere tabel/text`, `Previzualizare Markdown`, `Vedere binară`, `Previzualizare raport`, \
                `Previzualizare diagramă Mermaid`, `Mod jurnal` — toate rămân exact unde erau. `⌥⌘V` este \
                o **intrare comună**, nu un înlocuitor.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnameză

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnameză",
        summary: "Codificări vechi, normalizare Unicode, căutare fără diacritice și metode de introducere.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Codificări vietnameze",
        summary: "Citiți și scrieți TCVN3, VISCII, VNI-Windows și alte 33, detectate automat.",
        keywords: ["codificare", "tcvn3", "abc", "viscii", "vni", "mojibake"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Ați deschis un fișier vietnamez vechi și ați primit `Tr¦êng §¹i häc` în loc de `Trường Đại \
                học`? Fișierul nu e corupt — a fost salvat într-o codificare de dinainte de Unicode.
                """),
            .steps([
                "Faceți clic pe codificare în **bara de stare** (sau `Format ▸ Codificare…`).",
                "Alegeți-o pe cea potrivită — pentru fișiere vietnameze vechi, de obicei `TCVN3 (ABC)`, `VNI-Windows` sau `VISCII`.",
                "Textul se corectează imediat; nu e nevoie să redeschideți fișierul.",
                "Ca să rămână așa, `Salvează ca…` cu codificarea `UTF-8`.",
            ]),
            .heading("Cele trei codificări vietnameze vechi"),
            .table(
                headers: ["Codificare", "De obicei se găsește în"],
                rows: [
                    ["TCVN3 (ABC)", "Acte oficiale și documente Word mai vechi din nord"],
                    ["VNI-Windows", "Edituri, ziare și tipografii — obișnuită în sud"],
                    ["VISCII", "Poșta electronică timpurie și Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **detectează codificarea** la deschidere. Când ghicește greșit, un clic o \
                corectează, iar conținutul se decodează din nou, nu se peticește literă cu literă.
                """),
            .warning("""
                Scrierea într-o codificare veche pierde caracterele pe care acea codificare nu le are. \
                GEditor **le numără și o spune dinainte** — de pildă *»12 caractere nu există în TCVN3«* — \
                în loc să le transforme în tăcere în semne de întrebare.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Sfârșituri de linie",
        summary: "LF, CRLF, CR — convertite pentru tot fișierul cu un clic.",
        keywords: ["eol", "crlf", "lf", "sfârșit de linie", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Stil", "Folosit de", "Octeți"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac înainte de 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Stilul curent apare în bara de stare; faceți clic pe el ca să-l schimbați. Un fișier care \
                **amestecă** două stiluri e raportat tot acolo — activați `Arată invizibilele ▸ Sfârșituri \
                de linie` ca să vedeți exact unde.
                """),
            .note("Stilul sfârșitului de linie pentru fișierele **noi** se setează în `Setări…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalizare Unicode",
        summary: "De ce căutarea lui «ế» uneori nu găsește nimic și cum se repară tot fișierul.",
        keywords: ["unicode", "nfc", "nfd", "compus", "descompus", "normalizare"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                În Unicode, `ế` poate fi scris în **două feluri**: ca un singur punct de cod precompus \
                (NFC) sau ca `e` plus două semne separate (NFD). Pe ecran arată identic; pentru o mașină \
                sunt șiruri diferite.
                """),
            .paragraph("""
                Consecința: căutarea lui `ế` într-un fișier NFD **nu găsește nimic**, iar utilizatorul \
                conchide că datele nu sunt acolo.
                """),
            .steps([
                "`Format ▸ Normalizează Unicode…`",
                "Alegeți **NFC** (precompus) — forma folosită de aproape tot restul.",
                "Aplicați. Este un singur pas de anulare.",
            ]),
            .note("""
                Fișierele venite de pe macOS sunt adesea NFD, pentru că sistemul de fișiere Apple \
                stochează astfel numele. Acesta e de departe cel mai frecvent motiv pentru care datele \
                copiate din Finder nu mai pot fi găsite.
                """),
            .paragraph("""
                În `Setări…` există un comutator **normalizare la NFC la salvare**. Dezactivat implicit, \
                pentru că schimbă octeții fișierului.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Scrisul fără diacritice găsește totuși text cu diacritice",
        summary: "Fiecare câmp de căutare și de filtrare compară cu diacriticele înlăturate.",
        keywords: ["diacritice", "căutare", "filtru", "fără diacritice"],
        blocks: [
            .paragraph("""
                Scrieți `hue` ca să găsiți `Huế`. Scrieți `da nang` ca să găsiți `Đà Nẵng`. Regula se \
                aplică filtrului tabelului CSV, căutării de funcții, căutării din ajutor și celorlalte \
                câmpuri de filtrare.
                """),
            .note("""
                `Đ` se tratează separat, pentru că în Unicode este **o literă de sine stătătoare**, nu un \
                `D` purtând un semn — înlăturarea obișnuită a diacriticelor nu se atinge de el.
                """),
            .paragraph("""
                Filtrul CSV acceptă și un prefix `=` pentru comparație exactă. Forma cu `=` este **tot \
                fără diacritice**, pentru că un filtru care distinge diacriticele îl lasă pe utilizator să \
                creadă că datele lipsesc.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Metode vietnameze de introducere",
        summary: "EVKey, OpenKey, Unikey și sursa de introducere macOS scriu toate direct în document.",
        keywords: ["ime", "evkey", "unikey", "openkey", "telex", "vni", "metodă de introducere"],
        blocks: [
            .paragraph("""
                Nu e nimic de configurat. Telex și VNI funcționează amândouă, inclusiv peste **mai multe \
                cursoare** — scrieți o dată, iar fiecare cursor primește litera cu diacriticul corect.
                """),
            .paragraph("""
                Câmpurile de căutare, cele de filtrare și fiecare dialog acceptă metoda de introducere \
                exact ca editorul.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Limbaje și formate

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Limbaje și formate",
        summary: "Douăzeci de limbaje încorporate, limbaje proprii și unelte pentru JSON · XML · YAML · jurnale.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Douăzeci de limbaje încorporate",
        summary: "Colorare dintr-un arbore sintactic real, cu semnele de comentariu ale fiecărui limbaj.",
        keywords: ["sintaxă", "evidențiere", "limbaj", "tree-sitter", "gramatică"],
        blocks: [
            .paragraph("""
                Limbajul se detectează din **extensia fișierului** (plus câteva nume speciale precum \
                `Makefile`, `Dockerfile`, `Gemfile`). Îl puteți schimba manual din bara de stare.
                """),
            .table(
                headers: ["Limbaj", "Extensii", "Comentariu de linie · de bloc"],
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
                Ultima coloană e ce folosește `⌘/`. Limbajele fără comentariu de linie (JSON, CSS, XML) \
                primesc în schimb forma de bloc.
                """),
            .heading("Ce vine odată cu un arbore sintactic"),
            .bullets([
                "**Lista de funcții** din bara laterală urmează structura reală, nu presupuneri din indentare.",
                "**Pliere** după structură.",
                "**Potrivirea parantezelor** care sare peste parantezele din șiruri și comentarii.",
                "**Indentare automată** care adaugă un nivel după `{` și după `:` în Python și YAML.",
            ]),
            .note("""
                Trei gramatici grele (C++, C#, Ruby) trăiesc într-o bibliotecă **încărcată leneș** — se \
                încarcă doar când deschideți un fișier în unul dintre acele limbaje. Așa rămâne timpul de \
                pornire sub o jumătate de secundă.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Limbaje proprii",
        summary: "Colorați-vă propriul format cu un singur fișier JSON — fără gramatică de scris.",
        keywords: ["udl", "limbaj propriu", "jurnal propriu"],
        blocks: [
            .paragraph("""
                Formatul intern de jurnal al unei firme, un limbaj de configurare privat, un mic DSL — \
                niciunul nu are gramatică tree-sitter, iar scrierea uneia cere un compilator și ceva \
                teorie a analizei sintactice.
                """),
            .paragraph("""
                În schimb, GEditor acceptă un **analizor lexical condus de tabel** declarat în JSON. Puneți \
                fișierul în dosarul `grammars/` din directorul de configurare al GEditor și reporniți.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — un limbaj întreg",
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
            .heading("Fiecare cheie"),
            .table(
                headers: ["Cheie", "Tip", "Sens"],
                rows: [
                    ["`name`", "șir", "Numele afișat în bara de stare"],
                    ["`extensions`", "tablou de șiruri", "Extensii de fișier, **fără punct**"],
                    ["`caseSensitive`", "boolean", "Dacă cuvintele-cheie disting majusculele"],
                    ["`lineComment`", "șir", "Semnul de comentariu până la capăt de linie; omiteți-l dacă nu există"],
                    ["`blockComment`", "tablou de 2 șiruri", "`[deschidere, închidere]`"],
                    ["`stringDelimiters`", "tablou de șiruri", "Fiecare element e **un singur** caracter care deschide/închide un șir"],
                    ["`escapeCharacter`", "șir", "Caracter de evadare în șiruri; gol înseamnă că limbajul nu are"],
                    ["`keywordGroups`", "obiect", "Nume de grup → listă de cuvinte-cheie; trei grupuri primesc trei culori"],
                ]
            ),
            .paragraph("""
                Cele trei nume de grup care primesc culori proprii sunt `keyword`, `type` și `constant`.
                """),
            .warning("""
                Acest analizor **nu înțelege imbricarea**. Plierea structurală, lista de funcții și \
                potrivirea inteligentă a parantezelor rămân apanajul celor douăzeci de limbaje \
                încorporate. E un compromis intenționat: în schimb declarați un limbaj în zece minute, nu \
                într-o zi.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Unelte JSON",
        summary: "Reformatare, comprimare, sortarea cheilor și verificare după un JSON Schema.",
        keywords: ["json", "format", "comprimare", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Comandă", "Ce face"],
                rows: [
                    ["Reformatează", "Rupe rândurile și indentează pentru citire"],
                    ["Comprimă", "Elimină toate spațiile de prisos"],
                    ["Sortează cheile", "Ordonează alfabetic cheile fiecărui obiect — ca două fișiere JSON să poată fi **comparate**"],
                    ["Verifică după JSON Schema…", "Verifică documentul după un fișier de schemă, listând fiecare problemă cu linia ei"],
                ]
            ),
            .paragraph("""
                Regulile aplicate sunt **RFC 8259 strict**: fără virgule finale, fără comentarii, fără \
                `NaN`. O eroare de sintaxă arată linia și coloana exacte.
                """),
            .note("""
                Se recunosc și fișierele **JSONL** (un obiect pe linie) și au propriul set de unelte în \
                capitolul pachetului de cunoștințe.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Interogări JSONPath",
        summary: "Extrageți exact partea de care aveți nevoie dintr-un fișier JSON mare.",
        keywords: ["jsonpath", "interogare json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Scrieți o expresie; rezultatele apar ca listă în care puteți sări."),
            .table(
                headers: ["Scrieți", "Sens"],
                rows: [
                    ["`$`", "Rădăcina documentului"],
                    ["`$.name`", "Cheia `name` de la rădăcină"],
                    ["`$.orders[0]`", "Primul element al unui tablou"],
                    ["`$.orders[*].total`", "Cheia `total` a **fiecărui** element"],
                    ["`$..province`", "Cheia `province` la **orice adâncime**"],
                    ["`$.orders[1:3]`", "O felie: elementele 1 și 2"],
                ]
            ),
            .code(language: "text", caption: "Codul de provincie al fiecărei comenzi, oricât de adânc ar fi",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Unelte XML",
        summary: "Reformatare, comprimare, verificarea sintaxei și verificare după DTD sau XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "verificare", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Comandă", "Ce face"],
                rows: [
                    ["Reformatează", "Indentează după adâncimea etichetelor"],
                    ["Comprimă", "Elimină spațiile dintre etichete"],
                    ["Verifică sintaxa", "Etichete de închidere lipsă, imbricare greșită, caractere nevalide"],
                    ["Verifică după DTD/XSD…", "Verifică după o schemă, raportând fiecare problemă cu linia ei"],
                    ["Evaluează XPath…", "Rulează o expresie XPath; rezultatele se deschid într-o filă nouă"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Scrieți o expresie, iar rezultatele se deschid ca **filă de text**, un nod pe linie. De \
                pildă: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Rezultatele NU sar la o poziție din fișierul-sursă.** Evaluatorul XPath al sistemului \
                își construiește propriul arbore și nu păstrează deplasamentul în octeți al fiecărui nod, \
                așa că ce se întoarce este CONȚINUT, nu coordonate. Ca să ajungeți la locul exact, \
                folosiți `⌘F` pe șirul tocmai găsit.
                """),
            .paragraph("""
                În fișierele `.xml` și `.html`, scrierea lui `>` pentru a încheia o etichetă de deschidere \
                face ca **eticheta de închidere să apară**, cu cursorul între ele. Etichetele \
                autoînchise (`<br/>`), declarațiile (`<?xml …?>`) și comentariile nu — nu au ce închide.
                """),
            .warning("""
                Reformatarea XML **schimbă spațiile dintre etichete**. În documentele unde acele spații au \
                înțeles — să zicem XHTML cu text în etichete — asta schimbă ce se afișează. E un singur pas \
                de anulare, așa că `⌘Z` îl inversează.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Verificare YAML",
        summary: "Prindeți cele două greșeli YAML cele mai frecvente: chei repetate și indentare cu tabulatoare.",
        keywords: ["yaml", "yml", "lint", "cheie repetată", "indentare"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Chei repetate** într-o mapare — majoritatea cititoarelor YAML iau **ultima** și le aruncă în tăcere pe cele dinainte, așa că un fișier de configurare se poate purta cu totul altfel decât vă așteptați.",
                "**Indentare cu tabulatoare** — YAML interzice tabulatoarele în indentare, iar mesajele de eroare ale bibliotecilor despre asta sunt de obicei de neînțeles.",
            ]),
            .note("Activați `Arată invizibilele ▸ Tabulatoare` ca să vedeți imediat ce spațiu e tabulator."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Fișiere de jurnal",
        summary: "Șapte niveluri de gravitate, filtrare pe nivel și cum se citește un jurnal foarte mare.",
        keywords: ["jurnal", "eroare", "avertisment", "filtru", "nivel"],
        blocks: [
            .paragraph("""
                Activați `Vizualizare ▸ Mod jurnal (colorare după nivel)`. GEditor citește gravitatea de \
                la **începutul fiecărei linii** — după marca de timp și numele procesului.
                """),
            .table(
                headers: ["Nivel", "Culoare"],
                rows: [
                    ["CRITICAL · ERROR", "Roșu"],
                    ["WARNING", "Chihlimbariu"],
                    ["NOTICE", "Culoare de accent"],
                    ["INFO", "Text obișnuit"],
                    ["DEBUG · TRACE", "Estompat"],
                ]
            ),
            .paragraph("""
                `Filtrează jurnalul după nivel…` ascunde complet nivelurile inferioare. Liniile al căror \
                nivel **nu e recunoscut** — de pildă continuarea unei stive de apeluri — sunt lăsate în \
                pace, în loc să primească nivelul liniei precedente.
                """),
            .heading("Citirea unui jurnal mare, pas cu pas"),
            .steps([
                "Deschideți fișierul — și la scară de gigaocteți se deschide aproape instantaneu.",
                "`Vizualizare ▸ Mod jurnal` ca să vedeți petele roșii.",
                "`⌥⌘M` pentru harta documentului: roșul e grupat pe o porțiune sau împrăștiat în tot fișierul?",
                "`⌘F` pentru codul de eroare, `⌘M` ca să marcați fiecare linie potrivită.",
                "`Căutare ▸ Copiază liniile marcate` ca să le trageți într-o filă nouă.",
                "Încă rulează? `Fișier ▸ Urmărește fișierul (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
