#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: auto, height: auto, margin: 0.4cm)
#set text(font: ("SimSun", "Source Han Serif SC"), size: 10pt)

// 注：fillc / strokec / textc 三个参数保留以兼容既有调用点，实际配色统一为黑白灰工程风
#let band(x, y, w, h, title, fillc, strokec, textc) = {
  import draw: *
  rect((x, y), (rel: (w, h)), radius: 2pt, fill: rgb("#f8f9fa"), stroke: 0.6pt + rgb("#333333"))
  // west 锚点：文字从框内左缘起排（与 dataflow.typ 修法一致）
  // 层带内纵向节奏：顶留白 0.25 → 标题行 → 留白 0.30 → 节点行 → 底留白 0.25
  content((x + 0.2, y + h - 0.42), text(size: 8.4pt, weight: "bold", fill: rgb("#333333"))[#title],
    anchor: "west")
}

#let fnode(x, y, w, name, path, fillc, strokec, textc) = {
  import draw: *
  rect((x, y), (rel: (w, 0.92)), radius: 2pt, fill: white, stroke: 0.6pt + rgb("#333333"))
  content((x + w / 2, y + 0.60), text(size: 7.2pt, weight: "bold", fill: rgb("#1a1a1a"))[#name])
  content((x + w / 2, y + 0.26), text(size: 6.2pt, fill: rgb("#555550"))[#path])
}

#align(center)[
  #text(size: 12.5pt, weight: "bold")[HyperLPR 源码模块结构（Module-to-File 分配视图）]
]

// 层内右侧注记：统一 west 锚点、统一 x 列，保证各层注记左对齐

#align(center)[
  #canvas({
    import draw: *
    // 层内右侧注记：统一 west 锚点、统一 x 列，保证各层注记左对齐
    let note(x, y, s) = content((x, y), text(size: 6.8pt, fill: rgb("#666662"))[#s], anchor: "west")

    // ============ 自上而下：接口 → 编排 → 算子 → 数据 → 配置 ============
    // 层带高：单行层 2.0，双行层（算子）3.2；层间垂直间隙统一 0.5 供调用箭头使用

    // 接口层
    band(0.4, 12.3, 14.0, 2.0, "接口层　对外入口：Python API / CLI / Web 服务",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 12.55, 2.6, "hyperlpr3.py", "顶层 · 40 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    fnode(3.55, 12.55, 2.6, "cli.py", "command/ · 20 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    fnode(6.35, 12.55, 2.8, "serve.py", "command/ · 130 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    note(9.6, 13.01, "run() 为唯一外部调用点")

    // 编排层
    band(0.4, 9.8, 14.0, 2.0, "编排层　流水线装配与张量流转",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 10.05, 3.6, "pipeline.py", "inference/ · 121 行", white, rgb("#afa9ec"), rgb("#3c3489"))
    note(9.6, 10.67, "LPRMultiTaskPipeline.run()")
    note(9.6, 10.29, "顺序与执行位置写死 · 解耦对象")

    // 算子层（双行：检测 / 识别与分类）
    band(0.4, 6.1, 14.0, 3.2, "算子层　深度学习推理算子（前处理 → ONNX 前向 → 后处理）",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 7.52, 3.5, "multitask_detect.py", "inference/ · 184 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(4.45, 7.52, 2.9, "detect.py", "inference/ · 200 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(7.55, 7.52, 2.5, "vertex.py", "inference/ · 83 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(0.75, 6.35, 3.5, "recognition.py", "inference/ · 233 行", white, rgb("#5dc9a0"), rgb("#0f5132"))
    fnode(4.45, 6.35, 3.4, "classification.py", "inference/ · 49 行", white, rgb("#5dc9a0"), rgb("#0f5132"))

    // 数据层
    band(0.4, 3.6, 14.0, 2.0, "数据层　几何变换与数据结构（Stage 2 对齐在此，非 AI）",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 3.85, 3.5, "tools_process.py", "common/ · 304 行", white, rgb("#ba7517"), rgb("#854f0b"))
    fnode(4.45, 3.85, 2.8, "typedef.py", "common/ · 82 行", white, rgb("#ba7517"), rgb("#854f0b"))
    fnode(7.45, 3.85, 2.0, "tokenize.py", "common/ · 4 行", white, rgb("#ba7517"), rgb("#854f0b"))
    note(9.6, 4.31, "透视变换产出 48×160 切片")

    // 配置层
    band(0.4, 1.1, 14.0, 2.0, "配置层　模型路径与运行时参数",
      rgb("#f1efe8"), rgb("#b4b2a9"), rgb("#444441"))
    fnode(0.75, 1.35, 3.0, "settings.py", "config/ · 22 行", white, rgb("#85b7eb"), rgb("#0c447c"))
    fnode(3.95, 1.35, 3.4, "configuration.py", "config/ · 63 行", white, rgb("#85b7eb"), rgb("#0c447c"))

    // 层间调用箭头（上层调用下层，向下）
    line((7.4, 12.3), (7.4, 11.8), mark: (end: ">", size: 0.15pt), stroke: 0.8pt)
    line((7.4, 9.8), (7.4, 9.3), mark: (end: ">", size: 0.15pt), stroke: 0.8pt)
    line((7.4, 6.1), (7.4, 5.6), mark: (end: ">", size: 0.15pt), stroke: 0.8pt)
    line((7.4, 3.6), (7.4, 3.1), mark: (end: ">", size: 0.15pt), stroke: 0.8pt)

    // 底部说明
    content((7.4, 0.55), text(size: 8pt, fill: rgb("#444441"))[
      HyperLPR 原库 1697 行源码的模块分解（层 → 文件 → 行数）。
    ])
    content((7.4, 0.05), text(size: 8pt, fill: rgb("#444441"))[
      四阶段顺序与执行位置写死于 LPRMultiTaskPipeline.run()，算子可独立调用、无可重分配的执行位置。
    ])
  })
]
