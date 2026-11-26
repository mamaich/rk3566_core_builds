#!/bin/bash

##################################################################
# Created by Christian Haitian for use to easily update          #
# various standalone emulators, libretro cores, and other        #
# various programs for the RK3326 platform for various Linux     #
# based distributions.                                           #
# See the LICENSE.md file at the top-level directory of this     #
# repository.                                                    #
##################################################################

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
# rg52mini: pinned (2026-11-15). This recipe built upstream's head, and on 2026-11-13 upstream's
# b352039 changed the Makefile line that gametank-patch-002 edits: the patch no longer applied and
# a full image build stopped here. acc608a (2026-11-02) is the commit 1.6 to 1.12 were built from.
# 6ac0c0a (2026-11-25, for 1.13): audio start without a pop, the blitter's registers initialized;
# gametank-patch-002 ported to b352039's line (the compat.h include kept).
commit="6ac0c0aa65cca07c22055ad489bfa0a09de86770"

	# gametank git
	if [[ "$var" == "gametank" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	 if [ ! -d "GameTankEmulator/" ]; then
       git clone --recurse-submodules https://github.com/clydeshaffer/GameTankEmulator.git &&
       git -C GameTankEmulator checkout -q $commit && git -C GameTankEmulator submodule update -q --init --recursive
       if [[ $? != "0" ]]; then
         echo " "
	     echo "There was an error while cloning the gametank git source.  Is Internet active or did the download location change?  Stopping here."
	     exit 1
	   fi
	   cp patches/gametank-patch* GameTankEmulator/.
     else
       echo " "
	   echo "GameTankEmulator directory already exists.  Stopping here."
	   exit 1
     fi
     
	 cd GameTankEmulator
	 gametank_patches=$(find *.patch)

	 if [[ ! -z "$gametank_patches" ]]; then
	  for patching in gametank-patch*
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

     make -j$(nproc)
     if [[ $? != "0" ]]; then
       echo " "
	   echo "There was an error while building the gametank executable.  Stopping here."
	   exit 1
	 fi

	 if [ ! -d "../gametank64/" ]; then
	   mkdir -v ../gametank64
	 fi

     strip build/GameTankEmulator
     cp build/GameTankEmulator ../gametank64/.

	 echo " "
	 echo "GameTankEmulator has been created and has been placed in the rk3326_core_builds/gametank64 subfolder"
	fi
