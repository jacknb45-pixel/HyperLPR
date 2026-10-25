#import "@preview/cetz:0.3.4"

// --- 全局页面配置 ---
#set page(
  paper: "a4",
  flipped: true,
  margin: (x: 1.2cm, top: 1.0cm, bottom: 1.0cm),
  header: context {
    let page-num = counter(page).get().first()
    text(size: 8pt, fill: rgb("#94a3b8"))[
      #grid(
        columns: (1fr, 1fr),
        align(left)[HyperLPR 车牌识别系统 · 软件体系结构设计规范],
        align(right)[第 #page-num 页]
      )
      #v(-3pt)
      #line(length: 100%, stroke: 0.5pt + rgb("#e2e8f0"))
    ]
  }
)

#set text(
  font: ("Microsoft YaHei", "Noto Sans SC", "SimSun", "SimHei"),
  size: 9pt,
  fill: rgb("#1e293b")
)

// --- 样式函数定义 ---
#let layer-block(
  num: "",
  title: "",
  en-title: "",
  desc: "",
  accent-col: rgb("#3b82f6"),
  body
) = {
  block(
    width: 100%,
    stroke: 1.2pt + accent-col.lighten(30%),
    fill: accent-col.lighten(94%),
    radius: 6pt,
    inset: (x: 8pt, y: 6pt),
    spacing: 0pt,
    [
      #grid(
        columns: (170pt, 1fr),
        gutter: 10pt,
        align: (left + horizon, left + horizon),
        [
          #box[
            #text(weight: "bold", size: 10pt, fill: accent-col.darken(25%))[#num #title]\
            #v(1pt)
            #text(size: 7.5pt, weight: "bold", fill: accent-col.darken(10%))[#en-title]\
            #v(2pt)
            #text(size: 7pt, fill: rgb("#64748b"))[#desc]
          ]
        ],
        body
      )
    ]
  )
}

#let sub-card(
  title: "",
  desc: "",
  code-path: "",
  accent-col: rgb("#3b82f6"),
  width: 100%
) = {
  block(
    width: width,
    stroke: 1pt + accent-col.lighten(20%),
    fill: rgb("#ffffff"),
    radius: 4pt,
    inset: (x: 6pt, y: 5pt),
    [
      #text(weight: "bold", size: 8.5pt, fill: accent-col.darken(35%))[#title]\
      #v(1.5pt)
      #text(size: 7.2pt, fill: rgb("#334155"))[#desc]\
      #v(2pt)
      #text(size: 6.8pt, font: "Consolas", fill: accent-col.darken(20%))[#raw(code-path)]
    ]
  )
}

// =========================================================================
// 第 1 页：系统全局分层软件架构图 (Hierarchical System Architecture)
// =========================================================================

#align(center)[
  #text(weight: "bold", size: 15pt, fill: rgb("#0f172a"))[HyperLPR 高性能车牌识别系统 · 全局分层软件架构图]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#64748b"))[Hierarchical Software Architecture Diagram · 模块解耦、管线编排与跨平台抽象]
]

#v(6pt)

#stack(
  spacing: 5pt,

  // Layer 1: 应用接入与接口层
  layer-block(
    num: "1.",
    title: "交互与应用接入层",
    en-title: "Application & Interface Layer",
    desc: "跨语言/多平台外部调用接口与服务入口",
    accent-col: rgb("#059669"),
    [
      #grid(
        columns: (1fr, 1fr, 1.1fr, 1fr, 1.2fr),
        gutter: 6pt,
        sub-card(
          title: "WebAPI 服务",
          desc: "FastAPI REST 在线接口与 Swagger 文档",
          code-path: "command/serve.py",
          accent-col: rgb("#059669")
        ),
        sub-card(
          title: "CLI 命令行工具",
          desc: "基于 Click 的图像/流样本快速评测",
          code-path: "command/sample.py",
          accent-col: rgb("#059669")
        ),
        sub-card(
          title: "Python SDK",
          desc: "Pip 包高层接口与上下文对象注入",
          code-path: "hyperlpr3/__init__.py",
          accent-col: rgb("#059669")
        ),
        sub-card(
          title: "Native C-API",
          desc: "跨平台导出的 C 原生动态库接口",
          code-path: "cpp/c_api/hyper_lpr_sdk.h",
          accent-col: rgb("#059669")
        ),
        sub-card(
          title: "移动端嵌入式 SDK",
          desc: "Android JNI 桥接库与 iOS Framework",
          code-path: "platform/jni/android",
          accent-col: rgb("#059669")
        )
      )
    ]
  ),

  // Layer 2: 门面与控制调度层
  layer-block(
    num: "2.",
    title: "门面与控制调度层",
    en-title: "Facade & Orchestration Layer",
    desc: "屏蔽底层复杂性，管理上下文与任务生命周期",
    accent-col: rgb("#2563eb"),
    [
      #grid(
        columns: (1fr, 1fr),
        gutter: 8pt,
        sub-card(
          title: "Python 统一门面 (LicensePlateCatcher)",
          desc: "对外暴露统一 catch() / __call__() 高层推理接口，封装模型生命周期管理",
          code-path: "Prj-Python/hyperlpr3/hyperlpr3.py",
          accent-col: rgb("#2563eb")
        ),
        sub-card(
          title: "C++ 原生上下文句柄 (HyperLPRContext)",
          desc: "管理全局配置、多模型实例生命周期、内存生命期管理与多线程安全上下文调度",
          code-path: "cpp/src/context_module/hyper_lpr_context.h",
          accent-col: rgb("#2563eb")
        )
      )
    ]
  ),

  // Layer 3: 推理执行管线层
  layer-block(
    num: "3.",
    title: "推理执行管线流水线",
    en-title: "Inference Pipeline Engine",
    desc: "多任务检测、几何对齐、CTC 识别与属性分类",
    accent-col: rgb("#d97706"),
    [
      #stack(
        spacing: 4pt,
        block(
          width: 100%,
          stroke: 1pt + rgb("#f59e0b"),
          fill: rgb("#fef3c7"),
          radius: 3pt,
          inset: (x: 6pt, y: 3pt),
          align(center)[
            #text(weight: "bold", size: 8.5pt, fill: rgb("#92400e"))[管线调度中枢：LPRMultiTaskPipeline (串联级联 4 大推理阶段，统一数据流转)]
            #h(8pt)
            #text(size: 7.2pt, font: "Consolas", fill: rgb("#b45309"))[`inference/pipeline.py`]
          ]
        ),
        grid(
          columns: (1fr, 1fr, 1fr, 1fr),
          gutter: 6pt,
          sub-card(
            title: "Stage 1: 目标定位",
            desc: "MultiTaskDetectorORT / YOLO 输出边框与四顶点坐标",
            code-path: "multitask_detect.py",
            accent-col: rgb("#d97706")
          ),
          sub-card(
            title: "Stage 2: 几何对齐",
            desc: "tools_process 仿射与透视对齐裁剪 (黄金切分点: 9.75KB)",
            code-path: "tools_process.py",
            accent-col: rgb("#7c3aed")
          ),
          sub-card(
            title: "Stage 3: 字符识别",
            desc: "PPRCNNRecognitionORT 序列文字识别与 CTC 解码",
            code-path: "recognition.py",
            accent-col: rgb("#d97706")
          ),
          sub-card(
            title: "Stage 4: 属性分类",
            desc: "ClassificationORT 车牌底色与单双层类型分类",
            code-path: "classification.py",
            accent-col: rgb("#d97706")
          )
        )
      )
    ]
  ),

  // Layer 4: 推理引擎与加速后端
  layer-block(
    num: "4.",
    title: "推理后端与硬件适配层",
    en-title: "Inference Backend Abstraction",
    desc: "统一神经网络运行时抽象，屏蔽硬件差异",
    accent-col: rgb("#0284c7"),
    [
      #grid(
        columns: (1.2fr, 1fr, 1fr),
        gutter: 6pt,
        sub-card(
          title: "InferenceHelper (统一推理接口抽象)",
          desc: "定义 Tensor 预分配、模型加载、推理推断与结果后处理统一虚拟接口",
          code-path: "cpp/src/inference_helper_module",
          accent-col: rgb("#0284c7")
        ),
        sub-card(
          title: "ONNXRuntime 后端",
          desc: "支持 x86_64 / ARM / CUDA / DirectML 服务端与桌面端跨平台推理",
          code-path: "inference_helper_onnx.cpp",
          accent-col: rgb("#0284c7")
        ),
        sub-card(
          title: "MNN 移动轻量化后端",
          desc: "阿里巴巴轻量级推理引擎，针对 ARM NEON / GPU OpenCL 极致优化",
          code-path: "inference_helper_mnn.cpp",
          accent-col: rgb("#0284c7")
        )
      )
    ]
  ),

  // Layer 5: 基础支撑与配置管理层
  layer-block(
    num: "5.",
    title: "基础支撑与配置管理层",
    en-title: "Common Utilities & Platform",
    desc: "数据结构、词典编码、内存缓冲区与超参配置",
    accent-col: rgb("#475569"),
    [
      #grid(
        columns: (1.1fr, 1fr, 1.1fr, 1fr),
        gutter: 6pt,
        sub-card(
          title: "配置中心 (Config)",
          desc: "模型权重路径、NMS 阈值与图像输入尺寸设定",
          code-path: "configuration.py / settings.py",
          accent-col: rgb("#475569")
        ),
        sub-card(
          title: "类型定义 (Typedef)",
          desc: "Plate、PlateType、BoundingBox 结构体",
          code-path: "typedef.py / basic_types.h",
          accent-col: rgb("#475569")
        ),
        sub-card(
          title: "字符字典与解码 (Tokenize)",
          desc: "汉字/英文字典映射、CTC 贪心概率序列解码",
          code-path: "tokenize.py",
          accent-col: rgb("#475569")
        ),
        sub-card(
          title: "图像内存缓冲区 (Buffer)",
          desc: "跨平台 BGR / RGB / NV21 图像格式高速转换",
          code-path: "camera_buffer.h",
          accent-col: rgb("#475569")
        )
      )
    ]
  )
)

#pagebreak()

// =========================================================================
// 第 2 页：源码模块静态依赖与调用拓扑图 (Module Static Dependency DAG)
// =========================================================================

#align(center)[
  #text(weight: "bold", size: 15pt, fill: rgb("#0f172a"))[HyperLPR 源码子系统静态依赖与调用拓扑图]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#64748b"))[Source Module Static Dependency & Interaction Graph · 对齐 Module-to-File 设计期视角]
]

#v(8pt)

#align(center)[
#cetz.canvas({
  import cetz.draw: *

  // Container with clean top header
  let group-box(pos, size, name, title, subtitle, fill-col, stroke-col) = {
    rect(pos, (rel: size), name: name, fill: fill-col, stroke: 1.2pt + stroke-col.lighten(30%), radius: 7pt)
    rect(
      (rel: (0, -0.65), to: name + ".north-west"),
      (rel: (size.at(0), 0.65)),
      fill: stroke-col.lighten(88%),
      stroke: none,
      radius: (top: 7pt)
    )
    line(
      (rel: (0, -0.65), to: name + ".north-west"),
      (rel: (size.at(0), -0.65), to: name + ".north-west"),
      stroke: 1pt + stroke-col.lighten(30%)
    )
    content(
      (rel: (0.35, -0.325), to: name + ".north-west"),
      anchor: "west",
      [
        #text(weight: "bold", size: 9pt, fill: stroke-col.darken(25%))[#title]
        #h(6pt)
        #text(size: 7.5pt, fill: stroke-col.darken(10%))[#subtitle]
      ]
    )
  }

  // Component box inside container
  let comp-box(pos, size, name, title, desc, file, fill-col, stroke-col) = {
    rect(pos, (rel: size), name: name, fill: fill-col, stroke: 1.2pt + stroke-col, radius: 5pt)
    content(name, [
      #align(center)[
        #text(weight: "bold", size: 8.8pt, fill: stroke-col.darken(40%))[#title]\
        #v(2pt)
        #text(size: 7.2pt, fill: rgb("#334155"))[#desc]\
        #v(2pt)
        #text(size: 7pt, font: "Consolas", fill: stroke-col.darken(25%))[#raw(file)]
      ]
    ])
  }

  // 1. Facade Top
  group-box((-1.0, 10.8), (22.0, 2.9), "c_facade", "1. 门面入口层 (Facade Layer)", "统一外部交互接口与调度入口", rgb("#f0f7ff"), rgb("#1d4ed8"))
  comp-box((7.0, 11.2), (6.0, 1.7), "lpc", "LicensePlateCatcher", "统一门面入口 / 上下文调度器", "hyperlpr3.py", rgb("#eff6ff"), rgb("#2563eb"))

  // 2. Inference Pipeline Center
  group-box((-1.0, 3.8), (22.0, 6.2), "c_infer", "2. 推理执行管线 (Inference Engine & Pipeline)", "端到端车牌定位、对齐、识别与分类全流程级联", rgb("#fffdf5"), rgb("#b45309"))
  comp-box((7.0, 7.5), (6.0, 1.6), "pipe", "LPRMultiTaskPipeline", "推理任务编排与多算子级联流水线", "pipeline.py", rgb("#fef3c7"), rgb("#d97706"))

  comp-box((-0.5, 4.3), (4.8, 1.8), "det", "MultiTaskDetectorORT", "多任务 YOLO 目标定位与四角点", "multitask_detect.py", rgb("#fffbeb"), rgb("#f59e0b"))
  comp-box((4.8, 4.3), (4.5, 1.8), "proc", "tools_process", "仿射/透视变换与多点对齐裁剪", "tools_process.py", rgb("#fdf4ff"), rgb("#a855f7"))
  comp-box((9.8, 4.3), (4.8, 1.8), "rec", "PPRCNNRecognitionORT", "基于 CTC 的车牌字符序列识别", "recognition.py", rgb("#fffbeb"), rgb("#f59e0b"))
  comp-box((15.1, 4.3), (4.8, 1.8), "cls", "ClassificationORT", "车牌底色(蓝/绿/黄)与单双层分类", "classification.py", rgb("#fffbeb"), rgb("#f59e0b"))

  // 3. Common Tools (Left Bottom)
  group-box((-1.0, -1.0), (10.6, 4.0), "c_common", "3. 基础工具与算法 (Common Tools)", "", rgb("#faf5ff"), rgb("#6b21a8"))
  comp-box((-0.5, -0.4), (4.7, 1.8), "typedef", "typedef.py", "Plate / 车牌数据结构与状态定义", "typedef.py", rgb("#f3e8ff"), rgb("#9333ea"))
  comp-box((4.7, -0.4), (4.4, 1.8), "token", "tokenize.py", "字符映射字典与序列编解码", "tokenize.py", rgb("#f3e8ff"), rgb("#9333ea"))

  // 4. Config Bottom Right
  group-box((10.4, -1.0), (10.6, 4.0), "c_config", "4. 模型与超参配置 (Config & Settings)", "", rgb("#f8fafc"), rgb("#334155"))
  comp-box((11.0, -0.4), (9.4, 1.8), "cfg", "settings.py / configuration.py", "ONNX 模型权重路径、输入尺寸与 NMS 阈值参数", "settings.py / configuration.py", rgb("#f1f5f9"), rgb("#475569"))

  // Direct Invocations (Solid Lines)
  // LPC -> PIPE
  line("lpc.south", "pipe.north", mark: (end: ">", fill: rgb("#1d4ed8")), stroke: 1.6pt + rgb("#1d4ed8"))

  // PIPE -> DET, PROC, REC, CLS
  line((rel: (-2.2, 0), to: "pipe.south"), "det.north", mark: (end: ">", fill: rgb("#d97706")), stroke: 1.3pt + rgb("#d97706"))
  line((rel: (-0.8, 0), to: "pipe.south"), "proc.north", mark: (end: ">", fill: rgb("#d97706")), stroke: 1.3pt + rgb("#d97706"))
  line((rel: (0.8, 0), to: "pipe.south"), "rec.north", mark: (end: ">", fill: rgb("#d97706")), stroke: 1.3pt + rgb("#d97706"))
  line((rel: (2.2, 0), to: "pipe.south"), "cls.north", mark: (end: ">", fill: rgb("#d97706")), stroke: 1.3pt + rgb("#d97706"))

  // Dependencies (Dashed Lines) - Routed cleanly through vertical gaps & horizontal corridor
  // PIPE -> typedef (routed from pipe west through the det/proc gap)
  line((7.0, 8.0), (4.55, 8.0), (4.55, 3.5), (2.0, 3.5), "typedef.north", mark: (end: ">", fill: rgb("#9333ea")), stroke: (paint: rgb("#9333ea"), dash: "dashed", thickness: 1.1pt))

  // PROC -> typedef (routed down into corridor then to typedef)
  line("proc.south", (7.05, 3.5), (3.8, 3.5), "typedef.north-east", mark: (end: ">", fill: rgb("#9333ea")), stroke: (paint: rgb("#9333ea"), dash: "dashed", thickness: 1.1pt))

  // REC -> tokenize (routed from rec south-west down into token)
  line((9.8, 4.3), (7.5, 3.5), "token.north", mark: (end: ">", fill: rgb("#9333ea")), stroke: (paint: rgb("#9333ea"), dash: "dashed", thickness: 1.1pt))

  // REC & CLS -> CFG (direct vertical drops into config)
  line("rec.south", (12.2, 3.3), "cfg.north-west", mark: (end: ">", fill: rgb("#475569")), stroke: (paint: rgb("#475569"), dash: "dashed", thickness: 1.1pt))
  line("cls.south", (17.5, 3.3), "cfg.north-east", mark: (end: ">", fill: rgb("#475569")), stroke: (paint: rgb("#475569"), dash: "dashed", thickness: 1.1pt))

  // DET -> CFG (Clean orthogonal corridor routing along y = 3.3)
  line("det.south", (1.9, 3.3), (14.5, 3.3), "cfg.north", mark: (end: ">", fill: rgb("#475569")), stroke: (paint: rgb("#475569"), dash: "dashed", thickness: 1.1pt))

  // Legend at bottom
  let leg-y = -1.8
  rect((3.0, leg-y), (rel: (14.0, 0.65)), fill: rgb("#ffffff"), stroke: 0.8pt + rgb("#cbd5e1"), radius: 4pt)
  line((3.5, leg-y + 0.325), (4.7, leg-y + 0.325), stroke: 1.5pt + rgb("#d97706"), mark: (end: ">", fill: rgb("#d97706")))
  content((4.9, leg-y + 0.325), anchor: "west", [
    #text(size: 8pt, fill: rgb("#334155"))[控制/算子调用 (Direct Invocation)]
  ])
  line((9.5, leg-y + 0.325), (10.7, leg-y + 0.325), stroke: (paint: rgb("#64748b"), dash: "dashed", thickness: 1.2pt), mark: (end: ">", fill: rgb("#64748b")))
  content((10.9, leg-y + 0.325), anchor: "west", [
    #text(size: 8pt, fill: rgb("#334155"))[类型定义 / 配置参数依赖 (Dependency)]
  ])
})
]

#pagebreak()

// =========================================================================
// 第 3 页：端到端运行时数据流有向无环图与协同切分评测
// =========================================================================

#align(center)[
  #text(weight: "bold", size: 15pt, fill: rgb("#0f172a"))[HyperLPR 运行时数据流有向无环图 (Dataflow DAG) 与切分评测]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#64748b"))[Application Dataflow DAG Modeling & Cloud-Edge Collaborative Partitioning Point]
]

#v(8pt)

#align(center)[
#cetz.canvas({
  import cetz.draw: *

  let data-node(pos, size, name, title, sub1, sub2, is-golden: false) = {
    let fill-col = if is-golden { rgb("#fef3c7") } else { rgb("#f8fafc") }
    let stroke-col = if is-golden { rgb("#d97706") } else { rgb("#94a3b8") }
    let stroke-dash = if is-golden { "solid" } else { "dashed" }

    rect(
      pos, (rel: size),
      name: name,
      fill: fill-col,
      stroke: (paint: stroke-col, thickness: if is-golden { 1.6pt } else { 1.2pt }, dash: stroke-dash),
      radius: 6pt
    )
    content(name, [
      #align(center)[
        #text(weight: "bold", size: 9pt, fill: stroke-col.darken(30%))[#title]\
        #v(1.5pt)
        #text(size: 7.8pt, fill: rgb("#334155"))[#sub1]\
        #v(1pt)
        #text(size: 7.5pt, weight: if is-golden { "bold" } else { "regular" }, fill: if is-golden { rgb("#b45309") } else { rgb("#64748b") })[#sub2]
      ]
    ])
  }

  let proc-node(pos, size, name, title, sub1, time-pct, is-golden: false) = {
    let fill-col = if is-golden { rgb("#eff6ff") } else { rgb("#ffffff") }
    let stroke-col = if is-golden { rgb("#2563eb") } else { rgb("#3b82f6") }

    rect(
      pos, (rel: size),
      name: name,
      fill: fill-col,
      stroke: if is-golden { 2pt + stroke-col } else { 1.3pt + stroke-col },
      radius: 6pt
    )
    content(name, [
      #align(center)[
        #text(weight: "bold", size: 9pt, fill: stroke-col.darken(30%))[#title]\
        #v(1.5pt)
        #text(size: 7.8pt, fill: rgb("#475569"))[#sub1]\
        #v(1.5pt)
        #text(size: 7.8pt, weight: "bold", fill: rgb("#d97706"))[#time-pct]
      ]
    ])
  }

  // Horizontal layout for Dataflow DAG
  // 1. Input image
  data-node((0, 2), (3.4, 1.8), "in", "输入原图", "1080P RGB 图像", "载荷: 385.15 KB")

  // 2. Stage 1: Detector
  proc-node((4.2, 2), (4.0, 1.8), "s1", "Stage 1: Detector", "多任务 YOLO 定位与角点", "19.2 ms (48%)")

  // 3. Stage 2: Aligner
  proc-node((9.0, 2), (4.0, 1.8), "s2", "Stage 2: Aligner", "透视变换与仿射对齐", "0.9 ms (2%)", is-golden: true)

  // 4. Golden Data Slice
  data-node((13.8, 2), (4.8, 1.8), "patch", "★ 车牌切片 (黄金切分点)", "48 × 160 RGB 图像矩阵", "9.75 KB (载荷骤降 97.5%)", is-golden: true)

  // 5. Stage 3: Recognizer (Upper)
  proc-node((19.4, 3.1), (4.3, 1.7), "s3", "Stage 3: Recognizer", "CTC 字符序列文字识别", "17.8 ms (44%)")

  // 6. Stage 4: Classifier (Lower)
  proc-node((19.4, 0.9), (4.3, 1.7), "s4", "Stage 4: Classifier", "车牌底色与版型分类", "2.2 ms (6%)")

  // 7. Output Result
  data-node((24.5, 2), (3.6, 1.8), "out", "输出车牌结构体", "Plate(code, type, conf)", "JSON 载荷: ~100 B")

  // Directed Flow Arrows
  line("in.east", "s1.west", mark: (end: ">", fill: rgb("#3b82f6")), stroke: 1.5pt + rgb("#3b82f6"))
  line("s1.east", "s2.west", mark: (end: ">", fill: rgb("#3b82f6")), stroke: 1.5pt + rgb("#3b82f6"))
  line("s2.east", "patch.west", mark: (end: ">", fill: rgb("#d97706")), stroke: 2pt + rgb("#d97706"))

  // Patch to S3 & S4
  line("patch.east", (rel: (0.4, 0), to: "patch.east"), (rel: (-0.4, 0), to: "s3.west"), "s3.west", mark: (end: ">", fill: rgb("#d97706")), stroke: 1.5pt + rgb("#d97706"))
  line("patch.east", (rel: (0.4, 0), to: "patch.east"), (rel: (-0.4, 0), to: "s4.west"), "s4.west", mark: (end: ">", fill: rgb("#d97706")), stroke: 1.5pt + rgb("#d97706"))

  // S3 & S4 to Out
  line("s3.east", (rel: (0.4, 0), to: "s3.east"), (rel: (-0.4, 0), to: "out.west"), "out.west", mark: (end: ">", fill: rgb("#3b82f6")), stroke: 1.5pt + rgb("#3b82f6"))
  line("s4.east", (rel: (0.4, 0), to: "s4.east"), (rel: (-0.4, 0), to: "out.west"), "out.west", mark: (end: ">", fill: rgb("#3b82f6")), stroke: 1.5pt + rgb("#3b82f6"))

  // Bypass image reference line
  line("in.north", (rel: (0, 0.7), to: "in.north"), (rel: (0, 0.7), to: "s2.north"), "s2.north", stroke: (paint: rgb("#64748b"), dash: "dashed", thickness: 1.2pt), mark: (end: ">", fill: rgb("#64748b")))
  content((6.6, 4.2), anchor: "center", [
    #text(size: 7.5pt, fill: rgb("#64748b"), style: "italic")[原图数据矩阵引用传输]
  ])
})
]

#v(10pt)

// 基线性能数据表格与架构切分分析
#grid(
  columns: (1.2fr, 1fr),
  gutter: 14pt,
  [
    #text(weight: "bold", size: 10pt, fill: rgb("#0f172a"))[端侧本地基线性能实测数据表 (Profiling Baseline)]
    #v(3pt)
    #table(
      columns: (1.5fr, 2fr, 1.2fr, 1.1fr, 2fr),
      inset: (x: 5pt, y: 5pt),
      stroke: 0.5pt + rgb("#cbd5e1"),
      fill: (col, row) => if row == 0 { rgb("#f1f5f9") } else if row == 2 { rgb("#fef3c7") } else { none },
      align: (col, row) => if col == 0 { left } else { center },
      [#text(weight: "bold")[阶段 (Node)]], [#text(weight: "bold")[核心算法与模块]], [#text(weight: "bold")[平均耗时]], [#text(weight: "bold")[耗时占比]], [#text(weight: "bold")[输出载荷大小]],
      [Stage 1: Detector], [`MultiTaskDetectorORT`], [19.22 ms], [47.9%], [标量坐标框与四角点],
      [Stage 2: Aligner], [`tools_process.py`], [0.94 ms], [2.3%], [*9.75 KB (车牌小切片)*],
      [Stage 3: Recognizer], [`PPRCNNRecognitionORT`], [17.79 ms], [44.3%], [车牌文本字符串],
      [Stage 4: Classifier], [`ClassificationORT`], [2.19 ms], [5.5%], [颜色/版型概率枚举],
      [*端侧本地总计 (P0)*], [*端到端全流程串行*], [*40.15 ms*], [*100%*], [*最终结果 JSON 结构体*]
    )
  ],
  [
    #text(weight: "bold", size: 10pt, fill: rgb("#0f172a"))[协同切分点理论与系统开题分析]
    #v(3pt)
    #block(
      width: 100%,
      stroke: 1pt + rgb("#cbd5e1"),
      fill: rgb("#f8fafc"),
      radius: 4pt,
      inset: 8pt,
      [
        #text(size: 8pt, fill: rgb("#334155"))[
          *1. 计算密集型瓶颈识别*：\
          实测数据表明，Stage 1（检测定位 47.9%）与 Stage 3（字符识别 44.3%）合计占总体系统执行时间的 *92.2%*，是核心计算瓶颈。

          #v(3pt)
          *2. 数据传输骤降拐点 (黄金切分点)*：\
          - *全云端卸载 (P1)*：需传输原始高分辨率图像（*385.15 KB*）；
          - *端云协同切分 (P2)*：端侧完成 Stage 1 与 Stage 2 对齐后，仅向上层云端传输对齐后的车牌小切片（*9.75 KB*）；
          - *上行数据量削减 97.47% (缩减约 40 倍)*，大幅降低了弱网/移动无线环境下的传输延迟与带宽开销。
        ]
      ]
    )
  ]
)

#pagebreak()

// =========================================================================
// 第 4 页：模块详细职责与设计模式对照表
// =========================================================================

#align(center)[
  #text(weight: "bold", size: 15pt, fill: rgb("#0f172a"))[HyperLPR 核心模块设计与职责速查清单]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#64748b"))[Detailed Module Responsibilities, Interfaces & Architectural Design Patterns]
]

#v(8pt)

#table(
  columns: (1.3fr, 1.8fr, 2.2fr, 3.2fr, 1.5fr),
  inset: (x: 6pt, y: 6pt),
  stroke: 0.5pt + rgb("#cbd5e1"),
  fill: (col, row) => if row == 0 { rgb("#f1f5f9") } else { none },
  align: (col, row) => if col <= 1 { left } else { left },
  [#text(weight: "bold")[子模块归属]], [#text(weight: "bold")[组件/类名]], [#text(weight: "bold")[源文件路径]], [#text(weight: "bold")[核心职责与算法实现]], [#text(weight: "bold")[主要设计模式]],
  
  [门面入口层 (Facade)],
  [`LicensePlateCatcher`],
  [`Prj-Python/hyperlpr3/hyperlpr3.py`],
  [提供统一高层车牌识别 API，管理模型加载、资源释放与全管线调度，对外隐藏内部复杂的流水线级联细节。],
  [门面模式 (Facade)],

  [门面入口层 (Facade)],
  [`HyperLPRContext`],
  [`cpp/src/context_module/hyper_lpr_context.h`],
  [C++ 原生上下文句柄，封装全局参数、图像流识别会话、跨平台缓冲区生命周期与多线程安全调用。],
  [上下文模式 (Context)],

  [推理执行管线 (Pipeline)],
  [`LPRMultiTaskPipeline`],
  [`Prj-Python/hyperlpr3/inference/pipeline.py`],
  [将定位、对齐、识别、分类四大独立推理任务串接为有向级联流水线，负责算子间张量与元数据流转。],
  [管道过滤器模式 (Pipes & Filters)],

  [推理执行管线 (Pipeline)],
  [`MultiTaskDetectorORT`],
  [`inference/multitask_detect.py`],
  [基于多任务 YOLO 卷积神经网络，同时完成车牌目标框回归、四个角点关键点精细定位及单/双层初判。],
  [策略模式 (Strategy)],

  [基础工具与算法 (Common)],
  [`tools_process.py`],
  [`Prj-Python/hyperlpr3/common/tools_process.py`],
  [轻量级几何变换库，利用检测出的四个角点坐标执行仿射与透视对齐裁剪 (`get_rotate_crop_image`)。],
  [工具函数模块 (Utility)],

  [推理执行管线 (Pipeline)],
  [`PPRCNNRecognitionORT`],
  [`inference/recognition.py`],
  [基于 PPR-CNN 序列文字识别网络，通过 CTC (Connectionist Temporal Classification) 贪心解码生成车牌字符。],
  [策略模式 (Strategy)],

  [推理执行管线 (Pipeline)],
  [`ClassificationORT`],
  [`inference/classification.py`],
  [轻量级卷积分类器，判定车牌底色属性（蓝色、黄色、绿色新能源、白色等）以及单双层版型。],
  [策略模式 (Strategy)],

  [底层推理后端 (Backend)],
  [`InferenceHelper`],
  [`cpp/src/inference_helper_module`],
  [深度学习运行时抽象基类，向下屏蔽 ONNXRuntime、MNN、OpenVINO 等异构推理引擎的 API 差异。],
  [适配器模式 (Adapter) / 工厂模式],

  [基础类型定义 (Common)],
  [`typedef.py` / `basic_types.h`],
  [`common/typedef.py`, `cpp/src/basic_types.h`],
  [定义统一的跨模块数据契约，包含 `Plate` 结构体、`PlateType` 枚举、置信度分数及坐标多边形。],
  [值对象 (Value Object)],

  [配置管理中心 (Config)],
  [`settings.py` / `configuration.py`],
  [`config/settings.py`, `configuration.py`],
  [集中管理 ONNX/MNN 权重存储路径、网络输入分辨率、置信度阈值、NMS 重叠度超参数及版本信息。],
  [单例配置 (Singleton)]
)
