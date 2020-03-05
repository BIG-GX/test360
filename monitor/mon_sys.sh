#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
export LANG=C
export LC_ALL=C

#定义一系列变量

#写日志函数
log_info() {
  local msg=$1
  local func=$2
  local freq=$3
  echo "[$(date --rfc-3339=seconds)]:[$app]:[$func]:${freq}:${msg}" >>"$log_file" &
  return 0
}

#上报函数
report_value() {
             #针对数值型，比如负载，io，内存空闲率等需要机器数值的
}

report_alarm() {
             #针对直接发送告警，不需要记录数值
}



#进程数监控
process=$(ls -l /proc/|awk '{print $9}'|grep -c '^[0-9]')
report_value "......"

#重启监控
cuptime=$(awk -F"." '{print $1}' /proc/uptime)
boottime=$(who -b | awk '{print $3,$4,$5,$6}')
[ "$cuptime" -lt 600 ] && report_value "......." 0

#sshd_config密码验证项监控

#CPU---user、system、nice、total使用率统计
mon_cpu() {
  local top_msg
  top_msg=$(top -bn2|grep -C 10 'COMMAND')
  IFS=" " read -r -a cpu_usage <<< "$(echo "$top_msg"|grep Cpu|tail -n 1|sed 's/%/ /g'|tr ',' ' '|awk '{print $2,$4,$6,$8,$10}')"
  cpu_busy="$(awk -v cpu_idle="${cpu_usage[3]}" 'BEGIN{print 100 - cpu_idle}')"
  if [ "$(echo "$cpu_busy"|cut -d. -f 1)" -ge 100 ]; then
    cpu_busy=100
  fi
  topNprocess=$(echo " [top 5 进程:]";echo "$top_msg"|grep Cpu|tail -n 1;echo "$top_msg"|grep -A 5 'COMMAND'|sed 's/--//g'|tail -n 7|awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12}END{print "CPU告警:"}')
  report_value "....."
  IFS=" " read -r -a load_avg <<< "$(awk '{print $1,$2,$3}' /proc/loadavg)"
  report_value "....."
}
mon_cpu &

#内存使用率


#swap使用率


#硬盘io利用率和延时、空间和inode统计


#日志增长量监控

#syslog-ng部分业务不需要监控


#swap si so监控, page/s


#时间监控


#网卡利用率监控

