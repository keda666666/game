#!/bin/bash

PROJECT_PATH=$(cd `dirname $0`;pwd)
NAME_CONFIG="configure"
SERVER_CONFIG="configure.xml"
CENTER_CONFIG="configure_center.xml"
CROSS_CONFIG="configure_cross.xml"
PLAT_CONFIG="configure_plat.xml"
RECORD_CONFIG="configure_record.xml"

SERVER_LOG="lfile.log"
CENTER_LOG="lcenter.log"
CROSS_LOG="lcross.log"
PLAT_LOG="lplat.log"
RECORD_LOG="lrecord.log"

# CLIENT_CONFIG_FILE=$PROJECT_PATH/configure_client.xml
# MERGE_CONFIG_FILE=$PROJECT_PATH/configure_merge.xml

APP=$PROJECT_PATH/../libc++/App
SERVER_CONFIG_FILE=$PROJECT_PATH/${SERVER_CONFIG}
CENTER_CONFIG_FILE=$PROJECT_PATH/${CENTER_CONFIG}
CROSS_CONFIG_FILE=$PROJECT_PATH/${CROSS_CONFIG}
PLAT_CONFIG_FILE=$PROJECT_PATH/${PLAT_CONFIG}
RECORD_CONFIG_FILE=$PROJECT_PATH/${RECORD_CONFIG}

get_config() {
	case ${1} in
		game) NOW_CONFIG_FILE=${SERVER_CONFIG_FILE};;
		center) NOW_CONFIG_FILE=${CENTER_CONFIG_FILE};;
		cross) NOW_CONFIG_FILE=${CROSS_CONFIG_FILE};;
		plat) NOW_CONFIG_FILE=${PLAT_CONFIG_FILE};;
		record) NOW_CONFIG_FILE=${RECORD_CONFIG_FILE};;
	    *) help ;;
	esac
}

## 获取子shell命令
TARGET=$1
PARAM1=$2
PARAM2=$3
PARAM3=$4
## 帮助函数
help () {
    echo "gamectl 使用说明"
    echo "基本语法: gamectl [start|stop|restart|update] "
    echo "命令模块："
    echo "help                      显示当前帮助内容"

    echo "start                     启动游戏服务"
    echo "startbg                   后台运行游戏服务"
    echo "stop                      关闭游戏服务"
    echo "forcestop                 强制关闭游戏服务"
    echo "restart                   重新启动游戏服务"
    echo "update                    更新lua脚本"

    echo "startall                  开启所有服务"
    echo "startbase                 开启跨服逻辑相关服务"
    echo "stopall                   关闭所有服务"
    echo "updateall                 更新所有服务lua脚本"

    echo "center                    启动中心服务"
    echo "centerbg                  后台启动中心服务"
    echo "stopcenter                关闭中心服务"
    echo "updatecenter              启动中心服务lua脚本"

    echo "cross                     启动跨服服务"
    echo "crossbg                   后台启动跨服服务"
    echo "stopcross                 关闭跨服服务"
    echo "forcestopcross            强制关闭跨服服务"
    echo "updatecross               启动跨服服务lua脚本"

    # echo "record                  启动后台数据服务"
    # echo "plat                    启动平台登录服务"
    echo ""
    exit 0
}
## 确认函数
confirm() {
	echo "${1}""?(Yes/No): "
	if [ "${2}" == "Yes" ]; then
		echo "Yes(auto)"
		return 0
	fi
	read SELECT
	if [ "$SELECT" != "Yes" ]; then
	    exit 1
	fi
	return 0
}
## 设置数据库
get_sqlinfo() {
	ip=`grep "<cache" ${1} | gawk '{match($0, /ip[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
	port=`grep "<cache" ${1} | gawk '{match($0, /port[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
	dbname=`grep "<cache" ${1} | gawk '{match($0, /dbname[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
	user=`grep "<cache" ${1} | gawk '{match($0, /user[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
	pass=`grep "<cache" ${1} | gawk '{match($0, /pass[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
}
get_svrsqlinfo() {
	get_config ${1}
	get_sqlinfo ${NOW_CONFIG_FILE}
}
set_sqlinfo() {
	get_sqlinfo ${1}
	echo "create database if not exists \`${dbname}\` character set utf8mb4 COLLATE utf8mb4_bin;" \
		| mysql -u${user} -p${pass} -h${ip} -P${port}
}
reset_sqlinfo() {
	get_svrsqlinfo ${1}
	confirm "确认删除${1}数据库${dbname}" ${PARAM2}
	echo "drop database if exists \`${dbname}\`;" \
		| mysql -u${user} -p${pass} -h${ip} -P${port}
}
dump_sql() {
	get_svrsqlinfo ${1}
	mysqldump --opt -u${user} -p${pass} -h${ip} -P${port} ${dbname} | gzip > dbdump.sql.gz
}
backup_sql() {
	get_svrsqlinfo ${1}
	mkdir -p "/data"
	mysqldump --opt -u${user} -p${pass} -h${ip} -P${port} ${dbname} | gzip > "/data/"${dbname}_`date +%F_%H-%M`.sql.gz
}
recover_sql() {
	get_config ${1}
	set_sqlinfo ${NOW_CONFIG_FILE}
	confirm "确认还原数据库" ${PARAM3}
	gunzip < "${2}" | mysql -u${user} -p${pass} -h${ip} -P${port} ${dbname}
}
## 启动
start() {
	set_sqlinfo ${1}
	if [ ${2} ]; then	# 后台启动
		nohup $APP -configure=${1} > ${2} 2>&1 &
	else				# 前台启动
    	$APP -configure=${1}
	fi
}
## 热更
update() {
	tar=$PROJECT_PATH
	for pid in `pgrep App`;
	do
		ttt=$(ps -ef | grep $pid | grep -v grep)
		if [[ ${ttt} == *$tar* ]] && [[ ${ttt} == *"${1}"* ]]
		then
			ttt=${ttt##*libc++/App -configure=}
			echo update ${ttt%%.xml*}".xml" $pid
			kill -s 12 $pid
			sleep 1
		else
			continue
		fi
	done
#    ps -ef | grep App |grep -v grep | awk '{print $2}' | xargs kill -s 12
}
stop() {
	killtype=10
	if [ ${2} ]; then
		killtype=${2}
	fi
	#kill -s 10 `ps -aux | grep App | grep -v grep | awk '{print $2}'`
	tar=$PROJECT_PATH
	count=0
	while true
	do
		exist=0
		for pid in `pgrep App`;
		do
			ttt=$(ps -ef | grep $pid | grep -v grep)
			if [[ ${ttt} == *${tar}* ]] && [[ ${ttt} == *"${1}"* ]]
			then
				exist=1
				break
			fi
		done
		if [[ $exist -eq 0 ]]
		then
			break
		fi
		let count++
		if [ ${PARAM1} ] && [ ${count} -gt ${PARAM1} ]; then
			echo ${TARGET} "failed: count out" ${PARAM1}
			exit 1
		fi
		for pid in `pgrep App`;
		do
			ttt=$(ps -ef | grep $pid | grep -v grep)
			if [[ ${ttt} == *${tar}* ]] && [[ ${ttt} == *"${1}"* ]]
			then
				ttt=${ttt##*libc++/App -configure=}
				echo killing ${ttt%%.xml*}".xml" $pid
				kill -s ${killtype} $pid
				sleep 1
			else
				continue
			fi
		done
	done
}

# ## 启动客户端
# start_client()
# {
#     $APP -debug -nocheck -a -configure=${CLIENT_CONFIG_FILE}
# }
# start_merge()
# {
# 	ip=`grep "<cache" ${MERGE_CONFIG_FILE} | gawk '{match($0, /ip[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
# 	port=`grep "<cache" ${MERGE_CONFIG_FILE} | gawk '{match($0, /port[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
# 	dbname=`grep "<cache" ${MERGE_CONFIG_FILE} | gawk '{match($0, /dbname[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
# 	user=`grep "<cache" ${MERGE_CONFIG_FILE} | gawk '{match($0, /user[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
# 	pass=`grep "<cache" ${MERGE_CONFIG_FILE} | gawk '{match($0, /pass[ \t]*=[ \t]*"([^ \t]*)"/, data); print data[1]}'`
# 	echo "create database if not exists ${dbname} character set utf8mb4 COLLATE utf8mb4_bin;" \
# 		| mysql -u${user} -p${pass} -h${ip} -P${port}
#     $APP -configure=${MERGE_CONFIG_FILE} -plat=$1
# }
case $TARGET in
	dropsql)		reset_sqlinfo "game";;
	dump)			dump_sql ${PARAM1};;
	reset)			reset_sqlinfo ${PARAM1};;
	backup)			backup_sql ${PARAM1};;
	recover)		recover_sql ${PARAM1} ${PARAM2};;

    start)			start ${SERVER_CONFIG_FILE};;
    startbg)		start ${SERVER_CONFIG_FILE} ${SERVER_LOG};;
    gamebg)			start ${SERVER_CONFIG_FILE} ${SERVER_LOG};;
    stop)			stop ${SERVER_CONFIG};;
    forcestop)		stop ${SERVER_CONFIG} 9;;
	restart)		stop ${SERVER_CONFIG};start ${SERVER_CONFIG_FILE} ${SERVER_LOG};;
    update)			update ${SERVER_CONFIG};;

	dropsqlbase)	reset_sqlinfo "game"
					reset_sqlinfo "cross"
					reset_sqlinfo "center";;
	startbase)		start ${CENTER_CONFIG_FILE} ${CENTER_LOG}
					start ${CROSS_CONFIG_FILE} ${CROSS_LOG}
					start ${SERVER_CONFIG_FILE} ${SERVER_LOG};;
	restartbase)	stop ${SERVER_CONFIG}
					stop ${CROSS_CONFIG}
					stop ${CENTER_CONFIG}
					start ${CENTER_CONFIG_FILE} ${CENTER_LOG}
					start ${CROSS_CONFIG_FILE} ${CROSS_LOG}
					start ${SERVER_CONFIG_FILE} ${SERVER_LOG};;
    stopbase)		stop ${SERVER_CONFIG}
					stop ${CROSS_CONFIG}
					stop ${CENTER_CONFIG};;
	forcestopbase)	stop ${SERVER_CONFIG} 9
					stop ${CROSS_CONFIG} 9
					stop ${CENTER_CONFIG} 9;;
    updatebase)		update ${CROSS_CONFIG}
					update ${SERVER_CONFIG}
					update ${CENTER_CONFIG};;

	dropsqlall)		reset_sqlinfo "game"
					reset_sqlinfo "cross"
					reset_sqlinfo "center"
					reset_sqlinfo "plat"
					reset_sqlinfo "record";;
	startall)		start ${CENTER_CONFIG_FILE} ${CENTER_LOG}
					start ${CROSS_CONFIG_FILE} ${CROSS_LOG}
					start ${SERVER_CONFIG_FILE} ${SERVER_LOG}
					start ${PLAT_CONFIG_FILE} ${PLAT_LOG}
					start ${RECORD_CONFIG_FILE} ${RECORD_LOG};;
	restartall)		stop ${NAME_CONFIG}
					start ${CENTER_CONFIG_FILE} ${CENTER_LOG}
					start ${CROSS_CONFIG_FILE} ${CROSS_LOG}
					start ${SERVER_CONFIG_FILE} ${SERVER_LOG}
					start ${PLAT_CONFIG_FILE} ${PLAT_LOG}
					start ${RECORD_CONFIG_FILE} ${RECORD_LOG};;
    stopall)		stop ${NAME_CONFIG};;
	forcestopall)	stop ${NAME_CONFIG} 9;;
    updateall)		update ${NAME_CONFIG};;

    center)			start ${CENTER_CONFIG_FILE};;
    centerbg)		start ${CENTER_CONFIG_FILE} ${CENTER_LOG};;
    stopcenter)		stop ${CENTER_CONFIG};;
    forcestopcenter)stop ${CENTER_CONFIG} 9;;
	updatecenter)	update ${CENTER_CONFIG};;

    cross)			start ${CROSS_CONFIG_FILE};;
    crossbg)		start ${CROSS_CONFIG_FILE} ${CROSS_LOG};;
    stopcross)		stop ${CROSS_CONFIG};;
    forcestopcross)	stop ${CROSS_CONFIG} 9;;
	updatecross)	update ${CROSS_CONFIG};;

    plat)			start ${PLAT_CONFIG_FILE};;
    platbg)			start ${PLAT_CONFIG_FILE} ${PLAT_LOG};;
    stopplat)		stop ${PLAT_CONFIG};;
    forcestopplat)	stop ${PLAT_CONFIG} 9;;
	updateplat)		update ${PLAT_CONFIG};;

    record)			start ${RECORD_CONFIG_FILE};;
    recordbg)		start ${RECORD_CONFIG_FILE} ${RECORD_LOG};;
    stoprecord)		stop ${RECORD_CONFIG};;
    forcestoprecord)stop ${RECORD_CONFIG} 9;;
	updaterecord)	update ${RECORD_CONFIG};;

    # client) start_client;;
    # merge) start_merge $*;;
    *) help ;;
esac
