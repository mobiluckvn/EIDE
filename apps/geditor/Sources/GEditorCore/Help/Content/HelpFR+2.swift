import Foundation

/// Contenu de l'aide en français — deuxième partie : recherche, fichiers et sessions.
extension HelpFR {

    static let search = HelpChapter(
        id: "tim-kiem",
        title: "Recherche",
        summary: "Rechercher, remplacer, expressions régulières, recherche sur un dossier et marques de ligne.",
        topics: [findReplace, regularExpressions, replacementStrings, findInFiles, lineMarks, goToLine]
    )

    static let findReplace = HelpTopic(
        id: "tim-va-thay",
        title: "Rechercher et remplacer",
        summary: "Trois modes de recherche, et pourquoi ^ signifie début de LIGNE par défaut.",
        keywords: ["rechercher", "remplacer", "recherche", "cmd+f"],
        commands: ["Tìm…", "Tìm và thay…", "Kết quả kế", "Kết quả trước"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘F", "Rechercher"),
                HelpShortcut("⌥⌘F", "Rechercher et remplacer"),
                HelpShortcut("⌘G / ⇧⌘G", "Occurrence suivante / précédente"),
            ]),
            .heading("Trois modes"),
            .table(
                headers: ["Mode", "Comprend", "Pour"],
                rows: [
                    ["Normal", "Du texte brut, aucun caractère spécial", "La plupart des recherches"],
                    ["Étendu", "`\\n` `\\r` `\\t` `\\0` `\\xNN`", "Trouver sauts de ligne, tabulations, octets précis"],
                    ["Regex", "PCRE2 complet", "Chercher par motif"],
                ]
            ),
            .note("""
                Le mode **étendu** ne comprend pas la syntaxe des regex. Il n'étend que quelques \
                séquences d'échappement — y chercher `a.b` trouve exactement ces trois caractères ; \
                le point n'est pas un joker.
                """),
            .heading("Deux interrupteurs"),
            .bullets([
                "**Respecter la casse** — désactivé par défaut.",
                "**Mot entier** — ne correspond que si les deux extrémités sont des limites de mot.",
            ]),
            .heading("`^` et `$` correspondent aux bords de chaque LIGNE"),
            .paragraph("""
                Activé par défaut. Ceux qui viennent de Notepad++ attendent que `^` signifie « début \
                de ligne » ; sans cela, `^abc` ne correspondrait que si tout le document commençait \
                par `abc` — presque personne ne veut cela dans un éditeur de texte.
                """),
            .heading("Une mauvaise expression ne bloquera pas l'application"),
            .paragraph("""
                Le moteur est **PCRE2 compilé en JIT**, avec un budget de retour arrière. Un motif \
                qui explose de façon combinatoire est arrêté et signalé, au lieu de figer la \
                fenêtre.
                """),
            .seeAlso(["bieu-thuc-chinh-quy", "chuoi-thay-the", "tim-trong-thu-muc"]),
        ]
    )

    static let regularExpressions = HelpTopic(
        id: "bieu-thuc-chinh-quy",
        title: "Expressions régulières",
        summary: "La syntaxe PCRE2 qu'on utilise vraiment, avec des exemples qui tournent sur des données vietnamiennes.",
        keywords: ["regex", "pcre", "motif"],
        commands: ["Thử biểu thức chính quy…"],
        blocks: [
            .paragraph("""
                GEditor utilise **PCRE2**, le même moteur que PHP et de nombreux outils en ligne de \
                commande. Ouvrez `Recherche ▸ Tester une expression régulière…` pour essayer un \
                motif sur un texte d'exemple et voir ce que capture chaque groupe **avant** de \
                l'appliquer à un vrai document.
                """),
            .heading("Classes de caractères"),
            .table(
                headers: ["Écrire", "Correspond à"],
                rows: [
                    ["`.`", "N'importe quel caractère sauf un saut de ligne"],
                    ["`\\d` · `\\D`", "Un chiffre · pas un chiffre"],
                    ["`\\w` · `\\W`", "Un caractère de mot (lettre, chiffre, `_`) · l'inverse"],
                    ["`\\s` · `\\S`", "Un blanc · pas un blanc"],
                    ["`[abc]`", "L'un des caractères entre crochets"],
                    ["`[^abc]`", "Un caractère qui n'est PAS entre crochets"],
                    ["`[a-z]`", "Un caractère de l'intervalle"],
                ]
            ),
            .heading("Répétition"),
            .table(
                headers: ["Écrire", "Signification"],
                rows: [
                    ["`*`", "Zéro ou plus"],
                    ["`+`", "Un ou plus"],
                    ["`?`", "Zéro ou un"],
                    ["`{3}` · `{2,5}` · `{2,}`", "Exactement 3 · entre 2 et 5 · 2 ou plus"],
                    ["`*?` `+?` `??`", "Les formes **paresseuses** — prendre le moins possible"],
                ]
            ),
            .warning("""
                `.*` est **gourmand** : il mange jusqu'au bout de la ligne puis recule. Pour \
                découper des champs à l'intérieur d'une ligne, il vous faut presque toujours `.*?` \
                ou une classe étroite comme `[^,]*`.
                """),
            .heading("Ancres et groupes"),
            .table(
                headers: ["Écrire", "Signification"],
                rows: [
                    ["`^` · `$`", "Début de ligne · fin de ligne"],
                    ["`\\b`", "Limite de mot"],
                    ["`(…)`", "Groupe **capturant** — réutilisable dans le remplacement"],
                    ["`(?:…)`", "Groupe non capturant"],
                    ["`(?<name>…)`", "Groupe nommé"],
                    ["`a|b`", "a ou b"],
                    ["`(?=…)` · `(?!…)`", "Anticipation : doit suivre · ne doit pas suivre"],
                    ["`(?<=…)` · `(?<!…)`", "Rétrospection : doit précéder · ne doit pas précéder"],
                ]
            ),
            .heading("Des exemples qui tournent"),
            .code(language: "regex", caption: "Tout numéro de téléphone vietnamien à 10 chiffres",
                  source: "\\b0\\d{9}\\b"),
            .code(language: "regex", caption: "Découper une date 31/12/2026 en trois groupes",
                  source: "(\\d{1,2})/(\\d{1,2})/(\\d{4})"),
            .code(language: "regex", caption: "La troisième cellule d'une ligne CSV simple (sans guillemets)",
                  source: "^[^,]*,[^,]*,([^,]*)"),
            .code(language: "regex", caption: "Lignes de journal en ERROR ou FATAL, avec leur horodatage",
                  source: "^(\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}).*\\b(ERROR|FATAL)\\b"),
            .code(language: "regex", caption: "Lignes vides, ou ne contenant que des blancs",
                  source: "^\\s*$"),
            .code(language: "regex", caption: "Lettres vietnamiennes accentuées — utilisez la classe Unicode, ne les énumérez pas",
                  source: "\\p{L}+"),
            .note("""
                `\\p{L}` signifie « n'importe quelle lettre Unicode », donc cela attrape aussi `ế` \
                et `đ`. Énumérer à la main chaque voyelle accentuée est le moyen sûr d'en oublier.
                """),
            .seeAlso(["chuoi-thay-the", "tim-va-thay"]),
        ]
    )

    static let replacementStrings = HelpTopic(
        id: "chuoi-thay-the",
        title: "Chaînes de remplacement",
        summary: "Réutiliser les groupes capturés, et changer la casse pendant le remplacement.",
        keywords: ["remplacer", "référence arrière", "groupe", "$1", "\\U"],
        blocks: [
            .heading("Rappeler un groupe capturé"),
            .table(
                headers: ["Écrire", "Signification"],
                rows: [
                    ["`$1` … `$9`", "Le contenu du groupe n"],
                    ["`${1}`", "Le même, avec bornes explicites — à utiliser quand un chiffre suit"],
                    ["`\\1`", "Accepté aussi ; GEditor le réécrit en `${1}`"],
                    ["`$0`", "La correspondance entière"],
                ]
            ),
            .note("""
                Écrivez `${1}` plutôt que `$1` quand le caractère suivant est un chiffre. `$123` se \
                lit comme le groupe 123 ; `${1}23` est le groupe 1 suivi de deux chiffres.
                """),
            .heading("Changer la casse pendant un remplacement"),
            .table(
                headers: ["Écrire", "Signification"],
                rows: [
                    ["`\\U`", "MAJUSCULES à partir d'ici"],
                    ["`\\L`", "minuscules à partir d'ici"],
                    ["`\\u`", "Seul le caractère suivant en majuscule"],
                    ["`\\l`", "Seul le caractère suivant en minuscule"],
                    ["`\\E`", "Fin de la zone `\\U` ou `\\L`"],
                ]
            ),
            .heading("Exemples"),
            .code(language: "text", caption: "Transformer 31/12/2026 en 2026-12-31",
                  source: """
                    Rechercher : (\\d{1,2})/(\\d{1,2})/(\\d{4})
                    Remplacer  : $3-$2-$1
                    """),
            .code(language: "text", caption: "Mettre en majuscules le code de province en début de ligne, garder le reste",
                  source: """
                    Rechercher : ^([a-z]{2,3})(\\s)
                    Remplacer  : \\U$1\\E$2
                    """),
            .code(language: "text", caption: "Envelopper chaque ligne comme une chaîne JSON",
                  source: """
                    Rechercher : ^(.+)$
                    Remplacer  : "$1",
                    """),
            .paragraph("""
                Un groupe qui **n'a pas participé** à la correspondance devient une chaîne vide, pas \
                une erreur — un motif à alternatives comme `(a)|(b)` remplace donc proprement sans \
                l'écrire deux fois.
                """),
            .seeAlso(["bieu-thuc-chinh-quy"]),
        ]
    )

    static let findInFiles = HelpTopic(
        id: "tim-trong-thu-muc",
        title: "Rechercher et remplacer dans un dossier",
        summary: "Parcourir plusieurs fichiers d'un coup, et voir les résultats avant toute écriture.",
        keywords: ["recherche multi-fichiers", "grep", "remplacement en masse", "dossier"],
        commands: ["Tìm trong thư mục…", "Thay trong thư mục…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘F", "Rechercher dans un dossier")]),
            .paragraph("""
                Choisissez le dossier racine, filtrez par motif de nom de fichier, puis lancez le \
                balayage. Les résultats apparaissent groupés par fichier ; cliquer une ligne ouvre \
                ce fichier à cette position.
                """),
            .bullets([
                "Les mêmes trois modes de recherche et le même moteur de regex que le champ de recherche dans le document.",
                "Le remplacement sur un dossier **prévisualise** combien de fichiers et combien d'occurrences vont changer avant d'écrire.",
                "Le balayage tourne en parallèle et **peut être annulé** en cours de route.",
            ]),
            .warning("""
                Le remplacement sur un dossier écrit directement dans des fichiers **non ouverts**. \
                Ces fichiers ne sont pas dans l'historique d'annulation du document ouvert — \
                prévisualisez d'abord, et gardez une sauvegarde ou un dépôt versionné.
                """),
            .heading("Recherches précédentes et export des résultats"),
            .paragraph("""
                Le panneau de résultats **garde les recherches de cette session**. Le menu local en \
                haut du panneau les liste avec leur nombre d'occurrences — cherchez `TODO`, lisez à \
                moitié, cherchez `FIXME` pour comparer, puis revenez à la première liste sans \
                rebalayer tout le dossier.
                """),
            .paragraph("""
                Le bouton **Exporter** ouvre la recherche courante comme onglet texte, un résultat \
                par ligne au format `chemin:ligne:colonne: texte` — la forme qu'utilise `grep -n` et \
                celle des messages d'erreur des compilateurs. Chaque ligne se colle telle quelle \
                dans la boîte `Aller à` de ce produit, et vos `grep`, `awk` et `sed` la lisent sans \
                analyseur maison.
                """),
            .note("""
                L'historique vit **en mémoire** et n'est jamais écrit sur disque : les résultats de \
                recherche portent le contenu de chaque ligne trouvée, c'est-à-dire la même classe de \
                données que l'historique du presse-papiers ne conserve délibérément pas.
                """),
            .seeAlso(["tim-va-thay", "macro-chay-hang-loat", "di-toi-dong"]),
        ]
    )

    static let lineMarks = HelpTopic(
        id: "danh-dau-dong",
        title: "Marques de ligne",
        summary: "Neuf couleurs de marque, et quatre commandes qui transforment les lignes marquées en résultat.",
        keywords: ["signet", "marque", "f2", "filtrer les lignes"],
        commands: [
            "Đánh dấu mọi dòng khớp…", "Đảo dấu", "Bỏ mọi dấu",
            "Chép dòng đã đánh dấu", "Xóa dòng đã đánh dấu", "Chỉ giữ dòng đã đánh dấu",
            "Đánh dấu dòng này", "Dấu kế tiếp", "Dấu trước đó", "Màu đánh dấu…",
        ],
        blocks: [
            .paragraph("""
                Marquer, c'est filtrer un document **sans le modifier**. Marquez chaque ligne qui \
                correspond à un motif, puis copiez seulement celles-là, ou ne gardez qu'elles.
                """),
            .shortcuts([
                HelpShortcut("⌘M", "Marquer chaque ligne correspondant à la recherche courante"),
                HelpShortcut("⌘F2", "Marquer / démarquer la ligne courante"),
                HelpShortcut("F2 / ⇧F2", "Aller à la marque suivante / précédente"),
            ]),
            .heading("Un enchaînement courant"),
            .steps([
                "`⌘F` pour le motif sur lequel filtrer, par ex. `\\bERROR\\b`.",
                "`⌘M` marque chaque ligne correspondante.",
                "`Recherche ▸ Copier les lignes marquées` les tire dans un nouvel onglet — ou `Ne garder que les lignes marquées` filtre sur place.",
            ]),
            .heading("Neuf couleurs"),
            .paragraph("""
                Une ligne peut porter **plusieurs couleurs à la fois**. Utilisez des couleurs \
                différentes pour des critères différents et combinez-les : rouge pour les lignes \
                d'erreur, jaune pour les lignes d'un même numéro de commande, puis cherchez les \
                lignes qui portent les deux.
                """),
            .bullets([
                "`Inverser les marques` — les lignes marquées se démarquent et inversement.",
                "`Effacer toutes les marques` — retire chaque marque sans toucher au contenu.",
            ]),
            .seeAlso(["thao-tac-dong", "dinh-dang-log"]),
        ]
    )

    static let goToLine = HelpTopic(
        id: "di-toi-dong",
        title: "Aller à la ligne",
        summary: "Sauter à une ligne, une colonne ou une position en octets.",
        keywords: ["aller à", "numéro de ligne", "cmd+l", "position", "colonne"],
        commands: ["Đi tới dòng…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘L", "Aller à la ligne")]),
            .paragraph("""
                Le champ comprend **trois notations** et les distingue d'après ce que vous tapez — \
                il n'y a pas de sélecteur supplémentaire à cliquer.
                """),
            .table(
                headers: ["Tapez", "Va à"],
                rows: [
                    ["`120`", "le début de la ligne 120"],
                    ["`120,5` ou `120:5`", "ligne 120, colonne 5 — la colonne compte les CARACTÈRES"],
                    ["`@1024`", "la position 1024 en octets dans le fichier"],
                ]
            ),
            .note("""
                `ligne:colonne` est exactement la façon dont compilateurs et linters impriment une \
                position : une ligne copiée d'un terminal se colle telle quelle.

                Le `@` des positions en octets a une raison : `1234` est-il une ligne ou un octet ? \
                Il n'y a pas de bonne réponse, et deviner de travers envoie le curseur tout \
                ailleurs sans le moindre signal. Ce chiffre en octets est aussi celui qu'affiche la \
                barre d'état dans le segment de position (`@1024`) : ce que vous y lisez, vous \
                pouvez le taper ici.
                """),
            .bullets([
                "Une colonne **au-delà de la longueur de la ligne** s'arrête en fin de ligne ; elle ne déborde pas sur la suivante.",
                "Une position en octets **au-delà du fichier** vous mène à la fin — ce nombre vient généralement d'une exécution antérieure, et le fichier a pu rétrécir.",
                "Un texte illisible est **signalé**, et le curseur ne bouge pas ; il ne saute pas en haut du fichier.",
            ]),
            .paragraph("""
                Sur de très gros fichiers, GEditor ne lit pas tout le fichier pour y arriver — \
                l'index des lignes se construit progressivement en arrière-plan.
                """),
            .note("""
                L'outil en ligne de commande accepte aussi une position : `geditor rapport.csv:120:5` \
                ouvre le fichier avec le curseur ligne 120, colonne 5.
                """),
            .seeAlso(["dong-lenh", "thanh-trang-thai"]),
        ]
    )

    // MARK: - Fichiers et sessions

    static let files = HelpChapter(
        id: "tep",
        title: "Fichiers et sessions",
        summary: "Ouvrir, enregistrer, onglets, fenêtres, espaces de travail, et comment la session revient.",
        topics: [openAndSave, tabsAndWindows, workspace, session, savedVersions, followFile,
                 printing, nonTextFiles, pdfTools]
    )

    static let openAndSave = HelpTopic(
        id: "mo-va-luu",
        title: "Ouvrir et enregistrer",
        summary: "Ouvrir un fichier de n'importe quelle taille, et l'enregistrer avec un autre encodage ou d'autres fins de ligne.",
        keywords: ["ouvrir", "enregistrer", "dupliquer", "renommer", "déplacer"],
        commands: ["Mở…", "Mở gần đây", "Lưu", "Lưu thành…", "Tài liệu mới",
                   "Nhân bản tệp", "Đổi tên tệp…", "Chuyển tệp tới…"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘N", "Nouveau document"),
                HelpShortcut("⌘O", "Ouvrir un fichier"),
                HelpShortcut("⌘S", "Enregistrer"),
                HelpShortcut("⇧⌘S", "Enregistrer sous"),
            ]),
            .paragraph("""
                Glisser un fichier dans la fenêtre l'ouvre aussi. `Fichier ▸ Ouvrir récent` garde \
                la liste des fichiers sur lesquels vous travailliez.
                """),
            .heading("Enregistrer sous : trois choses modifiables"),
            .table(
                headers: ["Changement", "Signification"],
                rows: [
                    ["Encodage", "Écrire en UTF-8, TCVN3, VNI-Windows… — 36 encodages"],
                    ["Fins de ligne", "LF (Unix) · CRLF (Windows) · CR (Mac classique)"],
                    ["Nom et emplacement", "Comme toute boîte d'enregistrement macOS"],
                ]
            ),
            .paragraph("""
                La barre d'état montre toujours l'encodage, le style de fin de ligne et le langage \
                détecté. **Cliquer l'un d'eux le change immédiatement**, sans passer par une boîte \
                de dialogue.
                """),
            .heading("Dupliquer · renommer · déplacer"),
            .paragraph("""
                Ces trois-là agissent sur le FICHIER plutôt que sur son contenu — et l'onglet ouvert \
                suit le fichier, si bien que vous ne perdez jamais votre place.
                """),
            .table(
                headers: ["Commande", "Ce qu'elle fait"],
                rows: [
                    ["`Dupliquer le fichier`",
                     "Le copie en `nom 2.txt` à côté de l'original et **ouvre la copie** — parce qu'on duplique pour modifier la copie"],
                    ["`Renommer le fichier…`", "Renomme sur le disque ; l'onglet suit le nouveau nom"],
                    ["`Déplacer le fichier vers…`", "Déplace vers un autre dossier ; l'onglet suit"],
                ]
            ),
            .note("""
                Toutes trois **refusent si un fichier de ce nom existe déjà** à destination ; elles \
                n'écrasent jamais. Et toutes trois exigent un fichier enregistré au moins une fois — \
                un document jamais posé sur le disque n'a rien à dupliquer ni à déplacer.
                """),
            .heading("Écriture sûre"),
            .bullets([
                "L'écriture est **atomique** : une coupure de courant en plein milieu ne laisse jamais un fichier tronqué.",
                "Si un autre programme modifie le fichier pendant que vous l'avez ouvert, GEditor s'en aperçoit et demande avant d'écraser.",
                "Les fichiers sur iCloud Drive ou un volume réseau passent par le coordinateur de fichiers du système, pour que deux machines ne se marchent pas dessus.",
            ]),
            .seeAlso(["bang-ma-tieng-viet", "phien-lam-viec", "file-lon"]),
        ]
    )

    static let tabsAndWindows = HelpTopic(
        id: "tab-va-cua-so",
        title: "Onglets, fenêtres et vue partagée",
        summary: "Plusieurs onglets par fenêtre, plusieurs fenêtres, et des onglets qu'on fait glisser entre elles.",
        keywords: ["onglet", "fenêtre", "partage", "volet"],
        commands: [
            "Tab mới", "Đóng tab", "Tab kế", "Tab trước", "Mở lại tab vừa đóng",
            "Cửa sổ mới", "Tách tab ra cửa sổ mới",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘T", "Nouvel onglet"),
                HelpShortcut("⌘W", "Fermer l'onglet"),
                HelpShortcut("⇧⌘T", "Rouvrir le dernier onglet fermé"),
                HelpShortcut("⌘⇧] / ⌘⇧[", "Onglet suivant / précédent"),
                HelpShortcut("⌥⌘N", "Nouvelle fenêtre"),
                HelpShortcut("⌃⌘N", "Détacher l'onglet courant dans sa propre fenêtre"),
            ]),
            .paragraph("""
                Vous pouvez glisser un onglet dans une autre fenêtre, ou le lâcher sur le vide pour \
                créer une fenêtre. **Un onglet épinglé ne voyage pas** — épingler veut dire « garde \
                celui-ci ici ».
                """),
            .note("""
                `⇧⌘T` rouvre le dernier onglet fermé, y compris **non enregistré** : son contenu est \
                toujours là.
                """),
            .seeAlso(["chia-doi-man-hinh", "phien-lam-viec"]),
        ]
    )

    static let workspace = HelpTopic(
        id: "khong-gian-lam-viec",
        title: "Ouvrir un dossier comme espace de travail",
        summary: "Une arborescence dans la barre latérale, la recherche sur tout le projet, l'ouverture en un clic.",
        keywords: ["espace de travail", "dossier", "projet", "barre latérale"],
        commands: ["Mở thư mục làm Workspace…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘O", "Ouvrir un dossier comme espace de travail")]),
            .paragraph("""
                L'arborescence apparaît dans la barre latérale (`⌘0`). Cliquez un fichier pour \
                l'ouvrir, et `⇧⌘F` cherche dans tout le dossier.
                """),
            .note("""
                Dans la version App Store, l'accès au dossier est détenu par un **signet à portée de \
                sécurité**, si bien que le lancement suivant y accède encore sans vous redemander de \
                choisir le dossier.
                """),
            .seeAlso(["tim-trong-thu-muc", "hai-ban-phat-hanh"]),
        ]
    )

    static let session = HelpTopic(
        id: "phien-lam-viec",
        title: "La session se rétablit d'elle-même",
        summary: "Quittez et rouvrez : chaque onglet revient, y compris ceux non enregistrés.",
        keywords: ["session", "restaurer", "non enregistré", "récupérer"],
        blocks: [
            .paragraph("""
                Rien à activer. Quittez GEditor et rouvrez-le : les onglets, leur ordre, les \
                positions du curseur et du défilement reviennent tous.
                """),
            .heading("Et les onglets non enregistrés"),
            .paragraph("""
                Leur contenu est conservé dans un instantané séparé, ils reviennent donc aussi. Si \
                l'application se termine anormalement, le lancement suivant **demande** avant de \
                restaurer des brouillons orphelins — plutôt que de reconstruire en silence une pile \
                d'onglets dont vous n'avez pas souvenir.
                """),
            .warning("""
                Une session **n'est pas une sauvegarde**. Elle préserve un état de travail, pas un \
                historique. Tout ce qui compte doit encore être enregistré dans un fichier.
                """),
            .seeAlso(["ban-da-luu", "tab-va-cua-so"]),
        ]
    )

    static let savedVersions = HelpTopic(
        id: "ban-da-luu",
        title: "Versions enregistrées précédemment",
        summary: "Parcourir et restaurer d'anciennes versions d'un fichier.",
        keywords: ["versions", "historique", "restaurer", "time machine"],
        commands: ["Bản đã lưu…"],
        blocks: [
            .paragraph("""
                À chaque enregistrement, GEditor consigne la version **précédente** avant d'écraser. \
                `Macro ▸ Versions enregistrées…` en ouvre le navigateur.
                """),
            .bullets([
                "Le magasin de versions est celui du **système d'exploitation**, le mécanisme qu'utilisent les applications d'Apple.",
                "Restaurer une version ancienne est une **modification ordinaire** — `⌘Z` l'annule.",
            ]),
            .seeAlso(["phien-lam-viec"]),
        ]
    )

    static let followFile = HelpTopic(
        id: "theo-doi-tep",
        title: "Suivre un fichier encore en écriture",
        summary: "Comme `tail -f` : ce qui s'ajoute apparaît à mesure.",
        keywords: ["tail", "suivre", "journal", "temps réel"],
        commands: ["Theo dõi file (tail -f)"],
        blocks: [
            .paragraph("""
                `Fichier ▸ Suivre le fichier (tail -f)` charge ce qui apparaît à la fin du fichier \
                et défile avec.
                """),
            .warning("""
                Pendant le suivi, le document devient **en lecture seule**. Taper pendant que du \
                texte est chargé depuis le disque, c'est deux écrivains qui se disputent un \
                document, et le perdant est toujours ce que vous venez de taper.
                """),
            .note("""
                La barre d'état affiche **Suivi en cours** tout du long : quelques minutes plus \
                tard, vous savez encore pourquoi le fichier n'accepte pas la frappe. Cliquer le \
                segment **lecture seule** en donne franchement la raison.

                Le suivi appartient à **l'onglet qui l'a lancé**, pas à la fenêtre : ouvrez un autre \
                onglet et continuez à taper, les nouvelles lignes de journal continuent d'affluer \
                dans leur propre onglet sans toucher au fichier que vous modifiez.
                """),
            .seeAlso(["dinh-dang-log", "file-lon"]),
        ]
    )

    static let printing = HelpTopic(
        id: "in-an",
        title: "Impression",
        summary: "Imprimer par la boîte d'impression standard de macOS.",
        keywords: ["imprimer", "papier", "pdf"],
        commands: ["In…"],
        blocks: [
            .shortcuts([HelpShortcut("⌘P", "Imprimer")]),
            .paragraph("""
                Elle utilise la boîte d'impression du système : l'export en PDF s'y fait aussi — le \
                bouton `PDF` en bas à gauche.
                """),
        ]
    )

    static let nonTextFiles = HelpTopic(
        id: "tep-khong-phai-van-ban",
        title: "Images, PDF, fichiers Office, audio, vidéo et archives",
        summary: "Huit sortes de fichiers s'ouvrent dans GEditor sans autre application.",
        keywords: ["image", "pdf", "word", "excel", "powerpoint", "zip", "rar", "7z", "archive",
                   "audio", "vidéo"],
        blocks: [
            .table(
                headers: ["Sorte", "Ce que vous pouvez faire"],
                rows: [
                    ["Images", "Voir, zoomer, pivoter ; **les images animées se lisent** et se mettent en pause"],
                    ["Audio", "Lire, se déplacer, régler le volume"],
                    ["Vidéo", "Lire, se déplacer, plein écran, incrustation"],
                    ["PDF", "Lire, chercher, **annoter**"],
                    ["Word · Excel · PowerPoint", "Voir **et modifier** — `⌘S` réécrit directement dans le fichier"],
                    ["ZIP · TAR · GZ · XZ", "Lister les entrées et ouvrir chacune comme un onglet"],
                    ["7z · RAR et sept autres formats", "Pareil, via libarchive"],
                ]
            ),
            .paragraph("""
                Ouvrir une entrée d'archive crée un onglet avec son contenu. Les accents vietnamiens \
                survivent dans les noms comme dans les contenus.
                """),
            .note("""
                Modifiez l'un des trois formats Office, appuyez sur `⌘S`, et c'est réécrit dans le \
                fichier — LibreOffice relit le résultat. Ce chemin est testé de bout en bout, pas \
                seulement exporté vers une copie.
                """),
            .heading("L'audio et la vidéo utilisent les lecteurs de macOS"),
            .paragraph("""
                La lecture passe par les décodeurs du système : rien de plus n'est téléchargé et \
                rien de plus n'est livré. En contrepartie, quelques formats **ne se liront pas** — \
                `.mkv`, `.webm`, `.avi`, `.wmv` — car macOS n'a pas de décodeur intégré pour eux.
                """),
            .paragraph("""
                Pour un tel fichier, GEditor **dit pourquoi** au lieu d'afficher un rectangle noir, \
                et propose la vue binaire ou une autre application.
                """),
            .seeAlso(["xem-nhi-phan"]),
        ]
    )

    static let pdfTools = HelpTopic(
        id: "cong-cu-pdf",
        title: "Outils PDF",
        summary: "Lire, annoter, et toute une couche de pages : pivoter · déplacer · supprimer · extraire · fusionner.",
        keywords: ["pdf", "page", "pivoter", "supprimer une page", "extraire", "fusionner",
                   "annoter", "surligner", "signer"],
        blocks: [
            .paragraph("""
                La vue PDF a **deux barres d'outils**, qui répondent à des questions différentes. La \
                rangée du haut agit sur le **contenu** d'une page ; celle du bas sur l'**ensemble \
                des pages**.
                """),
            .heading("Rangée du haut — lire et annoter"),
            .table(
                headers: ["Bouton", "Ce qu'il fait"],
                rows: [
                    ["Surligner · Souligner", "Marquer le texte sélectionné"],
                    ["Note…", "Attacher une note à la page"],
                    ["Supprimer les annotations", "Retirer toute annotation de la page courante"],
                    ["Extraire le texte dans un onglet", "Déplacer tout le texte dans un onglet pour chercher, filtrer, lancer d'autres outils"],
                    ["Champ de recherche", "Chercher dans le PDF — **taper sans accents trouve quand même le texte accentué**"],
                ]
            ),
            .note("""
                Un PDF numérisé n'a pas de couche de texte. La commande d'extraction **le dit** au \
                lieu d'ouvrir un onglet vide et de vous laisser deviner.
                """),
            .heading("Rangée du bas — opérations sur les pages"),
            .table(
                headers: ["Bouton", "Ce qu'il fait", "Annulable"],
                rows: [
                    ["Pivoter à gauche · droite", "Tourner la page courante de 90°", "Oui"],
                    ["Page vers le haut · bas", "Échanger la page courante avec sa voisine", "Oui"],
                    ["Supprimer des pages…", "Supprimer par intervalle, ex. `2-4,7`", "Oui"],
                    ["Extraire des pages…", "Écrire un intervalle dans un **nouveau fichier**", "Ne touche pas au fichier ouvert"],
                    ["Fusionner un PDF…", "Insérer un autre PDF juste après la page courante", "Oui"],
                    ["Signer…", "Poser une image de signature sur la page courante", "Oui"],
                    ["Modifier le texte…", "Dessiner un texte de remplacement par-dessus la sélection", "Oui"],
                    ["Champ vide suivant", "Aller au champ de formulaire suivant non rempli", "—"],
                    ["Effacer les valeurs saisies", "Vider tous les champs de formulaire", "Oui"],
                    ["Annuler la modification de page", "Revenir d'une opération de page", "—"],
                    ["Enregistrer la copie modifiée…", "Écrire un nouveau fichier, puis **le rouvrir pour vérifier**", "—"],
                ]
            ),
            .heading("Formulaires remplissables"),
            .paragraph("""
                Ouvrez un PDF à champs de formulaire et la barre d'état indique **combien** il y en \
                a. Tapez directement dans les champs de la page, puis `Enregistrer la copie \
                modifiée…`.
                """),
            .bullets([
                "Les valeurs sont stockées comme **vrais champs de formulaire**, non aplatis — l'Acrobat du destinataire voit donc encore un formulaire rempli, et il peut le corriger.",
                "Les accents vietnamiens survivent à l'aller-retour écriture-réouverture. Un test le garantit précisément, avec le nom `Nguyễn Văn Anh`.",
                "`Champ vide suivant` saute au prochain vide — le chemin naturel dans un long formulaire.",
            ]),
            .heading("Signature"),
            .paragraph("""
                Préparez une image de signature (un PNG à fond transparent convient le mieux), \
                **sélectionnez l'endroit à signer** — d'ordinaire la ligne réglée ou le mot \
                « Signature » — puis appuyez sur `Signer…`. Sans sélection, la signature se pose en \
                bas à droite.
                """),
            .note("""
                La signature conserve les **proportions** de l'image : une signature écrasée ou \
                étirée a l'air fausse à l'instant.
                """),
            .heading("Modifier le texte — et trois choses à savoir d'abord"),
            .paragraph("""
                Sélectionnez le texte à changer et appuyez sur `Modifier le texte…`. GEditor \
                **couvre cette zone d'une couleur de fond prélevée juste à côté**, puis dessine le \
                nouveau texte par-dessus.
                """),
            .warning("""
                **L'ancien texte est COUVERT, pas SUPPRIMÉ.** Il est toujours dans le fichier et \
                toujours extractible avec `Extraire le texte dans un onglet` ou tout autre outil. Ce \
                **n'est pas du caviardage** — masquer ainsi un numéro d'identité le masque à l'œil \
                humain, pas à une machine.
                """),
            .bullets([
                "**Le nouveau texte reste trouvable avec `⌘F`.** Il est dessiné comme du vrai texte, pas comme une image — mesuré par un test, non supposé.",
                "**La police est une police système**, pas celle d'origine du document. Délibérément : les polices incorporées dans un PDF manquent souvent d'accents vietnamiens, et `Nguyễn` arriverait en `Nguy?n`.",
                "**Sur un fond à motifs, la retouche se voit** — la couleur de couverture est prélevée en un seul point juste à gauche de la sélection.",
            ]),
            .heading("Pourquoi dessiner par-dessus plutôt que modifier le flux de contenu"),
            .paragraph("""
                Modifier directement le flux de contenu d'un PDF, c'est affronter des polices en \
                sous-ensemble portant leur propre encodage, des phrases brisées en trois fragments \
                par le crénage, et des tables de largeurs de caractères à recalculer. Le faire \
                correctement pour **tous** les fichiers est un projet à part entière ; le faire mal \
                corrompt le document de quelqu'un.
                """),
            .paragraph("""
                En contrepartie, le reste de la page **ne change pas d'un seul octet**, et la page \
                reste une page — le texte se sélectionne, se copie et se cherche toujours. Redessiner \
                ne la transforme **pas** en image.
                """),
            .heading("Syntaxe des intervalles de pages"),
            .table(
                headers: ["Tapez", "Signification"],
                rows: [
                    ["`5`", "La page 5 seule"],
                    ["`2-4`", "Les pages 2, 3, 4"],
                    ["`-3`", "Du début à la page 3"],
                    ["`8-`", "De la page 8 à la fin"],
                    ["`1-3,5,9-`", "Plusieurs parties jointes par des virgules"],
                ]
            ),
            .paragraph("Les pages se comptent **à partir de 1**, le numéro que vous voyez à l'écran."),
            .warning("""
                Un intervalle inversé (`5-2`) et un intervalle au-delà de la fin (`1-999`) sont tous \
                deux **refusés avec une raison**, jamais corrigés en silence en quelque chose de \
                proche. Pour une commande de suppression de pages, deviner de travers signifie \
                perdre des pages, et rogner en silence transforme une faute de frappe en commande \
                valide.
                """),
            .heading("Le fichier d'origine n'est jamais écrasé"),
            .paragraph("""
                Tout ce qui précède modifie le document **en mémoire**. Un fichier n'est écrit que \
                lorsque vous appuyez sur `Enregistrer la copie modifiée…` et choisissez un \
                emplacement — et après écriture, GEditor **rouvre ce fichier même** pour confirmer \
                qu'il a encore toutes ses pages.
                """),
            .paragraph("""
                La raison : un fichier mal écrit repose sur le disque avec l'air parfaitement \
                normal, et l'utilisateur ne s'en aperçoit qu'après l'avoir envoyé.
                """),
            .note("""
                La ligne d'état de la vue affiche **· modifié, non enregistré** dès que le document \
                diffère du fichier sur disque.
                """),
            .seeAlso(["tep-khong-phai-van-ban", "xem-nhi-phan"]),
        ]
    )
}
