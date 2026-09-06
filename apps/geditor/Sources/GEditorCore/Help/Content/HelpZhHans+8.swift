import Foundation

/// 简体中文帮助内容 —— 第八部分：数据挖掘全流程。
extension HelpZhHans {

    static let mining = HelpChapter(
        id: "khai-pha",
        title: "数据挖掘 —— 完整流程",
        summary: "异常、相关、聚类、预测、关联规则 —— 以及怎么读懂它们。",
        topics: [miningWorkflow, anomalies, correlationMatrix, clustering, forecasting,
                 associationRules, groupMining, textMining]
    )

    static let miningWorkflow = HelpTopic(
        id: "quy-trinh-khai-pha",
        title: "挖掘流程，从头到尾",
        summary: "六件工具、使用顺序，以及一条规矩：没有测量就没有结论。",
        keywords: ["挖掘", "分析", "流程", "统计"],
        blocks: [
            .warning("""
                **先清洗，后挖掘。** 未规范的日期列会产出错误的预测；混着欧洲式千位分隔符的数值 \
                列会产出根本不存在的离群值。下面每一件工具都假定这张表是干净的。
                """),
            .heading("该走的顺序"),
            .steps([
                "**找异常** —— 回答*「有没有哪一行不对劲」*。最省力，而且常常立刻有用。",
                "**相关矩阵** —— 回答*「哪一列跟哪一列一起动」*。它左右着后面的一切。",
                "**聚类** —— 回答*「这里面天然有几组」*。",
                "**预测** —— 只有在有时间列且至少有**两个完整周期**时才做。",
                "**关联规则** —— 只适用于购物篮形状的数据：一行一笔交易，或者两列分别是交易号和商品。",
                "**分组挖掘** —— 在**每个组内独立**重跑前三项。这一步常常推翻从合并表得出的结论。",
            ]),
            .heading("整个家族的三条规矩"),
            .bullets([
                "**每份结果都带一个「方法」块**：算法、参数、随机种子、公式。没法关掉它 —— 一张三个数字却不说来路的表，无法用来做决定。",
                "**没有测量就没有结论。** 样本太小、方差为零、矩阵奇异 —— GEditor 会拒绝并说明原因，而不是返回一个看着像那么回事的数字。",
                "**结果是确定的。** 同样的数据给同样的结果；凡是需要随机的地方，种子都记录在输出里。",
            ]),
            .heading("从结果回到数据"),
            .paragraph("""
                每个面板都会**标回源数据**：点一行异常、一个相关格或一条关联规则，表格里相关的 \
                行就被标记出来。这就是从*「有点不对劲」*走到*「正是这几行不对劲」*的路。
                """),
            .seeAlso([
                "tim-bat-thuong", "ma-tran-tuong-quan", "phan-cum", "du-bao", "luat-ket-hop",
                "khai-pha-theo-nhom", "quy-trinh-lam-sach",
            ]),
        ]
    )

    static let anomalies = HelpTopic(
        id: "tim-bat-thuong",
        title: "找出异常行",
        summary: "四种度量、三档严重级别，还会解释这一行为什么不对劲。",
        keywords: ["离群值", "异常", "z-score", "iqr", "mad", "马氏距离"],
        commands: ["CSV: tìm bất thường…"],
        blocks: [
            .table(
                headers: ["度量", "什么时候用"],
                rows: [
                    ["z-score", "这一列大致服从正态分布"],
                    ["IQR", "这一列偏斜、有长尾 —— 稳妥的默认选择"],
                    ["MAD", "这一列本来就有很多离群值，需要稳健的度量"],
                    ["马氏距离", "**多列一起看** —— 抓的是组合起来才反常、单看任何一列都正常的行"],
                ]
            ),
            .paragraph("""
                结果按**三档严重级别**着色，而不是一种颜色到底 —— 否则稍微反常的行和极度反常的 \
                行就分不出来了。
                """),
            .heading("解释原因"),
            .paragraph("""
                对多列度量，GEditor 会分解出每一列的贡献，并给出一句话，例如*《主要因为营收 \
                (50%) × 数量 (50%) 这个组合而反常》*。
                """),
            .note("""
                那个百分比是*可解释部分*的占比，不是*距离*的占比。方法块就写在表格正下方。
                """),
            .warning("""
                IQR 或 MAD 为零的列会让度量**拒绝运行**，而不是去除以一个极小的数、产出一个巨大 \
                的分数。多列的情形下，如果协方差矩阵奇异，GEditor 会**指出该去掉哪一列**，而不是 \
                用伪逆去「让它能跑」。
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let correlationMatrix = HelpTopic(
        id: "ma-tran-tuong-quan",
        title: "相关矩阵",
        summary: "每一对列的 Pearson 与 Spearman，点一下看散点图。",
        keywords: ["相关", "pearson", "spearman", "热力图", "散点图"],
        commands: ["CSV: ma trận tương quan…"],
        blocks: [
            .table(
                headers: ["系数", "衡量什么"],
                rows: [
                    ["Pearson", "**线性**关系"],
                    ["Spearman", "**任何单调**关系，包括弯曲的 —— 在秩上计算"],
                ]
            ),
            .paragraph("""
                点热力图上的一格，即可看到那一对的散点图，带回归线和 R²。
                """),
            .heading("四个改变读法的细节"),
            .bullets([
                "**并列值取平均秩**，所以重新排序表格不会改变 Spearman 系数。",
                "**空单元格按对处理**，而每一格的 `n` 就写在表里 —— 6 行上的 `0.93` 和 6000 行上的 `0.93` 含义不同。",
                "**常量列返回空白**，不是 0。零的意思是*量过了，没发现关系*。",
                "**色标是蓝↔橙**，不是红绿：8% 的男性看红绿色标是一团灰，那会让 `+0.9` 和 `−0.9` 看起来一模一样。",
            ]),
            .warning("""
                **相关不等于因果。** 这句话**画在图表内部**，所以您导出图片时它会跟着走。
                """),
            .seeAlso(["khai-pha-theo-nhom", "pivot-va-bieu-do"]),
        ]
    )

    static let clustering = HelpTopic(
        id: "phan-cum",
        title: "聚类",
        summary: "k-means 与 DBSCAN，两种选 k 的办法 —— 以及一条关于缩放的警告。",
        keywords: ["聚类", "kmeans", "dbscan", "分组", "轮廓系数", "肘部法"],
        commands: ["CSV: phân cụm…"],
        blocks: [
            .table(
                headers: ["算法", "什么时候用"],
                rows: [
                    ["k-means", "您知道（或者想试）簇的个数；簇大致是团状的"],
                    ["DBSCAN", "您不知道个数；簇形状任意；您想把噪声分出来"],
                ]
            ),
            .heading("缩放默认开着 —— 为什么"),
            .paragraph("""
                一个 `营收` 列（以百万计）挨着一个 `数量` 列（以件计）：两行之间的距离几乎完全由 \
                大的那个决定。这不是「不够优」—— 这是在**回答另一个问题**。生效的缩放方式记录在 \
                结果里。
                """),
            .heading("选簇的个数"),
            .bullets([
                "**轮廓系数** —— 分数越高，簇分得越开。在大表上它会**抽样**（等距抽，而不是取前 2000 行），并且结果会声明自己是估计值。",
                "**肘部法** —— 画出簇内平方和随 k 的变化。这是一种**读图的方法**，不是优化：那个量随 k 增大必然下降，所以统计上并不存在「最优 k」。",
            ]),
            .note("""
                对 DBSCAN，**k-距离**图有助于挑半径：曲线的拐点通常是个合理的起点。
                """),
            .seeAlso(["tim-bat-thuong", "quy-trinh-khai-pha"]),
        ]
    )

    static let forecasting = HelpTopic(
        id: "du-bao",
        title: "时间序列预测",
        summary: "趋势与季节分解、Holt-Winters，以及始终并排跑着的基线。",
        keywords: ["预测", "时间序列", "季节性", "holt-winters", "趋势"],
        commands: ["CSV: dự báo chuỗi thời gian…"],
        blocks: [
            .paragraph("""
                选一个时间列和一个数值列。GEditor 把序列分解为**趋势 · 季节 · 残差**，再用 \
                Holt-Winters（加法或乘法）预测，给出 80% 和 95% 的区间。
                """),
            .heading("基线始终在跑，而且它会直说谁赢了"),
            .paragraph("""
                在模型之外，GEditor 还跑两种朴素方法：*取上一期*和*取上个季节的同期*。如果模型 \
                **输给**了某个基线，这句话会出现在**第一行，并用不同的颜色** —— 而不是压在一堆 \
                数字底下。
                """),
            .paragraph("""
                理由是：预测工具往往把模型呈现为事实，而用户无从得知「直接拿上个月的数」原本会 \
                更准。
                """),
            .heading("GEditor 会拒绝、或自我声明的三处"),
            .bullets([
                "**不足两个完整周期时退回朴素方法。** 拿单个周期的噪声去拟合季节性、再重复到未来，会产出一份非常有说服力、却完全是编出来的预测。",
                "**MAPE 遇到零会说明**，而如果超过 25% 的期为零，它会**扣下这个指标** —— 悄悄跳过它们，等于在一个系统性有偏的子集上算出一个数字。",
                "**置信区间会声明自己是近似的**，并说明它在长期上扩张得太慢。",
            ]),
            .note("""
                季节周期是在**一阶差分**上识别的，不是在原序列上：趋势会让每一个滞后都高度相关， \
                把季节的尖峰淹没掉。
                """),
            .seeAlso(["khai-pha-theo-nhom", "quy-trinh-khai-pha"]),
        ]
    )

    static let associationRules = HelpTopic(
        id: "luat-ket-hop",
        title: "关联规则",
        summary: "买了 A 常常也买 B —— 以及为什么表是按提升度而不是置信度排序的。",
        keywords: ["apriori", "关联规则", "购物篮", "提升度", "支持度"],
        commands: ["CSV: luật kết hợp…"],
        blocks: [
            .paragraph("接受两种数据形状："),
            .bullets([
                "**一行一个篮子** —— 某一列里装着商品清单。",
                "**两列** —— 交易号和商品，一行一件。",
            ]),
            .table(
                headers: ["指标", "含义"],
                rows: [
                    ["支持度 support", "同时包含两边的篮子占比"],
                    ["置信度 confidence", "在含左边的篮子里，有多大比例也含右边"],
                    ["**提升度 lift**", "置信度除以右边的基础比率"],
                    ["杠杆率 leverage", "与「相互独立」所预测值之间的差距"],
                ]
            ),
            .heading("按提升度排序，而不是置信度"),
            .paragraph("""
                如果右边本来就出现在 95% 的篮子里，那么指向它的**每一条**规则置信度都在 95% \
                左右 —— 却什么也没说明。按置信度排序，恰好把最没有意义的规则顶到最上面。
                """),
            .warning("""
                `lift < 1` 会**在那一行里标出来**：指向一个基础比率 95% 的东西却只有 80% 置信度， \
                意味着**反向**关系 —— 一个正确的数字导向一个错误的结论。
                """),
            .bullets([
                "买两盒牛奶仍然是**一笔**含牛奶的交易：篮子内的重复会被去掉，否则支持度会随数量虚高。",
                "支持度阈值设得太低会让候选集组合爆炸；触到上限时，GEditor 会**停下来并说明这张表不完整**。",
            ]),
            .seeAlso(["quy-trinh-khai-pha"]),
        ]
    )

    static let groupMining = HelpTopic(
        id: "khai-pha-theo-nhom",
        title: "分组挖掘",
        summary: "按组独立重跑分析 —— 最常推翻结论的一步。",
        keywords: ["分组", "逐组", "辛普森悖论", "分店", "组间比较"],
        commands: ["CSV: khai phá theo nhóm…"],
        blocks: [
            .paragraph("""
                选一个文本列作分组键。每个组都**完全独立地**跑一遍异常、预测和相关，然后按您 \
                挑的标准排序。
                """),
            .heading("为什么组必须分开，而不能合并"),
            .paragraph("""
                两家分店，一家在 10 上下，一家在 100 上下。在**合并**表上算出的离群围栏落在 \
                ±135 左右 —— 而它在**两个方向上都会出错**：
                """),
            .bullets([
                "**漏报**：20 这个值对小店来说明显反常，却稳稳落在共用围栏之内。组越多，它越瞎。",
                "**误报**：一个分散很广的组，其正常的尾巴被共用围栏切掉，于是一大片普通的行被标了出来。",
            ]),
            .heading("「相关背离」那一列抓的是辛普森悖论"),
            .paragraph("""
                三个组，**每一组**内两列的相关都是 `−1`，合起来却是 `> 0.9`。只读合并表的人会 \
                得出**完全相反**的结论。这一列指的正是这类情形。
                """),
            .note("""
                面板只把**文本列**作为可选的分组键，并在 1000 组处带警告停下 —— 免得有人挑了 \
                订单号那一列，把每一行都变成一个自己的组。
                """),
            .seeAlso(["tim-bat-thuong", "ma-tran-tuong-quan", "du-bao", "khoi-mining"]),
        ]
    )

    static let textMining = HelpTopic(
        id: "khai-pha-van-ban",
        title: "文本挖掘",
        summary: "在一列文本上做 n-gram 与 TF-IDF —— 找出有特征的短语。",
        keywords: ["文本挖掘", "n-gram", "tf-idf", "关键词", "短语"],
        commands: ["Khai phá văn bản (n-gram, TF-IDF)"],
        blocks: [
            .paragraph("""
                在一列文本上运行 —— 商品描述、客户反馈、备注字段。
                """),
            .bullets([
                "**n-gram** —— 最高频的 1 词、2 词和 3 词短语。",
                "**TF-IDF** —— 各文档组**有特征**的词，也就是在这里频繁而在别处罕见的词。",
            ]),
            .paragraph("""
                区别在于：n-gram 告诉您*「客户反复提到什么」*，TF-IDF 告诉您*「这一组与其他组 \
                有什么不同」*。
                """),
            .seeAlso(["quy-trinh-khai-pha", "danh-dau-entity"]),
        ]
    )
}
