import Foundation

/// Contenu de l'aide en français — quatrième partie : données tabulaires, nettoyage, exploration.
extension HelpFR {

    static let tabularData = HelpChapter(
        id: "csv",
        title: "Données tabulaires",
        summary: "Voir un CSV en grille, filtrer, trier, vérifier la structure, interroger en SQL, convertir.",
        topics: [csvGrid, excelSheets, filterAndSort, structureCheck, deleteColumns, sqlQueries,
                 pivotAndCharts, formatConversion, delimiter]
    )

    static let csvGrid = HelpTopic(
        id: "bang-csv",
        title: "Voir un CSV en grille",
        summary: "Un million de lignes défile encore sans à-coups, les en-têtes restent, le texte source est intact.",
        keywords: ["csv", "grille", "tableau", "tsv", "excel", "colonnes"],
        commands: ["Xem dạng bảng / văn bản"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘T", "Basculer entre grille et texte")]),
            .paragraph("""
                La grille est **virtualisée** : seules les lignes visibles sont construites, si bien \
                qu'un fichier d'un million de lignes défile comme un fichier de cent.
                """),
            .bullets([
                "**La ligne d'en-tête reste collée** pendant le défilement — à la ligne 40 000, vous savez encore ce qu'est la neuvième colonne.",
                "Modifiez une cellule dans la grille ; le changement va droit dans le texte source.",
                "Grille et texte sont **deux vues d'un fichier**, pas deux copies.",
                "**⌘C copie la ligne sélectionnée**, cellules séparées par des tabulations — collez directement dans Excel ou Numbers et chaque cellule tombe au bon endroit. Les cellules contenant tabulations ou sauts de ligne sont mises entre guillemets, pour que la destination ne les coupe pas en deux.",
            ]),
            .note("""
                Le séparateur est détecté à l'ouverture (virgule, point-virgule, tabulation, barre \
                verticale). Si la supposition est fausse, changez-le avec `CSV ▸ Changer le \
                séparateur…`.
                """),
            .seeAlso(["loc-va-sap-bang", "dau-phan-tach", "che-do-to-mau"]),
        ]
    )

    static let excelSheets = HelpTopic(
        id: "sheet-excel",
        title: "Classeurs à plusieurs feuilles",
        summary: "Ouvrir n'importe quelle feuille d'un .xlsx, et ⌘S réécrit dans la feuille que vous regardez.",
        keywords: ["excel", "xlsx", "feuille", "classeur"],
        commands: ["CSV: chọn sheet…"],
        blocks: [
            .paragraph("""
                Ouvrez un `.xlsx` et GEditor montre la **première feuille** en grille CSV. `CSV ▸ \
                Choisir la feuille…` liste toutes les feuilles du fichier et ouvre celle que vous \
                choisissez dans le même onglet.
                """),
            .heading("Réécrire dans la BONNE feuille"),
            .paragraph("""
                `⌘S` écrit vos modifications dans **la feuille que vous regardez**, pas la première. \
                Les autres feuilles ne sont pas touchées d'un seul octet.
                """),
            .note("""
                La feuille est retenue par **nom**, pas par position. Ainsi, réordonner les feuilles \
                dans Excel entre deux sessions ne détourne pas l'écriture.
                """),
            .warning("""
                Si la feuille ouverte a été **renommée ou supprimée** dans Excel depuis que vous \
                l'avez ouverte, `⌘S` **refuse d'écrire** et le dit. Retomber sur la première feuille \
                reviendrait à verser le contenu d'une feuille sur une autre — le fichier \
                s'enregistrerait quand même, se rouvrirait quand même, et contiendrait simplement \
                les données au mauvais endroit.
                """),
            .heading("Changer de feuille avec des modifications non enregistrées"),
            .paragraph("""
                Changer de feuille remplace tout le contenu de l'onglet : s'il reste quelque chose de \
                non enregistré, GEditor **demande d'abord**. `⌘Z` ne peut pas le ramener, car le \
                document entier a été échangé.
                """),
            .heading("Ce que coûte de ramener Excel à une grille"),
            .paragraph("""
                Ce qui survit, ce sont les **valeurs** — y compris les résultats de formules, \
                exactement les nombres qu'Excel affiche. Ce qui ne survit pas : polices, couleurs, \
                cellules fusionnées, graphiques incorporés, et les formules elles-mêmes.
                """),
            .paragraph("""
                En échange, cette feuille gagne tout le reste du produit : filtrage, tri, requêtes \
                SQL, l'établi de nettoyage, la notation de qualité, l'exploration, les graphiques.
                """),
            .seeAlso(["bang-csv", "truy-van-sql", "quy-trinh-lam-sach"]),
        ]
    )

    static let filterAndSort = HelpTopic(
        id: "loc-va-sap-bang",
        title: "Filtrer et trier dans la grille",
        summary: "Un champ de filtre par colonne, qui comprend la comparaison numérique et la frappe sans accents.",
        keywords: ["filtre", "tri", "colonne", "recherche dans la grille"],
        blocks: [
            .paragraph("Cliquez un en-tête de colonne pour trier. Le champ de filtre en dessous accepte :"),
            .table(
                headers: ["Tapez dans le filtre", "Signification"],
                rows: [
                    ["`hue`", "Contient `hue`, **insensible aux accents** — trouve aussi `Huế`"],
                    ["`=Huế`", "Exactement `Huế` (toujours insensible aux accents)"],
                    ["`>100`", "Supérieur à 100"],
                    ["`>=100`", "100 ou plus"],
                    ["`<0`", "Inférieur à 0"],
                    ["`100..200`", "Entre 100 et 200"],
                    ["vide", "Aucun filtre sur cette colonne"],
                ]
            ),
            .paragraph("""
                Filtrer plusieurs colonnes est un **et** : une ligne doit les satisfaire toutes. La \
                comparaison numérique saute les cellules non numériques au lieu de les traiter comme \
                des zéros.
                """),
            .note("""
                Filtrer est une **façon de voir**, pas une suppression. Effacez le filtre et toutes \
                les lignes reviennent.
                """),
            .seeAlso(["go-khong-dau", "truy-van-sql"]),
        ]
    )

    static let structureCheck = HelpTopic(
        id: "kiem-tra-du-lieu",
        title: "Vérifier la structure du tableau",
        summary: "Trouver les lignes au mauvais nombre de colonnes et les cellules du mauvais type — à faire en premier.",
        keywords: ["valider", "vérifier", "nombre de colonnes", "mauvais type", "données cassées"],
        commands: ["Kiểm tra dữ liệu (số cột · kiểu)"],
        blocks: [
            .paragraph("""
                C'est ce qu'il faut lancer **avant** tout le reste sur un fichier qu'on vous a \
                envoyé. Cela répond à deux questions :
                """),
            .bullets([
                "**Quelles lignes ont le mauvais nombre de colonnes ?** D'ordinaire une cellule contenant une virgule non protégée par des guillemets — et elle décale toutes les lignes suivantes.",
                "**Quelles cellules ont un type différent du reste de leur colonne ?** Par exemple `n/a` posé dans une colonne de nombres.",
            ]),
            .paragraph("Les résultats apparaissent en liste ; cliquez-en un pour sauter à cette ligne."),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let deleteColumns = HelpTopic(
        id: "xoa-cot",
        title: "Supprimer des colonnes",
        summary: "Retirer entièrement du fichier une ou plusieurs colonnes.",
        keywords: ["supprimer une colonne", "retirer une colonne"],
        commands: ["Xóa cột…"],
        blocks: [
            .paragraph("""
                Choisissez dans la liste les colonnes à retirer et appliquez. C'est **une** étape \
                d'annulation, quel que soit le nombre de lignes du fichier.
                """),
            .warning("""
                À la différence du filtrage, ceci **modifie le vrai fichier**. Pour seulement masquer \
                des colonnes, utilisez une requête SQL listant celles que vous voulez.
                """),
            .seeAlso(["truy-van-sql"]),
        ]
    )

    static let sqlQueries = HelpTopic(
        id: "truy-van-sql",
        title: "Interroger un CSV en SQL",
        summary: "Tout le SQL de DuckDB, exécuté directement sur le fichier ouvert — en lecture seule.",
        keywords: ["sql", "requête", "duckdb", "select", "join", "group by"],
        commands: ["CSV: truy vấn SQL…"],
        blocks: [
            .paragraph("""
                La table ouverte s'appelle **`t`**. Le moteur est **DuckDB** : `JOIN`, `DISTINCT`, \
                `HAVING`, `IN`, `LIKE`, `BETWEEN`, les fonctions de fenêtrage et les sous-requêtes \
                fonctionnent toutes.
                """),
            .code(language: "sql", caption: "Chiffre d'affaires par province, du plus grand au plus petit",
                  source: """
                    SELECT tinh, SUM(doanh_thu) AS tong
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    LIMIT 20
                    """),
            .code(language: "sql", caption: "Filtrer par date et par condition textuelle",
                  source: """
                    SELECT ma_don, ngay, khach_hang, tong
                    FROM t
                    WHERE ngay BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
                      AND khach_hang ILIKE '%công ty%'
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "La part de chaque province dans le total — avec une fonction de fenêtrage",
                  source: """
                    SELECT tinh,
                           SUM(doanh_thu) AS tong,
                           ROUND(100.0 * SUM(doanh_thu) / SUM(SUM(doanh_thu)) OVER (), 1) AS phan_tram
                    FROM t
                    GROUP BY tinh
                    ORDER BY tong DESC
                    """),
            .code(language: "sql", caption: "Jointure avec un autre fichier du disque",
                  source: """
                    SELECT t.ma_tinh, d.ten_tinh, SUM(t.doanh_thu) AS tong
                    FROM t
                    JOIN read_csv('danh-muc-tinh.csv', header = true) AS d
                      ON t.ma_tinh = d.ma_tinh
                    GROUP BY t.ma_tinh, d.ten_tinh
                    """),
            .heading("Lecture seule, et c'est une garantie ferme"),
            .bullets([
                "La base vit **en mémoire** ; le fichier source n'est jamais que lu.",
                "Exactement **une instruction** est acceptée, et elle **doit être un `SELECT`**. Tout le reste — y compris `COPY … TO 'fichier'`, que DuckDB peut parfaitement utiliser pour écrire sur disque — est bloqué avant d'atteindre la moindre donnée.",
            ]),
            .warning("""
                DuckDB lit des **fichiers**, pas la mémoire. Si le document a des modifications non \
                enregistrées, GEditor doit écrire une copie temporaire avant d'interroger. Pour un \
                très gros fichier aux modifications non enregistrées, il **s'arrête et le dit** \
                plutôt que d'écrire discrètement des centaines de mégaoctets sur disque pour une \
                seule requête.
                """),
            .seeAlso(["pivot-va-bieu-do", "bao-cao-greport", "quy-trinh-khai-pha"]),
        ]
    )

    static let pivotAndCharts = HelpTopic(
        id: "pivot-va-bieu-do",
        title: "Tableaux croisés et graphiques rapides",
        summary: "Croiser et tracer directement depuis un résultat de requête.",
        keywords: ["tableau croisé", "graphique", "agrégat"],
        blocks: [
            .paragraph("""
                Les deux s'ouvrent depuis la **table de résultat** : exécutez une instruction SQL, \
                puis utilisez le bouton Croiser ou Graphique du panneau.
                """),
            .heading("Tableau croisé"),
            .paragraph("""
                Choisissez la colonne de **lignes**, celle de **colonnes**, celle de **valeurs** et \
                l'agrégat (somme, compte, moyenne, min, max) — comme un tableau croisé de tableur.
                """),
            .heading("Graphiques"),
            .paragraph("""
                Barres, courbes, secteurs, nuage de points. Nombres au format vietnamien ou européen, \
                et le graphique s'exporte en PNG ou SVG pour être collé ailleurs.
                """),
            .note("""
                Vous voulez un graphique qui **se rafraîchit avec les données** à chaque \
                reconstruction ? C'est le bloc `chart` d'un rapport `.greport.md`.
                """),
            .seeAlso(["truy-van-sql", "bao-cao-greport"]),
        ]
    )

    static let formatConversion = HelpTopic(
        id: "chuyen-doi-dinh-dang",
        title: "Convertir un tableau vers un autre format",
        summary: "TSV, JSON, XML, tableaux Markdown, instructions SQL INSERT — avec aperçu.",
        keywords: ["convertir", "exporter", "markdown", "sql insert"],
        commands: ["Chuyển đổi…", "Xuất sang JSON…"],
        blocks: [
            .table(
                headers: ["Format", "Utile pour"],
                rows: [
                    ["TSV", "Coller dans un tableur sans se soucier des virgules dans les cellules"],
                    ["JSON", "Alimenter une API, un script ou un autre outil"],
                    ["XML", "Les systèmes anciens qui exigent du XML"],
                    ["Tableau Markdown", "Coller dans une documentation, un README, un ticket"],
                    ["Instructions SQL INSERT", "Charger dans une base de données"],
                ]
            ),
            .paragraph("""
                La boîte de dialogue **prévisualise les cinq premières lignes** avant de créer le \
                nouvel onglet — cinq lignes suffisent à confirmer le nom de la table, les guillemets \
                et quelles colonnes sont devenues des nombres.
                """),
            .note("""
                L'aperçu appelle **la même fonction** que celle qui produit la sortie réelle, limitée \
                à cinq lignes. Ce n'est pas une simulation qui pourrait diverger du résultat final.
                """),
        ]
    )

    static let delimiter = HelpTopic(
        id: "dau-phan-tach",
        title: "Changer le séparateur",
        summary: "Convertir un fichier entre virgule, point-virgule, tabulation et barre verticale.",
        keywords: ["séparateur", "virgule", "point-virgule", "tabulation", "csv européen"],
        commands: ["Đổi dấu phân tách…"],
        blocks: [
            .paragraph("""
                Les fichiers exportés d'un Excel vietnamien ou européen utilisent généralement des \
                **points-virgules**, car là-bas la virgule est le séparateur décimal.
                """),
            .warning("""
                Changer le séparateur **réécrit tout le fichier**. Les cellules contenant le nouveau \
                séparateur sont mises entre guillemets — sinon la structure du tableau se casse.
                """),
            .note("""
                **Si la détection s'est trompée, ce n'est pas la commande qu'il vous faut.** Il y a \
                ici deux tâches différentes, exactement comme la paire « réinterpréter » / \
                « convertir » des encodages :

                • *Le fichier est bien séparé par des points-virgules et nous avons deviné la \
                virgule* — cliquez le segment `CSV · …` de la **barre d'état** et choisissez le bon. \
                Pas un octet du fichier ne change ; seule sa lecture change.

                • *Le fichier est bien séparé par des virgules, et vous voulez des points-virgules* — \
                utilisez la commande de cette page. Elle réécrit le fichier.
                """),
            .seeAlso(["bang-csv", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Nettoyage

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Nettoyage des données — tout le flux",
        summary: "D'un fichier brut qu'on vous a envoyé à un tableau exploitable, et un standard à relancer chaque mois.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "Le flux de nettoyage, de bout en bout",
        summary: "Six étapes d'un fichier inconnu à un tableau fiable, et un standard pour le mois prochain.",
        keywords: ["nettoyage", "flux", "normaliser", "données propres"],
        blocks: [
            .paragraph("""
                Nettoyer des données n'est **presque jamais ponctuel**. Les gens reçoivent le même \
                modèle de rapport chaque mois, et chaque mois les mêmes colonnes demandent la même \
                normalisation. Ce flux est conçu pour cela : vous le faites une fois à la main, puis \
                vous le relancez d'une seule commande.
                """),
            .heading("Six étapes"),
            .steps([
                "**Regardez d'abord la structure.** `CSV ▸ Vérifier les données` — quelles lignes ont le mauvais nombre de colonnes, quelles cellules le mauvais type. Cela vient en premier car une seule ligne décalée rend toute statistique ultérieure dénuée de sens.",
                "**Lisez le profil des données.** Par colonne : combien de cellules vides, combien de valeurs distinctes, quel type, où sont les valeurs aberrantes. C'est là que vous comprenez le fichier, avant de rien changer.",
                "**Ouvrez l'établi de nettoyage** (`⇧⌘L`). Il détecte les formats de date mêlés, les nombres vietnamiens mêlés aux européens, les blancs parasites, les valeurs manquantes. **Aperçu avant→après**, puis appliquez.",
                "**Traitez les doublons approchés** si une colonne de noms ou d'adresses comporte des variantes saisies à la main. Ici, c'est vous qui décidez ; la machine ne fait que proposer.",
                "**Enregistrez cela comme recette.** La séquence que vous venez d'exécuter est écrite dans un fichier JSON nommé — ce fichier est votre connaissance de ces données.",
                "**Écrivez un jeu de règles de qualité** `.gquality.yaml` et notez. Désormais, le fichier du mois prochain passe par la recette et reçoit une note, et le **portail en ligne de commande** renvoie un code de sortie non nul en cas d'échec.",
            ]),
            .heading("Pourquoi cet ordre"),
            .bullets([
                "Structure **avant** profil : des statistiques sur un tableau décalé sont des statistiques sur une autre colonne.",
                "Profil **avant** nettoyage : il faut savoir « 2 % de vide » avant de décider de remplir ou de supprimer.",
                "Doublons approchés **après** normalisation : `CÔNG TY  A` et `Công ty A` ne se révèlent identiques qu'une fois les blancs et la casse réglés.",
                "Recette **avant** jeu de règles : la recette corrige, les règles jugent — noter un tableau non corrigé ne produit qu'un chiffre bas auquel vous vous attendiez déjà.",
            ]),
            .heading("Après la première fois, chaque mois tient en une commande"),
            .code(language: "bash", caption: "Nettoyer puis noter, en renvoyant un code de sortie pour la CI",
                  source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """),
            .paragraph("""
                Le code de sortie **0** signifie réussite, **1** échec, **2** erreur d'exécution. \
                `--record-history` ajoute une ligne au fichier d'historique pour que l'exécution \
                suivante puisse comparer la dérive.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Profil des données",
        summary: "Une description par colonne : type, vides, valeurs distinctes, distribution.",
        keywords: ["profil", "statistiques de colonne", "nul", "distinct"],
        blocks: [
            .paragraph("""
                Un profil **décrit** ; il ne juge pas. Il dit *« cette colonne est vide à 2 % »* ; \
                savoir si 2 % est acceptable relève du jeu de règles de qualité.
                """),
            .table(
                headers: ["Mesure", "Comment la lire"],
                rows: [
                    ["Type", "Déduit des données elles-mêmes, pas du nom de la colonne"],
                    ["Cellules vides", "Nombre et proportion de valeurs manquantes"],
                    ["Valeurs distinctes", "1 signifie une colonne constante ; égal au nombre de lignes, une colonne clé"],
                    ["Min · max · moyenne", "Colonnes numériques seulement"],
                    ["Valeurs les plus fréquentes", "Repérer aussitôt un code d'erreur ou une valeur par défaut trop employée"],
                ]
            ),
            .warning("""
                Le comptage des valeurs distinctes a un seuil. Au-delà, le nombre affiché est une \
                **borne inférieure**, et le profil **dit que c'est une estimation** au lieu de la \
                mêler aux comptes exacts.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "L'établi de nettoyage des données",
        summary: "Sept normalisations, toujours prévisualisées, toujours une seule annulation, jamais de devinette.",
        keywords: ["nettoyer", "normaliser", "dates", "nombres", "remplir"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Ouvrir l'établi de nettoyage")]),
            .table(
                headers: ["Opération", "Ce qu'elle fait"],
                rows: [
                    ["Normaliser les dates", "Ramener toutes les formes de date de la colonne à une seule"],
                    ["Normaliser les nombres", "Régler le séparateur décimal et celui des milliers"],
                    ["Couper les blancs", "Les retirer aux deux bouts ; en option, compacter aussi ceux du milieu"],
                    ["Changer la casse", "Rendre la capitalisation de la colonne cohérente"],
                    ["Remplir d'une valeur fixe", "Remplacer les cellules vides par une valeur que vous tapez"],
                    ["Remplir depuis une voisine", "Prendre la valeur de la ligne du dessus ou du dessous"],
                    ["Supprimer les lignes à cellules vides", "Écarter les lignes où des données manquent"],
                ]
            ),
            .heading("Trois garanties de tout l'établi"),
            .bullets([
                "**Toujours prévisualisé.** Un tableau avant→après, avec le nombre de cellules qui vont changer.",
                "**Une seule étape d'annulation** pour toute la passe, même quand elle touche un million de cellules.",
                "**Un rapport ensuite** : combien de cellules ont changé, et lesquelles n'ont pas pu être lues.",
            ]),
            .heading("Le principe : ne jamais deviner"),
            .paragraph("""
                Une cellule impossible à lire avec certitude est **signalée et laissée telle \
                quelle**. Prenez `03/04/2026` dans une colonne qui mêle les deux conventions — est-ce \
                le 3 avril ou le 4 mars ? GEditor vous demande l'ordre jour/mois plutôt que de \
                choisir à votre place.
                """),
            .warning("""
                Mal normaliser une colonne de dates est le genre de corruption **presque impossible à \
                détecter** : les nombres ont toujours l'air justes, ce sont simplement d'autres \
                dates. C'est pourquoi cet établi préfère refuser que déduire.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Doublons approchés",
        summary: "Trouver les variantes saisies à la main d'un même nom — et ne jamais les fusionner automatiquement.",
        keywords: ["approché", "doublons", "fusionner", "variantes", "fautes de frappe"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — trois façons \
                d'écrire un même client. Un dédoublonnage ordinaire ne les voit pas comme identiques.
                """),
            .steps([
                "Choisissez la colonne à examiner et un seuil de similarité.",
                "GEditor regroupe les valeurs proches en **grappes** et montre la forme de comparaison.",
                "Pour **chaque grappe**, vous choisissez la valeur à garder — ou vous passez cette grappe.",
                "Appliquez. Une seule étape d'annulation.",
            ]),
            .warning("""
                Cet outil **ne fusionne jamais de lui-même**, et il n'y a pas de bouton « tout \
                fusionner ». Deux chaînes semblables à 92 % peuvent être une faute de frappe, ou deux \
                entreprises réellement différentes d'un mot — une machine ne peut pas trancher.
                """),
            .paragraph("""
                Fusionner à tort deux enregistrements est une perte de données **silencieuse** : \
                aucune cellule ne devient vide, aucune ligne ne rougit, deux entités n'en font plus \
                qu'une et personne ne s'en aperçoit avant le rapprochement des comptes.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Recettes de nettoyage",
        summary: "Enregistrer la séquence comme fichier JSON et la relancer sur les données du mois prochain.",
        keywords: ["recette", "répéter", "automatiser", "mensuel", "lot"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                Après le nettoyage, enregistrez les étapes comme **recette**. C'est un fichier JSON \
                lisible par un humain, que vous pouvez garder près des données, envoyer à un \
                collègue, et déposer dans un dépôt pour que les changements soient suivis.
                """),
            .code(language: "json", caption: "sales-standard.json — abrégé",
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
                Chaque étape peut être **désactivée** (`enabled`), si bien qu'une recette peut servir \
                à plusieurs sortes de fichiers presque identiques.
                """),
            .heading("Relancer"),
            .bullets([
                "Dans l'application : `CSV ▸ Exécuter une recette de nettoyage…`",
                "Depuis le shell, sur tout un dossier : voir la page de la ligne de commande.",
            ]),
            .code(language: "bash", caption: "Un essai à blanc avant toute écriture — aucun fichier n'est touché",
                  source: "geditor --recipe sales-standard.json --dry-run sales-*.csv"),
            .note("""
                Par défaut, le résultat est écrit dans un nouveau fichier à côté de l'original \
                (`sales-clean.csv`). Écraser l'original doit être demandé explicitement avec \
                `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Notation de la qualité des données",
        summary: "Six dimensions, une note de 0 à 100, et chaque formule imprimée pour que vous puissiez la recalculer.",
        keywords: ["qualité", "note", "dqr", "six dimensions"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                Elle diffère du profil des données sur un point fondamental : un profil **décrit**, \
                une note **juge par rapport au standard que vous avez déclaré** dans un fichier \
                `.gquality.yaml`.
                """),
            .table(
                headers: ["Dimension", "Ce qu'elle mesure"],
                rows: [
                    ["Complétude", "Proportion de cellules remplies, selon les règles `not_null`"],
                    ["Validité", "Proportion de règles de format, type, intervalle et regex satisfaites"],
                    ["Unicité", "Par rapport à la clé déclarée dans `uniqueness_key`"],
                    ["Cohérence", "Règles inter-colonnes et inter-fichiers"],
                    ["Exactitude (estimée)", "Valeurs aberrantes dans les colonnes numériques que vous désignez"],
                    ["Fraîcheur", "L'âge des données face au seuil `freshness`"],
                ]
            ),
            .heading("Trois garanties sur la note"),
            .bullets([
                "**La formule est imprimée dans le résultat** — vous pouvez la recalculer à la main.",
                "**Déterministe** : mêmes données et mêmes règles donnent la même note. Seule la *Fraîcheur* dépend du moment, donc `now` est un **paramètre** consigné dans le résultat.",
                "**Une dimension qu'on ne peut pas noter reste vide avec une raison**, jamais silencieusement gratifiée d'un 100.",
            ]),
            .warning("""
                Cette dernière garantie compte. Un tableau sans `uniqueness_key` déclarée, gratifié \
                d'un 100 pour « unicité », est une note qui ment — et elle ment dans le sens \
                flatteur, celui qui est dangereux.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "Syntaxe de `.gquality.yaml`",
        summary: "Chaque clé du fichier de règles, avec un jeu complet qui s'exécute.",
        keywords: ["gquality", "yaml", "règles", "syntaxe", "standard de données"],
        blocks: [
            .paragraph("""
                Le fichier vit **à côté des données**, pas dans l'application : un standard de \
                données doit pouvoir être relu, et relire est ce que les gens font des standards.
                """),
            .code(language: "yaml", caption: "sales-standard.yaml — un jeu de règles complet",
                  source: """
                    schemaVersion: 1

                    # Poids des six dimensions. Une dimension absente pèse 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # La clé qui rend une ligne unique. Sans elle, la dimension « Unicité »
                    # NE PEUT PAS être notée — et le total le dira.
                    uniqueness_key: [ma_don]

                    # Colonnes numériques examinées pour l'« Exactitude (estimée) ».
                    accuracy_columns: [doanh_thu, so_luong]

                    # La dimension « Fraîcheur ».
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Avertir quand cette exécution baisse par rapport à la précédente.
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
                        max_null_pct: 2          # tolère 2 % de vide
                      # Règle inter-colonnes : pas de `col` nécessaire
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Règle inter-fichiers : la valeur doit exister dans un autre fichier
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """),
            .heading("Les types de règles"),
            .table(
                headers: ["Clé", "Signification", "Dimension"],
                rows: [
                    ["`not_null: true`", "La cellule doit être remplie ; `max_null_pct` assouplit", "Complétude"],
                    ["`unique: true`", "Aucune valeur répétée dans la colonne", "Unicité"],
                    ["`dtype: int\\|float\\|date\\|text`", "Type correct", "Validité"],
                    ["`range: { min:, max: }`", "Dans un intervalle numérique", "Validité"],
                    ["`length: { min:, max: }`", "Longueur de chaîne", "Validité"],
                    ["`regex: \"…\"`", "Correspond à une expression régulière", "Validité"],
                    ["`in_set: [ … ]`", "L'une d'une liste donnée", "Validité"],
                    ["`date_format: \"…\"`", "Forme de date correcte", "Validité"],
                    ["`compare: { a:, op:, b: }`", "Comparer deux colonnes ; `op` vaut `<` `<=` `=` `>=` `>` `<>`", "Cohérence"],
                    ["`foreign_key: { file:, column: }`", "La valeur doit exister dans un autre fichier", "Cohérence"],
                    ["`severity: error\\|warn`", "Gravité de la règle ; `error` par défaut", "—"],
                ]
            ),
            .warning("""
                Une clé de règle mal orthographiée fait **rejeter le fichier avec un message**, \
                plutôt que de sauter cette règle en silence. Sauter en silence, c'est vous laisser \
                croire que les données ont été vérifiées par une règle qui n'a jamais tourné.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "Un portail de qualité dans la CI",
        summary: "Arrêter les données défaillantes dans le pipeline, à l'aide des codes de sortie.",
        keywords: ["ci", "portail", "fail-under", "code de sortie", "historique", "dérive"],
        blocks: [
            .code(language: "bash", caption: "Noter et renvoyer un code de sortie",
                  source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """),
            .table(
                headers: ["Option", "Signification"],
                rows: [
                    ["`--quality <fichier.yaml>`", "Le jeu de règles servant à noter"],
                    ["`--fail-under <0…100>`", "En dessous de cette note, c'est un ÉCHEC"],
                    ["`--json <fichier\\|->`", "Résultat lisible par machine ; `-` écrit sur la sortie standard"],
                    ["`--record-history`", "Ajoute une ligne à `sales-standard.history.jsonl`"],
                    ["`--now <AAAA-MM-JJ>`", "Fixe la date de référence de la *Fraîcheur*"],
                    ["`--recipe <fichier.json>`", "Nettoie **en mémoire** avant de noter, sans écrire de fichier"],
                ]
            ),
            .table(
                headers: ["Code de sortie", "Signification"],
                rows: [["`0`", "Réussite"], ["`1`", "Échec"], ["`2`", "Erreur d'exécution"]]
            ),
            .heading("Pourquoi la CI devrait passer `--now`"),
            .paragraph("""
                Sans cela, la *Fraîcheur* compare les données au moment de l'exécution — le même \
                fichier perd donc des points au fil des jours, et un matin le pipeline vire au rouge \
                sans que personne n'ait rien changé.
                """),
            .heading("Suivi de la dérive"),
            .paragraph("""
                Avec `--record-history`, chaque exécution ajoute une ligne à un fichier d'historique \
                JSONL. La fois suivante, les seuils du bloc `drift:` comparent à l'exécution la plus \
                récente et avertissent quand la baisse est trop forte.
                """),
            .note("""
                Chaque seuil de dérive est **désactivé par défaut**, sauf `warn_on_new_failure`. Un \
                avertissement activé d'office avec un nombre choisi par l'application se \
                déclencherait dès la deuxième exécution de tout le monde — et ce qui crie au loup le \
                premier jour est ignoré dès le troisième.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Exploration

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Exploration des données — tout le flux",
        summary: "Anomalies, corrélation, grappes, prévision, règles d'association — et comment les lire.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "Le flux d'exploration, de bout en bout",
        summary: "Six outils, l'ordre dans lequel les utiliser, et une règle : pas de mesure, pas de conclusion.",
        keywords: ["exploration", "analyse", "flux", "statistiques"],
        blocks: [
            .warning("""
                **Nettoyer d'abord, explorer ensuite.** Une colonne de dates non normalisée produit \
                de mauvaises prévisions ; une colonne numérique mêlant des séparateurs de milliers \
                européens produit des valeurs aberrantes fantômes. Chaque outil ci-dessous suppose le \
                tableau propre.
                """),
            .heading("L'ordre à suivre"),
            .steps([
                "**Trouver les anomalies** — répond à *« une ligne est-elle bizarre »*. Le moins coûteux, et souvent immédiatement utile.",
                "**Matrice de corrélation** — répond à *« quelle colonne bouge avec quelle autre »*. Elle oriente tout ce qui suit.",
                "**Grappes** — répond à *« combien de groupes naturels y a-t-il là-dedans »*.",
                "**Prévision** — seulement avec une colonne de temps et au moins **deux cycles complets**.",
                "**Règles d'association** — seulement pour des données en forme de panier : une transaction par ligne, ou deux colonnes identifiant transaction et article.",
                "**Exploration par groupe** — relance les trois premiers **indépendamment dans chaque groupe**. Cette étape renverse fréquemment la conclusion tirée du tableau agrégé.",
            ]),
            .heading("Trois règles pour toute la famille"),
            .bullets([
                "**Chaque résultat porte un bloc « Méthode »** : algorithme, paramètres, graine, formule. Impossible de le désactiver — un tableau de trois nombres qui ne dit pas d'où ils viennent ne peut pas fonder une décision.",
                "**Pas de mesure, pas de conclusion.** Échantillon trop petit, variance nulle, matrice singulière — GEditor refuse et dit pourquoi, au lieu de renvoyer un nombre qui a seulement l'air juste.",
                "**Résultats déterministes.** Les mêmes données donnent le même résultat ; partout où de l'aléatoire est nécessaire, la graine est consignée dans la sortie.",
            ]),
            .heading("Du résultat vers les données"),
            .paragraph("""
                Chaque panneau **marque en retour dans les données source** : cliquez une ligne \
                anormale, une case de corrélation ou une règle d'association, et les lignes \
                concernées sont marquées dans la grille. C'est ainsi qu'on passe de *« quelque chose \
                cloche »* à *« cela cloche exactement dans ces lignes »*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Trouver les lignes anormales",
        summary: "Quatre mesures, trois niveaux de gravité, et une explication du pourquoi.",
        keywords: ["valeur aberrante", "anomalie", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Mesure", "À utiliser quand"],
                rows: [
                    ["z-score", "La colonne est à peu près distribuée normalement"],
                    ["IQR", "La colonne est asymétrique avec une longue queue — le choix sûr par défaut"],
                    ["MAD", "La colonne contient déjà beaucoup d'aberrations et demande une mesure robuste"],
                    ["Mahalanobis", "**Plusieurs colonnes à la fois** — attrape les lignes bizarres par combinaison, pas dans une seule colonne"],
                ]
            ),
            .paragraph("""
                Les résultats sont colorés selon **trois niveaux de gravité** plutôt qu'une couleur \
                uniforme — sinon une ligne légèrement inhabituelle ne se distingue pas d'une ligne \
                follement inhabituelle.
                """),
            .heading("Expliquer pourquoi"),
            .paragraph("""
                Pour la mesure multi-colonnes, GEditor décompose la contribution de chaque colonne et \
                produit une phrase telle que *« anormale surtout par la combinaison chiffre \
                d'affaires (50 %) × quantité (50 %) »*.
                """),
            .note("""
                Ce pourcentage porte sur la *part explicable*, non sur la *distance*. Le bloc Méthode \
                le dit juste sous le tableau.
                """),
            .warning("""
                Une colonne dont l'IQR ou la MAD vaut zéro fait **refuser la mesure**, plutôt que de \
                diviser par quelque chose de minuscule et de produire un score énorme. Dans le cas \
                multi-colonnes, si la matrice de covariance est singulière, GEditor **dit quelle \
                colonne retirer** au lieu d'employer une pseudo-inverse pour « que ça marche ».
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Matrice de corrélation",
        summary: "Pearson et Spearman pour chaque paire, avec un nuage de points au clic.",
        keywords: ["corrélation", "pearson", "spearman", "carte de chaleur", "nuage de points"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coefficient", "Ce qu'il mesure"],
                rows: [
                    ["Pearson", "Une relation **linéaire**"],
                    ["Spearman", "**Toute** relation **monotone**, y compris courbe — calculée sur les rangs"],
                ]
            ),
            .paragraph("""
                Cliquez une case de la carte de chaleur pour voir le nuage de points de cette paire, \
                avec droite de régression et R².
                """),
            .heading("Quatre détails qui changent la lecture"),
            .bullets([
                "**Les ex æquo prennent des rangs moyens** : retrier le tableau ne change donc pas le coefficient de Spearman.",
                "**Les cellules vides sont traitées par paire**, et le `n` de chaque case est juste là dans le tableau — `0,93` sur 6 lignes ne veut pas dire ce que `0,93` sur 6 000 lignes veut dire.",
                "**Une colonne constante renvoie du vide**, pas 0. Zéro veut dire *mesuré, aucune relation trouvée*.",
                "**L'échelle de couleurs est bleu↔orange**, pas rouge-vert : 8 % des hommes voient une échelle rouge-vert comme une seule masse grise, ce qui rend `+0,9` et `−0,9` identiques.",
            ]),
            .warning("""
                **Corrélation n'implique pas causalité.** Cette phrase est dessinée **à l'intérieur \
                même du graphique**, elle voyage donc avec l'image quand vous l'exportez.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Partitionnement en grappes",
        summary: "k-means et DBSCAN, deux façons de choisir k — et un avertissement sur la mise à l'échelle.",
        keywords: ["grappe", "cluster", "kmeans", "dbscan", "silhouette", "coude"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algorithme", "À utiliser quand"],
                rows: [
                    ["k-means", "Vous connaissez (ou voulez essayer) le nombre de grappes ; les grappes sont en amas"],
                    ["DBSCAN", "Vous ignorez le nombre ; les grappes ont des formes quelconques ; vous voulez isoler le bruit"],
                ]
            ),
            .heading("La mise à l'échelle est active par défaut — et pourquoi"),
            .paragraph("""
                Une colonne `chiffre d'affaires` (en millions) à côté d'une colonne `quantité` (en \
                unités) : la distance entre deux lignes est décidée presque entièrement par la plus \
                grande. Ce n'est pas « sous-optimal » — c'est **répondre à une autre question**. La \
                mise à l'échelle en vigueur est consignée dans le résultat.
                """),
            .heading("Choisir le nombre de grappes"),
            .bullets([
                "**Silhouette** — plus le score est haut, mieux les grappes sont séparées. Sur un grand tableau, elle **échantillonne** (à intervalles réguliers, pas les 2 000 premières lignes), et le résultat se déclare une estimation.",
                "**Coude** — trace la somme des carrés intra-grappe en fonction de k. C'est une **façon de lire un graphique**, pas une optimisation : cette quantité baisse toujours quand k monte, il n'existe donc pas de « k optimal » statistiquement.",
            ]),
            .note("""
                Pour DBSCAN, le graphique des **k-distances** aide à choisir un rayon : le genou de \
                la courbe est d'ordinaire une valeur de départ raisonnable.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Prévision de séries temporelles",
        summary: "Décomposition tendance/saison, Holt-Winters, et une référence qui tourne toujours à côté.",
        keywords: ["prévision", "série temporelle", "saisonnalité", "holt-winters", "tendance"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Choisissez une colonne de temps et une colonne de valeurs. GEditor décompose la série \
                en **tendance · saisonnalité · résidu**, puis prévoit avec Holt-Winters (additif ou \
                multiplicatif), avec des intervalles à 80 % et 95 %.
                """),
            .heading("La référence tourne toujours, et elle dit franchement qui a gagné"),
            .paragraph("""
                À côté du modèle, GEditor exécute deux méthodes naïves : *prendre la période \
                précédente* et *prendre la même période de la saison passée*. Si le modèle **perd** \
                contre une référence, cette phrase apparaît à la **première ligne, dans une autre \
                couleur** — et non sous un tableau de nombres.
                """),
            .paragraph("""
                La raison : les outils de prévision tendent à présenter le modèle comme un fait, et \
                l'utilisateur n'a aucun moyen d'apprendre que « prendre simplement le chiffre du mois \
                dernier » aurait été plus exact.
                """),
            .heading("Trois endroits où GEditor refuse, ou se déclare"),
            .bullets([
                "**Sans deux cycles complets, il retombe sur la méthode naïve.** Ajuster une saisonnalité sur le bruit d'un seul cycle et la répéter vers l'avenir produit une prévision très convaincante et entièrement inventée.",
                "**Le MAPE face à un zéro le dit**, et si plus de 25 % des périodes sont nulles, il retient la métrique — les sauter en silence produit un nombre calculé sur un sous-ensemble systématiquement biaisé.",
                "**L'intervalle de confiance se déclare approximatif**, et précise qu'il s'élargit trop lentement aux horizons lointains.",
            ]),
            .note("""
                La période saisonnière est détectée sur la **différence première**, non sur la série \
                brute : une tendance rend tous les décalages fortement corrélés et noie le pic \
                saisonnier.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Règles d'association",
        summary: "Acheter A, souvent acheter B — et pourquoi le tableau est trié par lift, non par confiance.",
        keywords: ["apriori", "règles d'association", "panier", "lift", "support"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Deux formes de données sont acceptées :"),
            .bullets([
                "**Un panier par ligne** — une colonne contenant une liste d'articles.",
                "**Deux colonnes** — identifiant de transaction et article, un article par ligne.",
            ]),
            .table(
                headers: ["Métrique", "Signification"],
                rows: [
                    ["support", "Part des paniers contenant les deux côtés"],
                    ["confiance", "Parmi les paniers ayant le côté gauche, quelle part a le droit"],
                    ["**lift**", "La confiance divisée par le taux de base du côté droit"],
                    ["leverage", "L'écart à ce que prédirait l'indépendance"],
                ]
            ),
            .heading("Trié par lift, non par confiance"),
            .paragraph("""
                Si le côté droit apparaît de toute façon dans 95 % des paniers, alors **chaque** \
                règle qui y mène a environ 95 % de confiance — sans rien dire du tout. Trier par \
                confiance met précisément les règles les plus vides de sens en haut.
                """),
            .warning("""
                `lift < 1` est **signalé dans la ligne même** : 80 % de confiance vers quelque chose \
                dont le taux de base est de 95 % signifie une relation **inverse** — un nombre juste \
                menant à une conclusion fausse.
                """),
            .bullets([
                "Acheter deux briques de lait reste **une** transaction contenant du lait : les doublons dans un panier sont écartés, sinon le support enfle avec la quantité.",
                "Un seuil de support trop bas fait exploser combinatoirement l'ensemble des candidats ; en atteignant le plafond, GEditor **s'arrête et déclare le tableau incomplet**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Explorer par groupe",
        summary: "Relancer l'analyse indépendamment par groupe — l'étape qui renverse le plus souvent une conclusion.",
        keywords: ["par groupe", "simpson", "agences", "comparer les groupes"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Choisissez une colonne de texte comme clé de regroupement. Chaque groupe reçoit \
                anomalies, prévision et corrélation exécutées **de façon totalement indépendante**, \
                puis classées selon le critère que vous choisissez.
                """),
            .heading("Pourquoi les groupes doivent être séparés, non agrégés"),
            .paragraph("""
                Deux agences, l'une autour de 10, l'autre autour de 100. Une barrière d'aberrations \
                calculée sur le tableau **agrégé** tombe autour de ±135 — et elle échoue **dans les \
                deux sens** :
                """),
            .bullets([
                "**Faux négatifs** : une valeur de 20, manifestement anormale pour la petite agence, se loge bien à l'intérieur de la barrière commune. Plus il y a de groupes, plus elle est aveugle.",
                "**Faux positifs** : un groupe très dispersé voit sa queue normale coupée par la barrière commune, et une foule de lignes ordinaires est signalée.",
            ]),
            .heading("La colonne « divergence de corrélation » attrape le paradoxe de Simpson"),
            .paragraph("""
                Trois groupes dans lesquels **chaque** groupe corrèle ses deux colonnes à `−1`, alors \
                qu'agrégés ils corrèlent à `> 0,9`. Qui ne lit que le tableau agrégé conclut \
                **exactement l'inverse**. Cette colonne pointe précisément ces cas.
                """),
            .note("""
                Le panneau n'offre que des **colonnes de texte** comme clés de regroupement, et \
                s'arrête à 1 000 groupes avec un avertissement — pour éviter de choisir une colonne \
                de numéros de commande et de faire de chaque ligne un groupe à elle seule.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Exploration de texte",
        summary: "n-grammes et TF-IDF sur une colonne de texte — trouver les expressions caractéristiques.",
        keywords: ["exploration de texte", "n-gramme", "tf-idf", "mots-clés", "expressions"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                S'exécute sur une colonne de texte — descriptions de produits, retours clients, champs \
                de commentaire.
                """),
            .bullets([
                "**n-grammes** — les expressions de 1, 2 et 3 mots les plus fréquentes.",
                "**TF-IDF** — les mots **caractéristiques** de chaque groupe de documents, c'est-à-dire fréquents ici et rares ailleurs.",
            ]),
            .paragraph("""
                La différence : les n-grammes vous disent *« ce que les clients mentionnent sans \
                cesse »*, le TF-IDF vous dit *« en quoi ce groupe diffère des autres »*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
