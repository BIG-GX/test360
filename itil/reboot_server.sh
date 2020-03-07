#!/bin/bash


if [ $# -lt 3 ]; then
    echo "Usage: $0 <ip> <reboot|poweroff> <id>"
    exit 10
fi

ips=$1
id=$2
ops_type=$3
action=$4

cur_dir=$(pwd)

URL_I="http://itil.test.xy/api/v1/xxx/$ops_type/xxx" ##itil系统提供的api接口

PORT=888
SSH_CMD="timeout 60 ssh -p ${PORT} -o StrictHostKeyChecking=no"
SCP_CMD="timeout 60 scp -P ${PORT} -o StrictHostKeyChecking=no"
SELF_NAME=$(basename $0)
APP=${SELF_NAME%.*}

CURL_POST='curl --max-time 60 --retry 3 --retry-delay 5 --retry-max-time 60 --connect-timeout 60 --silent -H Content
-Type:application/json --basic -u user:passwd -X POST'

[ -d /data/process_log/"$APP" ] || mkdir -p /data/process_log/"$APP"
log_dir="/data/process_log/$APP/"
cur_dir=/data/tools/process_tools

log_info() {
    echo "[$(date --rfc-3339=seconds)]:[info]:[$APP]:$1" >>${log_dir}${ip}.log
}

log_err() {
    echo "[$(date --rfc-3339=seconds)]:[error]:[$APP]:$1" >>${log_dir}${ip}.log
}

log_warn() {
    echo "[$(date --rfc-3339=seconds)]:[warn]:[$APP]:$1" >>${log_dir}${ip}.log
}

log_info "start isolate, ips:$ips, id:$id"

source /data/tools/xxxxx*.sh

upload_result() {
	ip=$1
	state=$2
    cd "$cur_dir"
    if [ -f "alive_detect.sh" ]; then
        log_info "start alive detect"
        bash alive_detect.sh "$ip" "$id" "$tmp_ops_type"
    fi
    ret=`$CURL_POST -d '{"id":"'$id'","ip":"'$ip'","state":"'$state'","creator":"base_ops"}' $URL_I`
    if [ "$(echo "$ret"|jq '.status')" = "1" ]; then
        log_info "upload $action result successed"
    else
        log_err "upload $action result failed"
    fi  
}

soft_reboot_poweroff() {
	local ip=$1
	local action="$2"
	
	if [[ "action" == "reboot" ]] || [[ "action" == "poweroff" ]]; then
		if $SSH_CMD "$ip" "sync";then
			$SSH_CMD "$ip" "sync;sync;sync;$action"
			log_info "remote execute $action successed"
			return 0
		else
			log_info "remote execute $action failed,can not ssh."
			return 1
		fi
	fi
	return 1
}

hard_reboot_poweroff() {
	local ip=$1
	local action="$2"
	
	verify_bmc_user_password
	if [ $? -eq -0 ];then
		log_info "can login bmc($mgmt_ip) by $bmc_user and $bmc_pass"
	else
		log_err "cannot find right user name and passwd to login bmc($mgmt_ip)"
		return 1
	fi
	get_system_sn
	if [ -Z "$system_sn" ] || [ "$system_sn" != "$cmdb_sn" ]; then
		log_err "server sn($system_sn) is not the same as cmdb_sn sn($cmdb_sn),exit!"
		return 1
	else
		log_info "server sn($system_sn) is the same as cmdb sn($cmdb_sn)"
		power_off_server
		if [ $? -eq 0 ]; then
			log_info "power off server successed"
		else 
			log_err "power off server fail"
			return 1
		fi
	fi
	if [[ "$action" == "reboot" ]]; then
		power_on_server
		if [ $? = 0 ]; then
			log_info "power on server successed"
			return 0
		else
			log_err "power on server failed"
			return 1
		fi
	fi
	return 0
}

check_uptime() {
	local ip=$1
	local action=$2
	local i=0
	
	while [ "$i" -lt 11 ];do
		sleep 60
		log_info "check_uptime, action:$action times:$i"
		if [[ "action" == "poweroff" ]];then
			check_power_status
			if [ $? -eq 0 ];then
				log_info "power status checked is:poweroff
				return 0
			fi
		    if /bin/ping -c 5 "$ip" >/dev/null 2>$1 || $SSH_CMD "$ip“ "uname >/dev/null";then
				if [ "$i" -ge 10 ];then   ##多次检查，如果10分钟内一直能ping通或者ssh能上，说明关机不成功
					log_info "$action server failed"
					return 1
				fi
			else
			    if ["$i" -ge 10 ];then   
					log_info "$action server successed"
					return 0
				fi
			fi
		else
			t1=$(date +%s)
			t_diff=$((t1-t0))
			cputime=$($SSH_CMD "$ip" "cut -d. -f 1 /proc/uptime")
			if [ "$cputime" -gt 60 ] && [ "$cputime" -le "$t_diff" ]; then
				log_info "$action server successed"
				return 0
			fi
			if [ "$1" -ge 60 ]; then
				log_info "$action server failed"
				return 1
			fi
		fi
		((i++))
	done	        
}

reboot_poweroff() {
	local ip=$1
	local action="$2"
	local i=0
	local n=0

	sleep 200
	get_server_info "$ip"
	t0=$(date +%s)
	if [ "status" = "上架中" ] || [ "$status" = "重装中" ] || [ "$status" = "重启中" ] || [ "$status" = "关机中" ] || [ "$status" = "已关机" ]; then
		log_info "ip:$ip, SN:$cmdb_sn, status:$status"
	else
		log_err "server status is $status,  $action is not allowed!"
		upload_result "$ip" fail
		return 1
	fi
	soft_reboot_poweroff "$ip" "$action"
	if [ $? -eq 0 ];then
		check_uptime "ip" "action"
		if [ $? -eq 0 ];then
			upload_result "ip" succ
			return 0
		fi
	fi
	hard_reboot_poweroff "$ip" "$action"
	if [ $? -eq 1 ]; then
		log_err "带内和带外操作($action)都失败了"
		return 1
    fi
	check_uptime "$ip" "$action"
	if [ $? -eq 0 ];then
		upload_result "$ip" succ
		return 0
	else
		upload_result "$ip" fail
		return 1
	fi
}

for ip in $(echo "$ips"|tr ',' ' '); do
	reboot_poweroff "$ip" "$action" &
done
