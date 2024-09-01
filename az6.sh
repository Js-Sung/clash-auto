#!/bin/bash

# basic configurations
URL="https://freenode.openrunner.net/uploads/$(date +%Y%m%d)-clash.yaml"
URL_BAK="https://freenode.openrunner.net/uploads/$(date -d '-1 day' +%Y%m%d)-clash.yaml"

my_cfg='
mixed-port: 7890
socks-port: 7892
allow-lan: true
external-ui: gh
secret: "123456"
external-controller: :9090
'

BIN="/opt/clash/clash-linux-arm64"
CFGFILE="/tmp/clash.yaml"
LOCKFILE="/tmp/clash.lock"

# curl configurations
#PROXY_CURL='socks5://192.168.8.1:1088'


# error msg
function log_e(){ echo -e "\x1b[30;41merror:\x1b[0m \x1b[31m${*}\x1b[0m" >&2; }
# info msg
function log_i(){ echo -e "\x1b[30;42minfo:\x1b[0m \x1b[32m${*}\x1b[0m" >&2; }
# warn msg
function log_w(){ echo -e "\x1b[30;43mwarning:\x1b[0m \x1b[33m${*}\x1b[0m" >&2; }

# 生成配置文件
function genCFGFile()
{
	declare data t0
	
	if ! touch "$CFGFILE"
	then
		log_e "failed to touch cfg file."
		return 1
	fi
	
	log_i "start to download nodes data"
	PROXY_CURL=$(sed -nE '/^\s*((socks5|http):\/\/|)[a-zA-Z0-9.]+:[0-9]+\s*$/{p;q;}' <<< "$PROXY_CURL")
	
	if ! data=$(curl -# --retry-all-errors --retry 4 ${PROXY_CURL:+-x $PROXY_CURL} --fail -L "$URL")
	then
		log_w "fail to download the 1st link, using backup link."
		if ! data=$(curl -# --retry-all-errors --retry 4 ${PROXY_CURL:+-x $PROXY_CURL} --fail -L "$URL_BAK")
		then
			log_e "failed to download cfg file."
			return 2
		fi
	fi
	
	t0=$(echo "$my_cfg" | sed -E "/^\s*$/d;:a;N;s/\n/\\\n/g;ta")
	data=$(echo "$data" | sed -E '/^(mixed-|socks-)?port/d;/^allow-lan/d;/^external-(ui|controller)/d;' | sed -E '1i\'"$t0")
	echo "$data" >"$CFGFILE"
	
	log_i "cfg file generated."
	return 0
}

function restartClash()
{
	# 杀死clash进程
	killall "$BIN" &> /dev/null
	sleep 0.1
	if ! killall -0 "$BIN" &> /dev/null
	then
		log_i "kill $BIN successfully."
	else
		log_e "failed to kill $BIN."
		return 1
	fi

	# 启动clash
	nohup $BIN -f "$CFGFILE" &> /dev/null &
	log_i "waiting for $BIN up."
	sleep 2

	if killall -0 "$BIN" &> /dev/null
	then
		log_i "$BIN started successfully."
	else
		log_e "failed to start $BIN."
		return 2
	fi
	return 0
}

#================PROGRAM START================#
# 进入脚本所在目录
cd $(dirname "$0")

{
	flock -n 198
	[ $? = 1 ] && { log_e "failed to get lock file. Is '$0' runing already?"; exit 40; }
	
	genCFGFile
	ret=$?
	if (( ret != 0 ))
	then 
		log_e "failed to generate cfg file with error code $ret."
		exit 1
	fi
	
	restartClash
	ret=$?
	if (( ret != 0 ))
	then
		log_e "failed to start clash with error code $ret."
		exit 2
	fi
	
	flock -u 198
	log_i "all jobs done."
} 198<>"$LOCKFILE"

exit 0
