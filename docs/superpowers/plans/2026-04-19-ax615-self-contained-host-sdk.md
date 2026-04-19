# AX615 Self-Contained Host SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep AX615 builds on the vendor SDK at `/opt/ax/arm-rel-linux-uclibcgnueabihf` while making `output/ax615/host` self-contained and relocatable.

**Architecture:** `build.sh` remains the only entry point. For `ax615` only, it will package the installed vendor SDK into `dl/ax615-sdk-toolchain.tar.xz`, generate a temporary defconfig that flips Buildroot from `PREINSTALLED` external toolchain mode to `DOWNLOAD` external toolchain mode, and run Buildroot with that temporary defconfig so the extracted toolchain lands under `output/ax615/host/opt/ext-toolchain`.

**Tech Stack:** Bash, Buildroot external toolchain support, GNU tar, `find`, `grep`, repository markdown docs.

---

## File Map

- Modify: `build.sh`
  Responsibility: detect AX615 builds, archive `/opt/ax/arm-rel-linux-uclibcgnueabihf`, create a temporary AX615 defconfig, and keep all other boards on the existing path.
- Modify: `readme.md`
  Responsibility: document that AX615 still consumes the vendor SDK from `/opt/ax/...`, but `build.sh ax615` repackages it to produce a self-contained `output/ax615/host`.
- Modify: `AGENTS.md`
  Responsibility: document the same AX615-specific build behavior so future edits do not accidentally revert the self-contained host flow.

### Task 1: Stage the AX615 SDK into `host` Through `build.sh`

**Files:**
- Modify: `build.sh`
- Test: command-line smoke checks from the repo root

- [ ] **Step 1: Write the failing smoke test**

Run:

```bash
rm -rf output/ax615
rm -f dl/ax615-sdk-toolchain.tar.xz
./build.sh ax615 olddefconfig
test -f dl/ax615-sdk-toolchain.tar.xz
grep -q '^BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y$' output/ax615/.config
grep -Eq '^BR2_TOOLCHAIN_EXTERNAL_URL="file://.*/dl/ax615-sdk-toolchain.tar.xz"$' output/ax615/.config
grep -q '^BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="arm-rel-linux-uclibcgnueabihf/bin"$' output/ax615/.config
```

Expected: FAIL before the implementation because the current script does not create `dl/ax615-sdk-toolchain.tar.xz`, and `output/ax615/.config` still stays on `BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y` with `BR2_TOOLCHAIN_EXTERNAL_PATH="/opt/ax/arm-rel-linux-uclibcgnueabihf"`.

- [ ] **Step 2: Run the failing smoke test and capture the failure mode**

Run:

```bash
rm -rf output/ax615
rm -f dl/ax615-sdk-toolchain.tar.xz
./build.sh ax615 olddefconfig
grep -E 'BR2_TOOLCHAIN_EXTERNAL_(DOWNLOAD|PREINSTALLED|PATH|URL|REL_BIN_PATH)' output/ax615/.config
```

Expected output includes:

```text
BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y
BR2_TOOLCHAIN_EXTERNAL_PATH="/opt/ax/arm-rel-linux-uclibcgnueabihf"
```

and does not include:

```text
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
BR2_TOOLCHAIN_EXTERNAL_URL="file://..."
BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="arm-rel-linux-uclibcgnueabihf/bin"
```

- [ ] **Step 3: Write the minimal implementation in `build.sh`**

Replace the current file with:

```bash
#!/bin/bash

set -e

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
AX615_SDK_DIR="/opt/ax/arm-rel-linux-uclibcgnueabihf"
AX615_SDK_ARCHIVE="${REPO_ROOT}/dl/ax615-sdk-toolchain.tar.xz"
AX615_REL_BIN_PATH="arm-rel-linux-uclibcgnueabihf/bin"

die() {
    echo "Error: $*" >&2
    exit 1
}

sdk_archive_needs_refresh() {
    local sdk_dir=$1
    local archive=$2

    [ ! -f "$archive" ] && return 0
    find "$sdk_dir" -mindepth 1 -newer "$archive" -print -quit | grep -q .
}

prepare_ax615_sdk_archive() {
    local sdk_dir=$1
    local archive=$2
    local sdk_parent
    local sdk_name

    [ -d "$sdk_dir" ] || die "AX615 SDK toolchain not found: $sdk_dir"

    mkdir -p "$(dirname "$archive")"

    if [ ! -f "$archive" ] || sdk_archive_needs_refresh "$sdk_dir" "$archive"; then
        rm -f "$archive"
        sdk_parent=$(dirname "$sdk_dir")
        sdk_name=$(basename "$sdk_dir")
        tar -C "$sdk_parent" -cJf "$archive" "$sdk_name" \
            || die "Failed to create AX615 SDK archive: $archive"
    fi
}

create_ax615_temp_defconfig() {
    local base_defconfig=$1
    local output_dir=$2
    local archive=$3
    local temp_defconfig="${output_dir}/ax615-sdk-download.defconfig"

    mkdir -p "$output_dir"

    awk \
        -v toolchain_url="file://${archive}" \
        -v rel_bin_path="${AX615_REL_BIN_PATH}" \
        -v base_defconfig="${base_defconfig}" '
BEGIN {
    seen_download = 0
    seen_preinstalled = 0
    seen_url = 0
    seen_rel_bin = 0
    seen_defconfig = 0
}
$0 == "# BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD is not set" {
    print "BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y"
    seen_download = 1
    next
}
$0 == "BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y" {
    print "# BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set"
    seen_preinstalled = 1
    next
}
$0 ~ /^BR2_TOOLCHAIN_EXTERNAL_PATH=/ {
    next
}
$0 ~ /^BR2_TOOLCHAIN_EXTERNAL_URL=/ {
    print "BR2_TOOLCHAIN_EXTERNAL_URL=\"" toolchain_url "\""
    seen_url = 1
    next
}
$0 ~ /^BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=/ {
    print "BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=\"" rel_bin_path "\""
    seen_rel_bin = 1
    next
}
$0 ~ /^BR2_DEFCONFIG=/ {
    print "BR2_DEFCONFIG=\"" base_defconfig "\""
    seen_defconfig = 1
    next
}
{
    print
}
END {
    if (!seen_download) {
        print "BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y"
    }
    if (!seen_preinstalled) {
        print "# BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED is not set"
    }
    if (!seen_url) {
        print "BR2_TOOLCHAIN_EXTERNAL_URL=\"" toolchain_url "\""
    }
    if (!seen_rel_bin) {
        print "BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH=\"" rel_bin_path "\""
    }
    if (!seen_defconfig) {
        print "BR2_DEFCONFIG=\"" base_defconfig "\""
    }
}' "$base_defconfig" > "$temp_defconfig"

    echo "$temp_defconfig"
}

resolve_defconfig() {
    local board_name=$1
    local config_file=$2
    local output_dir=$3

    if [ "$board_name" != "ax615" ]; then
        echo "$config_file"
        return 0
    fi

    prepare_ax615_sdk_archive "$AX615_SDK_DIR" "$AX615_SDK_ARCHIVE"
    create_ax615_temp_defconfig "$config_file" "$output_dir" "$AX615_SDK_ARCHIVE"
}

main() {
    local board_name
    local config_file
    local output_dir
    local effective_defconfig

    if [ $# -eq 0 ]; then
        echo "Usage: $0 <board_name> [additional_make_args...]"
        exit 1
    fi

    board_name=$1
    shift

    config_file="${REPO_ROOT}/board/${board_name}/configs/defconfig"

    if [ ! -f "$config_file" ]; then
        echo "Error: Config file not found for board: $board_name"
        echo "Expected config file: $config_file"
        exit 1
    fi

    output_dir="${REPO_ROOT}/output/${board_name}"
    effective_defconfig=$(resolve_defconfig "$board_name" "$config_file" "$output_dir")

    make -C buildroot BR2_EXTERNAL="${REPO_ROOT}/general" O="${output_dir}" \
        BR2_DEFCONFIG="${effective_defconfig}" defconfig

    make -C buildroot O="${output_dir}" "$@"
}

main "$@"
```

- [ ] **Step 4: Run syntax and config-generation checks**

Run:

```bash
bash -n build.sh
rm -rf output/ax615
rm -f dl/ax615-sdk-toolchain.tar.xz
./build.sh ax615 olddefconfig
test -f dl/ax615-sdk-toolchain.tar.xz
grep -q '^BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y$' output/ax615/.config
! grep -q '^BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y$' output/ax615/.config
! grep -q '^BR2_TOOLCHAIN_EXTERNAL_PATH=' output/ax615/.config
grep -Eq '^BR2_TOOLCHAIN_EXTERNAL_URL="file://.*/dl/ax615-sdk-toolchain.tar.xz"$' output/ax615/.config
grep -q '^BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="arm-rel-linux-uclibcgnueabihf/bin"$' output/ax615/.config
grep -Eq '^BR2_DEFCONFIG=".*/board/ax615/configs/defconfig"$' output/ax615/.config
```

Expected: all commands pass.

- [ ] **Step 5: Run the full AX615 build and verify the self-contained host toolchain**

Run:

```bash
./build.sh ax615
test -f output/ax615/images/rootfs.tar.gz
output/ax615/host/bin/arm-rel-linux-uclibcgnueabihf-gcc -print-sysroot
strings output/ax615/host/bin/toolchain-wrapper | grep /opt/ax && exit 1 || true
```

Expected:

```text
output/ax615/images/rootfs.tar.gz
```

exists, `-print-sysroot` points inside `output/ax615/host`, and the `strings ... | grep /opt/ax` check produces no match.

- [ ] **Step 6: Commit the build-script change**

Run:

```bash
git add build.sh
git commit -m "build: make ax615 host sdk self-contained"
```

Expected: one commit containing only the `build.sh` implementation for AX615.

### Task 2: Document the AX615 Self-Contained Host Behavior

**Files:**
- Modify: `readme.md`
- Modify: `AGENTS.md`
- Test: grep-based documentation checks

- [ ] **Step 1: Write the failing documentation check**

Run:

```bash
rg -n "ax615-sdk-toolchain|self-contained|自完备" readme.md AGENTS.md
```

Expected: FAIL before the documentation update because neither file explains that `./build.sh ax615` repackages the AX SDK into `dl/ax615-sdk-toolchain.tar.xz` and produces a self-contained `output/ax615/host`.

- [ ] **Step 2: Run the failing documentation check and confirm the gap**

Run:

```bash
rg -n "/opt/ax/arm-rel-linux-uclibcgnueabihf|ax615" readme.md AGENTS.md
```

Expected: both files mention AX615 and `/opt/ax/...`, but neither one states that the build now emits a self-contained host SDK.

- [ ] **Step 3: Add the minimal documentation**

Update `readme.md` AX615 section to:

```md
## ax615
```
```text
外部工具链
/opt/ax/arm-rel-linux-uclibcgnueabihf

构建时会自动将该 SDK 打包为 dl/ax615-sdk-toolchain.tar.xz，
并切换为 Buildroot download external toolchain 模式。
最终生成的 output/ax615/host 可单独拷走使用，不再运行时依赖 /opt/ax。

busybox配置
./build.sh ax615 busybox-menuconfig

配置buildroot
./build.sh ax615 menuconfig

编译
./build.sh ax615
```

Add this note under `## Supported Boards` in `AGENTS.md`:

```md
- **ax615** - AXERA AX615 (Dual ARM Cortex-A7), uses `/opt/ax/arm-rel-linux-uclibcgnueabihf` as the vendor SDK source and repackages it during `./build.sh ax615` so `output/ax615/host` is self-contained
```

- [ ] **Step 4: Run the documentation check again**

Run:

```bash
rg -n "ax615-sdk-toolchain|self-contained|自完备|不再运行时依赖 /opt/ax" readme.md AGENTS.md
```

Expected: matches appear in both files with the new AX615 explanation.

- [ ] **Step 5: Commit the documentation update**

Run:

```bash
git add readme.md AGENTS.md
git commit -m "docs: describe ax615 self-contained host sdk flow"
```

Expected: one commit containing only the documentation changes.
