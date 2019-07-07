###########
# 根据关键词排除逻辑上是一行的日志。与fullgrep.sh功能正好相反。建议后期重构代码的时候将两个shell合并
# author maoshuai
# date 2015-11-06
# version 0.0.1.snapshot
###########

if [ $# -lt 2 ];then
	echo "need 2 or more params"
	exit 1
fi
# 第一参数传递日志线程号
threadId="$1"
# 第二个开始，都是要搜索的文件名
shift
logName=$*

# 用来识别logback日志开头
LOG_TITLE_PATTERN="^(19|20)[0-9]{2}\-[0-1][0-9]\-[0-3][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9],[0-9]{3} \["


# Linux版本的awk需要增加 --re-interval选项，才支持正则的次数匹配
osName=`uname` &>/dev/null
if [ "$osName" = "Linux" ]; then

	awk --re-interval '
	BEGIN{
		isInThread = "no"
	}

	# 匹配thread
	{
		if($0~/'"$threadId"'/) # 判断是否在当前日志线程
		{
			isInThread="yes"
		}
		else if($0~/'"$LOG_TITLE_PATTERN"'/) # 是否开启了别的日志线程
		{
			isInThread="no"
		}
		if(isInThread=="no") #如果没有，那么就接着将日志打出
		{
			print $0
		}	
	}
	' $logName
	


else


	

	awk '
	BEGIN{
		isInThread = "no"
	}

	# 匹配thread
	{
		
		if($0~/'"$threadId"'/) # 判断是否在当前日志线程
		{
			isInThread="yes"
		}
		else if($0~/'"$LOG_TITLE_PATTERN"'/) # 是否开启了别的日志线程
		{
			isInThread="no"
		}
		if(isInThread=="no") #如果没有，那么就接着将日志打出
		{
			print $0
		}	
		# print isInThread, NR
	}
	' $logName


fi





