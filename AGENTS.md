# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Buildroot 2024.02.6 工程，用于构建多平台嵌入式 Linux 文件系统。使用 BR2_EXTERNAL 机制管理自定义包和配置。

## Build Commands

```bash
# 完整构建
./build.sh <board_name>

# 配置 Buildroot
./build.sh <board_name> menuconfig

# 配置 BusyBox
./build.sh <board_name> busybox-menuconfig

# 配置 Linux 内核 (仅 aarch64)
./build.sh <board_name> linux-menuconfig
./build.sh <board_name> linux-savedefconfig

# 重新构建单个包
./build.sh <board_name> <package>-rebuild
./build.sh <board_name> <package>-reconfigure

# 清理构建
./build.sh <board_name> clean
```

## External Toolchain Notes

- 使用 `BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD` 的板子，需要先准备好 `BR2_TOOLCHAIN_EXTERNAL_URL` 指向的工具链压缩包；本仓库建议统一放在 `dl/toolchains/`
- 常见做法是先将宿主机上的预装工具链目录打包，再交给 Buildroot 下载并安装到 `output/<board>/host/opt/ext-toolchain/`
- 工具链压缩包和 GitHub Release 中的 SDK 资产统一使用以下命名格式：

```text
toolchain-<chip>-<tc_ver>-gcc<gcc_ver>-linux<headers_ver>-<arch>-<libc>-YYYY.MM.DD.tar.gz
```

- 命名要求：
  - `chip` 放在最前面，优先体现芯片或平台
  - `tc_ver` 单独表示工具链版本，不与 GCC 版本混用
  - `gcc_ver`、`linux<headers_ver>`、`arch`、`libc` 必须保留，确保兼容信息完整
  - 日期固定放在文件名末尾，格式统一为 `YYYY.MM.DD`
  - 本地 `dl/toolchains/` 文件名与 GitHub Release 资产名保持一致
- 当前命名示例：
  - `toolchain-hi3516cv610-v01c02-gcc10-linux5.10-armv7-musl-2026.04.11.tar.gz`
  - `toolchain-hi3519dv500-v01c01-gcc10-linux5.10-aarch64-glibc-2026.04.11.tar.gz`
  - `toolchain-gk7206-gcc12.2.0-linux5.10-armv7-uclibc-2026.04.11.tar.gz`
  - `toolchain-rk1126b-rockchip1240-gcc12-linux6.1-armv7-glibc-2026.04.11.tar.gz`
- 通用示例：

```bash
mkdir -p dl/toolchains
tar -C <toolchain_parent_dir> -czf dl/toolchains/<toolchain_name>.tar.gz <toolchain_name>
```

- 例如：`tar -C /opt/linux/x86-arm -czf dl/toolchains/arm-v01c02-linux-musleabi-gcc.tar.gz arm-v01c02-linux-musleabi-gcc`
- 默认执行 `./build.sh <board_name>` 时，脚本会在构建完成后自动执行 `prepare-sdk`，因此 `output/<board>/host/` 可以整体拷走
- 如果将 `host/` 拷贝到新路径，先执行 `output/<board>/host/relocate-sdk.sh`

## Supported Boards

- **aarch64** - ARM64 Cortex-A53
- **3516cv610** - HiSilicon Hi3516CV610 (ARM Cortex-A7)
- **3519dv500** - HiSilicon Hi3519DV500
- **gk7206** - ARM Cortex-A7
- **rk1126b** - Rockchip 32-bit platform

## Architecture

```
board/<board>/configs/defconfig  # 板级 Buildroot 配置
board/<board>/configs/busybox_config  # BusyBox 配置
general/                         # BR2_EXTERNAL 外部树
  ├── package/                   # 自定义包 (如 zlmediakit)
  ├── overlay/                   # 根文件系统覆盖层
  └── scripts/                   # 构建脚本
output/<board>/images/           # 构建输出 (rootfs, kernel 等)
```

## Excluded Directories

- `dl/` - 下载的源码包
- `output/` - 构建输出目录
