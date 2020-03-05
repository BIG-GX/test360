#!/bin/bash
####此脚本用于CMDB授权系统后台调用，前端提供三个参数username，ip，usergroup，通过脚本执行，将管理机上存放的用户密钥上传到远端
机器，并且根据参数加到相应的用户组，不通的用户组拥有不通的权限

ssh_cmd="ssh -o xxxxx"
username=$1
ip=$2
usergroup=$3
app=${SELE_NAME%.*}
logfile='/data/log/$app.log
keypath='xxxxx'

pre_check(){
              #预判断,比如特殊机器，密钥不存在，服务器不是运营中机器，返回相应数值
}

adduser(){
               #登录远程机器添加用户并增加到相应组
}

funchmod(){
               #登录到远端机器修改.ssh目录为0700
               #在本地执行scp将管理机存放的用户密钥上传到远端机器的.ssh,并修改文件名和属主属组和权限为0600
}

main(){
               #通过pre_check返回的相应数值，做出不同的提示或者操作
}

main

