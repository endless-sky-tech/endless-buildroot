#!/bin/bash

set -euo pipefail

EXT_TC_BUILD_DIR_NAME="toolchain-external"

EXT_TC_ARCHIVE_REFRESHED=0
EXT_TC_ARCHIVE_STAGING_DIR=""
EXT_TC_ARCHIVE_TMP=""
EXT_TC_BOARD=""
EXT_TC_SOURCE_PATH=""
EXT_TC_SOURCE_NAME=""
EXT_TC_PREFIX=""
EXT_TC_ARCHIVE=""
EXT_TC_BUILDROOT_CACHE=""
EXT_TC_REL_BIN_PATH=""
declare -a EXT_TC_CANDIDATES=()

cleanup_external_toolchain_staging() {
    if [ -n "${EXT_TC_ARCHIVE_STAGING_DIR}" ] && [ -d "${EXT_TC_ARCHIVE_STAGING_DIR}" ]; then
        rm -rf "${EXT_TC_ARCHIVE_STAGING_DIR}"
    fi
    if [ -n "${EXT_TC_ARCHIVE_TMP}" ] && [ -e "${EXT_TC_ARCHIVE_TMP}" ]; then
        rm -f "${EXT_TC_ARCHIVE_TMP}"
    fi
}

trap cleanup_external_toolchain_staging EXIT

extract_quoted_config_value() {
    local key=$1
    local config_file=$2

    sed -n -E "s/^${key}=\"([^\"]*)\"$/\\1/p" "$config_file" | head -n1
}

path_size() {
    local path=$1

    if [ ! -e "$path" ]; then
        printf '0'
        return
    fi

    du -sh "$path" 2>/dev/null | awk '{print $1}' || printf 'unknown'
}

run_with_progress() {
    local label=$1
    local progress_path=$2
    local interval=10
    local elapsed=0
    local pid stat size

    shift 2

    echo "${label}..." >&2
    "$@" &
    pid=$!

    while [ -d "/proc/${pid}" ]; do
        stat=$(ps -o stat= -p "$pid" 2>/dev/null || true)
        case "$stat" in
            Z*|"")
                break
                ;;
        esac

        sleep 1
        elapsed=$((elapsed + 1))

        if [ $((elapsed % interval)) -ne 0 ]; then
            continue
        fi

        if [ -e "$progress_path" ]; then
            size=$(path_size "$progress_path")
            echo "${label}... ${elapsed}s elapsed, current size: ${size}" >&2
        else
            echo "${label}... ${elapsed}s elapsed" >&2
        fi
    done

    wait "$pid"
    echo "${label} done." >&2
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

    EXT_TC_SOURCE_PATH=$(extract_quoted_config_value "BR2_TOOLCHAIN_EXTERNAL_PATH" "$config_file")
    EXT_TC_PREFIX=$(extract_quoted_config_value "BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX" "$config_file")

    if [ -z "$EXT_TC_PREFIX" ]; then
        EXT_TC_PREFIX=$(extract_quoted_config_value "BR2_TOOLCHAIN_EXTERNAL_PREFIX" "$config_file")
    fi

    if [ -z "$EXT_TC_SOURCE_PATH" ] || [ -z "$EXT_TC_PREFIX" ]; then
        echo "Error: Missing external toolchain path or prefix in $config_file" >&2
        exit 1
    fi

    EXT_TC_BOARD="$board_name"
    EXT_TC_SOURCE_NAME=$(basename -- "$EXT_TC_SOURCE_PATH")
    EXT_TC_REL_BIN_PATH="${EXT_TC_SOURCE_NAME}/bin"

    return 0
}

set_external_toolchain_archive() {
    local repo_root=$1
    local archive_path=$2
    local rel_bin_path=$3

    EXT_TC_ARCHIVE="$archive_path"
    EXT_TC_REL_BIN_PATH="$rel_bin_path"
    EXT_TC_BUILDROOT_CACHE="${repo_root}/dl/toolchain-external-custom/$(basename -- "$archive_path")"
}

detect_archive_rel_bin_path() {
    local archive_path=$1
    local tool_path

    if [ ! -s "$archive_path" ]; then
        return 1
    fi

    tool_path=$(tar -tf "$archive_path" --wildcards \
        "*/bin/${EXT_TC_PREFIX}-gcc" \
        "*/bin/${EXT_TC_PREFIX}-cc" \
        "*/bin/${EXT_TC_PREFIX}-g++" 2>/dev/null | head -n1 || true)

    if [ -z "$tool_path" ]; then
        return 1
    fi

    dirname "$tool_path"
}

add_candidate_once() {
    local candidate=$1
    local existing

    [ -f "$candidate" ] || return

    for existing in "${EXT_TC_CANDIDATES[@]}"; do
        if [ "$existing" = "$candidate" ]; then
            return
        fi
    done

    EXT_TC_CANDIDATES+=("$candidate")
}

find_existing_toolchain_archive() {
    local repo_root=$1
    local toolchains_dir="${repo_root}/toolchains"
    local candidate rel_bin_path
    local -a invalid_candidates=()

    EXT_TC_CANDIDATES=()

    shopt -s nullglob
    for candidate in \
        "${toolchains_dir}/${EXT_TC_BOARD}-sdk-toolchain.tar.xz" \
        "${toolchains_dir}/${EXT_TC_BOARD}-sdk-toolchain.tar.gz" \
        "${toolchains_dir}/${EXT_TC_BOARD}-sdk-toolchain.tgz" \
        "${toolchains_dir}/"*${EXT_TC_BOARD}*.tar* \
        "${toolchains_dir}/"*${EXT_TC_SOURCE_NAME}*.tar* \
        "${toolchains_dir}/"*${EXT_TC_PREFIX}*.tar*
    do
        add_candidate_once "$candidate"
    done
    shopt -u nullglob

    for candidate in "${EXT_TC_CANDIDATES[@]}"; do
        if rel_bin_path=$(detect_archive_rel_bin_path "$candidate"); then
            set_external_toolchain_archive "$repo_root" "$candidate" "$rel_bin_path"
            echo "Using existing ${EXT_TC_BOARD} toolchain archive: ${EXT_TC_ARCHIVE}" >&2
            echo "Detected toolchain bin path: ${EXT_TC_REL_BIN_PATH}" >&2
            return 0
        fi
        invalid_candidates+=("$candidate")
    done

    if [ ${#invalid_candidates[@]} -gt 0 ]; then
        echo "Error: Found toolchain archive candidates in ${toolchains_dir}, but none contain */bin/${EXT_TC_PREFIX}-gcc" >&2
        printf '  %s\n' "${invalid_candidates[@]}" >&2
        exit 1
    fi

    return 1
}

invalidate_external_toolchain_download_cache() {
    rm -f "$EXT_TC_BUILDROOT_CACHE"
}

ensure_source_toolchain_layout() {
    local -a prefixed_tools

    shopt -s nullglob
    prefixed_tools=("${EXT_TC_SOURCE_PATH}/bin/${EXT_TC_PREFIX}-"*)
    shopt -u nullglob

    if [ ${#prefixed_tools[@]} -eq 0 ]; then
        echo "Error: No toolchain tools matching ${EXT_TC_PREFIX}-* found in ${EXT_TC_SOURCE_PATH}/bin" >&2
        exit 1
    fi
}

invalidate_external_toolchain_state() {
    local output_dir=$1

    rm -rf "${output_dir}/build/${EXT_TC_BUILD_DIR_NAME}"
    rm -rf "${output_dir}/host/opt/ext-toolchain"
}

external_toolchain_state_needs_invalidate() {
    local output_dir=$1
    local config_file="${output_dir}/.config"
    local archive_url="file://${EXT_TC_ARCHIVE}"

    if [ "$EXT_TC_ARCHIVE_REFRESHED" -eq 1 ]; then
        return 0
    fi

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    grep -Fxq "BR2_TOOLCHAIN_EXTERNAL_URL=\"${archive_url}\"" "$config_file" \
        && grep -Fxq "BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=\"${EXT_TC_REL_BIN_PATH}\"" "$config_file" \
        && return 1

    return 0
}

create_toolchain_archive_from_source() {
    local repo_root=$1
    local toolchains_dir="${repo_root}/toolchains"
    local archive_tmp staged_toolchain_path

    if [ ! -d "$EXT_TC_SOURCE_PATH" ]; then
        echo "Error: ${EXT_TC_BOARD} toolchain archive not found in ${toolchains_dir}" >&2
        echo "Expected an archive matching ${EXT_TC_BOARD}, ${EXT_TC_SOURCE_NAME}, or ${EXT_TC_PREFIX}." >&2
        echo "Fallback source path also does not exist: ${EXT_TC_SOURCE_PATH}" >&2
        exit 1
    fi

    ensure_source_toolchain_layout
    mkdir -p "$toolchains_dir"

    set_external_toolchain_archive \
        "$repo_root" \
        "${toolchains_dir}/${EXT_TC_BOARD}-sdk-toolchain.tar.xz" \
        "${EXT_TC_SOURCE_NAME}/bin"

    archive_tmp="${EXT_TC_ARCHIVE}.tmp"
    EXT_TC_ARCHIVE_TMP="$archive_tmp"
    EXT_TC_ARCHIVE_STAGING_DIR=$(mktemp -d)
    staged_toolchain_path="${EXT_TC_ARCHIVE_STAGING_DIR}/${EXT_TC_SOURCE_NAME}"

    echo "Preparing ${EXT_TC_BOARD} external toolchain archive: ${EXT_TC_ARCHIVE}" >&2
    echo "Toolchain source size: $(path_size "$EXT_TC_SOURCE_PATH")" >&2
    rm -f "$archive_tmp"
    run_with_progress \
        "Copying toolchain from ${EXT_TC_SOURCE_PATH}" \
        "$staged_toolchain_path" \
        cp -a "$EXT_TC_SOURCE_PATH" "$EXT_TC_ARCHIVE_STAGING_DIR/"
    run_with_progress \
        "Compressing toolchain archive to ${EXT_TC_ARCHIVE}" \
        "$archive_tmp" \
        tar -C "$EXT_TC_ARCHIVE_STAGING_DIR" -cJf "$archive_tmp" "$EXT_TC_SOURCE_NAME"
    mv "$archive_tmp" "$EXT_TC_ARCHIVE"
    echo "Created ${EXT_TC_BOARD} external toolchain archive: ${EXT_TC_ARCHIVE} ($(path_size "$EXT_TC_ARCHIVE"))" >&2

    EXT_TC_ARCHIVE_TMP=""
    cleanup_external_toolchain_staging
    EXT_TC_ARCHIVE_STAGING_DIR=""
    EXT_TC_ARCHIVE_REFRESHED=1
    invalidate_external_toolchain_download_cache
}

resolve_external_toolchain_archive() {
    local repo_root=$1

    EXT_TC_ARCHIVE_REFRESHED=0

    if find_existing_toolchain_archive "$repo_root"; then
        if [ -e "$EXT_TC_BUILDROOT_CACHE" ] && [ "$EXT_TC_ARCHIVE" -nt "$EXT_TC_BUILDROOT_CACHE" ]; then
            invalidate_external_toolchain_download_cache
        fi
        return
    fi

    create_toolchain_archive_from_source "$repo_root"
}

create_external_toolchain_defconfig() {
    local source_defconfig=$1
    local temp_defconfig=$2
    local archive_url="file://${EXT_TC_ARCHIVE}"

    mkdir -p "$(dirname "$temp_defconfig")"

    grep -vE '^(# )?BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD is not set$|^BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=|^(# )?BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set$|^BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=|^BR2_TOOLCHAIN_EXTERNAL_PATH=|^BR2_TOOLCHAIN_EXTERNAL_URL=|^BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=|^BR2_DEFCONFIG=' \
        "$source_defconfig" > "$temp_defconfig"

    cat <<EOF >> "$temp_defconfig"
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
# BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set
BR2_TOOLCHAIN_EXTERNAL_URL="${archive_url}"
BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="${EXT_TC_REL_BIN_PATH}"
BR2_DEFCONFIG="${source_defconfig}"
EOF
}

external_toolchain_resolve_defconfig() {
    local repo_root=$1
    local board_name=$2
    local config_file=$3
    local output_dir=$4
    local temp_defconfig

    if ! load_external_toolchain_context "$board_name" "$config_file"; then
        printf '%s\n' "$config_file"
        return
    fi

    resolve_external_toolchain_archive "$repo_root"
    if external_toolchain_state_needs_invalidate "$output_dir"; then
        invalidate_external_toolchain_state "$output_dir"
    fi

    temp_defconfig="${output_dir}/${board_name}-sdk-toolchain.defconfig"
    create_external_toolchain_defconfig "$config_file" "$temp_defconfig"
    printf '%s\n' "$temp_defconfig"
}

usage() {
    echo "Usage: $0 resolve-defconfig <repo_root> <board_name> <defconfig> <output_dir>" >&2
}

main() {
    local command=${1:-}

    case "$command" in
        resolve-defconfig)
            shift
            if [ $# -ne 4 ]; then
                usage
                exit 1
            fi
            external_toolchain_resolve_defconfig "$@"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
