import Foundation

/// Conteúdo de ajuda em português — parte 3: formas de ver, vietnamita, linguagens e formatos.
extension HelpPT {

    static let views = HelpChapter(
        id: "xem",
        title: "Formas de ver um documento",
        summary: "Barra lateral, mapa, dobragem, vista dividida, mudança de linha, invisíveis, modos de cor.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Barra lateral e lista de funções",
        summary: "A árvore de ficheiros e a lista de funções do ficheiro aberto, na mesma coluna.",
        keywords: ["barra lateral", "lista de funções", "esquema", "árvore de ficheiros"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Mostrar / ocultar a barra lateral")]),
            .paragraph("""
                A lista de funções é construída a partir da **árvore sintática** da linguagem, por isso \
                segue a estrutura real em vez de a adivinhar pela indentação. Carregue numa entrada para \
                saltar para lá.
                """),
            .note("O campo de filtro da lista **encontra texto acentuado escrevendo sem acentos**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Mapa do documento",
        summary: "O ficheiro inteiro numa coluna estreita à direita — mesmo com centenas de MB.",
        keywords: ["minimapa", "mapa", "vista geral"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Mostrar / ocultar o mapa do documento")]),
            .paragraph("""
                O mapa descreve o **ficheiro inteiro**, não só o que está no ecrã. Arrastar sobre ele \
                salta para a região correspondente.
                """),
            .paragraph("""
                As ocorrências de procura e as linhas marcadas aparecem no mapa, por isso vê se estão \
                dispersas ou agrupadas antes de deslizar para lá.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Dobragem",
        summary: "Dobrar funções, blocos e listas por estrutura — ou dobrar o ficheiro todo até um nível.",
        keywords: ["dobrar", "code folding", "recolher"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Dobrar / desdobrar o bloco do cursor"),
                HelpShortcut("⌥⇧⌘←", "Dobrar tudo"),
                HelpShortcut("⌥⌘→", "Desdobrar tudo"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Dobrar o ficheiro todo até ao nível 1…8"),
            ]),
            .paragraph("""
                Nas linguagens com árvore sintática, a dobragem segue a **estrutura real**. Nos ficheiros \
                sem gramática, segue a indentação.
                """),
            .paragraph("""
                `Dobrar até ao nível` ganha o seu valor em JSON e YAML profundos: dobrar ao nível 2 põe a \
                forma do ficheiro todo num ecrã.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Vista dividida",
        summary: "Dois painéis lado a lado, para dois ficheiros — ou dois pontos do mesmo ficheiro.",
        keywords: ["dividir", "painéis", "comparar"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Dividir na vertical"),
                HelpShortcut("⌥⌘-", "Dividir na horizontal"),
                HelpShortcut("⌥⌘0", "Retirar a divisão"),
                HelpShortcut("⌥⌘]", "Abrir este separador no outro painel"),
                HelpShortcut("⌥⌘[", "Saltar para o outro painel"),
            ]),
            .paragraph("""
                Cada painel tem a sua própria barra de separadores. Abrir o **mesmo ficheiro** em ambos \
                os painéis é perfeitamente possível — deslizam de forma independente, o que facilita \
                comparar o início e o fim de um ficheiro.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Mudança de linha automática",
        summary: "Três modos: desligado, na margem da janela ou numa coluna fixa.",
        keywords: ["mudança de linha", "quebra suave"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Modo", "Uma linha longa"],
                rows: [
                    ["Desligado", "Desliza na horizontal"],
                    ["Na janela", "Muda de linha na margem da janela, seguindo o seu tamanho"],
                    ["Numa coluna", "Muda de linha na coluna que definir — 80 ou 100, digamos"],
                ]
            ),
            .paragraph("""
                A mudança de linha é uma **forma de olhar**, não uma edição: não é inserido nenhum fim de \
                linha e nunca entra no histórico de desfazer.
                """),
            .note("O caminho rápido é o segmento `Ngắt: …` da barra de estado."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Tamanho da letra",
        summary: "Ampliar entre 8 e 32 pt.",
        keywords: ["zoom", "tamanho", "maior", "menor"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Maior"),
                HelpShortcut("⌘-", "Menor"),
                HelpShortcut("⌃⌘0", "Voltar ao tamanho por omissão"),
            ]),
            .paragraph("""
                Limitado entre 8 e 32 pt. Isto também é uma **forma de olhar**: sem edição, nada no \
                histórico de desfazer. O tamanho por omissão vive em `Definições…`.
                """),
            .note("`⌘0` **não** é o tamanho por omissão — essa tecla mostra e oculta a barra lateral."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Mostrar caracteres invisíveis",
        summary: "Um grupo de cada vez, porque todos ao mesmo tempo costuma ser demasiado.",
        keywords: ["invisível", "espaços", "nbsp", "largura zero", "tabulação"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Mostrar / ocultar todos os caracteres invisíveis")]),
            .paragraph("""
                Quatro grupos ligam-se em separado, porque acendê-los todos de uma vez enterra o conteúdo \
                sob uma floresta de pontos.
                """),
            .table(
                headers: ["Grupo", "O que apanha"],
                rows: [
                    ["Espaços", "Espaços no fim da linha, indentação inconsistente"],
                    ["Tabulações", "Ficheiros que misturam tabulações com espaços"],
                    ["Fins de linha", "Ficheiros que misturam CRLF com LF"],
                    ["NBSP · largura zero · controlo", "Caracteres invisíveis do Word, da web, de folhas de cálculo"],
                ]
            ),
            .warning("""
                O último grupo é o que salva as pessoas. Um espaço inquebrável (NBSP) colado de uma página \
                web parece **exatamente** um espaço vulgar e, no entanto, faz falhar cada comparação de \
                cadeias e cada filtro — e não há forma de o ver sem este grupo ligado.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Modo CSV e modo Registo",
        summary: "Duas colorações que substituem o realce de sintaxe, para dois tipos de ficheiro de dados.",
        keywords: ["modo csv", "modo registo", "realce", "colunas", "nível"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Modo CSV"),
            .paragraph("""
                Dá a cada coluna a sua própria cor na vista de **texto**, para que veja que célula \
                escorregou uma coluna sem passar à tabela.
                """),
            .heading("Modo Registo"),
            .paragraph("""
                Colore pela **gravidade** que lê da linha: erros a vermelho, avisos a âmbar, enquanto \
                `debug` e `trace` são esbatidos — compõem a maior parte de um registo, e realçá-los esbate \
                justamente aquilo que procura.
                """),
            .paragraph("`Filtrar registo por nível…` esconde por completo os níveis de que não precisa."),
            .note("""
                Estes dois colorem **em vez do** realce de sintaxe, não por cima. Um registo não tem \
                sintaxe para colorir, e duas fontes de cor a escrever no mesmo intervalo de bytes não \
                deixam um vencedor previsível.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Vista binária",
        summary: "Uma tabela hexadecimal para qualquer ficheiro — incluindo um de 1 GB, que abre quase de imediato.",
        keywords: ["hex", "binário", "byte", "posição", "despejo"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Ver ▸ Vista binária` mostra cada byte como uma tabela de três colunas: **posição · hex · \
                texto**. Funciona com **qualquer** ficheiro do disco, não só com imagens ou vídeo.
                """),
            .table(
                headers: ["Coluna", "Conteúdo"],
                rows: [
                    ["Posição", "Posição do byte, em hexadecimal"],
                    ["Hex", "16 bytes por linha, separados depois do oitavo para contar melhor"],
                    ["Texto", "Bytes ASCII imprimíveis; tudo o resto é um `.`"],
                ]
            ),
            .note("""
                A coluna de texto **não descodifica UTF-8**. Uma letra vietnamita ocupa dois ou três \
                bytes, por isso mostrá-la desalinharia a coluna de texto face à hexadecimal — e esse \
                alinhamento é todo o sentido da coluna. Para ler texto acentuado, use a vista normal.
                """),
            .heading("Ficheiros grandes"),
            .paragraph("""
                O ficheiro está **mapeado em memória**, por isso abrir um de 1 GB em vista binária custa \
                só o que olhar. Medido na bateria de autotestes: **menos de um milissegundo**.
                """),
            .paragraph("""
                A vista mostra **uma janela de 4 MB** de cada vez, e a barra de cima diz em que intervalo \
                está. É um limite do desenhador de tabelas do sistema, não da leitura: 1 GB são 62,5 \
                milhões de linhas, e a partir de certo ponto as linhas começam a saltar ao deslizar — e \
                uma tabela hexadecimal que salta não serve de nada.
                """),
            .heading("Saltar para uma posição"),
            .table(
                headers: ["Escreva no campo de posição", "Significado"],
                rows: [
                    ["`1F400`", "Hexadecimal — o que vem por omissão"],
                    ["`0x1F400`", "O mesmo, com prefixo explícito"],
                    ["`#128000`", "Decimal, quando tem uma contagem de bytes e não uma posição hexadecimal"],
                ]
            ),
            .bullets([
                "`‹` e `›` vão para a janela anterior / seguinte.",
                "**Copiar as linhas selecionadas** copia exatamente o que vê — sem seleção, copia a janela toda.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Pré-visualização de Markdown",
        summary: "Mostrar Markdown como texto formatado — e dizer claramente o que não mostra.",
        keywords: ["markdown", "pré-visualização", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Desenhado com o suporte de Markdown do sistema: negrito, itálico, código, ligações, listas."),
            .warning("""
                **Sem tabelas e sem cor de sintaxe dentro dos blocos de código.** A janela de \
                pré-visualização di-lo ao fundo. Documentos com mais de **4 MB** são recusados.
                """),
            .paragraph("""
                Precisa de tabelas e gráficos num documento publicável? É para isso que servem os \
                relatórios `.greport.md`, não esta pré-visualização.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Dois modos: Vista e Código",
        summary: "Uma tecla alterna entre a forma desenhada e a fonte editável, para cada tipo de ficheiro.",
        keywords: ["vista", "código", "modo", "fonte", "desenhado", "pré-visualização"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Alternar entre Vista e Código")]),
            .paragraph("""
                O controlo está na **barra logo abaixo dos separadores** — no mesmo sítio para cada tipo \
                de ficheiro: um comutador `View | Code` e depois o nome do modo Vista desse ficheiro \
                («Páginas do documento», «Árvore chave-valor», «Diagrama»…). Um ficheiro com um só modo \
                esbate o comutador e a barra diz porquê. Na margem direita ficam os botões próprios de \
                cada tipo: `.xlsx` tem **Tabela** (editável, escrita diretamente de volta), `.pptx` tem \
                **Esquema**.
                """),
            .note("""
                **O Word e o PowerPoint comportam-se como um leitor de documentos.** O seu modo Vista \
                constrói páginas verdadeiras — letras, tamanhos e cores corretos, com imagens, tabelas, \
                cabeçalhos e rodapés com números de página. Uma página é **exatamente tão larga como a \
                moldura** e amplia-se. O Excel é uma exceção deliberada: a sua Vista é uma **folha de \
                cálculo editável**, porque uma folha de cálculo não tem tamanho de papel enquanto não for \
                impressa.
                """),
            .note("""
                Em troca, as páginas são **só de leitura** e mostram a **cópia em disco**: edite em Código \
                sem guardar e as páginas mostram a versão antiga — a barra di-lo, com um botão `Guardar e \
                voltar a desenhar`.
                """),
            .heading("Definições"),
            .bullets([
                "**Código** é a **fonte editável**. Num ficheiro de texto é o próprio texto. Num ficheiro binário — PDF, imagem, áudio, vídeo — não há fonte textual, por isso Código são os **bytes**, mostrados em hexadecimal.",
                "**Vista** é o que é **desenhado** a partir do Código. Pode ser mais bonito, mais curto ou executável — mas é sempre uma consequência, nunca o original.",
            ]),
            .paragraph("""
                Dizer de um PDF que *«este tipo não tem Código»* seria cómodo, mas falso: os bytes são \
                mesmo a sua fonte.
                """),
            .heading("Onde se edita"),
            .paragraph("""
                A edição acontece no **Código**. Há exatamente **duas exceções**, ambas porque editar na \
                Vista é muito mais natural: as **células da tabela CSV** e os **campos de formulário do \
                PDF**. Ambas escrevem diretamente na fonte, por isso não aparece uma segunda cópia com que \
                discutir.
                """),
            .heading("Por tipo de ficheiro"),
            .table(
                headers: ["Tipo de ficheiro", "Vista", "Código", "Editar em"],
                rows: [
                    ["CSV · TSV", "Tabela", "Texto cru", "**Ambos**"],
                    ["Excel `.xlsx`", "Tabela da folha aberta", "Essa folha como CSV", "**Ambos**"],
                    ["PDF", "Páginas desenhadas", "Binário", "**Ambos** — anotações, campos, páginas"],
                    ["Markdown `.md`", "Texto desenhado", "Fonte Markdown", "Código"],
                    ["Relatório `.greport.md`", "Relatório com consultas executadas e gráficos desenhados", "Fonte", "Código"],
                    ["JSON", "Árvore chave-valor, dobrável", "Fonte JSON", "Código"],
                    ["XML · HTML", "Árvore de etiquetas, dobrável", "Fonte XML", "Código"],
                    ["YAML", "Árvore chave-valor pela indentação", "Fonte YAML", "Código"],
                    ["Diagramas `.mmd` · `.dot`", "O diagrama desenhado, a ocupar o separador", "Fonte mermaid ou DOT", "Código"],
                    ["Word `.docx`", "Páginas de documento desenhadas", "Markdown extraído", "Código"],
                    ["PowerPoint `.pptx`", "Páginas de diapositivos desenhadas", "Esquema Markdown", "Código"],
                    ["Ficheiros de registo", "Coloridos por nível, filtráveis", "Texto cru", "Código"],
                    ["Imagens", "A imagem (as animadas reproduzem-se)", "Binário", "Só de leitura"],
                    ["Áudio · vídeo", "Um leitor", "Binário", "Só de leitura"],
                    ["Arquivos", "Lista de entradas", "Binário", "Só de leitura"],
                    ["Código-fonte, texto simples", "— nenhuma", "O próprio texto", "Código"],
                ]
            ),
            .note("""
                O código-fonte **não tem Vista**, e isso é normal e não uma falta: um ficheiro Swift não \
                tem forma desenhada que valha a pena olhar.
                """),
            .heading("O leitor de páginas para Word e PowerPoint"),
            .paragraph("""
                As páginas empilham-se na vertical e deslizam de forma contínua, cada uma uma folha branca \
                sobre fundo cinzento — como em todos os leitores de documentos. Os seus controlos ficam à \
                direita da barra.
                """),
            .table(
                headers: ["Botão / tecla", "O que faz"],
                rows: [
                    ["`Ajustar à largura`", "A folha fica exatamente tão larga como a moldura — o que vem por omissão"],
                    ["`Ajustar à página`", "A folha inteira cabe na moldura"],
                    ["`−` `+`", "Ampliar por passos; ou beliscar, ou ⌘ + roda"],
                    ["O campo `Procurar`, ou ⌘F", "Procurar dentro das páginas, saltar para lá e realçar"],
                    ["Enter no campo de procura", "Ocorrência seguinte"],
                    ["Arrastar", "Selecionar texto; duplo clique para uma palavra, triplo para um parágrafo"],
                    ["⌘A · ⌘C", "Selecionar tudo · copiar a seleção"],
                    ["Page Up · Page Down · Home · End", "Andar pelo documento"],
                ]
            ),
            .paragraph("""
                O campo de procura **ignora acentos e maiúsculas**: escrever `vuong quoc` encontra `Vương \
                quốc`. A etiqueta «Página 12/363» na barra diz-lhe onde está.
                """),
            .note("""
                **O que não é desenhado, dito sem rodeios:** as imagens flutuantes ancoradas (texto a \
                contornar uma figura) aparecem como imagens em linha; as notas de rodapé, os gráficos e o \
                SmartArt do PowerPoint não são desenhados. Quando precisar de correspondência exata com a \
                cópia impressa, abra-o no Word.
                """),
            .heading("Carregar num nó volta à fonte"),
            .paragraph("""
                Uma árvore JSON não é uma impressão bonita: carregar num nó move o cursor **para o VALOR \
                desse nó** no texto e devolve o separador ao Código — porque o que quer a seguir é quase \
                sempre editar aquilo em que acabou de carregar.
                """),
            .bullets([
                "Os nós contentores mostram o seu **número de elementos** (`{12}`, `[340]`) em vez do conteúdo — é isso que responde a «vale a pena abrir?».",
                "Os **dois primeiros níveis** vêm abertos: abrir por completo um ficheiro de dez mil nós produz uma lista mais longa do que a fonte, enquanto fechá-lo todo obriga a carregar para descobrir seja o que for.",
                "Um ficheiro com **sintaxe inválida** não recebe meia árvore — uma árvore truncada parece um documento que simplesmente contém tão pouco.",
                "Numa árvore XML os atributos levam prefixo `@` em notação XPath, e **o espaço entre etiquetas não se torna nó** — é formatação, não conteúdo.",
                "Uma árvore YAML lê **ficheiros multidocumento** (`---`): cada documento tem a sua raiz. As coleções escritas em linha (`ports: [80, 443]`) continuam a ser uma folha — já vê tudo, e abrir custaria um clique. A **indentação com tabulações** é comunicada com a linha exata: é um erro de YAML que o olho não vê.",
                "O esquema do PowerPoint é construído a partir do **texto aberto**, não do ficheiro em disco: se acabou de editar o esquema no Código, a árvore tem de descrever a versão nova e os seus nós têm de saltar para essa versão nova. As notas do apresentador dobram-se num nó, para que um diapositivo falador não pareça um com muito conteúdo.",
                "**Um diagrama a ocupar o separador segue a mesma regra**: carregue num nó e volta ao Código com o cursor na sua declaração. No painel `Mermaid Studio` lado a lado o separador não fecha — o editor está mesmo ali, e basta mover o cursor para o ver.",
                "Os diagramas também **abrem onde está**: o elemento correspondente à linha do cursor fica realçado assim que o separador aparece, para não ter de o procurar.",
            ]),
            .heading("O campo de filtro: numa árvore de dez mil nós, procurar é o trabalho"),
            .paragraph("""
                Logo abaixo da contagem de nós há um campo de filtro. Escreva aí e a árvore mantém só os \
                nós correspondentes — **juntamente com o caminho da raiz até eles**, porque quando uma \
                chave `name` aparece em dez sítios a pergunta verdadeira é «qual», e só o ramo que a \
                contém responde. O resto é aberto por si: obrigá-lo a abrir cada nível a cliques é \
                obrigá-lo a filtrar outra vez à mão.
                """),
            .bullets([
                "Filtra por **etiquetas e valores**: procurar `Huế` é tão comum como procurar a chave `province`.",
                "**Escrever sem acentos continua a corresponder a texto acentuado** — `da nang` encontra `Đà Nẵng`. A mesma comparação do filtro da tabela CSV e da lista de funções, para não ter de decorar três regras de procura numa só aplicação.",
                "Sem correspondências, o cabeçalho diz **«Sem resultados»** em vez de o deixar a olhar para uma árvore vazia a perguntar-se se o ficheiro está estragado.",
                "Mudar de ficheiro ou voltar a entrar na Vista **limpa o filtro**: uma árvore que abre já truncada, sem nada a explicá-lo, é o estado mais confuso de todos.",
            ]),
            .heading("A árvore toda funciona com o teclado"),
            .paragraph("""
                Entrar na Vista põe o foco na árvore; não é preciso carregar nela primeiro. Cima e baixo \
                andam entre nós, esquerda e direita dobram e desdobram, e duas teclas terminam a sessão de \
                observação — fazendo coisas **diferentes**:
                """),
            .bullets([
                "**Enter** — ir para o nó selecionado: de volta ao Código com o cursor dentro do intervalo de bytes desse nó. Igual a carregar nele.",
                "**Tab** — andar entre a árvore e o campo de filtro.",
                "**⌘C** — copia o **caminho** do nó selecionado, não o texto por trás da árvore. JSON e YAML produzem JSONPath (`$.customer['name']`) que se cola tal e qual no campo de consulta JSONPath deste próprio produto, ou no `yq`; XML produz XPath (`/order/item[2]/@code`) com índices quando duas etiquetas partilham o nome; um esquema do PowerPoint copia o texto da linha, porque um esquema não tem linguagem de caminhos para inventar.",
                "**Esc** — o caminho de volta: voltar ao Código com o cursor **exatamente onde estava**. Estava a olhar para uma árvore, não a viajar para lado nenhum.",
            ]),
            .heading("E ao contrário: a árvore abre onde está o cursor"),
            .paragraph("""
                Entrar na Vista a meio de um ficheiro de dez mil linhas **não** abre a árvore no topo: abre \
                o caminho até ao nó correspondente ao sítio onde o cursor estava e seleciona-o. Esta é a \
                outra metade do salto para a fonte — sem ela, Vista e Código seriam dois olhares sobre um \
                documento em **apenas uma** direção.
                """),
            .bullets([
                "Abre **mais do que dois níveis** quando é preciso: a regra dos dois níveis responde a «como é este ficheiro», enquanto aqui a pergunta é outra — «onde estou nesta árvore».",
                "Um cursor sobre uma **chave** (`\"address\":`) seleciona essa entrada, mesmo que o intervalo de bytes do nó cubra só o valor. O texto imediatamente antes de um nó pertence a esse nó.",
                "Um cursor no **início de um bloco** — a chave de um bloco YAML, um título de diapositivo, um nome de etiqueta XML — seleciona esse bloco em vez de mergulhar no seu primeiro filho.",
                "Entrar na Vista **não move o cursor**. Saia da Vista e está exatamente onde estava; a Vista é uma forma de olhar, não um comando que mude de sítio.",
            ]),
            .heading("Já não falta Vista a nenhum tipo"),
            .paragraph("""
                **Todo o tipo de ficheiro com margem para um modo Vista desenha agora um.** A lista de \
                tipos em falta ficou vazia e foi removida.

                O código-fonte e o texto simples continuam sem Vista — isso é normal e não uma falta, por \
                isso nunca estiveram nessa lista.

                Se chegar um tipo de ficheiro novo cuja Vista ainda não esteja feita, o comando de alternar \
                di-lo e nomeia o que falta, em vez de abrir uma moldura vazia — uma moldura vazia é uma \
                promessa vazia, ao passo que uma recusa com nome é informação.
                """),
            .heading("Os seis comandos antigos continuam lá"),
            .paragraph("""
                `Vista tabela / texto`, `Pré-visualização de Markdown`, `Vista binária`, \
                `Pré-visualização do relatório`, `Pré-visualização do diagrama Mermaid`, `Modo registo` — \
                todos ficam exatamente onde estavam. `⌥⌘V` é uma **entrada partilhada**, não um \
                substituto.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamita

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamita",
        summary: "Codificações antigas, normalização Unicode, procura sem acentos e métodos de entrada.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Codificações vietnamitas",
        summary: "Ler e escrever TCVN3, VISCII, VNI-Windows e outras 33, detetadas automaticamente.",
        keywords: ["codificação", "tcvn3", "abc", "viscii", "vni", "caracteres estranhos"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Abriu um ficheiro vietnamita antigo e apareceu `Tr¦êng §¹i häc` em vez de `Trường Đại \
                học`? O ficheiro não está danificado — foi guardado numa codificação anterior ao Unicode.
                """),
            .steps([
                "Carregue na codificação na **barra de estado** (ou `Formato ▸ Codificação…`).",
                "Escolha a certa — em ficheiros vietnamitas antigos costuma ser `TCVN3 (ABC)`, `VNI-Windows` ou `VISCII`.",
                "O texto corrige-se de imediato; não é preciso reabrir o ficheiro.",
                "Para ficar assim, `Guardar como…` com a codificação `UTF-8`.",
            ]),
            .heading("As três codificações vietnamitas antigas"),
            .table(
                headers: ["Codificação", "Encontra-se sobretudo em"],
                rows: [
                    ["TCVN3 (ABC)", "Papelada oficial e documentos Word antigos do norte"],
                    ["VNI-Windows", "Edição, imprensa e tipografias — comum no sul"],
                    ["VISCII", "Correio e Usenet dos primeiros tempos"],
                ]
            ),
            .paragraph("""
                O GEditor **deteta a codificação** ao abrir. Quando erra, um clique resolve, e o conteúdo é \
                descodificado de novo em vez de ser remendado letra a letra.
                """),
            .warning("""
                Escrever para uma codificação antiga perde os caracteres que essa codificação não tem. O \
                GEditor **conta-os e diz-lho antes** — por exemplo *«12 caracteres não estão em TCVN3»* — \
                em vez de os transformar em pontos de interrogação em silêncio.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Fins de linha",
        summary: "LF, CRLF, CR — convertidos para o ficheiro inteiro com um clique.",
        keywords: ["eol", "crlf", "lf", "fim de linha", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Estilo", "Usado por", "Bytes"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac anterior a 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                O estilo atual aparece na barra de estado; carregue nele para o mudar. Um ficheiro que \
                **mistura** dois estilos também é comunicado aí — ligue `Mostrar invisíveis ▸ Fins de \
                linha` para ver exatamente onde.
                """),
            .note("O estilo de fim de linha para ficheiros **novos** define-se em `Definições…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalização Unicode",
        summary: "Porque procurar «ế» às vezes não encontra nada, e como corrigir um ficheiro inteiro.",
        keywords: ["unicode", "nfc", "nfd", "composto", "decomposto", "normalizar"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                No Unicode, `ế` pode escrever-se de **duas maneiras**: como um ponto de código \
                pré-composto (NFC), ou como `e` mais duas marcas separadas (NFD). No ecrã parecem iguais; \
                para uma máquina são duas cadeias diferentes.
                """),
            .paragraph("""
                A consequência: procurar `ế` num ficheiro NFD não encontra **nada**, e o utilizador conclui \
                que o dado não está lá.
                """),
            .steps([
                "`Formato ▸ Normalizar Unicode…`",
                "Escolha **NFC** (pré-composto) — a forma que quase tudo o resto usa.",
                "Aplique. É um único passo de desfazer.",
            ]),
            .note("""
                Os ficheiros vindos do macOS são muitas vezes NFD, porque o sistema de ficheiros da Apple \
                guarda os nomes assim. Esta é a razão mais comum para os dados copiados do Finder deixarem \
                de ser encontrados.
                """),
            .paragraph("""
                Há um interruptor **normalizar para NFC ao guardar** em `Definições…`. Desligado por \
                omissão, porque muda os bytes do ficheiro.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Escrever sem acentos encontra na mesma texto acentuado",
        summary: "Cada campo de procura e de filtro compara com os acentos retirados.",
        keywords: ["acentos", "diacríticos", "procura", "filtro"],
        blocks: [
            .paragraph("""
                Escreva `hue` para encontrar `Huế`. Escreva `da nang` para encontrar `Đà Nẵng`. A regra \
                vale para o filtro da tabela CSV, a procura de funções, a procura na ajuda e os restantes \
                campos de filtro.
                """),
            .note("""
                O `Đ` é tratado à parte, porque no Unicode é **uma letra própria** e não um `D` com uma \
                marca — a remoção de acentos vulgar não lhe toca.
                """),
            .paragraph("""
                O filtro CSV também aceita um prefixo `=` para comparação exata. A forma `=` é **igualmente \
                insensível aos acentos**, porque um filtro que distinga diacríticos deixa o utilizador a \
                crer que o dado falta.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Métodos de entrada vietnamitas",
        summary: "EVKey, OpenKey, Unikey e a fonte de entrada do macOS escrevem diretamente no documento.",
        keywords: ["método de entrada", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Nada a configurar. Telex e VNI funcionam ambos, também em **cursores múltiplos** — escreva \
                uma vez e cada cursor recebe a letra corretamente acentuada.
                """),
            .paragraph("""
                Os campos de procura, os de filtro e todas as caixas de diálogo aceitam o método de entrada \
                tal como o editor.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Linguagens e formatos

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Linguagens e formatos",
        summary: "Vinte linguagens integradas, outras definidas pelo utilizador, e ferramentas para JSON · XML · YAML · registos.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Vinte linguagens integradas",
        summary: "Coloração a partir de uma árvore sintática real, com os marcadores de comentário de cada linguagem.",
        keywords: ["sintaxe", "realce", "linguagem", "tree-sitter", "gramática"],
        blocks: [
            .paragraph("""
                A linguagem é detetada pela **extensão do ficheiro** (mais alguns nomes especiais como \
                `Makefile`, `Dockerfile`, `Gemfile`). Pode mudá-la à mão na barra de estado.
                """),
            .table(
                headers: ["Linguagem", "Extensões", "Comentário de linha · de bloco"],
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
                A última coluna é o que o `⌘/` usa. As linguagens sem comentário de linha (JSON, CSS, XML) \
                recebem a forma de bloco em vez disso.
                """),
            .heading("O que vem com uma árvore sintática"),
            .bullets([
                "A **lista de funções** na barra lateral segue a estrutura real, não palpites de indentação.",
                "**Dobragem** por estrutura.",
                "**Emparelhamento de parênteses** que salta os que estão dentro de cadeias e comentários.",
                "**Indentação automática** que acrescenta um nível depois de `{`, e depois de `:` em Python e YAML.",
            ]),
            .note("""
                Três gramáticas pesadas (C++, C#, Ruby) vivem numa biblioteca **carregada preguiçosamente** \
                — só são carregadas ao abrir um ficheiro dessas linguagens. É assim que o tempo de arranque \
                se mantém abaixo de meio segundo.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Linguagens definidas pelo utilizador",
        summary: "Colorir o seu próprio formato com um ficheiro JSON — sem gramática para escrever.",
        keywords: ["udl", "linguagem própria", "registo próprio"],
        blocks: [
            .paragraph("""
                O formato de registo interno de uma empresa, uma linguagem de configuração própria, uma \
                pequena DSL — nenhum tem gramática tree-sitter, e escrever uma exige um compilador e alguma \
                teoria de análise sintática.
                """),
            .paragraph("""
                Em vez disso, o GEditor aceita um **analisador léxico guiado por tabelas** declarado em \
                JSON. Ponha o ficheiro na pasta `grammars/` dentro do diretório de configuração do GEditor \
                e reinicie.
                """),
            .code(language: "json", caption: "grammars/internal-log.json — uma linguagem completa",
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
            .heading("Cada chave"),
            .table(
                headers: ["Chave", "Tipo", "Significado"],
                rows: [
                    ["`name`", "cadeia", "O nome mostrado na barra de estado"],
                    ["`extensions`", "lista de cadeias", "Extensões de ficheiro, **sem o ponto**"],
                    ["`caseSensitive`", "booleano", "Se as palavras-chave distinguem maiúsculas"],
                    ["`lineComment`", "cadeia", "Marcador de comentário até ao fim da linha; omita se não houver"],
                    ["`blockComment`", "lista de 2 cadeias", "`[abertura, fecho]`"],
                    ["`stringDelimiters`", "lista de cadeias", "Cada entrada é **um** caractere que abre/fecha uma cadeia"],
                    ["`escapeCharacter`", "cadeia", "Caractere de escape dentro de cadeias; vazio se a linguagem não tiver"],
                    ["`keywordGroups`", "objeto", "Nome de grupo → lista de palavras-chave; três grupos recebem três cores"],
                ]
            ),
            .paragraph("Os três nomes de grupo com cor própria são `keyword`, `type` e `constant`."),
            .warning("""
                Este analisador **não percebe aninhamento**. A dobragem estrutural, a lista de funções e o \
                emparelhamento inteligente de parênteses continuam exclusivos das vinte linguagens \
                integradas. É uma troca deliberada: em contrapartida, declara uma linguagem em dez minutos \
                em vez de num dia.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Ferramentas JSON",
        summary: "Reformatar, minificar, ordenar chaves e validar contra um JSON Schema.",
        keywords: ["json", "formatar", "minificar", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Comando", "O que faz"],
                rows: [
                    ["Reformatar", "Quebra e indenta para se poder ler"],
                    ["Minificar", "Remove todo o espaço supérfluo"],
                    ["Ordenar chaves", "Alfabeta as chaves de cada objeto — para que dois ficheiros JSON possam ser **comparados**"],
                    ["Validar contra JSON Schema…", "Verifica o documento contra um esquema, listando cada problema com a sua linha"],
                ]
            ),
            .paragraph("""
                As regras aplicadas são **RFC 8259 estrito**: sem vírgulas finais, sem comentários, sem \
                `NaN`. Um erro de sintaxe aponta para a linha e coluna exatas.
                """),
            .note("""
                Os ficheiros **JSONL** (um objeto por linha) também são reconhecidos e têm o seu próprio \
                conjunto de ferramentas no capítulo do pacote de conhecimento.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Consultas JSONPath",
        summary: "Tirar exatamente a parte de que precisa de um ficheiro JSON grande.",
        keywords: ["jsonpath", "consulta json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Escreva uma expressão; os resultados aparecem como uma lista para onde pode saltar."),
            .table(
                headers: ["Escreva", "Significado"],
                rows: [
                    ["`$`", "A raiz do documento"],
                    ["`$.name`", "A chave `name` na raiz"],
                    ["`$.orders[0]`", "O primeiro elemento de uma lista"],
                    ["`$.orders[*].total`", "A chave `total` de **cada** elemento"],
                    ["`$..province`", "A chave `province` a **qualquer profundidade**"],
                    ["`$.orders[1:3]`", "Um corte: elementos 1 e 2"],
                ]
            ),
            .code(language: "text", caption: "O código de província de cada encomenda, por mais aninhado que esteja",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Ferramentas XML",
        summary: "Reformatar, minificar, verificar a sintaxe e validar contra uma DTD ou um XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "validar", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Comando", "O que faz"],
                rows: [
                    ["Reformatar", "Indenta pela profundidade das etiquetas"],
                    ["Minificar", "Remove o espaço entre etiquetas"],
                    ["Verificar a sintaxe", "Etiquetas de fecho em falta, aninhamento errado, caracteres inválidos"],
                    ["Validar contra DTD/XSD…", "Verifica contra um esquema, comunicando cada problema com a sua linha"],
                    ["Avaliar XPath…", "Executa uma expressão XPath; os resultados abrem num separador novo"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Escreva uma expressão e os resultados abrem como **um separador de texto**, um nó por \
                linha. Por exemplo: `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Os resultados NÃO saltam para uma posição no ficheiro fonte.** O avaliador de XPath do \
                sistema constrói a sua própria árvore e não guarda a posição em bytes de cada nó, por isso \
                o que volta é CONTEÚDO e não coordenadas. Para chegar ao ponto exato, use `⌘F` sobre a \
                cadeia que acabou de encontrar.
                """),
            .paragraph("""
                Em ficheiros `.xml` e `.html`, escrever `>` para terminar uma etiqueta de abertura faz \
                **aparecer a de fecho** com o cursor entre as duas. As etiquetas de auto-fecho (`<br/>`), \
                as declarações (`<?xml …?>`) e os comentários não — não têm nada para fechar.
                """),
            .warning("""
                Reformatar XML **muda o espaço entre etiquetas**. Em documentos onde esse espaço tem \
                significado — XHTML com texto dentro de etiquetas, por exemplo — isso muda o que é \
                mostrado. É um único passo de desfazer, por isso `⌘Z` reverte-o.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Verificação de YAML",
        summary: "Apanhar os dois erros de YAML mais comuns: chaves duplicadas e indentação com tabulações.",
        keywords: ["yaml", "yml", "lint", "chave duplicada", "indentação"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Chaves duplicadas** num mesmo mapeamento — a maioria dos leitores de YAML fica com a **última** e descarta as anteriores em silêncio, por isso um ficheiro de configuração pode comportar-se de forma muito diferente do que julga.",
                "**Indentação com tabulações** — o YAML proíbe tabulações na indentação, e as mensagens de erro das bibliotecas sobre isso costumam ser incompreensíveis.",
            ]),
            .note("Ligue `Mostrar invisíveis ▸ Tabulações` para ver de imediato que espaço é uma tabulação."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Ficheiros de registo",
        summary: "Sete níveis de gravidade, filtragem por nível e como ler um registo muito grande.",
        keywords: ["registo", "log", "erro", "aviso", "filtro", "nível"],
        blocks: [
            .paragraph("""
                Ligue `Ver ▸ Modo registo (colorir por nível)`. O GEditor lê a gravidade no **início de \
                cada linha** — depois da marca temporal e do nome do processo.
                """),
            .table(
                headers: ["Nível", "Cor"],
                rows: [
                    ["CRITICAL · ERROR", "Vermelho"],
                    ["WARNING", "Âmbar"],
                    ["NOTICE", "Cor de destaque"],
                    ["INFO", "Texto vulgar"],
                    ["DEBUG · TRACE", "Esbatido"],
                ]
            ),
            .paragraph("""
                `Filtrar registo por nível…` esconde por completo os níveis mais baixos. As linhas cujo \
                nível **não é reconhecido** — a continuação de um rastreio de pilha, por exemplo — ficam \
                intactas em vez de receberem o nível da linha anterior.
                """),
            .heading("Ler um registo grande, passo a passo"),
            .steps([
                "Abra o ficheiro — mesmo à escala do gigabyte abre quase de imediato.",
                "`Ver ▸ Modo registo` para ver onde está o vermelho.",
                "`⌥⌘M` para o mapa do documento: o vermelho está agrupado num troço ou espalhado pelo ficheiro todo?",
                "`⌘F` para o código de erro, `⌘M` para marcar cada linha correspondente.",
                "`Procurar ▸ Copiar linhas marcadas` para as levar a um separador novo.",
                "Ainda a correr? `Ficheiro ▸ Seguir ficheiro (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
