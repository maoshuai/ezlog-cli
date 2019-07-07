# EZLOG_SOURCE_DIR=/Users/maoshuai/maos/it_studio/ezlog-workspace/ezlog-cli

EZLOG_DEPLOY_BUILD_DIR=/tmp/ezlog_build

# 
EZLOG_DEPLOY_CODING=UTF-8

currentDir=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P ) # 获取脚本运行的当前目录
cd $currentDir
cd ..
export EZLOG_SOURCE_DIR=`pwd`

# validate

if [ ! -d $EZLOG_SOURCE_DIR ];then
	echo "ezlog-dev dir not found! ">&2
	exit 1
fi


# if $EZLOG_DEPLOY_BUILD_DIR not created yet

if [ ! -d $EZLOG_DEPLOY_BUILD_DIR ];then
	mkdir -p $EZLOG_DEPLOY_BUILD_DIR
fi




ezlog_shells_dir=$EZLOG_DEPLOY_BUILD_DIR/ezlog_deploy_shell_temp
ezlog_shells_tarball=ezlog.tar



copyComponent()
{
	local componentName=$1
	cp -r $EZLOG_SOURCE_DIR/$componentName  $ezlog_shells_dir
	rm -rf $ezlog_shells_dir/$componentName/test.d # 删除test文件
}


mkdir -p $ezlog_shells_dir

# 目前只有4个对运行时有用的组件
copyComponent ezlog_common
copyComponent ezlog_wherelog
copyComponent ezlog_health
copyComponent builtin_profiles

cp $EZLOG_SOURCE_DIR/ezlog.profile $ezlog_shells_dir

# 暂时用wherelog 的版本命名
version=`head -n 1  $ezlog_shells_dir/ezlog_wherelog/wherelog.d/_meta/version.txt` # 版本号
# 修改构建时间
buildDate=`date "+%Y-%m-%d %H:%M:%S"`
buildDateForFileName="`echo $buildDate |sed 's/ //g'  | sed 's/://g' | sed 's/\-//g' `"

echo "$buildDate" > $ezlog_shells_dir/ezlog_common/_meta/ezlog_build_time.txt

# 根据版本和构建日期重命名
releaseName="ezlog-cli-${version}-${buildDateForFileName}"
mv "$ezlog_shells_dir" "$EZLOG_DEPLOY_BUILD_DIR/$releaseName"

# 打个tar包
cd $EZLOG_DEPLOY_BUILD_DIR


tar -cf ${releaseName}.tar $releaseName



echo "ezlog build sucessfully: $EZLOG_DEPLOY_BUILD_DIR/$releaseName"
