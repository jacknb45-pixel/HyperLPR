# Android 真机基准测试 App（BenchActivity）

用于**在真机上直接测量 HyperLPR 四个阶段各自的耗时**，产出开题报告与中期报告所用的端侧基线。

## 为什么需要它

官方 Android SDK（`com.hyperai.hyperlpr3.HyperLPR3`）只暴露 `init / release / plateRecognition`，
拿不到 Detect / Align / Rec / Cls 各自的耗时，因此无法回答"该把哪一阶段搬到云端"。

本 App 的做法是：自写 `libstage_bench.so`，链接官方 AAR 中 `libhyperlpr3.so`
**已导出**的引擎内部符号（`hyper::DetArch` / `RecognitionEngine` / `ClassificationEngine` /
`cv::*` / `MNN::*`），在 C++ 层按流水线源码 `hyper_lpr_context.cpp` 的原始顺序依次实例化
四个算子，每个算子前后各用 `std::chrono::steady_clock` 打点。

- 不用差分法（"整体减子集"）推算——真机上不成立；
- 不用本地编译 MNN / OpenCV——符号全部复用官方库；
- 与官方 `plateRecognition()` 并存于同一 APK，互不干扰。

> 官方库未导出 `imgcodecs`，故图像由 Java 解码后以 BGR 传入 native，
> 切片体积回传后用 `Bitmap.compress` 实测字节数。

## 目录说明（本目录是"覆盖层"，不是独立工程）

为避免与官方 demo 工程重复、也避免把 APK / `.so` / 测试图等二进制塞进仓库，
这里只保存**我们新增或修改的文件**。构建时以 `Prj-Android/`（官方 demo 工程）为基座覆盖即可：

| 本目录文件 | 覆盖到 |
|---|---|
| `build.gradle` | `Prj-Android/app/build.gradle` |
| `AndroidManifest.xml` | `Prj-Android/app/src/main/AndroidManifest.xml` |
| `BenchActivity.java` | `Prj-Android/app/src/main/java/com/hyperai/example/lpr3_demo/` |
| `NativeStageBench.java` | `Prj-Android/app/src/main/java/com/hyperai/example/lpr3_bench/` |

`build.gradle` 把 `applicationId` 改为 `com.hyperai.example.lpr3_bench`：
官方 demo APK 用的是官方 keystore，本机 debug 签名与之同名会安装失败，改包名后两者可共存。

## 构建步骤

```bash
# 1) 编译 native 计时库（NDK/CMake，需要在仓库根目录执行）
#    从官方 AAR 中取出 arm64-v8a 的 libhyperlpr3.so（解压 hyperlpr3-android-sdk 的 aar/jni）
cmake -S cpp/platform/jni/android_bench -B /tmp/stage_bench_build \
      -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21 \
      -DPREBUILT_SDK_SO=/path/to/libhyperlpr3.so
cmake --build /tmp/stage_bench_build
mkdir -p Prj-Android/app/src/main/jniLibs/arm64-v8a
cp /tmp/stage_bench_build/libstage_bench.so Prj-Android/app/src/main/jniLibs/arm64-v8a/

# 2) 覆盖本目录的四个文件到 Prj-Android/app/（见上表）

# 3) 内置测试图（App 打开即测，不需要存储权限与 USB 调试）
mkdir -p Prj-Android/app/src/main/assets/plates
cp resource/images/test_img.jpg resource/images/2.jpg Prj-Android/app/src/main/assets/plates/

# 4) 构建
cd Prj-Android && ./gradlew assembleDebug
```

需要 AGP ≥ 7.x / Gradle ≥ 7.5（仓库自带的 wrapper 若过旧需先升级）。

## 运行与结果

安装后打开即自动开测：内置测试图、3 次 warmup + 20 轮、逐阶段取均值与标准差，
外加官方 SDK 端到端计时与 MNN 线程数扫描（1/2/4/8）。

结果**逐行增量写入** `bench_result.txt`（`getExternalFilesDir()`，App 内可直接分享）。
这样做的原因：native 崩溃是 SIGSEGV，Java 的 `catch (Throwable)` 拦不住、进程直接死，
只有增量落盘才能在重启后看到"死在哪一步"。初始化也因此拆成
`createSession → initDet → initCls → initRec` 四步逐步打点。

> 另有一个历史教训：不要在 Java 层反复 `release()` 后 `init()` + `setThreads()`——
> 在部分真机（如 Unisoc）上会触发 native SIGSEGV。线程扫描已移到 C++ 侧，每档新建独立引擎实例。

## 实测基线（2026-11-01，Android 10 / 8 核 ARM / MNN）

| 项目 | test_img.jpg (1920×1080) | 2.jpg (1140×456) |
|---|---|---|
| Detect | 68.00 ms (48.1%) | 68.74 ms (47.0%) |
| Align | 0.88 ms (0.6%) | 3.29 ms (2.3%) |
| Rec | 70.08 ms (49.5%) | 71.49 ms (48.9%) |
| Cls | 2.53 ms (1.8%) | 2.58 ms (1.8%) |
| 四阶段合计 | **141.49 ms** | 146.10 ms |
| SDK 端到端 | 150.52 ms | 173.54 ms |

进程内存 PSS 84.2 MB；对齐后切片 5.81~12.73 KB。原始记录见 `doc/android_baseline_20261101.txt`。
