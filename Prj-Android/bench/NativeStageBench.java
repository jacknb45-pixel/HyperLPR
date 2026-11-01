package com.hyperai.example.lpr3_bench;

import android.graphics.Bitmap;

/**
 * 四阶段逐阶段计时的 native 入口（v5 分步版）。
 *
 * 官方 Java SDK（com.hyperai.hyperlpr3.HyperLPR3）只暴露 init / release / plateRecognition，
 * 拿不到 Detect / Align / Rec / Cls 各自的耗时。这里直接在本项目的 C++ 层
 * （cpp/platform/jni/android_bench/stage_bench_jni.cpp）把四个阶段拆开计时后通过 JNI 暴露，
 * 四个阶段的划分与流水线源码 hyper_lpr_context.cpp 的执行顺序一致。
 *
 * v5：初始化拆成 createSession / initDet / initCls / initRec 四步、推理拆成单轮 runOnce，
 * Java 侧在每步之间打日志并落盘——真机 native 崩溃（SIGSEGV 无法被 catch）时，
 * 依靠增量写盘的日志定位到具体步骤。
 *
 * 实现方式：libstage_bench.so 只编译我们自己的 JNI 源文件，hyper::* / cv::* / MNN 符号
 * 全部复用官方 AAR 中 libhyperlpr3.so 已导出的动态符号，因此不需要本地编译 MNN 与 OpenCV。
 */
public class NativeStageBench {

    private static volatile boolean loaded = false;
    private static volatile Throwable loadError = null;

    static {
        try {
            // 官方库（内含 MNN / OpenCV / hyper::* 符号），libstage_bench.so 依赖它
            try {
                System.loadLibrary("hyperlpr3");
            } catch (Throwable ignored) {
                // 可能已被 SDK 自身加载
            }
            System.loadLibrary("stage_bench");
            loaded = true;
        } catch (Throwable e) {
            loadError = e;
        }
    }

    public static boolean available() {
        return loaded;
    }

    public static Throwable loadError() {
        return loadError;
    }

    // ---------------- 生命周期 ----------------

    /** 创建会话（不含模型加载），返回句柄，0 = 失败 */
    public static native long nativeCreateSession(String modelDir);

    /** 初始化检测引擎。threads = MNN 线程数，inputSize = 320 或 640 */
    public static native boolean nativeInitDet(long handle, int threads, int inputSize);

    /** 初始化分类引擎 */
    public static native boolean nativeInitCls(long handle, int threads);

    /** 初始化识别引擎 */
    public static native boolean nativeInitRec(long handle, int threads);

    /** 销毁会话 */
    public static native void nativeDestroySession(long handle);

    // ---------------- 单轮推理 ----------------

    /**
     * 跑一轮完整四阶段流水线，返回 double[5]：
     *   [0]=det_ms [1]=align_ms [2]=rec_ms [3]=cls_ms [4]=detected(1/0)
     * 未检出时 [1]-[3] 为 0（流水线在 Detect 后即返回）。
     */
    public static native double[] nativeRunOnce(long handle, byte[] bgr, int w, int h);

    // ---------------- 状态查询 ----------------

    /** 最后一次识别出的车牌号（未识别则为空串） */
    public static native String nativeLastCode();

    /** 最后一次出错/进度信息（正常完成时为最新步骤描述） */
    public static native String nativeLastError();

    /** 最后一次对齐切片的宽高 [w, h] */
    public static native int[] nativeLastPatchSize();

    /** 最后一次对齐切片的 BGR 字节 */
    public static native byte[] nativeLastPatchBytes();

    /** ARGB_8888 Bitmap -> BGR byte[]（OpenCV 默认通道顺序） */
    public static byte[] toBgr(Bitmap bmp) {
        int w = bmp.getWidth();
        int h = bmp.getHeight();
        int[] argb = new int[w * h];
        bmp.getPixels(argb, 0, w, 0, 0, w, h);
        byte[] out = new byte[w * h * 3];
        for (int i = 0; i < argb.length; i++) {
            int c = argb[i];
            out[i * 3 + 0] = (byte) (c & 0xFF);          // B
            out[i * 3 + 1] = (byte) ((c >> 8) & 0xFF);   // G
            out[i * 3 + 2] = (byte) ((c >> 16) & 0xFF);  // R
        }
        return out;
    }

    /** BGR byte[] -> ARGB_8888 Bitmap */
    public static Bitmap fromBgr(byte[] bgr, int w, int h) {
        int[] argb = new int[w * h];
        for (int i = 0; i < argb.length; i++) {
            int b = bgr[i * 3 + 0] & 0xFF;
            int g = bgr[i * 3 + 1] & 0xFF;
            int r = bgr[i * 3 + 2] & 0xFF;
            argb[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
        }
        return Bitmap.createBitmap(argb, w, h, Bitmap.Config.ARGB_8888);
    }
}
