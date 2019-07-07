# wherelog对外暴露的接口
# wherelog_api.sh是仅次于wherelog的对外接口，可以直接被调用。
# wherelog_api.sh的参数更丰富，更灵活；wherelog是用户直接使用的shell

############################## 1.0 环境配置
. $EZLOG_HOME/ezlog_wherelog/wherelog.d/ezlog_wherelog_init.source
. $EZLOG_WHERELOG_HOME/wherelog.d/wherelog_core.source # wherelog核心



# 入口函数
wherelog_api_main()
{

	# optionHandler插件是否加载，默认是不加载；如果插件目录下有插件文件则尝试加载
	local _optionHandler_is_loaded="false"

	# 如果加载了optionHeandler插件，则将控制权交由otionHandler，否则调用默认的optionHandelr
	local optionHandlerPlugin="$EZLOG_PROFILE_HOME/ezlog_wherelog/plugins/optionHandler/optionHandler.source"
	if [ -e "$optionHandlerPlugin" ];then
		. $optionHandlerPlugin
		_optionHandler_is_loaded="true" # 设置为插件已加载状态
	else
		logDebug "plugin not exsist: $optionHandlerPlugin"
	fi


	logDebug "wherelog_api_args, $#: $*"

	_usingCache="true" # 是否使用上次结果的缓存，可以通过-C选项进行关闭
	_baseDir="" # wherelog的产出目录
	local _keywordIndex=""
	local _isShowVersion="false"
	local _showLatestHistory="false" # 显示wherelog的最近记录
	local _silentMode="false" # 静默模式，去除一些需要用户交互的东西，便于后台运行

	local _formatLog="true" # 是否格式化日志

	# 解析参数
	if [ `get_os_type` != "HP-UX" ];then # hp-ux 不能unset
		unset OPTIND
	fi

	while getopts "vCk:d:lsF" arg
	do
		logDebug "getopts $arg"
		case $arg in 
			v)  # 显示版本号信息
				_isShowVersion="true"
				
			;;
			l)
				_showLatestHistory="true"
			;;
			s)
				_silentMode="true"
			;;
			C)
				_usingCache="false"
			;;
			
			k)  # 根据keyword进行搜索
				_keywordIndex=$OPTARG
				logDebug "get _keyWordIndex: $_keywordIndex"
				
			;;
			d)  # 根据keyword进行搜索
				_baseDir=$OPTARG
				logDebug "get _baseDir: $_baseDir"
				
			;;
			F)
				_formatLog="false"
			;;
			?)
				handle_option_error
				throw 
			;;
		esac

	done





	logDebug "wherelog_api_main option, after getopts: $*"
	shift $(($OPTIND - 1))
	logDebug "wherelog_api_main option, after shift: $*"

	# 首先处理几种特殊选项

	# 仅打印版本号
	logDebug "_isShowVersion=$_isShowVersion"
	if [ x"$_isShowVersion" = x"true" ];then
		handle_option_v
		return
	fi

	# 列出历史
	if [ x"$_showLatestHistory" = x"true" ];then
		handle_option_l
		return
	fi


	# 下面是处理输入keyword的情况

	_keyword="$1"
	if [ x"$_keyword" = x"" ];then
		myEchoError "Please input keyword."
		handle_option_error
		exit 1
	fi

	# 如果没有输入keywordIndex，并且加载了optionHandler插件，则试图从插件，根据keyword本身解析keywordIndex
	# 通过keyword本身确定一些信息
	if [ x$_keywordIndex = x"" -a x"$_optionHandler_is_loaded" = x"true" ];then
		_keywordIndex=`getKeywordIndexFromKeyword $_keyword`
	fi

	if [ x"$_keywordIndex" = x"" ];then
		myEchoError "keyword index is not set, please use -k option."
		handle_option_error
		exit 1
	fi

	# 如果没有输入日期范围
	# 根据keyword本身获取日期信息
	local tempDateFrom=$2
	if [ x$tempDateFrom = x"" -a x"$_optionHandler_is_loaded" = x"true" ];then
		local _dateFrom=`getKeywordDateFromKeyword $_keyword`
	fi

	local _handelKeyParams="$_keywordIndex $@  $_dateFrom"
	handle_option_k $_handelKeyParams

}


handle_option_error()
{
	if [ x"$_optionHandler_is_loaded" = x"true" ];then
		print_wherelog_usage
	else
		_default_print_wherelog_usage
	fi
}



# TODO
handle_option_l()
{
	echo "Not done yet"
}



# 默认的wherelog使用帮助提示，在程序报错的时候提示
_default_print_wherelog_usage()
{
	myEcho "tos show correct wherelog usage, please implements in plugin optionHandler"
}



# wherelog API
# 处理v选项，显示版本号
# 参数：无
handle_option_v()
{
	wherelog_get_verison
}


# 处理key选项
# 参数1：keWordIndex 搜索的关键词序号
# 参数2：keyWord 搜索的关键词内容
# 参数3：dateFrom 限定的起始日，如果没有输入，则默认当前系统日期
# 参数4：dateTo 限定的结束日，如果没有输入，则默认与DateTo相同
handle_option_k()
{
	logDebug "handle_option_k params: $*"
	#--------
	# 1. 处理参数
	#--------
	if [ $# -lt 2 -o $# -gt 4 ];then
		throw "Params Error! wherelog_api.sh need 2~4 params: $*"
	fi

	local keyWordIndex="$1"
	local keyWord="$2"
	local dateFrom=""
	local dateTo=""

	# 没有指定日期
	if [ $# -eq 2 ];then
		dateFrom=`getCurrentDate` # 当前日期
		dateTo=$dateFrom
	# 指定一个日期
	elif [ $# -eq 3 ];then
		dateFrom=$3
		dateTo=$dateFrom

	# 指定起始日期
	elif [ $# -eq 4 ];then
		dateFrom=$3
		dateTo=$4
	fi

	# 关键字列号必须是数字
	flag=`regex_test $keyWordIndex "^[0-9]+"`
	if [ $flag -ne 1 ];then
		throw "param '$keyWordIndex' is not a number"
	fi

	# 输入的日期，可以是后半部分，会根据当前日期自动补全，比如今天如果是20160802，那么输入07，则代表20160807
	local tempFullDateFrom=`autoCompleteDateByCurrentDate $dateFrom`
	if [ x"$tempFullDateFrom" != x"-1" ];then # 补全没有出错的话，替换原来用户输入的日期
		dateFrom=$tempFullDateFrom
	fi
	local tempFullDateTo=`autoCompleteDateByCurrentDate $dateTo`
	if [ x"$tempFullDateTo" != x"-1" ];then  # 补全没有出错的话，替换原来用户输入的日期
		dateTo=$tempFullDateTo
	fi

	# 校验日期是否符合规范
	if [ "true" !=  `isEightDigitDate $dateFrom` ];then
		myEchoError "param '$dateFrom' is not a correct 8-digit date"
		handle_option_error
		exit 1
	fi
	if [ "true" !=  `isEightDigitDate $dateTo` ];then
		myEchoError "param '$dateTo' is not a correct 8-digit date"
		handle_option_error
		exit 1
	fi

	# 日期起始日不能是空集
	if [ $dateFrom -gt $dateTo ];then
		throw "dateFrom($dateFrom) should not be later than dateTo($dateTo)"
	fi

	logInfo "keyWordIndex=$keyWordIndex"
	logInfo "keyWord=$keyWord"
	logInfo "dateFrom=$dateFrom"
	logInfo "dateTo=$dateTo"



	#--------
	# 2. 调用核心代码wherelog_core
	#--------

	# 开始调用wherelog核心代码

	# index如果是0，比较特殊，代表按照日志唯一编号搜索。显示具体的日志信息
	if [ $keyWordIndex -eq 0 ];then
		wherelog_fetch_log_files_by_logUniqId $keyWord $dateFrom $dateTo $_usingCache $_baseDir

	# 根据关键字查出列表
	else
		# 关键词顺序号转换成索引文件里面的列号
		local keyWordColumn=`getKeyWordColumn $keyWordIndex`
		# 关键词查找的记录数
		local matchedNum=`wherelog_list_keyword $keyWordColumn $keyWord $dateFrom $dateTo "true"`
		if [ $matchedNum -eq 0 ];then
			myEchoError "No process found by keyword '$keyWord' from $dateFrom to $dateTo"
		else
			local formatString="`normalize_index_file_format_string`"
			wherelog_list_keyword $keyWordColumn $keyWord $dateFrom $dateTo | xargs printf "$formatString\n"

			myEcho "-------------"
			myEcho "$matchedNum process(es) found."
		fi 
	fi


}





wherelog_api_main "$@"




