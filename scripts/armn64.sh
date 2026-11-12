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
# rg52mini: pinned (2026-11-12), 3 commits after v1.1 (HLE fixes of G_BRANCH_Z and Fast3D, Shader
# Precompile on by default); the build tried on the console. Built for the Cortex-A53: upstream's
# ARMN64_TUNE asks for armv8.2-a and the A55, which the RK3562 is not. Link-time optimisation was
# tried and changed nothing. The core's fast GL renderer needs RetroArch's Vulkan driver here (the
# image's config/armN64/armN64.cfg): under the gl driver it gets no context and draws on the CPU.
commit="58e58ca12abff5c88521d634f6e6ed021f1144f5"

	# armn64 libretro core build
	if [[ "$var" == "armn64"  || "$var" == "all" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd

	  # Now we'll start the clone and build of armn64
	  if [ ! -d "armN64/" ]; then
		git clone --recursive https://github.com/MagnominusGit/armN64.git &&
		git -C armN64 checkout -q $commit && git -C armN64 submodule update -q --init --recursive
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the armn64 libretro git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi
		cp patches/armn64-patch* armN64/. 2>/dev/null
	  else
		echo " "
		echo "A armN64 subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the armN64 folder and rerun this script."
		echo " "
		exit 1
	  fi

	 cd armN64

	 armn64_core_patches=$(find *.patch 2>/dev/null)

	 if [[ ! -z "$armn64_core_patches" ]]; then
	  for patching in armn64-patch*
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

	 cmake -S . -B build-rk3562 -G Ninja \
	     -DCMAKE_BUILD_TYPE=Release \
	     -DARMN64_TUNE=OFF \
	     -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG -march=armv8-a+crc -mtune=cortex-a53 -ffp-contract=off"

	 cmake --build build-rk3562 \
	     --target armn64_libretro -j$(nproc)

	  if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while building the newest armn64 libretro core.  Stopping here."
		exit 1
	  fi

	  strip build-rk3562/armn64_libretro.so

	  if [ ! -d "../cores$bitness/" ]; then
		mkdir -v ../cores$bitness
	  fi

	  cp build-rk3562/armn64_libretro.so ../cores$bitness/.
	  cp libretro/armn64_libretro.info ../cores$bitness/.

	  gitcommit=$(git log | grep -m 1 commit | cut -c -14 | cut -c 8-)
	  echo $gitcommit > ../cores$bitness/armn64_libretro.so.commit

	  echo " "
	  echo "armn64_libretro.so executable has been created and has been placed in the rk3566_core_builds/cores$bitness subfolder"

	fi
