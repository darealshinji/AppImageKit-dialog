#!/bin/sh
set -x
rm -rf build libdesktopenvironments/build
test ! -e fltk/config.h || make -C fltk distclean
