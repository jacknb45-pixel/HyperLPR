#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: auto, height: auto, margin: 0.4cm)
#set text(font: ("SimSun", "Source Han Serif SC"), size: 10pt)

#let band(x, y, w, h, title, fillc, strokec, textc) = {
  import draw: *
  rect((x, y), (rel: (w, h)), radius: 7pt, fill: fillc, stroke: 0.5pt + strokec)
  // west 锚点：文字从框内左缘起排，不再以锚点为中心向左溢出色带（与 dataflow.typ 修法一致）
  content((x + 0.2, y + h - 0.38), text(size: 8.4pt, weight: "bold", fill: textc)[#title],
    anchor: "west")
}

#let fnode(x, y, w, name, path, fillc, strokec, textc) = {
  import draw: *
  rect((x, y), (rel: (w, 0.92)), radius: 3pt, fill: fillc, stroke: 0.5pt + strokec)
  content((x + w / 2, y + 0.60), text(size: 7.2pt, weight: "bold", fill: textc)[#name])
  content((x + w / 2, y + 0.26), text(size: 6.2pt, fill: textc.lighten(28%))[#path])
}

#align(center)[
  #text(size: 12.5pt, weight: "bold")[HyperLPR 源码模块结构（Module-to-File 分配视图）]
]

#v(0.1cm)

#align(center)[
  #canvas({
    import draw: *
    let note(x, y, s, c) = content((x, y), text(size: 6.8pt, fill: c)[#s])

    // ============ 左侧：原库分层 ============
    band(0.4, 11.5, 14.0, 1.7, "接口层　对外入口：Python API / CLI / Web 服务",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 11.75, 2.6, "hyperlpr3.py", "顶层 · 40 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    fnode(3.55, 11.75, 2.6, "cli.py", "command/ · 20 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    fnode(6.35, 11.75, 2.8, "serve.py", "command/ · 130 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    note(12.0, 12.25, "run() 为唯一外部调用点", rgb("#666662"))

    band(0.4, 9.6, 14.0, 1.7, "编排层　流水线装配与张量流转",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 9.85, 3.6, "pipeline.py", "inference/ · 121 行", white, rgb("#afa9ec"), rgb("#3c3489"))
    note(8.1, 10.42, "LPRMultiTaskPipeline：四阶段写死为顺序执行", rgb("#666662"))
    note(8.1, 10.04, "原实现无法切分 —— 本课题的解耦对象", rgb("#993c1d"))

    band(0.4, 6.6, 14.0, 2.8, "算子层　深度学习推理算子（前处理 → ONNX 前向 → 后处理）",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 7.75, 3.5, "multitask_detect.py", "inference/ · 184 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(4.45, 7.75, 2.9, "detect.py", "inference/ · 200 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(7.55, 7.75, 2.5, "vertex.py", "inference/ · 83 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(0.75, 6.72, 3.5, "recognition.py", "inference/ · 233 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(4.45, 6.72, 3.4, "classification.py", "inference/ · 49 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    note(12.3, 8.25, "Stage 1/3/4 · AI 推理算子", rgb("#666662"))
    note(12.1, 6.95, "三者均为 AI 推理算子", rgb("#666662"))

    band(0.4, 4.7, 14.0, 1.7, "数据层　几何变换与数据结构（Stage 2 对齐在此，非 AI）",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 4.95, 3.5, "tools_process.py", "common/ · 304 行", white, rgb("#ba7517"), rgb("#854f0b"))
    fnode(4.45, 4.95, 2.8, "typedef.py", "common/ · 82 行", white, rgb("#ba7517"), rgb("#854f0b"))
    fnode(7.45, 4.95, 2.5, "tokenize.py", "common/ · 4 行", white, rgb("#ba7517"), rgb("#854f0b"))
    note(12.3, 5.4, "透视变换产出 48×160 切片", rgb("#666662"))

    band(0.4, 2.8, 14.0, 1.7, "配置层　模型路径与运行时参数",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 3.05, 3.0, "settings.py", "config/ · 22 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    fnode(3.95, 3.05, 3.4, "configuration.py", "config/ · 63 行", white, rgb("#85b7eb"), rgb("#0c447c"))

    // 层间调用箭头
    line((7.4, 11.5), (7.4, 11.3), mark: (end: ">", size: 0.13pt), stroke: 0.8pt)
    line((7.4, 9.6), (7.4, 9.4), mark: (end: ">", size: 0.13pt), stroke: 0.8pt)
    line((7.4, 6.6), (7.4, 6.4), mark: (end: ">", size: 0.13pt), stroke: 0.8pt)
    line((7.4, 4.7), (7.4, 4.5), mark: (end: ">", size: 0.13pt), stroke: 0.8pt)

    // 底部说明
    content((7.4, 1.95), text(size: 8pt, fill: rgb("#444441"))[
      HyperLPR 原库 1697 行源码的模块分解（层 → 模块 → 文件 → 行数）。
    ])
    content((7.4, 1.45), text(size: 8pt, fill: rgb("#444441"))[
      四阶段写死在 LPRMultiTaskPipeline.run() 内，无可插拔接缝 —— 这是后续解耦的对象。
    ])
  })
]
