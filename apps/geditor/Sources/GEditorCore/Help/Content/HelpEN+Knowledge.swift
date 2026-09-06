import Foundation

extension HelpEN {

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "The knowledge pack",
        summary: "Chunking, search indexes, knowledge graphs, entities and retrieval evaluation.",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    // MARK: - Overview

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "What the knowledge pack is",
        summary: "Tools for preparing and checking data for a question-answering system over documents.",
        keywords: ["rag", "knowledge", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                When building a system that answers questions from a document corpus, most of the \
                work is not in the model but in **preparing the data**: cutting documents into \
                sensible passages, checking the quality of those passages, building an index, and \
                **measuring whether retrieval actually finds the right thing**.
                """),
            .paragraph("""
                This chapter is the toolset for exactly that. It runs **entirely on your machine** \
                and never calls out to a network.
                """),
            .table(
                headers: ["Task", "Tool"],
                rows: [
                    ["Cut documents into passages", "Chunk preview"],
                    ["Inspect and score passages", "JSONL chunk inspection"],
                    ["Convert between data shapes", "Knowledge conversion"],
                    ["Build and inspect a relationship graph", "Knowledge graph"],
                    ["Find proper nouns in text", "Entity marking"],
                    ["Measure retrieval quality", "Retrieval lab"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    // MARK: - Chunks

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "Chunking and inspecting a JSONL corpus",
        summary: "Preview chunk boundaries on the text itself, then score the whole corpus.",
        keywords: ["chunk", "jsonl", "corpus", "overlap", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("Chunk preview"),
            .paragraph("""
                Open a text or Markdown document, choose a strategy and a chunk size. The boundaries \
                are **highlighted on the text itself**, so you can see where a cut falls mid-sentence \
                or through a table before exporting anything.
                """),
            .bullets([
                "**Fixed size** with an overlap.",
                "**By structure** — on Markdown headings, keeping the document's flow intact.",
                "**By paragraph**, merging until the size is reached.",
            ]),
            .heading("Inspecting an existing JSONL corpus"),
            .paragraph("""
                For a corpus you already have (one JSON chunk per line), `JSONL: inspect chunks…` \
                answers: which lines are invalid JSON, which chunks are too short or too long, which \
                ones duplicate each other, and which were cut mid-sentence.
                """),
            .note("""
                A corpus can also be scored with the **same six-dimension framework** as tabular \
                data — use the `corpus:` key in a report's `quality` block.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    // MARK: - Conversion

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "Converting knowledge formats",
        summary: "Chunks between JSONL · CSV · Markdown, graphs between DOT · Mermaid · edge lists.",
        keywords: ["convert", "jsonl", "dot", "mermaid", "edge list"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["From", "To"],
                rows: [
                    ["JSONL chunks", "CSV · Markdown"],
                    ["CSV chunks", "JSONL · Markdown"],
                    ["DOT graph", "Mermaid · edge list"],
                    ["Edge list", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                There is a **five-row preview** before the new tab is created, the same mechanism as \
                the CSV conversion.
                """),
            .paragraph("""
                `Open triples/edges as a table` shows a triple file or edge list as a grid — filter \
                and sort it like any other CSV.
                """),
            .note("""
                The **Markdown → JSONL** direction is not in this command: that direction *is* \
                chunking, and the command points you there. Two implementations of one cut would \
                produce two different results.
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    // MARK: - Knowledge graph

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "Knowledge graphs",
        summary: "Check syntax, score health, and run algorithms on million-edge graphs.",
        keywords: ["graph", "dot", "cypher", "pagerank", "louvain", "syntax check"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor reads graphs as **DOT**, **edge lists** and **triples**. `Check graph syntax` \
                catches syntax errors, dangling nodes and edges pointing at nodes that do not exist.
                """),
            .heading("Available algorithms"),
            .table(
                headers: ["Algorithm", "Answers"],
                rows: [
                    ["k-hop neighbourhood", "What is related to this node within k steps"],
                    ["Connected components", "How many disjoint pieces the graph has"],
                    ["PageRank", "Which nodes are important"],
                    ["Louvain", "How the graph divides into communities"],
                ]
            ),
            .paragraph("""
                On a **million-edge** graph, all four run in somewhere between a few milliseconds \
                and about a second.
                """),
            .note("""
                A graph can also be scored with the **six-dimension framework** used for tables and \
                corpora — use the `graph:` key in a `quality` block.
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    // MARK: - Entity marking

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "Marking entities from a list",
        summary: "Load a list of proper nouns and find every occurrence — under three rules built for Vietnamese.",
        keywords: ["entity", "proper noun", "ner", "marking", "gazetteer", "matching"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                Load a list of names (companies, products, places) and GEditor highlights every \
                occurrence in the document, with a count table.
                """),
            .heading("Three matching rules, all of them from Vietnamese data"),
            .bullets([
                "**Longest match wins.** With both `An Phát` and `Công ty An Phát` in the list, a sentence containing the longer phrase must match the longer one — otherwise it is split in two and counted as two entities, which **inflates** the statistics.",
                "**Word boundaries are required.** `An` must not match inside `Anh` or `Hoàn`. Vietnamese proper nouns are short and share syllables with countless ordinary words.",
                "**Case-insensitive, but diacritic-SENSITIVE.** `CÔNG TY` and `Công ty` are one; `má` and `ma` are not.",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    // MARK: - Entity resolution

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "Resolving entity variants",
        summary: "Recognise `Cty An Phát` and `Công ty An Phát` as one — still leaving the decision to you.",
        keywords: ["entity resolution", "variants", "name normalisation", "duplicates"],
        blocks: [
            .paragraph("""
                The same clustering as **fuzzy duplicates** in a CSV grid — one shared \
                implementation, not two.
                """),
            .paragraph("""
                The output is a **proposal**: you review each cluster and choose the canonical form. \
                There is no merge-all button, because two names 92% alike may be two real \
                organisations.
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    // MARK: - Retrieval lab

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "The retrieval lab",
        summary: "Measure whether the index finds the right thing, using a question set with answers.",
        keywords: ["retrieval", "bm25", "recall", "mrr", "ndcg", "evaluation", "golden set"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                Load an **evaluation set** — each line a question with the chunk ids that should be \
                returned — then run the whole batch against the index.
                """),
            .table(
                headers: ["Metric", "Answers"],
                rows: [
                    ["recall@k", "How much of the answer set appears in the top k"],
                    ["MRR", "How far down the first correct result sits"],
                    ["nDCG@k", "Whether the ranking is good, position included"],
                ]
            ),
            .paragraph("""
                Results come **per question** as well, worst first — that is your list of things to \
                fix in the corpus, in the order most worth fixing.
                """),
            .warning("""
                All three metrics are **averages**, and an average hides a great deal. Always read \
                the per-question table before concluding that \"the index is good enough\".
                """),
            .paragraph("""
                Two configurations can be compared side by side, and the result drops straight into \
                a `.greport.md` report so the next run is identical.
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )
}
