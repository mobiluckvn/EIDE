import Foundation

/// Contenu de l'aide en français — cinquième partie : rapports, connaissances, automatisation, application.
extension HelpFR {

    static let reports = HelpChapter(
        id: "bao-cao",
        title: "Rapports et schémas",
        summary: "Un fichier texte qui produit un rapport HTML dont les chiffres se recalculent, plus les schémas Mermaid.",
        topics: [greportFiles, queryBlock, chartBlock, qualityBlock, miningBlock, batchReports,
                 mermaid, mermaidSyntax]
    )

    static let greportFiles = HelpTopic(
        id: "bao-cao-greport",
        title: "Rapports `.greport.md`",
        summary: "Du Markdown plus quatre types de blocs exécutables — écrire à gauche, prévisualiser à droite.",
        keywords: ["rapport", "greport", "html", "export", "markdown"],
        commands: ["Báo cáo: xem trước"],
        blocks: [
            .paragraph("""
                Un fichier `.greport.md` est du **Markdown ordinaire** plus quelques blocs délimités \
                exécutables. Son rendu produit un fichier HTML **autonome** — pas de réseau, pas de \
                fichiers annexes — que n'importe qui peut ouvrir.
                """),
            .paragraph("""
                Comme c'est du texte brut, il peut être **comparé, versionné et partagé** — la même \
                philosophie que les recettes de nettoyage et les jeux de règles de qualité.
                """),
            .code(language: "markdown", caption: "sales-2026-08.greport.md — un rapport complet",
                  source: """
                    ---
                    title: Rapport des ventes d'août
                    source: sales-2026-08.csv
                    ---

                    # Rapport des ventes d'août

                    Chiffres au 31 août 2026.

                    ## Chiffre d'affaires par province

                    ```query
                    SELECT tinh, SUM(doanh_thu) AS doanh_thu, COUNT(*) AS so_don
                    FROM t
                    GROUP BY tinh
                    ORDER BY doanh_thu DESC
                    LIMIT 10
                    ```

                    ```chart
                    kind: bar
                    title: Chiffre d'affaires par province
                    y_label: Chiffre d'affaires
                    number_format: vi
                    suffix: " ₫"
                    source: Source — sales-2026-08.csv
                    ```

                    ## Qualité des données source

                    ```quality
                    rules_file: sales-standard.yaml
                    fail_under: 90
                    chart: violations
                    ```
                    """),
            .heading("Les types de blocs"),
            .table(
                headers: ["Bloc", "Produit"],
                rows: [
                    ["`query`", "Un tableau, à partir d'une instruction SQL DuckDB"],
                    ["`chart`", "Un graphique"],
                    ["`quality`", "Une fiche de notation de la qualité"],
                    ["`mining`", "Un tableau de classement d'exploration par groupe"],
                    ["`mermaid`", "Un schéma"],
                ]
            ),
            .heading("Frontmatter"),
            .paragraph("""
                Le bloc `---` en tête déclare `title` et `source` — la source de données par défaut \
                de tout bloc qui ne nomme pas la sienne.
                """),
            .note("""
                L'aperçu se reconstruit dès que vous cessez de taper, mais il **ne fait qu'analyser** \
                ; il n'exécute pas les requêtes à chaque frappe. Les erreurs de document et les \
                erreurs de données sont signalées séparément — *« il manque la clé `kind` au bloc \
                chart »* est une erreur de fichier, *« la colonne `doanh_thu` n'existe pas »* est une \
                erreur de données.
                """),
            .seeAlso(["khoi-query", "khoi-chart", "khoi-quality", "khoi-mining", "bao-cao-hang-loat"]),
        ]
    )

    static let queryBlock = HelpTopic(
        id: "khoi-query",
        title: "Le bloc `query`",
        summary: "Une instruction DuckDB devient un tableau dans le rapport.",
        keywords: ["requête", "sql", "tableau", "rapport", "bloc"],
        blocks: [
            .paragraph("""
                Le contenu du bloc est **une instruction SQL**, exécutée sur la source du rapport. La \
                table s'appelle `t`, dans le même dialecte que le panneau de requêtes.
                """),
            .code(language: "text", caption: "Un bloc query paramétré",
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
                `:thang` est un **paramètre**. Il est fourni au moment du rendu — depuis le shell avec \
                `--param thang=8`, ou depuis un fichier de liste lors d'une génération en lot.
                """),
            .note("""
                Les tableaux d'un rapport de données **devraient venir d'un bloc query**, non être \
                saisis à la main. Un tableau saisi à la main ne se recalcule pas quand les chiffres \
                changent, et tôt ou tard il contredit le reste du rapport.
                """),
            .seeAlso(["truy-van-sql", "khoi-chart", "bao-cao-hang-loat"]),
        ]
    )

    static let chartBlock = HelpTopic(
        id: "khoi-chart",
        title: "Le bloc `chart`",
        summary: "Une configuration YAML devient un graphique — et la règle la plus importante du format.",
        keywords: ["graphique", "yaml", "rapport", "tracé"],
        blocks: [
            .code(language: "yaml", caption: "Chaque clé d'un bloc chart",
                  source: """
                    kind: bar                 # bar · line · pie · scatter
                    query: SELECT tinh, SUM(doanh_thu) AS dt FROM t GROUP BY tinh ORDER BY dt DESC
                    title: Chiffre d'affaires par province
                    x_label: Province
                    y_label: Chiffre d'affaires
                    number_format: vi         # vi · en
                    decimals: 0
                    suffix: " ₫"
                    theme: brand
                    source: Source — sales.csv, au 26 août 2026
                    """),
            .heading("Sans `query`, il utilise le résultat du bloc query JUSTE AU-DESSUS"),
            .paragraph("""
                C'est la règle la plus importante du format. Grâce à elle, le rapport courant « un \
                tableau puis un graphique de ce tableau » ne répète pas le SQL — et le répéter \
                signifie que les deux copies finissent par diverger, moment où le tableau et le \
                graphique disent des choses différentes sur la même page.
                """),
            .warning("""
                En contrepartie, **l'ordre des blocs compte** : insérer un bloc query entre les deux \
                change les données du graphique qui suit.
                """),
            .heading("Pourquoi `source` est une clé à part"),
            .paragraph("""
                Une mention de source écrite en prose sous le graphique s'affiche très bien — à \
                l'écran. Mais le graphique sera exporté en PNG et collé ailleurs, et la prose reste \
                en arrière. Comme clé, elle est dessinée **dans l'image** et voyage avec elle.
                """),
            .seeAlso(["khoi-query", "pivot-va-bieu-do"]),
        ]
    )

    static let qualityBlock = HelpTopic(
        id: "khoi-quality",
        title: "Le bloc `quality`",
        summary: "Une fiche de notation de la qualité des données au sein du rapport.",
        keywords: ["qualité", "fiche", "rapport", "bloc"],
        blocks: [
            .code(language: "yaml", caption: "Chaque clé d'un bloc quality",
                  source: """
                    rules_file: sales-standard.yaml
                    source: sales-08.csv        # vide = la source propre du rapport
                    title: Qualité des données de vente d'août
                    rules: true                 # afficher le tableau règle par règle
                    chart: violations           # violations · dimensions · none
                    now: 2026-08-26             # fixer la date de référence de « Fraîcheur »
                    fail_under: 90              # en dessous, la fiche vire à la couleur d'alerte
                    """),
            .table(
                headers: ["`chart`", "Dessine"],
                rows: [
                    ["`violations`", "Le nombre de lignes pour les règles **en échec** — répond à « que corriger d'abord »"],
                    ["`dimensions`", "Les notes des six dimensions"],
                    ["`none`", "Tableau seul, pas de graphique"],
                ]
            ),
            .note("""
                Renseignez `now:` dans un rapport périodique. Sans lui, la *Fraîcheur* se compare au \
                moment du rendu : refaire le rendu du rapport du mois dernier donne une note \
                différente de celle que vous avez publiée.
                """),
            .seeAlso(["cham-chat-luong", "cu-phap-gquality"]),
        ]
    )

    static let miningBlock = HelpTopic(
        id: "khoi-mining",
        title: "Le bloc `mining`",
        summary: "Classer les groupes par anomalies, erreur de prévision ou divergence de corrélation.",
        keywords: ["exploration", "rapport", "classement de groupes"],
        blocks: [
            .code(language: "yaml", caption: "Chaque clé d'un bloc mining",
                  source: """
                    group_by: tinh
                    value: doanh_thu          # la colonne des anomalies et de la prévision
                    pair: chi_phi             # une seconde colonne, pour la corrélation par groupe
                    rank: anomalies           # anomalies · forecast_error · correlation_gap
                    limit: 10
                    horizon: 4
                    iqr_k: 1.5
                    min_rows: 8
                    source: sales.csv         # vide = la source propre du rapport
                    title: Exploration par province
                    chart: true
                    """),
            .table(
                headers: ["`rank`", "Classe par"],
                rows: [
                    ["`anomalies`", "Le groupe ayant le plus de lignes anormales"],
                    ["`forecast_error`", "Le groupe dont la prévision est la pire"],
                    ["`correlation_gap`", "Le groupe dont la corrélation diverge le plus du tableau agrégé — attrape le paradoxe de Simpson"],
                ]
            ),
            .warning("""
                **Aucune clé ne désactive le bloc « Méthode ».** Un classement de groupes sans sa \
                méthode ne laisse au lecteur aucun moyen de savoir contre quelle barrière « le plus \
                d'anomalies » a été mesuré. Qui veut le masquer connaît déjà la réponse qu'il veut.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let batchReports = HelpTopic(
        id: "bao-cao-hang-loat",
        title: "Générer des rapports en lot",
        summary: "Un modèle, une liste de paramètres, de nombreux rapports.",
        keywords: ["lot", "en masse", "paramètres", "param"],
        commands: ["Báo cáo: sinh loạt…"],
        blocks: [
            .paragraph("""
                Un modèle de rapport, exécuté pour chaque agence ou chaque mois. La liste de \
                paramètres est un fichier CSV ou JSON — **une ligne par rapport**.
                """),
            .code(language: "text", caption: "list.csv — une ligne par rapport",
                  source: """
                    thang,tinh
                    8,Hà Nội
                    8,Đà Nẵng
                    8,TP Hồ Chí Minh
                    """),
            .code(language: "bash", caption: "Rendre tout le lot depuis le shell",
                  source: """
                    geditor --report template.greport.md \\
                            --param-list list.csv \\
                            --out ./reports-2026-08/
                    """),
            .code(language: "bash", caption: "Ou un seul rapport, paramètres passés à la main",
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
        title: "Schémas Mermaid",
        summary: "Dessiner des schémas en texte, les modifier par commandes, prévisualiser dans les deux sens.",
        keywords: ["mermaid", "schéma", "organigramme", "séquence", "dessiner"],
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
                Mermaid dessine des schémas **à partir de texte** : vous écrivez une description, la \
                machine la dessine. Un schéma peut donc être comparé et versionné — ce qu'un fichier \
                image ne peut pas.
                """),
            .paragraph("""
                Ouvrez `Schéma Mermaid : aperçu` pour une vue à côté de l'éditeur. Les deux sont \
                **synchronisés dans les deux sens** : sélectionnez un élément dans l'image et le \
                curseur saute à sa ligne.
                """),
            .heading("Modifier par commandes, pas en retapant"),
            .table(
                headers: ["Commande", "Ce qu'elle fait"],
                rows: [
                    ["Insérer un modèle…", "Insérer un squelette prêt pour chaque type de schéma"],
                    ["Ajouter un élément…", "Ajouter un nœud ou un participant"],
                    ["Relier les deux éléments sélectionnés", "Tracer une flèche entre eux"],
                    ["Modifier l'étiquette de l'élément sélectionné…", "Changer le texte sans chercher la ligne"],
                    ["Supprimer l'élément sélectionné", "Retirer le nœud **et** chaque arête qui le touche"],
                    ["Monter / descendre le message", "Réordonner les étapes d'un diagramme de séquence"],
                    ["Reformater", "Indenter et aligner tout le bloc"],
                ]
            ),
            .heading("Extraire vers un fichier et le réintégrer"),
            .paragraph("""
                Les grands schémas méritent leur propre fichier `.mmd` : `Extraire le bloc vers un \
                fichier .mmd…` le déplace et laisse une référence. `Réintégrer le fichier référencé` \
                fait l'inverse quand vous devez envoyer un fichier unique.
                """),
            .seeAlso(["cu-phap-mermaid", "bao-cao-greport"]),
        ]
    )

    static let mermaidSyntax = HelpTopic(
        id: "cu-phap-mermaid",
        title: "Syntaxe Mermaid courante",
        summary: "Les quatre types de schémas les plus utilisés, chacun avec un modèle qui s'exécute.",
        keywords: ["mermaid", "syntaxe", "organigramme", "séquence", "gantt", "classe", "modèle"],
        blocks: [
            .code(language: "mermaid", caption: "Organigramme — un processus d'approbation de commande",
                  source: """
                    flowchart TD
                        A[Nhận đơn] --> B{Đủ hàng?}
                        B -- Có --> C[Xuất kho]
                        B -- Không --> D[Đặt bổ sung]
                        D --> E[Chờ nhà cung cấp]
                        E --> C
                        C --> F([Giao khách])
                    """),
            .code(language: "mermaid", caption: "Diagramme de séquence — un flux de paiement",
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
            .code(language: "mermaid", caption: "Diagramme de classes — un modèle de données",
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
            .code(language: "mermaid", caption: "Gantt — un plan de publication",
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
                headers: ["Forme de nœud", "Écrire"],
                rows: [
                    ["Rectangle", "`A[Label]`"],
                    ["Coins arrondis", "`A(Label)`"],
                    ["Stade", "`A([Label])`"],
                    ["Losange (décision)", "`A{Label}`"],
                    ["Cylindre (données)", "`A[(Label)]`"],
                ]
            ),
            .table(
                headers: ["Flèche", "Écrire"],
                rows: [
                    ["Pleine, avec pointe", "`A --> B`"],
                    ["Pointillée", "`A -.-> B`"],
                    ["Épaisse", "`A ==> B`"],
                    ["Étiquetée", "`A -- label --> B`"],
                ]
            ),
            .note("""
                La direction d'un organigramme suit immédiatement `flowchart` : `TD` de haut en bas, \
                `LR` de gauche à droite, plus `BT` et `RL`.
                """),
            .seeAlso(["mermaid"]),
        ]
    )

    // MARK: - Pack de connaissances

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "Le pack de connaissances",
        summary: "Découpage, index de recherche, graphes de connaissances, entités et évaluation de la recherche.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "Ce qu'est le pack de connaissances",
        summary: "Des outils pour préparer et vérifier des données destinées à un système de questions-réponses sur documents.",
        keywords: ["rag", "connaissances", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                Quand on bâtit un système qui répond à des questions à partir d'un corpus de \
                documents, l'essentiel du travail n'est pas dans le modèle mais dans la **préparation \
                des données** : découper les documents en passages sensés, vérifier la qualité de ces \
                passages, construire un index, et **mesurer si la recherche trouve vraiment la bonne \
                chose**.
                """),
            .paragraph("""
                Ce chapitre est exactement l'outillage pour cela. Il tourne **entièrement sur votre \
                machine** et n'appelle jamais le réseau.
                """),
            .table(
                headers: ["Tâche", "Outil"],
                rows: [
                    ["Découper des documents en passages", "Aperçu du découpage"],
                    ["Inspecter et noter des passages", "Inspection de chunks JSONL"],
                    ["Convertir entre formes de données", "Conversion de connaissances"],
                    ["Construire et inspecter un graphe de relations", "Graphe de connaissances"],
                    ["Trouver les noms propres dans un texte", "Marquage d'entités"],
                    ["Mesurer la qualité de la recherche", "Laboratoire de recherche"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Découper et inspecter un corpus JSONL",
        summary: "Prévisualiser les limites de découpage sur le texte lui-même, puis noter tout le corpus.",
        keywords: ["chunk", "jsonl", "corpus", "chevauchement", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Aperçu du découpage"),
            .paragraph("""
                Ouvrez un document texte ou Markdown, choisissez une stratégie et une taille de bloc. \
                Les limites sont **surlignées sur le texte lui-même** : vous voyez où une coupe tombe \
                au milieu d'une phrase ou traverse un tableau avant de rien exporter.
                """),
            .bullets([
                "**Taille fixe** avec chevauchement.",
                "**Par structure** — sur les titres Markdown, en gardant intact le fil du document.",
                "**Par paragraphe**, en fusionnant jusqu'à atteindre la taille.",
            ]),
            .heading("Inspecter un corpus JSONL existant"),
            .paragraph("""
                Pour un corpus que vous avez déjà (un chunk JSON par ligne), `JSONL : inspecter les \
                chunks…` répond : quelles lignes ne sont pas du JSON valide, quels chunks sont trop \
                courts ou trop longs, lesquels se dupliquent, et lesquels ont été coupés en pleine \
                phrase.
                """),
            .note("""
                Un corpus peut aussi être noté avec le **même cadre à six dimensions** que les \
                données tabulaires — utilisez la clé `corpus:` dans un bloc `quality` de rapport.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Convertir des formats de connaissances",
        summary: "Chunks entre JSONL · CSV · Markdown, graphes entre DOT · Mermaid · listes d'arêtes.",
        keywords: ["convertir", "jsonl", "dot", "mermaid", "liste d'arêtes"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["De", "Vers"],
                rows: [
                    ["Chunks JSONL", "CSV · Markdown"],
                    ["Chunks CSV", "JSONL · Markdown"],
                    ["Graphe DOT", "Mermaid · liste d'arêtes"],
                    ["Liste d'arêtes", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                Il y a un **aperçu de cinq lignes** avant la création du nouvel onglet, le même \
                mécanisme que la conversion CSV.
                """),
            .paragraph("""
                `Ouvrir les triplets/arêtes en tableau` montre un fichier de triplets ou une liste \
                d'arêtes en grille — filtrez et triez comme n'importe quel CSV.
                """),
            .note("""
                Le sens **Markdown → JSONL** n'est pas dans cette commande : ce sens-là *est* le \
                découpage, et la commande vous y renvoie. Deux implémentations d'une même coupe \
                produiraient deux résultats différents.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Graphes de connaissances",
        summary: "Vérifier la syntaxe, noter la santé, et exécuter des algorithmes sur des graphes d'un million d'arêtes.",
        keywords: ["graphe", "dot", "cypher", "pagerank", "louvain", "vérification de syntaxe"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor lit les graphes en **DOT**, en **listes d'arêtes** et en **triplets**. \
                `Vérifier la syntaxe du graphe` attrape les erreurs de syntaxe, les nœuds pendants et \
                les arêtes pointant vers des nœuds inexistants.
                """),
            .heading("Algorithmes disponibles"),
            .table(
                headers: ["Algorithme", "Répond à"],
                rows: [
                    ["Voisinage à k sauts", "Ce qui est lié à ce nœud en k pas"],
                    ["Composantes connexes", "Combien de morceaux disjoints a le graphe"],
                    ["PageRank", "Quels nœuds sont importants"],
                    ["Louvain", "Comment le graphe se divise en communautés"],
                ]
            ),
            .paragraph("""
                Sur un graphe d'**un million d'arêtes**, les quatre s'exécutent entre quelques \
                millisecondes et environ une seconde.
                """),
            .note("""
                Un graphe peut aussi être noté avec le **cadre à six dimensions** employé pour les \
                tableaux et les corpus — utilisez la clé `graph:` dans un bloc `quality`.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Marquer des entités depuis une liste",
        summary: "Charger une liste de noms propres et trouver chaque occurrence — sous trois règles pensées pour le vietnamien.",
        keywords: ["entité", "nom propre", "ner", "marquage", "correspondance"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Chargez une liste de noms (entreprises, produits, lieux) et GEditor surligne chaque \
                occurrence dans le document, avec un tableau de comptes.
                """),
            .heading("Trois règles de correspondance, toutes issues de données vietnamiennes"),
            .bullets([
                "**La plus longue correspondance l'emporte.** Avec `An Phát` et `Công ty An Phát` tous deux dans la liste, une phrase contenant l'expression la plus longue doit correspondre à la plus longue — sinon elle est coupée en deux et comptée pour deux entités, ce qui **gonfle** les statistiques.",
                "**Les limites de mot sont exigées.** `An` ne doit pas correspondre à l'intérieur de `Anh` ou `Hoàn`. Les noms propres vietnamiens sont courts et partagent des syllabes avec d'innombrables mots ordinaires.",
                "**Insensible à la casse, mais SENSIBLE aux accents.** `CÔNG TY` et `Công ty` sont un seul ; `má` et `ma` ne le sont pas.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Résoudre les variantes d'entités",
        summary: "Reconnaître `Cty An Phát` et `Công ty An Phát` comme une seule — en vous laissant quand même la décision.",
        keywords: ["résolution d'entités", "variantes", "normalisation de noms", "doublons"],
        blocks: [
            .paragraph("""
                Le même regroupement que les **doublons approchés** dans une grille CSV — une seule \
                implémentation partagée, pas deux.
                """),
            .paragraph("""
                La sortie est une **proposition** : vous examinez chaque grappe et choisissez la forme \
                canonique. Il n'y a pas de bouton « tout fusionner », car deux noms semblables à 92 % \
                peuvent être deux organisations réelles.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "Le laboratoire de recherche",
        summary: "Mesurer si l'index trouve la bonne chose, à l'aide d'un jeu de questions avec réponses.",
        keywords: ["recherche", "bm25", "rappel", "mrr", "ndcg", "évaluation"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Chargez un **jeu d'évaluation** — chaque ligne une question avec les identifiants de \
                chunks qui devraient être renvoyés — puis lancez tout le lot contre l'index.
                """),
            .table(
                headers: ["Métrique", "Répond à"],
                rows: [
                    ["recall@k", "Quelle part de l'ensemble de réponses figure dans les k premiers"],
                    ["MRR", "À quelle profondeur se trouve le premier résultat correct"],
                    ["nDCG@k", "Si le classement est bon, position comprise"],
                ]
            ),
            .paragraph("""
                Les résultats viennent aussi **par question**, les pires d'abord — c'est votre liste \
                de choses à corriger dans le corpus, dans l'ordre le plus rentable.
                """),
            .warning("""
                Les trois métriques sont des **moyennes**, et une moyenne cache beaucoup. Lisez \
                toujours le tableau par question avant de conclure que « l'index est assez bon ».
                """),
            .paragraph("""
                Deux configurations peuvent être comparées côte à côte, et le résultat se dépose \
                directement dans un rapport `.greport.md` pour que la prochaine exécution soit \
                identique.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )

    // MARK: - Macros et automatisation

    static let automation = HelpChapter(
        id: "tu-dong-hoa",
        title: "Macros et automatisation",
        summary: "Enregistrer des actions, les exécuter en lot, écrire des scripts, et piloter depuis le shell.",
        topics: [macroBasics, macroBatch, macroSyntax, scripting, externalFilter,
                 commandLine, appleScript, plugins]
    )

    static let macroBasics = HelpTopic(
        id: "macro-co-ban",
        title: "Enregistrer et jouer des macros",
        summary: "Enregistrer une séquence et la répéter — toute l'exécution est une seule annulation.",
        keywords: ["macro", "enregistrer", "rejouer", "répéter", "automatiser"],
        commands: ["Bắt đầu / dừng ghi", "Phát lại", "Phát nhiều lần…", "Phát đến cuối tài liệu",
                   "Hủy macro đang chạy", "Lưu macro…", "Macro đã lưu…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌃R", "Démarrer / arrêter l'enregistrement"),
                HelpShortcut("⌃P", "Rejouer"),
            ]),
            .steps([
                "`⌃R` démarre l'enregistrement.",
                "Faites la chose à répéter — taper, déplacer le curseur, chercher, remplacer.",
                "`⌃R` de nouveau pour arrêter.",
                "`⌃P` la rejoue, ou `Macro ▸ Jouer jusqu'à la fin du document` l'exécute jusqu'au bout.",
                "`Macro ▸ Enregistrer la macro…` la nomme pour les sessions suivantes.",
            ]),
            .heading("Elle enregistre des COMMANDES, pas des frappes brutes"),
            .paragraph("""
                Une macro stocke **ce que vous avez fait**, non les touches pressées. Cela la rend \
                indépendante de la disposition du clavier et de la méthode de saisie active, et cela \
                rend le fichier de macro **lisible** quand vous l'ouvrez.
                """),
            .heading("Quand une macro s'arrête"),
            .table(
                headers: ["Raison", "Signification"],
                rows: [
                    ["Le compte de répétitions est épuisé", "Normal"],
                    ["Une étape `find` n'a rien trouvé", "C'est ainsi que « jouer jusqu'à la fin du fichier » s'arrête"],
                    ["Fin du document atteinte", "Nulle part où aller plus loin"],
                    ["Vous avez annulé", "`Macro ▸ Annuler la macro en cours`"],
                    ["Une itération n'a rien changé ni bougé", "Arrêtée pour ne pas boucler indéfiniment"],
                ]
            ),
            .note("Toute l'exécution — même dix mille répétitions — est **une seule** étape d'annulation."),
            .seeAlso(["macro-cu-phap", "macro-chay-hang-loat"]),
        ]
    )

    static let macroBatch = HelpTopic(
        id: "macro-chay-hang-loat",
        title: "Exécuter une macro en lot",
        summary: "Sur tous les onglets ouverts, ou sur un dossier de fichiers non ouverts.",
        keywords: ["lot", "tous les onglets", "dossier", "macro", "masque"],
        commands: ["Chạy trên mọi tab", "Chạy trên cả thư mục…"],
        blocks: [
            .table(
                headers: ["Commande", "Portée", "Annulable"],
                rows: [
                    ["Exécuter sur tous les onglets", "Les onglets ouverts", "Oui — une annulation par onglet"],
                    ["Exécuter sur tout un dossier…", "Des fichiers **non ouverts** sur le disque", "Non"],
                ]
            ),
            .warning("""
                Exécuter sur un dossier touche des fichiers ouverts dans aucun onglet : il n'y a donc \
                **pas d'annulation**. Par défaut, GEditor **écrit de nouveaux fichiers** plutôt que \
                d'écraser les originaux. Gardez ce réglage sauf si vous avez une sauvegarde ou un \
                dépôt versionné.
                """),
            .heading("Filtrer les fichiers par un masque"),
            .paragraph("""
                Le sélecteur de dossier a un **filtre de nom de fichier** : tapez `*.csv;*.log` et la \
                macro ne touche que ceux-là. C'est la même syntaxe de masque que `Rechercher dans un \
                dossier`, plusieurs motifs séparés par `;` ou `,`.
                """),
            .bullets([
                "Laissez-le **vide** et il prend tout fichier texte que GEditor sait lire — le comportement d'avant.",
                "Le masque **remplace** cette liste d'extensions au lieu de la restreindre : tapez `*.bak` et il s'exécute sur les fichiers `.bak`, même si cette extension n'est pas dans la liste des textes.",
                "Si rien ne correspond, le message **vous répète le masque** au lieu d'accuser un dossier vide.",
            ]),
            .paragraph("""
                Cette case a une raison très pratique : un dossier contient 400 fichiers `.json` et \
                12 fichiers `.log`, et votre macro ne range que des journaux. Sans masque, les 400 \
                autres sont traités aussi — et comme le lot écrit de nouveaux fichiers, une erreur \
                laisse 400 déchets.
                """),
            .seeAlso(["macro-co-ban", "dong-lenh", "tim-trong-thu-muc"]),
        ]
    )

    static let macroSyntax = HelpTopic(
        id: "macro-cu-phap",
        title: "Syntaxe des fichiers de macro",
        summary: "Sept types d'étapes, le format JSON complet, et deux macros qui s'exécutent.",
        keywords: ["macro", "json", "syntaxe", "format", "modifier à la main", "partager"],
        blocks: [
            .paragraph("""
                Chaque macro est **son propre fichier JSON** dans le dossier `macros/` de GEditor. Une \
                corruption reste confinée à une macro, et en partager une avec un collègue, c'est \
                envoyer un fichier.
                """),
            .code(language: "text", caption: "Où vivent les fichiers",
                  source: "~/Library/Application Support/GEditor/macros/<nom-de-macro>.json"),
            .heading("Les sept types d'étapes"),
            .table(
                headers: ["Étape", "Écrite comme", "Signification"],
                rows: [
                    ["Insérer du texte", "`{\"insert\": {\"_0\": \"texte\"}}`", "Taper au curseur ; avec une sélection, la remplace"],
                    ["Supprimer en arrière", "`{\"deleteBackward\": {}}`", "Comme la touche Suppr"],
                    ["Supprimer en avant", "`{\"deleteForward\": {}}`", "Comme ⌦"],
                    ["Déplacer", "`{\"move\": {\"_0\": \"nextLine\"}}`", "Voir la liste des directions ci-dessous"],
                    ["Sélectionner la ligne", "`{\"selectLine\": {}}`", "Sans le saut de ligne"],
                    ["Chercher", "`{\"find\": { … }}`", "Trouve et **sélectionne** l'occurrence suivante"],
                    ["Remplacer la sélection", "`{\"replaceSelection\": {\"_0\": \"…\"}}`", "`$1` marche si l'étape précédente était un `find` en regex"],
                ]
            ),
            .heading("Directions de déplacement"),
            .paragraph("""
                `left` · `right` · `up` · `down` · `lineStart` · `lineEnd` · `nextLine` · \
                `previousLine` · `documentStart` · `documentEnd`
                """),
            .heading("L'étape `find` complète"),
            .code(language: "json", caption: "Les quatre clés d'une étape find",
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
            .paragraph("`mode` prend `normal`, `extended` ou `regex` — les trois mêmes modes que le champ de recherche."),
            .heading("Exemple 1 — mettre en majuscules le code de province en début de ligne"),
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
                Exécutez-la avec `Macro ▸ Jouer jusqu'à la fin du document` : l'étape `find` ne \
                trouvant plus rien est exactement la condition d'arrêt.
                """),
            .heading("Exemple 2 — supprimer la ligne qui suit chaque ligne contenant TODO"),
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
                Testez d'abord une macro modifiée à la main sur une copie. Une étape `find` mal tapée \
                fait s'arrêter la macro aussitôt — c'est le cas bénin. Le cas malin est un motif qui \
                correspond plus largement que vous ne le pensiez, modifiant des milliers d'endroits \
                dans une seule étape d'annulation.
                """),
            .seeAlso(["macro-co-ban", "bieu-thuc-chinh-quy", "chuoi-thay-the"]),
        ]
    )

    static let scripting = HelpTopic(
        id: "script",
        title: "Scripts JavaScript",
        summary: "Quatre fonctions, un fichier `.js`, et tout ce qu'il fait est une seule annulation.",
        keywords: ["script", "javascript", "js", "automatiser", "api"],
        commands: ["Script…"],
        blocks: [
            .paragraph("""
                Placez un fichier `.js` dans le dossier `scripts/` de GEditor et exécutez-le depuis \
                `Macro ▸ Script…`. Un script voit exactement **quatre** choses :
                """),
            .table(
                headers: ["Appel", "Signification"],
                rows: [
                    ["`doc.text`", "Tout le texte du document"],
                    ["`doc.selection`", "La sélection (chaîne vide si rien n'est sélectionné)"],
                    ["`doc.replace(s)`", "Remplacer le **document entier** par `s` — une seule annulation"],
                    ["`doc.log(s)`", "Écrire une ligne dans le panneau de résultats"],
                ]
            ),
            .code(language: "javascript", caption: "scripts/number-lines.js",
                  source: """
                    // Numéroter chaque ligne.
                    var lines = doc.text.split("\\n");
                    var out = [];
                    for (var i = 0; i < lines.length; i++) {
                        if (i === lines.length - 1 && lines[i] === "") { out.push(""); continue; }
                        out.push((i + 1) + ". " + lines[i]);
                    }
                    doc.log("Numbered " + (lines.length - 1) + " lines");
                    doc.replace(out.join("\\n"));
                    """),
            .code(language: "javascript", caption: "scripts/keep-three-columns.js — garder les trois premières colonnes CSV",
                  source: """
                    var out = doc.text.split("\\n").map(function (line) {
                        if (line === "") { return line; }
                        return line.split(",").slice(0, 3).join(",");
                    });
                    doc.log("Trimmed " + out.length + " lines to 3 columns");
                    doc.replace(out.join("\\n"));
                    """),
            .heading("Trois limites à connaître"),
            .bullets([
                "**Pas d'accès aux fichiers, pas de réseau, pas de lancement de processus.** La surface d'API est délibérément étroite : l'élargir plus tard est facile, la rétrécir casse tous les scripts déjà écrits.",
                "**Ce n'est pas une frontière de sécurité.** Les scripts tournent dans le même processus. N'exécutez pas un script que vous n'avez pas lu.",
                "**Il y a une limite de cinq secondes.** Au-delà, vous recevez un message et l'application reste utilisable — mais le fil de ce script **continue de tourner jusqu'à ce que vous quittiez**, occupant un cœur. Le message le dit.",
            ]),
            .seeAlso(["plugin", "macro-cu-phap"]),
        ]
    )

    static let externalFilter = HelpTopic(
        id: "loc-qua-lenh-ngoai",
        title: "Filtrer par une commande externe",
        summary: "Envoyer la sélection dans un tuyau vers une commande Unix et reprendre le résultat.",
        keywords: ["filtre", "commande externe", "shell", "tuyau", "sort", "jq", "unix"],
        commands: ["Lọc qua lệnh ngoài…"],
        blocks: [
            .paragraph("""
                La sélection (ou tout le document) est passée au `stdin` d'une commande, et le \
                `stdout` de cette commande la remplace.
                """),
            .code(language: "bash", caption: "Quelques commandes courantes",
                  source: """
                    sort -u                     # trier et retirer les doublons
                    jq .                        # reformater du JSON
                    tr 'a-z' 'A-Z'              # majuscules
                    grep -v '^#'                # retirer les lignes de commentaire
                    awk -F, '{print $3","$1}'   # échanger l'ordre des colonnes
                    """),
            .note("""
                Le résultat est **une seule** étape d'annulation. Si la commande renvoie un code \
                d'erreur, GEditor laisse le texte tel quel et affiche `stderr`.
                """),
            .warning("""
                Cette commande n'existe **que dans la version en téléchargement direct**. L'App \
                Sandbox interdit d'exécuter du code hors de l'application : dans la version App \
                Store, l'élément de menu reste et explique pourquoi il est indisponible.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script"]),
        ]
    )

    static let commandLine = HelpTopic(
        id: "dong-lenh",
        title: "L'outil en ligne de commande `geditor`",
        summary: "Ouvrir, nettoyer, interroger, noter et rendre des rapports — sans ouvrir l'application.",
        keywords: ["cli", "ligne de commande", "terminal", "geditor", "script", "ci"],
        blocks: [
            .warning("""
                Disponible seulement dans la **version en téléchargement direct**. La version App \
                Store tourne dans un bac à sable : un processus externe en ligne de commande ne peut \
                pas s'y connecter.
                """),
            .heading("Ouvrir des fichiers"),
            .code(language: "bash", caption: "Ouvrir, sauter à une position, lire depuis un tuyau",
                  source: """
                    geditor report.csv
                    geditor report.csv:120:5       # ligne 120, colonne 5
                    geditor -w notes.md            # attendre la fermeture du fichier avant de quitter
                    geditor -r app.log             # ouvrir en lecture seule
                    git diff | geditor             # lire l'entrée standard dans un nouvel onglet
                    """),
            .table(
                headers: ["Option", "Signification"],
                rows: [
                    ["`-w`, `--wait`", "Attendre la fermeture du fichier avant de quitter — pour servir d'éditeur à `git`"],
                    ["`-n`, `--new-window`", "Ouvrir dans une nouvelle fenêtre"],
                    ["`-r`, `--read-only`", "Ouvrir en lecture seule"],
                    ["`-i`, `--info`", "Afficher encodage, fins de ligne et nombre de lignes, puis quitter — **sans** ouvrir l'application"],
                    ["`-h`, `--help`", "Afficher l'aide"],
                    ["`-v`, `--version`", "Afficher la version"],
                ]
            ),
            .heading("Exécuter sans ouvrir l'application"),
            .paragraph("""
                Les quatre groupes de commandes ci-dessous s'exécutent **entièrement dans le \
                processus en ligne de commande** : ils fonctionnent donc en CI, où personne n'est \
                connecté à une session graphique.
                """),
            .code(language: "bash", caption: "Nettoyer avec une recette",
                  source: """
                    geditor --recipe standard.json --dry-run sales-*.csv
                    geditor --recipe standard.json --out ./clean/ sales-*.csv
                    geditor --recipe standard.json --overwrite sales-08.csv
                    """),
            .code(language: "bash", caption: "Interroger",
                  source: """
                    geditor --query summary.sql --param thang=8 \\
                            --format md --out result.md sales.csv
                    """),
            .code(language: "bash", caption: "Le portail de qualité — code 0 réussite · 1 échec · 2 erreur",
                  source: """
                    geditor --quality standard.yaml --fail-under 90 \\
                            --json - --record-history --now 2026-09-01 \\
                            sales-09.csv
                    """),
            .code(language: "bash", caption: "Rendre des rapports",
                  source: "geditor --report template.greport.md --param-list list.csv --out ./reports/"),
            .seeAlso(["cong-thuc-lam-sach", "cong-chat-luong", "bao-cao-hang-loat", "hai-ban-phat-hanh"]),
        ]
    )

    static let appleScript = HelpTopic(
        id: "apple-script",
        title: "AppleScript et le menu Services",
        summary: "Lire et écrire le document depuis AppleScript, ou envoyer du texte à GEditor depuis une autre application.",
        keywords: ["applescript", "osascript", "services", "automatisation", "raccourcis"],
        blocks: [
            .code(language: "applescript", caption: "Lire le document ouvert",
                  source: """
                    tell application "GEditor"
                        get document text
                    end tell
                    """),
            .code(language: "applescript", caption: "Écraser le contenu, et lire la sélection",
                  source: """
                    tell application "GEditor"
                        set selected text to "text to put in place of the selection"
                        set contents to document text
                        get document path
                    end tell
                    """),
            .code(language: "applescript", caption: "Ouvrir un fichier",
                  source: """
                    tell application "GEditor"
                        open POSIX file "/Users/you/report.csv"
                    end tell
                    """),
            .heading("Le menu Services"),
            .paragraph("""
                Sélectionnez du texte dans n'importe quelle application, puis utilisez le menu \
                `Services` pour l'envoyer à GEditor comme nouvel onglet.
                """),
            .note("""
                La première fois que vous exécutez de l'AppleScript, macOS demande l'autorisation \
                d'automatisation. C'est la boîte de dialogue du système, pas celle de GEditor.
                """),
            .seeAlso(["dong-lenh", "script"]),
        ]
    )

    static let plugins = HelpTopic(
        id: "plugin",
        title: "Paquets d'extension et modules externes",
        summary: "Deux sortes d'extensions, et dans quelle version chacune s'exécute.",
        keywords: ["module", "extension", "paquet", "natif"],
        commands: ["Gói mở rộng…", "Plugin native…"],
        blocks: [
            .heading("Paquets d'extension"),
            .paragraph("""
                Un paquet est **un seul fichier JSON** réunissant un thème, des scripts et des \
                langages définis par l'utilisateur. Installer copie un fichier, retirer en supprime \
                un — et la liste des paquets est dérivée du **disque**, non d'un registre qui \
                pourrait mentir.
                """),
            .paragraph("Fonctionne dans les **deux versions**."),
            .heading("Modules externes natifs"),
            .paragraph("""
                Les modules précompilés tournent dans un **processus séparé** avec une surface d'API \
                étroite — un module qui plante n'emporte pas l'application avec lui.
                """),
            .warning("""
                Les modules natifs n'existent que dans la **version en téléchargement direct**, car \
                l'App Sandbox interdit de charger du code venu d'ailleurs que l'application. Chaque \
                module doit être **approuvé à la main une fois**, par empreinte, avant de s'exécuter.
                """),
            .seeAlso(["hai-ban-phat-hanh", "script", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    // MARK: - Configuration et application

    static let application = HelpChapter(
        id: "ung-dung",
        title: "Configuration et application",
        summary: "Réglages, raccourcis, thèmes, mises à jour, migration depuis Notepad++, dépannage.",
        topics: [settings, statusBar, keyBindings, themes, updatesAndAbout, usingHelp,
                 notepadppMigration, troubleshooting]
    )

    static let settings = HelpTopic(
        id: "cai-dat",
        title: "Réglages",
        summary: "Chaque option vit dans un fichier JSON lisible que vous pouvez copier sur un autre Mac.",
        keywords: ["réglages", "préférences", "options", "configuration", "json"],
        commands: ["Cài đặt…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘,", "Ouvrir les réglages")]),
            .paragraph("""
                Il n'y a ni OK ni Annuler — un changement prend effet et est écrit aussitôt, à la \
                façon de macOS.
                """),
            .heading("Le fichier de configuration"),
            .code(language: "text", caption: "Où il vit",
                  source: "~/Library/Application Support/GEditor/settings.json"),
            .paragraph("""
                C'est un **fichier JSON indenté que vous pouvez lire et modifier à la main**. \
                Copiez-le sur un autre Mac et toute votre configuration suit. Le bouton `Ouvrir le \
                fichier de configuration` des réglages vous y mène directement.
                """),
            .heading("Les clés"),
            .table(
                headers: ["Clé", "Défaut", "Signification"],
                rows: [
                    ["`fontSize`", "`13`", "Taille du texte de l'éditeur"],
                    ["`tabWidth`", "`4`", "Largeur d'une tabulation en colonnes"],
                    ["`usesTabsForIndent`", "`false`", "Indenter avec des tabulations plutôt que des espaces"],
                    ["`languageIndent`", "`{}`", "Indentation par langage — voir la page sur les blancs"],
                    ["`smartIndent`", "`true`", "Indentation automatique à la nouvelle ligne"],
                    ["`highlightAllMatches`", "`true`", "Surligner chaque occurrence trouvée"],
                    ["`ligatures`", "`false`", "Ligatures — voir la note sous le tableau"],
                    ["`trimTrailingWhitespaceOnSave`", "`false`", "Couper les blancs de fin à l'enregistrement"],
                    ["`normalizeToNFCOnSave`", "`false`", "Normaliser l'Unicode en NFC à l'enregistrement"],
                    ["`defaultEncoding`", "`\"utf-8\"`", "Encodage des nouveaux fichiers"],
                    ["`defaultEOL`", "`\"lf\"`", "Fins de ligne des nouveaux fichiers"],
                    ["`language`", "`\"system\"`", "Langue de l'interface"],
                    ["`appearance`", "`\"system\"`", "`system` · `light` · `dark`"],
                    ["`themeName`", "le thème par défaut", "Le thème de couleurs en usage"],
                    ["`showWelcomeOnLaunch`", "`true`", "Ouvrir la fenêtre d'accueil au lancement"],
                    ["`keyBindings`", "`{}`", "Seulement les touches que vous avez changées"],
                ]
            ),
            .note("""
                **Pourquoi les ligatures sont DÉSACTIVÉES par défaut.** Une ligature fond `!=` ou \
                `->` en **un seul** glyphe : les caractères que vous voyez à l'écran ne correspondent \
                donc plus à ceux du fichier — or l'éditeur de colonnes, le mode colonne et le retour \
                à la ligne à une colonne mesurent tous en colonnes. Activez-les pour écrire de la \
                prose, ou si vous avez choisi une police de programmation (Fira Code, JetBrains Mono) \
                précisément pour ses ligatures.
                """),
            .heading("Les dossiers voisins"),
            .table(
                headers: ["Dossier", "Contient"],
                rows: [
                    ["`macros/`", "Les macros enregistrées, un fichier JSON chacune"],
                    ["`scripts/`", "Les scripts JavaScript"],
                    ["`themes/`", "Les thèmes de couleurs"],
                    ["`grammars/`", "Les langages définis par l'utilisateur"],
                ]
            ),
            .warning("""
                Un fichier de configuration écrit par une version **plus récente** de GEditor n'est \
                **pas écrasé** par une plus ancienne — celle-ci tourne sur les valeurs par défaut et \
                le dit. Écraser est le moyen le plus sûr de détruire la configuration de quelqu'un \
                qui synchronise deux machines, et il n'en apprendrait jamais la raison.
                """),
            .seeAlso(["phim-tat", "theme", "ngon-ngu-tu-dinh-nghia"]),
        ]
    )

    static let statusBar = HelpTopic(
        id: "thanh-trang-thai",
        title: "La barre d'état",
        summary: "Dix segments en bas — chacun lisible, et chacun cliquable.",
        keywords: ["barre d'état", "position", "encodage", "lecture seule", "taille du fichier"],
        blocks: [
            .paragraph("""
                C'est la plus grande différence avec les barres d'état des autres éditeurs : **aucun \
                segment n'est en lecture seule**. Voyez une valeur fausse, et la cliquer est la façon \
                de la corriger, plutôt que de fouiller les menus.
                """),
            .table(
                headers: ["Segment", "Vous dit", "En le cliquant"],
                rows: [
                    ["`Dòng 12, Cột 5 · @340`",
                     "position du curseur — colonne en CARACTÈRES, `@340` la position en octets",
                     "ouvre la boîte `Aller à`"],
                    ["`11 byte · 3 dòng`", "taille du document",
                     "compte octets · caractères · mots · lignes"],
                    ["`🔒 Chỉ đọc`", "affiché seulement quand le document est verrouillé",
                     "dit POURQUOI il est verrouillé, et le déverrouille quand c'est possible"],
                    ["`View` / `Code`", "dans quelle vue vous êtes", "bascule (⌥⌘V)"],
                    ["`CSV · dấu phẩy`", "mode CSV et séparateur en usage",
                     "bascule le mode CSV, ou **rechoisit le séparateur**"],
                    ["`Đang theo dõi`", "`tail -f` est actif", "—"],
                    ["`UTF-8`", "l'encodage", "réinterpréter, ou convertir vers un autre encodage"],
                    ["`LF`", "style de fin de ligne", "basculer LF · CRLF · CR"],
                    ["`Python`", "langage de coloration syntaxique", "en choisir un autre, ou revenir au choix par extension"],
                    ["`Tab: 4`", "largeur d'indentation", "2 · 4 · 8, globalement ou **seulement pour ce langage**"],
                    ["`Ngắt: tắt`", "mode de retour à la ligne", "fait défiler les trois modes"],
                ]
            ),
            .heading("Trois segments qui méritent un second regard"),
            .bullets([
                "**`@340` — la position en octets.** C'est le nombre que parle chaque autre outil du produit : les erreurs JSON et XML, la sortie de `--doc-sweep`, la vue binaire, et la boîte `Aller à @340`. Lisez-le ici, tapez-le là.",
                "**Un `~` sur la colonne** signifie que le nombre compte des OCTETS et non des colonnes visuelles — cela n'arrive que sur des lignes de plus de 200 Ko, où compter les caractères ralentirait chaque déplacement du curseur.",
                "**`CSV · …` se clique pour rechoisir le séparateur.** La détection peut se tromper, et alors chaque opération sur colonnes est décalée sans le moindre signal. C'est ainsi que vous dites le contraire — cela ne fait que RELIRE le fichier, sans changer un octet (à la différence de `CSV ▸ Changer le séparateur…`, qui le réécrit).",
            ]),
            .note("""
                Un segment sans objet pour le fichier ouvert est **masqué**, non grisé : `Lecture \
                seule` n'apparaît que si le document est vraiment verrouillé, `CSV · …` seulement en \
                mode CSV.
                """),
            .seeAlso(["di-toi-dong", "bang-ma-tieng-viet", "bang-csv", "khoang-trang-thut-le"]),
        ]
    )

    static let keyBindings = HelpTopic(
        id: "phim-tat",
        title: "Changer les raccourcis clavier",
        summary: "Changer des touches une à une, ou adopter d'un coup la disposition de Notepad++.",
        keywords: ["raccourci", "disposition", "préréglage"],
        blocks: [
            .paragraph("""
                `Réglages…` a une section Raccourcis avec deux boutons rapides : **Utiliser le \
                préréglage Notepad++** et **Revenir aux valeurs par défaut**.
                """),
            .paragraph("""
                Le fichier de configuration ne consigne que ce que vous avez **changé par rapport aux \
                valeurs par défaut**. Ainsi, quand GEditor change une touche par défaut dans une \
                nouvelle version, vous ne restez pas coincé sur l'ancienne disposition sans que \
                personne ne vous le dise.
                """),
            .note("""
                Deux commandes ne peuvent pas partager un raccourci. Quand cela arrive, AppKit \
                déclenche silencieusement seulement le **premier** élément de menu et l'autre \
                commande paraît cassée — GEditor a donc une vérification qui l'empêche.
                """),
            .seeAlso(["cai-dat", "di-cu-notepadpp"]),
        ]
    )

    static let themes = HelpTopic(
        id: "theme",
        title: "Thèmes, clair et sombre",
        summary: "Suivre le système, clair ou sombre ; et un thème est un fichier JSON modifiable.",
        keywords: ["thème", "couleurs", "mode sombre", "clair", "apparence"],
        blocks: [
            .paragraph("`Réglages…` choisit `Suivre le système`, `Clair` ou `Sombre`, et sélectionne un thème de couleurs."),
            .paragraph("""
                Un thème est un fichier JSON dans `themes/`. Le bouton `Exporter le thème courant` en \
                écrit un comme point de départ pour le vôtre.
                """),
            .note("""
                Une couleur mal saisie dans un fichier de thème retombe sur la couleur du **thème par \
                défaut**, non sur du noir. Le noir a l'air d'une décision de conception, et \
                l'utilisateur irait chercher le problème ailleurs.
                """),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let updatesAndAbout = HelpTopic(
        id: "cap-nhat-va-ve",
        title: "Mises à jour, versions et fermeture",
        summary: "En quoi la mise à jour diffère entre les deux versions.",
        keywords: ["mise à jour", "version", "à propos", "quitter"],
        commands: ["Về GEditor", "Kiểm tra bản cập nhật…", "Thoát GEditor"],
        blocks: [
            .table(
                headers: ["Version", "Se met à jour par"],
                rows: [
                    ["App Store", "L'App Store, comme toute autre application"],
                    ["Téléchargement direct", "`Rechercher les mises à jour…` dans l'application"],
                ]
            ),
            .paragraph("""
                `À propos de GEditor` montre la version en cours et de quelle version il s'agit — \
                utile pour signaler un problème.
                """),
            .note("""
                Dans la version App Store, `Rechercher les mises à jour…` **reste dans le menu** et \
                explique pourquoi cela ne s'applique pas, au lieu de disparaître. Un élément de menu \
                absent devient une question au support.
                """),
            .paragraph("Quitter ne perd aucun travail : la session revient à la prochaine ouverture."),
            .seeAlso(["hai-ban-phat-hanh", "phien-lam-viec"]),
        ]
    )

    static let usingHelp = HelpTopic(
        id: "tro-giup",
        title: "Utiliser cette fenêtre d'aide",
        summary: "Chercher dans le livre, changer sa langue, et faire revenir la fenêtre d'accueil.",
        keywords: ["aide", "guide", "recherche", "accueil", "langue"],
        commands: ["Trợ giúp GEditor", "Giới thiệu tính năng"],
        blocks: [
            .shortcuts([HelpShortcut("⌘?", "Ouvrir la fenêtre d'aide")]),
            .bullets([
                "Le champ de recherche en haut à gauche fouille **le texte et les exemples de code** — taper une clé de configuration nue comme `fail_under` mène à la bonne page.",
                "Taper **sans accents** trouve quand même le texte accentué.",
                "Le bouton `Retour` ramène à la page précédente.",
                "Le bouton `Copier` de chaque bloc de code copie ce bloc.",
            ]),
            .heading("Lire dans une autre langue"),
            .paragraph("""
                Le menu local en haut à droite de cette fenêtre choisit la **langue du livre**, \
                indépendamment de la langue d'interface de l'application. Le changement vous garde \
                **sur la page que vous lisez** — les identifiants de page ne sont volontairement pas \
                traduits, précisément pour que cela fonctionne.
                """),
            .note("""
                Seules les langues qui ont réellement un livre sont listées. Une entrée de menu qui \
                bascule vers quelque chose et laisse le texte inchangé serait une entrée de menu qui \
                ment.
                """),
            .heading("Faire revenir la fenêtre d'accueil"),
            .paragraph("""
                Si vous avez coché **Ne pas ouvrir cette fenêtre au lancement**, rouvrez-la avec \
                `Aide ▸ Visite des fonctions` — la case au pied de la fenêtre réapparaît et peut être \
                décochée.
                """),
            .paragraph("Ou remettez `showWelcomeOnLaunch` à `true` dans `settings.json`."),
            .seeAlso(["gioi-thieu", "cai-dat"]),
        ]
    )

    static let notepadppMigration = HelpTopic(
        id: "di-cu-notepadpp",
        title: "De Notepad++ à GEditor",
        summary: "Quelles touches échangent leur place, ce qui fonctionne autrement, et ce qui manque.",
        keywords: ["notepad++", "migration", "windows", "raccourcis"],
        commands: ["Di cư từ Notepad++"],
        blocks: [
            .paragraph("""
                Quelques touches **échangent leur place** sur macOS plutôt que de simplement changer \
                `Ctrl` en `⌘`. Voici la comparaison.
                """),
            .table(
                headers: ["Notepad++", "GEditor", "Pourquoi"],
                rows: [
                    ["`Ctrl+D` Dupliquer la ligne", "**⇧⌘D**", "`⌘D` est ici le multi-curseur, comme dans tout éditeur Mac"],
                    ["`Ctrl+L` Supprimer la ligne", "**⌘K**", "Sur macOS, `⌘L` veut dire « aller à la ligne »"],
                    ["`Ctrl+G` Aller à la ligne", "**⌘L**", "Ces deux-là échangent leur place"],
                    ["`Ctrl+Q` Commenter", "**⌘/**", "Convention macOS"],
                    ["`Ctrl+Shift+↑/↓` Déplacer la ligne", "**⌥↑ / ⌥↓**", "Sur macOS, `⌃` appartient à Mission Control"],
                    ["`F3` Occurrence suivante", "**⌘G**", "Convention macOS"],
                    ["`Ctrl+F2` Basculer le signet", "**⌘F2**", "F2 et ⇧F2 sautent toujours entre les marques"],
                    ["`Alt` + glisser pour les colonnes", "**⌥ + glisser**", "Identique"],
                    ["`Ctrl+Alt+Shift+↓` Éditeur de colonnes", "**⌥⌘C**", "Convention macOS"],
                ]
            ),
            .note("Vous préférez ne pas réapprendre ? `Réglages ▸ Raccourcis ▸ Utiliser le préréglage Notepad++`."),
            .heading("Ce que Notepad++ a et qui fonctionne autrement ici"),
            .bullets([
                "**Les sessions** se restaurent d'elles-mêmes, onglets non enregistrés compris — rien à activer.",
                "**Les signets ont neuf couleurs**, et une ligne peut en porter plusieurs à la fois.",
                "**La carte du document** décrit *tout* le fichier, pas seulement la partie visible.",
                "**Les macros** peuvent jouer « jusqu'à la fin du document » et « sur tous les onglets », et toute une exécution est une seule annulation.",
            ]),
            .heading("Ce que GEditor ajoute"),
            .bullets([
                "Un **établi de nettoyage** et des **profils de données** pour les fichiers CSV.",
                "Des **requêtes SQL** directement sur un fichier CSV.",
                "Les **encodages vietnamiens anciens** — TCVN3, VISCII, VNI-Windows, lus, écrits et détectés automatiquement.",
                "La **recherche insensible aux accents** dans chaque champ de filtre.",
                "Les **rapports `.greport.md`** avec tableaux et graphiques qui se recalculent.",
                "L'**outil en ligne de commande `geditor`** dans la version en téléchargement direct.",
            ]),
            .seeAlso(["phim-tat", "quy-trinh-lam-sach", "bang-ma-tieng-viet"]),
        ]
    )

    static let troubleshooting = HelpTopic(
        id: "su-co-thuong-gap",
        title: "Problèmes courants",
        summary: "Six situations qui font croire que l'application est cassée.",
        keywords: ["erreur", "problème", "ne marche pas", "dépannage", "pourquoi"],
        blocks: [
            .table(
                headers: ["Symptôme", "Cause habituelle"],
                rows: [
                    ["Le texte vietnamien s'affiche en charabia", "Mauvais encodage — cliquez l'encodage dans la barre d'état"],
                    ["Chercher du texte accentué ne trouve rien", "Le fichier est en Unicode décomposé — lancez `Normaliser l'Unicode` en NFC"],
                    ["Un élément de menu est grisé", "La version App Store ne peut pas exécuter cette commande — l'élément explique pourquoi"],
                    ["La correspondance des parenthèses refuse", "Le document dépasse 1 Mo — surligner la mauvaise paire est pire que rien"],
                    ["La colonne dans la barre d'état a un `~`", "Le document dépasse 200 Ko : c'est un compte d'octets, pas une colonne visuelle"],
                    ["Une requête SQL dit qu'il faut d'abord enregistrer", "DuckDB lit des **fichiers**, pas le tampon que vous modifiez"],
                ]
            ),
            .heading("Quand GEditor quitte inopinément"),
            .paragraph("""
                Au lancement suivant, une bannière le dit, avec un bouton **Ouvrir le rapport** — le \
                rapport s'ouvre comme un onglet que vous pouvez lire et copier comme tout fichier \
                texte.
                """),
            .bullets([
                "Le rapport ne porte que la **version, la version de macOS, l'architecture de la machine, le nom du signal et la pile d'appels**.",
                "**Aucun contenu de document, et aucun chemin de fichier non plus** — un chemin comme `~/Bureau/salaires-decembre.xlsx` a déjà révélé trois choses privées avant que quiconque l'ouvre.",
                "**Rien n'est envoyé nulle part.** Il n'y a ni envoi automatique ni serveur pour le recevoir ; le fichier reste dans `~/Library/Application Support/GEditor/crash/` jusqu'à ce que vous l'ouvriez ou l'effaciez.",
                "Une fois le rapport ouvert, le lancement suivant n'en reparle plus.",
            ]),
            .heading("Où regarder ensuite"),
            .bullets([
                "La barre d'état montre encodage, fins de ligne, langage et mode de retour à la ligne — chaque segment est cliquable.",
                "`settings.json` se modifie à la main quand la fenêtre des réglages ne suffit pas.",
                "`À propos de GEditor` donne la version et la variante, dont un rapport de bogue a besoin.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "chuan-hoa-unicode", "hai-ban-phat-hanh", "cai-dat"]),
        ]
    )
}
