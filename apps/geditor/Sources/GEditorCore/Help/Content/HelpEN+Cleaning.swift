import Foundation

extension HelpEN {

    static let cleaning = HelpChapter(
        id: "lam-sach",
        title: "Data cleaning — the whole workflow",
        summary: "From a raw file someone sent you to a usable table, and a standard you can rerun monthly.",
        topics: [cleaningWorkflow, dataProfile, cleaningBench, fuzzyDuplicates, cleaningRecipe,
                 qualityScoring, gqualitySyntax, qualityGate]
    )

    // MARK: - Workflow

    static let cleaningWorkflow = HelpTopic(
        id: "quy-trinh-lam-sach",
        title: "The cleaning workflow, end to end",
        summary: "Six steps from an unknown file to a trustworthy table, and a standard for next month.",
        keywords: ["cleaning", "clean", "workflow", "normalise", "tidy data"],
        blocks: [
            .paragraph("""
                Cleaning data is **rarely a one-off**. People receive the same report template every \
                month, and every month the same columns need normalising the same way. This \
                workflow is designed for that: you do it by hand once, then rerun it with a single \
                command.
                """),
            .heading("Six steps"),
            .steps([
                "**Look at the structure first.** `CSV ▸ Check data` — which rows have the wrong column count, which cells the wrong type. This comes first because one misaligned row makes every later statistic meaningless.",
                "**Read the data profile.** Per column: how many empty cells, how many distinct values, what type, where the outliers are. This is where you understand the file, before changing anything.",
                "**Open the cleaning bench** (`⇧⌘L`). It detects mixed date formats, Vietnamese numbers mixed with European ones, stray whitespace, missing values. **Preview before→after**, then apply.",
                "**Handle fuzzy duplicates** if a name or address column has hand-typed variants. Here you decide; the machine only proposes.",
                "**Save it as a recipe.** The sequence you just performed is written to a named JSON file — that file is your knowledge about this data.",
                "**Write a quality rule set** `.gquality.yaml` and score it. From now on next month's file runs through the recipe and gets scored, and the **CLI gate** returns a non-zero exit code when it fails.",
            ]),
            .heading("Why this order"),
            .bullets([
                "Structure **before** profile: statistics on a misaligned table are statistics about a different column.",
                "Profile **before** cleaning: you need to know `2% empty` before deciding to fill or drop.",
                "Fuzzy duplicates **after** normalisation: `CÔNG TY  A` and `Công ty A` only reveal themselves as one after whitespace and case have been settled.",
                "Recipe **before** rule set: the recipe fixes, the rules judge — scoring an unfixed table just produces a low number you already expected.",
            ]),
            .heading("After the first time, each month is one command"),
            .code(
                language: "bash",
                caption: "Clean then score, returning an exit code for CI",
                source: """
                    geditor --recipe sales-standard.json \\
                            --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --record-history \\
                            sales-2026-09.csv
                    """
            ),
            .paragraph("""
                Exit code **0** means pass, **1** means fail, **2** means a run-time error. \
                `--record-history` appends a line to the history file so the next run can compare \
                drift.
                """),
            .seeAlso([
                "kiem-tra-du-lieu", "ho-so-du-lieu", "ban-lam-sach", "trung-lap-mo",
                "cong-thuc-lam-sach", "cham-chat-luong", "cong-chat-luong",
            ]),
        ]
    )

    // MARK: - Data profile

    static let dataProfile = HelpTopic(
        id: "ho-so-du-lieu",
        title: "Data profile",
        summary: "One description per column: type, empties, distinct values, distribution.",
        keywords: ["profile", "column statistics", "null", "distinct"],
        blocks: [
            .paragraph("""
                A profile **describes**; it does not judge. It says *"this column is 2% empty"*; \
                whether 2% is acceptable belongs to the quality rule set.
                """),
            .table(
                headers: ["Measure", "How to read it"],
                rows: [
                    ["Type", "Inferred from the data itself, not from the column name"],
                    ["Empty cells", "Count and proportion of missing values"],
                    ["Distinct values", "1 means a constant column; equal to the row count means a key column"],
                    ["Min · max · mean", "Numeric columns only"],
                    ["Most frequent values", "Spot an error code or an over-used default straight away"],
                ]
            ),
            .warning("""
                Distinct counting has a threshold. Past it, the number shown is a **lower bound**, \
                and the profile **says it is an estimate** rather than mixing it in with exact \
                counts.
                """),
            .seeAlso(["quy-trinh-lam-sach", "cham-chat-luong"]),
        ]
    )

    // MARK: - Cleaning bench

    static let cleaningBench = HelpTopic(
        id: "ban-lam-sach",
        title: "The data cleaning bench",
        summary: "Seven normalisations, always previewed, always one undo step, never guessing.",
        keywords: ["clean", "normalise", "dates", "numbers", "trim", "fill missing"],
        commands: ["Bàn làm sạch dữ liệu…"],
        blocks: [
            .shortcuts([HelpShortcut("⇧⌘L", "Open the cleaning bench")]),
            .table(
                headers: ["Operation", "What it does"],
                rows: [
                    ["Normalise dates", "Bring every date form in the column to one form"],
                    ["Normalise numbers", "Settle the decimal separator and the grouping separator"],
                    ["Trim whitespace", "Remove it at both ends; optionally collapse inner runs too"],
                    ["Change case", "Make the column's capitalisation consistent"],
                    ["Fill with a fixed value", "Replace empty cells with a value you type"],
                    ["Fill from a neighbour", "Take the value from the row above or below"],
                    ["Delete rows with empty cells", "Drop rows that are missing data"],
                ]
            ),
            .heading("Three guarantees from the whole bench"),
            .bullets([
                "**Always previewed.** A before→after table, with the number of cells that will change.",
                "**One undo step** for the whole pass, even when it touches a million cells.",
                "**A report afterwards**: how many cells changed, and which ones could not be read.",
            ]),
            .heading("The principle: never guess"),
            .paragraph("""
                A cell that cannot be read with certainty is **marked and left alone**. Take \
                `03/04/2026` in a column that mixes both conventions — is it 3 April or 4 March? \
                GEditor asks you for the day/month order rather than choosing for you.
                """),
            .warning("""
                Normalising a date column wrongly is the kind of corruption that is **almost \
                impossible to detect**: the numbers still look right, they are simply a different \
                date. That is why this bench would rather refuse than infer.
                """),
            .seeAlso(["cong-thuc-lam-sach", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Fuzzy duplicates

    static let fuzzyDuplicates = HelpTopic(
        id: "trung-lap-mo",
        title: "Fuzzy duplicates",
        summary: "Find hand-typed variants of the same name — and never merge them automatically.",
        keywords: ["fuzzy", "duplicates", "dedupe", "merge", "variants", "typos"],
        commands: ["Trùng lặp mờ theo cột…"],
        blocks: [
            .paragraph("""
                `Công ty TNHH An Bình`, `Cty TNHH An Bình`, `CÔNG TY  TNHH AN BÌNH` — three ways of \
                typing one customer. Ordinary deduplication does not see them as the same.
                """),
            .steps([
                "Choose the column to examine and a similarity threshold.",
                "GEditor groups near values into **clusters** and shows the comparison form.",
                "For **each cluster**, you choose which value to keep — or skip that cluster.",
                "Apply. One undo step.",
            ]),
            .warning("""
                This tool **never merges by itself**, and there is no \"merge all\" button. Two \
                strings that are 92% alike may be a typo, or two genuinely different companies that \
                differ by one word — a machine cannot tell.
                """),
            .paragraph("""
                Merging two records wrongly is **silent** data loss: no cell becomes empty, no row \
                turns red, two entities simply become one and nobody notices until the books are \
                reconciled.
                """),
            .seeAlso(["quy-trinh-lam-sach", "gom-bien-the-entity"]),
        ]
    )

    // MARK: - Recipe

    static let cleaningRecipe = HelpTopic(
        id: "cong-thuc-lam-sach",
        title: "Cleaning recipes",
        summary: "Record the sequence as a JSON file and rerun it on next month's data.",
        keywords: ["recipe", "repeat", "automate", "monthly", "batch"],
        commands: ["Chạy công thức làm sạch…"],
        blocks: [
            .paragraph("""
                After cleaning, save the steps as a **recipe**. It is a human-readable JSON file \
                you can keep beside the data, send to a colleague, and commit to a repository so \
                changes are tracked.
                """),
            .code(
                language: "json",
                caption: "sales-standard.json — abridged",
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
                    """
            ),
            .paragraph("""
                Each step can be **switched off** (`enabled`), so one recipe can serve several \
                near-identical kinds of file.
                """),
            .heading("Rerunning"),
            .bullets([
                "In the app: `CSV ▸ Run cleaning recipe…`",
                "From the shell, across a folder: see the command-line page.",
            ]),
            .code(
                language: "bash",
                caption: "A dry run before writing anything — no file is touched",
                source: """
                    geditor --recipe sales-standard.json --dry-run sales-*.csv
                    """
            ),
            .note("""
                By default the result is written to a new file beside the original \
                (`sales-clean.csv`). Overwriting the original has to be requested explicitly with \
                `--overwrite`.
                """),
            .seeAlso(["dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )

    // MARK: - Quality scoring

    static let qualityScoring = HelpTopic(
        id: "cham-chat-luong",
        title: "Data quality scoring",
        summary: "Six dimensions, one 0–100 score, and every formula printed so you can recompute it.",
        keywords: ["quality", "score", "dqr", "six dimensions"],
        commands: ["CSV: chất lượng dữ liệu…"],
        blocks: [
            .paragraph("""
                It differs from the data profile in one fundamental way: a profile **describes**, a \
                score **judges against the standard you declared** in a `.gquality.yaml` file.
                """),
            .table(
                headers: ["Dimension", "What it measures"],
                rows: [
                    ["Completeness", "Proportion of filled cells, per the `not_null` rules"],
                    ["Validity", "Proportion of format, type, range and regex rules that pass"],
                    ["Uniqueness", "Against the key you declared in `uniqueness_key`"],
                    ["Consistency", "Cross-column and cross-file rules"],
                    ["Accuracy (estimated)", "Outliers in the numeric columns you nominate"],
                    ["Timeliness", "How old the data is against the `freshness` threshold"],
                ]
            ),
            .heading("Three guarantees about the score"),
            .bullets([
                "**The formula is printed in the result** — you can recompute it by hand.",
                "**Deterministic**: the same data and the same rules give the same score. Only *Timeliness* depends on the moment, so `now` is a **parameter** and is recorded in the result.",
                "**A dimension that cannot be scored is left blank with a reason**, never silently given 100.",
            ]),
            .warning("""
                That last guarantee matters. A table with no `uniqueness_key` declared, awarded 100 \
                for \"uniqueness\", is a score that lies — and it lies in the flattering direction, \
                which is the dangerous one.
                """),
            .seeAlso(["cu-phap-gquality", "cong-chat-luong", "ho-so-du-lieu"]),
        ]
    )

    // MARK: - .gquality.yaml syntax

    static let gqualitySyntax = HelpTopic(
        id: "cu-phap-gquality",
        title: "`.gquality.yaml` syntax",
        summary: "Every key of the rule file, with one complete rule set that runs.",
        keywords: ["gquality", "yaml", "rules", "syntax", "data standard"],
        blocks: [
            .paragraph("""
                The file lives **beside the data**, not inside the application: a data standard has \
                to be reviewable, and reviewing is what people do with standards.
                """),
            .code(
                language: "yaml",
                caption: "sales-standard.yaml — a complete rule set",
                source: """
                    schemaVersion: 1

                    # Weights for the six dimensions. A missing dimension weighs 1.
                    weights:
                      completeness: 2
                      validity: 2
                      uniqueness: 1
                      consistency: 1
                      accuracy: 1
                      timeliness: 1

                    # The key that makes a row unique. Without it the "Uniqueness" dimension
                    # CANNOT be scored — and the total will say that it is missing.
                    uniqueness_key: [ma_don]

                    # Numeric columns examined for outliers in "Accuracy (estimated)".
                    accuracy_columns: [doanh_thu, so_luong]

                    # The "Timeliness" dimension.
                    freshness:
                      column: ngay
                      max_age_days: 45

                    # Warn when this run drops compared with the previous one.
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
                        max_null_pct: 2          # allow 2% empty
                      # Cross-column rule: no `col` needed
                      - compare: { a: ngay_giao, op: ">=", b: ngay_dat }
                      # Cross-file rule: the value must exist in another file
                      - col: ma_tinh
                        foreign_key: { file: danh-muc-tinh.csv, column: ma_tinh }
                    """
            ),
            .heading("The rule types"),
            .table(
                headers: ["Key", "Meaning", "Dimension"],
                rows: [
                    ["`not_null: true`", "The cell must be filled; `max_null_pct` loosens it", "Completeness"],
                    ["`unique: true`", "No repeated values in the column", "Uniqueness"],
                    ["`dtype: int\\|float\\|date\\|text`", "Correct type", "Validity"],
                    ["`range: { min:, max: }`", "Within a numeric range", "Validity"],
                    ["`length: { min:, max: }`", "String length", "Validity"],
                    ["`regex: \"…\"`", "Matches a regular expression", "Validity"],
                    ["`in_set: [ … ]`", "One of a given list", "Validity"],
                    ["`date_format: \"…\"`", "Correct date shape", "Validity"],
                    ["`compare: { a:, op:, b: }`", "Compare two columns; `op` is `<` `<=` `=` `>=` `>` `<>`", "Consistency"],
                    ["`foreign_key: { file:, column: }`", "The value must exist in another file", "Consistency"],
                    ["`severity: error\\|warn`", "The rule's severity; `error` by default", "—"],
                ]
            ),
            .warning("""
                Misspell a rule key and the file is **rejected with a message**, rather than that \
                rule being skipped silently. Skipping silently means you believe the data was \
                checked against a rule that never ran.
                """),
            .seeAlso(["cham-chat-luong", "cong-chat-luong"]),
        ]
    )

    // MARK: - Quality gate

    static let qualityGate = HelpTopic(
        id: "cong-chat-luong",
        title: "A quality gate in CI",
        summary: "Stop failing data at the pipeline, using exit codes.",
        keywords: ["ci", "gate", "fail-under", "exit code", "automation", "history", "drift"],
        blocks: [
            .code(
                language: "bash",
                caption: "Score and return an exit code",
                source: """
                    geditor --quality sales-standard.yaml \\
                            --fail-under 90 \\
                            --json result.json \\
                            --record-history \\
                            --now 2026-09-01 \\
                            sales-2026-09.csv
                    """
            ),
            .table(
                headers: ["Option", "Meaning"],
                rows: [
                    ["`--quality <file.yaml>`", "The rule set to score against"],
                    ["`--fail-under <0…100>`", "Below this score is a FAIL"],
                    ["`--json <file\\|->`", "Machine-readable result; `-` prints to stdout"],
                    ["`--record-history`", "Append a line to `sales-standard.history.jsonl`"],
                    ["`--now <YYYY-MM-DD>`", "Pin the reference date for *Timeliness*"],
                    ["`--recipe <file.json>`", "Clean **in memory** before scoring, writing no file"],
                ]
            ),
            .table(
                headers: ["Exit code", "Meaning"],
                rows: [["`0`", "Pass"], ["`1`", "Fail"], ["`2`", "Run-time error"]],
            ),
            .heading("Why CI should pass `--now`"),
            .paragraph("""
                Without it, *Timeliness* compares the data against the moment of the run — so the \
                same file loses points as days pass, and one morning the pipeline turns red with \
                nobody having changed anything.
                """),
            .heading("Drift tracking"),
            .paragraph("""
                With `--record-history`, each run appends a line to a JSONL history file. Next time, \
                the thresholds in the `drift:` block compare against the most recent run and warn \
                when the drop is too large.
                """),
            .note("""
                Every drift threshold is **off by default**, except `warn_on_new_failure`. A warning \
                enabled out of the box with a number the app chose for you would fire on everybody's \
                second run — and something that cries wolf on day one is ignored by day three.
                """),
            .seeAlso(["cu-phap-gquality", "dong-lenh", "quy-trinh-lam-sach"]),
        ]
    )
}
