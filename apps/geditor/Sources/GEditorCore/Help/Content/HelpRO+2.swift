import Foundation

/// Conținut de ajutor în română — partea 2: căutare, fișiere și sesiuni.
extension HelpRO {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Căutare",
        summary: "Căutare, înlocuire, expresii regulate, căutare într-un dosar și marcaje de linie.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Caută și înlocuiește",
        summary: "Trei moduri de căutare și de ce ^ înseamnă implicit începutul LINIEI.",
        keywords: ["caută", "înlocuiește", "găsește", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Caută"),
                HelpShortcut("⌥⌘F", "Caută și înlocuiește"),
                HelpShortcut("⌘G / ⇧⌘G", "Potrivirea următoare / precedentă"),
            ]),
            .heading("Trei moduri"),
            .table(
                headers: ["Mod", "Înțelege", "Folosit pentru"],
                rows: [
                    ["Normal", "Text simplu, fără niciun caracter special", "Majoritatea căutărilor"],
                    ["Extins", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Găsirea sfârșiturilor de linie, a TAB-urilor, a unor octeți anume"],
                    ["Regex", "PCRE2 complet", "Potrivirea după tipar"],
                ]
            ),
            .note("""
                Modul **extins** nu înțelege sintaxa regex. Extinde doar câteva secvențe de evadare — \
                așa că o căutare `a.b` acolo găsește exact acele trei caractere; punctul nu e un joker.
                """),
            .heading("Două comutatoare"),
            .bullets([
                "**Distincție majuscule/minuscule** — dezactivată implicit.",
                "**Doar cuvinte întregi** — se potrivește doar când ambele capete sunt limite de cuvânt.",
            ]),
            .heading("`^` și `$` se potrivesc la marginile fiecărei LINII"),
            .paragraph("""
                Activat implicit. Cei care vin de la Notepad++ se așteaptă ca `^` să însemne »început de \
                linie«; fără el, `^abc` s-ar potrivi doar dacă tot documentul ar începe cu `abc` — asta \
                nu vrea aproape nimeni într-un editor de text.
                """),
            .heading("O expresie proastă nu blochează aplicația"),
            .paragraph("""
                Motorul este **PCRE2 cu compilare JIT** și are un buget de revenire. Un tipar care \
                explodează combinatoriu este oprit și raportat, în loc să înghețe fereastra.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Expresii regulate",
        summary: "Sintaxa PCRE2 pe care chiar o folosiți, cu exemple care rulează pe date vietnameze.",
        keywords: ["regex", "regexp", "pcre", "tipar"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor folosește **PCRE2**, același motor ca PHP și multe unelte de linie de comandă. \
                Deschideți `Căutare ▸ Testează expresia regulată…` pentru a încerca un tipar pe un text \
                de probă și a vedea ce prinde fiecare grup **înainte** de a-l aplica pe un document real.
                """),
            .heading("Clase de caractere"),
            .table(
                headers: ["Scrieți", "Se potrivește cu"],
                rows: [
                    ["`.`", "Orice caracter în afară de sfârșitul de linie"],
                    ["`\\d` · `\\D`", "O cifră · o necifră"],
                    ["`\\w` · `\\W`", "Un caracter de cuvânt (literă, cifră, `_`) · opusul"],
                    ["`\\s` · `\\S`", "Spațiu alb · nu spațiu alb"],
                    ["`[abc]`", "Unul dintre caracterele din paranteze"],
                    ["`[^abc]`", "Un caracter care NU este în paranteze"],
                    ["`[a-z]`", "Un caracter din interval"],
                ]
            ),
            .heading("Repetiție"),
            .table(
                headers: ["Scrieți", "Sens"],
                rows: [
                    ["`*`", "Zero sau mai multe"],
                    ["`+`", "Unul sau mai multe"],
                    ["`?`", "Zero sau unul"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Exact 3 · între 2 și 5 · 2 sau mai multe"],
                    ["`*?` `+?` `??`", "Formele **leneșe** — ia cât mai puțin"],
                ]
            ),
            .warning("""
                `.*` este **lacom**: mănâncă până la sfârșitul liniei, apoi dă înapoi. Când despărțiți \
                câmpuri într-o linie, aproape întotdeauna aveți nevoie de `.*?` sau de o clasă îngustă \
                precum `[^,]*`.
                """),
            .heading("Ancore și grupuri"),
            .table(
                headers: ["Scrieți", "Sens"],
                rows: [
                    ["`^` · `$`", "Început de linie · sfârșit de linie"],
                    ["`\\b`", "Limită de cuvânt"],
                    ["`(…)`", "Grup **de captură** — reutilizabil în înlocuire"],
                    ["`(?:…)`", "Grup fără captură"],
                    ["`(?<name>…)`", "Grup denumit"],
                    ["`a|b`", "a sau b"],
                    ["`(?=…)` · `(?!…)`", "Privire înainte: trebuie să urmeze · nu trebuie să urmeze"],
                    ["`(?<=…)` · `(?<!…)`", "Privire înapoi: trebuie să preceadă · nu trebuie să preceadă"],
                ]
            ),
            .heading("Exemple care rulează"),
            .code(language: "regex", caption: "Orice număr de telefon vietnamez de 10 cifre",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Împarte o dată ca 31/12/2026 în trei grupuri",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "A treia celulă a unui rând CSV simplu (fără ghilimele)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Linii de jurnal de nivel ERROR sau FATAL, cu marca de timp",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Linii goale sau linii doar cu spații albe",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Litere vietnameze cu diacritice — folosiți clasa Unicode, nu le enumerați",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` înseamnă »orice literă Unicode«, așa că se potrivește și cu `ế` și cu `đ`. A \
                enumera manual fiecare vocală cu diacritice e o metodă sigură de a scăpa unele.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Șiruri de înlocuire",
        summary: "Refolosiți grupurile capturate și schimbați majusculele în timpul înlocuirii.",
        keywords: ["înlocuire", "referință inversă", "grup", "$1", "\\U"],
        blocks: [
            .heading("Rechemarea unui grup capturat"),
            .table(
                headers: ["Scrieți", "Sens"],
                rows: [
                    ["`$1` … `$9`", "Conținutul grupului n"],
                    ["`${1}`", "Același lucru, cu limite explicite — folosiți-l când urmează o cifră"],
                    ["`\\1`", "Se acceptă și așa; GEditor îl rescrie ca `${1}`"],
                    ["`$0`", "Toată potrivirea"],
                ]
            ),
            .note("""
                Scrieți `${1}` în loc de `$1` când caracterul următor e o cifră. `$123` se citește ca \
                grupul 123; `${1}23` este grupul 1 urmat de două cifre.
                """),
            .heading("Schimbarea majusculelor în timpul înlocuirii"),
            .table(
                headers: ["Scrieți", "Sens"],
                rows: [
                    ["`\\U`", "MAJUSCULE de aici înainte"],
                    ["`\\L`", "minuscule de aici înainte"],
                    ["`\\u`", "Doar caracterul următor cu majusculă"],
                    ["`\\l`", "Doar caracterul următor cu minusculă"],
                    ["`\\E`", "Încheie zona `\\U` sau `\\L`"],
                ]
            ),
            .heading("Exemple"),
            .code(language: "text", caption: "Transformă 31/12/2026 în 2026-12-31",
                  source: """
                    Caută:      (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Înlocuiește: $3-$2-$1
                    """),
            .code(language: "text", caption: "Codul de provincie de la începutul fiecărei linii cu majuscule, restul rămâne",
                  source: """
                    Caută:      ^([a-z]{2,3})(\\s)
                    Înlocuiește: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Împachetează fiecare linie ca șir JSON",
                  source: """
                    Caută:      ^(.+)$
                    Înlocuiește: "$1",
                    """),
            .paragraph("""
                Un grup care **nu a participat** la potrivire devine un șir gol, nu o eroare — așa că un \
                tipar cu alternative precum `(a)|(b)` înlocuiește curat fără a fi scris de două ori.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Caută și înlocuiește într-un dosar întreg",
        summary: "Scanați multe fișiere deodată și vedeți rezultatele înainte să se scrie ceva.",
        keywords: ["caută în fișiere", "grep", "înlocuire în masă", "dosar"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Caută într-un dosar întreg")]),
            .paragraph("""
                Alegeți dosarul rădăcină, filtrați după tiparul numelui de fișier, apoi scanați. \
                Rezultatele apar ca listă grupată pe fișiere; un clic pe o linie deschide acel fișier în \
                acel loc.
                """),
            .bullets([
                "Aceleași trei moduri de căutare și același motor regex ca la câmpul de căutare din document.",
                "Înlocuirea într-un dosar **previzualizează** câte fișiere și câte potriviri se vor schimba înainte de scriere.",
                "Scanarea rulează în paralel și **poate fi anulată** la jumătate.",
            ]),
            .warning("""
                Înlocuirea într-un dosar scrie direct în fișiere care **nu sunt deschise**. Acele fișiere \
                nu se află în istoricul de anulare al documentului deschis — previzualizați întâi și \
                păstrați o copie de rezervă sau un depozit cu control de versiuni.
                """),
            .heading("Căutări anterioare și exportul rezultatelor"),
            .paragraph("""
                Panoul de rezultate **păstrează căutările acestei sesiuni**. Meniul derulant din capul \
                panoului le enumeră cu numărul de potriviri — căutați `TODO`, citiți puțin, căutați \
                `FIXME` pentru comparație, apoi reveniți la prima listă fără a rescana tot dosarul.
                """),
            .paragraph("""
                Butonul **Exportă** deschide căutarea curentă ca filă de text, un rezultat pe linie sub \
                forma `cale:linie:coloană: text` — forma pe care o folosește `grep -n` și pe care o \
                folosesc compilatoarele pentru erori. Fiecare linie se lipește direct în câmpul `Mergi \
                la` al produsului, iar `grep`, `awk` și `sed` o citesc fără analizor propriu.
                """),
            .note("""
                Istoricul trăiește în **memorie** și nu se scrie niciodată pe disc: rezultatele căutării \
                poartă conținutul fiecărei linii potrivite, adică aceeași clasă de date pe care istoricul \
                clipboardului nu o păstrează intenționat.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Marcaje de linie",
        summary: "Nouă culori de marcaj și patru comenzi care transformă liniile marcate într-un rezultat.",
        keywords: ["semn de carte", "marcaj", "f2", "filtrează linii"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Marcarea este felul în care filtrați un document **fără a-l schimba**. Marcați fiecare \
                linie care se potrivește unui tipar, apoi copiați doar acelea — sau păstrați doar pe ele.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Marchează fiecare linie potrivită cu căutarea curentă"),
                HelpShortcut("⌘F2", "Marchează / demarchează linia curentă"),
                HelpShortcut("F2 / ⇧F2", "Sari la marcajul următor / precedent"),
            ]),
            .heading("Un flux obișnuit"),
            .steps([
                "`⌘F` pentru tiparul după care vreți să filtrați, de pildă `\\bERROR\\b`.",
                "`⌘M` marchează fiecare linie potrivită.",
                "`Căutare ▸ Copiază liniile marcate` le trage într-o filă nouă — sau `Păstrează doar liniile marcate` filtrează pe loc.",
            ]),
            .heading("Nouă culori"),
            .paragraph("""
                O linie poate purta **mai multe culori deodată**. Folosiți culori diferite pentru \
                criterii diferite și combinați-le: roșu pentru liniile cu erori, galben pentru liniile \
                unei anumite comenzi, apoi căutați liniile care le poartă pe amândouă.
                """),
            .bullets([
                "`Inversează marcajele` — liniile marcate devin nemarcate și invers.",
                "`Șterge toate marcajele` — elimină fiecare marcaj fără a atinge conținutul.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Mergi la linie",
        summary: "Săriți la o linie, o coloană sau o poziție în octeți.",
        keywords: ["mergi la", "număr de linie", "cmd+l", "poziție", "coloană"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Mergi la linie")]),
            .paragraph("""
                Câmpul înțelege **trei notații** și le deosebește după ce scrieți — nu există alt \
                selector pe care să faceți clic.
                """),
            .table(
                headers: ["Scrieți", "Merge la"],
                rows: [
                    ["`120`", "începutul liniei 120"],
                    ["`120,5` sau `120:5`", "linia 120, coloana 5 — coloana numără CARACTERE"],
                    ["`@1024`", "poziția 1024 în octeți din fișier"],
                ]
            ),
            .note("""
                `linie:coloană` este exact felul în care compilatoarele și linterele scriu o poziție, așa \
                că o linie tocmai copiată dintr-un terminal se lipește direct.

                `@` pentru pozițiile în octeți are un motiv: `1234` e o linie sau un octet? Nu există \
                răspuns corect, iar o presupunere greșită trimite cursorul cu totul altundeva fără nimic \
                care să semnaleze. Acel număr de octeți e și cel afișat de bara de stare în segmentul de \
                poziție (`@1024`), așa că ce citiți acolo scrieți aici.
                """),
            .bullets([
                "O coloană **peste lungimea liniei** se oprește la sfârșitul acelei linii; nu se revarsă pe următoarea.",
                "O poziție în octeți **peste fișier** vă duce la sfârșit — de obicei ați copiat acel număr dintr-o rulare anterioară, iar fișierul poate s-a micșorat.",
                "Textul pe care nu-l poate citi este **raportat**, iar cursorul rămâne pe loc; nu sare la începutul fișierului.",
            ]),
            .paragraph("""
                Pe fișiere foarte mari, GEditor nu citește tot fișierul ca să ajungă acolo — indexul de \
                linii se construiește treptat în fundal.
                """),
            .note("""
                Unealta de linie de comandă acceptă și o poziție: `geditor report.csv:120:5` deschide \
                fișierul cu cursorul pe linia 120, coloana 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Fișiere și sesiuni

    static let files = HelpChapter(
        id: "tep",
        title: "Fișiere și sesiuni",
        summary: "Deschidere, salvare, file, ferestre, spații de lucru și cum revine sesiunea.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Deschidere și salvare",
        summary: "Deschideți un fișier de orice mărime și salvați-l cu altă codificare sau alt sfârșit de linie.",
        keywords: ["deschide", "salvează", "salvează ca", "duplică", "redenumește", "mută"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Document nou"),
                HelpShortcut("⌘O", "Deschide un fișier"),
                HelpShortcut("⌘S", "Salvează"),
                HelpShortcut("⇧⌘S", "Salvează ca"),
            ]),
            .paragraph("""
                Tragerea unui fișier în fereastră îl deschide de asemenea. `Fișier ▸ Deschide recente` \
                păstrează lista fișierelor cu care tocmai lucrați.
                """),
            .heading("Salvează ca: trei lucruri pe care le puteți schimba"),
            .table(
                headers: ["Schimbare", "Sens"],
                rows: [
                    ["Codificare", "Scrieți ca UTF-8, TCVN3, VNI-Windows… — 36 de codificări"],
                    ["Sfârșituri de linie", "LF (Unix) · CRLF (Windows) · CR (Mac clasic)"],
                    ["Nume și locație", "Ca în orice dialog de salvare macOS"],
                ]
            ),
            .paragraph("""
                Bara de stare arată mereu codificarea, stilul sfârșitului de linie și limbajul detectat. \
                **Un clic pe oricare dintre ele îl schimbă imediat**, fără dialog.
                """),
            .heading("Duplică · redenumește · mută"),
            .paragraph("""
                Aceste trei lucrează cu FIȘIERUL, nu cu conținutul lui — iar fila deschisă urmează \
                fișierul, așa că nu vă pierdeți niciodată locul.
                """),
            .table(
                headers: ["Comandă", "Ce face"],
                rows: [
                    ["`Duplică fișierul`",
                     "Îl copiază drept `nume 2.txt` lângă original și **deschide copia** — pentru că oamenii duplică pentru a edita copia"],
                    ["`Redenumește fișierul…`", "Redenumește pe disc; fila urmează noul nume"],
                    ["`Mută fișierul în…`", "Mută în alt dosar; fila merge cu el"],
                ]
            ),
            .note("""
                Toate trei **refuză când există deja un fișier cu acel nume** la destinație; nu \
                suprascriu niciodată. Și toate trei au nevoie de un fișier salvat cel puțin o dată — un \
                document care n-a fost niciodată pe disc nu are ce duplica sau muta.
                """),
            .heading("Scriere sigură"),
            .bullets([
                "Scrierea este **atomică**: o pană de curent la jumătate nu lasă niciodată un fișier trunchiat.",
                "Dacă alt program modifică fișierul cât îl aveți deschis, GEditor observă și întreabă înainte de suprascriere.",
                "Fișierele de pe iCloud Drive sau de pe un volum de rețea trec prin coordonatorul de fișiere al sistemului, ca două mașini să nu se calce pe picioare.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "File, ferestre și vedere împărțită",
        summary: "Multe file pe fereastră, multe ferestre și file pe care le puteți trage între ele.",
        keywords: ["filă", "fereastră", "împărțire", "panou"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Filă nouă"),
                HelpShortcut("⌘W", "Închide fila"),
                HelpShortcut("⇧⌘T", "Redeschide ultima filă închisă"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Fila următoare / precedentă"),
                HelpShortcut("⌥⌘N", "Fereastră nouă"),
                HelpShortcut("⌃⌘N", "Desprinde fila curentă în fereastra ei"),
            ]),
            .paragraph("""
                Puteți trage o filă în altă fereastră sau o puteți lăsa pe spațiu gol ca să faceți o \
                fereastră nouă. **O filă fixată nu călătorește** — fixarea înseamnă »ține-o pe asta aici«.
                """),
            .note("""
                `⇧⌘T` redeschide ultima filă închisă, inclusiv una **nesalvată**: conținutul ei e tot \
                acolo.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Deschiderea unui dosar ca spațiu de lucru",
        summary: "Un arbore de fișiere în bara laterală, căutare în tot proiectul și deschidere cu un clic.",
        keywords: ["spațiu de lucru", "dosar", "proiect", "bară laterală"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Deschide un dosar ca spațiu de lucru")]),
            .paragraph("""
                Arborele apare în bara laterală (`⌘0`). Faceți clic pe un fișier ca să-l deschideți, iar \
                `⇧⌘F` caută în tot dosarul.
                """),
            .note("""
                În ediția App Store, accesul la dosar este ținut de un **semn de carte cu domeniu de \
                securitate**, așa că pornirea următoare îl mai poate atinge fără să vă ceară din nou \
                alegerea dosarului.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "Sesiunea se restaurează singură",
        summary: "Ieșiți și deschideți din nou: fiecare filă revine, inclusiv cele nesalvate.",
        keywords: ["sesiune", "restaurare", "nesalvat"],
        blocks: [
            .paragraph("""
                Nu e nimic de activat. Ieșiți din GEditor și deschideți-l din nou: filele, ordinea lor, \
                pozițiile cursorului și pozițiile de derulare revin toate.
                """),
            .heading("Ce se întâmplă cu filele nesalvate"),
            .paragraph("""
                Conținutul lor se păstrează într-un instantaneu separat, așa că revin și ele. Dacă \
                aplicația se încheie anormal, pornirea următoare **întreabă** înainte de a restaura \
                ciornele orfane — în loc să reconstruiască în tăcere un morman de file de care nu vă \
                amintiți.
                """),
            .warning("""
                O sesiune **nu este o copie de rezervă**. Păstrează starea de lucru, nu istoricul. Tot \
                ce contează trebuie totuși salvat într-un fișier.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Versiuni salvate anterior",
        summary: "Răsfoiți și restaurați versiuni mai vechi ale unui fișier.",
        keywords: ["versiuni", "istoric", "restaurare", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                La fiecare salvare, GEditor notează versiunea **precedentă** înainte de suprascriere. \
                `Macro ▸ Versiuni salvate…` deschide răsfoitorul lor.
                """),
            .bullets([
                "Depozitul de versiuni este **al sistemului de operare**, același mecanism folosit de aplicațiile Apple.",
                "Restaurarea unei versiuni mai vechi este o **editare obișnuită** — `⌘Z` o anulează.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Urmărirea unui fișier care încă se scrie",
        summary: "Ca `tail -f`: ce se adaugă apare pe măsură ce sosește.",
        keywords: ["tail", "urmărire", "jurnal", "timp real"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Fișier ▸ Urmărește fișierul (tail -f)` încarcă ce apare la sfârșitul fișierului și \
                derulează odată cu el.
                """),
            .warning("""
                În timpul urmăririi, documentul devine **doar pentru citire**. A scrie în timp ce se \
                încarcă text nou de pe disc înseamnă doi scriitori peste un document, iar cel care pierde \
                e mereu ce tocmai ați scris.
                """),
            .note("""
                Bara de stare arată **Se urmărește** tot timpul, așa că și minute mai târziu știți de ce \
                fișierul nu acceptă scrierea. Un clic pe segmentul **doar pentru citire** spune motivul \
                direct.

                Urmărirea aparține **filei care a pornit-o**, nu ferestrei: deschideți altă filă și \
                scrieți mai departe, iar liniile noi de jurnal curg în continuare în fila lor, fără a \
                atinge fișierul pe care îl editați.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Tipărire",
        summary: "Tipăriți prin dialogul standard de tipărire al macOS.",
        keywords: ["tipărire", "hârtie", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Tipărește")]),
            .paragraph("""
                Folosește dialogul de tipărire al sistemului, așa că exportul în PDF se face tot acolo — \
                butonul `PDF` din stânga jos.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Imagini, PDF-uri, fișiere Office, sunet, video și arhive",
        summary: "Opt feluri de fișiere se deschid în GEditor fără altă aplicație.",
        keywords: ["imagine", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arhivă",
                   "sunet", "video", "mp3", "mp4"],
        blocks: [
            .table(
                headers: ["Fel", "Ce puteți face"],
                rows: [
                    ["Imagini", "Vizualizare, mărire, rotire; **imaginile animate rulează** și pot fi puse pe pauză"],
                    ["Sunet", "Redare, derulare, schimbarea volumului"],
                    ["Video", "Redare, derulare, ecran complet, imagine în imagine"],
                    ["PDF", "Citire, căutare, **adnotare**"],
                    ["Word · Excel · PowerPoint", "Vizualizare **și editare** — `⌘S` scrie direct înapoi în fișier"],
                    ["ZIP · TAR · GZ · XZ", "Listarea intrărilor și deschiderea fiecăreia ca filă"],
                    ["7z · RAR și încă șapte formate", "La fel, prin libarchive"],
                ]
            ),
            .paragraph("""
                Deschiderea unei intrări dintr-o arhivă creează o filă nouă cu conținutul ei. \
                Diacriticele vietnameze supraviețuiesc atât în nume, cât și în conținut.
                """),
            .note("""
                Editați unul dintre cele trei formate Office, apăsați `⌘S`, și se scrie înapoi în fișier \
                — LibreOffice citește rezultatul. Această cale este testată cap la cap, nu doar \
                exportată într-o copie.
                """),
            .heading("Sunetul și videoul folosesc redoarele macOS"),
            .paragraph("""
                Redarea trece prin decodoarele proprii ale sistemului, așa că nu se descarcă nimic în \
                plus și nu se livrează nimic în plus. În schimb, câteva formate **nu se redau** — \
                `.mkv`, `.webm`, `.avi`, `.wmv` — pentru că macOS nu are decodor încorporat pentru ele.
                """),
            .paragraph("""
                Pentru un asemenea fișier, GEditor **spune de ce** în loc să arate un dreptunghi negru, \
                și oferă vizualizatorul binar sau altă aplicație.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Unelte PDF",
        summary: "Citire, adnotare și un întreg strat de pagini: rotire · mutare · ștergere · extragere · îmbinare.",
        keywords: ["pdf", "pagină", "rotire", "șterge pagina", "extrage", "îmbină",
                   "notă", "evidențiere", "semnătură"],
        blocks: [
            .paragraph("""
                Vederea PDF are **două bare de unelte**, care răspund la întrebări diferite. Rândul de \
                sus lucrează pe **conținutul** unei pagini; cel de jos pe **mulțimea de pagini**.
                """),
            .heading("Rândul de sus — citire și adnotare"),
            .table(
                headers: ["Buton", "Ce face"],
                rows: [
                    ["Evidențiază · Subliniază", "Marchează textul selectat"],
                    ["Notă…", "Atașează o notă la pagină"],
                    ["Elimină adnotările", "Elimină fiecare adnotare de pe pagina curentă"],
                    ["Extrage textul într-o filă nouă", "Mută tot textul într-o filă ca să puteți căuta, filtra, rula alte unelte"],
                    ["Câmp de căutare", "Caută în PDF — **scrisul fără diacritice găsește totuși text cu diacritice**"],
                ]
            ),
            .note("""
                Un PDF scanat nu are strat de text. Comanda de extragere **o spune** în loc să deschidă \
                o filă goală și să vă lase să ghiciți.
                """),
            .heading("Rândul de jos — operații pe pagini"),
            .table(
                headers: ["Buton", "Ce face", "Se anulează"],
                rows: [
                    ["Rotește la stânga · la dreapta", "Întoarce pagina curentă cu 90°", "Da"],
                    ["Pagina sus · jos", "Schimbă pagina curentă cu vecina", "Da"],
                    ["Șterge pagini…", "Șterge după interval, de ex. `2-4,7`", "Da"],
                    ["Extrage pagini…", "Scrie un interval de pagini ca **fișier nou**", "Nu atinge fișierul deschis"],
                    ["Îmbină un PDF…", "Inserează alt PDF imediat după pagina curentă", "Da"],
                    ["Semnează…", "Așază o imagine de semnătură pe pagina curentă", "Da"],
                    ["Editează textul…", "Desenează text de înlocuire peste selecție", "Da"],
                    ["Următorul câmp gol", "Sare la următorul câmp de formular necompletat", "—"],
                    ["Golește valorile completate", "Golește fiecare câmp de formular", "Da"],
                    ["Anulează modificarea de pagină", "Un pas înapoi într-o operație pe pagini", "—"],
                    ["Salvează copia editată…", "Scrie un fișier nou, apoi **îl redeschide pentru verificare**", "—"],
                ]
            ),
            .heading("Formulare completabile"),
            .paragraph("""
                Deschideți un PDF cu câmpuri de formular și bara de stare spune **câte** sunt. Scrieți \
                direct în câmpurile de pe pagină, apoi `Salvează copia editată…`.
                """),
            .bullets([
                "Valorile se păstrează ca **câmpuri de formular vii**, nu ca text aplatizat — așa că Acrobatul destinatarului vede tot un formular completat și îl poate corecta.",
                "Diacriticele vietnameze supraviețuiesc ciclului scriere-și-redeschidere. Un test păzește exact asta, cu numele `Nguyễn Văn Anh`.",
                "`Următorul câmp gol` sare la următorul gol — calea firească printr-un formular lung.",
            ]),
            .heading("Semnarea"),
            .paragraph("""
                Pregătiți o imagine de semnătură (un PNG cu fundal transparent merge cel mai bine), \
                **selectați locul de semnat** — de obicei linia punctată sau cuvântul »Semnătură« —, apoi \
                apăsați `Semnează…`. Fără selecție, semnătura aterizează dreapta-jos.
                """),
            .note("""
                Semnătura păstrează **raportul de aspect** al imaginii: o semnătură turtită sau întinsă \
                pare falsă instantaneu.
                """),
            .heading("Editarea textului — și trei lucruri de știut întâi"),
            .paragraph("""
                Selectați textul de schimbat și apăsați `Editează textul…`. GEditor **acoperă acea zonă \
                cu o culoare de fundal luată chiar de lângă ea**, apoi desenează deasupra textul nou.
                """),
            .warning("""
                **Textul vechi este ACOPERIT, nu ȘTERS.** Este tot în fișier și tot extractibil cu \
                `Extrage textul într-o filă nouă` sau cu orice altă unealtă. Aceasta **nu este \
                anonimizare**: a ascunde astfel un cod numeric personal îl ascunde de un ochi omenesc, \
                nu de o mașină.
                """),
            .bullets([
                "**Textul nou se găsește în continuare cu `⌘F`.** Este desenat ca text real, nu ca imagine — măsurat de un test, nu presupus.",
                "**Fontul este un font de sistem**, nu cel original al documentului. Intenționat: fonturile încorporate într-un PDF adesea nu au diacritice vietnameze, iar `Nguyễn` ar ajunge `Nguy?n`.",
                "**Pe un fundal cu model, petecul se vede** — culoarea de acoperire se ia dintr-un singur punct, chiar la stânga selecției.",
            ]),
            .heading("De ce desenăm deasupra în loc să edităm fluxul de conținut"),
            .paragraph("""
                A edita direct fluxul de conținut al unui PDF înseamnă a te lupta cu fonturi \
                subsetate cu codificare proprie, cu propoziții rupte în trei bucăți de kerning și cu \
                tabele de lățimi de caractere care trebuie recalculate. A face asta corect pentru \
                **fiecare** fișier e un proiect în sine; a o face greșit strică documentul cuiva.
                """),
            .paragraph("""
                În schimb, restul paginii **nu se schimbă nici cu un octet**, iar pagina rămâne pagină — \
                textul se selectează, se copiază și se caută în continuare. Redesenarea **nu** o \
                transformă în imagine.
                """),
            .heading("Sintaxa intervalului de pagini"),
            .table(
                headers: ["Scrieți", "Sens"],
                rows: [
                    ["`5`", "Doar pagina 5"],
                    ["`2-4`", "Paginile 2, 3, 4"],
                    ["`-3`", "De la început până la pagina 3"],
                    ["`8-`", "De la pagina 8 până la sfârșit"],
                    ["`1-3,5,9-`", "Mai multe părți unite cu virgule"],
                ]
            ),
            .paragraph("Paginile se numără **de la 1**, numărul pe care îl vedeți pe ecran."),
            .warning("""
                Un interval inversat (`5-2`) și unul care depășește sfârșitul (`1-999`) sunt amândouă \
                **refuzate cu un motiv**, niciodată corectate în tăcere spre ceva apropiat. Pentru o \
                comandă de ștergere de pagini, o presupunere greșită înseamnă pagini pierdute, iar \
                tăierea tăcută transformă o greșeală de tastare într-o comandă validă.
                """),
            .heading("Fișierul original nu se suprascrie niciodată"),
            .paragraph("""
                Tot ce e mai sus schimbă documentul **în memorie**. Abia când apăsați `Salvează copia \
                editată…` și alegeți o locație se scrie un fișier — iar după scriere GEditor **redeschide \
                chiar acel fișier** ca să confirme că are toate paginile.
                """),
            .paragraph("""
                Motivul: un fișier scris prost stă pe disc arătând perfect normal, iar utilizatorul află \
                abia după ce l-a trimis.
                """),
            .note("""
                Linia de stare a vederii arată **· editat, nesalvat** ori de câte ori documentul diferă \
                de fișierul de pe disc.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
