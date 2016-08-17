updateBlacklist
===================

This script will:
  * Grab the lastest [list of malicious IPs](http://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt) from the folks at [Emerging Threats (now Proofpoint)](http://www.emergingthreats.net). The list combines known malicious addresses from feeds provided by Spamhaus, abuse.ch and DShield.
  * Also grab the latest batch of malicious addresses from [Spamhaus EDROP](http://www.spamhaus.org/drop/edrop.txt) and the Blocklist.de [SSH](http://lists.blocklist.de/lists/ssh.txt) and [BruteForce](https://lists.blocklist.de/lists/bruteforcelogin.txt) lists.
  * Parse them into two separate lists, one comprised of CIDRs and one comprised of hosts only
  * Update two firewall groups with these addresses
  * Commit and save the configuration
  
The script was created to leverage the `vyatta-cfg-cmd-wrapper` utility, as opposed to other implementions that use `ipset` directly, and this approach ensures that the VyOS configuration always reflects the list of IPs being blocked.

Installation
---------

  * Ensure you've got an `ag-Blacklist` address-group and a `ng-Blacklist` network-group in your firewall configuration:
  
  ```
  set firewall group address-group ag-Blacklist description "Designated threat addresses"
  set firewall group network-group ng-Blacklist description "Designated threat networks"
  commit
  save
  exit
  ```
  
  * Download the latest copy of updateETBlocklist.sh:
  
  ```
  wget -q https://github.com/bradpeczka/vyos/updateBlacklist/raw/master/updateBlacklist.sh -O /config/scripts/updateBlacklist.sh
  ```
  
  * Make it executable:
  
  ```
  chmod +x /config/scripts/updateBlacklist.sh
  ```
  
  * Add the following configuration to ensure it auto-updates:
  
  ```
  set system task-scheduler task updateBlacklist interval 1d
  set system task-scheduler task updateBlacklist executable path /config/scripts/updateBlacklist.sh
  commit
  save
  exit
  ```
  
  * Add the ag-Blacklist and ng-Blacklist groups to your firewall in an appropriate place; I generally use WAN_IN but you might use something different:
  
  ```
  set firewall name WAN_IN rule 1010 action 'drop'
  set firewall name WAN_IN rule 1010 description 'Drop traffic from blacklisted networks'
  set firewall name WAN_IN rule 1010 source group network-group 'ng-EmergingThreats'
  set firewall name WAN_IN rule 1011 action 'drop'
  set firewall name WAN_IN rule 1011 description 'Drop traffic from blacklisted addresses'
  set firewall name WAN_IN rule 1011 source group address-group 'ag-EmergingThreats'
  commit
  save
  exit
  ```
  
  * ..?
  * ..profit!
  
Requirements
------------

Tested on VyOS 1.1.7 (helium). Should also work on the Brocade vRouter; *may* work on Ubiquiti EdgeOS but I suspect the performance will be less than optimal. My VyOS install is on an Intel Xeon E5-2670, and a normal update run completes in ~3 minutes with ~4500 addresses.

Credits
-------

Special mention and thanks to:
  * [UBNT-stig](https://community.ubnt.com/t5/EdgeMAX/Emerging-Threats-Blacklist/m-p/801422#M28771) for his work on the `update-ET-groups` script for EdgeOS, which inspired this script.
  * [ForDoDone](https://fordodone.com/2013/10/01/vyatta-create-and-update-ip-based-ban-lists-from-spamhaus/) for his `updateBanList.sh` script.

License
-------

This script is distributed under the terms of the BSD New License as published by the Regents of the University of California.

### Copyright

  Copyright (c) Brad Peczka

### Authors
  
  Brad Peczka
  (brad |at| bradpeczka |dot| com)
