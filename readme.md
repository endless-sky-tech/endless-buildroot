# buildroot

# 编译

## aarch64
```
./build.sh aarch64
内核配置
./build.sh aarch64 linux-menuconfig

./build.sh aarch64 linux-savedefconfig

busybox配置
./build.sh aarch64 busybox-menuconfig
```

## 3516cv610
```
外部工具链
/opt/linux/x86-arm/arm-v01c02-linux-musleabi-gcc
`./build.sh 3516cv610` 会优先使用 `toolchains/` 下已有工具链压缩包；不存在时才按需生成 `toolchains/3516cv610-sdk-toolchain.tar.xz`，并切换到 Buildroot 的外部下载工具链模式。
最终生成的 `output/3516cv610/host` 是 self-contained 的，可单独移动和使用，不再运行时依赖 `/opt/linux/x86-arm/arm-v01c02-linux-musleabi-gcc`。

busybox配置
./build.sh 3516cv610 busybox-menuconfig

配置buildroot
./build.sh 3516cv610 menuconfig

编译
./build.sh 3516cv610
```

## ax615
```
外部工具链
/opt/ax/arm-rel-linux-uclibcgnueabihf
./build.sh ax615 会优先使用 `toolchains/` 下已有工具链压缩包；不存在时才按需生成 `toolchains/ax615-sdk-toolchain.tar.xz`，并切换到 Buildroot 的外部下载工具链模式。
最终生成的 `output/ax615/host` 是 self-contained 的，可单独移动和使用，不再运行时依赖 `/opt/ax`。

busybox配置
./build.sh ax615 busybox-menuconfig

配置buildroot
./build.sh ax615 menuconfig

编译
./build.sh ax615
```

## 外部工具链打包说明
```
对于 defconfig 中使用 `BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y` 的板卡，`./build.sh <board>` 会统一执行以下流程：
1. 从 defconfig 读取外部工具链路径和前缀；
2. 优先查找 `toolchains/` 下匹配板卡名、工具链目录名或工具链前缀的压缩包，存在则直接复用；
3. 如果没有已有压缩包，按板卡名按需生成到 `toolchains/<board>-sdk-toolchain.tar.xz`；
4. 生成临时 defconfig，切换到 Buildroot 的外部下载工具链模式；
5. 让最终的 `output/<board>/host` 内含 `opt/ext-toolchain`，保持 self-contained。
6. 默认执行 `./build.sh <board>` 完整构建后，还会自动执行 `prepare-sdk`，在 `output/<board>/host/` 生成 `relocate-sdk.sh`，便于整体拷走后再做路径修正。
```

如果只是仓库内构建使用，可以继续使用 `toolchains/<board>-sdk-toolchain.tar.xz` 这套本地工作归档命名。这个归档只供 Buildroot external-download 流程复用，不作为对外发布资产。

如果需要对外发布工具链压缩包，或上传到 GitHub Release 作为 SDK 资产，发布包必须从 `output/<board>/host/` 打包，而不是直接发布 `toolchains/<board>-sdk-toolchain.tar.xz`。`host/` 是完整的、包含 sysroot 的可搬迁工具链目录，里面包含 Buildroot host 工具、`opt/ext-toolchain`、目标 sysroot 和 `relocate-sdk.sh`。压缩包内顶层目录不要叫 `host`，必须使用发布文件名去掉 `.tar.gz` 后的目录名。对外发布文件统一放在 `dist/toolchains/` 下，文件名使用：

```text
toolchain-<chip>-<tc_ver>-gcc<gcc_ver>-linux<headers_ver>-<arch>-<libc>-YYYY.MM.DD.tar.gz
```

命名示例：
- `toolchain-hi3516cv610-v01c02-gcc10-linux5.10-armv7-musl-2026.04.11.tar.gz`
- `toolchain-hi3519dv500-v01c01-gcc10-linux5.10-aarch64-glibc-2026.04.11.tar.gz`
- `toolchain-ax615-buildroot-sdk-rel-gcc8.3.0-linux4.19.125-armv7-uclibc-2026.04.25.tar.gz`
- `toolchain-gk7206-gcc12.2.0-linux5.10-armv7-uclibc-2026.04.11.tar.gz`
- `toolchain-rk1126b-rockchip1240-gcc12-linux6.1-armv7-glibc-2026.04.11.tar.gz`

## rk1126b
```
外部工具链
/opt/rockchip/arm-rockchip1240-linux-gnueabihf

busybox配置
./build.sh rk1126b busybox-menuconfig

配置buildroot
./build.sh rk1126b menuconfig

编译
./build.sh rk1126b
```

## gk7206
```
busybox配置
./build.sh gk7206 busybox-menuconfig

配置buildroot
./build.sh gk7206 menuconfig

编译
./build.sh gk7206
```

## 22ap10
```
busybox配置
./build.sh 22ap10 busybox-menuconfig

配置buildroot
./build.sh 22ap10 menuconfig

编译
./build.sh 22ap10
```

## m64x86
```
./build.sh m64x86
```
