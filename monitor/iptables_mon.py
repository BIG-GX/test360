#!/usr/bin/python
# -*- coding: utf-8 -*-
import re
import commands
import time, os
import subprocess
import socket
import struct
import json
import sys,signal
from subprocess import Popen,PIPE


def command(cmd, timeout=60):
    """执行命令cmd，返回命令输出的内容。
    如果超时将会抛出TimeoutError异常。
    cmd - 要执行的命令
    timeout - 最长等待时间，单位：秒
    """
    p = subprocess.Popen(cmd, stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
    t_beginning = time.time()
    seconds_passed = 0
    while True:
        if p.poll() is not None:
            break
        seconds_passed = time.time() - t_beginning
        if timeout and seconds_passed > timeout:
            p.terminate()
            print "Execute %s is timeout" % cmd
            result = 'Execute' + cmd + 'is timeout'
        time.sleep(0.1)
    return p.stdout.read()
#获取自建机房ip列表
def GetOwnIplist():
    owniplist = []
    with open('/usr/xxxxxxx/net_list.txt') as f:
        for i in f:
            tmp = i.split(",")
            startnum = int(tmp[1])
            endnum = int(tmp[2])
            tmpnumlist = range(startnum, endnum + 1)
            for ipnum in tmpnumlist:
                ip = Int2Ip(ipnum)
                owniplist.append(ip)
    return owniplist
# 记录上一分钟行数l1，和当前的行数l2，获取l1和l2之间的日志
def GetDroplog():
    if os.path.exists('/var/log/iptables.log'):
        filesize = os.path.getsize('/var/log/iptables.log')/(1024*1024)
        if filesize >= 200:
            cmd1= 'mv /var/log/iptables.log > /var/log/iptables.log.1 && > /var/log/iptables.log'
            cmd2= 'echo 0 > /var/log/.ipt_dropcount.txt'
            command(cmd1)
            command(cmd2)
        if not os.path.exists('/var/log/.ipt_dropcount.txt') or os.path.getsize('/var/log/.ipt_dropcount.txt') == 0:
            commands.getoutput("wc -l /var/log/iptables.log |awk '{print $1}' >/var/log/.ipt_dropcount.txt")
        else:
            newcount = int(commands.getoutput("wc -l /var/log/iptables.log |awk '{print $1}'"))
            oldcount = int(commands.getoutput("cat /var/log/.ipt_dropcount.txt"))
            commands.getoutput("wc -l /var/log/iptables.log |awk '{print $1}' >/var/log/.ipt_dropcount.txt")
            if oldcount < newcount:
                droplog = commands.getoutput("sed -n '{0},{1}p' /var/log/iptables.log".format(oldcount, newcount))
                return droplog

##跟据协议过滤出日志中某协议对应的条目
def Getdropitems(proto, log):
    droploglist = log.split('\n')
    protoitem = []
    for item in droploglist:
        if proto in item and "DPT=xxx" not in item and "DPT=xxx" not in item:
            protoitem.append(item)
    return protoitem

##获取条目中的ip列表，为后面判断是否在net_list做准备
def Getdropiplist(dropitems):
    dropiplist = []
    for item in dropitems:
        tmpitem = item.split("SRC=")
        tmpstr = tmpitem[1]
        dropip = tmpstr.split()[0]
        dropiplist.append(dropip)
    return dropiplist

##ip转数字
def Ip2Int(ip):
    return struct.unpack("!I", socket.inet_aton(ip))[0]

##数字转ip
def Int2Ip(i):
    return socket.inet_ntoa(struct.pack("!I", i))

##列表转字符串并去重
def list2str(droplist):
    list2set = list(set(droplist))
    str = ','.join(list2set)
    return str

def GetRole():
    if os.path.exists('/data/xxxx/serverinfo'):
        with open('/data/xxxx/serverinfo') as f:
            tmpstr = f.read()
            tmpdir = json.loads(tmpstr)
            return tmpdir['machine_type']
    else:
        return 'None'

def GetIptablesRole():
    cmd1 = '/sbin/iptables-save > /etc/iptables-rule'
    cmd2 = 'grep -wq \"^.*xxxxx.*$\" /etc/iptables-rule'
    command(cmd1)
    status = commands.getstatusoutput(cmd2)
    if status[0] == 0:
        return 'I'
    else:
        return 'O'
def Pcheck(pids):
    for pid in pids:
        with open('/proc/' + pid + '/cmdline') as f:
            command_content = f.read()
            if __file__ in command_content:
                os.kill(pid, signal.SIGKILL)

if __name__ == "__main__":

    lock_file = '/tmp/mon_iptables.lock'
    interval = 300
    ####防止进程不断拉起，控制单进程
    if os.path.exists(lock_file):
        file_time = os.path.getmtime(lock_file)
        now_time = time.time()
        time_diff = now_time - file_time
        with open(lock_file) as f:
            pid = int(f.read())
        if not os.path.exists('/proc/' + str(pid)):
            os.remove(lock_file)
            sys.exit()
        elif time_diff > interval:
            os.kill(pid, signal.SIGKILL)
            os.remove(lock_file)
            sys.exit()
        else:
            sys.exit()

    elif not os.path.exists(lock_file):
        proc = subprocess.Popen(['pidof', 'python'], stdout=subprocess.PIPE, shell=False)
        allpids = proc.stdout.read()
        if isinstance(allpids, bytes):
            pids = allpids.decode().split()
        else:
            pids = allpids.split()
        pids.remove(str(os.getpid()))
        Pcheck(pids)

        pid = os.getpid()
        fd = open(lock_file, 'w')
        fd.write(str(pid))
        fd.close()

    try:
       owniplist = GetOwnIplist()
       newdroplog = GetDroplog()
    # print newdroplog
    ###判断获取的日志是否为空
       if newdroplog == None:
          droptcp_allipcount = 0
          dropudp_allipcount = 0
          droptcp_ownipcount = 0
          dropudp_ownipcount = 0
          dropowntcp_str = ''
          dropownudp_str = ''
       else:
          tcp = "PROTO=TCP"
          udp = "PROTO=UDP"
          droptcpitems = Getdropitems(tcp, newdroplog)
          dropudpitems = Getdropitems(udp, newdroplog)
          drop_tcpiplist = Getdropiplist(droptcpitems)
          drop_udpiplist = Getdropiplist(dropudpitems)
          droptcp_allipcount = len(drop_tcpiplist)
          dropudp_allipcount = len(drop_udpiplist)
          dropowntcpiplist = [i for i in drop_tcpiplist if i in owniplist]
          dropownudpiplist = [i for i in drop_udpiplist if i in owniplist]
          droptcp_ownipcount = len(dropowntcpiplist)
          dropudp_ownipcount = len(dropownudpiplist)
          dropowntcp_str = list2str(dropowntcpiplist)
          dropownudp_str = list2str(dropownudpiplist)
       msg_tcp = "iptables DROP 自建机房ip:" + dropowntcp_str + "TCP包" + str(droptcp_ownipcount) + "个，请检查iptables是否正常！"
       msg_udp = "iptables DROP 自建机房ip:" + dropownudp_str + "UDP包" + str(dropudp_ownipcount) + "个，请检查iptables是否正常！"
       msg_all_i = "I角色机器 iptables 一分钟DROP包超过阈值，TCP包UDP包共计:" + str(droptcp_allipcount + dropudp_allipcount) + "个，请检查!"
       msg_all_o = "O角色机器 iptables 一分钟DROP包超过阀值，TCP包UDP包共计:" + str(droptcp_allipcount + dropudp_allipcount) + "个，请检查! "
       cmd1 = '/data/services/op_agent_d/tools/send_value \"fid=3884&value=' + str(droptcp_ownipcount) + '&info=' + msg_tcp + '\"'
       cmd2 = '/data/services/op_agent_d/tools/send_value \"fid=3885&value=' + str(dropudp_ownipcount) + '&info=' + msg_udp + '\"'
       cmd3 = '/data/services/op_agent_d/tools/send_value \"fid=3954&value=' + str(droptcp_allipcount + dropudp_allipcount) + '&info=' + msg_all_i + '\"'
       cmd4 = '/data/services/op_agent_d/tools/send_value \"fid=3883&value=' + str(droptcp_allipcount + dropudp_allipcount) + '&info=' + msg_all_o + '\"'
       command(cmd1)
       #print cmd1
       command(cmd2)
       #print cmd2
       ###根据不同的机器角色设置不同阀值，I角色机器drop超过3000个非自建机房的包时，才发送value，O角色一单有拒绝包就发送value
       machine_role = GetRole()
       iptables_role = GetIptablesRole()
       if machine_role == 'I':
          command(cmd3)
          #print cmd3
       if machine_role == 'O':
          command(cmd4)
          #print cmd4

       ###以下是机器角色匹配的监控，如果机器角色跟iptables不匹配就发送alarm
       msg_i = "iptables规则与机器角色不匹配，I角色机器对外开放，请检查LIMIT_ACCESS链是否存在，若存在，请检查这条链是否有drop条目！"
       msg_o = "iptables规则与机器角色不匹配，O角色机器没有对外开放，请检查!"
       cmd5 = '/data/services/op_agent_d/tools/send_alarm '
       cmd6 = '/data/services/op_agent_d/tools/send_alarm '
       cmd7 = '/data/services/op_agent_d/tools/send_alarm '
       if machine_role != iptables_role:
          if machine_role == 'I':
             command(cmd5)
             #print cmd5
          if machine_role == 'O':
             command(cmd6)
             #print cmd6
          if machine_role == 'None':
             command(cmd7)
             #print cmd7
       cmd8 = 'grep -wq \"^.*关键字.*DROP.*$\" /etc/iptables-rule'
       msg_n = "告警信息!"
       cmd9 = '/data/services/op_agent_d/tools/send_alarm ' + msg_n + '\"'
       status = commands.getstatusoutput(cmd8)
       if status[0] != 0:
          command(cmd9)
          #print cmd9
    finally:
       #time.sleep(60)
       os.remove(lock_file)
