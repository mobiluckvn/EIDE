import Foundation

/// 简体中文帮助内容 —— 第九部分：知识包。
extension HelpZhHans {

    static let knowledge = HelpChapter(
        id: "tri-thuc",
        title: "知识包",
        summary: "切块、检索索引、知识图谱、实体，以及检索质量评测。",
        topics: [knowledgePack, chunksAndJSONL, knowledgeConversion, knowledgeGraph, entityMarking,
                 entityResolution, retrievalLab]
    )

    static let knowledgePack = HelpTopic(
        id: "goi-tri-thuc",
        title: "知识包是什么",
        summary: "为「在文档上答问」的系统准备并检查数据的一套工具。",
        keywords: ["rag", "知识", "chunk", "embedding", "graphrag", "llm"],
        blocks: [
            .paragraph("""
                做一个能从文档集里回答问题的系统时，大部分工作不在模型，而在**准备数据**：把文档 \
                切成合适的段落、检查这些段落的质量、建索引，以及**衡量检索到底有没有找对东西**。
                """),
            .paragraph("""
                这一章正是为此准备的工具。它**完全在您自己的机器上运行**，从不访问网络。
                """),
            .table(
                headers: ["任务", "工具"],
                rows: [
                    ["把文档切成段落", "切块预览"],
                    ["查看并评分段落", "JSONL 块检查"],
                    ["在数据形状之间转换", "知识格式转换"],
                    ["构建并检查关系图", "知识图谱"],
                    ["在文本里找专有名词", "实体标注"],
                    ["衡量检索质量", "检索实验室"],
                ]
            ),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc", "phong-thi-nghiem-truy-hoi"]),
        ]
    )

    static let chunksAndJSONL = HelpTopic(
        id: "chunk-va-jsonl",
        title: "切块与检查 JSONL 语料",
        summary: "在原文上预览切块边界，再给整个语料评分。",
        keywords: ["chunk", "jsonl", "语料", "重叠", "token"],
        commands: ["Xem trước cắt chunk…", "JSONL: kiểm và soi chunk…"],
        blocks: [
            .heading("切块预览"),
            .paragraph("""
                打开一份文本或 Markdown 文档，选一种策略和块大小。边界会**高亮在原文上**，因此 \
                在导出任何东西之前，您就能看见哪一刀切在了句子中间或穿过了一张表。
                """),
            .bullets([
                "**固定大小**，带重叠。",
                "**按结构** —— 按 Markdown 标题切，保持文档的脉络完整。",
                "**按段落**，合并到够大为止。",
            ]),
            .heading("检查已有的 JSONL 语料"),
            .paragraph("""
                对于您手上已有的语料（每行一个 JSON 块），`JSONL：检查块…`回答：哪些行不是合法 \
                JSON、哪些块太短或太长、哪些彼此重复、哪些被切在了句子中间。
                """),
            .note("""
                语料同样可以用**与表格数据相同的六维框架**评分 —— 在报告的 `quality` 块里用 \
                `corpus:` 这个键。
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cong-cu-json"]),
        ]
    )

    static let knowledgeConversion = HelpTopic(
        id: "chuyen-doi-tri-thuc",
        title: "转换知识格式",
        summary: "块在 JSONL · CSV · Markdown 之间转，图在 DOT · Mermaid · 边列表之间转。",
        keywords: ["转换", "jsonl", "dot", "mermaid", "边列表"],
        commands: ["Chuyển đổi tri thức…", "Mở triple/edge dạng bảng"],
        blocks: [
            .table(
                headers: ["从", "到"],
                rows: [
                    ["JSONL 块", "CSV · Markdown"],
                    ["CSV 块", "JSONL · Markdown"],
                    ["DOT 图", "Mermaid · 边列表"],
                    ["边列表", "DOT · Mermaid"],
                ]
            ),
            .paragraph("""
                建立新标签页之前有**五行预览**，与 CSV 转换是同一套机制。
                """),
            .paragraph("""
                `以表格打开三元组／边`把三元组文件或边列表显示为表格 —— 可以像任何 CSV 一样筛选 \
                和排序。
                """),
            .note("""
                **Markdown → JSONL** 这个方向不在这条命令里：那个方向*就是*切块，命令会把您指 \
                过去。同一刀有两份实现，会得出两种不同的结果。
                """),
            .seeAlso(["chunk-va-jsonl", "do-thi-tri-thuc"]),
        ]
    )

    static let knowledgeGraph = HelpTopic(
        id: "do-thi-tri-thuc",
        title: "知识图谱",
        summary: "检查语法、评估健康度，并在百万条边的图上跑算法。",
        keywords: ["图", "dot", "cypher", "pagerank", "louvain", "语法检查"],
        commands: ["Kiểm cú pháp đồ thị"],
        blocks: [
            .paragraph("""
                GEditor 能读 **DOT**、**边列表**和**三元组**形式的图。`检查图语法`能抓出语法 \
                错误、悬空节点，以及指向并不存在的节点的边。
                """),
            .heading("可用的算法"),
            .table(
                headers: ["算法", "回答"],
                rows: [
                    ["k 跳邻域", "在 k 步之内，什么与这个节点相关"],
                    ["连通分量", "这张图分成几块互不相连的部分"],
                    ["PageRank", "哪些节点重要"],
                    ["Louvain", "这张图怎么划分成社群"],
                ]
            ),
            .paragraph("""
                在**百万条边**的图上，这四种算法都在几毫秒到一秒左右之间跑完。
                """),
            .note("""
                图同样可以用给表格和语料用的**六维框架**评分 —— 在 `quality` 块里用 `graph:` \
                这个键。
                """),
            .seeAlso(["khoi-quality", "chuyen-doi-tri-thuc", "cu-phap-mermaid"]),
        ]
    )

    static let entityMarking = HelpTopic(
        id: "danh-dau-entity",
        title: "按名单标注实体",
        summary: "载入一份专有名词清单并找出每一处 —— 遵循三条为越南语而设的规则。",
        keywords: ["实体", "专有名词", "ner", "标注", "词典", "匹配"],
        commands: ["Đánh dấu entity từ danh sách…"],
        blocks: [
            .paragraph("""
                载入一份名称清单（公司、产品、地名），GEditor 会在文档中高亮每一处出现，并给出 \
                计数表。
                """),
            .heading("三条匹配规则，全都来自越南语数据"),
            .bullets([
                "**最长匹配优先。** 清单里同时有 `An Phát` 和 `Công ty An Phát` 时，含较长短语的句子必须匹配较长的那个 —— 否则它会被切成两段、算作两个实体，把统计**抬高**。",
                "**必须有词边界。** `An` 不能匹配到 `Anh` 或 `Hoàn` 内部。越南语的专有名词很短，又与无数普通词共用音节。",
                "**忽略大小写，但**声调**敏感。** `CÔNG TY` 和 `Công ty` 是同一个；`má` 和 `ma` 不是。",
            ]),
            .seeAlso(["gom-bien-the-entity", "khai-pha-van-ban"]),
        ]
    )

    static let entityResolution = HelpTopic(
        id: "gom-bien-the-entity",
        title: "归并实体变体",
        summary: "认出 `Cty An Phát` 和 `Công ty An Phát` 是同一个 —— 决定权仍在您手里。",
        keywords: ["实体归并", "变体", "名称规范化", "重复"],
        blocks: [
            .paragraph("""
                与 CSV 表格里的**模糊重复**用的是同一套聚类 —— 一份共用实现，不是两份。
                """),
            .paragraph("""
                输出是一份**提议**：您逐簇审阅，选出规范写法。没有「全部合并」按钮，因为两个 \
                92% 相似的名字，可能是两家真实存在的不同机构。
                """),
            .seeAlso(["trung-lap-mo", "danh-dau-entity"]),
        ]
    )

    static let retrievalLab = HelpTopic(
        id: "phong-thi-nghiem-truy-hoi",
        title: "检索实验室",
        summary: "用一套带标准答案的问题集，衡量索引有没有找对东西。",
        keywords: ["检索", "bm25", "召回", "mrr", "ndcg", "评测", "标准集"],
        commands: ["JSONL: phòng thí nghiệm truy hồi…"],
        blocks: [
            .paragraph("""
                载入一份**评测集** —— 每行是一个问题，附上应当被返回的块 id —— 然后整批跑一遍 \
                索引。
                """),
            .table(
                headers: ["指标", "回答"],
                rows: [
                    ["recall@k", "答案集里有多少出现在前 k 名"],
                    ["MRR", "第一个正确结果排在多靠后"],
                    ["nDCG@k", "排序好不好，含位置因素"],
                ]
            ),
            .paragraph("""
                结果也会**逐题**给出，最差的排在最前 —— 那就是您在语料里要修的清单，而且按最 \
                值得修的顺序排好了。
                """),
            .warning("""
                这三个指标都是**平均值**，而平均值藏得住很多东西。在断言「索引够好了」之前， \
                永远先读逐题那张表。
                """),
            .paragraph("""
                两套配置可以并排比较，结果能直接落进 `.greport.md` 报告，好让下一次跑得一模一样。
                """),
            .seeAlso(["chunk-va-jsonl", "bao-cao-greport"]),
        ]
    )
}
