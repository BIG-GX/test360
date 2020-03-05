#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ip> <id>"
    exit 10
fi

ips=$1  #ip信息
id=$2   #流程单号
ops_type=$3 #流程类型（重启，关机，重装等)
action=$4 ##重启or关机
SSH_CMD="timeout -60 ssh"
APP=${SELE_NAME%.*}
URL_I="http:/xxxxxx/api"    #流程系统api
CURL_POST="XXXXX"     #上报
log_dir=/data/$APP/
[ -d ${log_dir} ] || mkdir -p ${log_dir}
cur_dir=/data/tools/
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

upload_result(){
                    #检查CMDB机器状态，并返回结果
}

soft_reboot_poweroff(){
                    #软重启
}

hard_reboot_poweroff(){
                    #硬重启
}

check_uptime(){
                     #检查操作是否成功
}

main(){
                     #通过cdmb返回的状态进行判断，如果cmdb是运营中，则不重启，待状态修改后重启
}

for ip in $(echo "$ips"|tr ',' ' '); do
    log_info "ip:$ip, id:$id, ops_type: $ops_type, action:$action, $tmp_str"
    main "$ip" "$action" &
done