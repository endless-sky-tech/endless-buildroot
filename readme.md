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
`./build.sh 3516cv610` 会按需把该工具链重新打包为 `dl/3516cv610-sdk-toolchain.tar.xz`，已存在有效归档时会复用，并切换到 Buildroot 的外部下载工具链模式。
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
./build.sh ax615 会按需把该 SDK 重新打包为 `dl/ax615-sdk-toolchain.tar.xz`，已存在有效归档时会复用，并切换到 Buildroot 的外部下载工具链模式。
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
2. 按板卡名按需重打包到 `dl/<board>-sdk-toolchain.tar.xz`；
3. 生成临时 defconfig，切换到 Buildroot 的外部下载工具链模式；
4. 让最终的 `output/<board>/host` 内含 `opt/ext-toolchain`，保持 self-contained。
5. 默认执行 `./build.sh <board>` 完整构建后，还会自动执行 `prepare-sdk`，在 `output/<board>/host/` 生成 `relocate-sdk.sh`，便于整体拷走后再做路径修正。
```

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
