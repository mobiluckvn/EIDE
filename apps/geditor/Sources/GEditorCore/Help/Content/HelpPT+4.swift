import Foundation

/// Conteúdo de ajuda em português — parte 4: dados tabulares, limpeza e mineração.
extension HelpPT {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Dados tabulares",
        summary: "Ver CSV como tabela, filtrar, ordenar, verificar a estrutura, consultar com SQL, converter.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Ver um CSV como tabela",
        summary: "Um milhão de linhas continua a deslizar sem falhas, o cabeçalho não sai do sítio e o texto fonte fica intacto.",
        keywords: ["csv", "tabela", "grelha", "tsv", "excel", "colunas"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Alternar entre tabela e texto")]),
            .paragraph("""
                A tabela é **virtualizada**: só as linhas visíveis são construídas, por isso um ficheiro de \
                um milhão de linhas desliza como um de cem.
                """),
            .bullets([
                "**A linha de cabeçalho fica fixa** durante o deslocamento — na linha 40 000 ainda sabe o que é a nona coluna.",
                "Edite uma célula na tabela; a alteração vai direta para o texto fonte.",
                "Tabela e texto são **dois olhares sobre um ficheiro**, não duas cópias.",
                "**⌘C copia a linha selecionada**, com células separadas por tabulações — cole diretamente no Excel ou no Numbers e cada célula cai no sítio certo. As células com tabulações ou fins de linha ficam entre aspas, para que o destino não as parta em duas.",
            ]),
            .note("""
                O separador é detetado ao abrir (vírgula, ponto e vírgula, tabulação, barra vertical). Se a \
                suposição estiver errada, mude-o com `CSV ▸ Mudar separador…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Livros com várias folhas",
        summary: "Abrir qualquer folha de um .xlsx, e ⌘S escreve de volta na folha que está a ver.",
        keywords: ["excel", "xlsx", "folha", "livro"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Abra um `.xlsx` e o GEditor mostra a **primeira folha** como tabela CSV. `CSV ▸ Escolher \
                folha…` lista cada folha do ficheiro e abre a que escolher no mesmo separador.
                """),
            .heading("Escrever de volta na folha CERTA"),
            .paragraph("""
                `⌘S` escreve as suas alterações na **folha que está a ver**, não na primeira. As restantes \
                folhas não são tocadas nem num byte.
                """),
            .note("""
                A folha é recordada pelo **nome**, não pela posição. Assim, reordenar as folhas no Excel \
                entre duas sessões não desvia a escrita.
                """),
            .warning("""
                Se a folha aberta tiver sido **renomeada ou apagada** no Excel desde que a abriu, o `⌘S` \
                **recusa escrever** e di-lo. Recorrer à primeira folha equivaleria a despejar o conteúdo de \
                uma folha sobre outra — o ficheiro seria guardado na mesma, voltaria a abrir na mesma, e \
                teria simplesmente os dados no sítio errado.
                """),
            .heading("Mudar de folha com alterações por guardar"),
            .paragraph("""
                Mudar de folha substitui todo o conteúdo do separador, por isso se houver algo por guardar \
                o GEditor **pergunta primeiro**. O `⌘Z` não o consegue trazer de volta, porque o documento \
                inteiro foi trocado.
                """),
            .heading("O que custa reduzir o Excel a uma tabela"),
            .paragraph("""
                O que sobrevive são os **valores** — incluindo os resultados de fórmulas, exatamente os \
                números que o Excel mostra. O que não sobrevive: letras, cores, células unidas, gráficos \
                embutidos e as próprias fórmulas.
                """),
            .paragraph("""
                Em troca, essa folha ganha todo o resto do produto: filtragem, ordenação, consultas SQL, a \
                bancada de limpeza, a pontuação de qualidade, a mineração, os gráficos.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrar e ordenar na tabela",
        summary: "Um campo de filtro por coluna, que percebe comparação numérica e escrita sem acentos.",
        keywords: ["filtro", "ordenar", "coluna", "procurar na tabela"],
        blocks: [
            .paragraph("Carregue num cabeçalho de coluna para ordenar. O campo de filtro por baixo aceita:"),
            .table(
                headers: ["Escreva no filtro", "Significado"],
                rows: [
                    ["`hue`", "Contém `hue`, **insensível a acentos** — encontra também `Huế`"],
                    ["`=Huế`", "Exatamente `Huế` (continua insensível a acentos)"],
                    ["`>100`", "Maior que 100"],
                    ["`>=100`", "100 ou mais"],
                    ["`<0`", "Menor que 0"],
                    ["`100..200`", "Entre 100 e 200"],
                    ["vazio", "Sem filtro nesta coluna"],
                ]
            ),
            .paragraph("""
                Filtrar várias colunas é um **e**: uma linha tem de satisfazer todas. A comparação numérica \
                salta as células não numéricas em vez de as tratar como zero.
                """),
            .note("""
                Filtrar é uma **forma de olhar**, não uma eliminação. Limpe o filtro e todas as linhas \
                voltam.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Verificar a estrutura da tabela",
        summary: "Encontrar linhas com o número de colunas errado e células do tipo errado — isto primeiro.",
        keywords: ["validar", "verificar", "número de colunas", "tipo errado", "dados estragados"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                É isto que se executa **antes** de tudo o resto num ficheiro que lhe enviaram. Responde a \
                duas perguntas:
                """),
            .bullets([
                "**Que linhas têm o número de colunas errado?** Normalmente uma célula com uma vírgula sem aspas — e desalinha todas as linhas seguintes.",
                "**Que células têm um tipo diferente do resto da sua coluna?** Por exemplo um `n/a` numa coluna de números.",
            ]),
            .paragraph("Os resultados aparecem como lista; carregue num para saltar para essa linha."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Apagar colunas",
        summary: "Retirar do ficheiro uma ou várias colunas por completo.",
        keywords: ["apagar coluna", "retirar coluna"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Escolha da lista as colunas a descartar e aplique. É **um** passo de desfazer, por muitas \
                linhas que o ficheiro tenha.
                """),
            .warning("""
                Ao contrário de filtrar, isto **edita o ficheiro a sério**. Para apenas esconder colunas, \
                use uma consulta SQL que liste as que quer.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Consultar CSV com SQL",
        summary: "O SQL completo do DuckDB, executado diretamente sobre o ficheiro aberto — só de leitura.",
        keywords: ["sql", "consulta", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                A tabela aberta chama-se **`t`**. O motor é o **DuckDB**, por isso `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, as funções de janela e as subconsultas funcionam todas.
                """),
            .code(language: "sql", caption: "Receita por província, da maior para a menor",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrar por data e por uma condição de texto",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "A quota de cada província no total — com uma função de janela",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Juntar com outro ficheiro do disco",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Só de leitura, e é uma garantia firme"),
            .bullets([
                "A base de dados vive **em memória**; o ficheiro fonte é apenas lido.",
                "É aceite exatamente **uma instrução**, e **tem de ser um `SELECT`**. Todo o resto — incluindo `COPY … TO 'ficheiro'`, que o DuckDB pode perfeitamente usar para escrever em disco — é bloqueado antes de chegar a qualquer dado.",
            ]),
            .warning("""
                O DuckDB lê **ficheiros**, não memória. Se o documento tiver alterações por guardar, o \
                GEditor tem de escrever uma cópia temporária antes de consultar. Com um ficheiro muito \
                grande e alterações por guardar, **para e di-lo** em vez de escrever em silêncio centenas de \
                megabytes em disco para uma só consulta.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Tabelas dinâmicas e gráficos rápidos",
        summary: "Pivotar e desenhar diretamente a partir de um resultado de consulta.",
        keywords: ["tabela dinâmica", "gráfico", "tabela cruzada", "agregado"],
        blocks: [
            .paragraph("""
                Ambos abrem a partir da **tabela de resultados**: execute uma instrução SQL e depois use o \
                botão Dinâmica ou Gráfico do painel.
                """),
            .heading("Tabela dinâmica"),
            .paragraph("""
                Escolha a coluna de **linhas**, a de **colunas**, a de **valores** e o agregado (soma, \
                contagem, média, mín., máx.) — como a tabela dinâmica de uma folha de cálculo.
                """),
            .heading("Gráficos"),
            .paragraph("""
                Barras, linhas, setores, dispersão. Números com formato vietnamita ou europeu, e o gráfico \
                exporta-se como PNG ou SVG para colar noutro sítio.
                """),
            .note("""
                Quer um gráfico que **se atualize com os dados** em cada reconstrução? Esse é o bloco \
                `chart` de um relatório `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Converter uma tabela para outro formato",
        summary: "TSV, JSON, XML, tabelas Markdown, instruções SQL INSERT — com pré-visualização.",
        keywords: ["converter", "exportar", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Formato", "Útil para"],
                rows: [
                    ["TSV", "Colar numa folha de cálculo sem se preocupar com as vírgulas das células"],
                    ["JSON", "Alimentar uma API, um script ou outra ferramenta"],
                    ["XML", "Sistemas antigos que exigem XML"],
                    ["Tabela Markdown", "Colar em documentação, num README, num ticket"],
                    ["Instruções SQL INSERT", "Carregar numa base de dados"],
                ]
            ),
            .paragraph("""
                A caixa de diálogo **pré-visualiza as cinco primeiras linhas** antes de criar o separador \
                novo — cinco linhas chegam para confirmar o nome da tabela, as aspas e que colunas passaram \
                a números.
                """),
            .note("""
                A pré-visualização chama **a mesma função** que produz a saída real, limitada a cinco \
                linhas. Não é uma simulação que pudesse divergir do resultado final.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Mudar o separador",
        summary: "Converter um ficheiro entre vírgula, ponto e vírgula, tabulação e barra vertical.",
        keywords: ["separador", "vírgula", "ponto e vírgula", "tabulação", "csv europeu"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Os ficheiros exportados de um Excel vietnamita ou europeu costumam usar **ponto e \
                vírgula**, porque lá a vírgula é o separador decimal.
                """),
            .warning("""
                Mudar o separador **reescreve o ficheiro inteiro**. As células que contenham o separador \
                novo ficam entre aspas — de outro modo a estrutura da tabela parte-se.
                """),
            .note("""
                **Se a deteção falhou, não é este o comando que quer.** Aqui estão duas tarefas diferentes, \
                tal como no par de codificação «reinterpretar» / «converter»:

                • *O ficheiro usa mesmo ponto e vírgula e nós adivinhámos vírgula* — carregue no segmento \
                `CSV · …` da **barra de estado** e escolha o certo. Não muda um byte do ficheiro; muda só \
                como é lido.

                • *O ficheiro usa mesmo vírgulas e você quer pontos e vírgulas* — use o comando desta \
                página. Reescreve o ficheiro.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Limpeza

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Limpeza de dados — o fluxo todo",
        summary: "De um ficheiro em bruto que lhe enviaram a uma tabela utilizável, e um padrão para repetir todos os meses.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "O fluxo de limpeza, do princípio ao fim",
        summary: "Seis passos de um ficheiro desconhecido a uma tabela de confiança, e um padrão para o mês seguinte.",
        keywords: ["limpeza", "fluxo", "normalizar", "dados limpos"],
        blocks: [
            .paragraph("""
                Limpar dados **raramente é coisa de uma vez**. As pessoas recebem o mesmo modelo de \
                relatório todos os meses, e todos os meses é preciso normalizar as mesmas colunas da mesma \
                maneira. Este fluxo foi pensado para isso: faz-se à mão uma vez e depois repete-se com um \
                único comando.
                """),
            .heading("Seis passos"),
            .steps([
                "**Olhe primeiro para a estrutura.** `CSV ▸ Verificar dados` — que linhas têm o número de colunas errado, que células o tipo errado. Isto vem primeiro porque uma única linha desalinhada torna sem sentido qualquer estatística posterior.",
                "**Leia o perfil dos dados.** Por coluna: quantas células vazias, quantos valores distintos, que tipo, onde estão os valores atípicos. É aqui que percebe o ficheiro, antes de mudar seja o que for.",
                "**Abra a bancada de limpeza** (`⇧⌘L`). Deteta formatos de data misturados, números vietnamitas misturados com europeus, espaços perdidos, valores em falta. **Pré-visualize antes→depois** e depois aplique.",
                "**Trate os duplicados aproximados** se uma coluna de nomes ou moradas tiver variantes escritas à mão. Aqui decide você; a máquina só propõe.",
                "**Guarde-o como receita.** A sequência que acabou de executar é escrita num ficheiro JSON com nome — esse ficheiro é o seu conhecimento sobre estes dados.",
                "**Escreva um conjunto de regras de qualidade** `.gquality.yaml` e pontue. A partir daí o ficheiro do mês seguinte passa pela receita e recebe uma nota, e o **portão de linha de comandos** devolve um código de saída diferente de zero quando falha.",
            ]),
            .heading("Porquê esta ordem"),
            .bullets([
                "Estrutura **antes** do perfil: estatísticas sobre uma tabela desalinhada são estatísticas sobre outra coluna.",
                "Perfil **antes** da limpeza: é preciso saber «2 % vazio» antes de decidir preencher ou descartar.",
                "Duplicados aproximados **depois** de normalizar: `CÔNG TY  A` e `Công ty A` só se revelam como um depois de espaços e maiúsculas estarem resolvidos.",
                "Receita **antes** do conjunto de regras: a receita corrige, as regras julgam — pontuar uma tabela por corrigir só produz um número baixo que já esperava.",
            ]),
            .heading("Depois da primeira vez, cada mês é um comando"),
            .code(language: "bash", caption: "Limpar e depois pontuar, devolvendo um código de saída para a CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                O código de saída **0** significa aprovado, **1** reprovado, **2** erro de execução. \
                `--record-history` acrescenta uma linha ao ficheiro de histórico para que a execução \
                seguinte possa comparar o desvio.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Perfil dos dados",
        summary: "Uma descrição por coluna: tipo, vazios, valores distintos, distribuição.",
        keywords: ["perfil", "estatística de coluna", "nulo", "distinto"],
        blocks: [
            .paragraph("""
                Um perfil **descreve**; não julga. Diz *«esta coluna está 2 % vazia»*; se 2 % é aceitável \
                pertence ao conjunto de regras de qualidade.
                """),
            .table(
                headers: ["Medida", "Como a ler"],
                rows: [
                    ["Tipo", "Deduzido dos próprios dados, não do nome da coluna"],
                    ["Células vazias", "Número e proporção de valores em falta"],
                    ["Valores distintos", "1 significa coluna constante; igual ao número de linhas, coluna chave"],
                    ["Mín · máx · média", "Só colunas numéricas"],
                    ["Valores mais frequentes", "Detetar de imediato um código de erro ou um valor por omissão usado em demasia"],
                ]
            ),
            .warning("""
                A contagem de valores distintos tem um limiar. Passado esse ponto, o número mostrado é um \
                **limite inferior**, e o perfil **diz que é uma estimativa** em vez de o misturar com as \
                contagens exatas.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "A bancada de limpeza de dados",
        summary: "Sete normalizações, sempre com pré-visualização, sempre um passo de desfazer, nunca a adivinhar.",
        keywords: ["limpar", "normalizar", "datas", "números", "preencher"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Abrir a bancada de limpeza")]),
            .table(
                headers: ["Operação", "O que faz"],
                rows: [
                    ["Normalizar datas", "Levar todas as formas de data da coluna a uma só"],
                    ["Normalizar números", "Resolver o separador decimal e o de milhares"],
                    ["Cortar espaços", "Retirá-los nas duas pontas; opcionalmente compactar também os interiores"],
                    ["Mudar maiúsculas", "Tornar coerente a capitalização da coluna"],
                    ["Preencher com um valor fixo", "Substituir as células vazias por um valor que escreva"],
                    ["Preencher a partir de uma vizinha", "Tomar o valor da linha de cima ou de baixo"],
                    ["Apagar linhas com células vazias", "Descartar as linhas a que faltam dados"],
                ]
            ),
            .heading("Três garantias de toda a bancada"),
            .bullets([
                "**Sempre com pré-visualização.** Uma tabela antes→depois, com o número de células que vão mudar.",
                "**Um passo de desfazer** para a passagem toda, mesmo que toque num milhão de células.",
                "**Um relatório depois**: quantas células mudaram e quais não puderam ser lidas.",
            ]),
            .heading("O princípio: nunca adivinhar"),
            .paragraph("""
                Uma célula que não se consegue ler com certeza é **assinalada e deixada em paz**. Tome \
                `03/04/2026` numa coluna que mistura as duas convenções: é 3 de abril ou 4 de março? O \
                GEditor pergunta-lhe a ordem dia/mês em vez de escolher por si.
                """),
            .warning("""
                Normalizar mal uma coluna de datas é o tipo de corrupção **quase impossível de detetar**: \
                os números continuam a parecer certos, são apenas outra data. Por isso esta bancada prefere \
                recusar a inferir.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Duplicados aproximados",
        summary: "Encontrar variantes escritas à mão do mesmo nome — e nunca as juntar automaticamente.",
        keywords: ["aproximado", "duplicados", "juntar", "variantes", "gralhas"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — três formas de \
                escrever o mesmo cliente. A eliminação de duplicados vulgar não as vê como iguais.
                """),
            .steps([
                "Escolha a coluna a examinar e um limiar de semelhança.",
                "O GEditor agrupa os valores próximos em **aglomerados** e mostra a forma de comparação.",
                "Para **cada aglomerado**, você escolhe que valor manter — ou salta-o.",
                "Aplique. Um passo de desfazer.",
            ]),
            .warning("""
                Esta ferramenta **nunca junta por sua conta**, e não há botão de «juntar tudo». Duas cadeias \
                92 % semelhantes podem ser uma gralha, ou duas empresas realmente diferentes que se \
                distinguem por uma palavra — uma máquina não consegue decidir.
                """),
            .paragraph("""
                Juntar mal dois registos é perda de dados **silenciosa**: nenhuma célula fica vazia, nenhuma \
                linha fica vermelha, duas entidades passam simplesmente a uma e ninguém dá por isso até se \
                fecharem as contas.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Receitas de limpeza",
        summary: "Gravar a sequência como ficheiro JSON e repeti-la nos dados do mês seguinte.",
        keywords: ["receita", "repetir", "automatizar", "mensal", "lote"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Depois de limpar, guarde os passos como **receita**. É um ficheiro JSON legível por humanos \
                que pode guardar junto dos dados, enviar a um colega e pôr num repositório para que as \
                mudanças fiquem registadas.
                """),
            .code(language: "json", caption: "sales-standard.json — abreviado",
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
                Cada passo pode ser **desligado** (`enabled`), por isso uma receita pode servir para várias \
                espécies de ficheiro quase iguais.
                """),
            .heading("Repetir"),
            .bullets([
                "Na aplicação: `CSV ▸ Executar receita de limpeza…`",
                "A partir da consola, sobre uma pasta inteira: veja a página da linha de comandos.",
            ]),
            .code(language: "bash", caption: "Um ensaio a seco antes de escrever seja o que for — nenhum ficheiro é tocado",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Por omissão o resultado é escrito num ficheiro novo ao lado do original \
                (`sales-clean.csv`). Sobrescrever o original tem de ser pedido explicitamente com \
                `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Pontuação de qualidade dos dados",
        summary: "Seis dimensões, uma nota de 0 a 100, e cada fórmula impressa para que a possa recalcular.",
        keywords: ["qualidade", "nota", "dqr", "seis dimensões"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Distingue-se do perfil dos dados numa coisa fundamental: um perfil **descreve**, uma nota \
                **julga face ao padrão que você declarou** num ficheiro `.gquality.yaml`.
                """),
            .table(
                headers: ["Dimensão", "O que mede"],
                rows: [
                    ["Completude", "Proporção de células preenchidas segundo as regras `not_null`"],
                    ["Validade", "Proporção de regras de formato, tipo, intervalo e regex que passam"],
                    ["Unicidade", "Face à chave declarada em `uniqueness_key`"],
                    ["Coerência", "Regras entre colunas e entre ficheiros"],
                    ["Exatidão (estimada)", "Valores atípicos nas colunas numéricas que indicar"],
                    ["Atualidade", "Quão antigos são os dados face ao limiar `freshness`"],
                ]
            ),
            .heading("Três garantias sobre a nota"),
            .bullets([
                "**A fórmula é impressa no resultado** — pode recalculá-la à mão.",
                "**Determinística**: os mesmos dados e as mesmas regras dão a mesma nota. Só a *Atualidade* depende do momento, por isso `now` é um **parâmetro** e fica registado no resultado.",
                "**Uma dimensão que não se consegue pontuar fica em branco com a sua razão**, nunca com um 100 dado em silêncio.",
            ]),
            .warning("""
                Esta última garantia conta. Uma tabela sem `uniqueness_key` declarada a que se dá um 100 em \
                «unicidade» é uma nota que mente — e mente na direção lisonjeira, que é a perigosa.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Sintaxe de `.gquality.yaml`",
        summary: "Cada chave do ficheiro de regras, com um conjunto completo que corre.",
        keywords: ["gquality", "yaml", "regras", "sintaxe", "padrão de dados"],
        blocks: [
            .paragraph("""
                O ficheiro vive **ao lado dos dados**, não dentro da aplicação: um padrão de dados tem de \
                poder ser revisto, e rever é o que as pessoas fazem com os padrões.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — um conjunto de regras completo",
                  source: """
                    schemaVersion: 1

                    # Pesos das seis dimensões. Uma dimensão ausente pesa 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # A chave que torna uma linha única. Sem ela, a dimensão «Unicidade»
                    # NÃO PODE ser pontuada — e o total di-lo.
                    uniqueness_key: [ma_don]

                    # Colunas numéricas examinadas para atípicos na «Exatidão (estimada)».
                    accuracy_columns: [doanh_thu, so_luong]

                    # A dimensão «Atualidade».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Avisar quando esta execução descer face à anterior.
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
                        max_null_pct: 2          # permite 2 % vazio
                      # Regra entre colunas: não é preciso `col`
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Regra entre ficheiros: o valor tem de existir noutro ficheiro
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Os tipos de regra"),
            .table(
                headers: ["Chave", "Significado", "Dimensão"],
                rows: [
                    ["`not_null: true`", "A célula tem de estar preenchida; `max_null_pct` alivia", "Completude"],
                    ["`unique: true`", "Sem valores repetidos na coluna", "Unicidade"],
                    ["`dtype: int\\|float\\|date\\|text`", "Tipo correto", "Validade"],
                    ["`range: { min:, max: }`", "Dentro de um intervalo numérico", "Validade"],
                    ["`length: { min:, max: }`", "Comprimento da cadeia", "Validade"],
                    ["`regex: \"…\"`", "Corresponde a uma expressão regular", "Validade"],
                    ["`in_set: [ … ]`", "Um de uma lista dada", "Validade"],
                    ["`date_format: \"…\"`", "Forma de data correta", "Validade"],
                    ["`compare: { a:, op:, b: }`", "Comparar duas colunas; `op` é `<` `<=` `=` `>=` `>` `<>`", "Coerência"],
                    ["`foreign_key: { file:, column: }`", "O valor tem de existir noutro ficheiro", "Coerência"],
                    ["`severity: error\\|warn`", "Gravidade da regra; `error` por omissão", "—"],
                ]
            ),
            .warning("""
                Se escrever mal uma chave de regra, o ficheiro é **recusado com uma mensagem**, em vez de \
                essa regra ser saltada em silêncio. Saltá-la em silêncio significa que julga que os dados \
                foram verificados face a uma regra que nunca correu.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Um portão de qualidade na CI",
        summary: "Travar os dados defeituosos na cadeia, usando códigos de saída.",
        keywords: ["ci", "portão", "fail-under", "código de saída", "histórico", "desvio"],
        blocks: [
            .code(language: "bash", caption: "Pontuar e devolver um código de saída",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Opção", "Significado"],
                rows: [
                    ["`--quality <ficheiro.yaml>`", "O conjunto de regras com que pontuar"],
                    ["`--fail-under <0…100>`", "Abaixo desta nota é REPROVADO"],
                    ["`--json <ficheiro\\|->`", "Resultado legível por máquina; `-` escreve na saída padrão"],
                    ["`--record-history`", "Acrescenta uma linha a `sales-standard.history.jsonl`"],
                    ["`--now <AAAA-MM-DD>`", "Fixa a data de referência da *Atualidade*"],
                    ["`--recipe <ficheiro.json>`", "Limpar **em memória** antes de pontuar, sem escrever ficheiro"],
                ]
            ),
            .table(
                headers: ["Código de saída", "Significado"],
                rows: [["`0`", "Aprovado"], ["`1`", "Reprovado"], ["`2`", "Erro de execução"]]
            ),
            .heading("Porque a CI deve passar `--now`"),
            .paragraph("""
                Sem isso, a *Atualidade* compara os dados com o momento da execução — por isso o mesmo \
                ficheiro vai perdendo pontos à medida que os dias passam, e uma manhã a cadeia fica \
                vermelha sem que ninguém tenha mudado nada.
                """),
            .heading("Seguimento do desvio"),
            .paragraph("""
                Com `--record-history`, cada execução acrescenta uma linha a um ficheiro de histórico \
                JSONL. Da vez seguinte, os limiares do bloco `drift:` comparam com a execução mais recente \
                e avisam quando a queda é demasiado grande.
                """),
            .note("""
                Todo o limiar de desvio vem **desligado por omissão**, exceto `warn_on_new_failure`. Um \
                aviso ligado de fábrica com um número que a aplicação escolheu dispararia na segunda \
                execução de toda a gente — e o que grita «lobo» ao primeiro dia é ignorado ao terceiro.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Mineração

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Mineração de dados — o fluxo todo",
        summary: "Anomalias, correlação, aglomerados, previsão, regras de associação — e como as ler.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "O fluxo de mineração, do princípio ao fim",
        summary: "Seis ferramentas, a ordem por que usá-las, e uma regra: sem medição, não há conclusão.",
        keywords: ["mineração", "análise", "fluxo", "estatística"],
        blocks: [
            .warning("""
                **Primeiro limpar, depois minerar.** Uma coluna de datas por normalizar produz previsões \
                erradas; uma coluna numérica que mistura separadores de milhares europeus produz atípicos \
                fantasma. Cada ferramenta abaixo pressupõe que a tabela está limpa.
                """),
            .heading("A ordem a seguir"),
            .steps([
                "**Encontrar anomalias** — responde a *«alguma linha é esquisita?»*. O mais barato e muitas vezes útil de imediato.",
                "**Matriz de correlação** — responde a *«que coluna se move com qual?»*. Orienta tudo o que vem depois.",
                "**Aglomerados** — responde a *«quantos grupos naturais há aqui dentro?»*.",
                "**Previsão** — só com uma coluna de tempo e pelo menos **dois ciclos completos**.",
                "**Regras de associação** — só para dados em forma de cesto: uma transação por linha, ou duas colunas com identificador de transação e artigo.",
                "**Mineração por grupo** — repete as três primeiras **de forma independente dentro de cada grupo**. Este passo inverte com frequência a conclusão tirada da tabela agregada.",
            ]),
            .heading("Três regras para toda a família"),
            .bullets([
                "**Cada resultado traz um bloco «Método»**: algoritmo, parâmetros, semente, fórmula. Não há forma de o desligar — uma tabela de três números que não diz de onde vieram não serve para decidir.",
                "**Sem medição, não há conclusão.** Amostra demasiado pequena, variância nula, matriz singular — o GEditor recusa e diz porquê, em vez de devolver um número que só parece certo.",
                "**Resultados determinísticos.** Os mesmos dados dão o mesmo resultado; onde é preciso acaso, a semente fica registada na saída.",
            ]),
            .heading("Do resultado de volta aos dados"),
            .paragraph("""
                Cada painel **marca de volta nos dados fonte**: carregue numa linha anómala, numa célula de \
                correlação ou numa regra de associação e as linhas em causa ficam marcadas na tabela. É \
                assim que se passa de *«há algo estranho»* para *«estranho exatamente nestas linhas»*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Encontrar linhas anómalas",
        summary: "Quatro medidas, três níveis de gravidade e uma explicação de porque uma linha é esquisita.",
        keywords: ["atípico", "anomalia", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Medida", "Quando usar"],
                rows: [
                    ["z-score", "A coluna segue mais ou menos uma normal"],
                    ["IQR", "A coluna é assimétrica com cauda longa — a opção segura por omissão"],
                    ["MAD", "A coluna já tem muitos atípicos e precisa de uma medida robusta"],
                    ["Mahalanobis", "**Várias colunas ao mesmo tempo** — apanha linhas esquisitas na combinação, não em nenhuma coluna isolada"],
                ]
            ),
            .paragraph("""
                Os resultados são coloridos por **três níveis de gravidade** em vez de uma cor única — de \
                outro modo uma linha ligeiramente invulgar não se distinguiria de uma absurdamente \
                invulgar.
                """),
            .heading("Explicar o porquê"),
            .paragraph("""
                Para a medida multicoluna, o GEditor decompõe o contributo de cada coluna e produz uma \
                frase como *«anómala sobretudo pela combinação receita (50 %) × quantidade (50 %)»*.
                """),
            .note("""
                Essa percentagem é *da parte explicável*, não *da distância*. O bloco Método di-lo logo \
                abaixo da tabela.
                """),
            .warning("""
                Uma coluna cujo IQR ou MAD seja zero faz a medida **recusar-se a correr**, em vez de \
                dividir por algo minúsculo e produzir uma pontuação enorme. No caso multicoluna, se a \
                matriz de covariâncias for singular, o GEditor **diz que coluna retirar** em vez de usar \
                uma pseudo-inversa para «fazer funcionar».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Matriz de correlação",
        summary: "Pearson e Spearman para cada par, com diagrama de dispersão ao carregar.",
        keywords: ["correlação", "pearson", "spearman", "mapa de calor", "dispersão"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coeficiente", "O que mede"],
                rows: [
                    ["Pearson", "Uma relação **linear**"],
                    ["Spearman", "**Qualquer** relação **monótona**, incluindo as curvas — calculada sobre postos"],
                ]
            ),
            .paragraph("""
                Carregue numa célula do mapa de calor para ver o diagrama de dispersão desse par, com reta \
                de regressão e R².
                """),
            .heading("Quatro pormenores que mudam a leitura"),
            .bullets([
                "**Os empates usam postos médios**, por isso reordenar a tabela não muda o coeficiente de Spearman.",
                "**As células vazias são tratadas aos pares**, e o `n` de cada célula está mesmo ali na tabela — `0,93` em 6 linhas não significa o que `0,93` em 6000 linhas significa.",
                "**Uma coluna constante devolve vazio**, não 0. Zero significa *medido, nenhuma relação encontrada*.",
                "**A escala de cor é azul↔laranja**, não vermelho-verde: 8 % dos homens veem uma escala vermelho-verde como uma massa cinzenta, o que faz `+0,9` e `−0,9` parecerem iguais.",
            ]),
            .warning("""
                **Correlação não implica causalidade.** Essa frase é desenhada **dentro do próprio \
                gráfico**, por isso viaja com a imagem quando a exporta.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Aglomerados",
        summary: "k-médias e DBSCAN, duas formas de escolher k — e um aviso sobre a escala.",
        keywords: ["aglomerado", "cluster", "kmeans", "dbscan", "silhueta", "cotovelo"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algoritmo", "Quando usar"],
                rows: [
                    ["k-médias", "Sabe (ou quer experimentar) o número de aglomerados; são em forma de mancha"],
                    ["DBSCAN", "Não sabe o número; os aglomerados têm formas arbitrárias; quer separar o ruído"],
                ]
            ),
            .heading("A escala vem ligada — e porquê"),
            .paragraph("""
                Uma coluna `receita` (em milhões) ao lado de uma coluna `quantidade` (em unidades): a \
                distância entre duas linhas é decidida quase por completo pela maior. Isso não é «subótimo» \
                — é **responder a outra pergunta**. A escala em vigor fica registada no resultado.
                """),
            .heading("Escolher o número de aglomerados"),
            .bullets([
                "**Silhueta** — quanto mais alta a pontuação, melhor separados estão. Numa tabela grande **tira uma amostra** (a intervalos regulares, não as primeiras 2000 linhas), e o resultado declara-se uma estimativa.",
                "**Cotovelo** — desenha a soma de quadrados dentro do aglomerado face a k. É uma **forma de ler um gráfico**, não uma otimização: essa quantidade desce sempre quando k sobe, por isso não existe estatisticamente um «k ótimo».",
            ]),
            .note("""
                Para o DBSCAN, o gráfico de **k-distâncias** ajuda a escolher um raio: o joelho da curva \
                costuma ser um valor de partida sensato.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Previsão de séries temporais",
        summary: "Decomposição de tendência e sazonalidade, Holt-Winters, e uma referência que corre sempre ao lado.",
        keywords: ["previsão", "série temporal", "sazonalidade", "holt-winters", "tendência"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Escolha uma coluna de tempo e uma de valores. O GEditor decompõe a série em **tendência · \
                sazonalidade · resíduo** e depois prevê com Holt-Winters (aditivo ou multiplicativo), com \
                intervalos a 80 % e a 95 %.
                """),
            .heading("A referência corre sempre, e diz sem rodeios quem ganhou"),
            .paragraph("""
                Ao lado do modelo, o GEditor executa dois métodos ingénuos: *tomar o período anterior* e \
                *tomar o mesmo período da época passada*. Se o modelo **perder** para uma referência, essa \
                frase aparece na **primeira linha, noutra cor** — e não debaixo de uma tabela de números.
                """),
            .paragraph("""
                A razão: as ferramentas de previsão tendem a apresentar o modelo como um facto, e o \
                utilizador não tem forma de saber que «pegar simplesmente no número do mês passado» teria \
                sido mais exato.
                """),
            .heading("Três sítios onde o GEditor recusa, ou se declara"),
            .bullets([
                "**Sem dois ciclos completos volta ao método ingénuo.** Ajustar a sazonalidade ao ruído de um único ciclo e repeti-la para o futuro produz uma previsão muito convincente e totalmente inventada.",
                "**Se o MAPE topar com um zero di-lo**, e se mais de 25 % dos períodos forem zero retém a métrica — saltá-los em silêncio produz um número calculado sobre um subconjunto sistematicamente enviesado.",
                "**O intervalo de confiança declara-se aproximado**, e avisa que alarga demasiado devagar em horizontes longos.",
            ]),
            .note("""
                O período sazonal é detetado sobre a **primeira diferença**, não sobre a série em bruto: uma \
                tendência torna todos os desfasamentos muito correlacionados e afoga o pico sazonal.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Regras de associação",
        summary: "Compra A, muitas vezes compra B — e porque a tabela é ordenada por lift e não por confiança.",
        keywords: ["apriori", "regras de associação", "cesto", "lift", "suporte"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("São aceites duas formas de dados:"),
            .bullets([
                "**Um cesto por linha** — uma coluna com uma lista de artigos.",
                "**Duas colunas** — identificador de transação e artigo, um artigo por linha.",
            ]),
            .table(
                headers: ["Métrica", "Significado"],
                rows: [
                    ["suporte", "Proporção de cestos que contêm ambos os lados"],
                    ["confiança", "Dos cestos com o lado esquerdo, que proporção tem o direito"],
                    ["**lift**", "A confiança dividida pela taxa base do lado direito"],
                    ["leverage", "A distância face ao que a independência preveria"],
                ]
            ),
            .heading("Ordenado por lift, não por confiança"),
            .paragraph("""
                Se o lado direito aparece de qualquer modo em 95 % dos cestos, então **toda** a regra que \
                leve a ele tem cerca de 95 % de confiança — sem dizer absolutamente nada. Ordenar por \
                confiança põe no topo precisamente as regras mais vazias de sentido.
                """),
            .warning("""
                `lift < 1` é **assinalado na própria linha**: 80 % de confiança para algo com uma taxa base \
                de 95 % significa uma relação **inversa** — um número certo a levar a uma conclusão errada.
                """),
            .bullets([
                "Comprar dois pacotes de leite continua a ser **uma** transação com leite: os duplicados dentro de um cesto são descartados, ou o suporte incha com a quantidade.",
                "Pôr o limiar de suporte demasiado baixo faz o conjunto de candidatos explodir de forma combinatória; ao atingir o teto, o GEditor **para e declara a tabela incompleta**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Minerar por grupo",
        summary: "Repetir a análise de forma independente por grupo — o passo que mais vezes inverte uma conclusão.",
        keywords: ["por grupo", "simpson", "filiais", "comparar grupos"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Escolha uma coluna de texto como chave de agrupamento. Cada grupo recebe anomalias, previsão \
                e correlação executadas **de forma totalmente independente**, e depois ordenados pelo \
                critério que escolher.
                """),
            .heading("Porque os grupos devem ser separados e não agregados"),
            .paragraph("""
                Duas filiais, uma à volta de 10 e outra à volta de 100. Uma cerca de atípicos calculada \
                sobre a tabela **agregada** cai à volta de ±135 — e falha **nas duas direções**:
                """),
            .bullets([
                "**Falsos negativos**: um valor de 20, claramente anómalo para a filial pequena, fica bem dentro da cerca comum. Quantos mais grupos, mais cega fica.",
                "**Falsos positivos**: a um grupo muito disperso a cerca comum corta a cauda normal, e um monte de linhas vulgares fica assinalado.",
            ]),
            .heading("A coluna «divergência de correlação» apanha o paradoxo de Simpson"),
            .paragraph("""
                Três grupos em que **cada** grupo correlaciona as suas duas colunas a `−1`, e no entanto \
                agregados correlacionam a `> 0,9`. Quem leia só a tabela agregada conclui **exatamente o \
                contrário**. Esta coluna aponta precisamente para esses casos.
                """),
            .note("""
                O painel só oferece **colunas de texto** como chave de agrupamento e para aos 1000 grupos \
                com um aviso — para evitar que se escolha uma coluna de números de encomenda e cada linha \
                passe a ser um grupo próprio.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Mineração de texto",
        summary: "n-gramas e TF-IDF sobre uma coluna de texto — encontrar as expressões características.",
        keywords: ["mineração de texto", "n-grama", "tf-idf", "palavras-chave", "expressões"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Corre sobre uma coluna de texto — descrições de produto, opiniões de clientes, campos de \
                notas.
                """),
            .bullets([
                "**n-gramas** — as expressões de 1, 2 e 3 palavras mais frequentes.",
                "**TF-IDF** — palavras **características** de cada grupo de documentos, isto é, frequentes aqui e raras noutros sítios.",
            ]),
            .paragraph("""
                A diferença: os n-gramas dizem-lhe *«o que os clientes mencionam vezes sem conta»*, e o \
                TF-IDF diz-lhe *«em que é que este grupo difere dos outros»*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
