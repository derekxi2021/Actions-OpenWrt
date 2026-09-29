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

# luci feed 排序靠前且自带旧 passwall2（25.8.22），删掉防遮挡
rm -rf feeds/luci/applications/luci-app-passwall2 feeds/luci/applications/luci-app-passwall
rm -rf package/feeds/luci/luci-app-passwall2 package/feeds/luci/luci-app-passwall

# helloworld feed（kenzok8/small）同理
rm -rf feeds/helloworld/luci-app-passwall2 feeds/helloworld/luci-app-passwall
rm -rf package/feeds/helloworld/luci-app-passwall2 package/feeds/helloworld/luci-app-passwall

# Pin passwall feeds（与 AN7581 对齐：passwall2 ab1e812 / passwall_packages c6d4772）
# feeds 脚本不支持 commit pin，只能 update 后 checkout；升级时两边一起改
echo ">>> Pinning passwall2 feed..."
git -C feeds/passwall2 checkout -q ab1e812ec57ac7be0e213532f60ef4c46e76d962 || { echo ">>> [ERROR] passwall2 pin failed!"; exit 1;}
git -C feeds/passwall_packages checkout -q c6d4772cea9bec6adc66261be2c3e6679a595250 || { echo ">>> [ERROR] passwall_packages pin failed!"; exit 1;}

# === 2026-09-27: passwall2 DNS 黑洞修复（x64 26.9.16 实测）===
# 1. 删 packages feed 的旧 xray-core（26.6.1），让 passwall_packages 的新版透出来（xray-core 26.9.9）
#    （v2ray-geodata 的清理见下方 2026-09-29 段落，改成全 feed 通杀）
echo ">>> Removing shadowed xray-core from packages feed..."
rm -rf feeds/packages/net/xray-core
rm -rf package/feeds/packages/xray-core


# 2. dns-in: tunnel -> dokodemo-door（26.9.16 源码 bug，无 UCI 项，只能改源码）
UTIL_XRAY=$(find feeds/passwall2 -name "util_xray.lua" 2>/dev/null | head -1)
[ -z "$UTIL_XRAY" ] && { echo ">>> [ERROR] util_xray.lua not found!"; exit 1;}
DNSIN_LINE=$(grep -n 'tag = "dns-in"' "$UTIL_XRAY" | head -1 | cut -d: -f1)
[ -z "$DNSIN_LINE" ] && { echo ">>> [ERROR] dns-in tag not found!"; exit 1;}
sed -i "$((DNSIN_LINE-5)),${DNSIN_LINE}s/protocol = \"tunnel\"/protocol = \"dokodemo-door\"/" "$UTIL_XRAY"
echo ">>> Verify dns-in protocol:"
grep -B5 'tag = "dns-in"' "$UTIL_XRAY" | grep -q 'protocol = "dokodemo-door"' \
|| { echo ">>> [ERROR] dns-in protocol patch failed!"; exit 1;}
grep -B3 'tag = "dns-in"' "$UTIL_XRAY" | grep protocol


./scripts/feeds install -f -a -p passwall2
./scripts/feeds install -f -a -p passwall_packages
echo ">>> Passwall feeds pinned."

# === 2026-09-29: v2ray-geodata 遮挡根治 ===
# 不止 packages feed 有旧版——helloworld（kenzok8/small）等 feed 也有 v2ray-geodata
# （helloworld 的是 2026-09-05 版），构建时多个副本只会用一个，不删干净就继续用旧的。
# 这里把所有 feed 的 v2ray-geodata 全删掉，只留 passwall_packages 的新版（geo 2026-09-24）。
# feeds/ 是源，package/feeds/ 是 install 后的副本，两处都要清。
# 注意：feeds 索引是 update 阶段生成的、删文件清不掉它，所以这段必须放在 install -f 之后。
echo ">>> Removing shadowing v2ray-geodata from all feeds except passwall_packages..."
find feeds package/feeds -type d -name "v2ray-geodata" 2>/dev/null | grep -v "passwall_packages" | while read -r d; do
  echo ">>> Removing $d"
  rm -rf "$d"
done
# 验证：只剩 passwall_packages 的那一个
[ -d "package/feeds/passwall_packages/v2ray-geodata" ] \
  || { echo ">>> [ERROR] passwall_packages v2ray-geodata missing!"; exit 1; }
REMAINING_COUNT=$(find package/feeds -type d -name "v2ray-geodata" 2>/dev/null | wc -l)
if [ "$REMAINING_COUNT" -ne 1 ]; then
  echo ">>> [ERROR] Expected exactly 1 v2ray-geodata, found $REMAINING_COUNT:"
  find package/feeds -type d -name "v2ray-geodata" 2>/dev/null
  exit 1
fi
# xray-core 收尾
rm -rf package/feeds/packages/xray-core
[ -d "package/feeds/passwall_packages/xray-core" ] \
  || { echo ">>> [ERROR] passwall_packages xray-core missing!"; exit 1; }
echo ">>> v2ray-geodata/xray-core: only passwall_packages version remains."

# ccache 目录放这里，不进.config（/workdir 是 runner 相关路径）
sed -i '/CONFIG_CCACHE_DIR/d' .config
echo 'CONFIG_CCACHE_DIR="/workdir/.ccache"' >> .config

# set golang 1.26.x （rc/beta）
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/kenzok8/golang -b 1.26 feeds/packages/lang/golang

# set golang 1.25.x
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/kenzok8/golang -b 1.25 feeds/packages/lang/golang

# set golang 1.24.x (main)
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/kenzok8/golang feeds/packages/lang/golang

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
#git clone https://github.com/ximiTech/msd_lite.git package/msd_lite/msd_lite
#git clone https://github.com/ximiTech/luci-app-msd_lite.git package/msd_lite/luci-app-msd_lite

# Naiveproxy 缺少x86编译失败版本回退
#sed -i 's/143.0.7499.109-2/140.0.7339.123-3/g' feeds/helloworld/naiveproxy/Makefile

# =========================================================
# 彻底根除 v2ray/xray-plugin 编译错误的组合拳（diy-part2 专用版）
# =========================================================


#!/bin/bash

#echo "================================================="
#echo "开始全自动执行：双插件（v2ray/xray-plugin）深度清洗..."
#echo "================================================="

# 1. 仅剔除 Makefile 里的混淆插件依赖，绝不误伤 Shadowsocks 核心组件
#find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/\+v2ray-plugin//g' 2>/dev/null
#find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/\+xray-plugin//g' 2>/dev/null

# 2. 彻底移除这两个导致报错的 Go 语言源码目录
#rm -rf feeds/helloworld/v2ray-plugin/
#rm -rf feeds/helloworld/xray-plugin/
#rm -rf feeds/small/v2ray-plugin/
#rm -rf feeds/small/xray-plugin/
#rm -rf feeds/kenzo/v2ray-plugin/
#rm -rf feeds/kenzo/xray-plugin/

#rm -rf package/feeds/helloworld/v2ray-plugin/
#rm -rf package/feeds/helloworld/xray-plugin/
#rm -rf package/feeds/small/v2ray-plugin/
#rm -rf package/feeds/small/xray-plugin/
#rm -rf package/feeds/kenzo/v2ray-plugin/
#rm -rf package/feeds/kenzo/xray-plugin/

# 3. 强行关掉.config 里的这哥俩，确保编译器不会惯性寻找
#if [ -f .config ]; then
#    sed -i '/CONFIG_PACKAGE_v2ray-plugin/d' .config
#    sed -i '/CONFIG_PACKAGE_luci-app-v2ray-plugin/d' .config
#    sed -i '/CONFIG_PACKAGE_xray-plugin/d' .config
#
#    echo "CONFIG_PACKAGE_v2ray-plugin=n" >> .config
#    echo "CONFIG_PACKAGE_luci-app-v2ray-plugin=n" >> .config
#    echo "CONFIG_PACKAGE_xray-plugin=n" >> .config
#fi

# =========================================================
# 解决 Kconfig 循环依赖报错 (fchomo / mihomo / nikki)
# =========================================================
echo ">>> 清理存在循环依赖冲突的软件包..."
rm -rf feeds/luci/applications/luci-app-fchomo
rm -rf feeds/packages/net/mihomo
rm -rf feeds/packages/net/nikki
rm -rf package/feeds/luci/luci-app-fchomo
rm -rf package/feeds/packages/mihomo
rm -rf package/feeds/packages/nikki
#.config 里残留的选中项也要清掉，否则 defconfig 报错
sed -i '/CONFIG_PACKAGE_luci-app-fchomo/d' .config
sed -i '/CONFIG_PACKAGE_mihomo/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-nikki/d' .config
sed -i '/CONFIG_PACKAGE_nikki/d' .config

# 修复 gettext-full 0.24.2 的 BISON_LOCALEDIR 缺失 Bug
GETTEXT_MAKEFILE="package/libs/gettext-full/Makefile"
if [ -f "$GETTEXT_MAKEFILE" ]; then
echo 'HOST_CFLAGS += -DBISON_LOCALEDIR=\"/usr/share/locale\"' >> $GETTEXT_MAKEFILE
echo 'HOST_CPPFLAGS += -DBISON_LOCALEDIR=\"/usr/share/locale\"' >> $GETTEXT_MAKEFILE
fi

# 清理旧的编译标记
rm -rf staging_dir/hostpkg/bin/msgfmt*
rm -rf staging_dir/hostpkg/share/gettext*
rm -rf build_dir/hostpkg/gettext-*

#echo "================================================="
#echo "双插件清洗完毕，您可以放心提交云编译了！"
#echo "================================================="
