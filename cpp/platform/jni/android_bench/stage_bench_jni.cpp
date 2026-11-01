//
// HyperLPR 四阶段逐阶段计时（Android / JNI）—— v5 分步初始化版
//
// 目的：官方 Java SDK 只暴露 plateRecognition()，拿不到各阶段耗时；
// 这里直接在 C++ 层把 Detect / Align / Rec / Cls 四个阶段拆开计时，
// 与桌面侧 profile_baseline.py 的四阶段口径一一对应。
//
// v5 变更（针对真机 native SIGSEGV 无法定位的问题）：
//   1. 引擎初始化拆成 nativeCreateSession / nativeInitDet / nativeInitCls / nativeInitRec
//      独立 JNI 调用，Java 侧在每步之间输出日志并落盘——崩溃时能精确定位到哪一步；
//   2. 推理拆成单轮 nativeRunOnce，Java 侧控制 warmup 与统计循环；
//   3. 其余同 v3：不编译 hyperlpr / MNN / OpenCV，直接复用官方 AAR 里
//      libhyperlpr3.so 已导出的符号；图像由 Java 侧解码成 BGR 传入
//      （官方库没链 imgcodecs，无 cv::imread）；
//   4. 用 JNI_OnLoad + RegisterNatives 注册，避开包名下划线的函数名转义问题。
//
// 对应 Java 类：com.hyperai.example.lpr3_bench.NativeStageBench
//

#include <jni.h>
#include <android/log.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <new>
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

// 一次完整的四阶段流水线，返回各阶段毫秒
struct StageResult {
    double det = 0, align = 0, rec = 0, cls = 0;
    bool detected = false;
    std::string code;
};

// 会话：三个引擎 + 配置。生命周期完全由 Java 侧 create/destroy 控制，
// 任何一步初始化失败都能从 Java 日志里看到是哪个引擎。
struct BenchSession {
    std::string model_dir;
    int det_input_size = 320;
    bool det_ready = false;
    bool cls_ready = false;
    bool rec_ready = false;
    DetArch det;
    ClassificationEngine cls;
    RecognitionEngine rec;
};

static StageResult run_once(BenchSession &s, const cv::Mat &image) {
    StageResult r;

    // ---------- Stage 1: Detect ----------
    auto t0 = clk::now();
    s.det.Detection(image, true, 1.0f);
    auto t1 = clk::now();
    r.det = ms_between(t0, t1);

    if (s.det.m_results_.empty()) return r;
    r.detected = true;
    auto &loc = s.det.m_results_[0];

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
            imagePadding(align, align_pad, wh_ratio, s.rec.getMInputImageSize());
            TextLine candidate_text;
            s.rec.Inference(align_pad, candidate_text);
            text_line.code += candidate_text.code;
            text_line.average_score += candidate_text.average_score;
        }
        text_line.average_score /= (float) candidate.size();
    } else {
        cv::Mat align_image_pad;
        float wh_ratio = (float) align_image.cols / align_image.rows;
        imagePadding(align_image, align_image_pad, wh_ratio, s.rec.getMInputImageSize());
        s.rec.Inference(align_image_pad, text_line);
    }
    auto t5 = clk::now();
    r.rec = ms_between(t4, t5);
    r.code = text_line.code;

    // ---------- Stage 4: Cls ----------
    cv::Mat cls_image;
    auto t6 = clk::now();
    cv::resize(align_image, cls_image, s.cls.getMInputImageSize());
    s.cls.Inference(cls_image);
    auto t7 = clk::now();
    r.cls = ms_between(t6, t7);

    // 保留最后一次的对齐切片，交由 Java 侧做 JPEG q95 编码统计体积
    g_last_patch = align_image.clone();
    return r;
}

static BenchSession *as_session(jlong h) {
    return reinterpret_cast<BenchSession *>(h);
}

// ---------- 生命周期 ----------

// nativeCreateSession(modelDir) -> handle（0 = 失败）
static jlong native_create_session(JNIEnv *env, jclass, jstring jModelDir) {
    g_last_error.clear();
    g_last_code.clear();
    g_last_patch.release();

    const char *c_model = env->GetStringUTFChars(jModelDir, nullptr);
    std::string model_dir(c_model ? c_model : "");
    env->ReleaseStringUTFChars(jModelDir, c_model);

    BenchSession *s = new (std::nothrow) BenchSession();
    if (s == nullptr) {
        g_last_error = "session alloc failed";
        return 0;
    }
    s->model_dir = model_dir;
    g_last_error = "session created";
    SB_LOGI("session created: %s", model_dir.c_str());
    return reinterpret_cast<jlong>(s);
}

// nativeInitDet(handle, threads, inputSize) -> bool
static jboolean native_init_det(JNIEnv *env, jclass, jlong h, jint threads, jint inputSize) {
    BenchSession *s = as_session(h);
    if (s == nullptr || s->det_ready) return JNI_FALSE;
    s->det_input_size = (inputSize == 640) ? 640 : 320;
    std::string backbone = s->model_dir + "/" +
                           (s->det_input_size == 640 ? DETECT_HIGH_BACKBONE_FILENAME
                                                     : DETECT_LOW_BACKBONE_FILENAME);
    std::string header = s->model_dir + "/" +
                         (s->det_input_size == 640 ? DETECT_HIGH_HEAD_FILENAME
                                                   : DETECT_LOW_HEAD_FILENAME);
    g_last_error = "init det: calling Initialize...";
    SB_LOGI("init det: %s threads=%d", backbone.c_str(), threads);
    int ret = s->det.Initialize(backbone, header, s->det_input_size, threads, 0.3f, 0.5f, false);
    if (ret != 0) {
        g_last_error = "det init failed: " + backbone;
        SB_LOGE("%s", g_last_error.c_str());
        return JNI_FALSE;
    }
    s->det_ready = true;
    g_last_error = "det init ok";
    return JNI_TRUE;
}

// nativeInitCls(handle, threads) -> bool
static jboolean native_init_cls(JNIEnv *env, jclass, jlong h, jint threads) {
    BenchSession *s = as_session(h);
    if (s == nullptr || s->cls_ready) return JNI_FALSE;
    std::string model = s->model_dir + "/" + CLS_MODEL_FILENAME;
    g_last_error = "init cls: calling Initialize...";
    SB_LOGI("init cls: %s threads=%d", model.c_str(), threads);
    int ret = s->cls.Initialize(model, CLS_INPUT_SIZE, threads, false);
    if (ret != 0) {
        g_last_error = "cls init failed: " + model;
        SB_LOGE("%s", g_last_error.c_str());
        return JNI_FALSE;
    }
    s->cls_ready = true;
    g_last_error = "cls init ok";
    return JNI_TRUE;
}

// nativeInitRec(handle, threads) -> bool
static jboolean native_init_rec(JNIEnv *env, jclass, jlong h, jint threads) {
    BenchSession *s = as_session(h);
    if (s == nullptr || s->rec_ready) return JNI_FALSE;
    std::string model = s->model_dir + "/" + REC_MODEL_FILENAME;
    g_last_error = "init rec: calling Initialize...";
    SB_LOGI("init rec: %s threads=%d", model.c_str(), threads);
    int ret = s->rec.Initialize(model, REC_INPUT_SIZE, threads, 0.5f, false);
    if (ret != 0) {
        g_last_error = "rec init failed: " + model;
        SB_LOGE("%s", g_last_error.c_str());
        return JNI_FALSE;
    }
    s->rec_ready = true;
    g_last_error = "rec init ok";
    return JNI_TRUE;
}

// nativeDestroySession(handle)
static void native_destroy_session(JNIEnv *env, jclass, jlong h) {
    BenchSession *s = as_session(h);
    if (s == nullptr) return;
    delete s;
    g_last_error = "session destroyed";
    SB_LOGI("session destroyed");
}

// ---------- 单轮推理 ----------

// nativeRunOnce(handle, bgr, w, h) -> double[5] {det_ms, align_ms, rec_ms, cls_ms, detected}
static jdoubleArray native_run_once(JNIEnv *env, jclass, jlong h, jbyteArray jBgr,
                                    jint w, jint hgt) {
    BenchSession *s = as_session(h);
    double out[5] = {0, 0, 0, 0, 0};
    if (s == nullptr) {
        g_last_error = "invalid session handle";
        jdoubleArray arr = env->NewDoubleArray(5);
        env->SetDoubleArrayRegion(arr, 0, 5, out);
        return arr;
    }
    if (!s->det_ready || !s->rec_ready || !s->cls_ready) {
        g_last_error = "engines not ready (det/cls/rec)";
        jdoubleArray arr = env->NewDoubleArray(5);
        env->SetDoubleArrayRegion(arr, 0, 5, out);
        return arr;
    }

    jsize len = env->GetArrayLength(jBgr);
    if (len < w * hgt * 3) {
        g_last_error = "bgr buffer too small";
        jdoubleArray arr = env->NewDoubleArray(5);
        env->SetDoubleArrayRegion(arr, 0, 5, out);
        return arr;
    }
    jbyte *data = env->GetByteArrayElements(jBgr, nullptr);
    cv::Mat bgr(hgt, w, CV_8UC3, (unsigned char *) data);
    cv::Mat image = bgr.clone();   // 拷贝一份，避免持有 JNI 缓冲
    env->ReleaseByteArrayElements(jBgr, data, JNI_ABORT);

    StageResult r = run_once(*s, image);
    if (!r.code.empty()) g_last_code = r.code;

    out[0] = r.det;
    out[1] = r.align;
    out[2] = r.rec;
    out[3] = r.cls;
    out[4] = r.detected ? 1.0 : 0.0;

    jdoubleArray arr = env->NewDoubleArray(5);
    env->SetDoubleArrayRegion(arr, 0, 5, out);
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
        {"nativeCreateSession",   "(Ljava/lang/String;)J",        (void *) native_create_session},
        {"nativeInitDet",         "(JII)Z",                       (void *) native_init_det},
        {"nativeInitCls",         "(JI)Z",                        (void *) native_init_cls},
        {"nativeInitRec",         "(JI)Z",                        (void *) native_init_rec},
        {"nativeRunOnce",         "(J[BII)[D",                    (void *) native_run_once},
        {"nativeDestroySession",  "(J)V",                         (void *) native_destroy_session},
        {"nativeLastCode",        "()Ljava/lang/String;",         (void *) native_last_code},
        {"nativeLastError",       "()Ljava/lang/String;",         (void *) native_last_error},
        {"nativeLastPatchSize",   "()[I",                         (void *) native_last_patch_size},
        {"nativeLastPatchBytes",  "()[B",                         (void *) native_last_patch_bytes},
};

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv((void **) &env, JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
    jclass cls = env->FindClass("com/hyperai/example/lpr3_bench/NativeStageBench");
    if (cls == nullptr) {
        SB_LOGE("NativeStageBench class not found");
        return JNI_ERR;   // 注册失败要让 loadLibrary 抛异常，而不是静默降级
    }
    if (env->RegisterNatives(cls, kMethods,
                             (jint) (sizeof(kMethods) / sizeof(kMethods[0]))) != JNI_OK) {
        SB_LOGE("RegisterNatives failed");
        return JNI_ERR;
    }
    SB_LOGI("StageBench natives registered");
    return JNI_VERSION_1_6;
}
