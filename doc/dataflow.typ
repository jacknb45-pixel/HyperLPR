#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: 20cm, height: 11cm, margin: 1.2cm)
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

    // 端侧
    band(0, 6.8, 16.6, 2.2, "端侧 Mobile　·　Device Tier")
    node(0.25, 7.05, 2.5, "输入原图", "数百 KB ~ 2 MB")
    node(3.15, 7.05, 3.0, "Stage 1 目标定位", "68.00 ms · 占 48%")
    node(6.55, 7.05, 2.0, "四角点", "8 floats")
    node(8.95, 7.05, 2.7, "Stage 2 几何对齐", "0.88 ms · 占 0.6%")
    node(12.05, 7.05, 3.1, "车牌切片", "48×160 · 5.8~12.7 KB")

    line((2.75, 7.63), (3.15, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((6.15, 7.63), (6.55, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((8.55, 7.63), (8.95, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((11.65, 7.63), (12.05, 7.63), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)

    // 切分面：贯穿端云的不连续点（Stage 2 之后、Stage 3 之前）
    line((0, 5.95), (16.6, 5.95),
      stroke: (paint: rgb("#333333"), thickness: 1pt, dash: "dashed"))
    content((0.15, 6.25), anchor: "west",
      text(size: 8pt, weight: "bold", fill: rgb("#333333"))[
        切分面 Cut Plane　·　跨面载荷 5.81\~12.73 KB（较原图削减 98.5%\~99.4%）
      ])

    // 云端（标题右移，给上传线让出进入路径）
    band(0, 3.0, 15.2, 2.2, "云端 Server　·　Cloud Tier", dx: 2.6)
    node(0.25, 3.25, 3.1, "接收切片", "JPEG 字节流")
    node(3.75, 3.25, 3.2, "Stage 3 字符识别", "70.08 ms · 占 49.5%")
    node(7.35, 3.25, 3.0, "Stage 4 属性分类", "2.53 ms · 占 1.8%")
    node(10.75, 3.25, 4.2, "车牌号 + 类型 + 置信度", "JSON 回传")

    line((3.35, 3.83), (3.75, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((6.95, 3.83), (7.35, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((10.35, 3.83), (10.75, 3.83), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)

    // 切片上传：垂直穿过切分面，带空心箭头落至云端首节点上沿
    // （画在最后，避免被后绘制的云端色带覆盖）
    line((13.6, 7.05), (13.6, 5.6), (1.8, 5.6), (1.8, 4.4),
      mark: (end: ">", size: 0.2pt),
      stroke: (paint: rgb("#333333"), thickness: 0.9pt))
  })
]
