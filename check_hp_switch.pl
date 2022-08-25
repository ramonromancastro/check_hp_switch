#!/usr/bin/perl -w
# ============================================================================
# ============================== INFO ========================================
# ============================================================================
# Version	: 0.4
# Date		: August 25 2022
# Author	: Ramon Roman Castro ( info@rrc2software.com)
# Based on	: "check_snmp_environment" plugin (version 0.7) from Michiel Timmers
# Licence 	: GPL - summary below
#
# ============================================================================
# ============================== VERSIONS ====================================
# ============================================================================
# version 0.1 : - First version
# version 0.2 : - Add OS Version check
# version 0.3 : - Add check selector, remove OS version check
# version 0.4 : - Add Stack check
#
# ============================================================================
# ============================== LICENCE =====================================
# ============================================================================
# check_hp_switch.pl checks HP switches status.
# Copyright (C) 2022 Ramón Román Castr <ramonromancastro@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc., 59
# Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
# ============================================================================
# ============================== HELP ========================================
# ============================================================================
# Help : ./check_hp_switch.pl --help
#
# ============================================================================
# ============================== To DO =======================================
# ============================================================================
# HpSwitchMgmtModuleVersionEntry
# https://github.com/talkingtontech/observium/blob/master/mibs/hp/hpswitchimage.mib
#
# ============================================================================

use warnings;
use strict;
use Net::SNMP;
use Getopt::Long;
use Switch;

# ============================================================================
# ============================== NAGIOS VARIABLES ============================
# ============================================================================

my $TIMEOUT 			= 15;	# This is the global script timeout, not the SNMP timeout
my %ERRORS				= ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my @Nagios_state 		= ("OK","WARNING","CRITICAL","UNKNOWN","DEPENDENT"); # Nagios states coding


# ============================================================================
# ============================== OID VARIABLES ===============================
# ============================================================================

# MEMORY
my $hpLocalMemFreeBytes  = "1.3.6.1.4.1.11.2.14.11.5.1.1.2.1.1.1.6";
my $hpLocalMemTotalBytes = "1.3.6.1.4.1.11.2.14.11.5.1.1.2.1.1.1.5";

# CPU
my $hpSwitchCpuStat      = "1.3.6.1.4.1.11.2.14.11.5.1.9.6.1";

# SENSORS
my $hpicfSensorTable     = "1.3.6.1.4.1.11.2.14.11.1.2.6";
my $hpicfSensorIndex     = $hpicfSensorTable.".1.1";
my $hpicfSensorObjectId  = $hpicfSensorTable.".1.2";
my $hpicfSensorStatus    = $hpicfSensorTable.".1.4";
my $hpicfSensorDescr     = $hpicfSensorTable.".1.7";

my $icfPowerSupplySensor = "1.3.6.1.4.1.11.2.3.7.8.3.1";
my $icfFanSensor         = "1.3.6.1.4.1.11.2.3.7.8.3.2";
my $icfTemperatureSensor = "1.3.6.1.4.1.11.2.3.7.8.3.3";
my $icfFutureSlotSensor  = "1.3.6.1.4.1.11.2.3.7.8.3.4";

my %hpicrfSensorStatus2Desc = (
	1=>'unknown',
	2=>'bad',
	3=>'warning',
	4=>'good',
	5=>'notPresent');
my %hpicrfSensorStatus2Nagios = (
	1=>'OK',
	2=>'CRITICAL',
	3=>'WARNING',
	4=>'OK',
	5=>'OK');
	
# STACK
my $hpStackOperStatus        = "1.3.6.1.4.1.11.2.14.11.5.1.69.1.1.2.0";
my $hpStackSwitchAdminStatus = "1.3.6.1.4.1.11.2.14.11.5.1.69.1.2.1.2.1";
my $hpStackMemberState       = "1.3.6.1.4.1.11.2.14.11.5.1.69.1.3.1.9";
my $hpStackPortOperStatus    = "1.3.6.1.4.1.11.2.14.11.5.1.69.1.5.1.3";

my %hpStackOperStatus2Desc        = (0=>'unAvailable', 1=>'disabled', 2=>'active', 3=>'fragmentInactive', 4=>'fragmentActive');
my %hpStackOperStatus2Nagios      = (0=>'OK', 1=>'OK', 2=>'OK', 3=>'WARNING', 4=>'WARNING');
my %hpStackSwitchAdminStatus2Desc = (1=>'enable', 2=>'disabled');
my %hpStackMemberState2Desc       = (0=>'unusedId', 1=>'missing', 2=>'provision', 3=>'commander', 4=>'standby', 5=>'member', 6=>'shutdown', 7=>'booting', 8=>'communicationFailure', 9=>'incompatibleOs', 10=>'unknownState', 11=>'standbyBooting');
my %hpStackMemberState2Nagios     = (0=>'OK', 1=>'CRITICAL', 2=>'OK', 3=>'OK', 4=>'OK', 5=>'OK', 6=>'WARNING', 7=>'WARNING', 8=>'CRITICAL', 9=>'CRITICAL', 10=>'CRITICAL', 11=>'WARNING');
my %hpStackPortOperStatus2Desc    = (1=>'up', 2=>'down', 3=>'disabled', 4=>'blocked');
my %hpStackPortOperStatus2Nagios  = (1=>'OK', 2=>'CRITICAL', 3=>'OK', 4=>'WARNING');

# ============================================================================
# ============================== GLOBAL VARIABLES ============================
# ============================================================================

my $Version		= '0.4';	# Version number of this script
my $o_host		= undef; 	# Hostname
my $o_community	= undef; 	# Community
my $o_port	 	= 161; 		# Port
my $o_help		= undef; 	# Want some help ?
my $o_verb		= undef;	# Verbose mode
my $o_version	= undef;	# Print version
my $o_timeout	= undef; 	# Timeout (Default 5)
my $o_perf		= undef;	# Output performance data
my $o_version1	= undef;	# Use SNMPv1
my $o_version2	= undef;	# Use SNMPv2c
my $o_domain	= undef;	# Use IPv6
my $o_login		= undef;	# Login for SNMPv3
my $o_passwd	= undef;	# Pass for SNMPv3
my $v3protocols	= undef;	# V3 protocol list.
my $o_authproto	= 'sha';	# Auth protocol
my $o_privproto	= 'aes';	# Priv protocol
my $o_privpass	= undef;	# priv password
my $o_test		= undef; 	# Test
my $warning_t   = 80;
my $critical_t  = 90;
my $index;
my $mem_used;


# ============================================================================
# ============================== SUBROUTINES (FUNCTIONS) =====================
# ============================================================================

# Subroutine: Print version
sub p_version { 
	print "check_hp_switch.pl version : $Version\n"; 
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-v] -H <host> [-6] -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] [-f] [-t <timeout>] -T <check> [-V]\n";
}

# Subroutine: Check number
sub isnnum { # Return true if arg is not a number
	my $num = shift;
	if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
	return 1;
}

# Subroutine: Set final status
sub set_status { # Return worst status with this order : OK, unknown, warning, critical 
	my $new_status = shift;
	my $cur_status = shift;
	if ($new_status == 1 && $cur_status != 2) {$cur_status = $new_status;}
	if ($new_status == 2) {$cur_status = $new_status;}
	if ($new_status == 3 && $cur_status == 0) {$cur_status = $new_status;}
	return $cur_status;
}

# Subroutine: Check if SNMP table could be retrieved, otherwise give error
sub check_snmp_result {
	my $snmp_table		= shift;
	my $snmp_error_mesg	= shift;

	# Check if table is defined and does not contain specified error message.
	# Had to do string compare it will not work with a status code
	# if (!defined($snmp_table) && $snmp_error_mesg !~ /table is empty or does not exist/) {
	if (!defined($snmp_table)) {
		printf("ERROR: ". $snmp_error_mesg . "\n");
		exit $ERRORS{"UNKNOWN"};
	}
}

# Subroutine: Check if SNMP values could be retrieved, otherwise give error
sub check_snmp_request {
	my $snmp_request		= shift;
	my $snmp_error_mesg	= shift;

	if (!defined($snmp_request)) {
		printf("ERROR: ". $snmp_error_mesg . "\n");
		exit $ERRORS{"UNKNOWN"};
	}
	
	foreach my $key (sort keys %$snmp_request){
		if ( $snmp_request->{$key} =~ /noSuchObject/ || $snmp_request->{$key} =~ /noSuchInstance/){
			printf("ERROR: Unable to read OID $key\n");
			exit $ERRORS{"UNKNOWN"};
		}
	}
}

# Subroutine: Print complete help
sub help {
	print "\nHP switch SNMP plugin for Nagios\nVersion: ",$Version,"\n\n";
	print_usage();
	print <<EOT;

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

EOT
}

# Subroutine: Verbose output
sub verb { 
	my $t=shift; 
	print $t,"\n" if defined($o_verb); 
}

# Subroutine: Verbose output
sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'		=> \$o_verb,		'verbose'		=> \$o_verb,
        'h'     => \$o_help,    	'help'      	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'		=> \$o_port,
        'C:s'   => \$o_community,	'community:s'	=> \$o_community,
		'l:s'	=> \$o_login,		'login:s'		=> \$o_login,
		'x:s'	=> \$o_passwd,		'passwd:s'		=> \$o_passwd,
		'X:s'	=> \$o_privpass,	'privpass:s'	=> \$o_privpass,
		'L:s'	=> \$v3protocols,	'protocols:s'	=> \$v3protocols,   
        't:i'   => \$o_timeout,    	'timeout:i'     => \$o_timeout,
        'T:s'   => \$o_test,    	'test:s'     	=> \$o_test,
		'V'		=> \$o_version,		'version'		=> \$o_version,
		'6'     => \$o_domain,     	'use-ipv6'      => \$o_domain,
		'1'     => \$o_version1,	'v1'            => \$o_version1,
		'2'     => \$o_version2,	'v2c'           => \$o_version2,
        'f'     => \$o_perf,		'perfparse'     => \$o_perf
	);

	# Basic checks
	if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) { 
		print "Timeout must be >1 and <60 !\n";
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	}
	
	if (!defined($o_timeout)) {
		$o_timeout=5;
	}
	if (defined ($o_help) ) {
		help();
		exit $ERRORS{"UNKNOWN"};
	}

	if (defined($o_version)) { 
		p_version(); 
		exit $ERRORS{"UNKNOWN"};
	}

	# check host and filter 
	if ( ! defined($o_host) ) {
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	}

	# Check IPv6 
	if (defined ($o_domain)) {
		$o_domain="udp/ipv6";
	} else {
		$o_domain="udp/ipv4";
	}

	# Check SNMP information
	if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) ){ 
		print "Put SNMP login info!\n"; 
		print_usage(); 
		exit $ERRORS{"UNKNOWN"};
	}
	if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) ){ 
		print "Can't mix SNMP v1,v2c,v3 protocols!\n"; 
		print_usage(); 
		exit $ERRORS{"UNKNOWN"};
	}

	# Check SNMPv3 information
	if (defined ($v3protocols)) {
		if (!defined($o_login)) { 
			print "Put SNMP V3 login info with protocols!\n"; 
			print_usage(); 
			exit $ERRORS{"UNKNOWN"};
		}
		my @v3proto=split(/,/,$v3protocols);
		if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {
			$o_authproto=$v3proto[0];
		}
		if (defined ($v3proto[1])) {
			$o_privproto=$v3proto[1];
		}
		if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
			print "Put SNMP v3 priv login info with priv protocols!\n";
			print_usage(); 
			exit $ERRORS{"UNKNOWN"};
		}
	}
}


# ============================================================================
# ============================== MAIN ========================================
# ============================================================================

check_options();

# Check gobal timeout if SNMP screws up
if (defined($TIMEOUT)) {
	verb("Alarm at ".$TIMEOUT." + ".$o_timeout);
	alarm($TIMEOUT+$o_timeout);
} else {
	verb("no global timeout defined : ".$o_timeout." + 15");
	alarm ($o_timeout+15);
}

# Report when the script gets "stuck" in a loop or takes to long
$SIG{'ALRM'} = sub {
	print "UNKNOWN: Script timed out\n";
	exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
if (defined($o_login) && defined($o_passwd)) {
	# SNMPv3 login
	verb("SNMPv3 login");
	if (!defined ($o_privpass)) {
		# SNMPv3 login (Without encryption)
		verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 3,
		-username	=> $o_login,
		-authpassword	=> $o_passwd,
		-authprotocol	=> $o_authproto,
		-timeout	=> $o_timeout
	);  
	} else {
		# SNMPv3 login (With encryption)
		verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 3,
		-username	=> $o_login,
		-authpassword	=> $o_passwd,
		-authprotocol	=> $o_authproto,
		-privpassword	=> $o_privpass,
		-privprotocol	=> $o_privproto,
		-timeout	=> $o_timeout
		);
	}
} else {
	if ((defined ($o_version2)) || (!defined ($o_version1))) {
		# SNMPv2 login
		verb("SNMP v2c login");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 2,
		-community	=> $o_community,
		-port		=> $o_port,
		-timeout	=> $o_timeout
		);
	} else {
		# SNMPv1 login
		verb("SNMP v1 login");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 1,
		-community	=> $o_community,
		-port		=> $o_port,
		-timeout	=> $o_timeout
		);
	}
}

# Check if there are any problems with the session
if (!defined($session)) {
	printf("ERROR opening session: %s.\n", $error);
	exit $ERRORS{"UNKNOWN"};
}

my ($exit_val,$critical,$warning,$output,$perfdata)=($ERRORS{"UNKNOWN"},0,0,"","");


sub check_cpu(){
	### CPU ###
	my $result_hpSwitchCpuStat = $session->get_table(Baseoid => $hpSwitchCpuStat);
	&check_snmp_result($result_hpSwitchCpuStat,$session->error);
	if(!defined($result_hpSwitchCpuStat)){
		printf("ERROR: Missing OID\n");
		exit $ERRORS{"UNKNOWN"};
	}
	foreach my $key (sort keys %$result_hpSwitchCpuStat){
		verb("OID : $key, Text: $$result_hpSwitchCpuStat{$key}");
		$index = $key;
		$index =~ s/$hpSwitchCpuStat\.//;
		$perfdata .= "cpu_$index=$$result_hpSwitchCpuStat{$key}% ";
		$output = "$output\nCPU ($index): $$result_hpSwitchCpuStat{$key}%";
		if ($$result_hpSwitchCpuStat{$key} > $critical_t) {$critical++;}
		elsif ($$result_hpSwitchCpuStat{$key} > $warning_t) {$warning++;}
	}
}

sub check_memory(){
	### MEMORY ###
	my $result_hpLocalMemFreeBytes = $session->get_table(Baseoid => $hpLocalMemFreeBytes);
	&check_snmp_result($result_hpLocalMemFreeBytes,$session->error);
	my $result_hpLocalMemTotalBytes = $session->get_table(Baseoid => $hpLocalMemTotalBytes);
	&check_snmp_result($hpLocalMemTotalBytes,$session->error);

	foreach my $key (sort keys %$result_hpLocalMemTotalBytes){
		verb("OID : $key, Text: $$result_hpLocalMemTotalBytes{$key}");
		$index = $key;
		$index =~ s/$hpLocalMemTotalBytes\.//;
		$mem_used = int((($$result_hpLocalMemTotalBytes{"$hpLocalMemTotalBytes.$index"}-$$result_hpLocalMemFreeBytes{"$hpLocalMemFreeBytes.$index"})/$$result_hpLocalMemTotalBytes{"$hpLocalMemTotalBytes.$index"})*100);
		$perfdata .= "mem_$index=$mem_used% ";
		$output = "$output\nMem ($index): $mem_used%";
		if ($mem_used > $critical_t) {$critical++;}
		elsif ($mem_used > $warning_t) {$warning++;}
	}
}

sub check_sensor{
	my $sensor_id = shift;
	my $sensor_exists = 0;
	
	### SENSORS ###
	my $result_hpicfSensorStatus = $session->get_table(Baseoid => $hpicfSensorStatus);
	&check_snmp_result($result_hpicfSensorStatus,$session->error);
	my $result_hpicfSensorDescr = $session->get_table(Baseoid => $hpicfSensorDescr);
	&check_snmp_result($result_hpicfSensorDescr,$session->error);
	my $result_hpicfSensorObjectId = $session->get_table(Baseoid => $hpicfSensorObjectId);
	&check_snmp_result($result_hpicfSensorObjectId,$session->error);

	foreach my $key (sort keys %$result_hpicfSensorStatus){
		verb("OID : $key, Text: $$result_hpicfSensorStatus{$key}");
		$index = $key;
		$index =~ s/$hpicfSensorStatus\.//;
		if ($sensor_id eq $$result_hpicfSensorObjectId{"$hpicfSensorObjectId.$index"}){
			$sensor_exists = 1;
			$output = "$output\n".$$result_hpicfSensorDescr{"$hpicfSensorDescr.$index"}." ($index): $hpicrfSensorStatus2Desc{$$result_hpicfSensorStatus{$key}}";
			switch ($hpicrfSensorStatus2Nagios{$$result_hpicfSensorStatus{$key}}) {
				case "CRITICAL" {$critical++;}
				case "WARNING" {$warning++;}
			}
		}
	}
	if (!$sensor_exists){
		$output = "$output\nNo sensors detected";
	}
}

sub check_stack(){
	# my $result_hpStackOperStatus = $session->get_table(Baseoid => $hpStackOperStatus);
	my $result = $session->get_request(-varbindlist => [ $hpStackOperStatus, $hpStackSwitchAdminStatus ],);
	&check_snmp_request($result,$session->error);
	
	verb("OID : $hpStackSwitchAdminStatus, Text: $result->{$hpStackSwitchAdminStatus}");
	verb("OID : $hpStackOperStatus, Text: $result->{$hpStackOperStatus}");
	
	switch ($hpStackOperStatus2Nagios{$result->{$hpStackOperStatus}}) {
		case "CRITICAL" {$critical++;}
		case "WARNING" {$warning++;}
	}
	
	$output = "$output\nSwitchAdminStatus: $hpStackSwitchAdminStatus2Desc{$result->{$hpStackSwitchAdminStatus}}";
	$output = "$output\nOperStatus: $hpStackOperStatus2Desc{$result->{$hpStackOperStatus}}";
	
	if (($result->{$hpStackSwitchAdminStatus} == 1) && ($result->{$hpStackOperStatus} >= 2)){
		my $result = $session->get_table(Baseoid => $hpStackMemberState);
		&check_snmp_result($result,$session->error);
	
		foreach my $key (sort keys %$result){
			verb("OID : $key, Text: $$result{$key}");
			$index = $key;
			$index =~ s/$hpStackMemberState\.//;
			$output = "$output\nMemberState $index: $hpStackMemberState2Desc{$$result{$key}}";
			switch ($hpStackMemberState2Nagios{$$result{$key}}) {
				case "CRITICAL" {$critical++;}
				case "WARNING" {$warning++;}
			}
		}
		
		$result = $session->get_table(Baseoid => $hpStackPortOperStatus);
		&check_snmp_result($result,$session->error);
	
		foreach my $key (sort keys %$result){
			verb("OID : $key, Text: $$result{$key}");
			$index = $key;
			$index =~ s/$hpStackPortOperStatus\.//;
			$output = "$output\nPortOperStatus $index: $hpStackPortOperStatus2Desc{$$result{$key}}";
			switch ($hpStackPortOperStatus2Nagios{$$result{$key}}) {
				case "CRITICAL" {$critical++;}
				case "WARNING" {$warning++;}
			}
		}
	}
	
}

# ============================================================================
# ============================== HH3C =======================================
# ============================================================================

verb("Checking HP switch env");

### MAIN CODE

switch ($o_test) { 
    case "cpu" { check_cpu ; }
	case "fan" { check_sensor($icfFanSensor) ; }
	case "future" { check_sensor($icfFutureSlotSensor) ; }
	case "memory" { check_memory; }
	case "power" { check_sensor($icfPowerSupplySensor) ; }
	case "stack" { check_stack ; }
	case "temp" { check_sensor($icfTemperatureSensor) ; }
	else {
		help();
		exit $ERRORS{"UNKNOWN"};
	}
}

if ($critical > 0){
	$exit_val = $ERRORS{"CRITICAL"};
}
elsif ($warning > 0){
	$exit_val = $ERRORS{"WARNING"};
}
else{
	$exit_val = $ERRORS{"OK"};
}
print "Status: $Nagios_state[$exit_val]$output|$perfdata";
exit $exit_val;
