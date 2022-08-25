# check_hp_switch
Nagios plugin for HP switches

## Devices tested

- HP 2530 Switch Series
- HP 2920 Switch Series
- HP ProCurve Switch 2500 Series

## Usage

```
Usage: ./check_hp_switch.pl [-v] -H <host> [-6] -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] [-f] [-t <timeout>] -T <check> [-V]

Options:
-v, --verbose
   Print extra debugging information
-h, --help
   Print this help message
-H, --hostname=HOST
   Hostname or IPv4/IPv6 address of host to check
-6, --use-ipv6
   Use IPv6 connection
-C, --community=COMMUNITY NAME
   Community name for the host's SNMP agent
-1, --v1
   Use SNMPv1
-2, --v2c
   Use SNMPv2c (default)
-l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for SNMPv3 authentication
   If no priv password exists, implies AuthNoPriv
-X, --privpass=PASSWD
   Priv password for SNMPv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default sha)
   <privproto> : Priv protocol (des|aes : default aes)
-P, --port=PORT
   SNMP port (Default 161)
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   Timeout for SNMP in seconds (Default: 5)
-T, --test=<check>
   cpu     : CPU
   fan     : Fans
   future  : FutureSlot
   memory  : Memory
   power   : Power supply
   stack   : Stack
   temp    : Temperature
-V, --version
   Prints version number
```
