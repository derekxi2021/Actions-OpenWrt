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
# 彻底根除 v2ray/xray-plugin 编译错误的组合拳（diy-part2 专用版）
# =========================================================


#!/bin/bash

echo "================================================="
echo "开始全自动执行：双插件（v2ray/xray-plugin）深度清洗..."
echo "================================================="

# 1. 【精准斩断】仅剔除 Makefile 里的混淆插件依赖，绝不误伤 Shadowsocks 核心组件
find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/\+v2ray-plugin//g' 2>/dev/null
find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/\+xray-plugin//g' 2>/dev/null

# 2. 【物理蒸发】彻底移除这两个导致报错的 Go 语言源码目录
rm -rf feeds/helloworld/v2ray-plugin/
rm -rf feeds/helloworld/xray-plugin/
rm -rf feeds/small/v2ray-plugin/
rm -rf feeds/small/xray-plugin/
rm -rf feeds/kenzo/v2ray-plugin/
rm -rf feeds/kenzo/xray-plugin/

rm -rf package/feeds/helloworld/v2ray-plugin/
rm -rf package/feeds/helloworld/xray-plugin/
rm -rf package/feeds/small/v2ray-plugin/
rm -rf package/feeds/small/xray-plugin/
rm -rf package/feeds/kenzo/v2ray-plugin/
rm -rf package/feeds/kenzo/xray-plugin/

# 3. 【配置清洗】强行关掉 .config 里的这哥俩，确保编译器不会惯性寻找
if [ -f .config ]; then
    sed -i '/CONFIG_PACKAGE_v2ray-plugin/d' .config
    sed -i '/CONFIG_PACKAGE_luci-app-v2ray-plugin/d' .config
    sed -i '/CONFIG_PACKAGE_xray-plugin/d' .config
    
    echo "CONFIG_PACKAGE_v2ray-plugin=n" >> .config
    echo "CONFIG_PACKAGE_luci-app-v2ray-plugin=n" >> .config
    echo "CONFIG_PACKAGE_xray-plugin=n" >> .config
fi

echo "================================================="
echo "双插件清洗完毕，您可以放心提交云编译了！"
echo "================================================="
