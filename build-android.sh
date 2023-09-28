#!/bin/bash
set -e  # Any error will cause the script to fail

sudo apt update -y
sudo apt install unzip cmake android-sdk -y

git submodule update --init --recursive

# Warn if cannot find OpenCV
OPENCV_DIR="./src/opencv"
if [ ! -d $OPENCV_DIR ]; then
    echo Could not find OpenCV.
    echo Make sure you are running this in the opencv_ffi package.
    exit 2
fi

ANDROID_NDK_URL="https://dl.google.com/android/repository/android-ndk-r26-linux.zip"

# Download and extract Android NDK
ANDROID_NDK_DIR="android-ndk-r26"
if [ ! -d "$ANDROID_NDK_DIR" ]; then
    echo "Downloading Android NDK..."
    wget -q "$ANDROID_NDK_URL" -O android_ndk.zip
    unzip -q android_ndk.zip
    rm android_ndk.zip
fi

export ANDROID_NDK_ROOT=`pwd`/android-ndk-r26
export ANDROID_SDK_ROOT="/usr/lib/android-sdk"
export ANDROID_NATIVE_API_LEVEL="21"
export ANDROID_PLATFORM="android-21"

# List of target Android ABIs
ANDROID_ABIS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")

# Build OpenCV for each ABI and move the resulting .so files to ABI-specific folders
for ABI in "${ANDROID_ABIS[@]}"; do
    echo "Building for ABI: $ABI"
    mkdir -p build_$ABI  # -p means no error if there
    cd build_$ABI

    cmake \
        -D CMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
        -D ANDROID_TOOLCHAIN=clang++ \
        -D ANDROID_ABI=$ABI \
        -D ANDROID_NATIVE_API_LEVEL=$ANDROID_NATIVE_API_LEVEL \
        -D ANDROID_PLATFORM=$ANDROID_PLATFORM \
        -D WITH_ANDROID_MEDIANDK=ON \
        -D BUILD_SHARED_LIBS=ON \
        -D BUILD_ANDROID_EXAMPLES=OFF \
        -D BUILD_ANDROID_PROJECTS=OFF \
        -D BUILD_FAT_JAVA_LIB=OFF \
        -D BUILD_opencv_java=OFF \
        -D BUILD_TESTS=OFF \
        -D BUILD_PERF_TESTS=OFF \
        ../src/

    cmake --build . -j8
    cd ..

    # Create ABI-specific directory in dist folder and copy .so files
    ABI_DIST_DIR="dist/$ABI"
    mkdir -p $ABI_DIST_DIR
    cp build_$ABI/opencv/lib/*.so $ABI_DIST_DIR # the OpenCV libraries
    cp build_$ABI/*.so $ABI_DIST_DIR  # the opencv_ffi library
done

cd $(dirname "$0")
SCRIPT_DIR=$(pwd)
INDENT="  "

echo
echo Done! Your files are in the dist folder
echo To let your device find them, run this command:
echo "  echo \"export LD_LIBRARY_PATH=\\\$LD_LIBRARY_PATH:$SCRIPT_DIR/dist\" >> ~/.bashrc"
echo You only need to run this once, but run this again if you move this folder
echo This command does not affect any open terminal shells or SSH sessions.
echo You'll need to open a new shell or SSH again for it to take effect.
