#!/usr/bin/env bash
# Builds the minimal, static OpenCV the Oracle desktop app links (oracle-calibration).
#
#   gizmo/build.sh <install-prefix> [extra cmake args...]
#
# Only the modules the calibration needs: fisheye calibration (calib) and ChArUco detection
# (objdetect), plus what they depend on, and PNG/JPEG codecs. Nothing is downloaded at configure
# time: IPP, KleidiCV, ITT, OpenCL, LAPACK, Eigen and every optional codec are off.
#
# The install has the same layout on every platform, so one set of `opencv` crate variables works
# everywhere: headers in include/, every static library (OpenCV's and the bundled zlib, libpng and
# libjpeg-turbo) in lib/, and no version suffix on Windows library names.
#
#   OPENCV_INCLUDE_PATHS=<prefix>/include
#   OPENCV_LINK_PATHS=<prefix>/lib
#   OPENCV_LINK_LIBS=$(cat <prefix>/link-libs.txt)
set -euo pipefail

prefix=${1:?usage: gizmo/build.sh <install-prefix> [cmake args...]}
shift
src=$(cd "$(dirname "$0")/.." && pwd)
build=${BUILD_DIR:-$src/build-gizmo}

# CMake honours CMAKE_GENERATOR itself; otherwise prefer Ninja when it's installed.
generator=()
[ -z "${CMAKE_GENERATOR:-}" ] && command -v ninja >/dev/null && generator=(-G Ninja)

cmake -S "$src" -B "$build" "${generator[@]}" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$prefix" \
	-DOPENCV_INCLUDE_INSTALL_PATH=include \
	-DOPENCV_LIB_INSTALL_PATH=lib \
	-DOPENCV_LIB_ARCHIVE_INSTALL_PATH=lib \
	-DOPENCV_3P_LIB_INSTALL_PATH=lib \
	-DOPENCV_CONFIG_INSTALL_PATH=lib/cmake/opencv5 \
	-DOPENCV_DLLVERSION= \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DBUILD_SHARED_LIBS=OFF \
	-DBUILD_WITH_STATIC_CRT=OFF \
	-DBUILD_LIST=core,flann,geometry,imgproc,features,objdetect,stereo,calib,imgcodecs \
	-DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_opencv_apps=OFF \
	-DBUILD_DOCS=OFF -DBUILD_JAVA=OFF -DBUILD_opencv_python3=OFF -DBUILD_opencv_js=OFF \
	-DBUILD_ZLIB=ON -DBUILD_PNG=ON -DBUILD_JPEG=ON \
	-DWITH_PNG=ON -DWITH_JPEG=ON -DWITH_SPNG=OFF \
	-DWITH_TIFF=OFF -DWITH_WEBP=OFF -DWITH_AVIF=OFF -DWITH_JPEGXL=OFF -DWITH_OPENJPEG=OFF \
	-DWITH_JASPER=OFF -DWITH_OPENEXR=OFF -DWITH_IMGCODEC_GIF=OFF -DWITH_GDAL=OFF -DWITH_GDCM=OFF \
	-DWITH_IPP=OFF -DWITH_KLEIDICV=OFF -DWITH_ITT=OFF -DWITH_OPENCL=OFF -DWITH_LAPACK=OFF \
	-DWITH_EIGEN=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_PROTOBUF=OFF -DWITH_FLATBUFFERS=OFF \
	-DWITH_OPENVINO=OFF -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_GTK=OFF -DWITH_QT=OFF \
	-DWITH_V4L=OFF -DWITH_1394=OFF -DWITH_VA=OFF -DWITH_VA_INTEL=OFF -DWITH_OBSENSOR=OFF \
	-DWITH_ADE=OFF -DWITH_VTK=OFF -DWITH_CUDA=OFF -DWITH_VULKAN=OFF -DWITH_WAYLAND=OFF \
	-DOPENCV_GENERATE_PKGCONFIG=ON \
	"$@"
cmake --build "$build" --config Release --parallel
cmake --install "$build" --config Release

# OpenCV names the bundled codecs lib<name> on every platform: liblibpng.a on Unix, libpng.lib with
# MSVC. The `opencv` crate strips a leading "lib" from link names except for MSVC, so give the MSVC
# files the Unix spelling and one link list works everywhere.
for f in "$prefix"/lib/{libjpeg-turbo,libpng,zlib}.lib; do
	[ -e "$f" ] && mv "$f" "$prefix/lib/lib$(basename "$f")"
done

# Dependants first, as a static link needs them.
echo "static=opencv_calib,static=opencv_imgcodecs,static=opencv_objdetect,static=opencv_features,\
static=opencv_stereo,static=opencv_imgproc,static=opencv_geometry,static=opencv_flann,static=opencv_core,\
static=liblibjpeg-turbo,static=liblibpng,static=libzlib" >"$prefix/link-libs.txt"
cp "$src/LICENSE" "$prefix/LICENSE"
