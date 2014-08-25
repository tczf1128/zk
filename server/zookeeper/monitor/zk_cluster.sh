#!/bin/bash
#set -x
#zookeeper����·��,�������ļ��ж�ȡclient port��server port��Ŀǰֻ֧����ͬ��server port
#install_path="/home/work/noah/zookeeper/"
help()
{
  cat << HELP
 Name: zk_cluster_monitor.sh -- �ɼ�zookeeper������leader��zxid��nodecount�Ĳ�ֵ
       ʹ��srvr����ɼ���Ϣ��nc localhost�ɼ�������Ϣ��nestat��ȡleader��ip��
       nc leaderip��ȡleader����Ϣ��
 Encoding: gb2312
 Usage: sh zk_cluster_monitor.sh [-h]
   -h,--help
    ��������ĵ�
 Description:
      zk_zxid_diff: ����zookeeper��leader��zxid��ֵ
      zk_nodecount_diff: ����zookeeper��leader��node count��ֵ
 Author:
      noah-op@baidu.com
HELP
}
config_file=''
#forѭ������
index=1
#�������˿�
server_port=''
#���汾������zookeeper����
local_data=''
#�жϱ����Ƿ�Ϊleader
local_mode=''
#����leader��zookeeper����
leader_data=''
#����leader������ip
leader_ip=''
#���汾��ip
local_ip="localhost"
#�������
while [ -n "$1" ]; do
        case $1 in
        -h) help;exit 0;shift 1;;
        --help) help;exit 0;shift 1;;
        *)echo "Incorrect arugs";help;exit 1;;
        esac
done

workpath=$(dirname $0)
userdir=`cd "${workpath}/../"; pwd`
config_file="${workpath}/../conf/zoo.cfg"
if [ ! -f $config_file ]; then
    exit 1
fi

  if [ -z "$config_file" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
#��ȡclient�Ķ˿ں�
client_port=$(awk -F= '{ if($1=="clientPort") print $2}' $config_file)
 if [ -z "$client_port" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
 
#��ȡ����zookeeper����
  local_data=$(echo srvr | nc $local_ip $client_port| awk '{
    if($1=="Zxid:"){
      zxid=strtonum("0x"substr($2,3))
    }else if($1=="Node"){
      nodecount=$3
    }else if($1=="Mode:"){
      mode=$2
    }
  }
  END{
    print zxid
    print nodecount
    print mode
  }')
#�������Ϊ�գ����ӡ-1
  if [ -z "$local_data" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
#�������Ϊleader����ֱ�����Ϊ0  
  local_mode=$(echo $local_data | awk '{print $3}')
  if [ $local_mode == "leader" ];then
     echo zk_zxid_diff: 0
     echo zk_nodecount_diff: 0
     exit 0
  fi
#ȡ�ñ�����zxid ��node_count
  local_zxid=$(echo $local_data | awk '{print $1}')
  local_node_count=$(echo $local_data | awk '{print $2}')

#��ȡserver�˿�������Ŀǰ��֧����ͬ�Ķ˿ں�
port_num=$(awk -F= '{ if(match($1,"server")!=0) print $2}' $config_file | awk -F: '{print $2}' | sort -u | wc -l)

#�ж϶˿ںŸ���Ϊ1
if [ $port_num -eq 1 ];then
  server_port=$(awk -F= '{ if(match($1,"server")!=0) print $2}' $config_file | awk -F: '{if(NR==1)print $2}')
else 
  echo zk_zxid_diff: -1
  echo zk_nodecount_diff:-1
  exit 0
fi
  if [ -z "$server_port" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi

#echo "server_port:"$server_port
#echo "client_port:"$client_port

#ͨ��stat��ȡʹ��server ip����Ϣ
output=$(netstat -n 2>/dev/null| grep -w $server_port)
  if [ -z "$output" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi

#��ȡtcp���ӵı���ip��Զ������ip����server port��β��Ϊleader
for((index=4;index<=5;index++));do
  leader_ip=$(echo $output | awk '{print $i}' i=$index | awk -F: '{ if($2==port) print $1}' port=$server_port)
done

  if [ -z "$leader_ip" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
#echo leader_ip: $leader_ip
#echo local_ip: $local_ip
#��ȡleader��zookeeper����
  leader_data=$(echo srvr | nc $leader_ip $client_port| awk '{
    if($1=="Zxid:"){
      zxid=strtonum("0x"substr($2,3))
    }else if($1=="Node"){
      nodecount=$3
    }
  }
  END{
    print zxid
    print nodecount
  }')
#�������Ϊ�գ����ӡ-1
  if [ -z "$leader_data" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
#ȡ��leader��zxid��node_count
  leader_zxid=$(echo $leader_data | awk '{print $1}')
  leader_node_count=$(echo $leader_data | awk '{print $2}')  
#fi
#echo local_zxid: $local_zxid
#echo local_node_cout: $local_node_count
#echo leader_zxid: $leader_zxid
#echo leader_node_count: $leader_node_count

#tr -d -r ȥ�����ţ���ӡ��ֵ
echo zk_zxid_diff: $(($local_zxid -$leader_zxid)) | tr -d -
echo zk_nodecount_diff: $(($local_node_count -$leader_node_count)) | tr -d -

