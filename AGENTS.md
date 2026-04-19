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

## Supported Boards

- **aarch64** - ARM64 Cortex-A53
- **3516cv610** - HiSilicon Hi3516CV610 (ARM Cortex-A7)
- **ax615** - AXERA AX615 (Dual ARM Cortex-A7). 使用 `/opt/ax/arm-rel-linux-uclibcgnueabihf` 作为 vendor SDK source，`./build.sh ax615` 会自动 repackaging 为 `dl/ax615-sdk-toolchain.tar.xz`，并让最终的 `output/ax615/host` 保持 self-contained，不再运行时依赖 `/opt/ax`。
- **3519dv500** - HiSilicon Hi3519DV500
- **3403** - ARM platform
- **22ap10** - ARM Cortex-A7
- **m64x86** - x86_64

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
