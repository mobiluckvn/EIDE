import Foundation

/// Conteúdo de ajuda em português — parte 2: procura, ficheiros e sessões.
extension HelpPT {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Procura",
        summary: "Procurar, substituir, expressões regulares, procura em pastas e marcas de linha.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Procurar e substituir",
        summary: "Três modos de procura, e porque ^ significa início de LINHA por omissão.",
        keywords: ["procurar", "substituir", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Procurar"),
                HelpShortcut("⌥⌘F", "Procurar e substituir"),
                HelpShortcut("⌘G / ⇧⌘G", "Ocorrência seguinte / anterior"),
            ]),
            .heading("Três modos"),
            .table(
                headers: ["Modo", "Percebe", "Para"],
                rows: [
                    ["Normal", "Texto simples, nenhum caractere especial", "A maioria das procuras"],
                    ["Alargado", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Encontrar fins de linha, tabulações, bytes concretos"],
                    ["Regex", "PCRE2 completo", "Procurar por padrão"],
                ]
            ),
            .note("""
                O modo **alargado** não percebe sintaxe de regex. Apenas expande algumas sequências de \
                escape — procurar `a.b` aí encontra exatamente esses três caracteres; o ponto não é um \
                caractere universal.
                """),
            .heading("Dois interruptores"),
            .bullets([
                "**Distinguir maiúsculas** — desligado por omissão.",
                "**Palavra inteira** — só corresponde quando ambas as extremidades são limites de palavra.",
            ]),
            .heading("`^` e `$` correspondem nos bordos de cada LINHA"),
            .paragraph("""
                Ligado por omissão. Quem vem do Notepad++ espera que `^` signifique «início de linha»; \
                sem isso, `^abc` só corresponderia se o documento inteiro começasse por `abc` — quase \
                ninguém quer isso num editor de texto.
                """),
            .heading("Uma expressão má não bloqueia a aplicação"),
            .paragraph("""
                O motor é **PCRE2 com compilação JIT** e tem um orçamento de retrocesso. Um padrão que \
                explode de forma combinatória é parado e comunicado, em vez de congelar a janela.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Expressões regulares",
        summary: "A sintaxe PCRE2 que se usa mesmo, com exemplos que correm sobre dados vietnamitas.",
        keywords: ["regex", "pcre", "padrão"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                O GEditor usa **PCRE2**, o mesmo motor do PHP e de muitas ferramentas de linha de \
                comandos. Abra `Procurar ▸ Testar expressão regular…` para experimentar um padrão sobre \
                texto de exemplo e ver o que cada grupo captura **antes** de o aplicar a um documento \
                real.
                """),
            .heading("Classes de caracteres"),
            .table(
                headers: ["Escreva", "Corresponde a"],
                rows: [
                    ["`.`", "Qualquer caractere exceto um fim de linha"],
                    ["`\\d` · `\\D`", "Um dígito · não um dígito"],
                    ["`\\w` · `\\W`", "Um caractere de palavra (letra, dígito, `_`) · o contrário"],
                    ["`\\s` · `\\S`", "Espaço em branco · não espaço"],
                    ["`[abc]`", "Um dos caracteres entre parênteses retos"],
                    ["`[^abc]`", "Um caractere que NÃO esteja entre parênteses retos"],
                    ["`[a-z]`", "Um caractere do intervalo"],
                ]
            ),
            .heading("Repetição"),
            .table(
                headers: ["Escreva", "Significado"],
                rows: [
                    ["`*`", "Zero ou mais"],
                    ["`+`", "Um ou mais"],
                    ["`?`", "Zero ou um"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Exatamente 3 · entre 2 e 5 · 2 ou mais"],
                    ["`*?` `+?` `??`", "As formas **preguiçosas** — apanhar o menos possível"],
                ]
            ),
            .warning("""
                `.*` é **guloso**: come até ao fim da linha e depois recua. Ao separar campos dentro de \
                uma linha precisa quase sempre de `.*?` ou de uma classe estreita como `[^,]*`.
                """),
            .heading("Âncoras e grupos"),
            .table(
                headers: ["Escreva", "Significado"],
                rows: [
                    ["`^` · `$`", "Início de linha · fim de linha"],
                    ["`\\b`", "Limite de palavra"],
                    ["`(…)`", "Um grupo **de captura** — reutilizável na substituição"],
                    ["`(?:…)`", "Grupo sem captura"],
                    ["`(?<name>…)`", "Grupo com nome"],
                    ["`a|b`", "a ou b"],
                    ["`(?=…)` · `(?!…)`", "Antecipação: tem de seguir · não pode seguir"],
                    ["`(?<=…)` · `(?<!…)`", "Retrospeção: tem de preceder · não pode preceder"],
                ]
            ),
            .heading("Exemplos que funcionam"),
            .code(language: "regex", caption: "Todo o número de telefone vietnamita de 10 dígitos",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Partir uma data 31/12/2026 em três grupos",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "A terceira célula de uma linha CSV simples (sem aspas)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Linhas de registo com ERROR ou FATAL, com a marca temporal",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Linhas vazias, ou só com espaços",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Letras vietnamitas acentuadas — use a classe Unicode, não as enumere",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` significa «qualquer letra Unicode», por isso também apanha `ế` e `đ`. Enumerar à \
                mão cada vogal acentuada é a forma garantida de esquecer alguma.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Cadeias de substituição",
        summary: "Reutilizar grupos capturados e mudar maiúsculas ao substituir.",
        keywords: ["substituir", "retrorreferência", "grupo", "$1", "\\U"],
        blocks: [
            .heading("Chamar um grupo capturado"),
            .table(
                headers: ["Escreva", "Significado"],
                rows: [
                    ["`$1` … `$9`", "O conteúdo do grupo n"],
                    ["`${1}`", "O mesmo com limites explícitos — use-o quando vier um dígito a seguir"],
                    ["`\\1`", "Também é aceite; o GEditor reescreve-o como `${1}`"],
                    ["`$0`", "A correspondência inteira"],
                ]
            ),
            .note("""
                Escreva `${1}` em vez de `$1` quando o caractere seguinte for um dígito. `$123` lê-se \
                como o grupo 123; `${1}23` é o grupo 1 seguido de dois dígitos.
                """),
            .heading("Mudar maiúsculas durante uma substituição"),
            .table(
                headers: ["Escreva", "Significado"],
                rows: [
                    ["`\\U`", "MAIÚSCULAS a partir daqui"],
                    ["`\\L`", "minúsculas a partir daqui"],
                    ["`\\u`", "Só o caractere seguinte em maiúscula"],
                    ["`\\l`", "Só o caractere seguinte em minúscula"],
                    ["`\\E`", "Fim da região `\\U` ou `\\L`"],
                ]
            ),
            .heading("Exemplos"),
            .code(language: "text", caption: "Transformar 31/12/2026 em 2026-12-31",
                  source: """
                    Procurar:  (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Substituir: $3-$2-$1
                    """),
            .code(language: "text", caption: "Pôr em maiúsculas o código de província no início da linha, manter o resto",
                  source: """
                    Procurar:  ^([a-z]{2,3})(\\s)
                    Substituir: \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Envolver cada linha como cadeia JSON",
                  source: """
                    Procurar:  ^(.+)$
                    Substituir: "$1",
                    """),
            .paragraph("""
                Um grupo que **não participou** na correspondência torna-se uma cadeia vazia, não um \
                erro — assim um padrão com alternativas como `(a)|(b)` substitui limpamente sem o \
                escrever duas vezes.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Procurar e substituir numa pasta",
        summary: "Percorrer muitos ficheiros ao mesmo tempo e ver os resultados antes de escrever seja o que for.",
        keywords: ["procurar em ficheiros", "grep", "substituição em massa", "pasta"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Procurar numa pasta")]),
            .paragraph("""
                Escolha a pasta raiz, filtre por padrão de nome e percorra. Os resultados aparecem \
                agrupados por ficheiro; carregar numa linha abre esse ficheiro nessa posição.
                """),
            .bullets([
                "Os mesmos três modos de procura e o mesmo motor de regex do campo de procura no documento.",
                "A substituição numa pasta **pré-visualiza** quantos ficheiros e quantas ocorrências vão mudar antes de escrever.",
                "A varredura corre em paralelo e **pode ser cancelada** a meio.",
            ]),
            .warning("""
                A substituição numa pasta escreve diretamente em ficheiros que **não estão abertos**. \
                Esses ficheiros não estão no histórico de desfazer do documento aberto — pré-visualize \
                primeiro e tenha uma cópia de segurança ou um repositório com versões.
                """),
            .heading("Procuras anteriores e exportar resultados"),
            .paragraph("""
                O painel de resultados **guarda as procuras desta sessão**. O menu de cima lista-as com \
                a contagem de ocorrências — procure `TODO`, leia a meio, procure `FIXME` para comparar e \
                volte à primeira lista sem percorrer a pasta outra vez.
                """),
            .paragraph("""
                O botão **Exportar** abre a procura atual como separador de texto, um resultado por \
                linha no formato `caminho:linha:coluna: texto` — a forma que o `grep -n` usa e a que os \
                compiladores usam para os erros. Cada linha cola-se tal e qual no campo `Ir para` deste \
                próprio produto, e os seus `grep`, `awk` e `sed` leem-na sem analisador próprio.
                """),
            .note("""
                O histórico vive **em memória** e nunca é escrito em disco: os resultados de procura \
                levam o conteúdo de cada linha encontrada, que é a mesma classe de dados que o histórico \
                da área de transferência deliberadamente não guarda.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Marcas de linha",
        summary: "Nove cores de marca e quatro comandos que transformam as linhas marcadas num resultado.",
        keywords: ["marcador", "marca", "f2", "filtrar linhas"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Marcar é a forma de filtrar um documento **sem o alterar**. Marque cada linha que \
                corresponda a um padrão e depois copie só essas, ou fique só com elas.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Marcar cada linha que corresponda à procura atual"),
                HelpShortcut("⌘F2", "Marcar / desmarcar a linha atual"),
                HelpShortcut("F2 / ⇧F2", "Ir para a marca seguinte / anterior"),
            ]),
            .heading("Um fluxo habitual"),
            .steps([
                "`⌘F` com o padrão por que quer filtrar, p. ex. `\\bERROR\\b`.",
                "`⌘M` marca cada linha correspondente.",
                "`Procurar ▸ Copiar linhas marcadas` leva-as para um separador novo — ou `Manter só as linhas marcadas` filtra no lugar.",
            ]),
            .heading("Nove cores"),
            .paragraph("""
                Uma linha pode levar **várias cores ao mesmo tempo**. Use cores diferentes para critérios \
                diferentes e combine-as: vermelho para linhas de erro, amarelo para linhas de um mesmo \
                número de encomenda, e depois procure as linhas que levem ambas.
                """),
            .bullets([
                "`Inverter marcas` — as linhas marcadas passam a não marcadas e vice-versa.",
                "`Limpar todas as marcas` — retira cada marca sem tocar no conteúdo.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Ir para a linha",
        summary: "Saltar para uma linha, uma coluna ou uma posição em bytes.",
        keywords: ["ir para", "número de linha", "cmd+l", "posição", "coluna"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Ir para a linha")]),
            .paragraph("""
                O campo percebe **três notações** e distingue-as pelo que escreve — não há nenhum \
                seletor extra para carregar.
                """),
            .table(
                headers: ["Escreva", "Vai para"],
                rows: [
                    ["`120`", "o início da linha 120"],
                    ["`120,5` ou `120:5`", "linha 120, coluna 5 — a coluna conta CARACTERES"],
                    ["`@1024`", "a posição 1024 em bytes do ficheiro"],
                ]
            ),
            .note("""
                `linha:coluna` é exatamente como os compiladores e os linters imprimem uma posição, por \
                isso uma linha acabada de copiar de um terminal cola-se tal e qual.

                O `@` das posições em bytes tem uma razão: `1234` é uma linha ou um byte? Não há resposta \
                certa, e adivinhar mal manda o cursor para outro sítio sem sinal nenhum. Esse número em \
                bytes é também o que a barra de estado mostra no segmento de posição (`@1024`): o que lê \
                ali pode escrever aqui.
                """),
            .bullets([
                "Uma coluna **para além do comprimento da linha** para no fim dessa linha; não transborda para a seguinte.",
                "Uma posição em bytes **para além do ficheiro** leva-o ao fim — esse número vem normalmente de uma execução anterior, e o ficheiro pode ter encolhido.",
                "O texto que não consegue ler é **comunicado**, e o cursor fica onde está; não salta para o início do ficheiro.",
            ]),
            .paragraph("""
                Em ficheiros muito grandes o GEditor não lê o ficheiro todo para lá chegar — o índice de \
                linhas é construído aos poucos em segundo plano.
                """),
            .note("""
                A ferramenta de linha de comandos também aceita uma posição: `geditor \
                relatorio.csv:120:5` abre o ficheiro com o cursor na linha 120, coluna 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Ficheiros e sessões

    static let files = HelpChapter(
        id: "tep",
        title: "Ficheiros e sessões",
        summary: "Abrir, guardar, separadores, janelas, espaços de trabalho e como a sessão volta.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Abrir e guardar",
        summary: "Abrir um ficheiro de qualquer tamanho e guardá-lo com outra codificação ou fim de linha.",
        keywords: ["abrir", "guardar", "duplicar", "mudar o nome", "mover"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Documento novo"),
                HelpShortcut("⌘O", "Abrir um ficheiro"),
                HelpShortcut("⌘S", "Guardar"),
                HelpShortcut("⇧⌘S", "Guardar como"),
            ]),
            .paragraph("""
                Arrastar um ficheiro para a janela também o abre. `Ficheiro ▸ Abrir recente` guarda a \
                lista dos ficheiros em que esteve a trabalhar.
                """),
            .heading("Guardar como: três coisas que pode mudar"),
            .table(
                headers: ["Mudança", "Significado"],
                rows: [
                    ["Codificação", "Escrever em UTF-8, TCVN3, VNI-Windows… — 36 codificações"],
                    ["Fins de linha", "LF (Unix) · CRLF (Windows) · CR (Mac clássico)"],
                    ["Nome e local", "Como em qualquer caixa de gravação do macOS"],
                ]
            ),
            .paragraph("""
                A barra de estado mostra sempre a codificação, o estilo de fim de linha e a linguagem \
                detetada. **Carregar em qualquer um deles muda-o de imediato**, sem passar por uma \
                caixa de diálogo.
                """),
            .heading("Duplicar · mudar o nome · mover"),
            .paragraph("""
                Estas três atuam sobre o FICHEIRO e não sobre o seu conteúdo — e o separador aberto segue \
                o ficheiro, por isso nunca perde o seu lugar.
                """),
            .table(
                headers: ["Comando", "O que faz"],
                rows: [
                    ["`Duplicar ficheiro`",
                     "Copia-o como `nome 2.txt` ao lado do original e **abre a cópia** — porque se duplica para editar a cópia"],
                    ["`Mudar o nome do ficheiro…`", "Muda o nome no disco; o separador segue o nome novo"],
                    ["`Mover ficheiro para…`", "Move para outra pasta; o separador segue"],
                ]
            ),
            .note("""
                As três **recusam se já existir um ficheiro com esse nome** no destino; nunca \
                sobrescrevem. E as três precisam de um ficheiro guardado pelo menos uma vez — um \
                documento que nunca esteve no disco não tem nada para duplicar nem mover.
                """),
            .heading("Escrita segura"),
            .bullets([
                "A escrita é **atómica**: uma falha de energia a meio nunca deixa um ficheiro truncado.",
                "Se outro programa alterar o ficheiro enquanto o tem aberto, o GEditor repara e pergunta antes de sobrescrever.",
                "Os ficheiros no iCloud Drive ou num volume de rede passam pelo coordenador de ficheiros do sistema, para que duas máquinas não se atropelem.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Separadores, janelas e vista dividida",
        summary: "Muitos separadores por janela, muitas janelas e separadores que se arrastam entre elas.",
        keywords: ["separador", "janela", "dividir", "painel"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Novo separador"),
                HelpShortcut("⌘W", "Fechar separador"),
                HelpShortcut("⇧⌘T", "Voltar a abrir o último separador fechado"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Separador seguinte / anterior"),
                HelpShortcut("⌥⌘N", "Janela nova"),
                HelpShortcut("⌃⌘N", "Separar o separador atual para a sua própria janela"),
            ]),
            .paragraph("""
                Pode arrastar um separador para outra janela, ou largá-lo em espaço vazio para criar uma \
                janela. **Um separador fixado não viaja** — fixar quer dizer «deixa este aqui».
                """),
            .note("""
                `⇧⌘T` volta a abrir o último separador fechado, incluindo um **não guardado**: o conteúdo \
                continua lá.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Abrir uma pasta como espaço de trabalho",
        summary: "Uma árvore de ficheiros na barra lateral, procura em todo o projeto e abertura com um clique.",
        keywords: ["espaço de trabalho", "pasta", "projeto", "barra lateral"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Abrir uma pasta como espaço de trabalho")]),
            .paragraph("""
                A árvore aparece na barra lateral (`⌘0`). Carregue num ficheiro para o abrir, e `⇧⌘F` \
                procura na pasta toda.
                """),
            .note("""
                Na versão da App Store, o acesso à pasta é mantido por um **marcador de âmbito de \
                segurança**, por isso o arranque seguinte ainda lá chega sem lhe pedir para escolher a \
                pasta outra vez.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "A sessão restaura-se sozinha",
        summary: "Saia e volte a abrir: cada separador regressa, incluindo os não guardados.",
        keywords: ["sessão", "restaurar", "não guardado", "recuperar"],
        blocks: [
            .paragraph("""
                Nada a ligar. Saia do GEditor e abra-o outra vez: os separadores, a sua ordem, as \
                posições do cursor e do deslocamento voltam todas.
                """),
            .heading("E os separadores não guardados"),
            .paragraph("""
                O seu conteúdo fica numa cópia à parte, por isso também voltam. Se a aplicação terminar \
                de forma anormal, o arranque seguinte **pergunta** antes de restaurar rascunhos órfãos — \
                em vez de reconstruir em silêncio um monte de separadores de que não se lembra.
                """),
            .warning("""
                Uma sessão **não é uma cópia de segurança**. Guarda o estado de trabalho, não o \
                histórico. Tudo o que importa continua a ter de ser guardado num ficheiro.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Versões guardadas anteriormente",
        summary: "Ver e restaurar versões antigas de um ficheiro.",
        keywords: ["versões", "histórico", "restaurar", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                A cada gravação, o GEditor regista a versão **anterior** antes de sobrescrever. `Macro ▸ \
                Versões guardadas…` abre o navegador delas.
                """),
            .bullets([
                "O arquivo de versões é o do **sistema operativo**, o mesmo mecanismo que as apps da Apple usam.",
                "Restaurar uma versão antiga é uma **edição vulgar** — `⌘Z` desfá-la.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Seguir um ficheiro que ainda está a ser escrito",
        summary: "Como o `tail -f`: o que for acrescentado aparece à medida que chega.",
        keywords: ["tail", "seguir", "registo", "tempo real"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Ficheiro ▸ Seguir ficheiro (tail -f)` carrega o que aparece no fim do ficheiro e \
                desliza com ele.
                """),
            .warning("""
                Enquanto segue, o documento fica **só de leitura**. Escrever enquanto texto novo está a \
                ser carregado do disco são dois escritores a disputar um documento, e o perdedor é \
                sempre o que acabou de escrever.
                """),
            .note("""
                A barra de estado diz **A seguir** o tempo todo, por isso minutos depois ainda sabe \
                porque é que o ficheiro não aceita escrita. Carregar no segmento **só de leitura** dá a \
                razão sem rodeios.

                O seguimento pertence ao **separador que o iniciou**, não à janela: abra outro separador \
                e continue a escrever, e as linhas novas de registo continuam a fluir para o seu próprio \
                separador sem tocar no ficheiro que está a editar.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Imprimir",
        summary: "Imprimir pela caixa de impressão padrão do macOS.",
        keywords: ["imprimir", "papel", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Imprimir")]),
            .paragraph("""
                Usa a caixa de impressão do sistema, por isso exportar para PDF também acontece aí — o \
                botão `PDF` em baixo à esquerda.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Imagens, PDF, ficheiros Office, áudio, vídeo e arquivos",
        summary: "Oito tipos de ficheiro abrem-se dentro do GEditor sem outra aplicação.",
        keywords: ["imagem", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "arquivo",
                   "áudio", "vídeo"],
        blocks: [
            .table(
                headers: ["Tipo", "O que pode fazer"],
                rows: [
                    ["Imagens", "Ver, ampliar, rodar; **as imagens animadas reproduzem-se** e podem ser pausadas"],
                    ["Áudio", "Reproduzir, avançar, mudar o volume"],
                    ["Vídeo", "Reproduzir, avançar, ecrã inteiro, imagem sobre imagem"],
                    ["PDF", "Ler, procurar, **anotar**"],
                    ["Word · Excel · PowerPoint", "Ver **e editar** — `⌘S` escreve diretamente de volta no ficheiro"],
                    ["ZIP · TAR · GZ · XZ", "Listar entradas e abrir cada uma como separador"],
                    ["7z · RAR e mais sete formatos", "O mesmo, através do libarchive"],
                ]
            ),
            .paragraph("""
                Abrir uma entrada de um arquivo cria um separador com o seu conteúdo. Os acentos \
                vietnamitas sobrevivem tanto nos nomes como no conteúdo.
                """),
            .note("""
                Edite um dos três formatos do Office, carregue em `⌘S`, e é escrito de volta no ficheiro \
                — o LibreOffice lê o resultado. Este caminho está testado de ponta a ponta, não apenas \
                exportado para uma cópia.
                """),
            .heading("O áudio e o vídeo usam os leitores do macOS"),
            .paragraph("""
                A reprodução passa pelos descodificadores do sistema, por isso nada de extra é \
                transferido nem incluído. Em troca, alguns formatos **não vão reproduzir** — `.mkv`, \
                `.webm`, `.avi`, `.wmv` — porque o macOS não traz descodificador para eles.
                """),
            .paragraph("""
                Para um ficheiro assim o GEditor **diz porquê** em vez de mostrar um retângulo preto, e \
                oferece o visualizador binário ou outra aplicação.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Ferramentas de PDF",
        summary: "Ler, anotar e toda uma camada de páginas: rodar · mover · apagar · extrair · juntar.",
        keywords: ["pdf", "página", "rodar", "apagar página", "extrair", "juntar",
                   "anotar", "realçar", "assinar"],
        blocks: [
            .paragraph("""
                A vista de PDF tem **duas barras de ferramentas**, que respondem a perguntas diferentes. \
                A linha de cima atua sobre o **conteúdo** de uma página; a de baixo sobre o **conjunto \
                de páginas**.
                """),
            .heading("Linha de cima — ler e anotar"),
            .table(
                headers: ["Botão", "O que faz"],
                rows: [
                    ["Realçar · Sublinhar", "Marcar o texto selecionado"],
                    ["Nota…", "Anexar uma nota à página"],
                    ["Remover anotações", "Retirar toda a anotação da página atual"],
                    ["Extrair texto para um separador", "Levar todo o texto para um separador para procurar, filtrar, usar outras ferramentas"],
                    ["Campo de procura", "Procurar dentro do PDF — **escrever sem acentos encontra na mesma texto acentuado**"],
                ]
            ),
            .note("""
                Um PDF digitalizado não tem camada de texto. O comando de extração **di-lo** em vez de \
                abrir um separador vazio e deixá-lo adivinhar.
                """),
            .heading("Linha de baixo — operações de página"),
            .table(
                headers: ["Botão", "O que faz", "Reversível"],
                rows: [
                    ["Rodar à esquerda · direita", "Rodar a página atual 90°", "Sim"],
                    ["Página acima · abaixo", "Trocar a página atual com a vizinha", "Sim"],
                    ["Apagar páginas…", "Apagar por intervalo, p. ex. `2-4,7`", "Sim"],
                    ["Extrair páginas…", "Escrever um intervalo de páginas como **ficheiro novo**", "Não toca no ficheiro aberto"],
                    ["Juntar um PDF…", "Inserir outro PDF logo a seguir à página atual", "Sim"],
                    ["Assinar…", "Colocar uma imagem de assinatura na página atual", "Sim"],
                    ["Editar texto…", "Desenhar texto de substituição sobre a seleção", "Sim"],
                    ["Campo vazio seguinte", "Ir para o campo de formulário seguinte por preencher", "—"],
                    ["Limpar valores preenchidos", "Esvaziar todos os campos de formulário", "Sim"],
                    ["Desfazer alteração de página", "Recuar uma operação de página", "—"],
                    ["Guardar a cópia editada…", "Escrever um ficheiro novo e depois **voltar a abri-lo para verificar**", "—"],
                ]
            ),
            .heading("Formulários preenchíveis"),
            .paragraph("""
                Abra um PDF com campos de formulário e a barra de estado diz **quantos** existem. Escreva \
                diretamente nos campos da página e depois `Guardar a cópia editada…`.
                """),
            .bullets([
                "Os valores ficam guardados como **campos de formulário vivos**, não como texto achatado — assim o Acrobat do destinatário continua a ver um formulário preenchido e pode corrigi-lo.",
                "Os acentos vietnamitas sobrevivem ao ciclo escrever-e-reabrir. Um teste vigia exatamente isso, com o nome `Nguyễn Văn Anh`.",
                "`Campo vazio seguinte` salta para o próximo em branco — o caminho natural por um formulário longo.",
            ]),
            .heading("Assinar"),
            .paragraph("""
                Prepare uma imagem de assinatura (um PNG com fundo transparente é o melhor), **selecione \
                o sítio onde assinar** — normalmente a linha ou a palavra «Assinatura» — e carregue em \
                `Assinar…`. Sem nada selecionado, a assinatura cai no canto inferior direito.
                """),
            .note("""
                A assinatura mantém a **proporção** da imagem: uma assinatura esmagada ou esticada parece \
                falsa de imediato.
                """),
            .heading("Editar texto — e três coisas a saber antes"),
            .paragraph("""
                Selecione o texto a mudar e carregue em `Editar texto…`. O GEditor **cobre essa área com \
                uma cor de fundo recolhida mesmo ao lado** e desenha o texto novo por cima.
                """),
            .warning("""
                **O texto antigo fica COBERTO, não REMOVIDO.** Continua no ficheiro e continua \
                extraível com `Extrair texto para um separador` ou qualquer outra ferramenta. Isto **não \
                é censura**: esconder assim um número de identificação esconde-o do olho humano, não de \
                uma máquina.
                """),
            .bullets([
                "**O texto novo continua a ser encontrável com `⌘F`.** É desenhado como texto a sério, não como imagem — medido por um teste, não presumido.",
                "**A letra é uma do sistema**, não a original do documento. De propósito: as letras embutidas num PDF muitas vezes não têm acentos vietnamitas, e `Nguyễn` chegaria como `Nguy?n`.",
                "**Sobre um fundo com padrão o remendo vê-se** — a cor de cobertura é recolhida num único ponto mesmo à esquerda da seleção.",
            ]),
            .heading("Porquê desenhar por cima em vez de editar o fluxo de conteúdo"),
            .paragraph("""
                Editar diretamente o fluxo de conteúdo de um PDF significa lidar com letras em \
                subconjunto que trazem a sua própria codificação, frases partidas em três fragmentos pelo \
                espacejamento e tabelas de largura de caracteres que é preciso recalcular. Fazê-lo bem \
                para **todos** os ficheiros é um projeto por si só; fazê-lo mal corrompe o documento de \
                alguém.
                """),
            .paragraph("""
                Em troca, o resto da página **não muda um único byte**, e a página continua a ser uma \
                página — o texto continua a selecionar-se, a copiar-se e a procurar-se. Redesenhar **não** \
                a transforma numa imagem.
                """),
            .heading("Sintaxe dos intervalos de páginas"),
            .table(
                headers: ["Escreva", "Significado"],
                rows: [
                    ["`5`", "Só a página 5"],
                    ["`2-4`", "Páginas 2, 3, 4"],
                    ["`-3`", "Do início até à página 3"],
                    ["`8-`", "Da página 8 até ao fim"],
                    ["`1-3,5,9-`", "Várias partes unidas por vírgulas"],
                ]
            ),
            .paragraph("As páginas contam-se **a partir de 1**, o número que vê no ecrã."),
            .warning("""
                Um intervalo invertido (`5-2`) e um para além do fim (`1-999`) são ambos **recusados com \
                uma razão**, nunca corrigidos em silêncio para algo parecido. Num comando de apagar \
                páginas, adivinhar mal significa perder páginas, e aparar em silêncio transforma uma gralha \
                num comando válido.
                """),
            .heading("O ficheiro original nunca é sobrescrito"),
            .paragraph("""
                Tudo o que está acima altera o documento **em memória**. Só quando carrega em `Guardar a \
                cópia editada…` e escolhe um local é que se escreve um ficheiro — e depois de escrever, o \
                GEditor **volta a abrir esse mesmo ficheiro** para confirmar que ainda tem todas as \
                páginas.
                """),
            .paragraph("""
                A razão: um ficheiro mal escrito fica no disco com um aspeto perfeitamente normal, e o \
                utilizador só se apercebe depois de o enviar.
                """),
            .note("""
                A linha de estado da vista diz **· editado, não guardado** sempre que o documento difere \
                do ficheiro em disco.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
