#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: 20cm, height: auto, margin: 1.2cm)
#set text(font: ("SimSun", "Source Han Serif SC"), size: 10pt)

// 节点：框内上下留白 0.21，标题与副标题间隔 0.15
#let node(x, y, w, title, sub) = {
  import draw: *
  rect((x, y), (rel: (w, 1.15)), radius: 2pt, fill: white, stroke: 0.6pt + rgb("#333333"))
  content((x + w / 2, y + 0.78), text(size: 9pt, weight: "bold", fill: rgb("#1a1a1a"))[#title])
  content((x + w / 2, y + 0.34), text(size: 7.5pt, fill: rgb("#555550"))[#sub])
}

// 色带：上留白 0.25 → 标题行 → 0.25 → 节点 → 下留白 0.25；dx 控制标题左起点（默认 0.25）
#let band(x, y, w, h, title, dx: 0.25) = {
  import draw: *
  rect((x, y), (rel: (w, h)), radius: 2pt, fill: rgb("#f8f9fa"), stroke: 0.6pt + rgb("#333333"))
  // 标题贴色带顶部一行，north-west 锚点保证从框内左上角起排
  content((x + dx, y + h - 0.25), text(size: 8.5pt, weight: "bold", fill: rgb("#333333"))[#title],
    anchor: "north-west")
}

#align(center)[
  #text(size: 13pt, weight: "bold")[HyperLPR 推理流水线数据流与候选切分点]
]

#align(center + horizon)[
  #canvas({
    import draw: *

    // 端侧：自左向右，末端 JPEG 编码正对云端接收切片，上传线垂直穿面
    band(0, 6.8, 16.6, 2.2, "端侧 Mobile　·　Device Tier")
    node(0.25, 7.05, 2.3, "输入原图", "385 KB–2 MB")
    node(2.95, 7.05, 2.9, "Stage 1 目标定位", "68.00 ms · 占 48.1%")
    node(6.25, 7.05, 1.6, "四角点", "4×2 int")
    node(8.25, 7.05, 2.75, "Stage 2 几何对齐", "0.88 ms · 占 0.6%")
    node(11.4, 7.05, 2.4, "车牌切片", "尺寸随角点距离")
    node(14.2, 7.05, 2.15, "JPEG 编码", "q95 · 未计时")

    line((2.55, 7.63), (2.95, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((5.85, 7.63), (6.25, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((7.85, 7.63), (8.25, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((11.0, 7.63), (11.4, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((13.8, 7.63), (14.2, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)

    // 切分面：贯穿端云的不连续点（Stage 2 之后、Stage 3 之前）
    line((0, 5.95), (16.6, 5.95),
      stroke: (paint: rgb("#333333"), thickness: 1pt, dash: "dashed"))
    // 面标签放在回传线（x=6.0）与上传线（x=15.25）之间，避免与竖线相交
    content((6.3, 6.25), anchor: "west",
      text(size: 8pt, weight: "bold", fill: rgb("#333333"))[
        切分面 Cut Plane　·　5.81–12.73 KB（削减 98.5%–99.4%）
      ])
    // 跨面两条线的语义：上行切片 + Stage 1 元数据，下行识别结果
    content((15.05, 5.6), anchor: "east",
      text(size: 7pt, fill: rgb("#333333"))[上行：JPEG 切片 + layer 标志 / bbox 元数据])
    content((6.2, 5.6), anchor: "west",
      text(size: 7pt, fill: rgb("#333333"))[下行：JSON 结果])

    // 云端：入口正对端侧出口，故链自右向左展开
    band(0, 2.3, 16.6, 2.9, "云端 Server　·　Cloud Tier")
    node(14.2, 3.25, 2.15, "接收切片", "JPEG 字节流")
    node(10.75, 3.25, 3.05, "Stage 3 字符识别", "70.08 ms · 占 49.5%")
    node(6.55, 3.25, 3.8, "Stage 4 属性分类", "条件 · 2.53 ms · 1.8%")
    node(0.25, 3.25, 5.9, "车牌号 + 类型 + 置信度", "JSON 回传端侧")

    line((14.2, 3.83), (13.8, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    // Stage 3 → Stage 4 为条件触发（长度 ≥ 7 且规则判不出类型），用虚线区别于必经路径
    line((10.75, 3.83), (10.35, 3.83), mark: (end: ">", size: 0.14pt),
      stroke: (paint: rgb("#333333"), thickness: 0.8pt, dash: "dashed"))
    line((6.55, 3.83), (6.15, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    // 旁路：code_filter 规则已判出类型时，Stage 3 结果不经 Stage 4 直达
    line((12.3, 3.25), (12.3, 2.85), (4.2, 2.85), (4.2, 3.25),
      mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    content((8.45, 2.6), text(size: 7pt, fill: rgb("#555550"))[
      旁路：code_filter 规则判出类型时直达，不经 Stage 4
    ])

    // 底部注记：走线方向与计时口径
    content((0.15, 1.85), anchor: "west", text(size: 7pt, fill: rgb("#555550"))[
      端侧链自左向右、云端链自右向左；JPEG 编码与网络传输耗时未计入四阶段计时；\
      Stage 4 仅在识别长度 ≥ 7 且规则判不出类型时触发（虚线），2.53 ms 系强制调用分类器测得；长度 \< 7 的结果直接丢弃。
    ])

    // 跨面两条竖线画在最后，以免被色带覆盖
    // 上行：切片垂直穿过切分面
    line((15.25, 7.05), (15.25, 4.4),
      mark: (end: ">", size: 0.2pt),
      stroke: (paint: rgb("#333333"), thickness: 0.9pt))
    // 下行：结果回传端侧
    line((6.0, 4.4), (6.0, 6.8),
      mark: (end: ">", size: 0.2pt),
      stroke: (paint: rgb("#333333"), thickness: 0.9pt))
  })
]
