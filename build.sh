#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${SCRIPT_DIR}"
BUILDROOT_DIR="${REPO_ROOT}/buildroot"
BR2_EXTERNAL_DIR="${REPO_ROOT}/general"

TOOLCHAIN_BUILDROOT_CACHE_ROOT="${REPO_ROOT}/dl/toolchain-external-custom"
TOOLCHAIN_BUILD_DIR_NAME="toolchain-external"

TOOLCHAIN_ARCHIVE_REFRESHED=0
TOOLCHAIN_ARCHIVE_STAGING_DIR=""
TOOLCHAIN_BOARD=""
TOOLCHAIN_SOURCE_PATH=""
TOOLCHAIN_SOURCE_NAME=""
TOOLCHAIN_PREFIX=""
TOOLCHAIN_ARCHIVE=""
TOOLCHAIN_BUILDROOT_CACHE=""
TOOLCHAIN_REL_BIN_PATH=""

cleanup_toolchain_archive_staging() {
    if [ -n "${TOOLCHAIN_ARCHIVE_STAGING_DIR}" ] && [ -d "${TOOLCHAIN_ARCHIVE_STAGING_DIR}" ]; then
        rm -rf "${TOOLCHAIN_ARCHIVE_STAGING_DIR}"
    fi
}

trap cleanup_toolchain_archive_staging EXIT

extract_quoted_config_value() {
    local key=$1
    local config_file=$2

    sed -n -E "s/^${key}=\"([^\"]*)\"$/\\1/p" "$config_file" | head -n1
}

has_preinstalled_external_toolchain() {
    local config_file=$1

    grep -q '^BR2_TOOLCHAIN_EXTERNAL=y$' "$config_file" \
        && grep -q '^BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y$' "$config_file"
}

load_external_toolchain_context() {
    local board_name=$1
    local config_file=$2

    if ! has_preinstalled_external_toolchain "$config_file"; then
        return 1
    fi

    TOOLCHAIN_SOURCE_PATH=$(extract_quoted_config_value "BR2_TOOLCHAIN_EXTERNAL_PATH" "$config_file")
    TOOLCHAIN_PREFIX=$(extract_quoted_config_value "BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX" "$config_file")

    if [ -z "$TOOLCHAIN_PREFIX" ]; then
        TOOLCHAIN_PREFIX=$(extract_quoted_config_value "BR2_TOOLCHAIN_EXTERNAL_PREFIX" "$config_file")
    fi

    if [ -z "$TOOLCHAIN_SOURCE_PATH" ] || [ -z "$TOOLCHAIN_PREFIX" ]; then
        echo "Error: Missing external toolchain path or prefix in $config_file"
        exit 1
    fi

    TOOLCHAIN_BOARD="$board_name"
    TOOLCHAIN_SOURCE_NAME=$(basename -- "$TOOLCHAIN_SOURCE_PATH")
    TOOLCHAIN_ARCHIVE="${REPO_ROOT}/dl/${TOOLCHAIN_BOARD}-sdk-toolchain.tar.xz"
    TOOLCHAIN_BUILDROOT_CACHE="${TOOLCHAIN_BUILDROOT_CACHE_ROOT}/$(basename -- "$TOOLCHAIN_ARCHIVE")"
    TOOLCHAIN_REL_BIN_PATH="${TOOLCHAIN_SOURCE_NAME}/bin"

    return 0
}

external_toolchain_archive_has_expected_layout() {
    local archive_path=$1
    local expected_tool_path_prefix="${TOOLCHAIN_SOURCE_NAME}/${TOOLCHAIN_REL_BIN_PATH}"

    if [ ! -s "$archive_path" ]; then
        return 1
    fi

    tar -tf "$archive_path" --wildcards \
        "${expected_tool_path_prefix}/${TOOLCHAIN_PREFIX}-*" >/dev/null 2>&1
}

invalidate_external_toolchain_download_cache() {
    rm -f "$TOOLCHAIN_BUILDROOT_CACHE"
}

archive_needs_refresh() {
    local source_path=$1
    local archive_path=$2

    if [ ! -s "$archive_path" ]; then
        return 0
    fi

    if find "$source_path" -newer "$archive_path" -print -quit | grep -q .; then
        return 0
    fi

    return 1
}

populate_external_toolchain_links() {
    local staged_toolchain_path=$1
    local nested_bin tool tool_name
    local -a prefixed_tools

    nested_bin="${staged_toolchain_path}/${TOOLCHAIN_SOURCE_NAME}/bin"
    mkdir -p "$nested_bin"

    shopt -s nullglob
    prefixed_tools=("${staged_toolchain_path}/bin/${TOOLCHAIN_PREFIX}-"*)
    shopt -u nullglob

    if [ ${#prefixed_tools[@]} -eq 0 ]; then
        echo "Error: No toolchain tools matching ${TOOLCHAIN_PREFIX}-* found in ${staged_toolchain_path}/bin"
        exit 1
    fi

    for tool in "${prefixed_tools[@]}"; do
        tool_name=$(basename "$tool")
        ln -sf "../../bin/${tool_name}" "${nested_bin}/${tool_name}"
    done
}

invalidate_external_toolchain_state() {
    local output_dir=$1

    rm -rf "${output_dir}/build/${TOOLCHAIN_BUILD_DIR_NAME}"
    rm -rf "${output_dir}/host/opt/ext-toolchain"
}

refresh_external_toolchain_archive() {
    local archive_dir archive_tmp staged_toolchain_path
    local archive_has_expected_layout=0

    TOOLCHAIN_ARCHIVE_REFRESHED=0
    TOOLCHAIN_ARCHIVE_STAGING_DIR=""

    if external_toolchain_archive_has_expected_layout "$TOOLCHAIN_ARCHIVE"; then
        archive_has_expected_layout=1
    fi

    if [ "$archive_has_expected_layout" -eq 1 ] && [ -d "$TOOLCHAIN_SOURCE_PATH" ] && ! archive_needs_refresh "$TOOLCHAIN_SOURCE_PATH" "$TOOLCHAIN_ARCHIVE"; then
        if [ -e "$TOOLCHAIN_BUILDROOT_CACHE" ] && [ "$TOOLCHAIN_ARCHIVE" -nt "$TOOLCHAIN_BUILDROOT_CACHE" ]; then
            invalidate_external_toolchain_download_cache
        fi
        return
    fi

    if [ "$archive_has_expected_layout" -eq 1 ] && [ ! -d "$TOOLCHAIN_SOURCE_PATH" ]; then
        echo "Warning: ${TOOLCHAIN_BOARD} toolchain source not found at ${TOOLCHAIN_SOURCE_PATH}; reusing existing archive ${TOOLCHAIN_ARCHIVE}" >&2
        if [ -e "$TOOLCHAIN_BUILDROOT_CACHE" ] && [ "$TOOLCHAIN_ARCHIVE" -nt "$TOOLCHAIN_BUILDROOT_CACHE" ]; then
            invalidate_external_toolchain_download_cache
        fi
        return
    fi

    if [ -s "$TOOLCHAIN_ARCHIVE" ] && [ "$archive_has_expected_layout" -ne 1 ]; then
        echo "Warning: ${TOOLCHAIN_BOARD} toolchain archive ${TOOLCHAIN_ARCHIVE} is missing expected staged layout ${TOOLCHAIN_REL_BIN_PATH}; rebuilding it" >&2
    fi

    if [ ! -d "$TOOLCHAIN_SOURCE_PATH" ]; then
        echo "Error: ${TOOLCHAIN_BOARD} toolchain not found: $TOOLCHAIN_SOURCE_PATH"
        exit 1
    fi

    archive_dir=$(dirname "$TOOLCHAIN_ARCHIVE")
    archive_tmp="${TOOLCHAIN_ARCHIVE}.tmp"
    TOOLCHAIN_ARCHIVE_STAGING_DIR=$(mktemp -d)
    staged_toolchain_path="${TOOLCHAIN_ARCHIVE_STAGING_DIR}/${TOOLCHAIN_SOURCE_NAME}"

    mkdir -p "$archive_dir"
    rm -f "$archive_tmp"
    cp -a "$TOOLCHAIN_SOURCE_PATH" "$TOOLCHAIN_ARCHIVE_STAGING_DIR/"
    populate_external_toolchain_links "$staged_toolchain_path"
    tar -C "$TOOLCHAIN_ARCHIVE_STAGING_DIR" -cJf "$archive_tmp" "$TOOLCHAIN_SOURCE_NAME"
    mv "$archive_tmp" "$TOOLCHAIN_ARCHIVE"
    cleanup_toolchain_archive_staging
    TOOLCHAIN_ARCHIVE_STAGING_DIR=""
    TOOLCHAIN_ARCHIVE_REFRESHED=1

    if [ "$TOOLCHAIN_ARCHIVE_REFRESHED" -eq 1 ]; then
        invalidate_external_toolchain_download_cache
    fi
}

create_external_toolchain_defconfig() {
    local source_defconfig=$1
    local temp_defconfig=$2
    local archive_url="file://${TOOLCHAIN_ARCHIVE}"

    mkdir -p "$(dirname "$temp_defconfig")"

    grep -vE '^(# )?BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD is not set$|^BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=|^(# )?BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set$|^BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=|^BR2_TOOLCHAIN_EXTERNAL_PATH=|^BR2_TOOLCHAIN_EXTERNAL_URL=|^BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=|^BR2_DEFCONFIG=' \
        "$source_defconfig" > "$temp_defconfig"

    cat <<EOF >> "$temp_defconfig"
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
# BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set
BR2_TOOLCHAIN_EXTERNAL_URL="${archive_url}"
BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="${TOOLCHAIN_REL_BIN_PATH}"
BR2_DEFCONFIG="${source_defconfig}"
EOF
}

resolve_defconfig() {
    local board_name=$1
    local config_file=$2
    local output_dir=$3
    local temp_defconfig

    if ! load_external_toolchain_context "$board_name" "$config_file"; then
        printf '%s\n' "$config_file"
        return
    fi

    refresh_external_toolchain_archive
    if [ "$TOOLCHAIN_ARCHIVE_REFRESHED" -eq 1 ]; then
        invalidate_external_toolchain_state "$output_dir"
    fi
    temp_defconfig="${output_dir}/${board_name}-sdk-toolchain.defconfig"
    create_external_toolchain_defconfig "$config_file" "$temp_defconfig"
    printf '%s\n' "$temp_defconfig"
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
    effective_defconfig=$(resolve_defconfig "$board_name" "$config_file" "$output_dir")

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
