# 文档编译说明

报告与配图均用 [Typst](https://typst.app) 编译。仓库只入库 `.typ` 源码，
PDF / PNG 属于本地产物，已被 `.gitignore` 排除。

## 必须先生成配图，再编译报告

`confirmation_report.typ` 通过 `image("module_map.png")` 与 `image("dataflow.png")`
引用两张配图，而这两种 PNG 不入仓库——**新克隆的分支直接编译报告会报"找不到文件"**。
正确顺序是先编译两张图：

```bash
typst compile doc/module_map.typ  doc/module_map.png
typst compile doc/dataflow.typ    doc/dataflow.png
typst compile doc/confirmation_report.typ doc/confirmation_report.pdf
```

（若 `typst` 未加入 PATH，把命令中的 `typst` 替换为本地二进制的完整路径即可；
各平台安装包见 <https://github.com/typst/typst/releases>。）

## 文件说明

| 文件 | 作用 |
|---|---|
| `confirmation_report.typ` | 开题报告正文（M1 交付物，编译后 8 页 PDF） |
| `module_map.typ` | 图 1：原库五层模块结构与模块到文件分配视图 |
| `dataflow.typ` | 图 2：四阶段数据流、张量形态与候选切分点 |
| `tensor_shapes.md` | 图 2 的数据依据（张量形态与载荷表） |
| `android_baseline_20261101.txt` | 真机实测原始记录（四阶段逐阶段计时） |
| `desktop_baseline_backup.md` | 早期桌面环境测量数据备份（报告已不引用，中期端云对照时复用） |
| `DEFENSE_NOTES.md` | 11/04 线下汇报讲稿要点与预期提问口径 |

## Typst 排版注意事项

- `~` 在 markup 中表示**不换行空格**，数值范围必须写成 `\~`（否则渲染后波浪号丢失）；
- cetz 的 `content()` 内单换行会被当作空格拼接，多行文本需在每个行尾加 `\`。
