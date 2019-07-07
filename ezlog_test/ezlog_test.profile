# 运行ezlog_test下面的测试案例的时候，要先source这个profile

# 先运行基本的profile
. $EZLOG_HOME/ezlog.profile

# 再运行测试相关的profile
# 测试的根目录
export EZLOG_TEST_HOME=$EZLOG_HOME/ezlog_test
# shunit2测试框架的目录
export EZLOG_SHUNIT2_DIR=$EZLOG_TEST_HOME/shunit2

export EZLOG_TEST_BASE_SOURCE=$EZLOG_TEST_HOME/ezlog_test_base.source


. $EZLOG_HOME/ezlog_common/common.d/os.source
. $EZLOG_HOME/ezlog_common/common.d/date_util.source
. $EZLOG_HOME/ezlog_common/common.d/common_util.source

# 如果日志配置为空，则使用默认的日志配置文件
if [ x"$EZLOG_SIMPLOG4SH_CFG" = "x" ];then
	. $EZLOG_HOME/ezlog_common/common.d/simpleLog4sh.source $EZLOG_HOME/ezlog_common/common.d/simpleLog4sh.cfg
else
	. $EZLOG_HOME/ezlog_common/common.d/simpleLog4sh.source $EZLOG_SIMPLOG4SH_CFG
fi

