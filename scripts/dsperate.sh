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
# Pinned (dArkOS): a newer upstream commit is a deliberate update, not whatever
# main is on the day of a build. e04b806 was the one 1.3 to 1.4 shipped; f608b4c
# (2026-10-31) was tried on the dual-boot card: the ARM9 IPC FIFO delivered at
# send time, the lean rasterizer's attributes as the DS has them, the frontend no
# longer realtime, scanout buffers off CMA where the display has an IOMMU.
# v3.2.0 (f8a575f, 2026-11-02): refreshed PGO profiles, 3D fixes (W-buffered depth
# in the GLES raster, the span walk before the submit for capture frames), the
# enhanced anti-aliasing mode by default, builds with GCC 8.
commit="f8a575f2672b0f41f6f741e36339480ca52dcf90"

	# DSperate Standalone build
	if [[ "$var" == "dsperate" ]]  && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd

	  # Now we'll start the clone and build of dsperate
	  if [ ! -d "DSperate/" ]; then
		git clone --recursive https://github.com/beebono/DSperate.git

		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the dsperate standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi
		cp patches/dsperate-patch* DSperate/.
	  else
		echo " "
		echo "A dsperate subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the dsperate folder and rerun this script."
		echo " "
		exit 1
	  fi

	 cd DSperate
	 git checkout $commit && git submodule update --init --recursive
	 if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while checking out dsperate at $commit.  Stopping here."
		exit 1
	 fi

	 dsperate_patches=$(find *.patch)

	 if [[ ! -z "$dsperate_patches" ]]; then
	  for patching in dsperate-patch*
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

           cmake -DDSPERATE_TESTS=OFF \
                 -DDSPERATE_HEADLESS=OFF \
                 -DDSPERATE_WAYLAND=OFF \
                 -DDSPERATE_PGO=use --preset host
           cmake --build --preset host -j$(nproc)

           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error that occured while making the dsperate standalone.  Stopping here."
              exit 1
           fi

           strip build/host/src/frontend/sdl/dsperate

           if [ ! -d "../dsperate-$bitness/" ]; then
	         mkdir -v ../dsperate-$bitness
           fi

	   cp build/host/src/frontend/sdl/dsperate ../dsperate-$bitness/.

	   echo " "
	   echo "The dsperate executable has been created and has been placed in the rk3566_core_builds/dsperate-$bitness subfolder"

	fi
