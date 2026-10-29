#!/usr/bin/env bash

set -euo pipefail

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
JOBS="$(nproc --all)"

CLANG_DIR="${KERNEL_DIR}/neutron-clang"
CLANG_BIN="${CLANG_DIR}/bin"
ANYKERNEL_DIR="${KERNEL_DIR}/tools/AnyKernel3"
ARCH="arm64"

DEFCONFIG="beryllium_defconfig"
KERNEL_IMAGE="Image.gz-dtb"
KERNEL_NAME="Miru"

DO_CLEAN="true"

export PATH="${CLANG_BIN}:${PATH}"
export ARCH="${ARCH}"
export SUBARCH="${ARCH}"
export KBUILD_BUILD_USER=miru
export KBUILD_BUILD_HOST=archlinux

MAKE_ARGS=(
	O="${OUT_DIR}"
	ARCH="${ARCH}"
	SUBARCH="${ARCH}"
	LLVM=1
	LLVM_IAS=1
	CC="clang"
	LD="ld.lld"
	AR="llvm-ar"
	NM="llvm-nm"
	HOSTCC="gcc"
	HOSTCXX="g++"
	OBJCOPY="llvm-objcopy"
	OBJDUMP="llvm-objdump"
	STRIP="llvm-strip"
	OBJSIZE="llvm-size"
	READELF="llvm-readelf"
	CROSS_COMPILE="aarch64-linux-gnu-"
	CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
	CLANG_TRIPLE="aarch64-linux-gnu-"
	LOCALVERSION="-美瑠/${KERNEL_NAME}"
)

hard_clean() {
	make mrproper
	echo "removing folder out"
	rm -rf "${OUT_DIR}"

	mkdir -p "${OUT_DIR}"
	echo "generate out"
}

build_kernel() {
	if [ -f "${OUT_DIR}/.version" ]; then
		rm "${OUT_DIR}/.version"
	fi

	echo "Starting kernel compilation using ${JOBS} cores"

	if make -C "${KERNEL_DIR}" "${MAKE_ARGS[@]}" -j"${JOBS}" 2>&1 | tee "${OUT_DIR}/build.log"; then
		echo "Kernel compilation finished successfully."
	else
		echo "Build failed! Check ${OUT_DIR}/build.log for details."
		exit 1
	fi

	if [ ! -f "${OUT_DIR}/arch/${ARCH}/boot/${KERNEL_IMAGE}" ]; then
		echo "Kernel image not found: ${OUT_DIR}/arch/${ARCH}/boot/${KERNEL_IMAGE}"
		echo "Build failed! Check ${OUT_DIR}/build.log for details."
		exit 1
	fi
}

package_anykernel() {
	echo "Packaging kernel with AnyKernel3"

	local current_kernel_name="${KERNEL_NAME}"

	if [ -d "${ANYKERNEL_DIR}" ]; then
		cd "${ANYKERNEL_DIR}"

		mkdir -p "${OUT_DIR}/zip"

		rm -rf *.zip Image.gz-dtb
		if [ -f "${OUT_DIR}/arch/${ARCH}/boot/${KERNEL_IMAGE}" ]; then
			cp "${OUT_DIR}/arch/${ARCH}/boot/${KERNEL_IMAGE}" "${ANYKERNEL_DIR}/"

			ZIP_NAME="${current_kernel_name}-Beryllium-$(date +%d%m%Y-%H%M).zip"
			zip -r9 "${ZIP_NAME}" * -x "*.git*" "README.md"

			mv "${ZIP_NAME}" "${OUT_DIR}/zip/"
			echo "SUCCESS: File ${ZIP_NAME} is in out/zip/ directory!"
		else
			echo "ERROR: File ${KERNEL_IMAGE} not found!"
			exit 1
		fi
	else
		echo "ERROR: File not found ${ANYKERNEL_DIR}!"
		exit 1
	fi
}

main() {
	if [ "${DO_CLEAN}" = "true" ]; then
		hard_clean
	fi

	make -C "${KERNEL_DIR}" "${MAKE_ARGS[@]}" "${DEFCONFIG}"
	build_kernel
	package_anykernel
}

main
