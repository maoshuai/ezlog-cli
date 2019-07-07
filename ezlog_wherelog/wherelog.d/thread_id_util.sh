#############################
# 处理BITS日志线程号的相关util
# --author maoshuai
# --date 2015-06-09
#
#############################


. $deployDir/common.d/logUtil.sh

# 根据结束时间，推算开始时间的宽宥，单位是ms
THREAD_ELAPSE_GRACE=1
# 交易码和交易名称的映射关系
AP_FUNC_MAPPING=$deployDir/wherelog.d/AP_FUNC.txt
# 
CACHE_DIR=$WHERELOG_HOME/.cache




# 解析线程号的类型
# 1-4共四种类型
# -1代表不合法的线程号
function parseThreadId
{
	
	if [ $# -ne 1 ];then
		throw "Need 1 param"
	fi

	local threadId=$1

	# 类型1： 6位数字型随机数线程号，比如：550576
	local flag=`awk_reg_test $threadId "^[0-9]{6}$"` 
	if [ $flag -eq 1 ];then
		echo 1
		return 
	fi
	
	# 类型2：最多17位，以日期型：20150609133829415
	flag=`awk_reg_test $threadId "^(19|20)[0-9]{2}[0-1]{1}[0-9]{1}[0-3][0-9]{0,11}$"`
	if [ $flag -eq 1 ];then
		echo 2
		return
	fi
	
	# 类型3： 最多17位日期+6为随机数： 20150609133829415.550576
	flag=`awk_reg_test $threadId "^(19|20)[0-9]{2}[0-1]{1}[0-9]{1}[0-3][0-9]{0,11}\.[0-9]{6}$"`
	if [ $flag -eq 1 ];then
		echo 3
		return
	fi

	# 类型4：完整线程号：4433802-20150609133829415.550576
	flag=`awk_reg_test $threadId "^([0-9]{7}|nologin)\-(19|20)[0-9]{2}[0-1]{1}[0-9]{1}[0-3][0-9]{0,11}\.[0-9]{6}$"`
	if [ $flag -eq 1 ];then
		echo 4
		return
	fi

	# 类型5：7位柜员+最多17位日期：4433802-20150609133829415
	flag=`awk_reg_test $threadId "^([0-9]{7}|nologin)\-(19|20)[0-9]{2}[0-1]{1}[0-9]{1}[0-3][0-9]{0,11}$"`
	if [ $flag -eq 1 ];then
		echo 5
		return
	fi


	# 类型21：业务编号 LCZC443201500154
	flag=`awk_reg_test $threadId "^[A-Z]{2}[A-Z0-9]{2}[0-9]{12}$"`
	if [ $flag -eq 1 ];then
		echo 21
		return
	fi


	# 类型22：EVENT_NO
	# 36f70da4f649c93a0007 或IBP开头的移植数据IBPLCZC0282013007080
	flag=`awk_reg_test $threadId "^([0-9a-z]{20}|IBP[A-Z]{2}[A-Z0-9]{2}[0-9]{12,})$"`
	if [ $flag -eq 1 ];then
		echo 22
		return
	fi

	# 类型23：柜员号	
	flag=`awk_reg_test $threadId "^([0-9]{7}|nologin)$"`
	if [ $flag -eq 1 ];then
		echo 23
		return
	fi


	echo -1
	return


}


# 从线程号的字面值获取线程的日期
function getDateFromThreadId
{
	if [ $# -ne 1 ];then
		throw "Need 1 param"
	fi

	threadId=$1
	threadType=`parseThreadId $threadId`

	
	
	# 类型1，则就认为是当天的日志
	if [ $threadIdType -eq 1 ];then
		echo `date +"%Y%m%d"`
		return
	fi

	if [  $threadType -eq 2  ];then
		echo $threadId |  cut -c 1-8 
		return
	fi

	if [  $threadType -eq 3  ];then
		echo $threadId |  cut -c 1-8 
		return
	fi 

	if [  $threadType -eq 4 -o $threadType -eq 5 ];then
		echo $threadId |  cut -c 9-16 
		return
	fi 
}


#判断是否当天的日志线程，如果是的话，返回1
# 参数：线程号
function isTodayLog
{
	logThread=$1
	logThreadDate=`getDateFromThreadId  $logThread`
	today=`date +"%Y%m%d"`
	if [ x$today = x$logThreadDate ];then
		echo 1 # 是今天的日志
	else
		echo 0
	fi
}


# 判断日志是否被压缩了，压缩和不压缩的日志处理有区别
# 判断的依据就是根据日期看，是否有.zip结尾的日志目录
# 是压缩日志，则返回1，否则返回0
# 传入的参数是线程号、日志根目录
isLogZipped()
{
	logThread=$1
	logThreadDate=`getDateFromThreadId  $logThread`

	bits_logs_dir=$2

	zipDir=$bits_logs_dir/${logThreadDate}.zip

	if [ -d $zipDir ];then
		echo 1
	else
		echo 0
	fi

}


# 返回一个文件的修改时间，格式如：10:55:21
# TODO 能否加上缓存，stat的代价太高
# 兼容AIX和linux以及mac os
getLogModifyTime()
{
	# 这个地方避免因为系统语言不同导致的bug，统一要求在英文环境处理
	old_LC_ALL=$LC_ALL
	LC_ALL=en_US
	local fileNameToGetModifyDate=$1
	local osname=`uname`
	if [ "x"$osname = x"AIX" ];then
		istat $fileNameToGetModifyDate | grep "Last modified" | awk '{print $6}'
	elif [ "x"$osname = x"Linux" ];then
		stat $fileNameToGetModifyDate | grep "Modify" |  awk -F "[ .]" '{print $3}'
	elif [ "x"$osname = x"Darwin" ];then
		istat $fileNameToGetModifyDate | grep "Last modified" | awk '{print $6}'
	else
		LC_ALL=$old_LC_ALL # 还原语言
		throw "Unspported OS: $osname"
	fi
	LC_ALL=$old_LC_ALL # 还原语言
}




# 根据时间戳，判断可能存在该线程号的日志
fetchCandidateLog()
{
	log_pattern=$1
	
	transTimeLog=`echo $* | awk '{$1=null;print $0}'`

	# 拿到完整的threadId
	fullThreadId=`getFullThreadFromTransTimelog $transTimeLog `
	# 拿到交易的耗时（毫秒）
	threadElapseMilSec=`echo $transTimeLog |  awk -F[ '{print $4}' | awk '{print $4}'`
	# 算出秒数，先上取整。因为实际耗时是要比记录的长，所以向上取整是合理的，同时加上一个宽限，已充分长的时间确保，这个时间肯定是比交易的开始时间早
	let "threadElapseSecond=threadElapseMilSec/1000+THREAD_ELAPSE_GRACE"

	# 获取日志时间（即结束时间)
	threadTime=`echo "$transTimeLog" | awk '{print $2}' | awk -F, '{print $1}'`

	# 交易的开始时间
	threadBeginTime=`subTime $threadTime $threadElapseSecond`

	threadDate=`getDateFromThreadId $fullThreadId`

	lsString="$BITS_LOGS_HOME/$threadDate/${log_pattern}*"
	isTodayLogFlag=`isTodayLog $fullThreadId`

	# 列出所有可能的日志文件
	if [ $isTodayLogFlag -eq 1 ];then
		ALL_BITS_LOG=`ls $BITS_LOGS_HOME/$threadDate/${log_pattern}* 2>/dev/null` 
	elif  [ $_IS_LOG_ZIPPED -eq 1 ];then
		ALL_BITS_LOG=`ls $BITS_LOGS_HOME/${threadDate}.zip/${log_pattern}* 2>/dev/null` 
	else
		ALL_BITS_LOG=`ls $BITS_LOGS_HOME/$threadDate/${log_pattern}* 2>/dev/null` 
	fi
	
	# 没找到该模式的文件，则跳过
	if [ "x" = "x$ALL_BITS_LOG" ];then
		logDebug "date log dir is empty"
	fi

	
	# 将要搜索的日期混入列表进行排序
	(echo $threadTime "00000000000000000002" 
		echo $threadBeginTime "00000000000000000001" # 标记日志开始时间
	for fileName in $ALL_BITS_LOG;do  # fileName like /home/bitsadm/bits_logs/BITS_LOG.txt
		echo `getLogModifyTime $fileName` $fileName  # get lastModified time:　11:11:17
	done) | sort -nk 1 | # we get list like this:
	# 13:15:59 /home/bitsadm/bits_logs/20150602/BITS_LOG.txt.3 -- 			foundBegin=no foundEnd=no 
	# 13:20:00 00000000000000000001    ----这里是打日志的开始时间 -- 			foundBegin=yes foundEnd=no
	# 13:20:02 /home/bitsadm/bits_logs/20150602/BITS_LOG.txt.4 --目标潜在日志 foundBegin=yes foundEnd=no 
	# 13:23:01 00000000000000000002    ----这里是打日志的结束时间 -- 			foundBegin=no foundEnd=yes
	# 13:23:50 /home/bitsadm/bits_logs/20150602/BITS_LOG.txt.5 --目标潜在日志 foundBegin=no foundEnd=no
	# 13:37:48 /home/bitsadm/bits_logs/20150602/BITS_LOG.txt.6

	# 找到修改日期第一大于或等于threadTime的文件
	# 13:23:50 /home/bitsadm/bits_logs/20150602/BITS_LOG.txt.5
	awk '
	BEGIN{foundEnd="no"
			foundBegin="no"
		}
	 foundBegin=="yes"||foundEnd=="yes"{
	 	print $0;
	 	foundEnd="no"
	}
	 /00000000000000000001/{foundBegin="yes"}
	 /00000000000000000002/{foundEnd="yes";foundBegin="no"} ' |

	 grep -v "00000000000000000002" | # 00000000000000000002 会被包含进来

	# 拿出第一列之后的路径名
	# /home/bitsadm/bits_logs/20150602/BITS_LOG.txt.5
	awk '{x=2;while(x<=NF){printf "%s ", $x;x++;}printf "\n"}'


	echo `ls $BITS_LOGS_HOME/${log_pattern}* 2>/dev/null` # 始终让当天的日志文件参与
	

	# 上面都是潜在的，但并不代表一定有
	# echo $candidateFileList、
	

}



# 从一行transTime日志，获取完整的thread id
getFullThreadFromTransTimelog()
{
	transTimeLog="$*"

	# 拿到完整的threadId
	echo $transTimeLog | awk -F[ '{print $3}'  | awk '{print $1}'
}

# 从一行transTime日志，获取process名
getProcessNameFromTimelog()
{
	transTimeLog="$*"
	echo $transTimeLog | awk -F"[][]" '{print $4}' | awk '{print $2}'
}

# 从一行transTime日志，获取交易耗时
getProcessTimeUsingFromTimelog()
{
	transTimeLog="$*"
	echo $transTimeLog | awk -F"[][]" '{print $7}' | awk '{print $3}'
}

# 从一行transTime日志，获取交易时间
getProcessEndTimeFromTimelog()
{
	transTimeLog="$*"
	echo $transTimeLog | awk '{print $1, $2}'
}

# 从一行transTime日志，获取交易码
getProcessTranCodeFromTimelog()
{
	transTimeLog="$*"
	echo $transTimeLog | awk -F"[][]" '{print $7}' | awk '{print $4}'
}


# 从一行transTime日志，获取BUSINESS_ID
getProcessBusinessIdFromTimelog()
{
	transTimeLog="$*"
	echo $transTimeLog | awk -F"[][]" '{print $7}' | awk '{print $5}'
}

# 从一行transTime日志，获取BUSINESS_ID
getProcessEventNoFromTimelog()
{
	transTimeLog="$*"
	echo $transTimeLog | awk -F"[][]" '{print $7}' | awk '{print $6}'
}

# 从一行transTime日志，获取交易名
getProcessTranNameFromTimelog()
{
	transTimeLog="$*"
	tranCode=`getProcessTranCodeFromTimelog $transTimeLog`
	grep $tranCode $AP_FUNC_MAPPING | awk '{print $2}'
}

logCounter()
{
	echo "$*" | grep -q '\-s' # 带有-s参数，说明是静默模式，不做下面的处理
	if [ $? -ne 0 ];then
		local clientIp=`who am i 2>/dev/null | awk '{print $NF}'` 
		if [ x$clientIp = "x" ];then
			clientIp="(000.000.000.000)" # 没ip
		fi
		echo `date +%Y-%m-%d\ %H:%M:%S ` $clientIp `pwd` " $*" >> ~/.wherelog
		local count=`wc -l ~/.wherelog| awk '{print $1}'`
		let "remain=count%1987"
		# remain=0
		if [ $remain -eq 0 ];then
			myEcho " ╭══╮  ┌═════════┐ ┌══════════┐ ┌═════════┐"

				myEcho "╭╯╭　║═║ wherelog║═║  Bonus   ║═║   ^_^   ║"

			myEcho "╰⊙═⊙╯  └⊙═⊙═⊙═⊙═⊙..└⊙═⊙═⊙═⊙══~..└⊙═⊙═⊙═⊙~~"
			exit 1
		fi
	fi
	
}

# 近似的对一个时刻进行减法处理
# 不考虑减法溢出的情况
subTime()
{
	if [ $# -ne 2 ];then
		throw "need 2 param"
	fi
	oriTime=$1 # 比如13:20:02
	second=$2 # 比如2

	hour=`echo $oriTime | awk -F ":" '{print $1}'`
	min=`echo $oriTime | awk -F ":" '{print $2}'`
	sec=`echo $oriTime | awk -F ":" '{print $3}'`
	hour=${hour#0}
	min=${min#0}
	sec=${sec#0}


	# 时间先转成秒
	
	let "timeSeconds=hour*3600+min*60+sec"
	let "newTimeSeconds=timeSeconds-second"

	# 秒转换成时间
	let "newHour=newTimeSeconds/3600"
	let "remain=newTimeSeconds%3600"
	let "newMin=remain/60"
	let "newSec=remain%60"

	if [ $newHour -lt 10 ];then
		newHour="0"$newHour
	fi
	if [ $newMin -lt 10 ];then
		newMin="0"$newMin
	fi
	if [ $newSec -lt 10 ];then
		newSec="0"$newSec
	fi

	
	
	echo "$newHour:$newMin:$newSec"

}




printReportMessage()
{
	myEcho "$*" 
	echo "$*" >> $threadLogDir/.report.txt
}



