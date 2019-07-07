#!/usr/bin/perl
# 通过perl获取文件的日期和时间，用于解决没有stat或istat命令的系统
# 输入：文件名
# 输出：日期和时间，比如：10 12:06:33
use File::stat;
use POSIX qw(strftime);

if (@ARGV != 1)
{
    print "Usage: $0 file";
    exit 1;
}

$file = $ARGV[0];
$date_string = strftime "%d %H:%M:%S", (localtime stat($file)->mtime)[0..5];
print "$date_string\n";