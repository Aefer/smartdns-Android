#!/system/bin/sh
MODDIR=/data/adb/modules/smartdns
[[ $(id -u) -ne 0 ]] && { echo "${MODDIR##\/*\/}: Permission denied"; exit 1; }

usage() {
	cat <<-EOF
Valid options are:
    -start
        Start Server
    -stop
        Stop Server
    -status
        Server Status
    -usage
        Get help
    -user [radio/root]
        Server permission
    -anti302 [true/false]
        anti-http 302 hijacking
    -ip6block [true/false]
        block IPv6 port 53
    -antipoisoning [true/false]
        anti-DNS poisoning
    -antihttpdns [true/false]
        anti-http dns
EOF
	exit $1
}

## 防火墙
# 主控
iptrules_on() {
	iptrules_load $IPT -I
	ip6trules_switch -I
}

iptrules_off() {
	local i=0
	while iptrules_check; do
		iptrules_load $IPT -D
		ip6trules_switch -D
		[[ ${i} > 2 ]] && { echo 'error: iptrules check error'; exit 1; } || ((++i))
	done
}

ip6trules_switch() {
	if [ $ip6t_block ]; then
		$IP6T -t filter $1 OUTPUT -p udp --dport 53 -j DROP
		$IP6T -t filter $1 OUTPUT -p tcp --dport 53 -j REJECT --reject-with tcp-reset
	else
		iptrules_load $IP6T $1
	fi
}

# 加载
iptrules_load() {
	echo "info: $1 $2"

	# 新建规则
	if [ "${2}" == '-I' ]; then
		$1 -t nat -N DNS_LOCAL
		$1 -t nat -A DNS_LOCAL -m owner --uid-owner $(id -u $ServerUID) -j RETURN
	fi

	for IPP in 'udp' 'tcp'
	do
		# DNS_LOCAL
		$1 -t nat $2 OUTPUT -p $IPP --dport 53 -j DNS_LOCAL
		$1 -t nat $2 DNS_LOCAL -p $IPP -j REDIRECT --to-ports $Listen_PORT
		$1 -t nat $2 POSTROUTING -p $IPP -d 127.0.0.1 --dport $Listen_PORT -j SNAT --to-source 127.0.0.1
		# DNS_EXTERNAL
		$1 -t nat $2 PREROUTING -p $IPP --dport 53 -j REDIRECT --to-ports $Listen_PORT
	done

	# 清除规则
	if [ "${2}" == '-D' ]; then
		$1 -t nat -F DNS_LOCAL
		$1 -t nat -X DNS_LOCAL
	fi

	#anti http 303
	if [ $ipt_anti302 ]; then
		$1 -t filter $2 INPUT -p tcp -m tcp --sport 80 --tcp-flags SYN,RST,URG FIN,PSH,ACK -m ttl --ttl-gt 20 -m ttl --ttl-lt 30 -j DROP
	fi

	#anti DNS poisoning
	if [ $ipt_antipoisoning ]; then
		$1 $2 INPUT -p udp --sport 53 -m u32 --u32 "2&0xFFFF=0x0" -j DROP
		$1 $2 INPUT -p udp --sport 53 -m u32 --u32 "4&0xFFFF=0x4000" -j DROP
	fi

	#anti httpdns
	if [ $ipt_antihttpdns ]; then
		$1 $2 INPUT -p tcp -d 119.29.29.29 -m tcp --dport 80 -j REJECT --reject-with tcp-reset
		$1 $2 INPUT -p tcp -d 180.76.76.200 -m tcp --dport 80 -j REJECT --reject-with tcp-reset
		$1 $2 INPUT -p tcp -d 180.76.76.200 -m tcp --dport 443 -j REJECT --reject-with tcp-reset
	fi
}

## 检查
# 防火墙
iptrules_check()
{
	if [ -n "`$IPT -t nat -S OUTPUT | grep 'DNS_LOCAL'`" ]; then
		echo 'info: iprules √'; return 0
	else
		echo 'info: iprules ×'; return 1
	fi
}

# 核心进程
core_check()
{
	if [ -n "`pgrep $CORE_BINARY`" ]; then
		echo 'info: Server √'; return 0
	else
		echo 'info: Server ×'; return 1
	fi
}

server_check() {
	local i=0
	core_check || i=`expr $i + 2`
	iptrules_check || ((++i))

	case ${i} in
		3)  # 未工作
			return 1 ;;
		2)  # 核心
			return 11 ;;
		1)  # 防火墙
			return 10 ;;
		0)  # 工作中
			return 0 ;;
	esac
}



## 其他
# (重)启动核心
core_start() {
	killall $CORE_BINARY 2>/dev/null
	sleep 1
	#setuidgid UID GID GROUPS
	$CORE_DIR/setuidgid $(id -u $ServerUID) $(id -g $ServerUID) $(id -g $ServerUID),$(id -g inet),$(id -g media_rw) $CORE_BOOT 2>&1
	sleep 3
	if core_check; then
		echo "info: Server start $(date +'%d/%r')"
		return 0
	else
		echo 'error: Server failed to start'
		exit 1
	fi
}

### main
save_value() {
	local tmp=$(grep "^$1=" $MODDIR/constant.sh)
	value_change=true
	if [ -z "${3}" ]; then
		sed -i "s#^$tmp#$1=\"$2\"#g" $MODDIR/constant.sh
	else
		sed -i "s#^$tmp#$1=$2#g" $MODDIR/constant.sh
	fi
	return $?
}


get_args() {
	Listen_PORT=6453
	ServerUID='radio'
	ip6t_block=true
	ipt_anti302=false
	source $MODDIR/constant.sh || exit 1

	while [ ${#} -gt 0 ]; do
		case "${1}" in
			-usage) # 帮助信息
				usage 0
				;;

			-start) # 启动
				Server='start'
				;;

			-stop) # 停止
				Server='stop'
				;;

			-status) # 检查状态
				server_check
				exit $?
				;;

				# 修改数值
			-user) # radio/root
				if [ "${2}" != 'radio' -a "${2}" != 'root' ]; then
					echo "warn: Invalid value: $2"
					exit 1
				fi
				ServerUID=$2
				save_value ServerUID $2
				shift 1
				;;

			-anti302)
				if [ "${2}" != 'true' -a "${2}" != 'false' ]; then
					echo "warn: Invalid value: $2"
					exit 1
				fi
				ipt_anti302=$2
				save_value ipt_anti302 $2 bool
				shift 1
				;;

			-ip6block)
				if [ "${2}" != 'true' -a "${2}" != 'false' ]; then
					echo "warn: Invalid value: $2"
					exit 1
				fi
				ip6t_block=$2
				save_value ip6t_block $2 bool
				shift 1
				;;

			*)
				echo "warn: Invalid argument: $1"
				usage 1
				;;

			esac
		shift 1
	done
}

process() {
	if [ $value_change -a server_check ]; then
		echo -e 'info: value change !\ninfo: restart server !'
		Server='start'
	fi

	case "$Server" in
		start) # 启动
			iptrules_off
			core_start && iptrules_on
			;;

		stop) # 停止
			iptrules_off
			killall $CORE_BINARY 2>/dev/null
			echo "info: Server stop $(date +'%d/%r')"
			;;
	esac
}

main() {
	if [ -z "${1}" ]; then
		usage 0
	else
		get_args "$@"
		process
	fi
}

main "$@"
