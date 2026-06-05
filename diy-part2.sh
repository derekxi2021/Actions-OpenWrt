#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# Modify Kernel version
#sed -i 's/CONFIG_LINUX.*/CONFIG_LINUX_6_1=y/g' .config
#sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.1/g' target/linux/x86/Makefile
#sed -i 's/KERNEL_TESTING_PATCHVER:=*.*/KERNEL_TESTING_PATCHVER:=6.1/g' target/linux/x86/Makefile

# set golang 1.26.x （rc/beta）
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/kenzok8/golang -b 1.26 feeds/packages/lang/golang

# set golang 1.25.x
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/kenzok8/golang -b 1.25 feeds/packages/lang/golang

# set golang 1.24.x (main)
rm -rf feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang feeds/packages/lang/golang

# set golang 1.23.x
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/kenzok8/golang -b 1.23 feeds/packages/lang/golang

# fixed rust host build download llvm in ci error
#sed -i 's/--set=llvm\.download-ci-llvm=false/--set=llvm.download-ci-llvm=true/' feeds/packages/lang/rust/Makefile
#grep -q -- '--ci false \\' feeds/packages/lang/rust/Makefile || sed -i '/x\.py \\/a \        --ci false \\' feeds/packages/lang/rust/Makefile

# Remove dns2socks-rust & v2raya
#rm -rfv feeds/helloworld/dns2socks-rust
#rm -rfv feeds/helloworld/v2raya

# msd_lite
#git clone --depth=1 https://github.com/ximiTech/luci-app-msd_lite package/luci-app-msd_lite
#git clone --depth=1 https://github.com/ximiTech/msd_lite package/msd_lite
#git clone  https://github.com/ximiTech/msd_lite.git package/msd_lite/msd_lite
#git clone https://github.com/ximiTech/luci-app-msd_lite.git package/msd_lite/luci-app-msd_lite

# Naiveproxy 缺少x86编译失败版本回退
#sed -i 's/143.0.7499.109-2/140.0.7339.123-3/g' feeds/helloworld/naiveproxy/Makefile

# =========================================================
# 彻底根除 v2ray-plugin 编译错误的组合拳（diy-part2 专用版）
# =========================================================

echo "开始强力清洗 v2ray-plugin 依赖..."

# 1. 强行修改所有 feeds 和 package 目录下的 Makefile，解除强制依赖锁定
find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/+v2ray-plugin//g' 2>/dev/null
find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/v2ray-plugin//g' 2>/dev/null

# 2. 物理抹除所有可能存在 v2ray-plugin 的源码文件夹
rm -rf feeds/helloworld/v2ray-plugin/
rm -rf feeds/small/v2ray-plugin/
rm -rf feeds/kenzo/v2ray-plugin/
rm -rf package/feeds/helloworld/v2ray-plugin/
rm -rf package/feeds/small/v2ray-plugin/
rm -rf package/feeds/kenzo/v2ray-plugin/

# 3. 强行清洗你的 .config 文件，把隐性勾选全部擦除并显式声明关闭
if [ -f .config ]; then
    sed -i '/CONFIG_PACKAGE_v2ray-plugin/d' .config
    sed -i '/CONFIG_PACKAGE_luci-app-v2ray-plugin/d' .config
    echo "CONFIG_PACKAGE_v2ray-plugin=n" >> .config
    echo "CONFIG_PACKAGE_luci-app-v2ray-plugin=n" >> .config
fi

echo "v2ray-plugin 依赖清洗完毕！"
