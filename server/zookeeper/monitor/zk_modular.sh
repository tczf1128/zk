#!/bin/bash

### enviroment
work_path=$(dirname $0)
cd $work_path
work_path=$(pwd)

# ִ�еĽű�����
scripts=(zk_monitor.sh zk_gc.sh zk_system.sh)

# �ɼ���ʱʱ��
waiting_time=10

interval_time=30

process_name="inf"

service_name="zookeeper"

output_file="${work_path}/modular.json"

tmp_file="${work_path}/.tmp_file"

execute() {
    command=$*
    cat /proc/self/stat 2>/dev/null | awk '{print $4}' > ${tmp_file}
    pid=$(cat ${tmp_file})
    ${command} > ${tmp_file} 2>/dev/null &
    command_pid=$!
    # �������̼��command���̣���ʱ��ɱ��
    {
        sleep ${waiting_time}
        if ps -p ${command_pid} >/dev/null 2>&1; then
            command_ppid=$(ps -p ${command_pid} -o ppid= 2>/dev/null)
            # ��ֹ��ɱ
            if [ p${command_ppid//\ /} = p${pid} ]; then
                kill -9 ${command_pid} >/dev/null 2>&1
            fi
        fi
    } &
    monitor_pid=$!
    wait ${command_pid} >/dev/null 2>&1
    output=""
    if ps -p ${monitor_pid} >/dev/null 2>&1; then
        # ������
        output=$(cat ${tmp_file} 2>/dev/null)
        # ɱ����ؽ���
        monitor_ppid=$(ps -p  ${monitor_pid} -o ppid= 2>/dev/null)
        if [ p${monitor_ppid//\ /} = p${pid} ]; then
            kill -9 ${monitor_pid} >/dev/null 2>&1
        fi
    fi
}

printJson() {
    data=""
    for script in ${scripts[@]}
    do
        execute "${work_path}/${script}"
        data=$(echo "${output}"| awk '{
            if ($1 != "BDEOF") {
                sub(/:/, "", $1)
                if ($1 != "" && $2 != "") printf("\"%s\":%s,", $1, $2)
            }
        }')${data}
    done
    echo '{"'${process_name}'":{"'${service_name}'":{'$data'"zk_null":0}}}' > ${output_file}
}

printJson & sleep ${interval_time}; printJson &

