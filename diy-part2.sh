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

# luci feed (coolsnowwolf/luci) also ships luci-app-passwall2 25.8.22
# and is listed before helloworld/passwall2 in feeds.conf.default
rm -rf feeds/luci/applications/luci-app-passwall2 feeds/luci/applications/luci-app-passwall
rm -rf package/feeds/luci/luci-app-passwall2 package/feeds/luci/luci-app-passwall

# Remove passwall2 shadowed by helloworld feed (kenzok8/small ships an old
# luci-app-passwall2 25.8.22 and is listed before the passwall2 feed in
# feeds.conf.default, so `feeds install -a` picks the old one. Delete it so
# the passwall2 feed's pinned version wins.
rm -rf feeds/helloworld/luci-app-passwall2 feeds/helloworld/luci-app-passwall
rm -rf package/feeds/helloworld/luci-app-passwall2 package/feeds/helloworld/luci-app-passwall

# Pin passwall feeds to commits matching AN7581 build (2026-09-25),
# so passwall2 config format stays compatible between x64 and AN7581.
# NOTE: feeds.conf.default cannot pin a commit hash directly (the feeds
# script treats ";rev" as a branch name), so checkout after feeds update.
# `scripts/feeds install -a` already ran before this script, so re-install
# these two feeds to pick up the pinned versions (otherwise the old installed
# copies under package/feeds/ would still be used).
# To upgrade passwall2 later, update both hashes here AND the matching
# pins in the ponwrt repo together, then rebuild both.
echo ">>> Pinning passwall2 feed..."
git -C feeds/passwall2 checkout -q ab1e812ec57ac7be0e213532f60ef4c46e76d962 || { echo ">>> [ERROR] passwall2 pin failed!"; exit 1; }
git -C feeds/passwall_packages checkout -q c6d4772cea9bec6adc66261be2c3e6679a595250 || { echo ">>> [ERROR] passwall_packages pin failed!"; exit 1; }

# === 2026-09-27: passwall2 DNS 黑洞修复（x64 26.9.16 实测）===
# 1. 删 packages feed 的 xray-core 26.6.1，避免遮挡 passwall_packages 的 26.9.9
echo ">>> Removing shadowed xray-core from packages feed..."
rm -rf feeds/packages/net/xray-core

# 2. dns-in: tunnel -> dokodemo-door
#    26.9.16 源码 bug：tunnel 不懂 DNS 协议，查询包黑洞；
#    dokodemo-door 是 xray 专用 DNS 入口。协议写死在源码，无 UCI 配置项，只能改源码。
UTIL_XRAY=$(find feeds/passwall2 -name "util_xray.lua" 2>/dev/null | head -1)
[ -z "$UTIL_XRAY" ] && { echo ">>> [ERROR] util_xray.lua not found!"; exit 1; }
DNSIN_LINE=$(grep -n 'tag = "dns-in"' "$UTIL_XRAY" | head -1 | cut -d: -f1)
[ -z "$DNSIN_LINE" ] && { echo ">>> [ERROR] dns-in tag not found!"; exit 1; }
sed -i "$((DNSIN_LINE-5)),${DNSIN_LINE}s/protocol = \"tunnel\"/protocol = \"dokodemo-door\"/" "$UTIL_XRAY"
echo ">>> Verify dns-in protocol:"
grep -B3 'tag = "dns-in"' "$UTIL_XRAY" | grep protocol


./scripts/feeds install -f -a -p passwall2
./scripts/feeds install -f -a -p passwall_packages
echo ">>> Passwall feeds pinned."

# Fix ccache dir: OpenWrt exports CCACHE_DIR=$(CONFIG_CCACHE_DIR) during build,
# and an empty CONFIG_CCACHE_DIR overrides the workflow's CCACHE_DIR env var,
# causing ccache to write to ~/.ccache (which actions/cache does not persist).
# Point it at the workflow's cache path (/workdir/.ccache) instead.
# Kept here (not in x64-LEDE.config) because /workdir is runner-specific.
sed -i '/CONFIG_CCACHE_DIR/d' .config
echo 'CONFIG_CCACHE_DIR="/workdir/.ccache"' >> .config

# set golang 1.26.x （rc/beta）
rm -rf feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang -b 1.26 feeds/packages/lang/golang

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
#git clone  https://github.com/ximiTech/msd_lite.git package/msd_lite/msd_lite
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

# 1. 【精准斩断】仅剔除 Makefile 里的混淆插件依赖，绝不误伤 Shadowsocks 核心组件
#find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/\+v2ray-plugin//g' 2>/dev/null
#find feeds/ package/ -type f -name "Makefile" | xargs sed -i 's/\+xray-plugin//g' 2>/dev/null

# 2. 【物理蒸发】彻底移除这两个导致报错的 Go 语言源码目录
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

# 3. 【配置清洗】强行关掉 .config 里的这哥俩，确保编译器不会惯性寻找
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

# =========================================================
# 云编译专用：拉取 Loyalsoldier 规则并进行多路径强制注入与拦截保护
# =========================================================
echo ">>> 开始处理 geosite / geoip 规则数据库..."

TMP_GEO_DIR="/tmp/geo_rules_tmp"
rm -rf "$TMP_GEO_DIR"
mkdir -p "$TMP_GEO_DIR"

# 尝试拉取 Loyalsoldier 最新规则
echo ">>> 尝试下载 Loyalsoldier 最新规则..."
curl -sSL --connect-timeout 15 -m 30 -o "$TMP_GEO_DIR/geoip.dat" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
curl -sSL --connect-timeout 15 -m 30 -o "$TMP_GEO_DIR/geosite.dat" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

GEOIP_SIZE=$(stat -c%s "$TMP_GEO_DIR/geoip.dat" 2>/dev/null || echo 0)
GEOSITE_SIZE=$(stat -c%s "$TMP_GEO_DIR/geosite.dat" 2>/dev/null || echo 0)

if [ "$GEOIP_SIZE" -gt 1048576 ] && [ "$GEOSITE_SIZE" -gt 1048576 ]; then
    echo ">>> Loyalsoldier 最新规则拉取成功！开始全路径注入..."
    
    # 注入 /usr/share/v2ray 路径
    mkdir -p files/usr/share/v2ray
    cp -f "$TMP_GEO_DIR/geoip.dat" files/usr/share/v2ray/
    cp -f "$TMP_GEO_DIR/geosite.dat" files/usr/share/v2ray/

    # 注入 /usr/share/geodata 路径（兼容 PassWall / Mihomo 等新版插件）
    #mkdir -p files/usr/share/geodata
    #cp -f "$TMP_GEO_DIR/geoip.dat" files/usr/share/geodata/
    #cp -f "$TMP_GEO_DIR/geosite.dat" files/usr/share/geodata/

    # 关键步骤：拦截 Makefile 中可能重新覆盖 dat 文件的解压/安装指令
    find feeds/ package/ -type f -name "Makefile" -exec grep -l "geodata" {} + 2>/dev/null | while read -r file; do
        sed -i 's/$(INSTALL_DATA) .*geoip.dat/echo "Skip geoip.dat"/g' "$file" 2>/dev/null || true
        sed -i 's/$(INSTALL_DATA) .*geosite.dat/echo "Skip geosite.dat"/g' "$file" 2>/dev/null || true
    done
    
    echo ">>> 规则替换与 Makefile 防覆盖处理完毕！"
else
    echo ">>> [警告] 最新规则拉取失败或超时，保留源码自带规则！"
fi

rm -rf "$TMP_GEO_DIR"

# 修复 gettext-full 0.24.2 的 BISON_LOCALEDIR 缺失 Bug
GETTEXT_MAKEFILE="package/libs/gettext-full/Makefile"
if [ -f "$GETTEXT_MAKEFILE" ]; then
    # 强制在 Makefile 末尾追加全局 HOST 编译宏，防止被覆盖
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
