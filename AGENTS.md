# CLAUDE.md

## 核心规则
- 对话、文档、注释、git提交日志都必须使用中文，代码中的日志打印必须使用英文
- 每次回复必须称呼 endless
- 如果没有显性要求，不要操作 Git 提交、变基、回滚

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
- **3516cv610** - HiSilicon Hi3516CV610 (ARM Cortex-A7). 使用 `/opt/linux/x86-arm/arm-v01c02-linux-musleabi-gcc` 作为 vendor toolchain source，`./build.sh 3516cv610` 会优先复用 `toolchains/` 下已有工具链压缩包；不存在时才按需生成 `toolchains/3516cv610-sdk-toolchain.tar.xz`，并让最终的 `output/3516cv610/host` 保持 self-contained，不再运行时依赖 `/opt/linux/x86-arm/arm-v01c02-linux-musleabi-gcc`。
- **ax615** - AXERA AX615 (Dual ARM Cortex-A7). 使用 `/opt/ax/arm-rel-linux-uclibcgnueabihf` 作为 vendor SDK source，`./build.sh ax615` 会优先复用 `toolchains/` 下已有工具链压缩包；不存在时才按需生成 `toolchains/ax615-sdk-toolchain.tar.xz`，并让最终的 `output/ax615/host` 保持 self-contained，不再运行时依赖 `/opt/ax`。
- **3519dv500** - HiSilicon Hi3519DV500
- **3403** - ARM platform
- **22ap10** - ARM Cortex-A7
- **m64x86** - x86_64

## External Toolchain Packaging

对于 defconfig 中使用 `BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y` 的板卡，`./build.sh <board>` 会优先查找 `toolchains/` 下匹配板卡名、工具链目录名或工具链前缀的压缩包，存在则直接复用；不存在时才按板卡名生成 `toolchains/<board>-sdk-toolchain.tar.xz`。脚本会生成临时 defconfig 切换到 Buildroot 的 external-download 模式。这样最终的 `output/<board>/host` 会包含 `opt/ext-toolchain`，保持 self-contained。默认完整构建完成后还会自动执行 `prepare-sdk`，在 `output/<board>/host/` 下生成 `relocate-sdk.sh` 供搬迁后修正路径。

如果只是仓库内构建使用，可以使用 `toolchains/<board>-sdk-toolchain.tar.xz` 这套本地工作归档命名。如果需要对外发布工具链压缩包，或上传到 GitHub Release 作为 SDK 资产，统一使用以下命名格式，并放在工程根目录 `toolchains/` 下：

```text
toolchain-<chip>-<tc_ver>-gcc<gcc_ver>-linux<headers_ver>-<arch>-<libc>-YYYY.MM.DD.tar.gz
```

命名要求：
- `chip` 放在最前面，优先体现芯片或平台
- `tc_ver` 单独表示工具链版本，不与 GCC 版本混用
- `gcc_ver`、`linux<headers_ver>`、`arch`、`libc` 必须保留，确保兼容信息完整
- 日期固定放在文件名末尾，格式统一为 `YYYY.MM.DD`
- 对外发布的压缩包文件名与 GitHub Release 资产名保持一致

命名示例：
- `toolchain-hi3516cv610-v01c02-gcc10-linux5.10-armv7-musl-2026.04.11.tar.gz`
- `toolchain-hi3519dv500-v01c01-gcc10-linux5.10-aarch64-glibc-2026.04.11.tar.gz`
- `toolchain-gk7206-gcc12.2.0-linux5.10-armv7-uclibc-2026.04.11.tar.gz`
- `toolchain-rk1126b-rockchip1240-gcc12-linux6.1-armv7-glibc-2026.04.11.tar.gz`

如果将 `output/<board>/host/` 拷贝到新路径，先执行 `output/<board>/host/relocate-sdk.sh`。

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
