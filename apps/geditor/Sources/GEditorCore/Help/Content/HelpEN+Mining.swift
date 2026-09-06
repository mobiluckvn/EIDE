import Foundation

extension HelpEN {

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "Data mining — the whole workflow",
        summary: "Anomalies, correlation, clustering, forecasting, association rules — and how to read them.",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    // MARK: - Workflow

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "The mining workflow, end to end",
        summary: "Six tools, the order to use them in, and one rule: no measurement, no conclusion.",
        keywords: ["mining", "analysis", "workflow", "statistics"],
        blocks: [
            .warning("""
                **Clean first, mine second.** An unnormalised date column produces wrong forecasts; \
                a numeric column mixing European grouping separators produces phantom outliers. \
                Every tool below assumes the table is clean.
                """),
            .heading("The order to go in"),
            .steps([
                "**Find anomalies** — answers *\"is any row odd\"*. Cheapest, and often immediately useful.",
                "**Correlation matrix** — answers *\"which column moves with which\"*. It steers everything after it.",
                "**Clustering** — answers *\"how many natural groups are in here\"*.",
                "**Forecasting** — only with a time column and at least **two full cycles**.",
                "**Association rules** — only for basket-shaped data: one transaction per row, or two columns of transaction ID and item.",
                "**Group mining** — reruns the first three **independently within each group**. This step frequently reverses the conclusion drawn from the pooled table.",
            ]),
            .heading("Three rules for the whole family"),
            .bullets([
                "**Every result carries a \"Method\" block**: algorithm, parameters, seed, formula. There is no way to turn it off — a table of three numbers that does not say where they came from cannot be used for a decision.",
                "**No measurement, no conclusion.** Too small a sample, zero variance, a singular matrix — GEditor refuses and says why, rather than returning a number that merely looks right.",
                "**Deterministic results.** The same data gives the same result; wherever randomness is needed, the seed is recorded in the output.",
            ]),
            .heading("From a result back to the data"),
            .paragraph("""
                Every panel **marks back into the source data**: click an anomalous row, a \
                correlation cell or an association rule and the relevant lines get marked in the \
                grid. That is how you go from *\"something is odd\"* to *\"odd in exactly these \
                rows\"*.
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    // MARK: - Anomalies

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "Finding anomalous rows",
        summary: "Four measures, three severity levels, and an explanation of why a row is odd.",
        keywords: ["outlier", "anomaly", "z-score", "iqr", "mad", "mahalanobis"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["Measure", "Use when"],
                rows: [
                    ["z-score", "The column is roughly normally distributed"],
                    ["IQR", "The column is skewed with a long tail — the safe default"],
                    ["MAD", "The column already contains many outliers and needs a robust measure"],
                    ["Mahalanobis", "**Several columns at once** — catches rows odd in combination, not in any single column"],
                ]
            ),
            .paragraph("""
                Results are coloured by **three severity levels** rather than one flat colour — \
                otherwise a slightly unusual row is indistinguishable from a wildly unusual one.
                """),
            .heading("Explaining why"),
            .paragraph("""
                For the multi-column measure, GEditor decomposes each column's contribution and \
                produces a sentence such as *«anomalous mainly through the combination revenue \
                (50%) × quantity (50%)»*.
                """),
            .note("""
                That percentage is *of the explainable part*, not *of the distance*. The Method \
                block states this directly under the table.
                """),
            .warning("""
                A column whose IQR or MAD is zero makes the measure **refuse to run**, rather than \
                dividing by something tiny and producing an enormous score. For the multi-column \
                case, if the covariance matrix is singular, GEditor **says which column to drop** \
                instead of using a pseudo-inverse to \"make it work\".
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Correlation

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "Correlation matrix",
        summary: "Pearson and Spearman for every pair, with a scatter plot on click.",
        keywords: ["correlation", "pearson", "spearman", "heatmap", "scatter"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["Coefficient", "What it measures"],
                rows: [
                    ["Pearson", "A **linear** relationship"],
                    ["Spearman", "**Any monotonic** relationship, including curved ones — computed on ranks"],
                ]
            ),
            .paragraph("""
                Click a cell in the heat map to see that pair's scatter plot, with a regression line \
                and R².
                """),
            .heading("Four details that change how you read it"),
            .bullets([
                "**Ties use average ranks**, so re-sorting the table does not change the Spearman coefficient.",
                "**Empty cells are handled pairwise**, and each cell's `n` is right there in the table — `0.93` over 6 rows does not mean what `0.93` over 6,000 rows means.",
                "**A constant column returns blank**, not 0. Zero means *measured, no relationship found*.",
                "**The colour scale is blue↔orange**, not red–green: 8% of men see a red–green scale as one grey mass, which makes `+0.9` and `−0.9` look identical.",
            ]),
            .warning("""
                **Correlation does not imply causation.** That sentence is drawn **inside the chart \
                itself**, so it travels with the image when you export it.
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    // MARK: - Clustering

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "Clustering",
        summary: "k-means and DBSCAN, two ways to choose k — and a warning about scaling.",
        keywords: ["cluster", "kmeans", "dbscan", "groups", "silhouette", "elbow"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["Algorithm", "Use when"],
                rows: [
                    ["k-means", "You know (or want to try) the number of clusters; clusters are blob-shaped"],
                    ["DBSCAN", "You do not know the number; clusters have arbitrary shapes; you want noise separated out"],
                ]
            ),
            .heading("Scaling is on by default — and why"),
            .paragraph("""
                A `revenue` column (in millions) sitting beside a `quantity` column (in units): the \
                distance between two rows is decided almost entirely by the larger one. That is not \
                \"suboptimal\" — it is **answering a different question**. The scaling in force is \
                recorded in the result.
                """),
            .heading("Choosing the number of clusters"),
            .bullets([
                "**Silhouette** — the higher the score, the better separated the clusters. On a large table it **samples** (evenly spaced, not the first 2,000 rows), and the result declares itself an estimate.",
                "**Elbow** — plots within-cluster sum of squares against k. This is a **way of reading a chart**, not an optimisation: that quantity always falls as k rises, so there is no statistically \"optimal k\".",
            ]),
            .note("""
                For DBSCAN, the **k-distance** plot helps pick a radius: the knee of the curve is \
                usually a sensible starting value.
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Forecasting

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "Time-series forecasting",
        summary: "Trend and seasonal decomposition, Holt-Winters, and a baseline that always runs beside it.",
        keywords: ["forecast", "time series", "seasonality", "holt-winters", "trend"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                Pick a time column and a value column. GEditor decomposes the series into **trend · \
                seasonality · residual**, then forecasts with Holt-Winters (additive or \
                multiplicative), with 80% and 95% intervals.
                """),
            .heading("The baseline always runs, and it says outright who won"),
            .paragraph("""
                Alongside the model, GEditor runs two naive methods: *take the previous period* and \
                *take the same period last season*. If the model **loses** to a baseline, that \
                sentence appears on the **first line, in a different colour** — not underneath a \
                table of numbers.
                """),
            .paragraph("""
                The reason: forecasting tools tend to present the model as fact, and the user has no \
                way of learning that \"just take last month's figure\" would have been more accurate.
                """),
            .heading("Three places GEditor refuses, or declares itself"),
            .bullets([
                "**Without two full cycles it falls back to the naive method.** Fitting seasonality to the noise of a single cycle and repeating it into the future produces a very convincing, entirely invented forecast.",
                "**MAPE meeting a zero says so**, and if more than 25% of periods are zero it withholds the metric — silently skipping them produces a number computed on a systematically biased subset.",
                "**The confidence interval declares itself approximate**, and states that it widens too slowly at long horizons.",
            ]),
            .note("""
                The seasonal period is detected on the **first difference**, not on the raw series: \
                a trend makes every lag highly correlated and drowns the seasonal peak.
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Association rules

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "Association rules",
        summary: "Buy A, often buy B — and why the table is sorted by lift, not confidence.",
        keywords: ["apriori", "association rules", "market basket", "lift", "support"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("Two data shapes are accepted:"),
            .bullets([
                "**One basket per row** — a column containing a list of items.",
                "**Two columns** — transaction ID and item, one item per row.",
            ]),
            .table(
                headers: ["Metric", "Meaning"],
                rows: [
                    ["support", "Share of baskets containing both sides"],
                    ["confidence", "Of the baskets with the left side, what share have the right"],
                    ["**lift**", "Confidence divided by the right side's base rate"],
                    ["leverage", "The gap from what independence would predict"],
                ]
            ),
            .heading("Sorted by lift, not confidence"),
            .paragraph("""
                If the right-hand side appears in 95% of baskets anyway, then **every** rule leading \
                to it has around 95% confidence — while saying nothing at all. Sorting by confidence \
                puts precisely the most meaningless rules on top.
                """),
            .warning("""
                `lift < 1` is **flagged in the row itself**: 80% confidence toward something with a \
                95% base rate means an **inverse** relationship — a correct number leading to a \
                wrong conclusion.
                """),
            .bullets([
                "Buying two cartons of milk is still **one** transaction containing milk: duplicates within a basket are dropped, otherwise support inflates with quantity.",
                "Setting the support threshold too low makes the candidate set explode combinatorially; on hitting the ceiling, GEditor **stops and states that the table is incomplete**.",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    // MARK: - Group mining

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "Mining by group",
        summary: "Rerun the analysis independently per group — the step that most often reverses a conclusion.",
        keywords: ["group by", "per group", "simpson", "branches", "compare groups"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                Choose a text column as the grouping key. Each group gets anomalies, forecasting and \
                correlation run **completely independently**, then ranked by the criterion you pick.
                """),
            .heading("Why groups must be separated, not pooled"),
            .paragraph("""
                Two branches, one around 10 and one around 100. An outlier fence computed on the \
                **pooled** table lands around ±135 — and it fails in **both directions**:
                """),
            .bullets([
                "**False negatives**: a value of 20, plainly anomalous for the small branch, sits well inside the shared fence. The more groups, the blinder it gets.",
                "**False positives**: a widely spread group has its normal tail cut off by the shared fence, and a swathe of ordinary rows gets flagged.",
            ]),
            .heading("The \"correlation divergence\" column catches Simpson's paradox"),
            .paragraph("""
                Three groups in which **each** group's two columns correlate at `−1`, yet pooled they \
                correlate at `> 0.9`. Anyone reading only the pooled table concludes the **exact \
                opposite**. This column points at precisely those cases.
                """),
            .note("""
                The panel offers only **text columns** as grouping keys, and stops at 1,000 groups \
                with a warning — to prevent picking an order-ID column and turning every row into a \
                group of its own.
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    // MARK: - Text mining

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "Text mining",
        summary: "n-grams and TF-IDF over a text column — finding characteristic phrases.",
        keywords: ["text mining", "n-gram", "tf-idf", "keywords", "phrases"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                Runs on one text column — product descriptions, customer feedback, note fields.
                """),
            .bullets([
                "**n-grams** — the most frequent 1-, 2- and 3-word phrases.",
                "**TF-IDF** — words **characteristic** of each document group, that is, frequent here and rare elsewhere.",
            ]),
            .paragraph("""
                The difference: n-grams tell you *\"what customers keep mentioning\"*, TF-IDF tells \
                you *\"how this group differs from the others\"*.
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
