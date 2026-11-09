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
# dArkOS RG52 Mini: pinned to the commit tested on the console. Since 7bd9645 (2026-03-28) a
# built-in copy of OpenBIOS starts a game when no PS1 BIOS is found, where the 2024 build the
# image downloaded did not load the game at all.
commit="631f0fb31b809e0f889d7c551fe695788e39c1d3"
# The RK3566 rumble patch (the motor's duty cycle written to /sys/class/pwm/pwmchip0 or 1) is gone:
# it no longer applied, and on the RG52 Mini those PWMs are the fan and the backlight, held by the
# kernel and not exported, so it never wrote anything; the pad rumbles through RetroArch's rumble
# interface (the joystick's force feedback), which the core calls as it is.

	# Libretro swanstation build
	if [[ "$var" == "swanstation" || "$var" == "all" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	  if [ ! -d "swanstation/" ]; then
		git clone https://github.com/libretro/swanstation.git
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the libretro git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		 fi
		git -C swanstation checkout -q $commit || exit 1
		cp patches/swanstation-patch* swanstation/.
	  fi

	 cd swanstation/
	 
	 swanstation_patches=$(find *.patch)
	 
	 if [[ ! -z "$swanstation_patches" ]]; then
	  for patching in swanstation-patch*
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

      cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_LIBRETRO_CORE=ON
	  make clean
	  make -j$(nproc)

	  if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while building the newest lr-swanstation core.  Stopping here."
		exit 1
	  fi

	  strip swanstation_libretro.so

	  if [ ! -d "../cores64/" ]; then
		mkdir -v ../cores64
	  fi

	  cp swanstation_libretro.so ../cores64/.

	  gitcommit=$(git log | grep -m 1 commit | cut -c -14 | cut -c 8-)
	  echo $gitcommit > ../cores$(getconf LONG_BIT)/swanstation_libretro.so.commit

	  echo " "
	  echo "swanstation_libretro.so has been created and has been placed in the rk3566_core_builds/cores64 subfolder"
	fi
