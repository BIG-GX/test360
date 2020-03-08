#!/bin/bash
####此脚本用于CMDB授权系统后台调用，前端提供三个参数username，ip，usergroup，通过脚本执行，将管理机上存放的用户密钥上传到远端
PORT=xxx
SSH_CMD=“timeout 60 ssh -p $PORT”
SCP_CMD="XXXXXX"
username=$1
ip=$2
usergroup=$3
self_name=$(basename "$0")
APP=$(self_name%.*)
logfile='/data/log/$APP/'
keyfile='/data/$APP/keys/${username}/.ssh/id_rsa.pub'

log_info() {
    echo "[$(date --rfc-3339=seconds)]:[info]:[$APP]:$1" >>"${log_dir}${username}.log"
}

log_err() {
    echo "[$(date --rfc-3339=seconds)]:[error]:[$APP]:$1" >>"${log_dir}${username}.log"
}

log_warn() {
    echo "[$(date --rfc-3339=seconds)]:[warn]:[$APP]:$1" >>"${log_dir}${username}.log"
}
log_info ""start auth_user, ip:$ip, username:$username,usergroup=$usergroup""

#  #预先检查，判断密钥是否存在，系统版本，机器是否可以ssh，并返回相应的数值
precheck(){
	if [ -e ${keyfile} ];then
		os_version=`$SSH_CMD $ip "cat /etc/issue|sed -n 'ip' "|awk '{print $1}'`
		if [ $? -eq 0 ];then
			if [ "$os_version" != "ubuntu" ];then
				echo 7
			fi
		else
			echo 9
		fi
	else
		echo 10
	fi
}

#创建用户,并加入相应用户组
createuser(){
	$SSH_CMD $ip > /dev/null 2>&1 << eeooff
	groupadd $username > /dev/null 2>&1
	useradd -d /home/$username -m $username -s /bin/bash -g $username
	chown -R $username:$username /home/$username
	gpasswd -a $username $usergroup
	exit
eeooff
}

##上传用户密钥
funchmod(){
 $go $ip > /dev/null 2>&1 << eeooff
        mkdir -p /home/$username/.ssh/;
        chmod 0700 /home/$username/.ssh/;
        chown $username.  /home/$username/.ssh/;
        exit 0;
eeooff

$SCP_CMD ${keyfile} ${ip}:/home/$username/.ssh/id_rsa.pub >/dev/null 2>&1
$SSH_CMD $ip > /dev/null 2>1& << eeooff
    cat /home/${username}/.ssh/id_rsa.pub > /home/${username}/.ssh/authorized_keys;
    chown $username. /home/$username/.ssh/authorized_keys;
    chmod 0600 /home/$username/.ssh/authorized_keys;
    chmod rm -f  /home/${username}/.ssh/id_rsa.pub;
    exit 0;
eeooff
}

auth_user(){
	res=`precheck`
	if [ $res -eq 10 ];then
		timenow=`date "++%Y-%m-%d %H:%M:%S"`
		log_err "授权用户 ${username} 失败,找不到公钥文件,请先申请账号"
		exit 1
	elif [ $res -eq 7 ];then
		/usr/bin/bash authuser_notubuntu.sh  ###针对centos授权方式不一样
	elif [ $res -eq 9 ];then
		log_err "授权用户 ${username} 登陆权限失败,可能是机器已宕机"
	else
		createuser
		funchmod
		log_info "授权用户 ${username} 成功"
        exit 0
	fi
}

auth_user

