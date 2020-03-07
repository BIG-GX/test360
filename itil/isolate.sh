#!/bin/bash


if [ $# -lt 2 ]; then
    echo "Usage: $0 <ip> <id>"
    exit 10
fi

ips=$1   ##ip
id=$2    ##流程单号
ops_type=$3  ##流程类型

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
sleep 10

##上报函数，通过调用api接口上报结果
upload_result() {
    ip=$1
    state=$2

    ret=`$CURL_POST -d '{"id":"'$id'","ip":"'$ip'","state":"'$state'","creator":"defaultuser"}' $URL_I`
    if [ `echo $ret|jq '.status'`x = "1x" ]; then
        log_info "upload isolate result successed"
    else
        log_err "upload isolate result failed"
    fi
}

#上传隔离脚本到远端机器并执行，并通过ping来测试执行是否成功，五次重试
isolate_by_iptables() {
    for i in `seq 5`; do
        if ping -c 3 $ip >/dev/null 2>&1 || $SSH_CMD $ip "iptables -nL INPUT |grep policy|grep ACCEPT"; then
            $SCP_CMD /data/tools/process_tools/isolate_ipt.sh $ip:/tmp/
            $SSH_CMD $ip "test -f /tmp/isolate_ipt.sh" || log_err "scp isolate script failed"
            $SSH_CMD $ip "bash /tmp/isolate_ipt.sh yes_isolate" || log_err "isolate with iptables failed"
        else
            log_info "isolate with iptables successed"
            return 0
        fi
    done
    return 1
}

source xxxx*.sh  #导入一些命令函数，例如，get_server_info,verify_bmc_passed,isolate_by_iptables

isolate() {
	local ip=$1
	get_server_info $ip  ##通过调用cdmb接口读取服务器状态
	sleep 300   
	if [ "status" = "上架中" ] || [ "status" = "重装中" ] || [ "status" = "隔离中" ]; then
		log_info "ip:$ip, SN:$cmdb_sn, status:$status"
	else
		log_err "server status is $status, the action is not allowed，exit!"
		upload_result $ip fail
		return 1
	fi
	isolate_by_iptables
	if [ $? -eq 1 ]; then
		if [ -z "$mgmt_ip" ]; then
			log_info "no mgmt ip,exit!"
			upload_result $ip succ
			return 1
		fi
		verify_bmc_user_password
		if [ $? -eq 0 ]; then
			log_info "can login bmc($mgmt_ip) by $bmc_user and $bmc_pass"
		else
			log_err "cannot find right user name and passwd to login bmc($mgmt_ip)"
			upload_result $ip succ
			return 1
		fi
		get_system_sn
		if [ -z "$system_sn" ]; then
			log_info "no BMC SN, exit."
			upload_result $ip succ
			return 1
		fi
		if [ -z "$system_sn" ] || [ "$system_sn" != "$cmdb_sn" ]; then
			log_err "server_sn($system_sn) is not the same as cmdb sn($cmdb_sn), exit!"
			upload_result $ip fail
		else
			log_info "server_sn($system_sn) is the same as cmdb sn($cmdb_sn)"
			power_off_server
			if [ $? -eq 0 ]; then
				log_info "power off server successed"
				upload_result $ip succ
			else 
				log_err "power off server fail"
				upload_result $ip fail
			fi
		fi
	else
		upload_result $ip succ
	fi
}

for ip in `echo $ips|tr ',' ' '`;do
	isolate $ip &
done

