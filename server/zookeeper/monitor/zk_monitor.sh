#!/bin/sh

### enviroment
workpath=$(dirname $0)
cd $workpath
workpath=$(pwd)

config_file="${workpath}/../conf/zoo.cfg"
if [ ! -f $config_file ]; then
    exit 1
fi

ip="127.0.0.1"
port=$(awk -F= '{if ($1 == "clientPort") print $2}' $config_file)
if [ -z "$port" ]; then
    exit 1
fi

### monr info: statistics
last_file="${workpath}/monr.last"
now_file="${workpath}/monr.now"
time_key="timestamp:"

echo "$(echo "$time_key $(date +%s)";echo monr|nc $ip $port)" > $now_file

if [ ! -f $last_file ]; then
    cp $now_file $last_file
fi

awk -v time_key="$time_key" 'BEGIN {
    mode = 0
} FNR == NR {
    last[$1] = $2
} FNR!=NR {
    name[FNR] = $1
    now[FNR] = $2
    if ($1 == "zk_mode:") {
        if ($2 == "leader") {
            mode = 1
        } else if ($2 == "follower") {
            mode = 5
        } else if ($2 == "observer") {
            mode = 10
        } else if ($2 == "proxy") {
            mode = 15
        } else {
            mode = -1
        }
    }
} END {
    if (mode == 0 || name[1] != time_key || !(time_key in last)) {
        exit 1
    }
    printf("zk_running: 1\n")
    interval = now[1] - last[time_key]
    if (interval <= 0) {
        interval = 1
    }
    for (i=2; i<=FNR; ++i) {
        if (name[i] in last) {
            key = name[i]
            value = now[i]
            if (key == "zk_mode:") {
                value = mode
            } else if (key == "zk_packets_received:") {
                value = (value - last[key])/interval
                key = "zk_received_per_sec:"
            } else if (key == "zk_packets_sent:") {
                value = (value - last[key])/interval
                key = "zk_sent_per_sec:"
            } else if (key ~ /^zk_.*(_received|_succeed|_failed):$/) {
                value = (value - last[key])/interval
            } 
            printf("%s %d\n", key, value)
        }
    }
}' $last_file $now_file

mv $now_file $last_file

echo BDEOF

