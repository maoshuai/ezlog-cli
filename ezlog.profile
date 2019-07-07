#----------------------
# author:	maoshuai
# date:		2016-06-23
#----------------------

#----------------------
# 本文件是ezlog读取的第一个配置文件
# 最重要的作用是设置变量EZLOG_PROFILE_HOME，决定ezlog加载哪个profile
# 如果在用户的home目录下也放置了.ezlog.profile文件，那么则会继续读取.ezlog.profile文件，并覆盖当前文件的设置
# 达到用户级配置覆盖全局级别的作用
#----------------------

#----------------------
# 最佳实践：
# 1. 不建议直接修改此文件，而是将本文将拷贝到用户home根目录，并命名为.ezlog.profile（比如/home/bitsadm/.ezlog.profile）
# 2. 将builtin_profiles下面的default_profile目录拷贝到用户home目录下，并命名为.ezlog_profile（比如/home/bitsadm/.ezlog_profile.d）
# 3. 将.ezlog.profile里面的EZLOG_PROFILE_HOME变量修改为.ezlog_profile的绝对路径（比如export EZLOG_PROFILE_HOME=/home/bitsadm/.ezlog_profile.d)
# 4. 将home/bitsadm/.ezlog_profile.d下面的配置文件或插件，根据项目的实际情况进行适配性修改
# 4. 每次升级ezlog的时候，可以直接升级所有文件，而/home/bitsadm/.ezlog_profile.d继续沿用
#----------------------

# EZLOG加载的profile配置目录
export EZLOG_PROFILE_HOME=$EZLOG_HOME/builtin_profiles/default_profile
