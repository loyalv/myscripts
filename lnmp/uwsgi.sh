#/bin/bash
##################################################
#Name:        uwsgi.sh
#Version:     v2.0.14
#Create_Date: 2017-3-27
#Author:      GuoLikai(glk73748196@sina.com)
#Description: "Nginx模块uwsgi用于Django项目"
##################################################

App=uwsgi-2.0.14
AppName=uwsgi
AppOptBase=/App/opt/OPS
AppOptDir=$AppOptBase/$AppName
AppInstallBase=/App/install/OPS
AppInstallDir=$AppInstallBase/$App
AppConfDir=/App/conf/OPS/$AppName
AppLogDir=/App/log/OPS/$AppName
AppSrcBase=/App/src/OPS
AppTarBall=$App.tar.gz
AppBuildBase=/App/build/OPS
AppBuildDir=$(echo "$AppBuildBase/$AppTarBall" | sed -e 's/.tar.*$//' -e 's/^.\///')
AppProg=$AppOptDir/$AppName
AppConf=$AppName.ini


RemoveFlag=0
InstallFlag=0

# 获取PID
fpid()
{
    AppMasterPid=$(ps ax | grep "$AppName" | grep -v "grep" | awk '{print $1}' 2> /dev/null)
}

# 查询状态
fstatus()
{
    fpid

    if [ ! -f "$AppProg" ]; then
        echo "$AppName 未安装"
    else
        echo "$AppName 已安装"
        if [ -z "$AppMasterPid" ]; then
            echo "$AppName 未启动"
        else
            echo "$AppName 正在运行"
        fi
    fi
}

# 删除
fremove()
{
    fpid
    RemoveFlag=1

    #Day=$(date +%Y-%m-%d)
    #BackupFile=$AppName.$Day.yml.bak
    #if [ -f "$AppConfDir/$AppConfName" ]; then
    #	mv $AppConfDir/$AppConfName /App/conf/OPS/$BackupFile
    #   [ $? -eq 0 ] && echo "$AppConfName 删除时备份配置文件成功" || echo "$AppConfName 删除时备份配置文件失败"
    #fi

    if [ -z "$AppMasterPid" ]; then
        if [ -d "$AppInstallDir" ]; then
            rm -rf $AppInstallDir && echo "删除 $AppName"
            rm -rf $AppConfDir
            rm -rf $AppOptDir
            rm -rf $AppLogDir
        else
            echo "$AppName 未安装"
        fi
    else
        echo "$AppName 正在运行" && exit
    fi
}

# 备份
fbackup()
{
    Day=$(date +%Y-%m-%d)
    BackupFile=$AppName.$Day.tgz

    if [ -f "$AppProg" ]; then
        cd $AppInstallBase
        tar zcvf $BackupFile --exclude=logs/* $AppName/* --backup=numbered
        [ $? -eq 0 ] && echo "$AppName 备份成功" || echo "$AppName 备份失败"
    else
        echo "$AppName 未安装" 
    fi
}


# 安装
finstall()
{

    fpid
    InstallFlag=1

    if [ -z "$AppMasterPid" ]; then
        test -f "$AppProg" && echo "$AppName 已安装" 
        [ $? -ne 0 ] && fupdate && fsymlink && fcpconf 
    else
        echo "$AppName 正在运行"
    fi
}

# 更新
fupdate()
{
    Operate="更新"
    [ $InstallFlag -eq 1 ] && Operate="安装"
    [ $RemoveFlag -ne 1 ] && fbackup
#    yum -y install python-devel libxml2  libxml2-devel  python-setuptools  zlib-devel  openssl-devel pcre pcre-devel gcc make 
    yum -y install python-devel  gcc make 
#wget $AppSrcBase/uwsgi-2.0.14.tar.gz https://pypi.python.org/packages/11/ef/3d64655693e12f163f659bc3a45837893d7ebbb242e608feb9adc788d2ca/uwsgi-2.0.14.tar.gz
    test -d "$AppBuildDir" && rm -rf $AppBuildDir
    tar zxf $AppSrcBase/$AppTarBall -C $AppBuildBase || tar jxf $AppSrcBase/$AppTarBall -C $AppBuildBase
    cp -rp $AppBuildDir $AppInstallDir
	cd $AppInstallDir && make
    if [ $? -eq 0 ]; then
        echo "$AppName $Operate成功"
    else
        echo "$AppName $Operate失败"
        exit 1
    fi
}

#创建软连接
fsymlink()
{
    [ -L $AppOptDir ] && rm -f $AppOptDir
    [ -L $AppConfDir ] && rm -f $AppConfDir
    [ -L $AppLogDir ] && rm -f $AppLogDir

    ln -s $AppInstallDir  $AppOptDir
}

# 拷贝配置
fcpconf()
{ 
    mkdir -p $AppConfDir 
    mkdir -p $AppLogDir 
echo "[uwsgi]  
socket=127.0.0.1:6000  
master=true  
vhost=true  
#gid=nginx  
#uid=nginx  
workers=10  
max-requests=1000  
limit-as=512  
pidfile=${AppLogDir}/${AppName}.pid  
daemonize=${AppLogDir}/${AppName}.log" > $AppConfDir/$AppConf 
}


# 启动
fstart()
{
    fpid
    if [ -n "$AppMasterPid" ]; then
        echo "$AppName 正在运行"
    else
       	$AppProg --ini $AppConfDir/$AppConf  &>/dev/null && [ $? -eq 0 ] && echo "$AppName 启动成功" || echo "$AppName 启动失败"
    fi
} 

# 停止
fstop()
{
    fpid

    if [ -n "$AppMasterPid" ]; then
        kill -9 $AppMasterPid  &>/dev/null && echo "停止 $AppName" || echo "$AppName 停止失败"
    else
        echo "$AppName 未启动"
    fi
}

# 终止进程
fkill()
{
    fpid

    if [ -n "$AppMasterPid" ]; then
        echo "$AppMasterPid" | xargs kill -9 &>/dev/null
        if [ $? -eq 0 ]; then
            echo "终止 $AppName 主进程"
        else
            echo "终止 $AppName 主进程失败"
        fi
    else
        echo "$AppName 主进程未运行"
    fi
}

# 重启
frestart()
{
    fpid
    [ -n "$AppMasterPid" ] && fstop && sleep 1
    fstart
}

ScriptDir=$(cd $(dirname $0); pwd)
ScriptFile=$(basename $0)
case "$1" in
    "install"   ) finstall;;
    "update"    ) fupdate;;
    "reinstall" ) fremove && finstall;;
    "remove"    ) fremove;;
    "backup"    ) fbackup;;
#    "cpconf"    ) fcpconf;;
    "start"     ) fstart;;
    "stop"      ) fstop;;
    "status"    ) fstatus;;
    "restart"   ) frestart;;
    "kill"      ) fkill;;
    *           )
    echo "$ScriptFile install              安装 $AppName"
    echo "$ScriptFile update               更新 $AppName"
    echo "$ScriptFile reinstall            重装 $AppName"
    echo "$ScriptFile remove               删除 $AppName"
    echo "$ScriptFile backup               备份 $AppName"
    echo "$ScriptFile start                启动 $AppName"
    echo "$ScriptFile status               状态 $AppName"
    echo "$ScriptFile stop                 停止 $AppName"
    echo "$ScriptFile restart              重启 $AppName"
    echo "$ScriptFile kill                 终止 $AppName 进程"
    ;;
esac
