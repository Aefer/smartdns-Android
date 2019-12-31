#!/bin/sh
rm -rf /tmp/smartdns
mkdir /tmp/smartdns
cd /tmp/smartdns

#Update configuration file
wget --retry-connrefused --waitretry=2 -O yhosts_union.conf.tmp https://raw.githubusercontent.com/vokins/yhosts/master/dnsmasq/union.conf && sed -i 's/=\/./ \//' yhosts_union.conf.tmp && sed -i 's/0.0.0.0/#/' yhosts_union.conf.tmp &
pid1=$!
wget -b --retry-connrefused --waitretry=2 -O yhosts_ip.conf.tmp https://raw.githubusercontent.com/vokins/yhosts/master/dnsmasq/ip.conf
pid2=$!
wget --retry-connrefused --waitretry=2 -O gfwlist.conf.tmp https://cokebar.github.io/gfwlist2dnsmasq/dnsmasq_gfwlist.conf && sed -i 's/127.0.0.1#5353/secure/' gfwlist.conf.tmp && sed -i 's/server/nameserver/' gfwlist.conf.tmp &
pid3=$!
wget -b --retry-connrefused --waitretry=2 -O googlehosts.conf.tmp https://raw.githubusercontent.com/googlehosts/hosts/master/hosts-files/dnsmasq.conf
pid4=$!
wget -b --retry-connrefused --waitretry=2 -O googlehosts_ipv6.conf.tmp https://raw.githubusercontent.com/googlehosts/hosts-ipv6/master/hosts-files/dnsmasq.conf
pid5=$!
wait $pid1
wait $pid2
wait $pid3
wait $pid4
wait $pid5
sed -i '/^#/d' *.conf.tmp
sed -i 's/=/ /' *.conf.tmp
mv yhosts_union.conf.tmp yhosts_union.conf
mv yhosts_ip.conf.tmp yhosts_ip.conf
mv googlehosts.conf.tmp googlehosts.conf
mv googlehosts_ipv6.conf.tmp googlehosts_ipv6.conf
mv gfwlist.conf.tmp gfwlist.conf

wget --retry-connrefused --waitretry=2 -O hosts_ipv6_lennylxx.tmp https://raw.githubusercontent.com/lennylxx/ipv6-hosts/master/hosts && dos2unix hosts_ipv6_lennylxx.tmp &
pid1=$!
wget -b --retry-connrefused --waitretry=2 -O hosts_PL.tmp 'https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&mimetype=plaintext'
pid2=$!
wget --retry-connrefused --waitretry=2 -O hosts_malware.tmp.1 https://mirror1.malwaredomains.com/files/domains.hosts && awk -F '#' '($1) {print $1}' hosts_malware.tmp.1 > hosts_malware.tmp && rm -f hosts_malware.tmp.1 &
pid3=$!
wget --retry-connrefused --waitretry=2 -O hosts_yhosts.tmp https://raw.githubusercontent.com/vokins/yhosts/master/hosts.txt && sed -i '/^@/d' hosts_yhosts.tmp &
pid4=$!
wget -b --retry-connrefused --waitretry=2 -O hosts_adwars.tmp https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts
pid5=$!
wget --retry-connrefused --waitretry=2 -O hosts_neo.tmp https://cdn.jsdelivr.net/gh/neoFelhz/neohosts@gh-pages/full/hosts && dos2unix hosts_neo.tmp &
pid6=$!
wget -b --retry-connrefused --waitretry=2 -O hosts_hp.tmp https://hosts-file.net/ad_servers.txt
pid7=$!
wget -b --retry-connrefused --waitretry=2 -O hosts_adguard.tmp https://raw.githubusercontent.com/r-a-y/mobile-hosts/master/AdguardDNS.txt
pid8=$!
wait $pid1
wait $pid2
wait $pid3
wait $pid4
wait $pid5
wait $pid6
wait $pid7
wait $pid8
awk '/^2/ {printf"address /%s/%s\n",$2,$1}' hosts_ipv6_lennylxx.tmp > hosts_ipv6_lennylxx
cat hosts_*.tmp > hosts_all.tmp
sed -i '/^#/d' hosts_all.tmp
sed -i 's/127.0.0.1/#/' hosts_all.tmp
sed -i 's/0.0.0.0/#/' hosts_all.tmp
sed -i 's/::/#/' hosts_all.tmp
sort -u hosts_all.tmp > hosts_all.tmp.1
awk '/^#/ {printf"address /%s/%s\n",$2,$1}' hosts_all.tmp.1 > hosts_all && rm -f hosts_all.tmp.1
rm -f hosts_*.tmp wget-log*
tar -cJ -C /tmp -f smartdns.tar.xz --exclude smartdns.tar.xz smartdns
cd /tmp
git clone https://github.com/Aefer/smartdns-Android.git
mv smartdns smartdns-Android/config/configs
git commit -c "Configs update"
echo $gitpassword > ~/.gitpassword
git push
