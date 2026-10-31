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
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * 端侧（Android）性能基准测试界面。
 *
 * 设计目标：不需要 USB 调试、不需要存储权限、不需要手动选图。
 * 测试图片内置在 assets/plates 中，打开即测，结果直接显示在屏幕上，
 * 同时写入应用私有目录并支持通过系统分享导出。
 *
 * 测量口径：plateRecognition() 的单次墙钟耗时 = Detect + Align + Rec + Cls 四阶段总和。
 * 每张图先跑 1 次 warmup（不计入统计），再跑 ROUNDS 次取均值/中位数/最小/最大。
 */
public class BenchActivity extends AppCompatActivity {

    private static final String TAG = "HyperLPR-Bench";
    private static final int ROUNDS = 20;

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
        tip.setText("测试图片已内置，无需选图、无需权限。点开始，跑完可分享结果。");
        tip.setTextSize(12f);
        root.addView(tip);

        runBtn = new Button(this);
        runBtn.setText("开始测试（每张 " + ROUNDS + " 轮）");
        root.addView(runBtn);

        shareBtn = new Button(this);
        shareBtn.setText("分享 / 导出结果");
        shareBtn.setEnabled(false);
        root.addView(shareBtn);

        resultView = new TextView(this);
        resultView.setTypeface(Typeface.MONOSPACE);
        resultView.setTextSize(11f);
        resultView.setTextIsSelectable(true);
        ScrollView sv = new ScrollView(this);
        sv.addView(resultView);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        root.addView(sv, lp);

        setContentView(root);

        HyperLPRParameter parameter = new HyperLPRParameter()
                .setDetLevel(HyperLPR3.DETECT_LEVEL_LOW)
                .setMaxNum(1)
                .setRecConfidenceThreshold(0.85f);
        HyperLPR3.getInstance().init(this, parameter);

        runBtn.setOnClickListener(v -> runBench());
        shareBtn.setOnClickListener(v -> shareReport());

        resultView.setText(deviceInfo() + "\n点击上方按钮开始测试。");
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

    private void runBench() {
        if (running) return;
        running = true;
        runBtn.setEnabled(false);
        shareBtn.setEnabled(false);

        report.setLength(0);
        report.append(deviceInfo()).append("\n");
        report.append("===== 端侧基线（四阶段合计）=====\n");
        report.append("口径: plateRecognition() 单次墙钟耗时, 每张图 1 次 warmup + ")
              .append(ROUNDS).append(" 轮统计\n");
        report.append(String.format(Locale.US, "%-14s %-11s %6s %8s %8s %8s %8s  %s%n",
                "图片", "分辨率", "轮次", "均值ms", "中位ms", "最小ms", "最大ms", "识别结果"));
        resultView.setText(report.toString());

        new Thread(() -> {
            List<Double> allMeans = new ArrayList<>();
            try {
                String[] names = getAssets().list("plates");
                Arrays.sort(names);
                for (String name : names) {
                    String lower = name.toLowerCase(Locale.US);
                    if (!lower.endsWith(".jpg") && !lower.endsWith(".jpeg") && !lower.endsWith(".png")) {
                        continue;
                    }
                    Bitmap bmp;
                    try {
                        bmp = BitmapFactory.decodeStream(getAssets().open("plates/" + name));
                    } catch (Exception e) {
                        appendLine(name + " 解码失败: " + e.getMessage());
                        continue;
                    }
                    if (bmp == null) {
                        appendLine(name + " 解码为空");
                        continue;
                    }
                    final int w = bmp.getWidth();
                    final int h = bmp.getHeight();

                    // warmup（不计入统计）
                    try {
                        HyperLPR3.getInstance().plateRecognition(bmp,
                                HyperLPR3.CAMERA_ROTATION_0, HyperLPR3.STREAM_BGRA);
                    } catch (Exception ignored) {
                    }

                    List<Double> samples = new ArrayList<>();
                    String plateTxt = "未识别到车牌";
                    for (int i = 0; i < ROUNDS; i++) {
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
                            plateTxt = p.getCode() + "[" + type + "]";
                        }
                    }
                    bmp.recycle();

                    List<Double> sorted = new ArrayList<>(samples);
                    Collections.sort(sorted);
                    double mean = mean(samples);
                    double median = sorted.get(sorted.size() / 2);
                    double min = sorted.get(0);
                    double max = sorted.get(sorted.size() - 1);
                    allMeans.add(mean);

                    appendLine(String.format(Locale.US, "%-14s %-11s %6d %8.2f %8.2f %8.2f %8.2f  %s",
                            name, w + "x" + h, ROUNDS, mean, median, min, max, plateTxt));
                }
            } catch (Exception e) {
                appendLine("ERROR: " + e);
                Log.e(TAG, "bench failed", e);
            }

            // 内存采样
            int pssKb = 0;
            try {
                Debug.MemoryInfo mi = new Debug.MemoryInfo();
                Debug.getMemoryInfo(mi);
                pssKb = mi.getTotalPss();
            } catch (Exception ignored) {
            }

            double overall = allMeans.isEmpty() ? 0 : mean(allMeans);
            appendLine("");
            appendLine("----- 汇总 -----");
            appendLine("参与统计的图片数: " + allMeans.size());
            appendLine(String.format(Locale.US, "各图均值再平均: %.2f ms", overall));
            appendLine("进程 PSS(测试后采样): " + pssKb + " KB (" + String.format(Locale.US, "%.1f", pssKb / 1024.0) + " MB)");
            appendLine("说明: 单张耗时 = Detect + Align + Rec + Cls 四阶段总耗时; "
                    + "不含图片解码与界面绘制。");

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

    private double mean(List<Double> xs) {
        if (xs.isEmpty()) return 0;
        double s = 0;
        for (double x : xs) s += x;
        return s / xs.size();
    }

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
