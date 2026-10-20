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
TAG="2126.2"
# Profile for clang's profile-guided optimisation: Super Mario 3D Land played
# on an RG52 Mini with an instrumented build of this tag (2026-10-20). A new
# profile changes this line, so the recipe's cache key changes with it.
PGO="pgo/azahar-2126.2.profdata.gz"
PGO_SHA256="c8bcce2217c819c73d48c4d054af5452d3fcd7e0759b6feeac58d7b12a8cd0f0"

	# Libretro Azahar (Nintendo 3DS) build
	if [[ "$var" == "azahar" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	  if [ "$(sha256sum ${PGO} | cut -c1-64)" != "${PGO_SHA256}" ]; then
		echo " "
		echo "The azahar PGO profile ${PGO} is missing or not the one this recipe names.  Stopping here."
		exit 1
	  fi
	  # clang reads the profile (llvm-profdata 19 made it; Debian trixie's clang is 19)
	  if ! dpkg -s clang &>/dev/null; then
		apt-get -y update && apt-get -y install clang
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "Could not install clang.  Stopping here."
		  exit 1
		fi
	  fi
	  rm -rf azahar/
	  git clone --recursive --depth=1 --shallow-submodules -b ${TAG} https://github.com/azahar-emu/azahar.git azahar
	  if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while cloning the azahar git.  Is Internet active or did the git location change?  Stopping here."
		exit 1
	  fi
	  cp patches/azahar-patch* azahar/.
	  gunzip -c ${PGO} > azahar/azahar.profdata

	  cd azahar
	  for patching in azahar-patch*
	  do
		   patch -Np1 < "$patching"
		   if [[ $? != "0" ]]; then
			echo " "
			echo "There was an error while applying $patching.  Stopping here."
			exit 1
		   fi
		   rm "$patching"
	  done

	  mkdir build
	  cd build
	  # OpenGL is off by default on aarch64 Linux. RetroArch here runs the gl
	  # driver on GLES (KMS), so build it, and have the core ask for a GLES 3
	  # context: USING_GLES, which upstream sets only for Android. Vulkan too,
	  # for the vulkan driver, which is the one RetroArch uses for this core.
	  # clang with the profile: on the RG52 Mini it took the game from 91% to
	  # full speed (27.3 -> 29.8 fps of 30) where gcc-style flags and ThinLTO
	  # alone gained 1-2%. Upstream's LTO is off: it adds nothing on top of the
	  # profile here and would need lld.
	  pgo_flags="-fprofile-use=$cur_wd/azahar/azahar.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date"
	  cmake .. -G Ninja \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER=/usr/bin/clang \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
		-DENABLE_LIBRETRO=ON \
		-DENABLE_OPENGL=ON \
		-DENABLE_VULKAN=ON \
		-DENABLE_TESTS=OFF \
		-DENABLE_LTO=OFF \
		-DCITRA_WARNINGS_AS_ERRORS=OFF \
		-DCMAKE_C_FLAGS="${pgo_flags}" \
		-DCMAKE_CXX_FLAGS="-DUSING_GLES ${pgo_flags}"
	  ninja -j$(nproc) citra_libretro

	  if [[ $? != "0" ]]; then
		echo " "
		echo "There was an error while building the azahar libretro core.  Stopping here."
		exit 1
	  fi

	  strip bin/Release/azahar_libretro.so

	  if [ ! -d "../../cores64/" ]; then
		mkdir -v ../../cores64
	  fi

	  cp bin/Release/azahar_libretro.so ../../cores64/.

	  echo ${TAG} > ../../cores64/azahar_libretro.so.commit

	  echo " "
	  echo "azahar_libretro.so has been created and has been placed in the rk3566_core_builds/cores64 subfolder"
	fi
