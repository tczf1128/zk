#!/bin/bash
#set -x
#zookeeper配置路径,从配置文件中读取client port和server port，目前只支持相同的server port
#install_path="/home/work/noah/zookeeper/"
help()
{
  cat << HELP
 Name: zk_cluster_monitor.sh -- 采集zookeeper本机与leader的zxid和nodecount的差值
       使用srvr命令采集信息。nc localhost采集本地信息，nestat获取leader的ip后，
       nc leaderip获取leader的信息。
 Encoding: gb2312
 Usage: sh zk_cluster_monitor.sh [-h]
   -h,--help
    输出帮助文档
 Description:
      zk_zxid_diff: 本地zookeeper与leader的zxid差值
      zk_nodecount_diff: 本地zookeeper与leader的node count差值
 Author:
      noah-op@baidu.com
HELP
}
config_file=''
#for循环变量
index=1
#服务器端口
server_port=''
#保存本机器的zookeeper数据
local_data=''
#判断本机是否为leader
local_mode=''
#保存leader的zookeeper数据
leader_data=''
#保存leader的主机ip
leader_ip=''
#保存本机ip
local_ip="localhost"
#处理参数
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
#获取client的端口号
client_port=$(awk -F= '{ if($1=="clientPort") print $2}' $config_file)
 if [ -z "$client_port" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
 
#获取本机zookeeper数据
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
#如果数据为空，则打印-1
  if [ -z "$local_data" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
#如果本机为leader，则直接输出为0  
  local_mode=$(echo $local_data | awk '{print $3}')
  if [ $local_mode == "leader" ];then
     echo zk_zxid_diff: 0
     echo zk_nodecount_diff: 0
     exit 0
  fi
#取得本机的zxid 和node_count
  local_zxid=$(echo $local_data | awk '{print $1}')
  local_node_count=$(echo $local_data | awk '{print $2}')

#获取server端口数量，目前仅支持相同的端口号
port_num=$(awk -F= '{ if(match($1,"server")!=0) print $2}' $config_file | awk -F: '{print $2}' | sort -u | wc -l)

#判断端口号个数为1
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

#通过stat获取使用server ip的信息
output=$(netstat -n 2>/dev/null| grep -w $server_port)
  if [ -z "$output" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi

#截取tcp连接的本机ip和远程主机ip，以server port结尾的为leader
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
#获取leader的zookeeper数据
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
#如果数据为空，则打印-1
  if [ -z "$leader_data" ];then
     echo zk_zxid_diff: -1
     echo zk_nodecount_diff: -1
     exit 0
  fi
#取得leader的zxid和node_count
  leader_zxid=$(echo $leader_data | awk '{print $1}')
  leader_node_count=$(echo $leader_data | awk '{print $2}')  
#fi
#echo local_zxid: $local_zxid
#echo local_node_cout: $local_node_count
#echo leader_zxid: $leader_zxid
#echo leader_node_count: $leader_node_count

#tr -d -r 去除符号，打印正值
echo zk_zxid_diff: $(($local_zxid -$leader_zxid)) | tr -d -
echo zk_nodecount_diff: $(($local_node_count -$leader_node_count)) | tr -d -

