服务器资源管理：
1、建立完整的CMDB系统；
功能：
a、录入服务器信息，包括ip、SN、机房、业务模块、服务器状态、机器型号、配置、系统版本、机器负责人，机器上进程负责人等
b、服务器权限管理，通过跳板机ssh密钥认证，禁止掉密码登录，业务人员申请服务器权限后，后台自动执行授权脚本开通权限
c、提供各种api接口，方便通过调用api接口获取服务器信息

2、建立itil流程系统
功能：
a、创建重启，关机，重装，回收，报修等流程，通过不同服务器厂商提供的带外工具，集成到系统中，实现自动重启，关机，重装流程，如果该流程失败，通过邮件方式发送给代维人员安排操作
b、服务器自动报修功能，通过硬件监控脚本，当监控到硬件错误时，通过itil系统报修api接口自动实现报修，通过cmdbapi实现通知相应机器负责人和进程负责人

服务器系统管理：
1、同一应用机器使用同一种版本系统，比如数据库只使用centos
2、系统初始化，针对不同业务需求定制不同的系统初始化版本，做到服务器装完系统后，直接跑初始化就可以交付使用；
3、系统脚本管理，通过服务器上定时任务检查更新自动拉取svn或者git仓库脚本
4、日志管理，规定日志存放路径和格式，通过logrotate实现定期轮询切割
5、配置管理

服务器监控管理：
1、部署监控agent
2、编写服务器监控脚本，采取负载、io、cpu、内存、磁盘、网卡、等各项指标，并通过agent上报到监控系统
3、监控系统通过每分钟收集到的数据绘制出历史监控曲线
4、跟进业务模块，机器ip，机房等多维度定义监控策略，当触发监控策略时产生告警，发送告警给相应负责人或者调用自动拨号通知负责人

###由于时间关系，以及问题涉及到的内容比较多，上面文件夹中放了部分脚本
###由于安全问题，只是大概的描述了一下
###还有很多内容没有详细描述








