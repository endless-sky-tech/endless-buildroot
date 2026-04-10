#!/bin/bash

set -e

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <board_name> [additional_make_args...]"
        exit 1
    fi

    board_name=$1
    shift  # 移除第一个参数（board名称）

    config_file="$(pwd)/board/${board_name}/configs/defconfig"

    if [ ! -f "$config_file" ]; then
        echo "Error: Config file not found for board: $board_name"
        echo "Expected config file: $config_file"
        exit 1
    fi

    output_dir=$(pwd)/output/${board_name}

    # 生成默认配置
    make -C buildroot BR2_EXTERNAL=$(pwd)/general O=${output_dir} BR2_DEFCONFIG="$config_file" defconfig

    # 编译
    make -C buildroot O=${output_dir} "$@"
}

main "$@"