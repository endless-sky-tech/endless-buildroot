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
./build.sh ax615 会自动把该 SDK 重新打包为 `dl/ax615-sdk-toolchain.tar.xz`，并切换到 Buildroot 的外部下载工具链模式。
最终生成的 `output/ax615/host` 是 self-contained 的，可单独移动和使用，不再运行时依赖 `/opt/ax`。

busybox配置
./build.sh ax615 busybox-menuconfig

配置buildroot
./build.sh ax615 menuconfig

编译
./build.sh ax615
```

## rk1126b
```
外部工具链
/opt/aarch64-rockchip1240-linux-gnu

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
