#!/bin/sh

help()
{
  cat << HELP
 Name:  zk_session_rate.sh 统计指定时间段内每ip新建连接总数
 Encoding: gb2312
 Usage: sh zk_session_rate.sh [-h]
   -b [N] 设置输出的最小值
   -l []  指定包含来至本地请求
   -E [reg] 指定统计的时间段,如"19:15:",默认指前一分钟
   -T [N] 只输出前N个
   -h,--help
    输出帮助文档
 Description:
 Author:
HELP
}

#频率>=baseline时输出
baseline=50
#显示本地
showlocal=0
#只显示前topn个
topn=0
#时间特征,默认为前一分钟
expect=$(date -d '1 minutes ago' +%H:%M:)

while [ -n "$1" ]; do
    case $1 in
    -h) help;exit 0;shift 1;;
    --help) help;exit 0;shift 1;;
    -b) if [ -z $2 ] || [ ! -z ${2//[0-9]/} ]; then
            help;exit 1
        fi
        baseline=$2;shift 2;;
    -l) showlocal=1;shift 1;;
    -E) if [ -z $2 ] || [ -${2#-} == $2 ]; then
            help;exit 1
        fi
        expect=$2;shift 2;;
    -T) if [ -z $2 ] || [ ! -z ${2//[0-9]/} ]; then
            help;exit 1
        fi
        topn=$2;shift 2;;
    *) echo "Incorrect arugs";help;exit 1;;
    esac
done

### enviroment
workpath=$(dirname $0)
cd $workpath
workpath=$(pwd)

log4j_file="${workpath}/../conf/log4j.properties"
if [ ! -f $log4j_file ]; then
    echo "${log4j_file}: No such file"
    exit 1
fi

log_file=$(grep 'log4j.appender.NOTICEFILE.File' $log4j_file|cut -d= -f2)
if [ -z "$log_file" ]; then
    echo "${log_file}: No NOTICEFILE"
    exit 1
fi

data=$(grep "$expect" $log_file|grep 'Accepted'|awk -F "[/:]" '{print $(NF-1)}'|\
    awk -v baseline="$baseline" '{s[$1]++}END{for(ip in s)if(s[ip]>=$baseline)print ip,s[ip]}'|sort -k2 -nr)

if [ $showlocal -ne 1 ]; then
    data=$(echo "$data" | grep -vE '^127\..*')
fi

if [ $topn -ne 0 ]; then
    data=$(echo "$data" | head -n $topn)
fi

echo "$data"

