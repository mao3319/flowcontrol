#!/bin/bash
dir=$(cd `dirname $0`;pwd)
read -p "请输入要监控的端口号:" net
read -p "请输入要监控的流量大小(以G为单位):"  flow_size
read -p "限制同时使用的IP数量:" ip_control
check=$(iptables -L -n -v|grep $net)
mkdir $dir/$net
touch $dir/$net/input
touch $dir/$net/output
touch $dir/$net/${net}.sh
if [[ -n $check ]];then
    read -p '已设置，是否重新覆盖(y/n)' answer
    if [[ $answer == 'y' ]];then
        iptables -D INPUT -p tcp --dport $net
        iptables -D OUTPUT -p tcp --sport $net
        iptables -A INPUT -p tcp --dport $net
        iptables -A OUTPUT -p tcp --sport $net
    fi
else
        iptables -A INPUT -p tcp --dport $net
        iptables -A OUTPUT -p tcp --sport $net
fi
(
cat << EOF
while true; 
do
  sleep 10
  iptables -L -v -n|grep $net|grep dpt|awk '{print \$2}'|sed -n '1p' >> $dir/$net/input
  iptables -L -v -n|grep $net|grep spt|awk '{print \$2}'|sed -n '1p' >> $dir/$net/output
  out=\$(tail -n 1 $dir/$net/output |tr -cd "[A-Z]")
  in=\$(tail -n 1 $dir/$net/input |tr -cd "[A-Z]")
  ip_number=\$(netstat -an|grep $net|grep ESTABLISHED|awk '{print \$5}'|cut -d ':' -f 1|sort -u|wc -l)
  if [ \$ip_number -gt $ip_control ];then
    echo -e "`date +%Y%m%d%k%M`   在线人数:$ip_number,超过了" >> $dir/$net/ip_over
    iptables -A OUTPUT -p tcp --sport $net -j DROP
    iptables -A INPUT -p tcp --sport $net -j DROP
  else
    iptables -D OUTPUT -p tcp --sport $net -j DROP
    iptables -D INPUT -p tcp --sport $net -j DROP
  fi
  case \$out in
     G)
        flow_input=\$(tail -n 1 $dir/$net/input|awk 'BEGIN{FS="G"}{print \$1}')
	flow_output=\$(tail -n 1 $dir/$net/output|awk 'BEGIN{FS="G"}{print \$1}')
        if [[ \$flow_input -ge $flow_size ]] || [[ \$flow_output -ge $flow_size ]];then
	   iptables -A OUTPUT -p tcp --sport $net -j DROP
           iptables -A INPUT -p tcp --sport $net -j DROP
	   mv $dir/$net $dir/${net}_overload
           ps aux|grep $net|grep -v 'grep $net'|awk '{print \$2}'|xargs kill -9
	fi
     ;;
   esac
   case \$in in
    G)
        flow_input=\$(tail -n 1 $dir/$net/input|awk 'BEGIN{FS="G"}{print \$1}')
        flow_output=\$(tail -n 1 $dir/$net/output|awk 'BEGIN{FS="G"}{print \$1}')
        if [[ \$flow_input -ge $flow_size ]] || [[ \$flow_output -ge $flow_size ]];then
           iptables -A OUTPUT -p tcp --sport $net -j DROP
           iptables -A INPUT -p tcp --sport $net -j DROP
           mv $dir/$net $dir/${net}_overload
	   ps aux|grep $net|grep -v 'grep $net'|awk '{print \$2}'|xargs kill -9
        fi
    ;;
   esac
done
EOF
) > $dir/$net/${net}.sh
nohup sh $dir/$net/${net}.sh & >/dev/null 2>&1
