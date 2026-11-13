#!/bin/bash

# dArkOS: RetroArch built from libretro's master, 64-bit only, a second choice beside the
# release that retroarch.sh builds (/opt/retroarch-next on the image, retroarch-next in ES).
# Pinned: a newer master is a deliberate update, made after the same checks on the console
# (docs/KNOWN-ISSUES.md, "RetroArch from master"). Its patches, patches/retroarch-next/, are
# the release's ported to master; they are applied in their numbered order.

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
commit="a4d0a85439dcdb6801ac37d2555c1e581c42f343"

	# Libretro RetroArch from master
	if [[ "$var" == "retroarch-next" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	 rm -rf retroarch-next
	 git init -q retroarch-next &&
	 git -C retroarch-next fetch -q --depth=1 https://github.com/libretro/RetroArch.git $commit &&
	 git -C retroarch-next checkout -q FETCH_HEAD
	 if [[ $? != "0" ]]; then
	  echo " "
	  echo "There was an error while fetching RetroArch $commit.  Is Internet active or did the git location change?  Stopping here."
	  exit 1
	 fi

	 cd retroarch-next/
	 for patching in ../patches/retroarch-next/*.patch
	 do
	  patch -Np1 < "$patching"
	  if [[ $? != "0" ]]; then
	   echo " "
	   echo "There was an error while applying $patching.  Stopping here."
	   exit 1
	  fi
	 done

	 CFLAGS="-Ofast -march=armv8-a -mtune=cortex-a53 -fomit-frame-pointer -DNDEBUG -DUDEV_TOUCH_SUPPORT" \
	 ./configure \
	  --disable-caca \
	  --disable-mali_fbdev \
	  --disable-opengl \
	  --disable-opengl_core \
	  --disable-opengl1 \
	  --disable-qt \
	  --disable-sdl \
	  --disable-vg \
	  --disable-wayland \
	  --disable-x11 \
	  --disable-jack \
	  --disable-pulse \
	  --disable-pipewire \
	  --disable-xrandr \
	  --disable-winrawinput \
	  --disable-gdi \
	  --disable-d3d10 \
	  --disable-d3d11 \
	  --disable-d3d12 \
	  --disable-microphone \
	  --enable-alsa \
	  --enable-egl \
	  --enable-freetype \
	  --enable-kms \
	  --enable-networking \
	  --enable-odroidgo2 \
	  --enable-opengles \
	  --enable-opengles3 \
	  --enable-opengles3_1 \
	  --enable-opengles3_2 \
	  --enable-ozone \
	  --enable-udev \
	  --enable-vulkan \
	  --enable-vulkan_display \
	  --enable-wifi

	 make -j$(nproc)
	 if [[ $? != "0" ]]; then
	  echo " "
	  echo "There was an error while building RetroArch from master.  Stopping here."
	  exit 1
	 fi

	 strip retroarch
	 mkdir -p ../retroarch64
	 cp retroarch ../retroarch64/retroarch-next
	 echo " "
	 echo "retroarch-next has been created and has been placed in the rk3566_core_builds/retroarch64 subfolder"
	fi
