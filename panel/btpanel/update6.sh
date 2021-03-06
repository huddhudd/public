#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

clear
if [ ! -d /www/server/panel/BTPanel ];then
	echo "============================================="
	echo "错误, 5.x不可以使用此命令升级!"
	echo "5.9平滑升级到6.0的命令：curl https://download.ccspump.com/install/update_to_6.sh|bash"
	exit 0;
fi

public_file=/www/server/panel/install/public.sh
if [ ! -f $public_file ];then
	wget -O $public_file $btsb_Url/install/public.sh -T 20;
fi

publicFileMd5=$(md5sum ${public_file}|awk '{print $1}')
md5check="db0bc4ee0d73c3772aa403338553ff77"
if [ "${publicFileMd5}" != "${md5check}"  ]; then
	wget -O $public_file $btsb_Url/install/public.sh -T 20;
fi

. $public_file

download_Url=$NODE_URL
btsb_Url=https://download.ccspump.com
setup_path=/www
version=$(curl -Ss --connect-timeout 5 -m 2 http://www.bt.cn/api/panel/get_version)
if [ "$version" = '' ];then
	version='7.1.1'
fi

chattr -i /www/server/panel/install/public.sh
chattr -i /www/server/panel/install/check.sh
wget -T 5 -O /tmp/panel.zip $btsb_Url/install/update/LinuxPanel-7.1.1.zip
dsize=$(du -b /tmp/panel.zip|awk '{print $1}')
if [ $dsize -lt 10240 ];then
	echo "获取更新包失败，请稍后更新或联系宝塔运维"
	exit;
fi
unzip -o /tmp/panel.zip -d $setup_path/server/ > /dev/null
wget -O /www/server/panel/install/check.sh ${btsb_Url}/install/check.sh -T 10
chattr +i /www/server/panel/install/public.sh
chattr +i /www/server/panel/install/check.sh
rm -f /tmp/panel.zip
cd $setup_path/server/panel/
check_bt=`cat /etc/init.d/bt`
if [ "${check_bt}" = "" ];then
	rm -f /etc/init.d/bt
	wget -O /etc/init.d/bt $download_Url/install/src/bt6.init -T 20
	chmod +x /etc/init.d/bt
fi
rm -f /www/server/panel/*.pyc
rm -f /www/server/panel/class/*.pyc

pip_list=$(pip list)
request_v=$(echo "$pip_list"|grep requests)
if [ "$request_v" = "" ];then
	pip install requests
fi
openssl_v=$(echo "$pip_list"|grep pyOpenSSL)
if [ "$openssl_v" = "" ];then
	pip install pyOpenSSL
fi

cffi_v=$(echo "$pip_list"|grep cffi|grep 1.12.)
if [ "$cffi_v" = "" ];then
	pip install cffi==1.12.3
fi

pymysql=$(echo "$pip_list"|grep pymysql)
if [ "$pymysql" = "" ];then
	pip install pymysql
fi

pip install -U psutil

chattr -i /etc/init.d/bt
chmod +x /etc/init.d/bt
echo "====================================="

firewall_restart(){
	if [[ ${release} == 'centos' ]]; then
		if [[ ${version} -ge '7' ]]; then
			firewall-cmd --reload
		else
			service iptables save
			if [ -e /root/test/ipv6 ]; then
				service ip6tables save
			fi
		fi
	else
		iptables-save > /etc/iptables.up.rules
		if [ -e /root/test/ipv6 ]; then
			ip6tables-save > /etc/ip6tables.up.rules
		fi
	fi
	echo -e "${Info}防火墙设置完成！"
}
add_firewall(){
	if [[ ${release} == 'centos' &&  ${version} -ge '7' ]]; then
		if [[ -z $(firewall-cmd --zone=public --list-ports |grep -w ${port}/tcp) ]]; then
			firewall-cmd --zone=public --add-port=${port}/tcp --add-port=${port}/udp --permanent >/dev/null 2>&1
		fi
	else
		if [[ -z $(iptables -nvL INPUT |grep :|awk -F ':' '{print $2}' |grep -w ${port}) ]]; then
			iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
			iptables -I INPUT -p udp --dport ${port} -j ACCEPT
			iptables -I OUTPUT -p tcp --sport ${port} -j ACCEPT
			iptables -I OUTPUT -p udp --sport ${port} -j ACCEPT
			if [ -e /root/test/ipv6 ]; then
				ip6tables -I INPUT -p tcp --dport ${port} -j ACCEPT
				ip6tables -I INPUT -p udp --dport ${port} -j ACCEPT
				ip6tables -I OUTPUT -p tcp --sport ${port} -j ACCEPT
				ip6tables -I OUTPUT -p udp --sport ${port} -j ACCEPT
			fi
		fi
	fi
}
port=2020 && add_firewall && firewall_restart
rm -rf /dev/shm/bt_sql_tips.pl
/etc/init.d/bt start
echo 'True' > /www/server/panel/data/restart.pl
pkill -9 gunicorn &
echo "已成功升级到$version专业版"
echo "为了保障本机安全性，从现在起开心版面板端口为:2020"
echo "若面板无法访问，请放行安全组，以及关闭机器的防火墙！"
rm -rf update6.sh