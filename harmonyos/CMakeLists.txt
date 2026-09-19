# Build cesium-native (plus the libraries needed by Cesium for Unreal) for
# HarmonyOS (OHOS) arm64, for linking into an Unreal Engine HarmonyOS game.
#
# This is the HarmonyOS analogue of cesium-unreal's extern/CMakeLists.txt.
# It adds the cesium-native repository root (the parent of this directory)
# as a subdirectory, so all of cesium-native's own build logic is used
# unchanged.
#
# Required environment variables:
#   OHOS_NDK_HOME       The OHOS NDK "native" directory (llvm/, sysroot/).
#   UNREAL_ENGINE_ROOT  Root of the Unreal Engine installation (or of a
#                       directory laid out like one). Used by the openssl
#                       overlay port to find UE's prebuilt OpenSSL. On
#                       CI, harmonyos/unreal-engine-root in this repo is
#                       used, which contains the OpenSSL subset that UE
#                       reuses from Android for HarmonyOS.
#
# Usage:
#   cmake -G Ninja ^
#     -DCMAKE_TOOLCHAIN_FILE=%~dp0unreal-ohos-toolchain.cmake ^
#     -DCMAKE_BUILD_TYPE=Release ^
#     %~dp0..
#   cmake --build . --target install
#
# Artifacts are installed to harmonyos/install:
#   lib/HarmonyOS-aarch64-Release/*.a  (matches the directory name that
#       CesiumRuntime.Build.cs expects for the HarmonyOS platform)
#   include/...                        (headers for the UE plugin)

cmake_minimum_required(VERSION 3.15)

project(
    cesium-native-for-harmonyos
    VERSION 0.1.0
    LANGUAGES CXX C
)

if (NOT "${CMAKE_SYSTEM_NAME}" STREQUAL "OHOS")
    message(FATAL_ERROR "This project must be configured for HarmonyOS. Pass -DCMAKE_TOOLCHAIN_FILE=${CMAKE_CURRENT_LIST_DIR}/unreal-ohos-toolchain.cmake and set the OHOS_NDK_HOME environment variable.")
endif()

if (NOT "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "aarch64")
    message(FATAL_ERROR "This build only supports the arm64-v8a (aarch64) ABI. Set -DOHOS_ARCH=arm64-v8a.")
endif()

if (DEFINED ENV{UNREAL_ENGINE_ROOT} AND NOT UNREAL_ENGINE_ROOT)
  set(UNREAL_ENGINE_ROOT "$ENV{UNREAL_ENGINE_ROOT}")
endif()

if (NOT UNREAL_ENGINE_ROOT)
  message(FATAL_ERROR "Please specify the root of your Unreal Engine installation, either by setting the UNREAL_ENGINE_ROOT environment variable or with -DUNREAL_ENGINE_ROOT=path on the cmake command-line.")
endif()

message(STATUS "Using Unreal Engine installation at: ${UNREAL_ENGINE_ROOT}")

# Set the UE environment variable so it's inherited by vcpkg builds (the
# openssl overlay port uses it to locate UE's prebuilt OpenSSL).
set(ENV{UNREAL_ENGINE_ROOT} "${UNREAL_ENGINE_ROOT}")

set(CESIUM_ARCHITECTURE "aarch64")
set(HTTPLIB_USE_OPENSSL_IF_AVAILABLE OFF)

# Rename sqlite3* symbols to cesium_sqlite3* so they don't conflict with UE's sqlite3,
# which has a bunch of limitations and is not considered public.
set(PRIVATE_CESIUM_SQLITE ON)

# Install to harmonyos/install. The lib directory name matches what
# CesiumRuntime.Build.cs expects on HarmonyOS (HarmonyOS-aarch64-Release),
# analogous to Android-aarch64-Release on Android.
set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_LIST_DIR}/install)
set(CMAKE_INSTALL_LIBDIR ${CMAKE_INSTALL_PREFIX}/lib/HarmonyOS-aarch64-$<IF:$<CONFIG:Debug>,Debug,Release>)

# Always define NDEBUG, since Unreal does in debug anyway.
# We don't want any mismatches, especially with class member ordering.
# But still let debug builds force assertions.
add_compile_definitions(NDEBUG $<$<CONFIG:Debug>:CESIUM_FORCE_ASSERTIONS>)

# Like on Android, Unreal uses hidden visibility on HarmonyOS.
# Keep RTTI enabled: UE 5.x builds game modules with RTTI (bUseRTTI), and the
# plugin's dynamic_cast/typeinfo references must resolve against these libs.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")

# vcpkg setup
set(ENV{VCPKG_OVERLAY_PORTS} "${CMAKE_CURRENT_LIST_DIR}/vcpkg-overlays")
set(ENV{VCPKG_OVERLAY_TRIPLETS} "${CMAKE_CURRENT_LIST_DIR}/vcpkg-overlays/triplets")

# Use our custom OHOS triplet, which chainloads the OHOS NDK toolchain for
# all vcpkg port builds (see vcpkg-overlays/triplets/arm64-ohos-unreal.cmake).
set(VCPKG_TRIPLET "arm64-ohos-unreal")

# Our OpenSSL is part of Unreal Engine, so need to install it.
set(CESIUM_EXCLUDE_INSTALL_HEADERS openssl)
set(CESIUM_EXCLUDE_INSTALL_STATIC_LIBS openssl)
# Skip including curl asset accessor as it causes issues on Android and iOS
set(CESIUM_DISABLE_CURL TRUE)

# The OHOS toolchain passes --gcc-toolchain (via
# CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN), which clang reports as an unused
# argument during compilation; under -Werror (COMPILE_WARNING_AS_ERROR) this
# fails every single TU. The port to HarmonyOS may also trip other warnings
# in system headers that upstream CI has never seen, so treat warnings as
# warnings for this build.
set(CESIUM_DISABLE_WARNINGS_AS_ERRORS TRUE)

# Add the cesium-native repository root (the parent of this directory) as a
# subdirectory, exactly like cesium-unreal's extern/CMakeLists.txt adds
# extern/cesium-native.
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/.. cesium-native-root)

# Unreal Engine doesn't include MikkTSpace on Android, iOS, or HarmonyOS.
# So add our own. The dependency is cloned to harmonyos/extern/MikkTSpace
# at the same commit as cesium-unreal's submodule.
add_library(MikkTSpace ${CMAKE_CURRENT_LIST_DIR}/extern/MikkTSpace/mikktspace.c)
set_target_properties(MikkTSpace PROPERTIES PUBLIC_HEADER "${CMAKE_CURRENT_LIST_DIR}/extern/MikkTSpace/mikktspace.h")
target_include_directories(MikkTSpace PUBLIC ${CMAKE_CURRENT_LIST_DIR}/extern/MikkTSpace)
install(TARGETS MikkTSpace
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mikktspace
)

option(BUILD_SHARED_LIB OFF)
option(SUPPORT_CONSOLE_APP OFF)
set(LIB_INSTALL_DIR ${CMAKE_INSTALL_LIBDIR})
set(CMAKE_POLICY_VERSION_MINIMUM "3.5")
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/extern/tidy-html5 tidy-html5)

# Don't build the cesium-native tests by default
if (TARGET cesium-native-tests)
    set_target_properties(cesium-native-tests PROPERTIES EXCLUDE_FROM_ALL 1 EXCLUDE_FROM_DEFAULT_BUILD 1)
endif()

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/extern/swl-variant swl-variant)
install(DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/extern/swl-variant/include/" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
