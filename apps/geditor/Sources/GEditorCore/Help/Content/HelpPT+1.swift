import Foundation

/// Conteúdo de ajuda em português — parte 1: primeiros passos e edição.
///
/// **Os `id` de tópico NUNCA são traduzidos.** É para eles que `.seeAlso` aponta, é eles que o menu
/// abre, e são eles que permitem à janela de ajuda mudar de idioma **sem devolver o leitor ao
/// índice**. Alterar um id quebra todas as ligações, em todos os livros ao mesmo tempo.
///
/// Os títulos de menu em `commands:` continuam em vietnamita: têm de corresponder palavra por
/// palavra às etiquetas reais do menu, que `HelpCoverage` confere por essa mesma cadeia.
enum HelpPT {}

extension HelpPT {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Primeiros passos",
        summary: "O que o GEditor faz e onde investir os seus primeiros cinco minutos.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "O que é o GEditor",
        summary: "Um editor de texto e dados à escala do gigabyte para macOS que fala vietnamita.",
        keywords: ["introdução", "bem-vindo", "visão geral", "acerca"],
        blocks: [
            .paragraph("""
                O GEditor abre um **ficheiro de 1 GB sem carregar 1 GB para a memória**. Lê através de \
                uma janela deslizante sobre um ficheiro mapeado em memória, por isso um registo de 200 \
                milhões de linhas ou um CSV de um milhão de linhas abre-se em cerca de um segundo e \
                desliza sem falhas.
                """),
            .paragraph("""
                Além de editar, é uma **bancada para dados**: ver um CSV como tabela, limpá-lo, \
                pontuar a sua qualidade, consultá-lo com SQL, procurar anomalias e tendências e depois \
                gerar um relatório. E lê as codificações vietnamitas antigas que a maioria das \
                ferramentas de hoje já esqueceu.
                """),
            .heading("Seis coisas que vale a pena experimentar primeiro"),
            .table(
                headers: ["Tarefa", "Onde ir"],
                rows: [
                    ["Abrir um ficheiro grande sem esperar", "Arraste-o para a janela — veja «Abrir ficheiros grandes»"],
                    ["Editar muitos sítios ao mesmo tempo", "`⌘D` acrescenta a ocorrência seguinte; depois escreva uma só vez"],
                    ["Procurar com uma expressão regular", "`⌘F`, ligue Regex — o motor é PCRE2 com JIT"],
                    ["Ver um CSV como tabela", "`⌥⌘T` — um milhão de linhas continua a deslizar sem falhas"],
                    ["Limpar uma tabela de dados desarrumada", "`⇧⌘L` bancada de limpeza — pré-visualização antes de aplicar"],
                    ["Abrir um ficheiro vietnamita que aparece como lixo", "Carregue na codificação na barra de estado"],
                ]
            ),
            .note("""
                Vem do Notepad++? Há uma página que compara os dois mapas de teclas, porque algumas \
                teclas **trocam de lugar** no macOS em vez de simplesmente trocar `Ctrl` por `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Os seus primeiros cinco minutos",
        summary: "Doze atalhos cobrem a maior parte do trabalho diário.",
        keywords: ["atalho", "teclas", "início", "básico"],
        blocks: [
            .paragraph("""
                Não precisa de aprender tudo. As doze teclas abaixo cobrem a maior parte do trabalho \
                diário; o resto consulta quando precisar.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Abrir um ficheiro"),
                HelpShortcut("⇧⌘O", "Abrir uma pasta inteira como espaço de trabalho"),
                HelpShortcut("⌘T", "Novo separador"),
                HelpShortcut("⌘S", "Guardar"),
                HelpShortcut("⌘F", "Procurar"),
                HelpShortcut("⌥⌘F", "Procurar e substituir"),
                HelpShortcut("⇧⌘F", "Procurar numa pasta"),
                HelpShortcut("⌘D", "Juntar a ocorrência seguinte à seleção"),
                HelpShortcut("⌘L", "Ir para a linha"),
                HelpShortcut("⌘/", "Comentar a linha com a sintaxe da própria linguagem"),
                HelpShortcut("⌥⌘T", "Alternar entre tabela e texto (ficheiros CSV)"),
                HelpShortcut("⌘?", "Voltar a abrir esta janela de ajuda"),
            ]),
            .heading("Três coisas que surpreendem quem chega"),
            .bullets([
                "**Uma operação em massa é UM passo de desfazer**, mesmo que toque num milhão de linhas. Ordenou mal? Um `⌘Z` e desaparece.",
                "**A sessão restaura-se sozinha.** Saia e volte a abrir: os separadores voltam ao lugar, mesmo os não guardados. Nada a carregar.",
                "**Escrever sem acentos encontra na mesma palavras acentuadas** em cada campo de procura e filtro — escreva `hue` e obtém `Huế`, `da nang` e obtém `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "O que está a tentar fazer?",
        summary: "Uma tabela que vai de tarefas reais ao capítulo que as trata.",
        keywords: ["índice", "procurar", "como fazer"],
        blocks: [
            .paragraph("""
                O índice à esquerda está ordenado por **função**. Esta tabela está ordenada por \
                **tarefa**, porque as duas ordens não coincidem.
                """),
            .table(
                headers: ["Preciso de…", "Veja"],
                rows: [
                    ["Editar o mesmo ponto em centenas de linhas", "Cursores múltiplos · Seleção em bloco"],
                    ["Reformatar em massa com uma regex", "Procurar e substituir · Expressões regulares"],
                    ["Repetir uma sequência de ações", "Macros"],
                    ["Abrir um CSV que me enviaram", "A tabela CSV"],
                    ["Limpar uma tabela desarrumada: datas misturadas, números como texto", "O fluxo de limpeza de dados"],
                    ["Avaliar se uma tabela é de confiança", "Pontuação de qualidade dos dados"],
                    ["Encontrar anomalias, tendências, grupos", "O fluxo de mineração de dados"],
                    ["Fazer perguntas em SQL", "Consultar CSV com SQL"],
                    ["Publicar um relatório cujos números se atualizem", "Relatórios `.greport.md`"],
                    ["Desenhar um diagrama dentro de um documento", "Mermaid"],
                    ["Abrir um ficheiro vietnamita ilegível", "Codificações vietnamitas"],
                    ["Automatizar a partir da consola ou do AppleScript", "Automatização"],
                    ["Colorir um formato inventado pela minha empresa", "Linguagens definidas pelo utilizador"],
                ]
            ),
            .note("""
                Não está na lista? O campo de procura no canto superior esquerdo olha para dentro do \
                **texto e dos exemplos de código**, por isso escrever uma chave de configuração como \
                `fail_under` leva à página certa.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Abrir ficheiros grandes",
        summary: "Porque é que 1 GB chega a abrir, e onde o GEditor recusa de propósito em vez de adivinhar.",
        keywords: ["ficheiro grande", "gigabyte", "registo", "mmap", "lento", "desempenho"],
        blocks: [
            .paragraph("""
                O ficheiro é **mapeado em memória** e lido através de uma janela deslizante; a parte que \
                está a editar vive numa piece table. Na prática: o tempo de abertura quase não depende \
                do tamanho do ficheiro, e a memória ocupada também não.
                """),
            .heading("Onde recusa de propósito"),
            .paragraph("""
                Alguns cálculos teriam de ler o ficheiro inteiro para uma única cadeia — precisamente o \
                que esta arquitetura evita. Aí, o GEditor **diz que não o faz** em vez de se arrastar em \
                silêncio ou de adivinhar:
                """),
            .table(
                headers: ["Operação", "Limite", "Para além dele"],
                rows: [
                    ["Emparelhar parênteses", "1 MB", "Recusa e di-lo — realçar o par errado é pior do que nenhum"],
                    ["Coluna visual na barra de estado", "200 KB", "Volta a contar bytes e marca-o com `~` para o significado ficar visível"],
                    ["Pré-visualização de Markdown", "4 MB", "Recusa e explica"],
                ]
            ),
            .warning("""
                Um número que parece igual mas significa outra coisa é o pior tipo de erro. É por isso \
                que uma coluna para além do limite se lê `~1234` e não `1234`.
                """),
            .heading("Dicas para ficheiros de registo"),
            .bullets([
                "`Ficheiro ▸ Seguir ficheiro (tail -f)` traz o que for escrito no fim. O documento fica **só de leitura** enquanto segue — escrever enquanto entra texto novo são dois escritores a disputar um documento, e o perdedor é sempre o que acabou de escrever.",
                "As linhas de registo são **coloridas por gravidade** e podem ser filtradas por nível.",
                "O **mapa do documento** (`⌥⌘M`) descreve o ficheiro inteiro, não só a parte no ecrã.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Versão da App Store e transferência direta",
        summary: "Três funcionalidades que só a versão direta tem, e porquê.",
        keywords: ["app store", "sandbox", "transferência", "cli", "extensão", "diferença"],
        blocks: [
            .paragraph("""
                O GEditor é publicado em duas versões. Vêm do **mesmo código-fonte** e a aplicação \
                reconhece ao arrancar qual delas é. A diferença está no que a App Sandbox permite.
                """),
            .table(
                headers: ["Funcionalidade", "App Store", "Transferência direta"],
                rows: [
                    ["Toda a edição, CSV, limpeza, mineração, relatórios", "Sim", "Sim"],
                    ["A ferramenta de linha de comandos `geditor`", "Não", "Sim"],
                    ["Filtrar texto por um comando externo", "Não", "Sim"],
                    ["Extensões nativas (processo à parte)", "Não", "Sim"],
                    ["Atualização automática", "Pela App Store", "Dentro da aplicação"],
                ]
            ),
            .paragraph("""
                Cada «Não» acima nasce da mesma regra: a sandbox **proíbe executar código fora da \
                aplicação**. Esse é o preço da distribuição pela App Store, não um descuido.
                """),
            .note("""
                Na versão da App Store esses comandos **ficam no menu** e explicam porque não estão \
                disponíveis, em vez de desaparecerem. Um item de menu em falta torna-se um pedido ao \
                suporte; uma resposta no lugar, não.
                """),
            .heading("Acesso a ficheiros na versão da App Store"),
            .paragraph("""
                A versão em sandbox só toca em ficheiros que você próprio abriu ou arrastou. O GEditor \
                guarda um **marcador de âmbito de segurança** para cada separador e para a pasta do \
                espaço de trabalho, por isso a sua sessão volta a abrir depois de sair sem voltar a \
                pedir autorização.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Edição

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Edição",
        summary: "Editar muitos sítios ao mesmo tempo, trabalhar com linhas e as regras escondidas que convém saber primeiro.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Cursores múltiplos",
        summary: "Selecionar cada sítio que corresponde, escrever uma vez, mudar todos.",
        keywords: ["multicursor", "cmd+d", "seleção múltipla"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Isto substitui a maioria dos momentos em que ia escrever uma expressão regular. \
                Selecione uma palavra, carregue em `⌘D` algumas vezes para recolher as ocorrências \
                seguintes e escreva — todos os sítios mudam ao mesmo tempo.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Juntar a ocorrência seguinte à seleção"),
                HelpShortcut("⌘ + clique", "Pôr outro cursor onde clicar"),
                HelpShortcut("Esc", "Largá-los todos, voltar a um cursor"),
                HelpShortcut("⌥ + arrastar", "Seleção em bloco (outra forma de obter muitos cursores)"),
            ]),
            .heading("Regras que convém saber"),
            .bullets([
                "Escrever, apagar e colar em muitos cursores é **um** passo de desfazer, não um por cursor.",
                "Os cursores sobrevivem ao movimento com as setas — o grupo todo desloca-se em conjunto.",
                "`⌘D` salta os sítios que já estão na seleção, por isso carregar de mais nunca empilha cursores uns sobre os outros.",
            ]),
            .note("""
                `⌘D` sobre uma palavra dentro de uma cadeia longa era lento antes. A deteção de limites \
                de palavra lê agora por lotes — cerca de **42× mais rápido** numa cadeia de 1 MB, o que \
                o torna utilizável em ficheiros de dados e não só em código-fonte.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Seleção em bloco de colunas",
        summary: "Selecionar um retângulo ao longo de muitas linhas — com o rato ou pelo teclado.",
        keywords: ["modo coluna", "bloco", "alt arrastar", "retângulo", "teclado", "setas"],
        blocks: [
            .paragraph("""
                Mantenha `⌥` e arraste para selecionar um **bloco retangular**. Escrever, apagar e colar \
                seguem o bloco. Colar um bloco num único cursor mantém o seu retângulo.
                """),
            .shortcuts([
                HelpShortcut("⌥ + arrastar", "Selecionar um bloco"),
                HelpShortcut("⌥⌘← →", "Alargar o bloco uma coluna para a esquerda/direita"),
                HelpShortcut("⌥⌘↑ ↓", "Estender o bloco uma linha para cima/baixo"),
            ]),
            .paragraph("""
                O caminho do teclado não é um remendo para o rato: selecionar um bloco de 40 linhas a \
                arrastar obriga a arrastar através de um deslocamento, enquanto `⌥⌘` + setas mantém a \
                precisão coluna a coluna. Carregar em **qualquer outra** tecla (ou escrever) termina o \
                bloco que estava a estender.
                """),
            .heading("Aqui as colunas são colunas VISUAIS"),
            .paragraph("""
                Uma tabulação expande-se até à paragem seguinte conforme a sua largura de tabulação, em \
                vez de contar como uma coluna. É isso que faz com que as linhas indentadas com \
                tabulações e com espaços **fiquem alinhadas como no ecrã**.
                """),
            .paragraph("O texto multibyte continua a ser uma coluna: `Nguyễn` ocupa seis colunas, não nove."),
            .table(
                headers: ["Situação", "O que o GEditor faz"],
                rows: [
                    ["A coluna de destino cai a meio de uma tabulação", "Encosta ao bordo mais próximo; em empate, para a esquerda"],
                    ["Uma linha é mais curta do que a coluna inicial", "Essa linha contribui com uma seleção vazia, e aceita na mesma o texto escrito"],
                    ["Colar um bloco num único cursor", "Mantém o retângulo e insere nas linhas de baixo"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Editor de colunas",
        summary: "Inserir texto, uma série de números ou de datas em cada linha de um bloco.",
        keywords: ["editor de colunas", "numeração", "sequência", "série"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Selecione um bloco de colunas e abra `Editar ▸ Editor de colunas…` (`⌥⌘C`). A caixa tem \
                **pré-visualização** antes de aplicar seja o que for.
                """),
            .table(
                headers: ["Modo", "Parâmetros", "Quando"],
                rows: [
                    ["Texto", "Uma cadeia fixa", "Juntar o mesmo prefixo/sufixo a cada linha"],
                    ["Série de números", "Início · passo · base 2·8·10·16 · zeros à esquerda", "Numerar linhas, gerar códigos"],
                    ["Série de datas", "Primeira data · passo em dias", "Produzir uma coluna de datas consecutivas"],
                ]
            ),
            .code(language: "text", caption: "Numeração com zeros à esquerda, início 1, passo 1",
                  source: """
                    Antes:            Depois (série de números, 3 dígitos):
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """),
            .bullets([
                "Um passo **negativo** é válido — contar para trás funciona.",
                "Inserir em 5000 linhas continua a ser **um** passo de desfazer.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Operações com linhas",
        summary: "Ordenar, eliminar duplicados, mover, juntar, dividir, duplicar, apagar.",
        keywords: ["ordenar", "duplicar", "juntar", "dividir", "mover linha"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                Com uma seleção, o comando atua sobre a seleção; sem ela, atua sobre o **documento \
                inteiro**. Cada comando daqui é um único passo de desfazer.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Duplicar a linha"),
                HelpShortcut("⌘K", "Apagar a linha"),
                HelpShortcut("⌥↑ / ⌥↓", "Mover a linha para cima / baixo"),
            ]),
            .heading("Três tipos de ordenação, e qual escolher"),
            .table(
                headers: ["Tipo", "`file2` vs `file10`", "Para"],
                rows: [
                    ["A→Z / Z→A", "`file10` vem antes de `file2`", "Listas simples de palavras"],
                    ["Natural", "`file2` vem antes de `file10`", "Nomes de ficheiro, identificadores, versões"],
                ]
            ),
            .paragraph("""
                A ordenação **natural** lê as séries de dígitos como números. É quase sempre o que quer \
                quando a lista está numerada.
                """),
            .heading("Eliminar duplicados"),
            .bullets([
                "**Documento inteiro** — descarta toda a linha que já apareceu antes e mantém a primeira.",
                "**Só as adjacentes** — junta as linhas vizinhas iguais, como o `uniq` do Unix.",
            ]),
            .heading("Juntar e dividir"),
            .bullets([
                "**Juntar linhas** funde as linhas selecionadas numa só.",
                "**Dividir por comprimento** corta as linhas longas a um número dado de caracteres.",
                "**Dividir por caractere** corta em cada ocorrência de um caractere que escreva — por exemplo, para partir uma linha CSV nas suas células.",
            ]),
            .note("""
                Duplicar a **última linha** de um ficheiro acrescenta o fim de linha em falta; apagar até \
                ao fim do documento engole também o fim de linha da linha anterior. Ambos diferem da \
                implementação ingénua, e ambos existem para que o ficheiro não acabe com uma linha em \
                branco a mais — nem sem a que era precisa.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Espaços e indentação",
        summary: "Limpar espaços perdidos, converter tabulação ↔ espaço, e um interruptor que dá que pensar.",
        keywords: ["espaços", "tabulação", "indentação", "linhas em branco"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Comando", "O que faz"],
                rows: [
                    ["Remover linhas em branco", "Descarta toda a linha sem nada"],
                    ["Compactar linhas em branco seguidas", "Várias linhas em branco seguidas ficam numa"],
                    ["Cortar espaços no fim da linha", "Remove espaços e tabulações perdidos no fim de cada linha"],
                    ["Tabulação → Espaço", "Converte tabulações em espaços à largura atual"],
                    ["Espaço → Tabulação", "O sentido inverso"],
                ]
            ),
            .heading("Indentação por linguagem"),
            .paragraph("""
                Carregue em `Tab: 4` na barra de estado. A parte de cima do menu muda-a para a \
                **aplicação toda**; a de baixo — `Só para Go`, `Só para Python`… — aplica-se apenas à \
                linguagem do ficheiro aberto e lembra-se se usar tabulações ou espaços.
                """),
            .paragraph("""
                As pessoas não escolhem a indentação por gosto, mas por **convenção da comunidade**: Go \
                usa tabulações (`gofmt` manda sobre tudo o resto), Python quatro espaços segundo a PEP \
                8, JavaScript e YAML normalmente dois. Um só número para todas as linguagens faz com \
                que cada ficheiro em que toque ganhe linhas que nunca editou.
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
                Declará-lo em `settings.json` também serve — a chave é o código da linguagem (`go`, \
                `python`, `javascript`…). As linguagens ausentes usam o `tabWidth` comum.
                """),
            .heading("Porque «cortar ao guardar» vem DESLIGADO"),
            .paragraph("""
                O interruptor `Ficheiro ▸ Cortar espaços finais ao guardar` edita **linhas em que nunca \
                tocou**. Ligado por omissão, uma correção de uma palavra no repositório de outra pessoa \
                torna-se um diff de mil linhas, e o revisor deixa de encontrar a mudança verdadeira.
                """),
            .paragraph("""
                Quando está ligado, o corte é um **passo de desfazer à parte** colocado antes da \
                escrita — um desfazer devolve o documento ao que era, sem perder o que acabou de \
                guardar.
                """),
            .heading("Indentação automática"),
            .bullets([
                "Uma linha nova herda a indentação da anterior, mais um nível depois de um símbolo de abertura — `{` nas linguagens de chavetas, `:` em Python e YAML.",
                "A medida é em **colunas visuais**, por isso os ficheiros que misturam tabulações e espaços continuam alinhados no ecrã.",
                "**Não** há regra de «escrever `}` reindenta a linha». Essa regra edita uma linha que já tinha terminado, e é o comportamento mais criticado de todos os editores que o têm.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Maiúsculas e convenções de nomes",
        summary: "Oito conversões, incluindo camelCase, snake_case e kebab-case.",
        keywords: ["maiúsculas", "minúsculas", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Aplica-se à seleção. Todas vivem no menu `Formato`."),
            .table(
                headers: ["Comando", "`tổng doanh thu` passa a"],
                rows: [
                    ["MAIÚSCULAS", "`TỔNG DOANH THU`"],
                    ["minúsculas", "`tổng doanh thu`"],
                    ["Maiúscula Em Cada Palavra", "`Tổng Doanh Thu`"],
                    ["Maiúscula de frase", "`Tổng doanh thu`"],
                    ["Inverter maiúsculas", "Vira cada caractere"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                As três últimas retiram os acentos vietnamitas, porque produzem **identificadores de \
                código** — onde as letras acentuadas normalmente não são permitidas.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Comentários e parênteses",
        summary: "⌘/ usa o marcador próprio de cada linguagem; ⌃⌘B salta para o parêntese correspondente.",
        keywords: ["comentário", "parêntese", "cmd+/", "emparelhar"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` escolhe o marcador de comentário **conforme a linguagem do documento**: `#` para \
                Python, `//` para Rust e C, `<!-- -->` para XML e HTML.
                """),
            .heading("O bloco todo vai no mesmo sentido"),
            .paragraph("""
                Se uma única linha do bloco continuar sem comentário, o comando comenta **tudo**. \
                Decidir linha a linha transformaria um bloco meio comentado num tabuleiro de xadrez. O \
                marcador é inserido na indentação menos profunda do bloco, por isso o bloco mantém a \
                forma.
                """),
            .heading("Saltar para o parêntese correspondente"),
            .bullets([
                "`⌃⌘B` salta para o parêntese que corresponde ao do cursor.",
                "Os parênteses dentro de **cadeias** ou de **comentários** não contam — um analisador leve distingue-os.",
                "Passado **1 MB**, o comando recusa e di-lo em vez de se ancorar a meio e adivinhar. Realçar o par errado é pior do que não realçar nenhum.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Desfazer e área de transferência",
        summary: "Histórico de desfazer ilimitado e uma área de transferência com várias posições.",
        keywords: ["desfazer", "refazer", "área de transferência", "colar", "histórico"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Desfazer / Refazer"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Cortar / Copiar / Colar"),
                HelpShortcut("⇧⌘V", "Histórico da área de transferência"),
            ]),
            .heading("Uma operação em massa é UM passo"),
            .paragraph("""
                Ordenar um milhão de linhas, substituir dez mil ocorrências, inserir em cinco mil linhas \
                com o editor de colunas — cada uma delas desfaz-se com **um** `⌘Z`.
                """),
            .paragraph("""
                O histórico de desfazer vive no próprio buffer de texto do GEditor e não no \
                `UndoManager` do sistema, precisamente por isso: o `UndoManager` conta teclas.
                """),
            .heading("Histórico da área de transferência"),
            .paragraph("""
                `⇧⌘V` abre uma lista do que copiou há pouco e cola a entrada que escolher. Útil quando \
                tem de alternar dois fragmentos em muitos sítios.
                """),
        ]
    )
}
