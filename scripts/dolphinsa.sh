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
TAG="584366cb6859f5e371b1314bf0d92bb59d4d1b80"
	# dolphin Standalone build
	if [[ "$var" == "dolphinsa" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd

	  # Now we'll start the clone and build of dolphin standalone
	  if [ ! -d "dolphin/" ]; then
		git clone https://github.com/dolphin-emu/dolphin

		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the dolphin standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi
		cp patches/dolphinsa-patch* dolphin/.
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

             cmake -DENABLE_HEADLESS=ON \
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
