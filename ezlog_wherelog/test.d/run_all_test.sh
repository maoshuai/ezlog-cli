

# 运行test.profile
. $EZLOG_HOME/ezlog_test/ezlog_test.profile

# 导入ezlog的测试调度器
. $EZLOG_HOME/ezlog_test/ezlog_test_runner.source

# 调度test.d下面的所有测试案例
runTestUnderDir "$EZLOG_HOME/ezlog_wherelog/test.d"