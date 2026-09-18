# Toolchain for building cesium-native for HarmonyOS (OHOS) arm64 for use
# with Unreal Engine. This is the HarmonyOS analogue of cesium-unreal's
# unreal-android-toolchain.cmake.
#
# The environment variable OHOS_NDK_HOME must be set to the OHOS NDK
# "native" directory (the one containing llvm/ and sysroot/), e.g.:
#   set OHOS_NDK_HOME=C:\ohos-ndk\native
#
# Usage:
#   cmake -G Ninja ^
#     -DCMAKE_TOOLCHAIN_FILE=<repo>/harmonyos/unreal-ohos-toolchain.cmake ^
#     -DCMAKE_BUILD_TYPE=Release ^
#     <repo>/harmonyos

if(NOT DEFINED ENV{OHOS_NDK_HOME})
    message(FATAL_ERROR "The environment variable OHOS_NDK_HOME must be defined and point to the OHOS NDK 'native' directory (containing llvm/ and sysroot/).")
endif()

file(TO_CMAKE_PATH "$ENV{OHOS_NDK_HOME}" _OHOS_NDK_HOME)
include("${_OHOS_NDK_HOME}/build/cmake/ohos.toolchain.cmake")

# cpp-httplib: don't use OpenSSL even if it is available. Unreal Engine links
# its own copy of OpenSSL and we must not pull in a second one.
set(HTTPLIB_USE_OPENSSL_IF_AVAILABLE OFF)
