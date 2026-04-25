#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${SCRIPT_DIR}"
BUILDROOT_DIR="${REPO_ROOT}/buildroot"
BR2_EXTERNAL_DIR="${REPO_ROOT}/general"
EXTERNAL_TOOLCHAIN_SDK_SCRIPT="${REPO_ROOT}/external-toolchain-sdk.sh"

uses_board_defconfig_for_target() {
    if [ $# -ne 1 ]; then
        return 1
    fi

    case "$1" in
        defconfig|olddefconfig|oldconfig|savedefconfig|menuconfig|nconfig|gconfig|xconfig|\
        busybox-menuconfig|busybox-nconfig|busybox-xconfig|busybox-savedefconfig|\
        linux-menuconfig|linux-nconfig|linux-xconfig|linux-savedefconfig)
            return 0
            ;;
    esac

    return 1
}

main() {
    local board_name config_file output_dir effective_defconfig
    local prepare_sdk_after_build=0

    if [ $# -eq 0 ]; then
        echo "Usage: $0 <board_name> [additional_make_args...]"
        exit 1
    fi

    board_name=$1
    shift  # 移除第一个参数（board名称）

    if [ $# -eq 0 ]; then
        prepare_sdk_after_build=1
    fi

    config_file="${REPO_ROOT}/board/${board_name}/configs/defconfig"

    if [ ! -f "$config_file" ]; then
        echo "Error: Config file not found for board: $board_name"
        echo "Expected config file: $config_file"
        exit 1
    fi

    output_dir="${REPO_ROOT}/output/${board_name}"
    if uses_board_defconfig_for_target "$@"; then
        effective_defconfig="$config_file"
    else
        effective_defconfig=$(bash "$EXTERNAL_TOOLCHAIN_SDK_SCRIPT" \
            resolve-defconfig "$REPO_ROOT" "$board_name" "$config_file" "$output_dir")
    fi

    # 生成默认配置
    make -C "$BUILDROOT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL_DIR" O="${output_dir}" BR2_DEFCONFIG="$effective_defconfig" defconfig

    if [ $# -eq 1 ] && [ "$1" = "defconfig" ]; then
        exit 0
    fi

    # 编译
    make -C "$BUILDROOT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL_DIR" O="${output_dir}" "$@"

    if [ "$prepare_sdk_after_build" -eq 1 ]; then
        make -C "$BUILDROOT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL_DIR" O="${output_dir}" prepare-sdk
    fi
}

main "$@"
