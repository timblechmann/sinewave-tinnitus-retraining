#!/bin/bash

set -e

# Define target architectures
TARGET_ARM="aarch64-apple-darwin"
TARGET_INTEL="x86_64-apple-darwin"

# Build for Apple Silicon
echo "Building Rust dynamic library for $TARGET_ARM..."
cargo build --release --target $TARGET_ARM

# Build for Intel
echo "Building Rust dynamic library for $TARGET_INTEL..."
cargo build --release --target $TARGET_INTEL

# Create universal dynamic library using lipo
UNIVERSAL_LIB_DIR="target/universal-macos"
UNIVERSAL_LIB_PATH="$UNIVERSAL_LIB_DIR/libsinewave_tinnitus_retraining_audio_core.dylib"

echo "Creating universal dynamic library..."
mkdir -p $UNIVERSAL_LIB_DIR
lipo -create -output "$UNIVERSAL_LIB_PATH" \
  "target/$TARGET_ARM/release/libsinewave_tinnitus_retraining_audio_core.dylib" \
  "target/$TARGET_INTEL/release/libsinewave_tinnitus_retraining_audio_core.dylib"

# The destination path in the Flutter macOS project.
DEST_PATH="sinewave_tinnitus_retraining/macos/libsinewave_tinnitus_retraining_audio_core.dylib"

# Copy the universal dynamic library to the destination.
echo "Copying universal library to $DEST_PATH"
mkdir -p sinewave_tinnitus_retraining/macos
cp "$UNIVERSAL_LIB_PATH" "$DEST_PATH"

# Sign the dynamic library
echo "Signing the dynamic library..."
codesign --sign "BD625049EA0CE323180B2D1052B176ED1324B3B7" --force "$DEST_PATH"

# Build the Flutter desktop application.
echo "Building Flutter desktop application..."
cd sinewave_tinnitus_retraining
flutter build macos
cd ..

echo "Desktop build finished successfully."
