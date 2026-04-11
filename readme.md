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

## gk7206
```
busybox配置
./build.sh gk7206 busybox-menuconfig

配置buildroot
./build.sh gk7206 menuconfig

编译
./build.sh gk7206
```
