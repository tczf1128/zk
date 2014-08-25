#!/bin/sh

### enviroment
workpath=$(dirname $0)
cd $workpath
workpath=$(pwd)

config_file="${workpath}/../conf/zoo.cfg"
if [ ! -f $config_file ]; then
    exit 1
fi

### tcp connection state
now=$(date +%s;netstat -ts 2>/dev/null| awk '{
    if ($2 == "passive") {
        print $1
    }
    else if ($2 == "failed") {
        print $1	
    }
    else if ($NF == "overflowed") {
        print $1
    }
}')

lastfile="${workpath}/tcp.stat"
if [ ! -f "$lastfile" ]; then
    last=$now
else
    last=$(cat $lastfile)
fi
echo "$now" > $lastfile

if [ -z "$last" ] || [ -z "$now" ];then
    echo "zk_tcp_passive: -1"
    echo "zk_tcp_failed: -1"
    echo "zk_tcp_overflowed: -1"
else
    function index() {
        echo $1 | cut -d " " -f $2
    }
    interval=$(($(index "$now" 1)-$(index "$last" 1)))
    if [ $interval -le 0 ]; then
        interval=1
    fi
    function rate() {
        curr=$(index "$1" $3)
        prev=$(index "$2" $3)
        echo $(((curr-prev)/interval))
    }
    echo "zk_tcp_passive: "$(rate "$now" "$last" 2)
    echo "zk_tcp_failed: "$(rate "$now" "$last" 3)
    echo "zk_tcp_overflowed: "$(rate "$now" "$last" 4)
fi

check() {
    [ -z "$1" ] && echo "-1" || echo $1
}

### snapshot file size
data_dir=$(awk -F= '{if($1=="dataDir") print $2}' $config_file)
if [ ! -z "$data_dir" ]; then
    myid=$(cat "$data_dir/myid" 2>/dev/null)
    size=$(ls -lt --block-size=1k $data_dir/version-2/snapshot.* 2>/dev/null | head -1 | awk '{print $5}')
    log_size=$(ls -lt --block-size=1k $data_dir/version-2/log.* 2>/dev/null | head -2 | tail -1 | awk '{print $5}')
fi
echo "zk_snapshot: "$(check $size)
echo "zk_log_size_k: "$(check $log_size)

### election port state
election_port=$(awk -v server="server.$myid" -F= '{if($1==server) print $2;}' $config_file|awk -F: '{print $3}')
if [ -z "$election_port" ]; then
    stat=0
else
    stat=$(netstat -an|grep "$election_port"|grep 'LISTEN'|wc -l)
fi
echo "zk_election_port_stat: "$stat

### warning logs of last 1 minute
expect=$(date -d '1 minutes ago' +%H:%M:)
log4j_file="${workpath}/../conf/log4j.properties"
log_file=$(grep 'log4j.appender.WARNFILE.File' $log4j_file 2>/dev/null | cut -d= -f2)
echo "zk_warning_logs_1min: "$(check $(grep "${expect}" ${log_file} 2>/dev/null | wc -l))

echo BDEOF
