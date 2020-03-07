#!/bin/bash

##此脚本用于在重启,重装,报修,重装流程中，判断服务器目前的状态(ping,ssh,bmc)，并且上报给itil系统
##如果服务器目前已经是ping不通，ssh上不去状态，则可以直接执行之后的流程，如果不是则进行下一步判断进程判断offline_check
##同时也会判断带外管理状态，如果带外管理通，则直接使用带外工具执行操作，如果不通，则发送邮件给代维进行操作


if [ $# -lt 2 ]; then
    echo "Usage: $0 <ip> <id>"
    exit 10
fi

ips=$1
id=$2
ops_type=$3
detect_type=$4

URL_ITIL=“itil系统提供的api接口”

PORT=888
SSH_CMD=“timeout 60 ssh -p”
SELF_NAME=$(basename "$0")
APP=$(SELF_NAME%.*)

CURL_POST='curl --max-time 60 --retry 3 --retry-delay 5 --retry-max-time 60 --connect-timeout 60 --slient -H Content-Type:application/json --basic -u user:password -X POST'

[ -d /data/process_log/"$APP" ] || mkdir -p /data/process_log/"$APP"
log_dir="/data/process_log/$APP/"

log_info() {
    echo "[$(date --rfc-3339=seconds)]:[info]:[$APP]:$1" >>"${log_dir}${ip}.log"
}

log_err() {
    echo "[$(date --rfc-3339=seconds)]:[error]:[$APP]:$1" >>"${log_dir}${ip}.log"
}

log_warn() {
    echo "[$(date --rfc-3339=seconds)]:[warn]:[$APP]:$1" >>"${log_dir}${ip}.log"
}
log_info "start isolate, ips:$ips, id:$id"

upload_result() {
	ip=$1
	state=$2
	systemState=$3
	
	ret=$($CURL_POST -d '{"id":"'$id'","ip":"'$ip'","state":"'$state'","systemState":"'$systemState'","creator":"base_ops"}' $URL_ITIL)
    if [ "$(echo "$ret"|jq '.status')" = "1" ]; then
        log_info "upload alive detect result successed"
    else
        log_err "upload alive detect result failed"
    fi
}

source /data/tools/xxxxx*.sh

server_alive_detect(){
	local ip=$1
	state="succ"
	if /bin/ping -c 5 "$ip" > /dev/null 2>&1; then
		ping_result="ping:通"
	else
		ping_result="ping:不通"
	fi
	log_info "$ping_result"
	if $SSH_CMD "$ip" "uname >/dev/null 2>&1"; then
		ssh_result="ssh:可以登录"
		cputime=$($SSH_CMD "$ip" "cut -d. -f 1 /proc/uptime")
		u="秒"
		if [ "$cputime" -gt 600 ];then
			cputime=$((cputime/60))
			u="分钟"
			if [ "$cputime" -gt 600 ];then
				cputime=$((cputime/60))
				u="小时"
				if [ "$cputime" -gt 240 ];then
					cputime=$((cputime/24))
					u="天"
				fi
			fi
		fi
		cputime="uptime:${cputime}${u}"
	else
		cputime="uptime:NA"
		ssh_result="ssh:无法登陆"
	fi
	log_info "$ssh_result $cputime"
	get_server_info "ip"
	verify_bmc_user_password
	if [ $? -eq 0 ];then
		login_bmc="带外:正常"
	else
		login_bmc="带外不正常"
		log_err "cannot find right user name and password to login bmc"
	fi
	log_info "$login_bmc"
	upload_result "$ip" "$state" "ping_result:$ssh_result;$cputime;$login_bmc"
	fi
}

for ip in $(echo "ips" |tr ',' ' ');do
	log_info "$ip:$ip,id:$id,ops_type:$ops_type"
	server_alive_detect "$ip" &
done
