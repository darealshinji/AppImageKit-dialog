#!/bin/bash
set -e
set -x

if [ -x /usr/bin/yum ]; then
  yum -y update
  yum -y install gcc gcc-c++ vim-common git wget cmake make binutils glibc-devel libXft-devel librsvg2 desktop-file-utils
  # vim-common provides xxd
elif [ -x /usr/bin/apt-get ]; then
  sudo apt-get install build-essential xxd git wget cmake libx11-dev libxft-dev libfontconfig1-dev librsvg2-bin
fi

common_FLAGS="-fstack-protector -ffunction-sections -fdata-sections -D_FORTIFY_SOURCE=2"
CFLAGS="-Os $common_FLAGS"
CXXFLAGS="-Os -std=c++98 $common_FLAGS -Wno-deprecated-declarations"
LDFLAGS="-Wl,--gc-sections -Wl,--as-needed -Wl,-z,relro"
CXX="g++"
STRIP="strip"
JOBS=${JOBS:-1}

HERE="$(dirname "$(readlink -f "${0}")")"
cd "$HERE"

git submodule init
git submodule update

mkdir -p build

if [ ! -e "./fltk/lib/libfltk_images.a" ]; then
  cd fltk
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
  ./configure --disable-gl --enable-localzlib --enable-localpng --enable-xft \
    --disable-xinerama --disable-xdbe --disable-xfixes --disable-xcursor --disable-xrender
  make -j$JOBS DIRS='zlib png src'
  cd -
fi

if [ ! -e "./libdesktopenvironments/build/src/libdesktopenvironments.a" ]; then
  mkdir -p libdesktopenvironments/build
  cd libdesktopenvironments/build
  cmake .. -DCMAKE_BUILD_TYPE="MinSizeRel"
  make -j$JOBS
  cd -
fi

cd build
rsvg-convert -f png -o appimagetool-48x48.png -w 48 -h 48 ../appimagetool.svg
rsvg-convert -f png -o alacarte-96x96.png -w 96 -h 96 ../alacarte.svg
rsvg-convert -f png -o oxygen-launch-96x96.png -w 96 -h 96 ../oxygen-launch.svg
xxd -i appimagetool-48x48.png > dialog_images.h
xxd -i alacarte-96x96.png >> dialog_images.h
xxd -i oxygen-launch-96x96.png >> dialog_images.h
cd -

$CXX dialog.cpp -o ./build/dialog \
  -I./libdesktopenvironments/include -I. -I./build \
  $(./fltk/fltk-config --use-images --cxxflags) \
  $(./fltk/fltk-config --use-images --ldflags | sed 's|-lfltk_jpeg||g') \
  ./libdesktopenvironments/build/src/libdesktopenvironments.a
$STRIP ./build/dialog
(objdump -p ./build/dialog | grep NEEDED) || true
ldd ./build/dialog || true

