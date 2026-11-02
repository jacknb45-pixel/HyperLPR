#import "@preview/cetz:0.3.4": canvas, draw

#set page(width: auto, height: auto, margin: 0.4cm)
#set text(font: ("SimSun", "Source Han Serif SC"), size: 10pt)

#let band(x, y, w, h, title) = {
  import draw: *
  rect((x, y), (rel: (w, h)), radius: 2pt, fill: rgb("#f8f9fa"), stroke: 0.6pt + rgb("#333333"))
  content((x + 0.25, y + h - 0.40), text(size: 8.4pt, weight: "bold", fill: rgb("#333333"))[#title],
    anchor: "west")
}

#let fnode(x, y, w, name, sub) = {
  import draw: *
  rect((x, y), (rel: (w, 0.92)), radius: 2pt, fill: white, stroke: 0.6pt + rgb("#333333"))
  content((x + w / 2, y + 0.60), text(size: 7.4pt, weight: "bold", fill: rgb("#1a1a1a"))[#name])
  content((x + w / 2, y + 0.25), text(size: 6.2pt, fill: rgb("#555550"))[#sub])
}

#align(center)[
  #text(size: 12.5pt, weight: "bold")[HyperLPR 源码模块结构]
]

#align(center)[
  #canvas({
    import draw: *
    let note(x, y, s) = content((x, y), text(size: 6.8pt, fill: rgb("#555550"))[#s], anchor: "west")

    // ============ 最外层总模块：HyperLPR 核心包 ============
    rect((0, 1.6), (rel: (14.8, 12.1)), radius: 3pt, fill: white, stroke: 0.9pt + rgb("#222222"))
    content((0.35, 13.28), anchor: "west",
      text(size: 9pt, weight: "bold", fill: rgb("#1a1a1a"))[
        HyperLPR　·　Python 核心包（Prj-Python/hyperlpr3）
      ])

    // ============ 子模块 1：接口层 ============
    band(0.4, 10.65, 14.0, 2.0, "接口层　对外入口：Python API / CLI / Web 服务")
    fnode(0.75, 10.90, 2.7, "hyperlpr3.py", "顶层 · SDK 入口")
    fnode(3.65, 10.90, 2.6, "cli.py", "command/ · 命令行")
    fnode(6.45, 10.90, 2.8, "serve.py", "command/ · Web 服务")
    note(9.55, 11.55, "LicensePlateCatcher.__call__() 统一入口")
    note(9.55, 11.15, "启动期读配置、构造算子并注入 pipeline")

    // ============ 子模块 2：编排层 ============
    band(0.4, 8.35, 14.0, 2.0, "编排层　流水线装配与张量流转")
    fnode(0.75, 8.60, 3.6, "pipeline.py", "inference/ · 流水线编排")
    note(4.75, 9.25, "LPRMultiTaskPipeline.run()：")
    note(4.75, 8.85, "四阶段顺序与执行位置写死于此（含 Stage 2 对齐），是后续解耦的目标")

    // ============ 子模块 3：算子层 ============
    band(0.4, 4.85, 14.0, 3.2, "算子层　深度学习推理算子（前处理 → ONNX 前向 → 后处理）")
    fnode(0.75, 6.27, 3.5, "multitask_detect.py", "inference/ · Stage 1 检测")
    fnode(4.45, 6.27, 2.9, "detect.py", "inference/ · 备用检测")
    fnode(7.55, 6.27, 2.5, "vertex.py", "inference/ · 备用角点")
    note(10.3, 6.87, "detect.py / vertex.py 仅供备用")
    note(10.3, 6.47, "管线 LPRPipeline，主路径未用")
    fnode(0.75, 5.10, 3.5, "recognition.py", "inference/ · Stage 3 识别")
    fnode(4.45, 5.10, 3.4, "classification.py", "inference/ · Stage 4 分类")
    note(8.15, 5.70, "均继承 base/base.py（HamburgerABC），")
    note(8.15, 5.30, "统一 __call__ → _run_session 算子接口")

    // ============ 子模块 4 & 5：数据层与配置层（平级支撑） ============
    band(0.4, 1.95, 8.2, 2.6, "数据层　数据与几何支撑")
    fnode(0.75, 2.62, 2.85, "tools_process.py", "common/ · 几何与后处理")
    fnode(3.75, 2.62, 2.2, "typedef.py", "common/ · 类型定义")
    fnode(6.10, 2.62, 2.15, "tokenize.py", "common/ · 词表")
    note(0.75, 2.28, "Stage 2 透视对齐 / 规则过滤 / NMS / letterbox（无 config 依赖）")

    band(8.9, 1.95, 5.5, 2.6, "配置层　配置与模型管理")
    fnode(9.15, 2.62, 2.35, "settings.py", "config/ · 路径常量")
    fnode(11.65, 2.62, 2.55, "configuration.py", "config/ · 模型初始化")
    note(9.15, 2.28, "模型路径与参数，启动期由 hyperlpr3.py 读取")
  })
]
