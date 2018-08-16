#!/bin/bash
  dir=$(cd `dirname $0`;pwd)
  read -p "请输入要监控的端口号:" net
  read -p "请输入要监控的时间(天为单位):" day
  mkdir $dir/$net
  touch $dir/$net/${net}.sh
  date=$(date +%Y%m%d)
  echo '账号创建时间:'$date > $dir/$net/start_time
(
cat << EOF
while true; 
do
  sleep 10
  over_date=\$(date -d "+${day} day" +%Y%m%d)
  if [ $date -eq \$over_date ];then
      iptables -A OUTPUT -p tcp --sport $net -j DROP
      iptables -A INPUT -p tcp --sport $net -j DROP
      ps aux|grep $net|grep -v 'grep'|awk '{print \$2}'|xargs kill -9
  fi
done
EOF
) > $dir/$net/${net}.sh
nohup sh $dir/$net/${net}.sh & >/dev/null 2>&1
