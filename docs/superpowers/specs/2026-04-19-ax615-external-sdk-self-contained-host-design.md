# AX615 External SDK Self-Contained Host Design

## Context

AX615 当前已经接入 Buildroot，并能基于 AX 官方提供的外部工具链
`/opt/ax/arm-rel-linux-uclibcgnueabihf` 成功生成根文件系统。

当前问题不在于目标文件系统，而在于 `output/ax615/host` 仍然依赖宿主机上的
`/opt/ax/arm-rel-linux-uclibcgnueabihf`。Buildroot 为预装外部工具链生成的
wrapper 会固化绝对路径，因此 `host` 目录不能被单独拷走使用。

用户约束如下：

- 必须继续使用 AX SDK 当前提供的外部工具链，不能切换为 Buildroot 内建工具链。
- 不能改变 AX615 当前依赖的 ABI、libc、sysroot 来源。
- 尽量不要改动已有功能面，只解决 `host` 工具链自完备问题。
- 继续保持 `./build.sh ax615` 的使用方式，不要求用户额外执行导出 SDK 步骤。

## Goals

- 保持 AX615 使用 AX SDK 原始工具链和 sysroot 构建。
- 最终生成的 `output/ax615/host` 可以脱离 `/opt/ax/...` 单独使用。
- 不改变 AX615 当前包选择和根文件系统内容。
- 保持 `./build.sh ax615` 为唯一入口。

## Non-Goals

- 不把 AX615 改成 Buildroot 内建工具链。
- 不对其他板子统一改造。
- 不增加额外的独立 SDK 导出脚本。
- 不借机调整包配置或裁剪功能。

## Chosen Approach

采用 Buildroot 支持的“下载型外部工具链”路径，但工具链源头仍然是本机安装的
AX SDK。

具体做法是：

1. `build.sh ax615` 在执行 `defconfig` 前，自动把
   `/opt/ax/arm-rel-linux-uclibcgnueabihf` 打包为本地 tarball。
2. `build.sh` 基于正式的 `board/ax615/configs/defconfig` 生成一个临时 defconfig。
3. 临时 defconfig 仅覆盖外部工具链装载方式，使 Buildroot 以
   `BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y` 的模式使用该 tarball。
4. Buildroot 将工具链解压到 `output/ax615/host/opt/ext-toolchain` 下，生成的
   wrapper 自动改为相对路径。

这样做不会改变编译器、sysroot、libc 及其 ABI，只改变工具链进入 Buildroot
构建树的方式。

## Why This Approach

该方案同时满足两个约束：

- ABI 继续完全跟随 AX SDK，因为实际参与构建的仍然是 AX 提供的编译器目录树。
- `host` 自完备，因为工具链本体被纳入 `HOST_DIR`，wrapper 不再引用 `/opt/ax`。

相比“切换到 Buildroot 内建工具链”，该方案不会引入 ABI 漂移风险。
相比“构建后再手工复制并修补 wrapper”，该方案直接走 Buildroot 原生机制，
可维护性更高，后续复现也更稳定。

## Detailed Design

### 1. Toolchain Packaging in `build.sh`

`build.sh` 增加一段仅对 `ax615` 生效的准备逻辑：

- 检查 `/opt/ax/arm-rel-linux-uclibcgnueabihf` 是否存在。
- 若不存在，直接报错退出，错误信息明确指出缺少 AX SDK 工具链目录。
- 若存在，则生成本地工具链 tarball，建议落到仓库顶层 `dl/` 目录下。

建议产物名：

- `dl/ax615-sdk-toolchain.tar.xz`

tarball 内容保留顶层目录名 `arm-rel-linux-uclibcgnueabihf/`，不重排目录结构。
这样 tarball 是对 SDK 目录的直接归档，最接近用户当前使用的原始布局。

### 2. Temporary Defconfig Generation

`build.sh` 不直接把正式 defconfig 传给 Buildroot，而是：

1. 读取 `board/ax615/configs/defconfig`
2. 在 `output/ax615/` 下生成一个临时 defconfig
3. 在临时 defconfig 中仅覆盖以下工具链相关项

覆盖项如下：

- 打开 `BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y`
- 关闭 `BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED`
- 删除或清空 `BR2_TOOLCHAIN_EXTERNAL_PATH`
- 设置 `BR2_TOOLCHAIN_EXTERNAL_URL="file://<repo>/dl/ax615-sdk-toolchain.tar.xz"`
- 设置 `BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="arm-rel-linux-uclibcgnueabihf/bin"`

同时保留：

- `BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y`
- `BR2_TOOLCHAIN_EXTERNAL_PREFIX="arm-rel-linux-uclibcgnueabihf"`
- uClibc、headers、浮点 ABI、GCC 版本等现有探针配置

临时 defconfig 必须继续写回：

- `BR2_DEFCONFIG="<repo>/board/ax615/configs/defconfig"`

这样最终生成的 `.config` 仍然指向正式板级 defconfig，而不是临时文件路径。

### 3. Scope Boundary

本次改动仅影响 `ax615`：

- 不修改 3516cv610、3519dv500、22ap10 等其他板子的工具链装载方式。
- 不调整 `general/` 下包逻辑。
- 不改变 AX615 BusyBox 和包选择。

### 4. Tarball Refresh Policy

为避免每次构建都重复打包大目录，同时避免 SDK 更新后 tarball 过期，`build.sh`
应采用“按需刷新”策略：

- tarball 不存在时创建。
- 若 `/opt/ax/arm-rel-linux-uclibcgnueabihf` 下存在比 tarball 更新的文件，则重建。
- 否则复用已有 tarball。

这保证常规增量构建不会反复压缩工具链，同时 SDK 更新后仍可自动生效。

### 5. Error Handling

新增错误场景及处理方式：

- SDK 目录不存在：立即失败，提示需要安装或挂载 AX SDK 到 `/opt/ax/...`
- tarball 生成失败：立即失败，提示本地归档失败
- Buildroot defconfig 失败：沿用现有 `set -e` 直接退出

不引入静默降级。若缺少 SDK，则不尝试回退到 `/opt/ax` 预装模式，因为那会让
“host 自完备”的目标失效。

## Verification Plan

实现后以以下标准验收：

1. `./build.sh ax615` 返回成功。
2. `output/ax615/images/rootfs.tar.gz` 正常生成。
3. `output/ax615/host/bin/arm-rel-linux-uclibcgnueabihf-gcc -print-sysroot`
   指向 `output/ax615/host` 内部路径。
4. `strings output/ax615/host/bin/toolchain-wrapper | grep /opt/ax`
   不再命中。
5. 目标根文件系统仍可生成，说明包集没有因工具链装载方式切换被额外裁掉。

## Risks and Mitigations

### Risk: AX SDK Toolchain Is Not Relocatable

缓解方式：

- 已做最小验证：将整个 SDK 目录复制到 `/tmp` 后，`gcc -print-sysroot` 指向新路径，
  且最小 C 程序可成功编译。
- 因此该风险当前可接受，不需要额外的 wrapper hack。

### Risk: Temporary Defconfig Pollutes Saved Config Paths

缓解方式：

- 在临时 defconfig 中显式保留正式 `BR2_DEFCONFIG` 路径。
- 仅在初始 `defconfig` 阶段使用临时文件，后续 `make` 不再传该路径。

### Risk: Tarball Layout Does Not Match Buildroot Expectation

缓解方式：

- 明确设置 `BR2_TOOLCHAIN_EXTERNAL_REL_BIN_PATH="arm-rel-linux-uclibcgnueabihf/bin"`。
- 不依赖默认 `bin` 路径推断。

## Testing Notes

本设计不要求新增单元测试。验证以构建成功和生成物检查为主。

若后续需要回归脚本化，可补充一个简单检查：

- 检查 `toolchain-wrapper` 中是否仍含 `/opt/ax`
- 检查 `-print-sysroot` 是否位于 `output/ax615/host`

## Expected Outcome

完成后，AX615 将继续基于 AX SDK 编译，但最终产出的
`output/ax615/host` 将成为一套可直接拷贝使用的自完备交叉编译环境，
不再要求目标机器额外具备 `/opt/ax/arm-rel-linux-uclibcgnueabihf`。
