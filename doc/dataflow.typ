#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: 20cm, height: 12.5cm, margin: 1.2cm)
#set text(font: ("SimSun", "Source Han Serif SC"), size: 10pt)

#let node(x, y, w, title, sub) = {
  import draw: *
  rect((x, y), (rel: (w, 1.4)), radius: 2pt, fill: white, stroke: 0.6pt + rgb("#333333"))
  content((x + w / 2, y + 0.92), text(size: 9pt, weight: "bold", fill: rgb("#1a1a1a"))[#title])
  content((x + w / 2, y + 0.48), text(size: 7.5pt, fill: rgb("#555550"))[#sub])
}

#let band(x, y, w, h, title) = {
  import draw: *
  rect((x, y), (rel: (w, h)), radius: 2pt, fill: rgb("#f8f9fa"), stroke: 0.6pt + rgb("#333333"))
  // 标题单独占用色带顶部一行，避免与节点重叠；north-west 锚点保证从框内左上角起排
  content((x + 0.25, y + h - 0.35), text(size: 8.5pt, weight: "bold", fill: rgb("#333333"))[#title],
    anchor: "north-west")
}

#align(center)[
  #text(size: 13pt, weight: "bold")[HyperLPR 推理流水线数据流与候选切分点]
]

#align(center)[
  #canvas({
    import draw: *

    // 端侧
    band(0, 6.6, 16.6, 3.2, "端侧 Mobile　·　Device Tier")
    node(0.25, 7.0, 2.5, "输入原图", "数百 KB \~ 2 MB")
    node(3.15, 7.0, 3.0, "Stage 1 目标定位", "68.00 ms · 占 48%")
    node(6.55, 7.0, 2.0, "四角点", "8 floats")
    node(8.95, 7.0, 2.7, "Stage 2 几何对齐", "0.88 ms · 占 0.6%")
    node(12.05, 7.0, 3.1, "车牌切片", "48×160 · 5.8\~12.7 KB")

    line((2.75, 7.7), (3.15, 7.7), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((6.15, 7.7), (6.55, 7.7), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((8.55, 7.7), (8.95, 7.7), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((11.65, 7.7), (12.05, 7.7), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)

    // 切分面：贯穿端云的不连续点（Stage 2 之后、Stage 3 之前）
    line((0, 5.95), (16.6, 5.95),
      stroke: (paint: rgb("#333333"), thickness: 1pt, dash: "dashed"))
    content((0.15, 6.25), anchor: "west",
      text(size: 8pt, weight: "bold", fill: rgb("#333333"))[
        切分面 Cut Plane　·　跨面载荷 5.81\~12.73 KB（较原图削减 98.5%\~99.4%）
      ])

    // 切片上传：垂直穿过切分面
    line((13.6, 7.0), (13.6, 5.45), (1.8, 5.45), (1.8, 2.3),
      mark: (end: ">", size: 0.16pt),
      stroke: (paint: rgb("#333333"), thickness: 0.9pt, dash: "dashed"))

    // 云端
    band(0, 1.9, 15.2, 3.2, "云端 Server　·　Cloud Tier")
    node(0.25, 2.3, 3.1, "接收切片", "JPEG 字节流")
    node(3.75, 2.3, 3.2, "Stage 3 字符识别", "70.08 ms · 占 49.5%")
    node(7.35, 2.3, 3.0, "Stage 4 属性分类", "2.53 ms · 占 1.8%")
    node(10.75, 2.3, 4.2, "车牌号 + 类型 + 置信度", "JSON 回传")

    line((3.35, 3.0), (3.75, 3.0), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((6.95, 3.0), (7.35, 3.0), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
    line((10.35, 3.0), (10.75, 3.0), mark: (end: ">", size: 0.14pt), stroke: 0.8pt)
  })
]
