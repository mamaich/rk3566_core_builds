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
# Azahar 2126.1.2 with GammaOS's azahar-nano changes (patches/azahar-patch-000,
# from GammaOSNextDistribution-14 8d68e5ecaab), the release they are made on,
# and ours on top (001 layout, 002-005 to build and run them here).
TAG="2126.1.2"
NANO="8d68e5ecaab"
# Profile for clang's profile-guided optimisation: Super Mario 3D Land played
# on an RG52 Mini with an instrumented build of this recipe (2026-10-20),
# merged with GammaOS's own for azahar-nano (21714041b96, 2026-10-13: Kirby,
# Senran Kagura, Metroid, Pokemon Sun, Mario Kart 7 and Super Mario 3D Land
# save states), ours weighted 2 so both carry about the same total count.
# Theirs alone fits this build badly: made on Android (libc++, the NDK's
# clang 18), 44% of its counts are on functions whose code differs here, and
# clang drops those. A new profile changes this line, so the recipe's cache
# key changes with it.
PGO="pgo/azahar-nano-merged-20261020.profdata.gz"
PGO_SHA256="60af4f31938eec43b06ee1a5ba96beed61c0ae3186e37d32e070e0bd2be79971"

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
	  # clang with the profile. On the RG52 Mini (Super Mario 3D Land, 1-1,
	  # CPU capped at 816 MHz) azahar-nano ran at 24.7 fps without one, 24.8
	  # with GammaOS's alone and at the game's full 30 with this one; with the
	  # CPU at 1008 MHz 2126.2 ran at 24 fps, this core at 30. Upstream's LTO
	  # is off: it added nothing on top of a profile here and would need lld.
	  pgo_flags="-fprofile-use=$cur_wd/azahar/azahar.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin"
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

	  echo ${TAG}+azahar-nano-${NANO} > ../../cores64/azahar_libretro.so.commit

	  echo " "
	  echo "azahar_libretro.so has been created and has been placed in the rk3566_core_builds/cores64 subfolder"
	fi
