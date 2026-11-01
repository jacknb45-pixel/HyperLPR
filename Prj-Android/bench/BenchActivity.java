package com.hyperai.example.lpr3_demo;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.content.res.AssetFileDescriptor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.os.Debug;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.hyperai.hyperlpr3.HyperLPR3;
import com.hyperai.hyperlpr3.bean.HyperLPRParameter;
import com.hyperai.hyperlpr3.bean.Plate;
import com.hyperai.example.lpr3_bench.NativeStageBench;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * 端侧（Android 真机）性能基准测试界面。
 *
 * 设计目标：不需要 USB 调试、不需要存储权限、不需要手动选图。
 * 测试图片内置在 assets/plates 中，打开即测，结果直接显示在屏幕上，
 * 同时写入应用私有目录并支持通过系统分享导出。
 *
 * 测量口径（v4）：
 *   A 组 = 四阶段逐阶段直接计时。C++ 层（libstage_bench.so，链接官方 libhyperlpr3.so）
 *          对 Detect / Align / Rec / Cls 各用 steady_clock 单独计时，与桌面
 *          profile_baseline.py 同口径，不依赖任何差分推算。
 *   B 组 = Java SDK plateRecognition() 端到端墙钟耗时（与 C++ 路径互相印证）。
 *   C 组 = 参考组（流水线中间产物/调试图，不参与基线）。
 *
 * 历史：v2/v3 曾用"差分法"推算阶段耗时（无牌对照图 vs 含牌原图相减），v4 已删除——
 * 既然能直接逐阶段计时，差分推算没有必要；且 v3 的 C 组（Java 侧 release+init 线程扫描）
 * 会在真机上触发 native 崩溃，线程扫描改由 A 组在 C++ 层做（每档新建独立引擎实例）。
 */
public class BenchActivity extends AppCompatActivity {

    private static final String TAG = "HyperLPR-Bench";
    private static final int ROUNDS = 20;
    private static final int ROUNDS_SWEEP = 10;
    private static final int WARMUP = 3;
    private static final int[] THREAD_SWEEP = {1, 2, 4, 8};

    private TextView resultView;
    private Button runBtn;
    private Button shareBtn;
    private final StringBuilder report = new StringBuilder();
    private final Handler ui = new Handler(Looper.getMainLooper());
    private volatile boolean running = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (16 * getResources().getDisplayMetrics().density);
        root.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("HyperLPR 端侧基准测试");
        title.setTextSize(20f);
        title.setTypeface(null, Typeface.BOLD);
        root.addView(title);

        TextView tip = new TextView(this);
        tip.setText("A 组 C++ 逐阶段计时 → B 组端到端 → C 组参考图。无需选图、无需权限，"
                + "结果实时写入 bench_result.txt，跑完可分享。");
        tip.setTextSize(12f);
        root.addView(tip);

        runBtn = new Button(this);
        runBtn.setText("开始测试");
        root.addView(runBtn);

        shareBtn = new Button(this);
        shareBtn.setText("分享 / 导出结果");
        shareBtn.setEnabled(false);
        root.addView(shareBtn);

        // 诊断按钮：抓取本进程 logcat（含 crash 缓冲区），native 崩溃后重新打开 App 点它
        Button dumpBtn = new Button(this);
        dumpBtn.setText("抓取崩溃日志（logcat）");
        dumpBtn.setOnClickListener(v -> dumpLogcat());
        root.addView(dumpBtn);

        resultView = new TextView(this);
        resultView.setTypeface(Typeface.MONOSPACE);
        resultView.setTextSize(10.5f);
        resultView.setTextIsSelectable(true);
        ScrollView sv = new ScrollView(this);
        sv.addView(resultView);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        root.addView(sv, lp);

        setContentView(root);

        initEngine(0);

        runBtn.setOnClickListener(v -> runBench());
        shareBtn.setOnClickListener(v -> shareReport());

        String prev = readPrevResult();
        resultView.setText(deviceInfo()
                + (prev.isEmpty() ? "\n点击上方按钮开始测试。"
                                  : "\n\n----- 上次运行残留结果（若上次闪退，此处即崩溃位置）-----\n" + prev));
    }

    /** threads=0 表示使用 SDK 默认线程配置 */
    private void initEngine(int threads) {
        HyperLPRParameter parameter = new HyperLPRParameter()
                .setDetLevel(HyperLPR3.DETECT_LEVEL_LOW)
                .setMaxNum(1)
                .setRecConfidenceThreshold(0.75f);
        if (threads > 0) {
            parameter.setThreads(threads);
        }
        HyperLPR3.getInstance().init(this, parameter);
    }

    private String deviceInfo() {
        StringBuilder sb = new StringBuilder();
        sb.append("===== 端侧设备信息 =====\n");
        sb.append("机型: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n");
        sb.append("硬件/板: ").append(Build.HARDWARE).append(" / ").append(Build.BOARD).append("\n");
        sb.append("主 ABI: ").append(Build.SUPPORTED_ABIS.length > 0 ? Build.SUPPORTED_ABIS[0] : "?").append("\n");
        sb.append("Android API: ").append(Build.VERSION.SDK_INT).append("\n");
        sb.append("可用 CPU 核心: ").append(Runtime.getRuntime().availableProcessors()).append("\n");
        try {
            ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
            ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
            am.getMemoryInfo(mi);
            sb.append("系统内存: 可用 ").append(mi.availMem / 1024 / 1024)
              .append(" MB / 共 ").append(mi.totalMem / 1024 / 1024).append(" MB\n");
        } catch (Exception e) {
            sb.append("系统内存: 读取失败\n");
        }
        return sb.toString();
    }

    // ---------------------------------------------------------------- 测量原语

    private static class Stat {
        double mean, median, min, max;
        String plate = "未识别到车牌";
        int w, h;
    }

    private Stat measure(Bitmap bmp, int rounds) {
        // warmup：不计入统计
        try {
            HyperLPR3.getInstance().plateRecognition(bmp,
                    HyperLPR3.CAMERA_ROTATION_0, HyperLPR3.STREAM_BGRA);
        } catch (Exception ignored) {
        }

        List<Double> samples = new ArrayList<>();
        Stat st = new Stat();
        st.w = bmp.getWidth();
        st.h = bmp.getHeight();

        for (int i = 0; i < rounds; i++) {
            long t0 = System.nanoTime();
            Plate[] plates = HyperLPR3.getInstance().plateRecognition(bmp,
                    HyperLPR3.CAMERA_ROTATION_0, HyperLPR3.STREAM_BGRA);
            long t1 = System.nanoTime();
            samples.add((t1 - t0) / 1_000_000.0);
            if (i == 0 && plates != null && plates.length > 0) {
                Plate p = plates[0];
                String type = "未知";
                if (p.getType() != HyperLPR3.PLATE_TYPE_UNKNOWN
                        && p.getType() < HyperLPR3.PLATE_TYPE_MAPS.length) {
                    type = HyperLPR3.PLATE_TYPE_MAPS[p.getType()];
                }
                st.plate = p.getCode() + "[" + type + "]";
            }
        }

        List<Double> sorted = new ArrayList<>(samples);
        Collections.sort(sorted);
        double sum = 0;
        for (double x : samples) sum += x;
        st.mean = sum / samples.size();
        st.median = sorted.get(sorted.size() / 2);
        st.min = sorted.get(0);
        st.max = sorted.get(sorted.size() - 1);
        return st;
    }

    private Bitmap load(String name) {
        try {
            return BitmapFactory.decodeStream(getAssets().open("plates/" + name));
        } catch (Exception e) {
            return null;
        }
    }

    private String row(String name, Stat st, int rounds) {
        return String.format(Locale.US, "%-18s %-11s %6d %9.2f %9.2f %9.2f %9.2f  %s",
                name, st.w + "x" + st.h, rounds, st.mean, st.median, st.min, st.max, st.plate);
    }

    private static final String HEAD =
            String.format(Locale.US, "%-18s %-11s %6s %9s %9s %9s %9s  %s",
                    "图片", "分辨率", "轮次", "均值ms", "中位ms", "最小ms", "最大ms", "识别结果");

    // ---------------------------------------------------------------- 主流程

    private void runBench() {
        if (running) return;
        running = true;
        runBtn.setEnabled(false);
        shareBtn.setEnabled(false);

        report.setLength(0);
        report.append(deviceInfo());
        resultView.setText(report.toString());

        new Thread(() -> {
            try {
                // 顺序：最重要的四阶段直接计时先跑，避免后面的次要分组崩溃时丢核心数据
                phaseStage();      // A. 四阶段直接计时（C++ 埋点）+ 线程扫描
                phaseE2E();        // B. 自然场景图端到端
                phaseRef();        // C. 参考组
            } catch (Throwable e) {
                appendLine("ERROR: " + e);
                Log.e(TAG, "bench failed", e);
            }

            int pssKb = 0;
            try {
                Debug.MemoryInfo mi = new Debug.MemoryInfo();
                Debug.getMemoryInfo(mi);
                pssKb = mi.getTotalPss();
            } catch (Exception ignored) {
            }
            appendLine("");
            appendLine("----- 汇总 -----");
            appendLine("进程 PSS(测试后采样): " + pssKb + " KB ("
                    + String.format(Locale.US, "%.1f", pssKb / 1024.0) + " MB)");
            appendLine("口径: A 组为 C++ 层 Detect/Align/Rec/Cls 各自 steady_clock 计时（3 次 warmup）;");
            appendLine("      B/C 组为 plateRecognition() 单次墙钟耗时（1 次 warmup）; 均不含解码与界面绘制;");
            appendLine("      计时用 System.nanoTime() / steady_clock()。本版已删除差分法，全部为直接实测。");

            String text = report.toString();
            Log.i(TAG, "\n" + text);
            saveToFile(text);

            ui.post(() -> {
                resultView.setText(text);
                runBtn.setEnabled(true);
                shareBtn.setEnabled(true);
                running = false;
                Toast.makeText(this, "测试完成", Toast.LENGTH_SHORT).show();
            });
        }).start();
    }

    /** B. 自然场景图端到端（Java SDK 路径，与 A 组 C++ 路径互证） */
    private void phaseE2E() {
        String[] names = {"test_img.jpg", "2.jpg"};
        appendLine("");
        appendLine("===== B. 自然场景图 端到端（Java SDK plateRecognition，默认线程）=====");
        appendLine("口径: plateRecognition() 单次墙钟耗时, 1 次 warmup + " + ROUNDS + " 轮");
        appendLine(HEAD);
        for (String n : names) {
            Bitmap bmp = load(n);
            if (bmp == null) { appendLine(n + " 加载失败"); continue; }
            Stat st = measure(bmp, ROUNDS);
            appendLine(row(n, st, ROUNDS));
            bmp.recycle();
        }
    }

    /** C. 参考组：仓库内其余图像（流水线中间产物/调试小图，非自然场景） */
    private void phaseRef() {
        String[] names = {"1.jpg", "pre.jpg", "a.jpg", "pad.jpg", "align.jpg"};
        appendLine("");
        appendLine("===== C. 参考组：非自然场景图（中间产物/调试图，仅供交叉验证）=====");
        appendLine("注意: 这些是流水线中间产物或裁剪切片, 不代表真实输入, 不参与基线统计;");
        appendLine("      \"未识别\"样本的耗时即 Detect 全流程的量级, 可与 A 组 det_ms 互证。");
        appendLine(HEAD);
        for (String n : names) {
            Bitmap bmp = load(n);
            if (bmp == null) { continue; }
            Stat st = measure(bmp, ROUNDS_SWEEP);
            appendLine(row(n, st, ROUNDS_SWEEP));
            bmp.recycle();
        }
    }

    /** A. 四阶段逐阶段直接计时（C++ 层埋点，不是差分法；分步初始化，每步落盘定位崩溃点） */
    private void phaseStage() {
        appendLine("");
        appendLine("===== A. 四阶段逐阶段直接计时（C++/MNN 层埋点，真机实测）=====");
        if (!NativeStageBench.available()) {
            appendLine("native 库未加载: " + NativeStageBench.loadError());
            return;
        }
        String modelDir = extractModels();
        if (modelDir == null) {
            appendLine("模型目录准备失败（assets/r2_mobile 不存在？）");
            return;
        }
        appendLine("模型目录: " + modelDir);
        appendLine("口径: C++ 层对 Detect/Align/Rec/Cls 各用 steady_clock 单独计时, "
                + WARMUP + " 次 warmup + " + ROUNDS + " 轮; 与桌面 profile_baseline.py 同口径");

        // ---- 分步初始化：任何一步崩溃，落盘日志都能定位到具体引擎 ----
        appendLine("step 1/6: 创建 native 会话...");
        long h = NativeStageBench.nativeCreateSession(modelDir);
        if (h == 0) {
            appendLine("会话创建失败: " + NativeStageBench.nativeLastError());
            return;
        }
        appendLine("step 1/6 OK: 会话句柄 " + h);
        try {
            int threads = 4;
            appendLine("step 2/6: 初始化 Detect 引擎（threads=" + threads + ", input=320）...");
            if (!NativeStageBench.nativeInitDet(h, threads, 320)) {
                appendLine("Detect 初始化失败: " + NativeStageBench.nativeLastError());
                return;
            }
            appendLine("step 2/6 OK: " + NativeStageBench.nativeLastError());
            appendLine("step 3/6: 初始化 Cls 引擎...");
            if (!NativeStageBench.nativeInitCls(h, threads)) {
                appendLine("Cls 初始化失败: " + NativeStageBench.nativeLastError());
                return;
            }
            appendLine("step 3/6 OK: " + NativeStageBench.nativeLastError());
            appendLine("step 4/6: 初始化 Rec 引擎...");
            if (!NativeStageBench.nativeInitRec(h, threads)) {
                appendLine("Rec 初始化失败: " + NativeStageBench.nativeLastError());
                return;
            }
            appendLine("step 4/6 OK: " + NativeStageBench.nativeLastError());

            appendLine("step 5/6: 逐图测试");
            appendLine(String.format(Locale.US, "%-14s %9s %9s %9s %9s %9s %8s %8s  %s",
                    "图片", "det_ms", "align_ms", "rec_ms", "cls_ms", "total_ms", "切片KB", "削减%", "识别结果"));
            for (String n : new String[]{"test_img.jpg", "2.jpg"}) {
                benchImage(h, n);
            }

            appendLine("step 6/6: 线程数扫描（每档新建独立会话，避免 release/init 崩溃）");
            threadSweep(modelDir);
        } finally {
            NativeStageBench.nativeDestroySession(h);
            appendLine("native 会话已销毁");
        }
    }

    /** 单张图的 warmup + 统计（native 单轮调用，逐轮落盘进度） */
    private void benchImage(long h, String name) {
        Bitmap bmp = load(name);
        if (bmp == null) { appendLine(name + " 加载失败"); return; }
        double rawKb = assetKb("plates/" + name);
        byte[] bgr = NativeStageBench.toBgr(bmp);
        int w = bmp.getWidth(), hgt = bmp.getHeight();
        appendLine(String.format(Locale.US, "[ %s ] %dx%d, 原图 %.1f KB", name, w, hgt, rawKb));

        for (int i = 0; i < WARMUP; i++) {
            double[] r = NativeStageBench.nativeRunOnce(h, bgr, w, hgt);
            appendLine(String.format(Locale.US,
                    "  warmup %d/%d: det %.2f align %.2f rec %.2f cls %.2f total %.2f ms%s",
                    i + 1, WARMUP, r[0], r[1], r[2], r[3], r[0] + r[1] + r[2] + r[3],
                    r[4] > 0 ? "" : "  (未检出)"));
            if (r[0] < 0 || (r[4] > 0 && r[0] == 0)) {
                appendLine("  native 异常: " + NativeStageBench.nativeLastError());
                bmp.recycle();
                return;
            }
        }

        double sdet = 0, salign = 0, srec = 0, scls = 0, stotal = 0;
        int detected = 0;
        double vdet = 0, valign = 0, vrec = 0, vcls = 0, vtotal = 0;
        for (int i = 0; i < ROUNDS; i++) {
            double[] r = NativeStageBench.nativeRunOnce(h, bgr, w, hgt);
            double det = r[0], align = r[1], rec = r[2], cls = r[3], total = det + align + rec + cls;
            if (r[4] > 0) detected++;
            sdet += det; salign += align; srec += rec; scls += cls; stotal += total;
            vdet += det * det; valign += align * align; vrec += rec * rec; vcls += cls * cls; vtotal += total * total;
            if ((i + 1) % 5 == 0) {
                appendLine(String.format(Locale.US, "  进度 %d/%d: 本轮 total %.2f ms",
                        i + 1, ROUNDS, total));
            }
        }
        double mdet = sdet / ROUNDS, malign = salign / ROUNDS, mrec = srec / ROUNDS, mcls = scls / ROUNDS, mtotal = stotal / ROUNDS;
        double sd = Math.sqrt(Math.max(0, vdet / ROUNDS - mdet * mdet));
        double sa = Math.sqrt(Math.max(0, valign / ROUNDS - malign * malign));
        double sr = Math.sqrt(Math.max(0, vrec / ROUNDS - mrec * mrec));
        double sc = Math.sqrt(Math.max(0, vcls / ROUNDS - mcls * mcls));

        double patchKb = detected > 0 ? patchJpegKb() : 0;
        double cut = (rawKb > 0 && patchKb > 0) ? (1 - patchKb / rawKb) * 100.0 : 0;
        appendLine(String.format(Locale.US,
                "%-14s %9.2f %9.2f %9.2f %9.2f %9.2f %8.2f %8.2f  %s (检出 %d/%d 轮)",
                name, mdet, malign, mrec, mcls, mtotal, patchKb, cut,
                NativeStageBench.nativeLastCode(), detected, ROUNDS));
        appendLine(String.format(Locale.US,
                "  标准差: det %.2f / align %.2f / rec %.2f / cls %.2f / total %.2f",
                sd, sa, sr, sc, Math.sqrt(Math.max(0, vtotal / ROUNDS - mtotal * mtotal))));
        bmp.recycle();
    }

    /** 线程数扫描：每档 create → 3 步 init → 1 次 warmup + ROUNDS_SWEEP 轮 → destroy */
    private void threadSweep(String modelDir) {
        appendLine(String.format(Locale.US, "%-8s %10s %10s %10s %10s",
                "threads", "det_ms", "rec_ms", "cls_ms", "total_ms"));
        Bitmap bmp = load("test_img.jpg");
        if (bmp == null) { appendLine("test_img.jpg 加载失败"); return; }
        byte[] bgr = NativeStageBench.toBgr(bmp);
        int w = bmp.getWidth(), hgt = bmp.getHeight();
        for (int th : THREAD_SWEEP) {
            long h = NativeStageBench.nativeCreateSession(modelDir);
            if (h == 0) { appendLine(th + " 线程档: 会话创建失败"); continue; }
            try {
                if (!NativeStageBench.nativeInitDet(h, th, 320)
                        || !NativeStageBench.nativeInitCls(h, th)
                        || !NativeStageBench.nativeInitRec(h, th)) {
                    appendLine(th + " 线程档: 引擎初始化失败 - " + NativeStageBench.nativeLastError());
                    continue;
                }
                NativeStageBench.nativeRunOnce(h, bgr, w, hgt);   // 1 次 warmup
                double sum = 0, sd = 0, sr = 0, sc = 0, st = 0;
                for (int i = 0; i < ROUNDS_SWEEP; i++) {
                    double[] r = NativeStageBench.nativeRunOnce(h, bgr, w, hgt);
                    sd += r[0]; sr += r[2]; sc += r[3]; st += r[0] + r[1] + r[2] + r[3];
                }
                appendLine(String.format(Locale.US, "%-8d %10.2f %10.2f %10.2f %10.2f",
                        th, sd / ROUNDS_SWEEP, sr / ROUNDS_SWEEP, sc / ROUNDS_SWEEP, st / ROUNDS_SWEEP));
            } finally {
                NativeStageBench.nativeDestroySession(h);
            }
        }
        bmp.recycle();
    }

    /** 用 Java 侧 JPEG q95 编码统计对齐切片体积（native 库未链接 imgcodecs） */
    private double patchJpegKb() {
        try {
            int[] dims = NativeStageBench.nativeLastPatchSize();
            byte[] px = NativeStageBench.nativeLastPatchBytes();
            if (dims == null || px == null || dims[0] <= 0 || dims[1] <= 0) return 0;
            Bitmap bmp = NativeStageBench.fromBgr(px, dims[0], dims[1]);
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            bmp.compress(Bitmap.CompressFormat.JPEG, 95, bos);
            int bytes = bos.size();
            bmp.recycle();
            return bytes / 1024.0;
        } catch (Throwable e) {
            return 0;
        }
    }

    private double assetKb(String assetPath) {
        try {
            AssetFileDescriptor afd = getAssets().openFd(assetPath);
            long len = afd.getLength();
            afd.close();
            return len / 1024.0;
        } catch (Exception e) {
            return 0;
        }
    }

    /** 把 assets/r2_mobile 的 6 个模型落到私有目录，返回目录绝对路径 */
    private String extractModels() {
        try {
            File out = new File(getFilesDir(), "r2_mobile");
            if (!out.exists() && !out.mkdirs()) return null;
            String[] models = getAssets().list("r2_mobile");
            if (models == null) return null;
            for (String m : models) {
                File dst = new File(out, m);
                if (dst.exists() && dst.length() > 0) continue;
                copyAsset("r2_mobile/" + m, dst);
            }
            return out.getAbsolutePath();
        } catch (Exception e) {
            Log.e(TAG, "extractModels failed", e);
            return null;
        }
    }

    /** 把 assets/plates 里的测试图落盘（保留给需要文件路径的场景，当前 A 组经 JNI 传字节，不使用） */
    private File copyPlate(String name) {
        try {
            File dir = new File(getFilesDir(), "plates");
            if (!dir.exists() && !dir.mkdirs()) return null;
            File dst = new File(dir, name);
            if (!dst.exists() || dst.length() == 0) copyAsset("plates/" + name, dst);
            return dst;
        } catch (Exception e) {
            Log.e(TAG, "copyPlate failed", e);
            return null;
        }
    }

    private void copyAsset(String assetPath, File dst) throws Exception {
        InputStream is = getAssets().open(assetPath);
        OutputStream os = new FileOutputStream(dst);
        byte[] buf = new byte[8192];
        int len;
        while ((len = is.read(buf)) > 0) os.write(buf, 0, len);
        os.close();
        is.close();
    }

    // ---------------------------------------------------------------- 工具

    /**
     * 抓取本进程 logcat（main + crash 缓冲区），native SIGSEGV 的 backtrace 在 crash 缓冲区里。
     * 不需要 adb / USB 调试——App 可以读取自己 UID 的日志。
     */
    private void dumpLogcat() {
        Toast.makeText(this, "正在抓取日志...", Toast.LENGTH_SHORT).show();
        new Thread(() -> {
            appendLine("");
            appendLine("===== logcat 抓取（pid=" + android.os.Process.myPid() + "）=====");
            for (String buf : new String[]{"crash", "main"}) {
                appendLine("----- buffer: " + buf + " -----");
                try {
                    Process p = Runtime.getRuntime().exec(new String[]{
                            "logcat", "-d", "-v", "time", "-b", buf,
                            "--pid", String.valueOf(android.os.Process.myPid())});
                    java.io.BufferedReader br = new java.io.BufferedReader(
                            new java.io.InputStreamReader(p.getInputStream(), "UTF-8"));
                    String line;
                    int n = 0;
                    while ((line = br.readLine()) != null) {
                        appendLine(line);
                        if (++n > 400) { appendLine("...(超过 400 行截断)"); break; }
                    }
                    br.close();
                    p.waitFor();
                } catch (Exception e) {
                    appendLine("logcat 读取失败: " + e);
                }
            }
            appendLine("===== logcat 抓取结束，可分享导出 =====");
            ui.post(() -> {
                shareBtn.setEnabled(true);
                saveToFile(report.toString());
                Toast.makeText(this, "日志已抓取，可分享", Toast.LENGTH_SHORT).show();
            });
        }).start();
    }

    /** 读上次残留的 bench_result.txt（尾部），闪退后重新打开 App 可看到崩溃位置 */
    private String readPrevResult() {
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) dir = getFilesDir();
            File f = new File(dir, "bench_result.txt");
            if (!f.exists()) return "";
            java.io.BufferedReader br = new java.io.BufferedReader(
                    new java.io.InputStreamReader(new java.io.FileInputStream(f), "UTF-8"));
            StringBuilder sb = new StringBuilder();
            char[] buf = new char[4096];
            int n;
            while ((n = br.read(buf)) > 0) sb.append(buf, 0, n);
            br.close();
            String s = sb.toString();
            if (s.length() > 6000) s = "...(前文截断)...\n" + s.substring(s.length() - 6000);
            return s.trim();
        } catch (Exception e) {
            return "";
        }
    }

    private void appendLine(String line) {
        report.append(line).append("\n");
        String snapshot = report.toString();
        ui.post(() -> resultView.setText(snapshot));
        // 增量落盘：native 崩溃无法被 try/catch 拦截，进程直接死，只有实时写盘才不丢数据
        flush(snapshot);
    }

    private void flush(String text) {
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) dir = getFilesDir();
            if (dir == null) return;
            if (!dir.exists() && !dir.mkdirs()) return;
            File f = new File(dir, "bench_result.txt");
            OutputStream os = new FileOutputStream(f, false);
            os.write(text.getBytes("UTF-8"));
            os.close();
        } catch (Exception ignored) {
        }
    }

    private void saveToFile(String text) {
        flush(text);
        File dir = getExternalFilesDir(null);
        if (dir == null) dir = getFilesDir();
        if (dir != null) report.append("\n结果已保存到: ")
                .append(new File(dir, "bench_result.txt").getAbsolutePath()).append("\n");
    }

    private void shareReport() {
        try {
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("text/plain");
            send.putExtra(Intent.EXTRA_TEXT, report.toString());
            startActivity(Intent.createChooser(send, "导出测试结果"));
        } catch (Exception e) {
            Toast.makeText(this, "分享失败: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }
}
