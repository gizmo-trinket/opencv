# Gizmo & Trinket OpenCV build

A minimal, static build of upstream OpenCV for the Oracle desktop app, which links it through
[oracle-calibration](https://github.com/gizmo-trinket/oracle-calibration), and for the training
worker ([data-validation-service](https://github.com/gizmo-trinket/data-validation-service)), which
uses only `remap`. The branch
`gizmo/<version>` is upstream's release tag plus only this directory and `.github/workflows`: no
OpenCV source is changed.

## What's in it

`build.sh` builds only what fisheye calibration and ChArUco detection need:

| Modules | Why |
|---|---|
| `calib` | `fisheye::calibrate` |
| `objdetect` | `CharucoDetector`, ArUco dictionaries |
| `geometry`, `imgproc` | fisheye projection and undistortion, `solvePnP`, `Rodrigues`, `remap` |
| `features`, `flann`, `stereo`, `core` | what `calib` and `objdetect` depend on |

There are **no image codecs** (`imgcodecs`): the app decodes photos in Rust. A bundled libjpeg-turbo
or libpng would export the same symbols as the ones other crates link statically (nokhwa's mozjpeg,
which decodes the camera's MJPEG stream), and the link would fail. zlib is bundled because core
needs it.

Everything else is off, including every optional dependency that would be downloaded at configure
time (IPP, KleidiCV, ITT) or found on the build machine (OpenCL, LAPACK, Eigen, TBB, other codecs),
so the libraries depend on nothing but the platform's C and C++ runtimes. Windows uses the dynamic
CRT (`/MD`), as Rust does.

## Platforms

| Archive | Runner |
|---|---|
| `opencv-<version>-x86_64-unknown-linux-gnu.tar.gz` | `ubuntu-24.04` |
| `opencv-<version>-aarch64-unknown-linux-gnu.tar.gz` | `ubuntu-24.04-arm`, for the training worker |
| `opencv-<version>-aarch64-apple-darwin.tar.gz` | `macos-15`, macOS 11.0 or later |
| `opencv-<version>-x86_64-pc-windows-msvc.tar.gz` | `windows-2025`, MSVC |

The Linux archives link only against a C and C++ runtime at least as new as Ubuntu 24.04's (glibc
2.39, GCC 13): Debian 13, not Debian 12.

Each archive has the same layout:

```
include/opencv2/...
lib/            every static library, OpenCV's and the bundled zlib
link-libs.txt   the value for OPENCV_LINK_LIBS
LICENSE
```

## Linking it from Rust

The [`opencv`](https://crates.io/crates/opencv) crate reads three variables:

```sh
OPENCV_INCLUDE_PATHS=<archive>/include
OPENCV_LINK_PATHS=<archive>/lib
OPENCV_LINK_LIBS=$(cat <archive>/link-libs.txt)
```

The link list is the same on every platform. oracle-calibration's `scripts/fetch-opencv.sh`
downloads the right archive, checks its SHA-256, and sets these through `.cargo/config.toml`.

## Releasing

Push a tag `opencv/v<version>` on this branch. `publish.yml` builds every platform and creates
a GitHub release with the archives, a `.sha256` for each, and `SHA256SUMS`. The repository is
public, so the downloads need no token. `ci.yml` runs the same build on demand (Actions → CI → Run
workflow) or after a pull request into the branch is merged, without publishing.

A rebuild of the same upstream version with different options gets a build number as semver build
metadata: `opencv/v5.0.0+r2`, `+r3`, … Earlier tags and their releases stay, so anything pinned to
them keeps working.

| Tag | What changed |
|---|---|
| `opencv/v5.0.0` | First build, with `imgcodecs` (PNG, JPEG) |
| `opencv/v5.0.0+r2` | `imgcodecs` and its bundled libjpeg-turbo and libpng removed: they clashed with nokhwa's mozjpeg |
| `opencv/v5.0.0+r3` | Adds arm64 Linux, for the training worker. Same options |

For a new upstream release, branch `gizmo/<new version>` from upstream's tag, copy `gizmo/` and
`.github/workflows/` over, and drop upstream's own workflows.

## Building locally

```sh
gizmo/build.sh ~/opt/opencv-5.0.0      # needs CMake and a C++17 compiler; uses Ninja if present
```
