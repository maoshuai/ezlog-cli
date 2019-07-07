

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
# 第一参数传递日志一行的长度限制
lineLenght=$1
# 第二个开始，都是要搜索的文件名
shift
logName=$*

# 用来识别logback日志开头
LOG_TITLE_PATTERN="^(19|20)[0-9]{2}\-[0-1][0-9]\-[0-3][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9],[0-9]{3} \["

# 默认是不压缩的日志
if [ x$_IS_LOG_ZIPPED = x ];then
	_IS_LOG_ZIPPED=0
fi

# Linux版本的awk需要增加 --re-interval选项，才支持正则的次数匹配
osName=`uname` &>/dev/null
if [ "$osName" = "Linux" ]; then
	
	

	awk --re-interval '
	BEGIN{
		isNewLineBegin = "yes" # 初始化为新的一行开始
		MAX_LENGTH = '"$lineLenght"' #一行的对的最大字符数
		leftLength = MAX_LENGTH # 初始化时，剩余字符数就是最大字符数
	}

	# 匹配
	{
		
		if($0~/'"$LOG_TITLE_PATTERN"'/) # 是否开启了别的日志线程
		{
			leftLength=MAX_LENGTH
		}
		if (leftLength >0)
		{
			currentLineLength=length($0) # 当前行的长度
			
			if(leftLength - currentLineLength >=0)
				{
					print $0
				}
			else
				{
					print substr($0, 1, leftLength), " [...log omitted]"
				}
			leftLength = leftLength - currentLineLength # 更新剩余字符额度
		}

		
		
	}
	' $logName



else



	awk '
	BEGIN{
		isNewLineBegin = "yes" # 初始化为新的一行开始
		MAX_LENGTH = '"$lineLenght"' #一行的对的最大字符数
		leftLength = MAX_LENGTH # 初始化时，剩余字符数就是最大字符数
	}

	# 匹配
	{
		
		if($0~/'"$LOG_TITLE_PATTERN"'/) # 是否开启了别的日志线程
		{
			leftLength=MAX_LENGTH
		}
		if (leftLength >0)
		{
			currentLineLength=length($0) # 当前行的长度
			
			if(leftLength - currentLineLength >=0)
				{
					print $0
				}
			else
				{
					print substr($0, 1, leftLength), " [...log omitted]"
				}
			leftLength = leftLength - currentLineLength # 更新剩余字符额度
		}

		
		
	}
	' $logName


fi





