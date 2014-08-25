#!/bin/sh

help()
{
  cat << HELP
 Name: zk_request_rate.sh 按[ip/连接]计算每秒处理的请求数
 Encoding: gb2312
 Usage: sh zk_request_rate.sh [-h]
   -b [N] 设置输出的最小值
   -c []  指定按连接统计数据
   -l []  指定包含来至本地请求
   -t [N] 设置采集的时间[秒]
   -T [N] 只输出前N个
   -h,--help 输出帮助文档
 Description:
 Author:
HELP
}

#单ip速率>=baseline时输出
baseline=10
#采集时间
interval=1
#统计单位，ip/cons
unit="ip"
#显示本地
showlocal=0
#只显示前topn个
topn=0

while [ -n "$1" ]; do
    case $1 in
    -h) help;exit 0;shift 1;;
    --help) help;exit 0;shift 1;;
    -b) if [ -z $2 ] || [ ! -z ${2//[0-9]/} ]; then
            help;exit 1
        fi
        baseline=$2;shift 2;;
    -c) unit="cons";shift 1;;
    -l) showlocal=1;shift 1;;
    -t) if [ -z $2 ] || [ ! -z ${2//[0-9]/} ]; then
            help;exit 1
        fi
        interval=$2;shift 2;;
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

config_file="${workpath}/../conf/zoo.cfg"
if [ ! -f $config_file ]; then
    echo "${config_file}: No such file"
    exit 1
fi

local_ip="127.0.0.1"
port=$(awk -F= '{if ($1 == "clientPort") print $2}' $config_file)
if [ -z "$port" ]; then
    echo "${port}: No clientPort"
    exit 1
fi
last=$(echo cons|nc $local_ip $port|sed -n 's/.*\/\(.*\)\[.*recved=\([0-9]*\).*/\1 \2/p')
sleep $interval
now=$(echo cons|nc $local_ip $port|sed -n 's/.*\/\(.*\)\[.*recved=\([0-9]*\).*/\1 \2/p')
lines=$(echo "$now"|wc -l)

data=$((echo "$now";echo "$last")|awk -v interval="$interval" -v seg="$lines" '
FNR <= seg {
    cons[FNR] = $1
    now[FNR] = $2
} FNR > seg {
    last[$1] = $2
} END {
    for (i=1; i<=seg; ++i) {
        /* if this is a new connection, last[cons[i]] = 0 in awk */
        received = now[i] - last[cons[i]]
        printf "%s %d\n", cons[i], received/interval
    }
}')

if [ "$unit" == "ip" ]; then
    data=$(echo "$data" | awk -v baseline="$baseline" -F "[ :]" '{s[$1]+=$3}END{for(ip in s)if(s[ip]>=baseline)print ip,s[ip]}' | sort -k2 -nr)
elif [ "$unit" == "cons" ]; then
    data=$(echo "$data" | awk -v baseline="$baseline" '{if($2>=baseline)print $1,$2}' | sort -k2 -nr)
fi

if [ $showlocal -ne 1 ]; then
    data=$(echo "$data" | grep -vE '^127\..*')
fi

if [ $topn -ne 0 ]; then
    data=$(echo "$data" | head -n $topn)
fi

echo "$data"

