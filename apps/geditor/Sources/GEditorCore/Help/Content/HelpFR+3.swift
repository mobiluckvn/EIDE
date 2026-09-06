import Foundation

/// Contenu de l'aide en français — troisième partie : façons de voir, vietnamien, langages.
extension HelpFR {

    static let views = HelpChapter(
        id: "xem",
        title: "Façons de voir un document",
        summary: "Barre latérale, carte, repliement, vue partagée, retour à la ligne, invisibles, modes de coloration.",
        topics: [sidebarAndFunctions, documentMap, folding, splitView, wrapping, fontSize,
                 invisibles, colouringModes, markdownPreview, binaryView, viewCodeModes]
    )

    static let sidebarAndFunctions = HelpTopic(
        id: "sidebar-va-ham",
        title: "Barre latérale et liste des fonctions",
        summary: "L'arborescence des fichiers et la liste des fonctions du fichier ouvert, dans une même colonne.",
        keywords: ["barre latérale", "liste des fonctions", "plan", "arborescence"],
        commands: ["Ẩn/hiện sidebar (Function List)"],
        blocks: [
            .shortcuts([HelpShortcut("⌘0", "Afficher / masquer la barre latérale")]),
            .paragraph("""
                La liste des fonctions est bâtie sur l'**arbre syntaxique** du langage : elle suit \
                donc la structure réelle au lieu de la deviner d'après l'indentation. Cliquez une \
                entrée pour y sauter.
                """),
            .note("Le champ de filtre de la liste **trouve du texte accentué sans que vous tapiez les accents**."),
            .seeAlso(["ngon-ngu-dung-san", "khong-gian-lam-viec"]),
        ]
    )

    static let documentMap = HelpTopic(
        id: "ban-do-tai-lieu",
        title: "Carte du document",
        summary: "Tout le fichier dans une colonne étroite à droite — même à plusieurs centaines de Mo.",
        keywords: ["minicarte", "carte", "aperçu"],
        commands: ["Ẩn/hiện bản đồ tài liệu"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘M", "Afficher / masquer la carte du document")]),
            .paragraph("""
                La carte décrit **tout le fichier**, pas seulement ce qui est à l'écran. Glisser \
                dessus saute à la région correspondante.
                """),
            .paragraph("""
                Les occurrences de recherche et les lignes marquées apparaissent sur la carte : vous \
                voyez si elles sont dispersées ou groupées avant d'y défiler.
                """),
            .seeAlso(["danh-dau-dong", "file-lon"]),
        ]
    )

    static let folding = HelpTopic(
        id: "gap-khoi",
        title: "Repliement",
        summary: "Replier fonctions, blocs et tableaux par structure — ou replier tout le fichier à un niveau.",
        keywords: ["replier", "code folding", "réduire"],
        commands: ["Gấp / mở khối tại con nháy", "Gấp tất cả", "Bỏ gấp tất cả", "Gấp theo cấp"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘←", "Replier / déplier le bloc sous le curseur"),
                HelpShortcut("⌥⇧⌘←", "Tout replier"),
                HelpShortcut("⌥⌘→", "Tout déplier"),
                HelpShortcut("⌥⌘1 … ⌥⌘8", "Replier tout le fichier au niveau 1…8"),
            ]),
            .paragraph("""
                Pour les langages dotés d'un arbre syntaxique, le repliement suit la **structure \
                réelle**. Pour les fichiers sans grammaire, il suit l'indentation.
                """),
            .paragraph("""
                `Replier au niveau` prend tout son sens sur du JSON et du YAML profonds : replier au \
                niveau 2 met la forme de tout le fichier sur un seul écran.
                """),
            .seeAlso(["cong-cu-json", "ngon-ngu-dung-san"]),
        ]
    )

    static let splitView = HelpTopic(
        id: "chia-doi-man-hinh",
        title: "Vue partagée",
        summary: "Deux volets côte à côte, pour deux fichiers — ou deux endroits d'un même fichier.",
        keywords: ["partage", "volets", "comparer"],
        commands: [
            "Chia đôi theo chiều dọc", "Chia đôi theo chiều ngang", "Bỏ chia đôi",
            "Mở tab này ở nửa kia", "Nhảy sang nửa kia",
        ],
        blocks: [
            .shortcuts([
                HelpShortcut("⌥⌘=", "Partager verticalement"),
                HelpShortcut("⌥⌘-", "Partager horizontalement"),
                HelpShortcut("⌥⌘0", "Supprimer le partage"),
                HelpShortcut("⌥⌘]", "Ouvrir cet onglet dans l'autre volet"),
                HelpShortcut("⌥⌘[", "Sauter dans l'autre volet"),
            ]),
            .paragraph("""
                Chaque volet a sa propre barre d'onglets. Ouvrir le **même fichier** dans les deux \
                est parfaitement possible — ils défilent indépendamment, ce qui facilite la \
                comparaison du haut et du bas d'un fichier.
                """),
            .seeAlso(["tab-va-cua-so"]),
        ]
    )

    static let wrapping = HelpTopic(
        id: "ngat-dong",
        title: "Retour à la ligne automatique",
        summary: "Trois modes : désactivé, au bord de la fenêtre, ou à une colonne fixe.",
        keywords: ["retour à la ligne", "césure douce"],
        commands: ["Ngắt dòng (tắt / cửa sổ / cột)", "Ngắt dòng tại cột…"],
        blocks: [
            .table(
                headers: ["Mode", "Une longue ligne"],
                rows: [
                    ["Désactivé", "Défile horizontalement"],
                    ["À la fenêtre", "Revient à la ligne au bord de la fenêtre, en suivant sa taille"],
                    ["À une colonne", "Revient à la ligne à la colonne fixée — 80 ou 100, disons"],
                ]
            ),
            .paragraph("""
                Le retour à la ligne est une **façon de voir**, pas une modification : aucun saut de \
                ligne n'est inséré, et cela n'entre jamais dans l'historique d'annulation.
                """),
            .note("Le chemin rapide est le segment `Ngắt: …` de la barre d'état."),
        ]
    )

    static let fontSize = HelpTopic(
        id: "co-chu",
        title: "Taille du texte",
        summary: "Zoomer entre 8 et 32 pt.",
        keywords: ["zoom", "taille", "agrandir", "réduire"],
        commands: ["Phóng to chữ", "Thu nhỏ chữ", "Cỡ chữ gốc"],
        blocks: [
            .shortcuts([
                HelpShortcut("⌘=", "Agrandir"),
                HelpShortcut("⌘-", "Réduire"),
                HelpShortcut("⌃⌘0", "Revenir à la taille par défaut"),
            ]),
            .paragraph("""
                Borné entre 8 et 32 pt. C'est aussi une **façon de voir** : aucune modification, \
                rien dans l'historique d'annulation. La taille par défaut vit dans `Réglages…`.
                """),
            .note("`⌘0` n'est **pas** la taille par défaut — cette touche affiche et masque la barre latérale."),
            .seeAlso(["cai-dat"]),
        ]
    )

    static let invisibles = HelpTopic(
        id: "ky-tu-an",
        title: "Afficher les caractères invisibles",
        summary: "Un groupe à la fois, car tous ensemble c'est en général trop.",
        keywords: ["invisible", "blancs", "nbsp", "chasse nulle", "tabulation"],
        commands: [
            "Hiện tất cả ký tự ẩn", "  Khoảng trắng", "  Tab", "  Xuống dòng",
            "  NBSP · zero-width · điều khiển",
        ],
        blocks: [
            .shortcuts([HelpShortcut("⌥I", "Afficher / masquer tous les caractères invisibles")]),
            .paragraph("""
                Quatre groupes s'activent séparément, car les allumer tous d'un coup enterre le \
                contenu sous une forêt de points.
                """),
            .table(
                headers: ["Groupe", "Ce qu'il attrape"],
                rows: [
                    ["Espaces", "Espaces en fin de ligne, indentation incohérente"],
                    ["Tabulations", "Fichiers mêlant tabulations et espaces"],
                    ["Fins de ligne", "Fichiers mêlant CRLF et LF"],
                    ["NBSP · chasse nulle · contrôle", "Caractères invisibles venus de Word, du web, des tableurs"],
                ]
            ),
            .warning("""
                Le dernier groupe est celui qui sauve les gens. Une espace insécable (NBSP) collée \
                d'une page web ressemble **exactement** à une espace ordinaire, et pourtant elle \
                fait échouer chaque comparaison de chaîne et chaque filtre — impossible de la voir \
                sans activer ce groupe.
                """),
            .seeAlso(["khoang-trang-thut-le", "chuan-hoa-unicode"]),
        ]
    )

    static let colouringModes = HelpTopic(
        id: "che-do-to-mau",
        title: "Mode CSV et mode Journal",
        summary: "Deux colorations qui remplacent la coloration syntaxique, pour deux sortes de fichiers de données.",
        keywords: ["mode csv", "mode journal", "coloration", "colonnes", "niveau"],
        commands: ["Chế độ CSV (tô màu theo cột)", "Chế độ Log (tô theo mức)", "Lọc log theo mức…"],
        blocks: [
            .heading("Mode CSV"),
            .paragraph("""
                Donne à chaque colonne sa propre couleur dans la vue **texte** : vous voyez quelle \
                cellule a glissé d'une colonne sans passer à la grille.
                """),
            .heading("Mode Journal"),
            .paragraph("""
                Colore selon la **gravité** lue dans la ligne : erreurs en rouge, avertissements en \
                ambre, tandis que `debug` et `trace` sont atténués — ils forment le gros d'un \
                journal, et les mettre en valeur estompe justement ce que vous cherchez.
                """),
            .paragraph("`Filtrer le journal par niveau…` masque complètement les niveaux inutiles."),
            .note("""
                Ces deux modes colorent **à la place** de la coloration syntaxique, pas par-dessus. \
                Un journal n'a pas de syntaxe à colorer, et deux sources de couleur écrivant sur la \
                même plage d'octets ne laissent pas de vainqueur prévisible.
                """),
            .seeAlso(["dinh-dang-log", "bang-csv"]),
        ]
    )

    static let binaryView = HelpTopic(
        id: "xem-nhi-phan",
        title: "Vue binaire",
        summary: "Une table hexadécimale pour n'importe quel fichier — y compris 1 Go, ouvert presque instantanément.",
        keywords: ["hexadécimal", "binaire", "octet", "position", "dump"],
        commands: ["Xem nhị phân"],
        blocks: [
            .paragraph("""
                `Présentation ▸ Vue binaire` montre chaque octet dans une table à trois colonnes : \
                **position · hexadécimal · texte**. Cela marche pour **n'importe quel** fichier sur \
                disque, pas seulement images ou vidéos.
                """),
            .table(
                headers: ["Colonne", "Contenu"],
                rows: [
                    ["Position", "Position de l'octet, en hexadécimal"],
                    ["Hexadécimal", "16 octets par ligne, séparés après le huitième pour compter plus facilement"],
                    ["Texte", "Octets ASCII imprimables ; tout le reste devient `.`"],
                ]
            ),
            .note("""
                La colonne texte **ne décode pas l'UTF-8**. Une lettre vietnamienne prend deux ou \
                trois octets : l'afficher désalignerait la colonne texte et la colonne hexadécimale \
                — or cet alignement est toute la raison d'être de la colonne. Pour lire du texte \
                accentué, utilisez la vue normale.
                """),
            .heading("Gros fichiers"),
            .paragraph("""
                Le fichier est **projeté en mémoire** : ouvrir 1 Go en vue binaire ne coûte que ce \
                que vous regardez. Mesuré dans la suite d'autotests : **moins d'une milliseconde**.
                """),
            .paragraph("""
                La vue montre **une fenêtre de 4 Mo** à la fois, et la barre du haut indique dans \
                quelle plage vous êtes. C'est une limite du moteur de tables du système, pas de la \
                lecture : 1 Go fait 62,5 millions de lignes, et passé un certain point les lignes se \
                mettent à sauter pendant le défilement — or une table hexadécimale qui saute ne sert \
                à rien.
                """),
            .heading("Sauter à une position"),
            .table(
                headers: ["Tapez dans le champ de position", "Signification"],
                rows: [
                    ["`1F400`", "Hexadécimal — par défaut"],
                    ["`0x1F400`", "Le même, avec préfixe explicite"],
                    ["`#128000`", "Décimal, quand vous avez un nombre d'octets et non une position hexadécimale"],
                ]
            ),
            .bullets([
                "`‹` et `›` passent à la fenêtre précédente / suivante.",
                "**Copier les lignes sélectionnées** copie exactement ce que vous voyez — sans sélection, c'est toute la fenêtre.",
            ]),
            .seeAlso(["tep-khong-phai-van-ban", "file-lon"]),
        ]
    )

    static let markdownPreview = HelpTopic(
        id: "xem-truoc-markdown",
        title: "Aperçu Markdown",
        summary: "Rendre du Markdown en texte mis en forme — et dire franchement ce qu'il ne rend pas.",
        keywords: ["markdown", "aperçu", "md"],
        commands: ["Xem trước Markdown"],
        blocks: [
            .paragraph("Rendu par le support Markdown du système : gras, italique, code, liens, listes."),
            .warning("""
                **Pas de tableaux, et pas de coloration syntaxique dans les blocs de code.** La \
                fenêtre d'aperçu le dit en pied de page. Les documents de plus de **4 Mo** sont \
                refusés.
                """),
            .paragraph("""
                Besoin de tableaux et de graphiques dans un document publiable ? C'est à cela que \
                servent les rapports `.greport.md`, pas cet aperçu.
                """),
            .seeAlso(["bao-cao-greport"]),
        ]
    )

    static let viewCodeModes = HelpTopic(
        id: "che-do-view-code",
        title: "Deux modes : Vue et Code",
        summary: "Une touche bascule entre la forme rendue et la source modifiable, pour chaque type de fichier.",
        keywords: ["vue", "code", "mode", "source", "rendu", "aperçu"],
        commands: ["Đổi chế độ View / Code"],
        blocks: [
            .shortcuts([HelpShortcut("⌥⌘V", "Basculer entre Vue et Code")]),
            .paragraph("""
                La commande se trouve dans la **barre juste sous les onglets** — au même endroit \
                pour chaque type de fichier : un sélecteur `View | Code`, puis le nom du mode Vue de \
                ce fichier (« Pages du document », « Arbre clé-valeur », « Schéma »…). Un fichier \
                n'ayant qu'un seul mode grise le sélecteur, et la barre dit pourquoi. À droite \
                siègent les boutons propres à chaque type : `.xlsx` a **Grille** (modifiable, \
                réécrite directement), `.pptx` a **Plan**.
                """),
            .note("""
                **Word et PowerPoint se comportent comme un lecteur de documents.** Leur mode Vue \
                construit de vraies pages — polices, tailles et couleurs correctes, avec images, \
                tableaux, en-têtes et pieds de page numérotés. Une page est **exactement aussi large \
                que le cadre**, et se zoome. Excel est une exception délibérée : sa Vue est un \
                **tableur modifiable**, car un tableur n'a pas de format de papier avant d'être \
                imprimé.
                """),
            .note("""
                En contrepartie, les pages sont **en lecture seule** et rendent la **copie sur \
                disque** : modifiez en Code sans enregistrer et les pages montrent l'ancienne version \
                — la barre le dit, avec un bouton `Enregistrer et refaire le rendu`.
                """),
            .heading("Définitions"),
            .bullets([
                "**Code** est la **source modifiable**. Pour un fichier texte, c'est le texte lui-même. Pour un fichier binaire — PDF, image, audio, vidéo — il n'y a pas de source textuelle, donc Code, ce sont les **octets**, montrés en hexadécimal.",
                "**Vue** est ce qui est **rendu** à partir du Code. Ce peut être plus joli, plus court ou exécutable — mais c'est toujours une conséquence, jamais l'original.",
            ]),
            .paragraph("""
                Dire d'un PDF qu'*« il n'a pas de Code »* serait commode, mais faux : les octets sont \
                bel et bien sa source.
                """),
            .heading("Où l'on modifie"),
            .paragraph("""
                La modification se fait en **Code**. Il y a exactement **deux exceptions**, toutes \
                deux parce qu'y modifier en Vue est bien plus naturel : les **cellules de la grille \
                CSV** et les **champs de formulaire PDF**. Toutes deux écrivent droit dans la \
                source, si bien qu'aucune seconde copie ne vient contredire la première.
                """),
            .heading("Par type de fichier"),
            .table(
                headers: ["Type de fichier", "Vue", "Code", "Modifier dans"],
                rows: [
                    ["CSV · TSV", "Grille", "Texte brut", "**Les deux**"],
                    ["Excel `.xlsx`", "Grille de la feuille ouverte", "Cette feuille en CSV", "**Les deux**"],
                    ["PDF", "Pages rendues", "Binaire", "**Les deux** — annotations, champs, pages"],
                    ["Markdown `.md`", "Texte rendu", "Source Markdown", "Code"],
                    ["Rapport `.greport.md`", "Rapport avec requêtes exécutées et graphiques tracés", "Source", "Code"],
                    ["JSON", "Arbre clé-valeur, repliable", "Source JSON", "Code"],
                    ["XML · HTML", "Arbre de balises, repliable", "Source XML", "Code"],
                    ["YAML", "Arbre clé-valeur par indentation", "Source YAML", "Code"],
                    ["Schémas `.mmd` · `.dot`", "Le schéma dessiné, occupant l'onglet", "Source mermaid ou DOT", "Code"],
                    ["Word `.docx`", "Pages de document rendues", "Markdown extrait", "Code"],
                    ["PowerPoint `.pptx`", "Pages de diapositives rendues", "Plan Markdown", "Code"],
                    ["Journaux", "Colorés par niveau, filtrables", "Texte brut", "Code"],
                    ["Images", "L'image (les animées se lisent)", "Binaire", "Lecture seule"],
                    ["Audio · vidéo", "Un lecteur", "Binaire", "Lecture seule"],
                    ["Archives", "Liste des entrées", "Binaire", "Lecture seule"],
                    ["Code source, texte brut", "— aucune", "Le texte lui-même", "Code"],
                ]
            ),
            .note("""
                Le code source **n'a pas de Vue**, et c'est normal plutôt qu'une lacune : un fichier \
                Swift n'a pas de forme rendue qui vaille d'être regardée.
                """),
            .heading("Le lecteur de pages pour Word et PowerPoint"),
            .paragraph("""
                Les pages s'empilent verticalement et défilent en continu, chacune une feuille \
                blanche sur fond gris — comme tout lecteur de documents. Ses commandes siègent à \
                droite de la barre.
                """),
            .table(
                headers: ["Bouton / touche", "Ce qu'il fait"],
                rows: [
                    ["`Ajuster la largeur`", "La feuille est exactement aussi large que le cadre — par défaut"],
                    ["`Ajuster la page`", "La feuille entière tient dans le cadre"],
                    ["`−` `+`", "Zoom par paliers ; ou pincement, ou ⌘ + molette"],
                    ["Le champ `Rechercher`, ou ⌘F", "Chercher dans les pages, y sauter et surligner"],
                    ["Entrée dans le champ de recherche", "Occurrence suivante"],
                    ["Glisser", "Sélectionner du texte ; double-clic pour un mot, triple-clic pour un paragraphe"],
                    ["⌘A · ⌘C", "Tout sélectionner · copier la sélection"],
                    ["Page préc. · Page suiv. · Début · Fin", "Se déplacer dans le document"],
                ]
            ),
            .paragraph("""
                Le champ de recherche **ignore accents et casse** : taper `vuong quoc` trouve `Vương \
                quốc`. L'étiquette « Page 12/363 » dans la barre vous dit où vous en êtes.
                """),
            .note("""
                **Ce qui n'est pas rendu, dit franchement :** les images ancrées flottantes (texte \
                habillant une image) apparaissent en ligne ; notes de bas de page, graphiques et \
                SmartArt de PowerPoint ne sont pas dessinés. Quand il vous faut une correspondance \
                exacte avec l'imprimé, ouvrez-le dans Word.
                """),
            .heading("Cliquer un nœud ramène à la source"),
            .paragraph("""
                Un arbre JSON n'est pas une jolie impression : cliquer un nœud déplace le curseur \
                **sur la VALEUR de ce nœud** dans le texte et ramène l'onglet en Code — car ce que \
                vous voulez ensuite, c'est presque toujours modifier ce que vous venez de cliquer.
                """),
            .bullets([
                "Les nœuds conteneurs montrent leur **nombre d'éléments** (`{12}`, `[340]`) plutôt que leur contenu — c'est cela qui répond à « vaut-il la peine d'ouvrir ».",
                "Les **deux premiers niveaux** sont dépliés : tout déplier sur un fichier de dix mille nœuds produit une liste plus longue que la source, tout replier oblige à cliquer pour découvrir quoi que ce soit.",
                "Un fichier à la **syntaxe invalide** n'obtient pas un demi-arbre — un arbre tronqué ressemble à un document qui ne contiendrait que cela.",
                "Dans un arbre XML, les attributs portent un préfixe `@` en notation XPath, et **les blancs entre balises ne deviennent pas des nœuds** — c'est de la mise en forme, pas du contenu.",
                "Un arbre YAML lit les **fichiers multi-documents** (`---`) : chaque document a sa racine. Les collections écrites en ligne (`ports: [80, 443]`) restent une feuille — vous voyez déjà tout, et déplier coûterait un clic. L'**indentation par tabulations** est signalée avec la ligne exacte : c'est une erreur YAML que l'œil ne voit pas.",
                "Le plan PowerPoint est bâti sur le **texte ouvert**, pas sur le fichier du disque : si vous venez de modifier le plan en Code, l'arbre doit décrire la nouvelle version et ses nœuds doivent sauter dans cette nouvelle version. Les notes du présentateur se replient en un nœud, pour qu'une diapositive bavarde n'ait pas l'air d'une diapositive chargée.",
                "**Un schéma plein onglet suit la même règle** : cliquez un nœud et vous voilà en Code, curseur sur sa déclaration. Dans le panneau `Mermaid Studio` côte à côte, l'onglet ne se ferme pas — l'éditeur est juste là, et déplacer le curseur suffit à le voir.",
                "Les schémas **s'ouvrent aussi là où vous êtes** : l'élément correspondant à la ligne du curseur est surligné dès l'apparition de l'onglet, pour ne pas avoir à le chercher.",
            ]),
            .heading("Le champ de filtre : dans un arbre de dix mille nœuds, chercher est le travail"),
            .paragraph("""
                Juste sous le compte de nœuds se trouve un champ de filtre. Tapez-y et l'arbre ne \
                garde que les nœuds correspondants — **avec le chemin depuis la racine jusqu'à \
                eux**, car quand une clé `name` apparaît à dix endroits, la vraie question est \
                « lequel », et seule la branche qui la contient y répond. Le reste est déplié pour \
                vous : vous faire cliquer chaque niveau, c'est vous faire filtrer une seconde fois à \
                la main.
                """),
            .bullets([
                "Il filtre sur **les étiquettes et les valeurs** : chercher `Huế` est aussi courant que chercher la clé `province`.",
                "**Taper sans accents trouve quand même le texte accentué** — `da nang` trouve `Đà Nẵng`. La même comparaison que le filtre de la grille CSV et que la liste des fonctions, pour ne pas avoir à retenir trois règles de recherche dans une seule application.",
                "Sans correspondance, l'en-tête affiche **« Aucun résultat »** au lieu de vous laisser devant un arbre vide en vous demandant si le fichier est cassé.",
                "Changer de fichier ou revenir en Vue **efface le filtre** : un arbre qui s'ouvre déjà tronqué, sans rien pour l'expliquer, est l'état le plus déroutant qui soit.",
            ]),
            .heading("Tout l'arbre se pilote au clavier"),
            .paragraph("""
                Entrer en Vue place le focus sur l'arbre ; nul besoin de cliquer d'abord. Haut et bas \
                se déplacent entre nœuds, gauche et droite replient et déplient, et deux touches \
                terminent la consultation — en faisant des choses **différentes** :
                """),
            .bullets([
                "**Entrée** — aller au nœud sélectionné : retour en Code avec le curseur dans la plage d'octets de ce nœud. Exactement comme un clic.",
                "**Tab** — passer entre l'arbre et le champ de filtre.",
                "**⌘C** — copie le **chemin** du nœud sélectionné, pas le texte derrière l'arbre. JSON et YAML produisent du JSONPath (`$.customer['name']`) qui se colle tel quel dans la boîte de requête JSONPath de ce produit, ou dans `yq` ; XML produit du XPath (`/order/item[2]/@code`) avec index quand deux balises partagent un nom ; un plan PowerPoint copie le texte de la ligne, car un plan n'a pas de langage de chemin à inventer.",
                "**Échap** — le chemin du retour : revenir en Code avec le curseur **exactement où il était**. Vous regardiez un arbre, vous ne voyagiez pas.",
            ]),
            .heading("Et dans l'autre sens : l'arbre s'ouvre là où est le curseur"),
            .paragraph("""
                Entrer en Vue depuis le milieu d'un fichier de dix mille lignes n'ouvre **pas** \
                l'arbre en haut : il déplie le chemin jusqu'au nœud correspondant à l'endroit du \
                curseur, et le sélectionne. C'est l'autre moitié du saut-vers-la-source — sans elle, \
                Vue et Code ne seraient deux regards sur un document que dans **un seul** sens.
                """),
            .bullets([
                "Il déplie **plus loin que deux niveaux** au besoin : la règle des deux niveaux répond à « à quoi ressemble ce fichier », alors qu'ici la question est autre — « où suis-je dans cet arbre ».",
                "Un curseur sur une **clé** (`\"address\":`) sélectionne cette entrée, même si la plage d'octets du nœud ne couvre que la valeur. Le texte immédiatement avant un nœud appartient à ce nœud.",
                "Un curseur au **début d'un bloc** — clé d'un bloc YAML, titre de diapositive, nom de balise XML — sélectionne ce bloc au lieu de plonger vers son premier enfant.",
                "Entrer en Vue **ne déplace pas le curseur**. Quittez la Vue et vous êtes exactement où vous étiez ; la Vue est une façon de voir, pas une commande qui change de place.",
            ]),
            .heading("Plus aucun type ne manque de Vue"),
            .paragraph("""
                **Chaque type de fichier ayant matière à un mode Vue en rend un désormais.** La liste \
                des types manquants s'est vidée et a été supprimée.

                Le code source et le texte brut n'ont toujours pas de Vue — c'est normal, pas une \
                lacune : ils n'ont jamais figuré sur cette liste.

                Si un nouveau type arrive dont la Vue n'est pas encore construite, la commande de \
                bascule le dira et nommera ce qui manque, au lieu d'ouvrir un cadre vide — un cadre \
                vide est une promesse vide, un refus nommé est une information.
                """),
            .heading("Les six commandes anciennes sont toujours là"),
            .paragraph("""
                `Vue grille / texte`, `Aperçu Markdown`, `Vue binaire`, `Aperçu du rapport`, \
                `Aperçu du schéma Mermaid`, `Mode journal` — toutes restent exactement où elles \
                étaient. `⌥⌘V` est une **entrée commune**, pas un remplacement.
                """),
            .seeAlso(["bang-csv", "sheet-excel", "xem-nhi-phan", "cong-cu-pdf",
                      "xem-truoc-markdown"]),
        ]
    )

    // MARK: - Vietnamien

    static let vietnamese = HelpChapter(
        id: "tieng-viet",
        title: "Vietnamien",
        summary: "Encodages anciens, normalisation Unicode, recherche sans accents et méthodes de saisie.",
        topics: [vietnameseEncodings, lineEndings, unicodeNormalisation, accentInsensitive, inputMethods]
    )

    static let vietnameseEncodings = HelpTopic(
        id: "bang-ma-tieng-viet",
        title: "Encodages vietnamiens",
        summary: "Lire et écrire TCVN3, VISCII, VNI-Windows et 33 autres, détectés automatiquement.",
        keywords: ["encodage", "tcvn3", "abc", "viscii", "vni", "mojibake"],
        commands: ["Bảng mã…"],
        blocks: [
            .paragraph("""
                Vous avez ouvert un vieux fichier vietnamien et obtenu `Tr¦êng §¹i häc` au lieu de \
                `Trường Đại học` ? Le fichier n'est pas corrompu — il a été enregistré dans un \
                encodage antérieur à Unicode.
                """),
            .steps([
                "Cliquez l'encodage dans la **barre d'état** (ou `Format ▸ Encodage…`).",
                "Choisissez le bon — pour les vieux fichiers vietnamiens c'est en général `TCVN3 (ABC)`, `VNI-Windows` ou `VISCII`.",
                "Le texte se corrige aussitôt ; inutile de rouvrir le fichier.",
                "Pour que cela reste ainsi, `Enregistrer sous…` avec l'encodage `UTF-8`.",
            ]),
            .heading("Les trois encodages vietnamiens anciens"),
            .table(
                headers: ["Encodage", "Se trouve d'ordinaire dans"],
                rows: [
                    ["TCVN3 (ABC)", "L'administration et les vieux documents Word du Nord"],
                    ["VNI-Windows", "L'édition, la presse et l'imprimerie — courant au Sud"],
                    ["VISCII", "Les premiers courriels et Usenet"],
                ]
            ),
            .paragraph("""
                GEditor **détecte l'encodage** à l'ouverture. Quand il se trompe, un clic corrige, et \
                le contenu est redécodé plutôt que rapiécé lettre à lettre.
                """),
            .warning("""
                Écrire vers un encodage ancien perd les caractères qu'il ne possède pas. GEditor \
                **les compte et vous prévient d'abord** — par exemple *« 12 caractères ne sont pas \
                dans TCVN3 »* — au lieu de les changer silencieusement en points d'interrogation.
                """),
            .seeAlso(["chuan-hoa-unicode", "mo-va-luu"]),
        ]
    )

    static let lineEndings = HelpTopic(
        id: "xuong-dong",
        title: "Fins de ligne",
        summary: "LF, CRLF, CR — converties pour tout le fichier en un clic.",
        keywords: ["eol", "crlf", "lf", "fin de ligne", "windows", "unix"],
        commands: ["Xuống dòng…"],
        blocks: [
            .table(
                headers: ["Style", "Utilisé par", "Octets"],
                rows: [
                    ["LF", "macOS, Linux", "`\\n`"],
                    ["CRLF", "Windows", "`\\r\\n`"],
                    ["CR", "Mac avant 2001", "`\\r`"],
                ]
            ),
            .paragraph("""
                Le style courant s'affiche dans la barre d'état ; cliquez-le pour le changer. Un \
                fichier qui **mêle** deux styles y est signalé aussi — activez `Afficher les \
                invisibles ▸ Fins de ligne` pour voir exactement où.
                """),
            .note("Le style de fin de ligne des **nouveaux** fichiers se règle dans `Réglages…`."),
            .seeAlso(["ky-tu-an", "cai-dat"]),
        ]
    )

    static let unicodeNormalisation = HelpTopic(
        id: "chuan-hoa-unicode",
        title: "Normalisation Unicode",
        summary: "Pourquoi chercher « ế » ne trouve parfois rien, et comment réparer tout un fichier.",
        keywords: ["unicode", "nfc", "nfd", "composé", "décomposé", "normaliser"],
        commands: ["Chuẩn hóa Unicode…"],
        blocks: [
            .paragraph("""
                En Unicode, `ế` peut s'écrire de **deux façons** : un seul point de code précomposé \
                (NFC), ou `e` plus deux signes séparés (NFD). À l'écran, ils sont identiques ; pour \
                une machine, ce sont deux chaînes différentes.
                """),
            .paragraph("""
                Conséquence : chercher `ế` dans un fichier NFD ne trouve **rien**, et l'utilisateur \
                en conclut que la donnée n'y est pas.
                """),
            .steps([
                "`Format ▸ Normaliser l'Unicode…`",
                "Choisissez **NFC** (précomposé) — la forme qu'utilise presque tout le reste.",
                "Appliquez. C'est une seule étape d'annulation.",
            ]),
            .note("""
                Les fichiers venus de macOS sont souvent en NFD, car le système de fichiers d'Apple \
                stocke les noms ainsi. C'est la raison la plus fréquente pour laquelle des données \
                copiées depuis le Finder deviennent introuvables.
                """),
            .paragraph("""
                Il existe un interrupteur **normaliser en NFC à l'enregistrement** dans `Réglages…`. \
                Désactivé par défaut, car il change les octets du fichier.
                """),
            .seeAlso(["bang-ma-tieng-viet", "cai-dat"]),
        ]
    )

    static let accentInsensitive = HelpTopic(
        id: "go-khong-dau",
        title: "Taper sans accents trouve quand même le texte accentué",
        summary: "Chaque champ de recherche et de filtre compare accents retirés.",
        keywords: ["accents", "diacritiques", "recherche", "filtre"],
        blocks: [
            .paragraph("""
                Tapez `hue` pour trouver `Huế`. Tapez `da nang` pour trouver `Đà Nẵng`. La règle \
                vaut pour le filtre de la grille CSV, la recherche de fonctions, la recherche dans \
                l'aide et les autres champs de filtre.
                """),
            .note("""
                `Đ` est traité à part, car en Unicode c'est **une lettre à part entière** et non un \
                `D` portant un signe — un retrait d'accents ordinaire n'y touche pas.
                """),
            .paragraph("""
                Le filtre CSV accepte aussi un préfixe `=` pour une comparaison exacte. La forme `=` \
                est **également insensible aux accents**, car un filtre qui distingue les \
                diacritiques laisse croire à l'utilisateur que la donnée manque.
                """),
            .seeAlso(["loc-va-sap-bang", "tim-va-thay"]),
        ]
    )

    static let inputMethods = HelpTopic(
        id: "bo-go",
        title: "Méthodes de saisie vietnamiennes",
        summary: "EVKey, OpenKey, Unikey et la source de saisie de macOS écrivent directement dans le document.",
        keywords: ["saisie", "evkey", "unikey", "openkey", "telex", "vni"],
        blocks: [
            .paragraph("""
                Rien à configurer. Telex et VNI fonctionnent tous deux, y compris sur **plusieurs \
                curseurs** — tapez une fois et chaque curseur reçoit la lettre correctement \
                accentuée.
                """),
            .paragraph("""
                Champs de recherche, champs de filtre et toutes les boîtes de dialogue acceptent la \
                méthode de saisie comme l'éditeur.
                """),
            .seeAlso(["nhieu-con-nhay", "go-khong-dau"]),
        ]
    )

    // MARK: - Langages et formats

    static let languages = HelpChapter(
        id: "ngon-ngu",
        title: "Langages et formats",
        summary: "Vingt langages intégrés, des langages définis par l'utilisateur, et des outils pour JSON · XML · YAML · journaux.",
        topics: [builtInLanguages, userDefinedLanguages, jsonTools, jsonPath, xmlTools, yamlTools,
                 logFiles]
    )

    static let builtInLanguages = HelpTopic(
        id: "ngon-ngu-dung-san",
        title: "Vingt langages intégrés",
        summary: "Coloration issue d'un vrai arbre syntaxique, avec les marqueurs de commentaire de chaque langage.",
        keywords: ["syntaxe", "coloration", "langage", "tree-sitter", "grammaire"],
        blocks: [
            .paragraph("""
                Le langage est détecté d'après l'**extension du fichier** (plus quelques noms \
                spéciaux comme `Makefile`, `Dockerfile`, `Gemfile`). Vous pouvez le changer à la \
                main dans la barre d'état.
                """),
            .table(
                headers: ["Langage", "Extensions", "Commentaire ligne · bloc"],
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
                La dernière colonne est ce qu'utilise `⌘/`. Les langages sans commentaire de ligne \
                (JSON, CSS, XML) reçoivent la forme bloc à la place.
                """),
            .heading("Ce que l'arbre syntaxique apporte"),
            .bullets([
                "La **liste des fonctions** dans la barre latérale suit la structure réelle, pas des devinettes d'indentation.",
                "Le **repliement** par structure.",
                "Une **correspondance des parenthèses** qui saute celles dans les chaînes et les commentaires.",
                "L'**indentation automatique** ajoutant un niveau après `{`, et après `:` en Python et YAML.",
            ]),
            .note("""
                Trois grammaires lourdes (C++, C#, Ruby) vivent dans une bibliothèque **chargée à la \
                demande** — elles ne sont chargées qu'à l'ouverture d'un fichier de ces langages. \
                C'est ainsi que le temps de lancement reste sous la demi-seconde.
                """),
            .seeAlso(["ngon-ngu-tu-dinh-nghia", "comment-va-ngoac", "gap-khoi"]),
        ]
    )

    static let userDefinedLanguages = HelpTopic(
        id: "ngon-ngu-tu-dinh-nghia",
        title: "Langages définis par l'utilisateur",
        summary: "Colorer votre propre format avec un seul fichier JSON — sans grammaire à écrire.",
        keywords: ["udl", "langage personnalisé", "journal maison"],
        blocks: [
            .paragraph("""
                Le format de journal interne d'une entreprise, un langage de configuration maison, un \
                petit DSL — aucun n'a de grammaire tree-sitter, et en écrire une demande un \
                compilateur et un peu de théorie de l'analyse syntaxique.
                """),
            .paragraph("""
                À la place, GEditor accepte un **analyseur lexical piloté par tables** déclaré en \
                JSON. Placez le fichier dans le dossier `grammars/` du répertoire de configuration \
                de GEditor, puis relancez.
                """),
            .code(
                language: "json", caption: "grammars/internal-log.json — un langage complet",
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
                    """
            ),
            .heading("Chaque clé"),
            .table(
                headers: ["Clé", "Type", "Signification"],
                rows: [
                    ["`name`", "chaîne", "Le nom affiché dans la barre d'état"],
                    ["`extensions`", "tableau de chaînes", "Extensions de fichier, **sans le point**"],
                    ["`caseSensitive`", "booléen", "Si les mots-clés distinguent la casse"],
                    ["`lineComment`", "chaîne", "Marqueur de commentaire jusqu'en fin de ligne ; omettre s'il n'y en a pas"],
                    ["`blockComment`", "tableau de 2 chaînes", "`[ouvrant, fermant]`"],
                    ["`stringDelimiters`", "tableau de chaînes", "Chaque entrée est **un** caractère qui ouvre/ferme une chaîne"],
                    ["`escapeCharacter`", "chaîne", "Caractère d'échappement dans les chaînes ; vide si le langage n'en a pas"],
                    ["`keywordGroups`", "objet", "Nom de groupe → liste de mots-clés ; trois groupes, trois couleurs"],
                ]
            ),
            .paragraph("Les trois noms de groupe qui reçoivent leur couleur sont `keyword`, `type` et `constant`."),
            .warning("""
                Cet analyseur **ne comprend pas l'imbrication**. Le repliement structurel, la liste \
                des fonctions et la correspondance intelligente des parenthèses restent réservés aux \
                vingt langages intégrés. C'est un compromis délibéré : en échange, vous déclarez un \
                langage en dix minutes au lieu d'une journée.
                """),
            .seeAlso(["ngon-ngu-dung-san", "cai-dat"]),
        ]
    )

    static let jsonTools = HelpTopic(
        id: "cong-cu-json",
        title: "Outils JSON",
        summary: "Reformater, minifier, trier les clés et valider contre un JSON Schema.",
        keywords: ["json", "formater", "minifier", "schema"],
        commands: [
            "JSON: định dạng lại", "JSON: thu gọn một dòng", "JSON: sắp xếp khóa",
            "Kiểm theo JSON Schema…",
        ],
        blocks: [
            .table(
                headers: ["Commande", "Ce qu'elle fait"],
                rows: [
                    ["Reformater", "Retourne à la ligne et indente pour la lecture"],
                    ["Minifier", "Retire tout blanc superflu"],
                    ["Trier les clés", "Classe alphabétiquement les clés de chaque objet — pour que deux fichiers JSON soient **comparables**"],
                    ["Valider contre un JSON Schema…", "Vérifie le document contre un schéma, listant chaque problème avec sa ligne"],
                ]
            ),
            .paragraph("""
                Les règles appliquées sont **RFC 8259 stricte** : pas de virgule finale, pas de \
                commentaires, pas de `NaN`. Une erreur de syntaxe pointe la ligne et la colonne \
                exactes.
                """),
            .note("""
                Les fichiers **JSONL** (un objet par ligne) sont reconnus aussi, et disposent de \
                leurs propres outils au chapitre du pack de connaissances.
                """),
            .seeAlso(["json-path", "gap-khoi", "chunk-va-jsonl"]),
        ]
    )

    static let jsonPath = HelpTopic(
        id: "json-path",
        title: "Requêtes JSONPath",
        summary: "Extraire exactement la partie voulue d'un gros fichier JSON.",
        keywords: ["jsonpath", "requête json", "$.."],
        commands: ["JSON: truy vấn JSONPath…"],
        blocks: [
            .paragraph("Tapez une expression ; les résultats apparaissent en liste où l'on peut sauter."),
            .table(
                headers: ["Écrire", "Signification"],
                rows: [
                    ["`$`", "La racine du document"],
                    ["`$.name`", "La clé `name` à la racine"],
                    ["`$.orders[0]`", "Le premier élément d'un tableau"],
                    ["`$.orders[*].total`", "La clé `total` de **chaque** élément"],
                    ["`$..province`", "La clé `province` à **n'importe quelle profondeur**"],
                    ["`$.orders[1:3]`", "Une tranche : éléments 1 et 2"],
                ]
            ),
            .code(language: "text", caption: "Le code de province de chaque commande, si profondément imbriqué soit-il",
                  source: "$..orders[*].address.province"),
            .seeAlso(["cong-cu-json"]),
        ]
    )

    static let xmlTools = HelpTopic(
        id: "cong-cu-xml",
        title: "Outils XML",
        summary: "Reformater, minifier, vérifier la syntaxe et valider contre une DTD ou un XSD.",
        keywords: ["xml", "xsd", "dtd", "schema", "valider", "xpath"],
        commands: [
            "XML: định dạng lại", "XML: thu gọn một dòng", "XML: kiểm cú pháp",
            "XML: kiểm theo DTD/XSD…", "XML: đánh giá XPath…",
        ],
        blocks: [
            .table(
                headers: ["Commande", "Ce qu'elle fait"],
                rows: [
                    ["Reformater", "Indente selon la profondeur des balises"],
                    ["Minifier", "Retire les blancs entre balises"],
                    ["Vérifier la syntaxe", "Balises fermantes manquantes, imbrication fautive, caractères invalides"],
                    ["Valider contre DTD/XSD…", "Vérifie contre un schéma, signalant chaque problème avec sa ligne"],
                    ["Évaluer un XPath…", "Exécute une expression XPath ; les résultats s'ouvrent dans un nouvel onglet"],
                ]
            ),
            .heading("XPath"),
            .paragraph("""
                Tapez une expression et les résultats s'ouvrent comme **un onglet texte**, un nœud \
                par ligne. Par exemple : `//order/item[2]/@code` · `//*[@kind='A']` · `count(//item)`.
                """),
            .note("""
                **Les résultats ne sautent PAS à une position dans le fichier source.** L'évaluateur \
                XPath du système construit son propre arbre et ne conserve pas la position en octets \
                de chaque nœud : ce qui revient est du CONTENU, non des coordonnées. Pour atteindre \
                l'endroit exact, faites `⌘F` sur la chaîne que vous venez de trouver.
                """),
            .paragraph("""
                Dans les fichiers `.xml` et `.html`, taper `>` pour achever une balise ouvrante fait \
                **apparaître la balise fermante**, curseur entre les deux. Les balises auto-fermantes \
                (`<br/>`), les déclarations (`<?xml …?>`) et les commentaires, non — ils n'ont rien à \
                fermer.
                """),
            .warning("""
                Reformater du XML **change les blancs entre balises**. Dans les documents où ces \
                blancs comptent — du XHTML avec du texte dans les balises, par exemple — cela change \
                ce qui est affiché. C'est une seule étape d'annulation, `⌘Z` la défait.
                """),
        ]
    )

    static let yamlTools = HelpTopic(
        id: "cong-cu-yaml",
        title: "Vérification YAML",
        summary: "Attraper les deux erreurs YAML les plus courantes : clés dupliquées et indentation par tabulations.",
        keywords: ["yaml", "yml", "lint", "clé dupliquée", "indentation"],
        commands: ["YAML: kiểm khóa trùng và thụt lề"],
        blocks: [
            .bullets([
                "**Clés dupliquées** dans un même mappage — la plupart des lecteurs YAML prennent la **dernière** et écartent silencieusement les précédentes : un fichier de configuration peut se comporter tout autrement que vous ne l'imaginez.",
                "**Indentation par tabulations** — YAML interdit les tabulations dans l'indentation, et les messages d'erreur des bibliothèques à ce sujet sont d'ordinaire incompréhensibles.",
            ]),
            .note("Activez `Afficher les invisibles ▸ Tabulations` pour voir aussitôt quel blanc est une tabulation."),
            .seeAlso(["ky-tu-an"]),
        ]
    )

    static let logFiles = HelpTopic(
        id: "dinh-dang-log",
        title: "Fichiers journaux",
        summary: "Sept niveaux de gravité, filtrage par niveau, et comment lire un très gros journal.",
        keywords: ["journal", "log", "erreur", "avertissement", "filtre", "niveau"],
        blocks: [
            .paragraph("""
                Activez `Présentation ▸ Mode journal (couleur par niveau)`. GEditor lit la gravité au \
                **début de chaque ligne** — après l'horodatage et le nom du processus.
                """),
            .table(
                headers: ["Niveau", "Couleur"],
                rows: [
                    ["CRITICAL · ERROR", "Rouge"],
                    ["WARNING", "Ambre"],
                    ["NOTICE", "Couleur d'accentuation"],
                    ["INFO", "Texte ordinaire"],
                    ["DEBUG · TRACE", "Atténué"],
                ]
            ),
            .paragraph("""
                `Filtrer le journal par niveau…` masque entièrement les niveaux inférieurs. Les \
                lignes dont le niveau n'est **pas reconnu** — la suite d'une trace de pile, par \
                exemple — sont laissées telles quelles plutôt que de recevoir le niveau de la ligne \
                précédente.
                """),
            .heading("Lire un gros journal, pas à pas"),
            .steps([
                "Ouvrez le fichier — même à l'échelle du gigaoctet, il s'ouvre presque instantanément.",
                "`Présentation ▸ Mode journal` pour voir où est le rouge.",
                "`⌥⌘M` pour la carte du document : le rouge est-il groupé sur une plage ou dispersé dans tout le fichier ?",
                "`⌘F` pour le code d'erreur, `⌘M` pour marquer chaque ligne correspondante.",
                "`Recherche ▸ Copier les lignes marquées` pour les tirer dans un nouvel onglet.",
                "Toujours en cours ? `Fichier ▸ Suivre le fichier (tail -f)`.",
            ]),
            .seeAlso(["che-do-to-mau", "danh-dau-dong", "theo-doi-tep", "ban-do-tai-lieu"]),
        ]
    )
}
