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
# v1.5 (b1c4a69, 2026-11-08), 60 commits after 20061e2: LCD effects (ghosting, subpixels, grid,
# interlaced rows) on the CPU or in its shaders, cartridge clocks on real or game time, a CPU
# clock option, e-Reader cards and the Game Boy Printer, SRAM for reproduction cartridges'
# images, a JIT fix for ARM code at a halfword address. Main is 15 commits further (2026-11-12:
# recompiler changes from a 3DS port, built with -fwrapv): left for the next check.
commit="b1c4a69c99797d93f0f96901b69b9fd7bf7917c3"

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
