cmake_minimum_required(VERSION 3.14)
project(StageBench CXX)

# 逐阶段计时库：只编译本目录下的 JNI 源文件，
# hyper::* / cv::* / MNN 符号全部复用官方 AAR 里的 libhyperlpr3.so（其符号完整导出）。
# 因此不需要本地编译 MNN 与 OpenCV，只需它们的头文件。

set(HYPERLPR_ROOT "" CACHE PATH "HyperLPR 仓库根目录（其下需有 cpp/src）")
set(OPENCV_INC "" CACHE PATH "OpenCV Android SDK 的 sdk/native/jni/include")
set(MNN_INC "" CACHE PATH "MNN 头文件目录（MNN-x.y.z/include）")
set(PREBUILT_SDK_SO "" CACHE FILEPATH "官方 AAR 中的 libhyperlpr3.so（arm64-v8a）")

set(CMAKE_CXX_STANDARD 11)
add_definitions("-DINFERENCE_HELPER_ENABLE_MNN")

if(NOT HYPERLPR_ROOT)
    message(FATAL_ERROR "-DHYPERLPR_ROOT 必须指向 HyperLPR 仓库根目录")
endif()
if(NOT EXISTS "${PREBUILT_SDK_SO}")
    message(FATAL_ERROR "-DPREBUILT_SDK_SO 必须指向 libhyperlpr3.so")
endif()

add_library(hyperlpr3 SHARED IMPORTED)
set_target_properties(hyperlpr3 PROPERTIES IMPORTED_LOCATION "${PREBUILT_SDK_SO}")

add_library(stage_bench SHARED stage_bench_jni.cpp)

target_include_directories(stage_bench PRIVATE
        "${HYPERLPR_ROOT}/cpp/src"
        "${HYPERLPR_ROOT}/cpp/c_api"
        "${OPENCV_INC}"
        "${MNN_INC}")

target_link_libraries(stage_bench hyperlpr3 jnigraphics log)
