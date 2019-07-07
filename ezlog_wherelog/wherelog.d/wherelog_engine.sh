. $deployDir/common.d/logUtil.sh # 日志支持
. $deployDir/common.d/commonUtil.sh
. $deployDir/common.d/log_formater.sh # 日志格式支持

printWherelogUsage() 
{
  myEcho
  myEcho "------------USAGE-------------"
  myEcho "1.Syntax: "
  myEcho "   $shellName [-options] (log_thread_id|EVENT_NO|BUSINESS_ID|USER_CODE) [date]"
  myEcho
  myEcho "2.Examples: "
  myEcho "   1).By log thread id:   "
  myEcho "       BITS full log thread id is like: 4432849-20150802052013145.201314"
  myEcho "       Using part of the id is OK: "
  myEcho "       $shellName 201314            # Note: only search in logs TODAY"
  myEcho "       $shellName 20150802052013145"
  myEcho "       $shellName 20150802052013145.201314"
  myEcho "   2).By EVENT_NO"
  myEcho "       $shellName 36f70da4f649c93a0007             # search today logs"
  myEcho "       $shellName 36f70da4f649c93a0007 20150802    # search 20150802 logs"
  myEcho "       $shellName 36f70da4f649c93a0007 ALL         # search ALL logs"
  myEcho "   3).By BUSINESS_ID"
  myEcho "       $shellName LCZC443201500154"
  myEcho "       $shellName LCZC443201500154 20150802    # search 20150802 logs"
  myEcho "       $shellName LCZC443201500154 ALL         # search ALL logs"
  myEcho "   4).By USER_CODE"
  myEcho "       $shellName 4433802"
  myEcho "       $shellName 4433802 20150802    # search 20150802 logs"
  myEcho "       $shellName 4433802 ALL         # search ALL logs"
  myEcho
}

# 检查日志目录是否合法，这里是按照BITS的规则校验
checkBitsLogHome()
{

# 判断原始日志目录是否正确
	if [ ! -d $BITS_LOGS_HOME ];then
		throw "BITS_LOGS_HOME not exists, please check : $BITS_LOGS_HOME"
	fi

	if [ ! -e $BITS_LOGS_HOME/TRANS_TIME* ];then
		throw "It seems not a BITS log direcotry, please check : $BITS_LOGS_HOME"
	fi

}









# 根据thread id查找日志
doWherelogForThreadId()
{
	# 获取传进来的日志线程号
	threadId=$1

	# 首先判断threadId的类型
	threadIdType=`parseThreadId $threadId`
	if [ $threadIdType -lt 0 ];then
		myEchoError "Params Error! It seems not a BITS log thread id: $threadId"
		printWherelogUsage
		throw
	fi

	#提取日期信息，注意：只有类型2、3、4才能从字面获取时间
	threadDate=`getDateFromThreadId $threadId`

	# 日志是否压缩了
	export _IS_LOG_ZIPPED=`isLogZipped $threadId $BITS_LOGS_HOME`


	# 拿到TRANS_TIME里面匹配的日志，最多取MATCHES_SHOW_NUM条
	# 形式类似下面的列子：
	# 2015-06-02 13:23:01,793 [WebContainer : 0] [4430208-20150602132505671.376692 queryList] [TRANS_TIME_BITS] INFO queryList_BITSLA0411 166903 BITSLA0411
	grepkey=$threadId
	if [ $threadIdType -eq 1 ];then
		grepkey=".$threadId " # 6位简写可能与日志其他部分重，所以在首位添加了些内容
	fi
	if [ $_IS_LOG_ZIPPED -eq 1 ];then
		transTimeLog="`zgrep -hF $grepkey $BITS_LOGS_HOME/$TRANS_TIME_LOG_NAME* $BITS_LOGS_HOME/${threadDate}.zip/$TRANS_TIME_LOG_NAME*  2>/dev/null | head -n $MATCHES_SHOW_NUM`"
	else
		transTimeLog="`grep -hF $grepkey $BITS_LOGS_HOME/$TRANS_TIME_LOG_NAME* $BITS_LOGS_HOME/${threadDate}/$TRANS_TIME_LOG_NAME*  2>/dev/null | head -n $MATCHES_SHOW_NUM`"
	fi

	# 看看匹配了多少条
	threadNum=`echo "$transTimeLog" |  wc -l`

	# 如果多于一条，则退出
	if [ $threadNum -gt 1 ];then
		throw "More than $threadNum threads found, please check: \n `echo "$transTimeLog" |  awk -F'\]' '{print $1, $2, $4}' |awk -F'\[' '{print $1, $3}' |awk '{print $1, $2, $3, $7, $8}' `
	Too many threads matches thread id: $threadId ; $shellName can find thread id that matches only [ONE] thread ....	"
	fi


	# 如果一条，再看有没有grep到日志
	if [ "x" = x"$transTimeLog" ];then
		if [ $threadIdType -eq 1 ];then
			throw "Cannot find thread id : " $threadId ". Note: Only search today logs when using 6 numbers id and $threadId is not in today logs"
		else
			throw "Cannot find thread id : " $threadId
		fi
	fi


	# 从用户输入的不完整id，拿到完整的threadId
	fullThreadId=`getFullThreadFromTransTimelog $transTimeLog `
	processName=`getProcessNameFromTimelog $transTimeLog`
	processUsingTime=`getProcessTimeUsingFromTimelog $transTimeLog`
	processEndTime=`getProcessEndTimeFromTimelog $transTimeLog`
	processTranCode=`getProcessTranCodeFromTimelog $transTimeLog`
	processTranName=`getProcessTranNameFromTimelog $transTimeLog`
	processBusinessId=`getProcessBusinessIdFromTimelog $transTimeLog`
	processEventNo=`getProcessEventNoFromTimelog $transTimeLog`
	threadLogDir=$WHERELOG_HOME/${fullThreadId}_${processName}_${processTranCode}


	# 是否从新查找 1-重新查找 0-使用上次查找结果
	isReFind=1
	# 只有允许使用缓存，并且上次的缓存是OK的，才不用启动本次查找
	if [ $IS_USING_CACHE_RESULT -eq 1 ];then
		if [ -e $threadLogDir/.ok ];then
			isReFind=0
		fi
	fi


	# 准备输出目录
	if [ ! -e $threadLogDir ];then
		mkdir -p $threadLogDir
	elif [ $isReFind -eq 1 ];then # 删除重新产生
		rm -rf $threadLogDir
		mkdir -p $threadLogDir
	fi



	export threadLogDir

	# 直接读取上次的缓存结果
	if [ $isReFind -eq 0 ];then
		logDebug "isReFind=$isReFind, use last report"
		cat $threadLogDir/.report.txt
		exit 0
	fi

	printReportMessage "1. Log thread id:  $fullThreadId"
	printReportMessage "2. Business info:"
	printReportMessage "      PROCESS ID:  $processName"
	printReportMessage "      TRAN CODE:   $processTranCode"
	printReportMessage "      TRAN NAME:   $processTranName"
	printReportMessage "      BUSINESS_ID: $processBusinessId"
	printReportMessage "      EVENT_NO:    $processEventNo"
	printReportMessage "3. Time :"
	printReportMessage "      END TIME:    $processEndTime"
	printReportMessage "      COST(ms):    $processUsingTime"
	printReportMessage "4. Original logs:"


	# 对每一种日志类型进行搜索，看是否包含线程id
	for pattern in $LOG_NAME_PATTERNS;do
		candidateFileList="`fetchCandidateLog $pattern "$transTimeLog"`" #只是根据日期判断可能有日志的文件，可能是多个文件
		logInfo "candidate: $candidateFileList"
		for candiateFile in $candidateFileList;do # 显然这里要求路径名不能有空格
			if [ $_IS_LOG_ZIPPED -eq 1 ];then
				matchedFileName=`zgrep -lF $fullThreadId $candiateFile`
			else
				matchedFileName=`fgrep -l $fullThreadId $candiateFile`
			fi
			if [ "x" != x"$matchedFileName" ];then
				printReportMessage "      "$matchedFileName
				echo $matchedFileName >> $threadLogDir/GREP_FILE_LIST.txt
			fi
		done
	done

	# 是否有错误日志
	isDumpExist=0
	dumpFileName=""

	printReportMessage "5. Filtered logs [ONLY 1 thread]:"
	printReportMessage "      $threadLogDir/"
	while read matchedFileNameWithPath
	do
		matchedFileName=`echo $matchedFileNameWithPath | awk -F/ '{print $NF}'`
		matchedFileFullPath=$threadLogDir/${matchedFileName}

		# 首先用fullgrep将日志过滤出来到一个临时文件
		$deployDir/wherelog.d/fullgrep.sh $fullThreadId $matchedFileNameWithPath>${matchedFileFullPath}_tmp

		# 限制日志行的长度，仅针对BITS_LOG而言
		if [ $BITS_LOG_LINE_LIMIT -gt 0 -a  1 -eq  `awk_reg_test $matchedFileName "BITS_LOG"` ];then
			$deployDir/wherelog.d/limit_log_line_length.sh $BITS_LOG_LINE_LIMIT ${matchedFileFullPath}_tmp > ${matchedFileFullPath}_tmp_2
			rm -rf ${matchedFileFullPath}_tmp
			mv ${matchedFileFullPath}_tmp_2 ${matchedFileFullPath}_tmp
		fi

		# 删除冗余日志行
		if [ $IS_EXCLUDE_VERBOSE_LOG -eq 1 ];then

			oldIFS="$IFS"
			IFS='
			'
			for verbose_keyword in $VERBOSE_LOG_KEYWORD;do
				$deployDir/wherelog.d/exclude_line.sh "$verbose_keyword" ${matchedFileFullPath}_tmp >${matchedFileFullPath}_tmp_2
				rm -rf ${matchedFileFullPath}_tmp
				mv ${matchedFileFullPath}_tmp_2 ${matchedFileFullPath}_tmp
			done
			IFS="$oldIFS"
		fi

		# 判断是否输出简化版日志
		if [ $IS_SIMPLE_LOG -ne 1 ];then
			# 不用简化的，则临时文件就是正式要输出的结果
			mv ${matchedFileFullPath}_tmp ${matchedFileFullPath}
		else
			
			# 简化SQL_TIME与WS_TIME的日志
			if [ 1 -eq `awk_reg_test $matchedFileName "SQL_TIME"` -o  1 -eq `awk_reg_test $matchedFileName "WS_TIME"`  ];then
				# 格式化统计信息，格式如下：
				# 2015-07-02 11:20:37,813          5 EUIF_BASE_AUTHORITY.selectOrgByOrgCode
				cat ${matchedFileFullPath}_tmp |
				awk -F "[][]" '{print $1, $7}' |
				awk -F "|" '{print $1, $5 }' | 
				sed  "s/Consumed Time://g" | 
				awk '{printf "%10s %12s %10s %12s\n", $1, $2, $5, $4}'> $matchedFileFullPath
			# 简化JDBC日志
			elif [ 1 -eq `awk_reg_test $matchedFileName "JDBC_LOG"` ]; then
				cat ${matchedFileFullPath}_tmp |
				fgrep -v "java.sql.Connection" | 
				awk -F "[" '{print $1, $4}' |
				sed 's/java.sql.PreparedStatement] DEBUG//g' |
				awk '
				{
					print
					if($0~/^20.*    ==> Parameters/)
						{
							
							print "" # 打个空行，好区分每一个JDBC日志
							print "" # 打个空行，好区分每一个JDBC日志
						}
				}' >$matchedFileFullPath
			# 简化TF BITS ROOT SOAP日志
			elif [ 1 -eq `awk_reg_test $matchedFileName "TF_LOG"`  -o  1 -eq  `awk_reg_test $matchedFileName "BITS_LOG"` -o 1 -eq  `awk_reg_test $matchedFileName "ROOT_LOG"`  -o 1 -eq  `awk_reg_test $matchedFileName "SOAP_LOG"` ]; then
				cat ${matchedFileFullPath}_tmp |
				sed 's/\(20[0-9]\{2\}\-[0-1][0-9]\-[0-3][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9],[0-9]\{3\}\) \[[^][]*\] \[[^][]*\]/\1/' >$matchedFileFullPath
			else
				# 没有识别出来的类型，直接复制
				cp ${matchedFileFullPath}_tmp ${matchedFileFullPath}
			fi

			# 删除临时文件
			rm -rf ${matchedFileFullPath}_tmp
			
		fi
		
		printReportMessage "      "$matchedFileFullPath

		# 判断是否有报错
		if [ $isDumpExist -eq 0 ];then
			isDumpExist=`awk_reg_test $matchedFileName "DUMP"` 
			if [ $isDumpExist -eq 1 ];then
				dumpFileName=$matchedFileFullPath
			fi
		fi

	done<$threadLogDir/GREP_FILE_LIST.txt


	# 是否格式化JSON和XML日志
	if [ $IS_PRETTY_XML_JSON -eq 1 ];then
		# 格式化LOGSWITCH的前后台请求JSON日志	
		ls $threadLogDir/LOGSWITCH* >/dev/null 2>&1
		if [ $? -eq 0 ];then
			logDebug "format json"
			printReportMessage "      Format json in LOGSWITCH.txt ... "
			formatLogSwitchLog $threadLogDir/LOGSWITCH*
		fi

		ls $threadLogDir/SOAP_LOG* >/dev/null 2>&1
		if [ $? -eq 0 ];then
			printReportMessage "      Format xml in SOAP_LOG.txt ... "
			logDebug "format xml"
			formatSoapLog $threadLogDir/SOAP_LOG*
		fi
		
	fi





	# 标记整个搜索完毕，用于判断第二次搜索是否需要重新搜索
	touch $threadLogDir/.ok

	# 如果有错误日志，提示是否立即more查看
	if [ $isDumpExist -eq 1 -a $IS_PROMPT_ERROR_LOG -eq 1 ];then
		local osname=`uname`
		myEcho ""
		if [ "x"$osname = x"Linux" ];then
			echo -n "Error in DUMP log, read it? (y|n)" # linux处理echo不换行和aix不一样
		else
			myEcho "Error in DUMP log, read it? (y|n) \c"
		fi
		
		read YESNO
		case $YESNO in
			y|Y)
				
				if [ "x"$osname = x"Linux" ];then
					less $dumpFileName # linux下用less
				else
					more -v $dumpFileName
				fi				
			;;
			*)
			;;
		esac
	fi

}








# 这种情况，默认只是显示出包含这个业务编号的日志线程号
doWherelogForList()
{
	keyword=$1

	# 缩小范围的日期
	searchDate=$2 # 日志日期，如果没有输入，就默认为当天；或者指定为ALL搜索所有日志
	if [ x"$searchDate" = "x" ];then
		searchDate=`date +"%Y%m%d"`
	fi


	# 校验日期
	flag=`awk_reg_test "$searchDate" "^((19|20)[0-9]{2}[0-1]{1}[0-9]{1}[0-3][0-9]|ALL)$"`
	if [ $flag -ne 1 ];then
		myEchoError "Params Error: when the 1st param is BUSINESS_ID, EVENT_NO or USER_CODE, the 2nd param $searchDate should be a date: YYYYMMDD"
		printWherelogUsage
		exit 1
	fi

	# 根据不同的范围搜索
	if [ x"$searchDate" = xALL ];then
		result=`getLogToStdout "$BITS_LOGS_HOME/TRANS_TIME* $BITS_LOGS_HOME/20[0-9][0-9][0-9][0-9][0-9][0-9]/TRANS_TIME* $BITS_LOGS_HOME/20[0-9][0-9][0-9][0-9][0-9][0-9].zip/TRANS_TIME*"  |
		grep -shF $keyword | formatTransTimeList`
		
	else
		dateLogFormat=`echo $searchDate | cut -c 1-4 `"-"`echo $searchDate | cut -c 5,6 `"-"`echo $searchDate | cut -c 7,8 `
		result=`getLogToStdout "$BITS_LOGS_HOME/TRANS_TIME* $BITS_LOGS_HOME/$searchDate/TRANS_TIME* $BITS_LOGS_HOME/${searchDate}.zip/TRANS_TIME*" |
		grep  "^$dateLogFormat" |
		grep -shF $keyword | formatTransTimeList`

	fi

	
	# 参数类型
	if [ $threadIdType -eq 21 ];then
		keywordName="BUSINESS_ID"
	elif [ $threadIdType -eq 22 ];then
		keywordName="EVENT_NO"
	elif [ $threadIdType -eq 23 ];then
		keywordName="USER_CODE"
	fi

	# 没有查到
	if [ x"$result" = "x" ];then
		myEcho "No process found by $keywordName : $keyword on date $searchDate"
		if [ x$searchDate != xALL ];then
			myEcho "Try to search in ALL logs: $shellName $keyword ALL"
		fi
		exit 2
	fi
 

 	resultNum=`echo "$result" |wc -l`
 	resultNum=`echo $resultNum`

	myEcho "$result"
	myEcho "-------------"
	myEcho "$resultNum process(es) found."

	

}



# 格式化结果
formatTransTimeList()
{
	# # 替换掉 [WebContainer : 3] 
	# 2015-07-14 09:04:14,726 [4430208-201507140904871 processId_authProcess] [WS_TIME] INFO   WS_STAT.getAuthType||FINISHED SUCCESS||Consumed Time:2804 Milli Seconds.
	sed 's/\(20[0-9]\{2\}\-[0-1][0-9]\-[0-3][0-9] [0-2][0-9]:[0-6][0-9]:[0-6][0-9],[0-9]\{3\}\) \[[^][]*\]/\1/' | 
	# 防止日志线程号为空的情况，补充一个线程号
	sed 's/\[ \]/\[0000000-20990101010101000.000000 processId_no_process_id\]/'|
	#  nologin开头，只有线程号，没有process id的
	sed 's/\[\(nologin-[0-9]* \)\]/\[\1 processId_no_process_id\]/'|
	# 去掉 [4430208-201507140904871 processId_authProcess]两边的中括号
	# 2015-07-14 09:04:14,726 4430208-201507140904871 processId_authProcess [WS_TIME] INFO   WS_STAT.getAuthType||FINISHED SUCCESS||Consumed Time:2804 Milli Seconds.
	sed 's/\[//' | 
	sed 's/\]//' |
	# [WS_TIME] 删掉
	# 2015-07-14 09:04:14,726 4430208-201507140904871 processId_authProcess   WS_STAT.getAuthType||FINISHED SUCCESS||Consumed Time:2804 Milli Seconds.
	sed 's/\[[^][]*\] INFO//' |
	# 2015-07-14 09:04:14,726 4430208-201507140904871 processId_authProcess   WS_STAT.getAuthType||FINISHED SUCCESS|| 2804 
	
	sed 's/processId_//' |  #到这里有8列了 2015-06-29 09:22:10,238 nologin-201506261742871  no_process_id    WS_STAT.sendModeThreeTaskByUserCodeWithRsp FINISHED SUCCESS  337 
	# awk 整理
	#            日期 时刻  日志号 交易码 业务编号 EVENT_NO STATUS process
	#             1    2      3        7   8        9         10      4
	awk '{printf "%10s %12s  %-32s  %10s  %16s  %20s %8s  %-60s\n" ,$1, $2, $3, $7, $8, $9, $10, $4}' | sort
}


# 列出当天做的wherelog目录
listWherelogHistory()
{
	if [ ! -d $WHERELOG_HOME ];then
		return 
	fi
	find $WHERELOG_HOME -mtime -1 -type d -print | grep -v "^$WHERELOG_HOME$" | xargs ls -ltrd | awk '{
		# $1=null;$2=null;$3=null;$4=null;$5=null;print
		for (i=6;i<=NF;i++)
		{
			printf "%s " ,$i
		}
		printf "\n"
	}'
}
