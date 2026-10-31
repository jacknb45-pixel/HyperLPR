package com.hyperai.example.lpr3_demo;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
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

import java.io.File;
import java.io.FileOutputStream;
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
 * 测量口径：plateRecognition() 单次墙钟耗时。官方 SDK 只暴露这一个整体接口
 * （javap 确认：HyperLPR3 仅有 init / release / plateRecognition），无法直接
 * 逐阶段计时，因此阶段分解采用差分法：
 *   - CNN 推理耗时由 FLOPs 决定，与图像内容无关（这是差分法成立的前提）；
 *   - 无车牌的对照图 -> 检测无框 -> 流水线在 Detect 后立即返回 -> 耗时 = Detect；
 *   - 含车牌的原图   -> 耗时 = Detect + Align + Rec + Cls；
 *   - 两者相减得 Align+Rec+Cls，其中 Align 为几何透视变换（纯 CPU，桌面实测占 0.7%）。
 * 用两张不同性质的对照图（纯色 / 原图遮蔽）互检：若二者接近，说明内容无关性成立。
 */
public class BenchActivity extends AppCompatActivity {

    private static final String TAG = "HyperLPR-Bench";
    private static final int ROUNDS = 20;
    private static final int ROUNDS_SWEEP = 10;
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
        tip.setText("测试图片已内置，无需选图、无需权限。点开始，跑完可分享结果。全程约 2 分钟。");
        tip.setTextSize(12f);
        root.addView(tip);

        runBtn = new Button(this);
        runBtn.setText("开始测试");
        root.addView(runBtn);

        shareBtn = new Button(this);
        shareBtn.setText("分享 / 导出结果");
        shareBtn.setEnabled(false);
        root.addView(shareBtn);

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

        resultView.setText(deviceInfo() + "\n点击上方按钮开始测试。");
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
                phaseA();
                phaseB();
                phaseC();
                phaseD();
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
            appendLine("口径: 每次计时均为 plateRecognition() 单次墙钟耗时, 不含图片解码与界面绘制;");
            appendLine("      warmup 1 次不计入统计; 计时用 System.nanoTime()。");

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

    /** A. 自然场景图端到端 */
    private void phaseA() {
        String[] names = {"test_img.jpg", "2.jpg"};
        appendLine("");
        appendLine("===== A. 自然场景图 端到端（端侧 MNN，默认线程）=====");
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

    /** B. 阶段分解（差分法） */
    private void phaseB() {
        appendLine("");
        appendLine("===== B. 阶段耗时分解（差分法，真机实测）=====");
        appendLine("原理: CNN 推理耗时由 FLOPs 决定、与图像内容无关, 故");
        appendLine("  Detect   = 无车牌对照图耗时(检测无框 -> 流水线立即返回)");
        appendLine("  Align+Rec+Cls = 含车牌原图耗时 - Detect");
        appendLine("  其中 Align 为几何透视变换(纯 CPU), 桌面实测占 0.7%, 端侧约 1 ms");
        appendLine(HEAD);

        Stat g = null, m = null, t = null;
        Bitmap bg = load("ctrl_gray_1920.jpg");
        if (bg != null) { g = measure(bg, ROUNDS); appendLine(row("ctrl_gray_1920", g, ROUNDS)); bg.recycle(); }
        Bitmap bm = load("ctrl_masked_1920.jpg");
        if (bm != null) { m = measure(bm, ROUNDS); appendLine(row("ctrl_masked_1920", m, ROUNDS)); bm.recycle(); }
        Bitmap bt = load("test_img.jpg");
        if (bt != null) { t = measure(bt, ROUNDS); appendLine(row("test_img.jpg", t, ROUNDS)); bt.recycle(); }

        if (g != null && m != null) {
            appendLine(String.format(Locale.US, "方法自检: 两组对照图差值 %.2f ms (纯色 vs 遮蔽)",
                    Math.abs(g.mean - m.mean)));
            appendLine("          差值接近 0 说明\"耗时与图像内容无关\"成立, 差分法有效");
        }
        if (t != null && (g != null || m != null)) {
            double det = (g != null && m != null) ? (g.mean + m.mean) / 2.0
                    : (g != null ? g.mean : m.mean);
            double rest = t.mean - det;
            appendLine(String.format(Locale.US, "  => Detect        ≈ %.2f ms (占 %.1f%%)", det, det / t.mean * 100));
            appendLine(String.format(Locale.US, "  => Align+Rec+Cls ≈ %.2f ms (占 %.1f%%)", rest, rest / t.mean * 100));
            appendLine(String.format(Locale.US, "     (其中 Align ≈ 1 ms, 故 Rec+Cls ≈ %.2f ms)", rest - 1.0));
        }
    }

    /** C. 线程数扫描：回答移动端部署该配几个线程 */
    private void phaseC() {
        appendLine("");
        appendLine("===== C. 线程数扫描（端侧 MNN，test_img.jpg）=====");
        appendLine("口径: 每个线程档重新 init, 1 次 warmup + " + ROUNDS_SWEEP + " 轮");
        appendLine(String.format(Locale.US, "%-10s %10s %12s", "threads", "均值ms", "相对1线程加速"));
        double base = 0;
        for (int th : THREAD_SWEEP) {
            try {
                try { HyperLPR3.getInstance().release(); } catch (Exception ignored) { }
                initEngine(th);
                Bitmap bmp = load("test_img.jpg");
                if (bmp == null) { appendLine(th + " 加载失败"); continue; }
                Stat st = measure(bmp, ROUNDS_SWEEP);
                bmp.recycle();
                if (th == 1) base = st.mean;
                double speed = (base > 0) ? base / st.mean : 0;
                appendLine(String.format(Locale.US, "%-10d %10.2f %12.2fx", th, st.mean, speed));
            } catch (Throwable e) {
                appendLine(th + " 线程档失败: " + e);
            }
        }
        appendLine("说明: 桌面 ONNXRuntime 默认多线程曾占满整机(约 31 等效核心);");
        appendLine("      本组数据用于确定真机上的线程-时延权衡。");
    }

    /** D. 参考组：仓库内其余图像（流水线中间产物/调试小图，非自然场景） */
    private void phaseD() {
        String[] names = {"1.jpg", "pre.jpg", "a.jpg", "pad.jpg", "align.jpg"};
        appendLine("");
        appendLine("===== D. 参考组：非自然场景图（中间产物/调试图，仅供交叉验证）=====");
        appendLine("注意: 这些是流水线中间产物或裁剪切片, 不代表真实输入;");
        appendLine("      \"未识别\"样本的耗时即 Detect(+Align 前) 的量级, 可与 B 组互证。");
        appendLine(HEAD);
        for (String n : names) {
            Bitmap bmp = load(n);
            if (bmp == null) { continue; }
            Stat st = measure(bmp, ROUNDS_SWEEP);
            appendLine(row(n, st, ROUNDS_SWEEP));
            bmp.recycle();
        }
    }

    // ---------------------------------------------------------------- 工具

    private void appendLine(String line) {
        report.append(line).append("\n");
        String snapshot = report.toString();
        ui.post(() -> resultView.setText(snapshot));
    }

    private void saveToFile(String text) {
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) dir = getFilesDir();
            if (!dir.exists()) dir.mkdirs();
            File f = new File(dir, "bench_result.txt");
            OutputStream os = new FileOutputStream(f, false);
            os.write(text.getBytes("UTF-8"));
            os.close();
            report.append("\n结果已保存到: ").append(f.getAbsolutePath()).append("\n");
        } catch (Exception e) {
            report.append("\n保存失败: ").append(e.getMessage()).append("\n");
        }
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
