#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${SCRIPT_DIR}"
BUILDROOT_DIR="${REPO_ROOT}/buildroot"
BR2_EXTERNAL_DIR="${REPO_ROOT}/general"

AX615_BOARD="ax615"
AX615_SDK_ROOT="/opt/ax"
AX615_SDK_NAME="arm-rel-linux-uclibcgnueabihf"
AX615_SDK_PATH="${AX615_SDK_ROOT}/${AX615_SDK_NAME}"
AX615_SDK_ARCHIVE="${REPO_ROOT}/dl/ax615-sdk-toolchain.tar.xz"
AX615_SDK_BUILDROOT_CACHE="${REPO_ROOT}/dl/toolchain-external-custom/ax615-sdk-toolchain.tar.xz"
AX615_SDK_REL_BIN_PATH="${AX615_SDK_NAME}/bin"
AX615_TOOLCHAIN_BUILD_DIR_NAME="toolchain-external"

AX615_SDK_ARCHIVE_REFRESHED=0
AX615_SDK_ARCHIVE_STAGING_DIR=""

cleanup_ax615_sdk_archive_staging() {
    if [ -n "${AX615_SDK_ARCHIVE_STAGING_DIR}" ] && [ -d "${AX615_SDK_ARCHIVE_STAGING_DIR}" ]; then
        rm -rf "${AX615_SDK_ARCHIVE_STAGING_DIR}"
    fi
}

trap cleanup_ax615_sdk_archive_staging EXIT

ax615_archive_has_expected_layout() {
    local archive_path=$1
    local expected_tool_path_prefix="${AX615_SDK_NAME}/${AX615_SDK_REL_BIN_PATH}"

    if [ ! -s "$archive_path" ]; then
        return 1
    fi

    tar -tf "$archive_path" --wildcards \
        "${expected_tool_path_prefix}/${AX615_SDK_NAME}-*" >/dev/null 2>&1
}

invalidate_ax615_sdk_download_cache() {
    rm -f "$AX615_SDK_BUILDROOT_CACHE"
}

archive_needs_refresh() {
    local sdk_path=$1
    local archive_path=$2

    if [ ! -s "$archive_path" ]; then
        return 0
    fi

    if find "$sdk_path" -newer "$archive_path" -print -quit | grep -q .; then
        return 0
    fi

    return 1
}

populate_ax615_sdk_links() {
    local staged_sdk_path=$1
    local nested_bin tool tool_name
    local -a prefixed_tools

    nested_bin="${staged_sdk_path}/${AX615_SDK_NAME}/bin"
    mkdir -p "$nested_bin"

    shopt -s nullglob
    prefixed_tools=("${staged_sdk_path}/bin/${AX615_SDK_NAME}-"*)
    shopt -u nullglob

    if [ ${#prefixed_tools[@]} -eq 0 ]; then
        echo "Error: No AX615 SDK tools matching ${AX615_SDK_NAME}-* found in ${staged_sdk_path}/bin"
        exit 1
    fi

    for tool in "${prefixed_tools[@]}"; do
        tool_name=$(basename "$tool")
        ln -sf "../../bin/${tool_name}" "${nested_bin}/${tool_name}"
    done
}

invalidate_ax615_toolchain_state() {
    local output_dir=$1

    rm -rf "${output_dir}/build/${AX615_TOOLCHAIN_BUILD_DIR_NAME}"
    rm -rf "${output_dir}/host/opt/ext-toolchain"
}

refresh_ax615_sdk_archive() {
    local archive_dir archive_tmp staged_sdk_path
    local archive_has_expected_layout=0

    AX615_SDK_ARCHIVE_REFRESHED=0
    AX615_SDK_ARCHIVE_STAGING_DIR=""

    if ax615_archive_has_expected_layout "$AX615_SDK_ARCHIVE"; then
        archive_has_expected_layout=1
    fi

    if [ "$archive_has_expected_layout" -eq 1 ] && [ -d "$AX615_SDK_PATH" ] && ! archive_needs_refresh "$AX615_SDK_PATH" "$AX615_SDK_ARCHIVE"; then
        if [ -e "$AX615_SDK_BUILDROOT_CACHE" ] && [ "$AX615_SDK_ARCHIVE" -nt "$AX615_SDK_BUILDROOT_CACHE" ]; then
            invalidate_ax615_sdk_download_cache
        fi
        return
    fi

    if [ "$archive_has_expected_layout" -eq 1 ] && [ ! -d "$AX615_SDK_PATH" ]; then
        echo "Warning: AX615 SDK source not found at ${AX615_SDK_PATH}; reusing existing archive ${AX615_SDK_ARCHIVE}" >&2
        if [ -e "$AX615_SDK_BUILDROOT_CACHE" ] && [ "$AX615_SDK_ARCHIVE" -nt "$AX615_SDK_BUILDROOT_CACHE" ]; then
            invalidate_ax615_sdk_download_cache
        fi
        return
    fi

    if [ -s "$AX615_SDK_ARCHIVE" ] && [ "$archive_has_expected_layout" -ne 1 ]; then
        echo "Warning: AX615 SDK archive ${AX615_SDK_ARCHIVE} is missing expected staged layout ${AX615_SDK_REL_BIN_PATH}; rebuilding it" >&2
    fi

    if [ ! -d "$AX615_SDK_PATH" ]; then
        echo "Error: AX615 SDK not found: $AX615_SDK_PATH"
        exit 1
    fi

    archive_dir=$(dirname "$AX615_SDK_ARCHIVE")
    archive_tmp="${AX615_SDK_ARCHIVE}.tmp"
    AX615_SDK_ARCHIVE_STAGING_DIR=$(mktemp -d)
    staged_sdk_path="${AX615_SDK_ARCHIVE_STAGING_DIR}/${AX615_SDK_NAME}"

    mkdir -p "$archive_dir"
    rm -f "$archive_tmp"
    cp -a "$AX615_SDK_PATH" "$AX615_SDK_ARCHIVE_STAGING_DIR/"
    populate_ax615_sdk_links "$staged_sdk_path"
    tar -C "$AX615_SDK_ARCHIVE_STAGING_DIR" -cJf "$archive_tmp" "$AX615_SDK_NAME"
    mv "$archive_tmp" "$AX615_SDK_ARCHIVE"
    cleanup_ax615_sdk_archive_staging
    AX615_SDK_ARCHIVE_STAGING_DIR=""
    AX615_SDK_ARCHIVE_REFRESHED=1

    if [ "$AX615_SDK_ARCHIVE_REFRESHED" -eq 1 ]; then
        invalidate_ax615_sdk_download_cache
    fi
}

create_ax615_defconfig() {
    local source_defconfig=$1
    local temp_defconfig=$2
    local archive_url="file://${AX615_SDK_ARCHIVE}"

    mkdir -p "$(dirname "$temp_defconfig")"

    grep -vE '^(# )?BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD is not set$|^BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=|^(# )?BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set$|^BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=|^BR2_TOOLCHAIN_EXTERNAL_PATH=|^BR2_TOOLCHAIN_EXTERNAL_URL=|^BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=|^BR2_DEFCONFIG=' \
        "$source_defconfig" > "$temp_defconfig"

    cat <<EOF >> "$temp_defconfig"
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
# BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set
BR2_TOOLCHAIN_EXTERNAL_URL="${archive_url}"
BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="${AX615_SDK_REL_BIN_PATH}"
BR2_DEFCONFIG="${source_defconfig}"
EOF
}

resolve_defconfig() {
    local board_name=$1
    local config_file=$2
    local output_dir=$3
    local temp_defconfig

    if [ "$board_name" != "$AX615_BOARD" ]; then
        printf '%s\n' "$config_file"
        return
    fi

    refresh_ax615_sdk_archive
    if [ "$AX615_SDK_ARCHIVE_REFRESHED" -eq 1 ]; then
        invalidate_ax615_toolchain_state "$output_dir"
    fi
    temp_defconfig="${output_dir}/ax615-sdk-toolchain.defconfig"
    create_ax615_defconfig "$config_file" "$temp_defconfig"
    printf '%s\n' "$temp_defconfig"
}

main() {
    local board_name config_file output_dir effective_defconfig

    if [ $# -eq 0 ]; then
        echo "Usage: $0 <board_name> [additional_make_args...]"
        exit 1
    fi

    board_name=$1
    shift  # 移除第一个参数（board名称）

    config_file="${REPO_ROOT}/board/${board_name}/configs/defconfig"

    if [ ! -f "$config_file" ]; then
        echo "Error: Config file not found for board: $board_name"
        echo "Expected config file: $config_file"
        exit 1
    fi

    output_dir="${REPO_ROOT}/output/${board_name}"
    effective_defconfig=$(resolve_defconfig "$board_name" "$config_file" "$output_dir")

    # 生成默认配置
    make -C "$BUILDROOT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL_DIR" O="${output_dir}" BR2_DEFCONFIG="$effective_defconfig" defconfig

    # 编译
    make -C "$BUILDROOT_DIR" BR2_EXTERNAL="$BR2_EXTERNAL_DIR" O="${output_dir}" "$@"
}

main "$@"
