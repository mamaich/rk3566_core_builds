#!/bin/bash

##################################################################
# Created by Christian Haitian for use to easily update          #
# various standalone emulators, libretro cores, and other        #
# various programs for the RK3566 platform for various Linux     #
# based distributions.                                           #
# See the LICENSE.md file at the top-level directory of this     #
# repository.                                                    #
##################################################################

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
# master of 2026-11-02 (e8c4246, 16 commits after c4856ead of 2026-10-31), by its
# full id: on the console the ND Demo 49.1 fps against 49.5 for c4856ead, three
# rounds each, within the spread; c4856ead was within 2609a's spread too
# master of 2026-11-04 (584366c, 10 commits after e8c4246)
# master of 2026-11-06 (4a70679, 11 commits after 584366c): bounds on FIFO memory updates
# and on legacy savestate LZO decompression, a monotonic clock for sockets
# master of 2026-11-11 (db2afcb, 15 commits after 4a70679), the owner's word of 2026-11-12, for its
# two CRT post-processing shaders (Sys/Shaders/crt_pi.glsl, made for slow GPUs, and
# crt_lottes_fast.glsl; chosen with PostProcessingShader in GFX.ini). The rest: macOS packaging,
# Skylanders audio, one game's setting, glslang's headers under clang.
# master of 2026-11-21 (b2c2c21, 97 commits after db2afcb): the JIT's icache invalidated only
# on dcbf, an Arm64 emitter fix, EFB/XFB clears faster, interpreter carry fixes, AX surround and
# de-pop fixes, GameCube microphone settings, a hang of quickly stopped games fixed. The ND Demo:
# 50.3 and 50.2 fps against 50.3 and 49.4 for db2afcb, the same picture (2026-11-21).
TAG="b2c2c21e58d4acc5de49e8c7d3bc76c8e34f6476"
# Built with clang and a profile for its profile-guided optimisation (for 1.13, the owner's word of
# 2026-11-22). The profile: an instrumented build of this recipe, in this tree's path, playing Super
# Mario Galaxy 2 and Metroid Prime from the owner's savestates and the ND Demo from boot (150 s each)
# on an RG52 Mini. Galaxy 2 from its savestate, 2 rounds: gcc (before) 24.1 fps, clang alone 25.2,
# clang with the profile 26.1 (+8%); the Soulcalibur II demo, not in the training: level (27.6 / 27.7).
# File-local functions are named in the profile by the path of their source, so it fits only a build
# in /home/ark/rk3562_core_builds/dolphin (the image build's chroot). A new profile changes these lines
# and with them the recipe's cache key.
PGO="pgo/dolphin-b2c2c21-20261122.profdata.gz"
PGO_SHA256="d67070aa0e86490272eedf02e98e3f3ab67ee0c2095ac62e4b17b340b97c66c2"
	# dolphin Standalone build
	if [[ "$var" == "dolphinsa" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	  if [ "$(sha256sum ${PGO} | cut -c1-64)" != "${PGO_SHA256}" ]; then
		echo " "
		echo "The dolphin PGO profile ${PGO} is missing or not the one this recipe names.  Stopping here."
		exit 1
	  fi
	  # clang reads the profile (llvm-profdata 19 made it; Debian trixie's clang is 19); lld links
	  # its ThinLTO, llvm-ar archives the bitcode objects
	  if ! dpkg -s clang lld llvm &>/dev/null; then
		apt-get -y update && apt-get -y install clang lld llvm
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "Could not install clang, lld and llvm.  Stopping here."
		  exit 1
		fi
	  fi

	  # Now we'll start the clone and build of dolphin standalone
	  if [ ! -d "dolphin/" ]; then
		git clone https://github.com/dolphin-emu/dolphin

		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the dolphin standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi
		cp patches/dolphinsa-patch* dolphin/.
		gunzip -c ${PGO} > dolphin/dolphin.profdata
	  else
		echo " "
		echo "A dolphin standalone subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the dolphin standalone folder and rerun this script."
		echo " "
		exit 1
	  fi

	 cd dolphin
	 git checkout ${TAG}
	 git submodule update --init --recursive
	 dolphin_patches=$(find *.patch)

	 if [[ ! -z "$dolphin_patches" ]]; then
	  for patching in dolphinsa-patch*
	  do
		   patch -Np1 < "$patching"
		   if [[ $? != "0" ]]; then
			echo " "
			echo "There was an error while applying $patching.  Stopping here."
			exit 1
		   fi
		   rm "$patching"
	  done
	  fi

           if [ ! -d "build" ]; then
             mkdir build
             cd build

             # CLANG_CC/CLANG_CXX: dArkOS's image build hands in the amd64 build of this clang,
             # mounted into its arm64 chroot, which runs without qemu (its xtool.sh); the same
             # compiler, so the same binary. -fuse-ld=lld is in the compile flags too: CMake's
             # LTO check links its test project with those alone, and bfd ld has no LLVMgold
             # here (the build would go on without LTO).
             cc=${CLANG_CC:-/usr/bin/clang}; cxx=${CLANG_CXX:-/usr/bin/clang++}; llvm_bin=$(dirname $cc)
             dflags="-march=armv8-a -moutline-atomics -fuse-ld=lld -Wno-unused-command-line-argument -fprofile-use=$cur_wd/dolphin/dolphin.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin"
             cmake -DCMAKE_C_COMPILER=$cc -DCMAKE_CXX_COMPILER=$cxx \
             -DCMAKE_AR=$llvm_bin/llvm-ar -DCMAKE_RANLIB=$llvm_bin/llvm-ranlib \
             -DCMAKE_C_COMPILER_AR=$llvm_bin/llvm-ar -DCMAKE_CXX_COMPILER_AR=$llvm_bin/llvm-ar \
             -DCMAKE_C_COMPILER_RANLIB=$llvm_bin/llvm-ranlib -DCMAKE_CXX_COMPILER_RANLIB=$llvm_bin/llvm-ranlib \
             -DCMAKE_C_FLAGS="$dflags" -DCMAKE_CXX_FLAGS="$dflags" \
             -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
             -DENABLE_HEADLESS=ON \
             -DENABLE_EGL=ON \
             -DENABLE_EVDEV=ON \
             -DENABLE_TESTS=OFF \
             -DENABLE_LLVM=OFF \
             -DENABLE_ANALYTICS=OFF \
             -DENABLE_X11=OFF \
             -DENABLE_LTO=ON \
             -DENABLE_VULKAN=ON \
             -DENABLE_QT=OFF \
             -DENABLE_NOGUI=ON \
             -DCMAKE_BUILD_TYPE=Release \
             -DDISTRIBUTOR="dArkOS" \
             -DENABLE_ALSA=ON \
             -DENABLE_CLI_TOOL=OFF \
             -DENABLE_AUTOUPDATE=OFF \
             -DUSE_RETRO_ACHIEVEMENTS=OFF \
             -DUSE_DISCORD_PRESENCE=OFF \
             -DENABLE_DRM=ON \
             -DUSE_MGBA=OFF \
             -DENABLE_SDL=OFF \
             -DUSE_SYSTEM_FMT=OFF \
             -DUSE_SYSTEM_GLSLANG=OFF \
             -DUSE_SYSTEM_XXHASH=OFF \
             -DUSE_UPNP=OFF \
             -DENABLE_CUBEB=OFF \
             -DENCODE_FRAMEDUMPS=OFF ..

             if [[ $? != "0" ]]; then
		       echo " "
		       echo "There was an error that occured while verifying the necessary dependancies to build the newest dolphin standalone.  Stopping here."
               exit 1
             fi
           fi

           #if [[ "$0" == *"builds-alt"* ]]; then
             #mkdir -p /opt/dolphin/lib
	     #cp ../../mali/aarch64/libmali-bifrost-g52-g2p0-gbm.so /opt/dolphin/lib/libmali.so
	     #sed -i 's|/usr/local/lib/aarch64-linux-gnu/libGLESv2\.so|/opt/dolphin/lib/libmali.so|g' CMakeCache.txt
             #sed -i 's|/usr/local/lib/aarch64-linux-gnu/libGLESv3\.so|/opt/dolphin/lib/libmali.so|g' CMakeCache.txt
             #sed -i 's|/usr/local/lib/aarch64-linux-gnu/libgbm\.so|/opt/dolphin/lib/libmali.so|g' CMakeCache.txt
             #sed -i 's|/usr/lib/aarch64-linux-gnu/libgbm\.so|/opt/dolphin/lib/libmali.so|g' CMakeCache.txt
             #sed -i 's|/usr/local/lib/aarch64-linux-gnu/libEGL\.so|/opt/dolphin/lib/libmali.so|g' CMakeCache.txt
             #sed -i 's|/usr/lib/aarch64-linux-gnu/libEGL\.so|/opt/dolphin/lib/libmali.so|g' CMakeCache.txt
	   #fi
           make -j$(nproc) dolphin-nogui
           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error that occured while making the dolphin standalone.  Stopping here."
             exit 1
           fi
           strip Binaries/dolphin-emu-nogui

           if [ ! -d "../../dolphinsa$bitness/" ]; then
		     mkdir -v ../../dolphinsa$bitness
	       fi

	       cp Binaries/dolphin-emu-nogui ../../dolphinsa$bitness/dolphin-emu-nogui

	       echo " "
	       echo "The dolphin standalone executable has been created and has been placed in the rk3566_core_builds/dolphinsa$bitness subfolder"

	fi
