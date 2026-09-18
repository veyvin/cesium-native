include("${CMAKE_CURRENT_LIST_DIR}/shared/common.cmake")

set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME OHOS)
set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-linux-ohos")

# Chainload the OHOS NDK toolchain for all port builds.
# The NDK location is provided via the OHOS_NDK_HOME environment variable,
# which must point to the NDK "native" directory (containing llvm/ and sysroot/).
if(NOT DEFINED ENV{OHOS_NDK_HOME})
    message(FATAL_ERROR "The environment variable OHOS_NDK_HOME must be defined and point to the OHOS NDK 'native' directory (containing llvm/ and sysroot/).")
endif()
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "$ENV{OHOS_NDK_HOME}/build/cmake/ohos.toolchain.cmake")

# From Unreal Build Tool (mirrors arm64-android-unreal.cmake so that the
# vcpkg-built static libraries have a compatible ABI with the UE module):
set(VCPKG_CXX_FLAGS "-fvisibility=hidden -fvisibility-inlines-hidden")
set(VCPKG_C_FLAGS "${VCPKG_CXX_FLAGS}")

# Libraries provided by the OHOS musl libc sysroot.
set(VCPKG_SYSTEM_LIBRARIES dl m pthread rt)
