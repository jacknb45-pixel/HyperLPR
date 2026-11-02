#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: 20cm, height: 10.4cm, margin: 1.2cm)
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
    node(0.25, 7.05, 2.4, "输入原图", "数百 KB ~ 2 MB")
    node(3.05, 7.05, 2.8, "Stage 1 目标定位", "68.00 ms · 占 48%")
    node(6.25, 7.05, 1.6, "四角点", "8 floats")
    node(8.25, 7.05, 2.6, "Stage 2 几何对齐", "0.88 ms · 占 0.6%")
    node(11.25, 7.05, 2.5, "车牌切片", "尺寸随角点距离")
    node(14.15, 7.05, 2.2, "JPEG 编码", "q95 · 未计时")

    line((2.65, 7.63), (3.05, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((5.85, 7.63), (6.25, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((7.85, 7.63), (8.25, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((10.85, 7.63), (11.25, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((13.75, 7.63), (14.15, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)

    // 切分面：贯穿端云的不连续点（Stage 2 之后、Stage 3 之前）
    line((0, 5.95), (16.6, 5.95),
      stroke: (paint: rgb("#333333"), thickness: 1pt, dash: "dashed"))
    content((0.15, 6.25), anchor: "west",
      text(size: 8pt, weight: "bold", fill: rgb("#333333"))[
        切分面 Cut Plane　·　跨面载荷 5.81\~12.73 KB（较原图削减 98.5%\~99.4%）
      ])

    // 云端：入口正对端侧出口，故链自右向左展开
    band(0, 3.0, 16.6, 2.2, "云端 Server　·　Cloud Tier")
    node(14.15, 3.25, 2.2, "接收切片", "JPEG 字节流")
    node(10.75, 3.25, 3.0, "Stage 3 字符识别", "70.08 ms · 占 49.5%")
    node(6.35, 3.25, 3.4, "Stage 4 属性分类", "条件触发 · 2.53 ms")
    node(0.25, 3.25, 5.7, "车牌号 + 类型 + 置信度", "JSON 回传端侧")

    line((14.15, 3.83), (13.75, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    // Stage 3 → Stage 4 为条件触发（长度 ≥ 7 且规则判不出类型）：间隙加宽到 1.0cm
    // 并用密集虚线，避免短线看不出虚线特征
    line((10.75, 3.83), (9.75, 3.83), mark: (end: ">", size: 0.14pt),
      stroke: (paint: rgb("#333333"), thickness: 0.8pt, dash: "densely-dashed"))
    line((6.35, 3.83), (5.95, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)

    // 底部注记：走线方向与计时口径
    content((0.15, 2.6), anchor: "west", text(size: 7pt, fill: rgb("#555550"))[
      端侧链自左向右、云端链自右向左；JPEG 编码与网络传输耗时未计入四阶段计时；\
      Stage 4 为条件触发，2.53 ms 系强制调用分类器测得。
    ])

    // 切片上传：垂直穿过切分面，带空心箭头（画在最后以免被色带覆盖）
    line((15.25, 7.05), (15.25, 4.4),
      mark: (end: ">", size: 0.2pt),
      stroke: (paint: rgb("#333333"), thickness: 0.9pt))
  })
]
