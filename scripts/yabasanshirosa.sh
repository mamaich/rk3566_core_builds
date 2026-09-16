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
# devmiyax/yabause, which this recipe used to clone at tag pi4-1-9-0, no longer
# exists, and no surviving mirror carries that tag: sydarn/yabasanshiro and
# Mechafatnick/YabaSanshiroPi have no tags at all, pirrypirrypirry has four and
# none of them this one, and libretro/yabause is a different project. So the
# choice is a different revision or nothing.
#
# Mechafatnick/YabaSanshiroPi is a Pi-oriented fork of the same tree, last
# touched 2021-09-04 - roughly the era of 1.9.0. Pinned to a commit rather than
# master so this stays reproducible.
YABA_REPO="https://github.com/Mechafatnick/YabaSanshiroPi"
YABA_COMMIT="91990f8620fc03d7614b9a89af166d67ff563f8c"
TAG="mechafatnick-91990f8"

# Only four of the eleven patches suit this revision, and the other seven are
# skipped for reasons, not for convenience:
#   01 adds #include <core.h> for a YabNanosleep(u64) prototype this revision
#      does not have yet
#   02 patches the nx and sdl ports, neither of which is compiled under
#      YAB_PORTS=retro_arena
#   08 turns off use_sh2_cache, a setting that does not exist here
#   09 10 11 are Vulkan, and this fork has no yabause/src/vulkan at all
# 07 is the odroidgoa menu-size patch, applied after the first build pass by
# the logic further down, the same as before.
YABA_PATCHES="03 04 05 06 07"

# This fork carries no Vulkan backend, so the GL path is the only one there is.
YABA_VULKAN="OFF"

	# yabasanshiro Standalone build
	if [[ "$var" == "yabasanshirosa" ]]; then
	 cd $cur_wd

	  # Now we'll start the clone and build of yabasanshiro
	  if [ ! -d "yabasanshiro/" ]; then
		git clone --recursive ${YABA_REPO} yabasanshiro

		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the yabasanshiro standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi

		( cd yabasanshiro && git checkout -q ${YABA_COMMIT} && git submodule update --init --recursive )
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "Could not check out ${YABA_COMMIT} of the yabasanshiro fork.  Stopping here."
		  exit 1
		fi

		for yaba_p in ${YABA_PATCHES}; do
		  cp patches/yabasanshirosa-patch-${yaba_p}-* yabasanshiro/.
		done
	  else
		echo " "
		echo "A yabasanshiro subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the yabasanshiro folder and rerun this script."
		echo " "
		exit 1
	  fi

	 # Ensure dependencies are installed and available
     neededlibs=( git python3-pip cmake build-essential protobuf-compiler libglfw3-dev libprotobuf-dev libsecret-1-dev libshaderc-dev libssl-dev libsdl2-dev libboost-all-dev libvulkan-dev )
     updateapt="N"
     for libs in "${neededlibs[@]}"
     do
          dpkg -s "${libs}" &>/dev/null
          if [[ $? != "0" ]]; then
           if [[ "$updateapt" == "N" ]]; then
            apt-get -y update
            updateapt="Y"
           fi
           apt-get -y install "${libs}"
           if [[ $? != "0" ]]; then
            echo " "
            echo "Could not install needed library ${libs}.  Stopping here so this can be reviewed."
            exit 1
           fi
          fi
     done

	 cd yabasanshiro
	 
	 yabasanshirosa_patches=$(find *.patch)
	 
	 if [[ ! -z "$yabasanshirosa_patches" ]]; then
	  for patching in yabasanshirosa-patch*
	  do
		 if [[ $patching == *"odroidgoa"* ]]; then
		   echo " "
		   echo "Skipping the $patching for now and making a note to apply that later"
		   sleep 3
		   yaba_menusizepatch="yes"
		 else
		   patch -Np1 < "$patching"
		   if [[ $? != "0" ]]; then
			echo " "
			echo "There was an error while applying $patching.  Stopping here."
			exit 1
		   fi
		   rm "$patching"
         fi
	  done
	  fi

             mkdir build
             cd build
             export CFLAGS="-O2 -march=armv8-a+crc -mtune=cortex-a53 -ftree-vectorize -funsafe-math-optimizations"
             export CXXFLAGS="$CXXFLAGS $CFLAGS"
             export LDFLAGS="$CFLAGS"
             if [[ "$bitness" == "64" ]]; then
               cmake ../yabause \
                     -DYAB_PORTS=retro_arena \
                     -DYAB_WANT_DYNAREC_DEVMIYAX=ON \
                     -DYAB_WANT_ARM7=ON \
                     -DYAB_WANT_VULKAN=${YABA_VULKAN} \
                     -DUSE_EGL=ON \
                     -DCMAKE_TOOLCHAIN_FILE=../yabause/src/retro_arena/n2.cmake \
                     -DCMAKE_BUILD_TYPE=Release
               if [[ $? != "0" ]]; then
		         echo " "
		         echo "There was an error that occured while verifying the necessary dependancies to build the newest yabasanshiro standalone.  Stopping here."
                 exit 1
               fi
            else
               cmake ../yabause \
                     -DYAB_PORTS=retro_arena \
                     -DYAB_WANT_DYNAREC_DEVMIYAX=ON \
                     -DYAB_WANT_ARM7=ON \
                     -DYAB_WANT_VULKAN=OFF \
                     -DUSE_EGL=ON \
                     -DCMAKE_TOOLCHAIN_FILE=../yabause/src/retro_arena/pi4.cmake \
                     -DCMAKE_BUILD_TYPE=Release
               if [[ $? != "0" ]]; then
                 echo " "
                 echo "There was an error that occured while verifying the necessary dependancies to build the newest yabasanshiro standalone.  Stopping here."
                 exit 1
               fi
            fi
           make VERBOSE=1 -j$(nproc)
           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error that occured while making the yabasanshiro standalone.  Stopping here."
             exit 1
           fi
           strip src/retro_arena/yabasanshiro

           if [ ! -d "../../yabasanshirosa$bitness/" ]; then
		     mkdir -v ../../yabasanshirosa$bitness
	       fi

	       cp src/retro_arena/yabasanshiro ../../yabasanshirosa$bitness/yabasanshiro

	       echo " "
	       echo "The yabasanshiro executable has been created and has been placed in the rk3566_core_builds/yabasanshirosa$bitness subfolder"

            if [[ $yaba_menusizepatch == "yes" ]]; then
              cd ..
        	  for patching in yabasanshirosa-patch*
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

           cd build
           make -j$(nproc)
           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error that occured while making the yabasanshiro standalone.  Stopping here."
             exit 1
           fi
           strip src/retro_arena/yabasanshiro

           if [ ! -d "../../yabasanshirosa$bitness/" ]; then
		     mkdir -v ../../yabasanshirosa$bitness
	       fi

	       cp src/retro_arena/yabasanshiro ../../yabasanshirosa$bitness/yabasanshiro.oga

	       echo " "
	       echo "The yabasanshiro executable has been created and has been placed in the rk3566_core_builds/yabasanshirosa$bitness subfolder"

	fi
