"""Part A 源码解耦产物：把 HyperLPR 固化的四阶段流水线拆成可独立调用的算子。

本目录当前只含**开题阶段（Part A）**的交付物：

- ``ops.py``   ：Detect / Align / Recognition / Classification 四个原子算子，
  对应原库写死在 ``LPRMultiTaskPipeline.run()`` 里的四段逻辑，
  拆开后每个算子都能被单独调用与单独计时，且不修改原库任何一行；
- ``engine.py``：按需加载 Detect / Rec / Cls 三个 ONNX 模型的端侧引擎，
  使算子可以脱离原库的 ``LPRMultiTaskPipeline`` 独立运行。

Part B 的内容（可插拔流水线编排、网络条件模拟、云端传输、划分矩阵实验）
不属于开题范围，其源码维护在 ``part-b-pipeline`` 分支。
"""

from .engine import LocalEngine, get_engine
from .ops import (
    align_crop,
    box_crop,
    detect_plates,
    full_recognize,
    resolve_plate_type,
    run_classification,
    run_recognition,
)

__all__ = [
    "LocalEngine",
    "get_engine",
    "detect_plates",
    "align_crop",
    "box_crop",
    "run_recognition",
    "run_classification",
    "resolve_plate_type",
    "full_recognize",
]

__version__ = "0.1.0-part-a"
