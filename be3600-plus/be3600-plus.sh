#!/bin/sh
# be3600-plus.sh — 基于 be3600.sh 的改进版本
# 原作者: @wukongdaily
# 改进: 修复菜单第5项缺失、风扇warn_temp逻辑、输入校验、错误处理、新增OpenClash安装
# 版本: plus-2.0 (2026-03-23)

# 定义颜色输出函数
red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
blue() { echo -e "\033[34m\033[01m$1\033[0m"; }
light_magenta() { echo -e "\033[95m\033[01m$1\033[0m"; }
light_yellow() { echo -e "\033[93m\033[01m$1\033[0m"; }
cyan() { echo -e "\033[38;2;0;255;255m$1\033[0m"; }
third_party_source="https://istore.linkease.com/repo/all/nas_luci"
# 使用自有 GitHub 仓库作为包源，不依赖第三方 cpolar 隧道
HTTP_HOST="https://raw.githubusercontent.com/caryzxd-tech/gl-inet-scripts/main/be3600-plus/packages"
setup_base_init() {
	#添加出处信息
	add_author_info
	#添加安卓时间服务器
	add_dhcp_domain
	##设置时区
	uci set system.@system[0].zonename='Asia/Shanghai'
	uci set system.@system[0].timezone='CST-8'
	uci commit system
	/etc/init.d/system reload
}

## 安装应用商店和主题
install_istore_os_style() {
	##设置Argon 紫色主题
	do_install_argon_skin
	#增加终端
	opkg install luci-i18n-ttyd-zh-cn
	#默认安装必备工具SFTP 方便下载文件 比如finalshell等工具可以直接浏览路由器文件
	opkg install openssh-sftp-server
	#默认使用体积很小的文件传输：系统——文件传输
	do_install_filetransfer
	FILE_PATH="/etc/openwrt_release"
	NEW_DESCRIPTION="Openwrt like iStoreOS Style by wukongdaily"
	CONTENT=$(cat $FILE_PATH)
	UPDATED_CONTENT=$(echo "$CONTENT" | sed "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/")
	echo "$UPDATED_CONTENT" >$FILE_PATH
}
# 安装iStore
do_istore() {
	echo "do_istore 64bit ==================>"
	opkg update
	# 定义目标 URL 和本地目录
	URL="https://repo.istoreos.com/repo/all/store/"
	DIR="/tmp/ipk_store"

	# 创建目录
	mkdir -p "$DIR"
	cd "$DIR" || return 1

	for ipk in $(wget -qO- "$URL" | grep -oE 'href="[^"]+\.ipk"' | cut -d'"' -f2); do
		echo "下载 $ipk"
		wget -q "${URL}${ipk}"
	done

	# 安装所有下载的 .ipk 包
	opkg install ./*.ipk

	#调整a53架构优先级
	add_arch_64bit

}

# 首页和网络向导
do_quickstart() {
	download_lib_quickstart
	download_luci_quickstart
	opkg install /tmp/ipk_downloads/*.ipk
	green "正在更新到最新版iStoreOS首页风格 "
	TMPATH=/tmp/qstart
	mkdir -p ${TMPATH}
	app_aarch64='quickstart_0.11.13-r1_aarch64_generic.ipk'
	app_ui='luci-app-quickstart_0.12.4-r1_all.ipk'
	app_lng='luci-i18n-quickstart-zh-cn_25.090.31208-f5bf244_all.ipk'
	curl -sL -A "Mozilla/5.0" -o ${TMPATH}/$app_aarch64 "$HTTP_HOST/quickstart/$app_aarch64"
	curl -sL -A "Mozilla/5.0" -o ${TMPATH}/$app_ui "$HTTP_HOST/quickstart/$app_ui"
	curl -sL -A "Mozilla/5.0" -o ${TMPATH}/$app_lng "$HTTP_HOST/quickstart/$app_lng"
	opkg install ${TMPATH}/*.ipk
	rm -rf ${TMPATH}
	hide_ui_elements
	#安装高级卸载
	advanced_uninstall
	#自动安装官方辅助UI
	do_auto_install_ui_helper
	green "首页风格安装完毕！请使用8080端口访问luci界面：http://192.168.8.1:8080"
	green "作者更多动态务必收藏：https://tvhelper.cpolar.cn/"
}

download_luci_quickstart() {
	# 目标目录
	REPO_URL="https://repo.istoreos.com/repo/all/nas_luci/"
	DOWNLOAD_DIR="/tmp/ipk_downloads"

	# 创建下载目录
	mkdir -p "$DOWNLOAD_DIR"

	# 获取目录索引并筛选 quickstart ipk 链接
	wget -qO- "$REPO_URL" | grep -oE 'href="[^"]*quickstart[^"]*\.ipk"' |
		sed 's/href="//;s/"//' | while read -r FILE; do
		echo "📦 正在下载: $FILE"
		wget -q -P "$DOWNLOAD_DIR" "$REPO_URL$FILE"
	done

	echo "✅ 所有 quickstart 相关 IPK 文件已下载到: $DOWNLOAD_DIR"
}

download_lib_quickstart() {
	# 目标目录
	REPO_URL="https://repo.istoreos.com/repo/aarch64_cortex-a53/nas/"
	DOWNLOAD_DIR="/tmp/ipk_downloads"

	# 创建下载目录
	mkdir -p "$DOWNLOAD_DIR"

	# 获取目录索引并筛选 quickstart ipk 链接
	wget -qO- "$REPO_URL" | grep -oE 'href="[^"]*quickstart[^"]*\.ipk"' |
		sed 's/href="//;s/"//' | while read -r FILE; do
		echo "📦 正在下载: $FILE"
		wget -q -P "$DOWNLOAD_DIR" "$REPO_URL$FILE"
	done

	echo "✅ 所有 quickstart 相关 IPK 文件已下载到: $DOWNLOAD_DIR"
}

# 判断系统是否为iStoreOS
is_iStoreOS() {
	DISTRIB_ID=$(cat /etc/openwrt_release | grep "DISTRIB_ID" | cut -d "'" -f 2)
	# 检查DISTRIB_ID的值是否等于'iStoreOS'
	if [ "$DISTRIB_ID" = "iStoreOS" ]; then
		return 0 # true
	else
		return 1 # false
	fi
}

## 去除opkg签名
remove_check_signature_option() {
	local opkg_conf="/etc/opkg.conf"
	sed -i '/option check_signature/d' "$opkg_conf"
}

## 添加opkg签名
add_check_signature_option() {
	local opkg_conf="/etc/opkg.conf"
	echo "option check_signature 1" >>"$opkg_conf"
}

#设置第三方软件源
setup_software_source() {
	## 传入0和1 分别代表原始和第三方软件源
	if [ "$1" -eq 0 ]; then
		echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
		##如果是iStoreOS系统,还原软件源之后，要添加签名
		if is_iStoreOS; then
			add_check_signature_option
		else
			echo
		fi
		# 还原软件源之后更新
		opkg update
	elif [ "$1" -eq 1 ]; then
		#传入1 代表设置第三方软件源 先要删掉签名
		remove_check_signature_option
		# 先删除再添加以免重复
		echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
		echo "src/gz third_party_source $third_party_source" >>/etc/opkg/customfeeds.conf
		# 设置第三方源后要更新
		opkg update
	else
		echo "Invalid option. Please provide 0 or 1."
	fi
}

# 添加主机名映射(解决安卓原生TV首次连不上wifi的问题)
add_dhcp_domain() {
	local domain_name="time.android.com"
	local domain_ip="203.107.6.88"

	# 检查是否存在相同的域名记录
	existing_records=$(uci show dhcp | grep "dhcp.@domain\[[0-9]\+\].name='$domain_name'")
	if [ -z "$existing_records" ]; then
		# 添加新的域名记录
		uci add dhcp domain
		uci set "dhcp.@domain[-1].name=$domain_name"
		uci set "dhcp.@domain[-1].ip=$domain_ip"
		uci commit dhcp
	else
		echo
	fi
}

#添加出处信息
add_author_info() {
	uci set system.@system[0].description='wukongdaily'
	uci set system.@system[0].notes='文档说明:
    https://tvhelper.cpolar.cn/'
	uci commit system
}

##获取软路由型号信息
get_router_name() {
	model_info=$(cat /tmp/sysinfo/model)
	echo "$model_info"
}

get_router_hostname() {
	hostname=$(uci get system.@system[0].hostname)
	echo "$hostname 路由器"
}

# 安装体积非常小的文件传输软件 默认上传位置/tmp/upload/
do_install_filetransfer() {
	mkdir -p /tmp/luci-app-filetransfer/
	cd /tmp/luci-app-filetransfer/
	curl -sL -A "Mozilla/5.0" -o luci-app-filetransfer_all.ipk "$HTTP_HOST/filetransfer/luci-app-filetransfer_all.ipk"
	curl -sL -A "Mozilla/5.0" -o luci-lib-fs_1.0-14_all.ipk "$HTTP_HOST/filetransfer/luci-lib-fs_1.0-14_all.ipk"
	opkg install *.ipk --force-depends
}
do_install_depends_ipk() {
	curl -sL -A "Mozilla/5.0" -o "/tmp/luci-lua-runtime_all.ipk" "$HTTP_HOST/theme/luci-lua-runtime_all.ipk"
	curl -sL -A "Mozilla/5.0" -o "/tmp/libopenssl3.ipk" "$HTTP_HOST/theme/libopenssl3.ipk"
	opkg install "/tmp/luci-lua-runtime_all.ipk"
	opkg install "/tmp/libopenssl3.ipk"
}
#单独安装argon主题
do_install_argon_skin() {
	echo "正在尝试安装argon主题......."
	#下载和安装argon的依赖
	do_install_depends_ipk
	# bug fix 由于2.3.1 最新版的luci-argon-theme 登录按钮没有中文匹配,而2.3版本字体不对。
	# 所以这里安装上一个版本2.2.9,考虑到主题皮肤并不需要长期更新，因此固定版本没问题
	opkg update
	opkg install luci-lib-ipkg
	curl -sL -A "Mozilla/5.0" -o "/tmp/luci-theme-argon.ipk" "$HTTP_HOST/theme/luci-theme-argon-master_2.2.9.4_all.ipk"
	curl -sL -A "Mozilla/5.0" -o "/tmp/luci-app-argon-config.ipk" "$HTTP_HOST/theme/luci-app-argon-config_0.9_all.ipk"
	curl -sL -A "Mozilla/5.0" -o "/tmp/luci-i18n-argon-config-zh-cn.ipk" "$HTTP_HOST/theme/luci-i18n-argon-config-zh-cn.ipk"
	cd /tmp/
	opkg install luci-theme-argon.ipk luci-app-argon-config.ipk luci-i18n-argon-config-zh-cn.ipk
	# 检查上一个命令的返回值
	if [ $? -eq 0 ]; then
		echo "argon主题 安装成功"
		# 设置主题和语言
		uci set luci.main.mediaurlbase='/luci-static/argon'
		uci set luci.main.lang='zh_cn'
		uci commit
		sed -i 's/value="<%:Login%>"/value="登录"/' /usr/lib/lua/luci/view/themes/argon/sysauth.htm
		echo "重新登录web页面后, 查看新主题 "
	else
		echo "argon主题 安装失败! 建议再执行一次!再给我一个机会!事不过三!"
	fi
}

recovery() {
	echo "⚠️ 警告：此操作将恢复出厂设置，所有配置将被清除！"
	echo "⚠️ 请确保已备份必要数据。"
	read -p "是否确定执行恢复出厂设置？(yes/[no]): " confirm

	if [ "$confirm" = "yes" ]; then
		echo "正在执行恢复出厂设置..."
		# 安静执行 firstboot，不显示其内部的提示信息
		firstboot -y >/dev/null 2>&1
		echo "操作完成，正在重启设备..."
		reboot
	else
		echo "操作已取消。"
	fi
}

add_arch_64bit() {
	if ! curl -sL -A "Mozilla/5.0" -o /etc/opkg/arch.conf "$HTTP_HOST/64bit/arch.conf"; then
		echo "下载 arch.conf 失败，脚本终止。"
		exit 1
	fi
}

# 防止误操作 隐藏首页无用的元素
hide_ui_elements() {

    TARGET="/www/luci-static/quickstart/style.css"
    MARKER="/* hide custom luci elements */"

    # 如果没有追加过，就添加
    if ! grep -q "$MARKER" "$TARGET"; then
        cat <<EOF >>"$TARGET"

$MARKER
/* 隐藏首页格式化按钮 */
.value-data button {
  display: none !important;
}

/* 隐藏网络页的第 3 个 item */
#main > div > div.network-container.align-c > div > div > div:nth-child(3) {
  display: none !important;
}

/* 隐藏网络页的第 5 个 item */
#main > div > div.network-container.align-c > div > div > div:nth-child(5) {
  display: none !important;
}

/* 隐藏 feature-card.pink */
#main > div > div.card-container > div.feature-card.pink {
  display: none !important;
}

EOF
        echo "✅ 自定义元素已隐藏"
    else
        echo "⚠️ 无需重复操作"
    fi
}

#自定义风扇开始工作的温度
set_glfan_temp() {

	echo "兼容带风扇机型的GL-iNet路由器"
	echo "请输入风扇开始工作的温度(建议40-70之间的整数):"
	read temp

	# 兼容 sh 的整数校验（不依赖 bash 的 [[ =~ ]]）
	case "$temp" in
		''|*[!0-9]*) echo "错误: 请输入整数."; return ;;
	esac

	if [ "$temp" -lt 30 ] || [ "$temp" -gt 85 ]; then
		echo "错误: 温度应在 30-85°C 之间."
		return
	fi

	if true; then
		# warn_temperature 设为启动温度 +15°C，避免与启动温度相同导致逻辑混乱
		warn_temp=$((temp + 15))
		uci set glfan.@globals[0].temperature="$temp"
		uci set glfan.@globals[0].warn_temperature="$warn_temp"
		uci set glfan.@globals[0].integration=4
		uci set glfan.@globals[0].differential=20
		uci commit glfan
		/etc/init.d/gl_fan restart
		echo "设置成功！风扇启动温度: ${temp}°C，警告温度: ${warn_temp}°C"
		echo "稍等片刻，请查看风扇转动情况"
	else
		echo "错误: 请输入整数."
	fi
}

toggle_adguardhome() {
	status=$(uci get adguardhome.config.enabled)

	if [ "$status" -eq 1 ]; then
		echo "Disabling AdGuardHome..."
		uci set adguardhome.config.enabled='0' >/dev/null 2>&1
		uci commit adguardhome >/dev/null 2>&1
		/etc/init.d/adguardhome disable >/dev/null 2>&1
		/etc/init.d/adguardhome stop >/dev/null 2>&1
		green "AdGuardHome 已关闭"
	else
		echo "Enabling AdGuardHome..."
		uci set adguardhome.config.enabled='1' >/dev/null 2>&1
		uci commit adguardhome >/dev/null 2>&1
		/etc/init.d/adguardhome enable >/dev/null 2>&1
		/etc/init.d/adguardhome start >/dev/null 2>&1
		green "AdGuardHome 已开启 访问 http://192.168.8.1:3000"
	fi
}

# 安装[官方辅助UI]插件 by 论坛 iBelieve
do_install_ui_helper() {
  echo "⚠️ 请您确保当前固件版本大于 4.7.2，若低于此版本建议先升级。"
  read -p "👉 如果您已确认，请按 [回车] 继续；否则按 Ctrl+C 或输入任意内容后回车退出：" user_input
  if [ -n "$user_input" ]; then
    echo "🚫 用户取消安装。"
    return 1
  fi
  do_auto_install_ui_helper
}

#自动安装[官方辅助UI]（无需确认，供一键安装流程调用）
do_auto_install_ui_helper() {

  local ipk_file="/tmp/glinjector_3.0.5-6_all.ipk"
  local sha_file="${ipk_file}.sha256"

  echo "📥 正在下载 IPK 及 SHA256 校验文件..."
  curl -sL -A "Mozilla/5.0" -o "$sha_file" "$HTTP_HOST/ui/glinjector_3.0.5-6_all.ipk.sha256" || {
    echo "❌ 下载 SHA256 文件失败"
    return 1
  }

  curl -sL -A "Mozilla/5.0" -o "$ipk_file" "$HTTP_HOST/ui/glinjector_3.0.5-6_all.ipk" || {
    echo "❌ 下载 IPK 文件失败"
    return 1
  }

  echo "🔐 正在进行 SHA256 校验..."

  cd "$(dirname "$ipk_file")"
  sha256sum -c "$sha_file" || {
    echo "❌ 校验失败：文件已损坏或未完整下载"
    rm -f "$ipk_file"
    return 1
  }

  echo "✅ 校验通过，开始安装..."

  opkg update
  opkg install "$ipk_file"
}

# 安装 OpenClash
do_install_openclash() {
	echo "📥 正在安装 OpenClash..."

	# 安装依赖
	opkg update
	opkg install bash iptables dnsmasq-full curl ca-bundle ipset ip-full \
		iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun \
		kmod-inet-diag unzip luci-compat luci luci-base 2>/dev/null

	# 如果 dnsmasq-full 冲突，先卸载 dnsmasq 再装
	if ! opkg list-installed | grep -q "dnsmasq-full"; then
		opkg remove dnsmasq && opkg install dnsmasq-full
	fi

	# 获取最新 release 版本号
	CLASH_URL="https://github.com/vernesong/OpenClash/releases"
	echo "正在获取最新版本信息..."

	# 直接从 GitHub API 获取最新 release
	LATEST_VER=$(wget -qO- "https://api.github.com/repos/vernesong/OpenClash/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | cut -d'"' -f4)

	if [ -z "$LATEST_VER" ]; then
		yellow "⚠️ 无法获取最新版本，使用备用方式安装..."
		# 备用：从 iStore 安装（如果有的话）
		opkg install luci-app-openclash 2>/dev/null
		if [ $? -eq 0 ]; then
			green "✅ OpenClash 从 iStore 安装成功"
			return 0
		fi
		red "❌ 安装失败，请检查网络连接"
		return 1
	fi

	IPK_NAME="luci-app-openclash_${LATEST_VER#v}_all.ipk"
	IPK_URL="https://github.com/vernesong/OpenClash/releases/download/${LATEST_VER}/${IPK_NAME}"

	echo "📦 下载 OpenClash ${LATEST_VER}..."
	wget --user-agent="Mozilla/5.0" -O "/tmp/${IPK_NAME}" "$IPK_URL"
	if [ $? -ne 0 ]; then
		red "❌ 下载失败，请检查网络（可能需要代理访问 GitHub）"
		return 1
	fi

	opkg install "/tmp/${IPK_NAME}"
	if [ $? -eq 0 ]; then
		green "✅ OpenClash ${LATEST_VER} 安装成功！"
		green "🌐 访问 http://192.168.8.1/cgi-bin/luci/admin/services/openclash"
		echo ""
		yellow "📝 提示：还需要下载 Clash 内核才能使用，请在 OpenClash 界面中操作"
		# 清理
		rm -f "/tmp/${IPK_NAME}"
	else
		red "❌ 安装失败"
		return 1
	fi
}

#高级卸载
advanced_uninstall(){
	echo "📥 正在下载 高级卸载插件..."
	curl -sL -A "Mozilla/5.0" -o /tmp/advanced_uninstall.run "$HTTP_HOST/luci-app-uninstall.run" && chmod +x /tmp/advanced_uninstall.run
	sh /tmp/advanced_uninstall.run
}

while true; do
	clear
	gl_name=$(get_router_name)
	result="GL-iNet Be3600 一键iStoreOS风格化"
	echo "***********************************************************************"
	echo "*      一键安装工具箱(for gl-inet be3600)  by @wukongdaily 20251118       "
	echo "**********************************************************************"
	echo "*******支持的机型列表***************************************************"
	green "*******GL-iNet BE-3600********"
	green "请确保您的固件版本在4.7.2以上"
	echo

	light_magenta " 1. $result (64位)"
	echo
	light_magenta " 2. 安装argon紫色主题"
	echo
	light_magenta " 3. 单独安装iStore商店"
	echo
	light_magenta " 4. 隐藏首页格式化按钮"
	echo
	light_magenta " 5. 自定义风扇启动温度（适用带风扇机型）"
	echo
	light_magenta " 6. 启用或关闭AdGuardHome广告拦截"
	echo
	light_magenta " 7. 安装个性化UI辅助插件(by VMatrices)"
	echo
	light_magenta " 8. 安装高级卸载插件"
	echo
	light_magenta " 9. 恢复出厂设置/重置路由器"
	echo
	light_magenta " 10. 安装 OpenClash（科学上网）"
	echo
	echo " Q. 退出本程序"
	echo
	read -p "请选择一个选项: " choice

	case $choice in

	1)
		#安装iStore风格
		install_istore_os_style
		#基础必备设置
		setup_base_init
		#安装iStore商店
		do_istore
		#安装首页和网络向导
		do_quickstart
		;;
	2)
		do_install_argon_skin
		;;
	3)
		do_istore
		;;
	4)
		hide_ui_elements
		;;
	5)
		set_glfan_temp
		;;
	6)
		toggle_adguardhome
		;;
	7)
		do_install_ui_helper
		;;
	8)
		advanced_uninstall
		;;
	9)
		recovery
		;;
	10)
		do_install_openclash
		;;
	q | Q)
		echo "退出"
		exit 0
		;;
	*)
		echo "无效选项，请重新选择。"
		;;
	esac

	read -p "按 Enter 键继续..."
done
