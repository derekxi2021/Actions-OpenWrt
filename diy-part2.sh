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

# 2026-09-30: 去掉 passwall feed pin，直接用上游最新版
# （pin 维护成本高，上游经常 force-push 导致 build 挂）
echo ">>> Using latest passwall feeds (no pin)..."

# === 2026-09-27: passwall2 DNS 黑洞修复（x64 26.9.16 实测）===
# 1. 删 packages feed 的旧 xray-core（26.6.1），让 passwall_packages 的新版透出来（xray-core 26.9.9）
echo ">>> Removing shadowed xray-core from packages feed..."
rm -rf feeds/packages/net/xray-core
rm -rf package/feeds/packages/xray-core

# === 2026-09-29: v2ray-geodata 遮挡根治 ===
# 不止 packages feed 有旧版——helloworld（kenzok8/small）等 feed 也有 v2ray-geodata
# （helloworld 的是 2026-09-05 版），构建时多个副本只会用一个，不删干净就继续用旧的。
# 这里把所有 feed 的 v2ray-geodata 全删掉，只留 passwall_packages 的新版（geo 2026-09-24）。
# feeds/ 是源，package/feeds/ 是 install 后的副本，两处都要清。
# 注意：必须在下面的 feeds install 之前删！yml 里 "Install feeds" 步骤已经跑过
# ./scripts/feeds install -a，v2ray-geodata 此时是从 packages feed（排前面）装的；
# 如果 package/feeds 里还留着旧版，install -f -a -p passwall_packages 会认为是"已安装"
# 而跳过，passwall_packages 版就永远装不上。
echo ">>> Removing shadowing v2ray-geodata from all feeds except passwall_packages..."
# 注意：package/feeds/ 下的是 symlink（feeds install 创建的），find 不能加 -type d，
# 否则匹配不到 symlink，删不干净，断言也会误报 found 0。
find feeds package/feeds -name "v2ray-geodata" 2>/dev/null | grep -v "passwall_packages" | while read -r d; do
  echo ">>> Removing $d"
  rm -rf "$d"
done


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

# POST-INSTALL 清理：feeds install 装依赖时会查陈旧索引（feeds update 在删目录之前跑的），
# 把已删的 packages 版 v2ray-geodata 又装回来。这里在索引用完之后再清一次，它不会复活。
echo ">>> Removing post-install v2ray-geodata stragglers..."
find package/feeds -name "v2ray-geodata" 2>/dev/null | grep -v "passwall_packages" | while read -r d; do
  echo ">>> Removing straggler $d"
  rm -rf "$d"
done
# 同理，xray-core 也可能被复活
rm -rf package/feeds/packages/xray-core

# 确保 passwall_packages 的在位（万一 install 跳过，手动建 symlink 兜底）
if [ ! -e "package/feeds/passwall_packages/v2ray-geodata" ]; then
  echo ">>> Manually linking v2ray-geodata from passwall_packages..."
  mkdir -p package/feeds/passwall_packages
  ln -s "../../../feeds/passwall_packages/v2ray-geodata" package/feeds/passwall_packages/v2ray-geodata
fi

# 验证：v2ray-geodata 只剩 passwall_packages 的那一个
# 注意：package/feeds/ 下的是 symlink，find 不能加 -type d
[ -d "package/feeds/passwall_packages/v2ray-geodata" ] \
  || { echo ">>> [ERROR] passwall_packages v2ray-geodata missing!"; exit 1; }
REMAINING_COUNT=$(find package/feeds -name "v2ray-geodata" 2>/dev/null | wc -l)
if [ "$REMAINING_COUNT" -ne 1 ]; then
  echo ">>> [ERROR] Expected exactly 1 v2ray-geodata, found $REMAINING_COUNT:"
  find package/feeds -name "v2ray-geodata" 2>/dev/null
  exit 1
fi
# xray-core 收尾
[ -d "package/feeds/passwall_packages/xray-core" ] \
  || { echo ">>> [ERROR] passwall_packages xray-core missing!"; exit 1; }
echo ">>> v2ray-geodata/xray-core: only passwall_packages version remains."

# ccache 目录放这里，不进.config（/workdir 是 runner 相关路径）
sed -i '/CONFIG_CCACHE_DIR/d' .config
echo 'CONFIG_CCACHE_DIR="/workdir/.ccache"' >> .config

# === 2026-09-30: 移除 LEDE 首次启动强制设 root 密码 ===
# 背景：coolsnowwolf/lede 的 zzz-default-settings 会在首次启动时把空密码的 root
# 设成 "password"。sysupgrade 保留配置时，若 /etc/shadow 恢复失败（空），密码会
# 被悄悄改成 password（2026-09-29 实测）。删掉这行逻辑后：
#   - 全新刷机 → 空密码（标准 OpenWrt 行为）
#   - sysupgrade 保留配置 → 旧密码保留，不会被覆盖
# 健壮性设计（防上游变更）：
#   - 按目标文件 /etc/shadow 匹配，不按具体 hash/salt，上游换 hash 照样命中
#   - 先检查文件存在、再计数、删完验证，三段式不静默失败
#   - 上游若自行删掉该逻辑 → 计数为 0，日志明示，不报错不中断构建
DEFAULT_SETTINGS="package/lean/default-settings/files/zzz-default-settings"
echo ">>> Checking LEDE default password logic..."
if [ ! -f "$DEFAULT_SETTINGS" ]; then
  echo ">>> [WARN] $DEFAULT_SETTINGS not found, skipping password fix (upstream may have restructured)"
else
  SHADOW_LINES_BEFORE=$(grep -c "/etc/shadow" "$DEFAULT_SETTINGS" 2>/dev/null || true)
  SHADOW_LINES_BEFORE=${SHADOW_LINES_BEFORE:-0}
  if [ "$SHADOW_LINES_BEFORE" -eq 0 ]; then
    echo ">>> No /etc/shadow logic in zzz-default-settings (upstream already removed?), nothing to do"
  else
    echo ">>> Found $SHADOW_LINES_BEFORE line(s) touching /etc/shadow, removing..."
    grep "/etc/shadow" "$DEFAULT_SETTINGS" | sed 's/^/>>>   was: /'
    sed -i '\|/etc/shadow|d' "$DEFAULT_SETTINGS"
    SHADOW_LINES_AFTER=$(grep -c "/etc/shadow" "$DEFAULT_SETTINGS" 2>/dev/null || true)
    SHADOW_LINES_AFTER=${SHADOW_LINES_AFTER:-0}
    if [ "$SHADOW_LINES_AFTER" -ne 0 ]; then
      echo ">>> [ERROR] Failed to remove all /etc/shadow lines from zzz-default-settings!"
      exit 1
    fi
    echo ">>> LEDE default password logic removed ($SHADOW_LINES_BEFORE line(s))"
  fi
fi

# === 2026-09-30: 调试 sysupgrade shadow 恢复失败 ===
# 现象：备份包里有 shadow（hash 正确），但 preinit 恢复后密码为空，其他配置正常。
# 在 80_mount_root 的 tar 解压后加日志，把证据写到 /boot（重启后还在）。
MOUNT_ROOT="package/base-files/files/lib/preinit/80_mount_root"
if [ -f "$MOUNT_ROOT" ]; then
  echo ">>> Adding restore debug logging to 80_mount_root..."
  cp "$MOUNT_ROOT" "${MOUNT_ROOT}.bak"
  python3 - "$MOUNT_ROOT" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = "\t\t[ -f /sysupgrade.tgz ] && tar xzf /sysupgrade.tgz"
new = ("\t\t[ -f /sysupgrade.tgz ] && {\n"
       "\t\t\ttar xzf /sysupgrade.tgz\n"
       "\t\t\techo \"restore-debug: tgz tar exit=$? shadow_head=$(head -1 /etc/shadow | cut -c1-20)\" >> /boot/restore_debug.log\n"
       "\t\t}")
if old not in content:
    print(">>> [WARN] pattern not found in 80_mount_root, skipping debug patch")
    sys.exit(0)
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print(">>> restore debug logging added")
PYEOF
else
  echo ">>> [WARN] $MOUNT_ROOT not found, skipping debug patch"
fi
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
