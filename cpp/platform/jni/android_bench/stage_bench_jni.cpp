//
// HyperLPR 四阶段逐阶段计时（Android / JNI）
//
// 目的：官方 Java SDK 只暴露 plateRecognition()，拿不到各阶段耗时；
// 这里直接在 C++ 层把 Detect / Align / Rec / Cls 四个阶段拆开计时，
// 与桌面侧 profile_baseline.py 的四阶段口径一一对应。
//
// 实现要点：
//   1. 不编译 hyperlpr / MNN / OpenCV，直接复用官方 AAR 里 libhyperlpr3.so 已导出的符号
//      （hyper::DetArch / RecognitionEngine / ClassificationEngine 与 cv::* 均在动态符号表中）；
//   2. libhyperlpr3.so 没有链接 imgcodecs（无 cv::imread / imencode），
//      因此图像由 Java 侧解码成 BGR 字节传入，切片体积也由 Java 侧 JPEG q95 编码统计；
//   3. 用 JNI_OnLoad + RegisterNatives 注册，避免包名下划线造成的函数名转义问题。
//
// 对应 Java 类：com.hyperai.example.lpr3_bench.NativeStageBench
//

#include <jni.h>
#include <android/log.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <numeric>
#include <string>
#include <vector>

#include <opencv2/opencv.hpp>

#include "nn_implementation_module/all.h"
#include "configuration.h"
#include "utils.h"

#define SB_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "StageBench", __VA_ARGS__)
#define SB_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StageBench", __VA_ARGS__)

using namespace hyper;
using clk = std::chrono::steady_clock;

static inline double ms_between(clk::time_point a, clk::time_point b) {
    return std::chrono::duration<double, std::milli>(b - a).count();
}

static std::string g_last_code;
static std::string g_last_error;
static cv::Mat g_last_patch;

struct Stat {
    std::vector<double> v;
    void add(double x) { v.push_back(x); }
    double mean() const {
        if (v.empty()) return 0.0;
        return std::accumulate(v.begin(), v.end(), 0.0) / (double) v.size();
    }
    double stddev() const {
        if (v.size() < 2) return 0.0;
        double m = mean(), s = 0.0;
        for (double x : v) s += (x - m) * (x - m);
        return std::sqrt(s / (double) (v.size() - 1));
    }
};

// 一次完整的四阶段流水线，返回各阶段毫秒
struct StageResult {
    double det = 0, align = 0, rec = 0, cls = 0;
    bool detected = false;
    std::string code;
};

static StageResult run_once(DetArch &det_arch, RecognitionEngine &rec_engine,
                            ClassificationEngine &cls_engine, const cv::Mat &image) {
    StageResult r;

    // ---------- Stage 1: Detect ----------
    auto t0 = clk::now();
    det_arch.Detection(image, true, 1.0f);
    auto t1 = clk::now();
    r.det = ms_between(t0, t1);

    if (det_arch.m_results_.empty()) return r;
    r.detected = true;
    auto &loc = det_arch.m_results_[0];

    // ---------- Stage 2: Align ----------
    cv::Mat align_image;
    auto t2 = clk::now();
    getRotateCropAndAlignPad(image, align_image, loc.kps);
    auto t3 = clk::now();
    r.align = ms_between(t2, t3);

    // ---------- Stage 3: Rec ----------
    TextLine text_line;
    text_line.code = "";
    text_line.average_score = 0.0f;
    auto t4 = clk::now();
    if (loc.layers == LayersNum::DOUBLE) {
        int line = (int) ((float) align_image.rows * 0.4f);
        int bottom_h = align_image.rows - line;
        cv::Rect_<int> top_rect(0, 0, align_image.cols, line);
        cv::Rect_<int> bottom_rect(0, line, align_image.cols, bottom_h);
        std::vector<cv::Mat> candidate = {align_image(top_rect), align_image(bottom_rect)};
        for (size_t j = 0; j < candidate.size(); ++j) {
            cv::Mat &align = candidate[j];
            cv::Mat align_pad;
            float wh_ratio = (float) align.cols / align.rows;
            imagePadding(align, align_pad, wh_ratio, rec_engine.getMInputImageSize());
            TextLine candidate_text;
            rec_engine.Inference(align_pad, candidate_text);
            text_line.code += candidate_text.code;
            text_line.average_score += candidate_text.average_score;
        }
        text_line.average_score /= (float) candidate.size();
    } else {
        cv::Mat align_image_pad;
        float wh_ratio = (float) align_image.cols / align_image.rows;
        imagePadding(align_image, align_image_pad, wh_ratio, rec_engine.getMInputImageSize());
        rec_engine.Inference(align_image_pad, text_line);
    }
    auto t5 = clk::now();
    r.rec = ms_between(t4, t5);
    r.code = text_line.code;

    // ---------- Stage 4: Cls ----------
    cv::Mat cls_image;
    auto t6 = clk::now();
    cv::resize(align_image, cls_image, cls_engine.getMInputImageSize());
    cls_engine.Inference(cls_image);
    auto t7 = clk::now();
    r.cls = ms_between(t6, t7);

    // 保留最后一次的对齐切片，交由 Java 侧做 JPEG q95 编码统计体积
    g_last_patch = align_image.clone();
    return r;
}

static jdoubleArray empty_result(JNIEnv *env) {
    double z[12] = {0};
    jdoubleArray arr = env->NewDoubleArray(12);
    env->SetDoubleArrayRegion(arr, 0, 12, z);
    return arr;
}

// nativeRun(modelDir, bgr, w, h, rounds, threads, detLevel) -> double[12]
// [0]=det_mean [1]=det_std [2]=align_mean [3]=align_std
// [4]=rec_mean [5]=rec_std [6]=cls_mean [7]=cls_std
// [8]=total_mean [9]=patch_w [10]=patch_h [11]=detected_rounds
static jdoubleArray native_run(JNIEnv *env, jclass, jstring jModelDir, jbyteArray jBgr,
                               jint w, jint h, jint rounds, jint threads, jint detLevel) {
    g_last_error.clear();
    g_last_code.clear();
    g_last_patch.release();

    const char *c_model = env->GetStringUTFChars(jModelDir, nullptr);
    std::string model_dir(c_model ? c_model : "");
    env->ReleaseStringUTFChars(jModelDir, c_model);

    jsize len = env->GetArrayLength(jBgr);
    if (len < w * h * 3) {
        g_last_error = "bgr buffer too small";
        SB_LOGE("%s", g_last_error.c_str());
        return empty_result(env);
    }
    jbyte *data = env->GetByteArrayElements(jBgr, nullptr);
    cv::Mat bgr(h, w, CV_8UC3, (unsigned char *) data);
    cv::Mat image = bgr.clone();
    env->ReleaseByteArrayElements(jBgr, data, JNI_ABORT);

    const int input_size = (detLevel == 640) ? 640 : 320;
    std::string det_backbone = model_dir + "/" +
                               (input_size == 640 ? DETECT_HIGH_BACKBONE_FILENAME : DETECT_LOW_BACKBONE_FILENAME);
    std::string det_header = model_dir + "/" +
                             (input_size == 640 ? DETECT_HIGH_HEAD_FILENAME : DETECT_LOW_HEAD_FILENAME);
    std::string cls_model = model_dir + "/" + CLS_MODEL_FILENAME;
    std::string rec_model = model_dir + "/" + REC_MODEL_FILENAME;

    DetArch det_arch;
    if (det_arch.Initialize(det_backbone, det_header, input_size, threads, 0.3f, 0.5f, false) != 0) {
        g_last_error = "det init failed: " + det_backbone;
        SB_LOGE("%s", g_last_error.c_str());
        return empty_result(env);
    }
    ClassificationEngine cls_engine;
    if (cls_engine.Initialize(cls_model, CLS_INPUT_SIZE, threads, false) != 0) {
        g_last_error = "cls init failed: " + cls_model;
        SB_LOGE("%s", g_last_error.c_str());
        return empty_result(env);
    }
    RecognitionEngine rec_engine;
    if (rec_engine.Initialize(rec_model, REC_INPUT_SIZE, threads, 0.5f, false) != 0) {
        g_last_error = "rec init failed: " + rec_model;
        SB_LOGE("%s", g_last_error.c_str());
        return empty_result(env);
    }

    // warmup
    for (int i = 0; i < 3; ++i) run_once(det_arch, rec_engine, cls_engine, image);

    Stat sdet, salign, srec, scls, stotal;
    int detected_rounds = 0;
    for (int i = 0; i < rounds; ++i) {
        StageResult r = run_once(det_arch, rec_engine, cls_engine, image);
        if (!r.detected) continue;
        detected_rounds++;
        sdet.add(r.det);
        salign.add(r.align);
        srec.add(r.rec);
        scls.add(r.cls);
        stotal.add(r.det + r.align + r.rec + r.cls);
        if (!r.code.empty()) g_last_code = r.code;
    }

    double out[12] = {0};
    out[0] = sdet.mean();   out[1] = sdet.stddev();
    out[2] = salign.mean(); out[3] = salign.stddev();
    out[4] = srec.mean();   out[5] = srec.stddev();
    out[6] = scls.mean();   out[7] = scls.stddev();
    out[8] = stotal.mean();
    out[9] = g_last_patch.empty() ? 0.0 : (double) g_last_patch.cols;
    out[10] = g_last_patch.empty() ? 0.0 : (double) g_last_patch.rows;
    out[11] = (double) detected_rounds;

    SB_LOGI("%dx%d th=%d det=%.2f align=%.2f rec=%.2f cls=%.2f total=%.2f code=%s",
            w, h, threads, out[0], out[2], out[4], out[6], out[8], g_last_code.c_str());

    jdoubleArray arr = env->NewDoubleArray(12);
    env->SetDoubleArrayRegion(arr, 0, 12, out);
    return arr;
}

static jstring native_last_code(JNIEnv *env, jclass) {
    return env->NewStringUTF(g_last_code.c_str());
}

static jstring native_last_error(JNIEnv *env, jclass) {
    return env->NewStringUTF(g_last_error.c_str());
}

// 最后一次对齐切片的宽高
static jintArray native_last_patch_size(JNIEnv *env, jclass) {
    int v[2] = {g_last_patch.empty() ? 0 : g_last_patch.cols,
                g_last_patch.empty() ? 0 : g_last_patch.rows};
    jintArray arr = env->NewIntArray(2);
    env->SetIntArrayRegion(arr, 0, 2, v);
    return arr;
}

// 最后一次对齐切片的 BGR 字节（供 Java 侧 JPEG q95 编码统计体积）
static jbyteArray native_last_patch_bytes(JNIEnv *env, jclass) {
    if (g_last_patch.empty()) return nullptr;
    size_t n = (size_t) g_last_patch.cols * g_last_patch.rows * 3;
    jbyteArray arr = env->NewByteArray((jsize) n);
    env->SetByteArrayRegion(arr, 0, (jsize) n, (const jbyte *) g_last_patch.data);
    return arr;
}

static const JNINativeMethod kMethods[] = {
        {"nativeRun",            "(Ljava/lang/String;[BIIII)[D", (void *) native_run},
        {"nativeLastCode",       "()Ljava/lang/String;",         (void *) native_last_code},
        {"nativeLastError",      "()Ljava/lang/String;",         (void *) native_last_error},
        {"nativeLastPatchSize",  "()[I",                         (void *) native_last_patch_size},
        {"nativeLastPatchBytes", "()[B",                         (void *) native_last_patch_bytes},
};

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv((void **) &env, JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
    jclass cls = env->FindClass("com/hyperai/example/lpr3_bench/NativeStageBench");
    if (cls == nullptr) {
        SB_LOGE("NativeStageBench class not found");
        return JNI_VERSION_1_6;
    }
    env->RegisterNatives(cls, kMethods, (jint) (sizeof(kMethods) / sizeof(kMethods[0])));
    SB_LOGI("StageBench natives registered");
    return JNI_VERSION_1_6;
}
