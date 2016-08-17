#!/bin/bash
# FILE: /config/scripts/updateBlacklist.sh
# AUTHOR: Brad Peczka <brad@bradpeczka.com>
# DATE: 2016-08-17
# NOTES: Script to dynamically update firewall ruleset with latest addreses from a variety of online blocklists

# variables
VERBOSE=0
BLACKLIST_FILE=/config/user-data/ip-blacklist.list

# simple logger function
logger(){
  if [ "$VERBOSE" == "1" ];
  then
    /usr/bin/logger -t updateBlacklist -p local0.notice "$@" 
    echo "$@"
  fi
}

# make pushd quiet
pushd () {
    command pushd "$@" > /dev/null
}

# set verbose flag if given
if [ "$1" == "-v" ]
then
VERBOSE=1;
fi

# change to our user-data directory for all this work
pushd /config/user-data

# backup the old consolidated list
if [ -f ip-blacklist.list ]; then
  mv ip-blacklist.list ip-blacklist-old.list
fi

# set the blacklist array up
BLACKLIST_ARRAY=(
"http://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" # Emerging Threats
"http://www.spamhaus.org/drop/edrop.txt" # Spamhaus Drop Nets
"http://lists.blocklist.de/lists/ssh.txt" # SSH Blocklist
"https://lists.blocklist.de/lists/bruteforcelogin.txt" #BruteForce Blocklist
)

# check our commands are available
for command in egrep grep curl sort uniq wc
do
	if ! which $command > /dev/null; then
		logger "Error: Please install $command"
		exit 1
	fi
done

# grab the lists and merge
BLACKLIST_TMP=$(mktemp)
for i in "${BLACKLIST_ARRAY[@]}"
do
	IP_TMP=$(mktemp)
	HTTP_RC=`curl --connect-timeout 10 --max-time 10 -o $IP_TMP -s -w "%{http_code}" "$i"`
	if [ $HTTP_RC -eq 200 -o $HTTP_RC -eq 302 ]; then
		grep -Po '(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' $IP_TMP >> $BLACKLIST_TMP
		logger "Success: Received $i"
	else
		logger "Warning: curl returned HTTP response code $HTTP_RC for URL $i"
	fi
rm $IP_TMP
done

# sanity check in case localhost is being blocked
sort $BLACKLIST_TMP -n | uniq | sed -e '/^127.0.0.0\|127.0.0.1\|0.0.0.0/d' > $BLACKLIST_FILE
rm $BLACKLIST_TMP

logger "Info: Received `wc -l $BLACKLIST_FILE | awk '{print $1}'` blacklisted IP/networks..."

logger "Info: Starting vyatta cmd wrapper.."
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin

# remove existing network list, in case a network has been removed"
logger "Info: Updating blacklisted network group..."
START=$(date +"%s")
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall group network-group ng-Blacklist

# add each network to the block list
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group network-group ng-Blacklist description "Designated threat networks"

for i in `cat $BLACKLIST_FILE | egrep '^[0-9]' | egrep '/'`;
do
  /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group network-group ng-Blacklist network $i
done;

# now commit the changes
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit
END=$(date +"%s")
DIFF=$(($END-$START))
logger "Success: Network group updated in $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds!"

# remove existing ET-A list, in case an address has been removed"
logger "Info: Updating blacklisted address group..."
START=$(date +"%s")
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete firewall group address-group ag-Blacklist

# add each address to the block list
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group ag-Blacklist description "Designated threat addresses"

#for i in `cat /tmp/block|egrep '^[0-9]'|egrep -v '/' |sed "s/$/\/32/"`;
for i in `cat $BLACKLIST_FILE | egrep '^[0-9]' | egrep -v '/'`;
do
  /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set firewall group address-group ag-Blacklist address $i
done;

# now commit the changes
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit
END=$(date +"%s")
DIFF=$(($END-$START))
logger "Success: Address group updated in $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds!"

logger "Info: Ending vyatta cmd wrapper..."
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper end

# clean up
chown -R root:vyattacfg /opt/vyatta/config/active/
logger "Script complete!"
