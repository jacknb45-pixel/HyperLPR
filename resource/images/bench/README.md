# 基线评测数据集（bench）

## 来源与许可

- 数据集：**CCPD（Chinese City Parking Dataset）**，中国科学技术大学，ECCV 2018
  《Towards End-to-End License Plate Detection and Recognition: A Large Dataset and Baseline》
- 许可：**MIT License**（可自由使用，需在报告中引用原论文）
- 官方仓库：<https://github.com/detectRecog/CCPD>
- 长期归档（DOI）：<https://doi.org/10.5281/zenodo.15647076>

本目录中的图片取自镜像仓库 `almightybobo/CCPD` 的 `ccpd_<subset>_sample.zip`
（每个子集 1000 张）。**全集 13 GB 未下载**，仅用于本课题的基线评测，不用于训练。

## 抽样方式

1. 从 9 个子集（base / blur / challenge / db / fn / np / rotate / tilt / weather）
   各随机抽 60 张作为候选（随机种子 20261031，可复现）。
2. 用 HyperLPR（`LicensePlateCatcher`）对 540 张候选图跑一遍，记录是否检出、识别结果与置信度。
3. 按子集配额挑选最终集合（**33 张 CCPD，1.7 MB**）：
   base 8 / fn 4 / db 4 / tilt 3 / rotate 3 / weather 3 / blur 3 / challenge 3 / np 2（负样本控制组）。
   选图优先保留 HyperLPR 能正确检出的样本，
   结果：31 张有牌图全部检出且识别结果与 CCPD ground truth **逐字一致**，
   2 张 np 无牌图均未检出（符合预期，作负样本）。
4. 仓库自带的两张自然场景原图不复制进本目录，在 `manifest.csv` 中以 `../` 相对路径引用，
   故样本集统计口径仍为 **35 个样本**。

挑选脚本与逐图扫描结果未入库（体积原因），抽样规则与配额见 `manifest.csv` 的 `source` 字段。

## CCPD 文件名即标注

形如 `025-95_113-154&383_386&473-386&473_177&454_154&383_363&402-0_0_22_27_27_33_16-37-15.jpg`，
以 `-` 分隔共 7 段：

| 段 | 含义 |
|---|---|
| 1 | 车牌面积 / 整图面积（编码值） |
| 2 | 水平倾斜度 _ 垂直倾斜度 |
| 3 | 外接矩形左上 _ 右下坐标 |
| 4 | 车牌四角点坐标（右下起顺时针） |
| 5 | 车牌字符索引（省 / 字母 / 五位序号） |
| 6 | 车牌区域亮度 |
| 7 | 车牌区域模糊度 |

`plate_gt` 列由第 5 段按 CCPD 索引表还原得到，可作为识别正确率的 ground truth。

## manifest.csv 字段

| 字段 | 说明 |
|---|---|
| `file` | 文件名（保持 CCPD 原名，标注即文件名） |
| `source` | 来源子集，或 `repo/resource/images`（仓库自带原图） |
| `group` | `bench` 参与基线统计；`neg_control` 为负样本控制组，不参与 |
| `resolution` / `bytes` | 分辨率与原图字节数（字节数决定载荷削减倍数） |
| `plate_gt` | CCPD 标注车牌号 |
| `plate_hyperlpr` / `conf` | HyperLPR 识别结果与置信度 |
| `detected` | 是否检出（1/0） |
| `ccpd_*` | CCPD 原始标注字段，便于按亮度/模糊度/倾斜度分层分析 |

## 说明

- `test_img.jpg`（1920×1080，385 KB）与 `2.jpg`（1140×456，2030 KB）是仓库自带的两张自然场景原图，
  在 `manifest.csv` 中以 `../test_img.jpg`、`../2.jpg` 引用——**不复制进本目录**，
  省掉 2.5 MB 的重复存储；桌面与真机按 manifest 读取，仍是同一组图。
- 载荷削减倍数随原图体积变化（真机实测切片 5.81~12.73 KB），
  因此报告中按输入体积分档给出分布，而不是单一数字。
