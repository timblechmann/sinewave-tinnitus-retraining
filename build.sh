#!/bin/bash

set -e

# Parse build mode argument (default: debug)
BUILD_MODE=${1:-debug}

if [ "$BUILD_MODE" != "debug" ] && [ "$BUILD_MODE" != "release" ]; then
    echo "Usage: $0 [debug|release]"
    echo "  debug   - Build in debug mode (default)"
    echo "  release - Build in release mode"
    exit 1
fi

export ANDROID_NDK_ROOT="/opt/homebrew/share/android-commandlinetools/ndk/27.2.12479018"

echo "Building Rust library for Android ($BUILD_MODE mode)..."
if [ "$BUILD_MODE" = "release" ]; then
    cargo ndk -t arm64-v8a -P 26 build --release
    RUST_LIB_PATH="target/aarch64-linux-android/release/libsinewave_tinnitus_retraining_audio_core.so"
else
    cargo ndk -t arm64-v8a -P 26 build
    RUST_LIB_PATH="target/aarch64-linux-android/debug/libsinewave_tinnitus_retraining_audio_core.so"
fi

echo "Copying Rust library to Flutter JNI libs..."
cp "$RUST_LIB_PATH" sinewave_tinnitus_retraining/android/app/src/main/jniLibs/arm64-v8a/

echo "Copying libc++_shared.so to Flutter JNI libs..."
# Assuming NDK is installed via Homebrew
LIBCPP_PATH="/opt/homebrew/share/android-commandlinetools/ndk/27.2.12479018/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
if [ -f "$LIBCPP_PATH" ]; then
    cp "$LIBCPP_PATH" sinewave_tinnitus_retraining/android/app/src/main/jniLibs/arm64-v8a/
else
    echo "Error: libc++_shared.so not found at $LIBCPP_PATH. Please ensure Android NDK is installed via Homebrew."
    exit 1
fi

echo "Building Flutter $BUILD_MODE APK for arm64-v8a..."
cd sinewave_tinnitus_retraining
if [ "$BUILD_MODE" = "release" ]; then
    flutter build apk --target-platform android-arm64 --release
    APK_PATH="sinewave_tinnitus_retraining/build/app/outputs/flutter-apk/app-release.apk"
else
    flutter build apk --target-platform android-arm64 --debug
    APK_PATH="sinewave_tinnitus_retraining/build/app/outputs/flutter-apk/app-debug.apk"
fi
cd ..

echo "Build complete. APK available at $APK_PATH"
