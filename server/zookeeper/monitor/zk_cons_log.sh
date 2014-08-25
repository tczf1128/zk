#!/bin/sh

### enviroment
workpath=$(dirname $0)
cd $workpath
workpath=$(pwd)

config_file="${workpath}/../conf/zoo.cfg"
if [ ! -f $config_file ]; then
    exit 1
fi

local_ip="127.0.0.1"
port=$(awk -F= '{if ($1 == "clientPort") print $2}' $config_file)
if [ -z "$port" ]; then
    exit 1
fi

log_path="${workpath}/logs"
mkdir -p $log_path
N=100
#日志后缀
suffix=$(date +%Y%m%d%H)
#流量最大的N个连接
cons_top="${log_path}/cons_top."$suffix
#流量最大的N个ip
ip_top="${log_path}/ip_top."$suffix
#连接数最多的N个ip
ip_cons_top="${log_path}/ip_cons_top."$suffix

### cons info: statistics
last_file="${workpath}/.cons.last"
now_file="${workpath}/.cons.now"
time_key="timestamp"

echo "$time_key $(date +%s)" > $now_file
echo cons|nc $local_ip $port|sed -n 's/.*\/\(.*\)\[.*recved=\([0-9]*\).*/\1 \2/p' >> $now_file

if [ ! -f $last_file ]; then
    cp $now_file $last_file
fi

data=$(awk -v time_key="$time_key" '
FNR == NR {
    last[$1] = $2
} FNR!=NR {
    cons[FNR] = $1
    now[FNR] = $2
} END {
    interval = now[1] - last[time_key]
    if (interval <= 0) {
        interval = 1
    }
    for (i=2; i<=FNR; ++i) {
        /* if this is a new connection, last[cons[i]] = 0 in awk */
        received = now[i] - last[cons[i]]
        printf "%s %d\n", cons[i], received/interval
    }
}' $last_file $now_file)


function print_topn() {
    result=$(echo "$1" | sort -k2 -nr | head -n $N | awk '
        BEGIN {time_s=strftime("%Y-%m-%d %H:%M:%S",systime())}
        {if($2>0) print time_s,$1,$2}')
    if [ ! -z "$result" ]; then
        echo "$result" >> "$2"
    fi
}

print_topn "$data" $cons_top
print_topn "$(echo "$data" | awk -F "[ :]" '{s[$1]+=$3}END{for(ip in s)print ip,s[ip]}')" $ip_top
print_topn "$(echo "$data" | awk -F "[ :]" '{s[$1]++}END{for(ip in s)print ip,s[ip]}')" $ip_cons_top

mv $now_file $last_file

