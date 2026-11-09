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
# dArkOS RG52 Mini: pinned to the commit tested on the console. Since 684926fe20 (2026-10-13) its
# built-in "Opera Boot" BIOS is the default: a 3DO game starts with no BIOS file, where the older
# build the image downloaded stayed on a black screen.
commit="595fd1db7d5bf0d3ca63d2292854d587ddcfa94b"

	# Libretro opera build
	if [[ "$var" == "opera" || "$var" == "all" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	  if [ ! -d "opera-libretro/" ]; then
		git clone https://github.com/libretro/opera-libretro.git
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the libretro git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		 fi
		git -C opera-libretro checkout -q $commit || exit 1
		cp patches/opera-patch* opera-libretro/.
	  fi

	 cd opera-libretro/
	 
	 opera_patches=$(find *.patch)
	 
	 if [[ ! -z "$opera_patches" ]]; then
	  for patching in opera-patch*
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

	  make clean
	  make -j$(nproc)

	  if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while building the newest lr-opera core.  Stopping here."
		exit 1
	  fi

	  strip opera_libretro.so

	  if [ ! -d "../cores64/" ]; then
		mkdir -v ../cores64
	  fi

	  cp opera_libretro.so ../cores64/.

	  gitcommit=$(git log | grep -m 1 commit | cut -c -14 | cut -c 8-)
	  echo $gitcommit > ../cores$(getconf LONG_BIT)/opera_libretro.so.commit

	  echo " "
	  echo "opera_libretro.so has been created and has been placed in the rk3566_core_builds/cores64 subfolder"
	fi
