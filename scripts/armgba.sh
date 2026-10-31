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
# rg52mini: pinned (2026-10-28), the build tried on the console
commit="20061e22f3cf36d805e4c48e0a53a0f58802f84a"

	# Libretro armgba build
	if [[ "$var" == "armgba" || "$var" == "all" ]] && [[ "$bitness" == "64" ]]; then
	 gba_rumblepatch="no"
	 cd $cur_wd
	  if [ ! -d "armGBA/" ]; then
		git clone --recursive https://github.com/MagnominusGit/armGBA.git &&
		git -C armGBA checkout -q $commit && git -C armGBA submodule update -q --init --recursive
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the libretro git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		 fi
		cp patches/armgba-patch* armGBA/. 2>/dev/null
	  fi

	 cd armGBA/
	 
	 armgba_patches=$(find *.patch)
	 
	 if [[ ! -z "$armgba_patches" ]]; then
	  for patching in armgba-patch*
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
	  cmake -S . -B build-aarch64 -G Ninja \
                 -DCMAKE_C_FLAGS="-march=armv8-a+crc -mtune=cortex-a53" \
                 -DCMAKE_CXX_FLAGS="-march=armv8-a+crc -mtune=cortex-a53"
	  ninja -C build-aarch64

	  if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while building the newest lr-armgba core.  Stopping here."
		exit 1
	  fi

	  strip build-aarch64/armgba_libretro.so

	  if [ ! -d "../cores64/" ]; then
		mkdir -v ../cores64
	  fi

	  cp build-aarch64/armgba_libretro.so ../cores64/.
	  cp libretro/armgba_libretro.info ../cores64/.

	  gitcommit=$(git log | grep -m 1 commit | cut -c -14 | cut -c 8-)
	  echo $gitcommit > ../cores$(getconf LONG_BIT)/$(basename $PWD | tr '[:upper:]' '[:lower:]')_libretro.so.commit

	  echo " "
	  echo "armgba_libretro.so has been created and has been placed in the rk3566_core_builds/cores64 subfolder"
	fi
