#!/bin/bash

# basic configurations
TMPLTFILE="template.yaml"
BIN="/opt/clash/clash-linux-armv8"    # clash主体执行文件的绝对路径
URL=(
#"https://raw.githubusercontent.com/AzadNetCH/Clash/main/AzadNet.yml"    # 不好用
"https://raw.githubusercontent.com/alanbobs999/TopFreeProxies/master/sub/sub_merge_clash.yaml"
)

CFGFILE="/tmp/clash.yaml"
LOCKFILE="/tmp/clash.lock"

# curl configurations
TRYS_CURL=5
#PROXY_CURL='socks5://192.168.1.1:1080'      # 如果你想通过代理下载节点数据，取消注释该参数

# temp file
TEMPFILE="/tmp/tmp_clashdata"	


# error msg
function log_e(){ echo -e "\x1b[30;41merror:\x1b[0m \x1b[31m${*}\x1b[0m" >&2; }
# info msg
function log_i(){ echo -e "\x1b[30;42minfo:\x1b[0m \x1b[32m${*}\x1b[0m" >&2; }
# warn msg
function log_w(){ echo -e "\x1b[30;43mwarning:\x1b[0m \x1b[33m${*}\x1b[0m" >&2; }

# 生成配置文件
function genCFGFile()
{
	declare doc nodes tp names_all names_cn names_foreign names_info num
	
	if ! touch "$CFGFILE"
	then
		log_e "failed to touch cfg file."
		return 1
	fi
	if ! tp=$(cat "$TMPLTFILE")
	then
		log_e "failed to load template file."
		return 1
	fi
	
	log_i "start to download nodes data"
	PROXY_CURL=$(sed -nE '/^\s*((socks5|http):\/\/|)[a-zA-Z0-9.]+:[0-9]+\s*$/{p;q;}' <<< "$PROXY_CURL")
	nodes=$(for url0 in ${URL[@]}
	do
		doc=$(curl -# --retry-all-errors --retry "$TRYS_CURL" ${PROXY_CURL:+-x $PROXY_CURL} --fail "$url0")
		echo "$doc" | gojq -c '.proxies[]' --yaml-input
	done | sed -E '/^\s*$/d')
	#nodes=$(cat sub_merge_clash.yaml | gojq -c '.proxies[]' --yaml-input | sed -E '/^\s*$/d')
	if [ -z "$nodes" ]
	then
		log_e "no valid nodes fetched."
		return 2
	fi
	num=$(echo "$nodes" | sed -E '/^\s*$/d' | wc -l)
	log_i "total nodes: $num"
	# 插入信息节点
	# 更改不支持的加密算法：ssr?:chacha20 ---> xchacha20;; ss:chacha20-poly1305 ----> chacha20-ietf-poly1305
	# TLS must be true with h2/grpc network
	nodes=$(echo "$nodes" | sed -E -e '$a'"{\"name\": \"更新时间：$(date "+%Y-%m-%d %H:%M:%S")\", \"server\": \"www.w3school.com.cn\", \"port\": 2, \"type\": \"ss\", \"cipher\": \"xchacha20\", \"password\": \"1\"}" -e '/\"type\":\"ssr?\"/{s/(\"cipher\":\")(chacha20\")/\1x\2/gi;/\"type\":\"ss\"/s/(\"cipher\":\"chacha20)(-poly1305\")/\1-ietf\2/gi};/\"network\":\"grpc\"/{/\"tls\":false/s/(\"tls\":)false/\1true/gi}')
	# 节点名分类
	names_all=$(echo "$nodes" | gojq -c '.name' | sed -E 's/^/      - /;')
	names_cn=$(echo "$names_all" | sed -nE '/香港|台湾|澳门/!{/🇨🇳|(中|回)国|电信|移动|联通/p}')
	names_foreign=$(echo "$names_all" | sed -E '/🇨🇳|(中|回)国|电信|移动|联通|时间|剩余流量/{/香港|台湾|澳门/!d}')
	names_info=$(echo "$names_all" | sed -nE '/时间|剩余流量/p')

	num=$(echo "$names_foreign" | sed -E '/^\s*$/d' | wc -l)
	log_i "foreign nodes: $num"
	num=$(echo "$names_cn" | sed -E '/^\s*$/d' | wc -l)
	log_i "inland nodes: $num"

	if [[ -z "$names_foreign" || -z "$names_info" ]]
	then
		log_e "no vaild nodes found."
		return 2
	fi
	if [[ -z "$names_cn" ]]
	then
		log_w "no nodes available for main land."
		names_cn="$names_info"
	fi
	
	log_i "generating cfg file."
	# 插入节点，失败退出
	if ! tp=$(insertData "$tp" "$(sed 's/^/  - /;' <<< "$nodes")" "^\s*# nodes data up here")
	then
		log_e "error: can't insert nodes to template."
		return 3
	fi
	# 插入节点名，失败退出
	if ! tp=$(insertData "$tp" "$names_foreign" "^\s*# foreign nodes name up here")
	then
		log_e "can't insert nodes' names to template."
		return 4
	fi
	# 插入节点名，失败退出
	#if ! tp=$(insertData "$tp" "$names_all" "^\s*# all nodes name up here")
	#then
	#	log_e "can't insert nodes' names to template."
	#	return 4
	#fi
	# 插入节点名，失败退出
	if ! tp=$(insertData "$tp" "$names_cn" "^\s*# inland nodes name up here")
	then
		log_e "can't insert nodes' names to template."
		return 4
	fi
	# 插入节点名，失败退出
	if ! tp=$(insertData "$tp" "$names_info" "^\s*# info nodes name up here")
	then
		log_e "can't insert nodes' names to template."
		return 4
	fi
	
	if ! cat > "$CFGFILE" <<< "$tp" 
	then
		log_e "failed to write data to cfg file."
		return 5
	fi
	log_i "cfg file generated."
	return 0
}

# 输入：$1=模板, $2=数据, $3=插入位置标记
# 输出：插入数据后的模板
function insertData()
{
	local t
	
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
	then
		echo "error: invaild input data." >& 2
		return 1
	fi
	
	if ! cat > "$TEMPFILE" <<< "$2" 
	then
		echo "error: failed to save data to temp file." >& 2
		rm -f "$TEMPFILE"
		return 2
	fi
	
	if ! t=$(echo "$1" | sed '/'"$3"'/e\'"cat $TEMPFILE")
	then
		echo "error: failed to insert data." >& 2
		rm -f "$TEMPFILE"
		return 3
	fi
	# 信息节点也被加入
	echo "$t"
	rm -f "$TEMPFILE"
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
	[ $? = 1 ] && { log_e "failed to get lock file. Is it runing already?"; exit 40; }
	
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
