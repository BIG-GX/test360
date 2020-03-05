#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ip> <id>"
    exit 10
fi

ips=$1  #ip信息
id=$2   #流程单号
ops_type=$3 #流程类型（重启，关机，重装等)
SSH_CMD="timeout -60 ssh"
APP=${SELE_NAME%.*}
URL_I="http:/xxxxxx/api"    #流程系统api
CURL_POST="XXXXX"     #上报
log_dir=/data/offine_check/
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
log_info "start offine check, ips:$ips, id:$id"

offline_check() {
    local ip=$1
    local proc_check=0
    local net_link_check=0
    if $SSH_CMD "$ip" "ps -ef|grep -vE ']$|PPID|grep'" >"${cur_dir}/logs/${ip}.proc.log"; then
        log_info "offline_check_process successed"
        proc_check=1
    else
        log_err "offline_check_process failed"
    fi
    if $SSH_CMD "$ip" "netstat -tuplan |grep ESTABLISHED" >"${cur_dir}/logs/${ip}.net_link.log"; then
        log_info "offline_check_net_link successed"
        net_link_check=1
    else
        log_err "offline_check_net_link failed"

    if [ $proc_check -eq 1 ]; then
        process=$(cat -A  "${cur_dir}/logs/${ip}.proc.log"|grep -vE '白名单进程' |head -n 1000)
        proc=$(urlencode -m "$process")
    fi
    if [ $net_link_check -eq 1 ]; then
        net_link=$(cat -A "${cur_dir}/logs/${ip}.net_link.log"|grep -vE '白名单' |head -n 2000)
        net_lk=$(urlencode -m "$net_link")
    fi
    ret=$($CURL_POST -d '{xxxxx}' "$URL_I")
    if [ "$(echo "$ret"|jq '.status')"x = "1x" ]; then
        log_info "upload offline_check result successed"
    else
        log_err "upload offline_check result failed"
    fi
}

for ip in $(echo "$ips"|tr ',' ' '); do
    log_info "ip:$ip, id:$id, ops_type: $ops_type, $tmp_str"
    offline_check "$ip" &
done
