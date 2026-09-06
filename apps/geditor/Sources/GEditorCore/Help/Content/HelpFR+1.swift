import Foundation

/// Contenu de l'aide en français — première partie : démarrage et édition.
///
/// **Les `id` de rubrique ne sont JAMAIS traduits.** Ce sont eux que `.seeAlso` vise, eux que le
/// menu ouvre, et eux qui permettent à la fenêtre d'aide de changer de langue **sans renvoyer le
/// lecteur à la table des matières**. Modifier un id casse tous les liens, dans tous les livres à
/// la fois.
///
/// Les intitulés de menu dans `commands:` restent en vietnamien : ils doivent correspondre mot
/// pour mot aux vrais libellés de menu, que `HelpCoverage` vérifie par cette chaîne exacte.
enum HelpFR {}

extension HelpFR {

    static let gettingStarted = HelpChapter(
        id: "bat-dau",
        title: "Premiers pas",
        summary: "Ce que fait GEditor, et où passer vos cinq premières minutes.",
        topics: [intro, firstFiveMinutes, pickATask, largeFiles, twoBuilds]
    )

    static let intro = HelpTopic(
        id: "gioi-thieu",
        title: "Ce qu'est GEditor",
        summary: "Un éditeur de texte et de données à l'échelle du gigaoctet pour macOS, qui parle vietnamien.",
        keywords: ["introduction", "bienvenue", "aperçu", "à propos"],
        blocks: [
            .paragraph("""
                GEditor ouvre un **fichier de 1 Go sans charger 1 Go en mémoire**. Il lit par \
                fenêtre glissante sur un fichier projeté en mémoire : un journal de 200 millions de \
                lignes ou un CSV d'un million de lignes s'ouvre en une seconde environ et défile \
                sans à-coups.
                """),
            .paragraph("""
                Au-delà de l'édition, c'est un **établi pour les données** : voir un CSV comme une \
                grille, le nettoyer, noter sa qualité, l'interroger en SQL, y chercher anomalies et \
                tendances, puis produire un rapport. Et il lit les encodages vietnamiens anciens \
                que la plupart des outils d'aujourd'hui ont oubliés.
                """),
            .heading("Six choses à essayer en premier"),
            .table(
                headers: ["Tâche", "Où aller"],
                rows: [
                    ["Ouvrir un gros fichier sans attendre", "Glissez-le dans la fenêtre — voir « Ouvrir de gros fichiers »"],
                    ["Modifier plusieurs endroits à la fois", "`⌘D` ajoute l'occurrence suivante, puis tapez une seule fois"],
                    ["Chercher avec une expression régulière", "`⌘F`, activez Regex — le moteur est PCRE2 avec JIT"],
                    ["Voir un CSV en grille", "`⌥⌘T` — un million de lignes défile toujours sans à-coups"],
                    ["Nettoyer un tableau en désordre", "`⇧⌘L` l'établi de nettoyage — aperçu avant application"],
                    ["Ouvrir un fichier vietnamien illisible", "Cliquez l'encodage dans la barre d'état"],
                ]
            ),
            .note("""
                Vous venez de Notepad++ ? Une page compare les deux jeux de raccourcis, car \
                quelques touches **échangent leur place** sur macOS au lieu de simplement remplacer \
                `Ctrl` par `⌘`.
                """),
            .seeAlso(["nam-phut-dau", "chon-viec", "file-lon", "di-cu-notepadpp"]),
        ]
    )

    static let firstFiveMinutes = HelpTopic(
        id: "nam-phut-dau",
        title: "Vos cinq premières minutes",
        summary: "Douze raccourcis couvrent l'essentiel du travail quotidien.",
        keywords: ["raccourci", "touches", "démarrer", "bases"],
        blocks: [
            .paragraph("""
                Inutile de tout apprendre. Les douze touches ci-dessous couvrent l'essentiel du \
                travail quotidien ; cherchez le reste le jour où vous en aurez besoin.
                """),
            .shortcuts([
                HelpShortcut("⌘O", "Ouvrir un fichier"),
                HelpShortcut("⇧⌘O", "Ouvrir un dossier entier comme espace de travail"),
                HelpShortcut("⌘T", "Nouvel onglet"),
                HelpShortcut("⌘S", "Enregistrer"),
                HelpShortcut("⌘F", "Rechercher"),
                HelpShortcut("⌥⌘F", "Rechercher et remplacer"),
                HelpShortcut("⇧⌘F", "Rechercher dans un dossier"),
                HelpShortcut("⌘D", "Ajouter l'occurrence suivante à la sélection"),
                HelpShortcut("⌘L", "Aller à la ligne"),
                HelpShortcut("⌘/", "Commenter la ligne avec la syntaxe du langage"),
                HelpShortcut("⌥⌘T", "Basculer grille / texte (fichiers CSV)"),
                HelpShortcut("⌘?", "Rouvrir cette fenêtre d'aide"),
            ]),
            .heading("Trois choses qui surprennent les nouveaux venus"),
            .bullets([
                "**Une opération en masse ne fait QU'UNE étape d'annulation**, même si elle touche un million de lignes. Mauvais tri ? Un seul `⌘Z` et c'est effacé.",
                "**La session se rétablit d'elle-même.** Quittez puis rouvrez : les onglets reviennent à leur place, y compris ceux non enregistrés. Rien à activer.",
                "**Taper sans accents trouve quand même les mots accentués**, dans chaque champ de recherche et de filtre — tapez `hue` pour obtenir `Huế`, `da nang` pour `Đà Nẵng`.",
            ]),
            .seeAlso(["chon-viec", "nhieu-con-nhay", "tim-va-thay"]),
        ]
    )

    static let pickATask = HelpTopic(
        id: "chon-viec",
        title: "Que cherchez-vous à faire ?",
        summary: "Un tableau qui va des tâches réelles au chapitre qui les traite.",
        keywords: ["index", "recherche", "comment faire"],
        blocks: [
            .paragraph("""
                La table des matières à gauche est classée par **fonction**. Ce tableau-ci est \
                classé par **tâche**, car les deux ordres ne coïncident pas.
                """),
            .table(
                headers: ["J'ai besoin de…", "Voir"],
                rows: [
                    ["Modifier le même endroit sur des centaines de lignes", "Curseurs multiples · Sélection en bloc"],
                    ["Reformater en masse avec une regex", "Rechercher-remplacer · Expressions régulières"],
                    ["Répéter une suite d'actions", "Macros"],
                    ["Ouvrir un CSV qu'on m'a envoyé", "La grille CSV"],
                    ["Nettoyer un tableau : dates mêlées, nombres en texte", "Le flux de nettoyage des données"],
                    ["Juger si un tableau est fiable", "Notation de la qualité des données"],
                    ["Trouver anomalies, tendances, groupes", "Le flux d'exploration des données"],
                    ["Poser des questions en SQL", "Interroger un CSV en SQL"],
                    ["Publier un rapport dont les chiffres se rafraîchissent", "Rapports `.greport.md`"],
                    ["Dessiner un schéma dans un document", "Mermaid"],
                    ["Ouvrir un fichier vietnamien illisible", "Encodages vietnamiens"],
                    ["Automatiser depuis le shell ou AppleScript", "Automatisation"],
                    ["Colorer un format inventé par mon entreprise", "Langages définis par l'utilisateur"],
                ]
            ),
            .note("""
                Absent de la liste ? Le champ de recherche en haut à gauche fouille **le texte et \
                les exemples de code** : taper une clé de configuration comme `fail_under` mène \
                directement à la bonne page.
                """),
        ]
    )

    static let largeFiles = HelpTopic(
        id: "file-lon",
        title: "Ouvrir de gros fichiers",
        summary: "Pourquoi 1 Go s'ouvre, et où GEditor refuse exprès plutôt que de deviner.",
        keywords: ["gros fichier", "gigaoctet", "journal", "mmap", "lent", "performance"],
        blocks: [
            .paragraph("""
                Le fichier est **projeté en mémoire** et lu par fenêtre glissante ; la partie que \
                vous modifiez vit dans une piece table. En pratique : le temps d'ouverture ne \
                dépend presque pas de la taille du fichier, ni la mémoire occupée.
                """),
            .heading("Là où il refuse exprès"),
            .paragraph("""
                Quelques calculs devraient lire tout le fichier en une seule chaîne — précisément \
                ce que cette architecture évite. Là, GEditor **dit qu'il ne le fera pas** au lieu \
                de ramper en silence ou de deviner :
                """),
            .table(
                headers: ["Opération", "Plafond", "Au-delà"],
                rows: [
                    ["Correspondance des parenthèses", "1 Mo", "Refuse et le dit — surligner la mauvaise paire est pire que rien"],
                    ["Colonne visuelle dans la barre d'état", "200 Ko", "Repasse au comptage d'octets, et le marque `~` pour que le sens reste visible"],
                    ["Aperçu Markdown", "4 Mo", "Refuse et s'explique"],
                ]
            ),
            .warning("""
                Un nombre qui a l'air identique mais signifie autre chose est la pire sorte \
                d'erreur. C'est pourquoi une colonne au-delà du plafond s'écrit `~1234`, et non \
                `1234`.
                """),
            .heading("Astuces pour les journaux"),
            .bullets([
                "`Fichier ▸ Suivre le fichier (tail -f)` ajoute ce qui est écrit à la fin. Le document devient **en lecture seule** pendant le suivi — taper pendant que du texte arrive du disque, c'est deux écrivains qui se disputent un document, et le perdant est toujours ce que vous venez de taper.",
                "Les lignes de journal sont **colorées par gravité**, et filtrables par niveau.",
                "La **carte du document** (`⌥⌘M`) décrit tout le fichier, pas seulement la partie à l'écran.",
            ]),
            .seeAlso(["ban-do-tai-lieu", "dinh-dang-log"]),
        ]
    )

    static let twoBuilds = HelpTopic(
        id: "hai-ban-phat-hanh",
        title: "Version App Store et téléchargement direct",
        summary: "Trois fonctions que seule la version directe possède, et pourquoi.",
        keywords: ["app store", "bac à sable", "sandbox", "téléchargement", "cli", "extension"],
        blocks: [
            .paragraph("""
                GEditor est publié en deux versions. Elles proviennent des **mêmes sources** et \
                l'application reconnaît laquelle elle est au lancement. La différence tient à ce \
                que l'App Sandbox autorise.
                """),
            .table(
                headers: ["Fonction", "App Store", "Téléchargement direct"],
                rows: [
                    ["Édition, CSV, nettoyage, exploration, rapports", "Oui", "Oui"],
                    ["L'outil en ligne de commande `geditor`", "Non", "Oui"],
                    ["Filtrer du texte par une commande externe", "Non", "Oui"],
                    ["Extensions natives (processus séparé)", "Non", "Oui"],
                    ["Mise à jour automatique", "Par l'App Store", "Dans l'application"],
                ]
            ),
            .paragraph("""
                Chaque « Non » ci-dessus découle de la même règle : le bac à sable **interdit \
                d'exécuter du code hors de l'application**. C'est le prix de la distribution sur \
                l'App Store, pas un oubli.
                """),
            .note("""
                Dans la version App Store, ces commandes **restent dans le menu** et expliquent \
                pourquoi elles sont indisponibles, au lieu de disparaître. Un élément de menu \
                absent devient une question au support ; une réponse sur place, non.
                """),
            .heading("L'accès aux fichiers dans la version App Store"),
            .paragraph("""
                La version en bac à sable ne touche que les fichiers que vous avez vous-même \
                ouverts ou glissés. GEditor conserve un **signet à portée de sécurité** pour chaque \
                onglet et pour le dossier de l'espace de travail, si bien que votre session rouvre \
                après avoir quitté sans redemander l'autorisation.
                """),
            .seeAlso(["dong-lenh", "plugin"]),
        ]
    )

    // MARK: - Édition

    static let editing = HelpChapter(
        id: "soan-thao",
        title: "Édition",
        summary: "Modifier plusieurs endroits à la fois, travailler sur les lignes, et les règles cachées à connaître d'abord.",
        topics: [
            multipleCarets, columnBlock, columnEditor, lineOperations,
            whitespaceAndIndent, caseConversion, commentsAndBrackets, undoAndClipboard,
        ]
    )

    static let multipleCarets = HelpTopic(
        id: "nhieu-con-nhay",
        title: "Curseurs multiples",
        summary: "Sélectionner chaque endroit qui correspond, taper une fois, tout changer.",
        keywords: ["multi-curseur", "cmd+d", "sélection multiple"],
        commands: ["Chọn lần kế tiếp", "Chọn tất cả"],
        blocks: [
            .paragraph("""
                Cela remplace la plupart des moments où vous alliez écrire une expression \
                régulière. Sélectionnez un mot, appuyez quelques fois sur `⌘D` pour ramasser les \
                occurrences suivantes, puis tapez — tous les endroits changent d'un coup.
                """),
            .shortcuts([
                HelpShortcut("⌘D", "Ajouter l'occurrence suivante à la sélection"),
                HelpShortcut("⌘ + clic", "Poser un curseur de plus à l'endroit cliqué"),
                HelpShortcut("Esc", "Tout abandonner, revenir à un seul curseur"),
                HelpShortcut("⌥ + glisser", "Sélection en bloc (autre façon d'obtenir plusieurs curseurs)"),
            ]),
            .heading("Règles à connaître"),
            .bullets([
                "Taper, supprimer et coller sur plusieurs curseurs ne fait **qu'une** étape d'annulation, pas une par curseur.",
                "Les curseurs survivent aux flèches — tout le groupe se déplace ensemble.",
                "`⌘D` saute les endroits déjà dans la sélection : appuyer trop n'empile jamais deux curseurs au même point.",
            ]),
            .note("""
                `⌘D` sur un mot dans une longue chaîne était lent autrefois. La détection des \
                limites de mot lit désormais par lots — environ **42× plus vite** sur une chaîne \
                de 1 Mo, ce qui rend la chose utilisable sur des fichiers de données, pas seulement \
                sur du code.
                """),
            .seeAlso(["chon-khoi-cot", "column-editor", "tim-va-thay"]),
        ]
    )

    static let columnBlock = HelpTopic(
        id: "chon-khoi-cot",
        title: "Sélection en bloc de colonnes",
        summary: "Sélectionner un rectangle sur plusieurs lignes — à la souris ou au clavier.",
        keywords: ["mode colonne", "bloc", "alt glisser", "rectangle", "clavier", "flèches"],
        blocks: [
            .paragraph("""
                Maintenez `⌥` et glissez pour sélectionner un **bloc rectangulaire**. Taper, \
                supprimer et coller suivent le bloc. Coller un bloc sur un seul curseur conserve \
                son rectangle.
                """),
            .shortcuts([
                HelpShortcut("⌥ + glisser", "Sélectionner un bloc"),
                HelpShortcut("⌥⌘← →", "Élargir le bloc d'une colonne à gauche/droite"),
                HelpShortcut("⌥⌘↑ ↓", "Étendre le bloc d'une ligne vers le haut/bas"),
            ]),
            .paragraph("""
                Le chemin clavier n'est pas un pis-aller de la souris : sélectionner un bloc de 40 \
                lignes en glissant oblige à glisser à travers un défilement, tandis que `⌥⌘` + \
                flèches garde la précision colonne par colonne. Appuyer sur **toute autre** touche \
                (ou taper) met fin au bloc que vous étendiez.
                """),
            .heading("Ici, les colonnes sont des colonnes VISUELLES"),
            .paragraph("""
                Une tabulation s'étend jusqu'au taquet suivant selon votre largeur de tabulation, \
                au lieu de compter pour une colonne. C'est ce qui fait que les lignes indentées par \
                tabulations et par espaces **s'alignent comme à l'écran**.
                """),
            .paragraph("""
                Le texte multi-octet reste une colonne : `Nguyễn` occupe six colonnes, pas neuf.
                """),
            .table(
                headers: ["Situation", "Ce que fait GEditor"],
                rows: [
                    ["La colonne visée tombe au milieu d'une tabulation", "Se cale sur le bord le plus proche ; à égalité, vers la gauche"],
                    ["Une ligne est plus courte que la colonne de départ", "Cette ligne apporte une sélection vide, et accepte quand même le texte tapé"],
                    ["Coller un bloc sur un seul curseur", "Conserve le rectangle, en insérant sur les lignes du dessous"],
                ]
            ),
            .seeAlso(["nhieu-con-nhay", "column-editor"]),
        ]
    )

    static let columnEditor = HelpTopic(
        id: "column-editor",
        title: "Éditeur de colonnes",
        summary: "Insérer un texte, une série de nombres ou de dates sur chaque ligne d'un bloc.",
        keywords: ["éditeur de colonnes", "numérotation", "séquence", "série"],
        commands: ["Column Editor…"],
        blocks: [
            .paragraph("""
                Sélectionnez un bloc de colonnes, puis ouvrez `Édition ▸ Éditeur de colonnes…` \
                (`⌥⌘C`). La boîte de dialogue offre un **aperçu** avant toute application.
                """),
            .table(
                headers: ["Mode", "Paramètres", "Quand l'utiliser"],
                rows: [
                    ["Texte", "Une chaîne fixe", "Ajouter le même préfixe/suffixe à chaque ligne"],
                    ["Série de nombres", "Début · pas · base 2·8·10·16 · zéros de tête", "Numéroter des lignes, engendrer des codes"],
                    ["Série de dates", "Première date · pas en jours", "Produire une colonne de dates consécutives"],
                ]
            ),
            .code(
                language: "text", caption: "Numérotation à zéros de tête, début 1, pas 1",
                source: """
                    Avant :           Après (série de nombres, 3 chiffres) :
                    hà nội            001 hà nội
                    hải phòng         002 hải phòng
                    đà nẵng           003 đà nẵng
                    """
            ),
            .bullets([
                "Un pas **négatif** est valide — compter à rebours fonctionne.",
                "Insérer dans 5 000 lignes ne fait toujours **qu'une** étape d'annulation.",
            ]),
            .seeAlso(["chon-khoi-cot"]),
        ]
    )

    static let lineOperations = HelpTopic(
        id: "thao-tac-dong",
        title: "Opérations sur les lignes",
        summary: "Trier, dédoublonner, déplacer, joindre, scinder, dupliquer, supprimer.",
        keywords: ["trier", "dupliquer", "dédoublonner", "déplacer une ligne", "joindre", "scinder"],
        commands: [
            "Sắp xếp A→Z", "Sắp xếp Z→A", "Sắp xếp tự nhiên", "Khử trùng lặp",
            "Đảo thứ tự dòng", "Dời dòng lên", "Dời dòng xuống", "Ghép dòng",
            "Tách dòng theo độ dài…", "Tách dòng theo ký tự…", "Nhân đôi dòng", "Xóa dòng",
        ],
        blocks: [
            .paragraph("""
                S'il y a une sélection, la commande s'y applique ; sinon elle s'applique au \
                **document entier**. Chaque commande d'ici est une seule étape d'annulation.
                """),
            .shortcuts([
                HelpShortcut("⇧⌘D", "Dupliquer la ligne"),
                HelpShortcut("⌘K", "Supprimer la ligne"),
                HelpShortcut("⌥↑ / ⌥↓", "Déplacer la ligne vers le haut / le bas"),
            ]),
            .heading("Trois sortes de tri, et laquelle choisir"),
            .table(
                headers: ["Sorte", "`file2` vs `file10`", "Pour"],
                rows: [
                    ["A→Z / Z→A", "`file10` vient avant `file2`", "Listes de mots simples"],
                    ["Naturel", "`file2` vient avant `file10`", "Noms de fichiers, identifiants codés, versions"],
                ]
            ),
            .paragraph("""
                Le tri **naturel** lit les suites de chiffres comme des nombres. C'est presque \
                toujours ce que vous voulez quand la liste est numérotée.
                """),
            .heading("Dédoublonnage"),
            .bullets([
                "**Document entier** — supprime toute ligne déjà apparue, garde la première.",
                "**Voisines seulement** — fusionne les lignes identiques contiguës, comme `uniq` d'Unix.",
            ]),
            .heading("Joindre et scinder"),
            .bullets([
                "**Joindre les lignes** fusionne les lignes sélectionnées en une seule.",
                "**Scinder par longueur** coupe les longues lignes à un nombre de caractères donné.",
                "**Scinder par caractère** coupe à chaque occurrence d'un caractère que vous tapez — par exemple pour éclater une ligne CSV en cellules.",
            ]),
            .note("""
                Dupliquer la **dernière ligne** d'un fichier ajoute le saut de ligne manquant ; \
                supprimer jusqu'à la fin du document avale aussi le saut de ligne précédent. Les \
                deux diffèrent de l'implémentation naïve, et existent pour que le fichier ne \
                finisse pas avec une ligne vide de trop — ou sans la ligne qu'il fallait.
                """),
            .seeAlso(["khoang-trang-thut-le", "danh-dau-dong"]),
        ]
    )

    static let whitespaceAndIndent = HelpTopic(
        id: "khoang-trang-thut-le",
        title: "Espaces et indentation",
        summary: "Nettoyer les espaces parasites, convertir tabulation ↔ espace, et un réglage à peser.",
        keywords: ["espaces", "tabulation", "indentation", "lignes vides"],
        commands: [
            "Xóa dòng rỗng", "Nén dòng trống liên tiếp", "Cắt khoảng trắng cuối dòng",
            "Tab → Space", "Space → Tab", "Cắt khoảng trắng cuối dòng khi lưu",
        ],
        blocks: [
            .table(
                headers: ["Commande", "Ce qu'elle fait"],
                rows: [
                    ["Supprimer les lignes vides", "Supprime toute ligne sans rien dessus"],
                    ["Compacter les lignes vides consécutives", "Plusieurs lignes vides d'affilée n'en font plus qu'une"],
                    ["Couper les espaces de fin de ligne", "Retire espaces et tabulations parasites en fin de ligne"],
                    ["Tabulation → Espace", "Convertit les tabulations en espaces à la largeur courante"],
                    ["Espace → Tabulation", "L'autre sens"],
                ]
            ),
            .heading("Indentation par langage"),
            .paragraph("""
                Cliquez `Tab: 4` dans la barre d'état. Le haut du menu la change pour **toute \
                l'application** ; le bas — `Seulement pour Go`, `Seulement pour Python`… — ne \
                s'applique qu'au langage du fichier ouvert, et retient s'il faut des tabulations ou \
                des espaces.
                """),
            .paragraph("""
                Les gens ne choisissent pas l'indentation par goût mais par **convention de \
                communauté** : Go utilise des tabulations (`gofmt` prime sur tout le reste), Python \
                quatre espaces selon PEP 8, JavaScript et YAML deux le plus souvent. Un seul nombre \
                pour tous les langages, et chaque fichier que vous touchez gagne des lignes que \
                vous n'avez jamais modifiées.
                """),
            .code(
                language: "json", caption: "settings.json",
                source: """
                    "languageIndent": {
                      "go":         { "width": 4, "usesTabs": true },
                      "python":     { "width": 4, "usesTabs": false },
                      "javascript": { "width": 2, "usesTabs": false }
                    }
                    """
            ),
            .note("""
                Le déclarer dans `settings.json` marche aussi — la clé est le code du langage \
                (`go`, `python`, `javascript`…). Les langages absents utilisent le `tabWidth` \
                commun.
                """),
            .heading("Pourquoi « couper à l'enregistrement » est DÉSACTIVÉ par défaut"),
            .paragraph("""
                Le réglage `Fichier ▸ Couper les espaces de fin à l'enregistrement` modifie **des \
                lignes que vous n'avez jamais touchées**. Activé par défaut, une correction d'un \
                mot dans le dépôt d'autrui devient un diff de mille lignes, et le relecteur ne \
                trouve plus le vrai changement.
                """),
            .paragraph("""
                Quand il est actif, la coupe est une **étape d'annulation distincte** placée avant \
                l'écriture — une annulation rend le document tel qu'il était, sans perdre ce que \
                vous venez d'enregistrer.
                """),
            .heading("Indentation automatique"),
            .bullets([
                "Une nouvelle ligne hérite de l'indentation de la précédente, plus un niveau après un jeton ouvrant — `{` pour les langages à accolades, `:` pour Python et YAML.",
                "La mesure se fait en **colonnes visuelles**, si bien que les fichiers mêlant tabulations et espaces restent alignés à l'écran.",
                "Il n'y a **pas** de règle « taper `}` ré-indente la ligne ». Cette règle modifie une ligne que vous aviez finie, et c'est le comportement le plus critiqué de tous les éditeurs qui l'ont.",
            ]),
        ]
    )

    static let caseConversion = HelpTopic(
        id: "doi-hoa-thuong",
        title: "Casse et conventions de nommage",
        summary: "Huit conversions, dont camelCase, snake_case et kebab-case.",
        keywords: ["casse", "majuscules", "minuscules", "camel", "snake", "kebab"],
        commands: [
            "HOA", "thường", "Chữ Hoa Đầu Từ", "Chữ hoa đầu câu", "Đảo hoa/thường",
            "camelCase", "snake_case", "kebab-case",
        ],
        blocks: [
            .paragraph("Appliqué à la sélection. Toutes vivent dans le menu `Format`."),
            .table(
                headers: ["Commande", "`tổng doanh thu` devient"],
                rows: [
                    ["MAJUSCULES", "`TỔNG DOANH THU`"],
                    ["minuscules", "`tổng doanh thu`"],
                    ["Casse De Titre", "`Tổng Doanh Thu`"],
                    ["Casse de phrase", "`Tổng doanh thu`"],
                    ["Inverser la casse", "Retourne chaque caractère"],
                    ["camelCase", "`tongDoanhThu`"],
                    ["snake_case", "`tong_doanh_thu`"],
                    ["kebab-case", "`tong-doanh-thu`"],
                ]
            ),
            .note("""
                Les trois dernières retirent les accents vietnamiens, car elles produisent des \
                **identifiants de code** — où les lettres accentuées sont généralement interdites.
                """),
        ]
    )

    static let commentsAndBrackets = HelpTopic(
        id: "comment-va-ngoac",
        title: "Commentaires et parenthèses",
        summary: "⌘/ utilise le marqueur propre au langage ; ⌃⌘B saute à la parenthèse correspondante.",
        keywords: ["commentaire", "parenthèse", "cmd+/", "correspondance"],
        commands: ["Comment dòng", "Nhảy tới ngoặc khớp"],
        blocks: [
            .paragraph("""
                `⌘/` choisit le marqueur de commentaire **selon le langage du document** : `#` pour \
                Python, `//` pour Rust et C, `<!-- -->` pour XML et HTML.
                """),
            .heading("Tout le bloc va dans le même sens"),
            .paragraph("""
                Si une seule ligne du bloc n'est pas commentée, la commande commente **tout**. \
                Décider ligne par ligne transformerait un bloc à moitié commenté en damier. Le \
                marqueur est inséré à l'indentation la moins profonde du bloc, qui garde ainsi sa \
                forme.
                """),
            .heading("Sauter à la parenthèse correspondante"),
            .bullets([
                "`⌃⌘B` saute à la parenthèse qui correspond à celle sous le curseur.",
                "Les parenthèses dans les **chaînes** ou les **commentaires** ne comptent pas — un analyseur léger les distingue.",
                "Au-delà d'**1 Mo**, la commande refuse et le dit plutôt que de s'ancrer à mi-chemin et de deviner. Surligner la mauvaise paire est pire que n'en surligner aucune.",
            ]),
            .seeAlso(["ngon-ngu-dung-san", "file-lon"]),
        ]
    )

    static let undoAndClipboard = HelpTopic(
        id: "hoan-tac-clipboard",
        title: "Annulation et presse-papiers",
        summary: "Historique d'annulation illimité, et un presse-papiers à plusieurs cases.",
        keywords: ["annuler", "rétablir", "presse-papiers", "coller", "historique"],
        commands: ["Hoàn tác", "Làm lại", "Cắt", "Sao chép", "Dán", "Lịch sử clipboard…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘Z / ⇧⌘Z", "Annuler / Rétablir"),
                HelpShortcut("⌘X / ⌘C / ⌘V", "Couper / Copier / Coller"),
                HelpShortcut("⇧⌘V", "Historique du presse-papiers"),
            ]),
            .heading("Une opération en masse ne fait QU'UNE étape"),
            .paragraph("""
                Trier un million de lignes, remplacer dix mille occurrences, insérer dans cinq \
                mille lignes avec l'éditeur de colonnes — chacune s'annule d'**un seul** `⌘Z`.
                """),
            .paragraph("""
                L'historique d'annulation vit dans le tampon de texte propre à GEditor plutôt que \
                dans l'`UndoManager` du système, précisément pour cette raison : `UndoManager` \
                compte les frappes.
                """),
            .heading("Historique du presse-papiers"),
            .paragraph("""
                `⇧⌘V` ouvre la liste de ce que vous avez copié récemment et colle l'entrée choisie. \
                Utile quand il faut alterner deux fragments à de nombreux endroits.
                """),
        ]
    )
}
