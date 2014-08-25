#!/bin/bash

#jstat����·��
MONITOR_DIR=`dirname $0`
MONITOR_DIR=`cd "$MONITOR_DIR"; pwd`
JSTAT_PATH="$MONITOR_DIR/../../java6/bin/jstat"
USER_DIR=`cd "${MONITOR_DIR}/../"; pwd`
JVM_GC_LOG=${MONITOR_DIR}/jvm_gc.log
help()
{
  cat << HELP
 Name: zk_jvm.sh -- �鿴zookeeperʹ��java�ѵĸ��������������ڵ������𵥸�zookeeper������
       ʹ��java jstat -gcutil 'pid' ����ɼ� pid���ļ�zookeeper_server.pid�ж�ȡ
 Encoding: gb2312
 Description:
 Author:
HELP
}

cat ${JVM_GC_LOG} 2>/dev/null

{
CONFIG_FILE="${MONITOR_DIR}/../conf/zoo.cfg"
if [ ! -f $CONFIG_FILE ]; then
    exit 1
fi

DATA_DIR=$(awk -F= '{if($1=="dataDir") print $2}' $CONFIG_FILE)
PID_FILE="$DATA_DIR/zookeeper_server.pid"
if [ ! -f "$PID_FILE" ]; then
    exit 1
fi
pid=$(cat $PID_FILE)
if [ -z $pid ];then
    exit 1;
fi
#ͨ��jstat�����ȡ��ǰjava�ѵĲ���
gc_output=$($JSTAT_PATH -gc $pid | tail -1)

#�����Ϊ��ʱ��ѭ�����������
if [ -z "$gc_output" ];then
    exit 1;
fi

check() {
    [ -z "$1" ] && echo "-1" || echo $1
}

echo "zk_jvm_old_util: "$(check $(echo $gc_output | awk '{printf "%.2f", $8*100/$7}'))
echo "zk_jvm_per_util: "$(check $(echo $gc_output | awk '{printf "%.2f", $10*100/$9}'))
echo "zk_jvm_old_used_m: "$(check $(echo $gc_output | awk '{printf "%.2f", $8/1000}'))
echo "zk_jvm_per_used_m: "$(check $(echo $gc_output | awk '{printf "%.2f", $10/1000}'))
echo "zk_jvm_YGC: "$(check $(echo $gc_output | awk '{print $11}'))
echo "zk_jvm_YGCT: "$(check $(echo $gc_output | awk '{print $12}'))
echo "zk_jvm_FGC: "$(check $(echo $gc_output | awk '{print $13}'))
echo "zk_jvm_FGCT: "$(check $(echo $gc_output | awk '{print $14}'))
echo "zk_jvm_GCT: "$(check $(echo $gc_output | awk '{print $15}'))

echo BDEOF
} > $JVM_GC_LOG &
