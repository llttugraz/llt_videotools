#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;


# Copyright 2016-2017 Graz University of Technology – "Educational Technology" https://elearning.tugraz.at
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


{ # MAIN
	$| = 1;
	my $usage = 'usage: ~ perl acl2oc.pl --series <OC_series_ID> {--role <OC_custom_role> --mcourse <Moodle_course_ID>} [--host <OC_url> --username <OC_digest_username> --password <OC_digest_password> --newacl]';
	my $series;
	my @ocRoleIn;
	my $aclActionBase = '{"action":"read","allow":true,"role":"**role**"},{"action":"write","allow":**write**,"role":"**role**"}';
	my @mCourseIn;
	my $newAcl = 0;
	my $host;
	my $http;
	my $username;
	my $password;
	my $aclPre = '{"acl":{"ace":[';
	my $aclPost = ']}}';
	my $aclPreQ = quotemeta($aclPre);
	my $aclPostQ = quotemeta($aclPost);
	my $acl;
	my $aclCmd;
	my $usrCreateCmd;
	my $usrCreateRoles = "\'" . 'roles=[]' . "\'";
	my $usrDeleteCmd;
	my $configFile = './config/config.ini';
	
	# greet
	print "\nHello :-)\n\n";
	
	# check config file
	print "Reading configuration parameters...\n";
	open (my $cfh, '<:encoding(UTF-8)', $configFile) or die "Could not open file '$configFile' $!";

	while (my $row = <$cfh>) {
  		chomp $row;
  		if ($row =~ /^\#.*/) {
  			next;
  		}
  		elsif ($row =~ /^host:(.*)/) {
  			$host = $1;
  		}
  		elsif ($row =~ /^user:(.*)/) {
  			$username = $1;
  		}
  		elsif ($row =~ /^pass:(.*)/) {
  			$password = $1;
  		}
	}
	close $cfh;
	
	# check arguments
	my $argvi = 0;
	foreach (@ARGV) {
		#print "$_\n";
		if ($_ eq '--series') {
			$series = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '--role') {
			push (@ocRoleIn, $ARGV[$argvi + 1]);
		}
		elsif ($_ eq '--mcourse') {
			push (@mCourseIn, $ARGV[$argvi + 1]);
		}
		elsif ($_ eq '--host') {
			$host = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '--username') {
			$username = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '--password') {
			$password = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '--newacl') {
			$newAcl = 1;
		}
		$argvi++;
	}
	
	print "OK\nChecking Protocol...\n";
	
	# check $host for protocol
	if ($host =~ /^(https?\:\/\/)/) {
		$http = $1;
		if ($http eq 'http://') {
			print "The selected host does NOT support encrypted transmission of data. As a result, sensitive information (usernames, passwords, etc.) can be seen by others while in transit.\nAre you sure you want to continue (yes/no)? ... ";
			my $continue_nonencrypted = <STDIN>;
			chomp $continue_nonencrypted;
			unless ($continue_nonencrypted =~ /^yes$/i) {
				die "\nExiting...\n\n";
			}
		}
	}
	else {
		die "Please include HTT-Protocol in the 'host' argument (e.g.: https://opencast.myuni.edu).\n";
	}
	
	print "OK\nChecking mandatory parameters...\n";
	
	# check if all essential arguments have been defined
	unless (defined $series) {
		die "\nERROR: OC-Series-ID must be defined. Exiting...\n\n";
	}
	
	print "OK\n";
	
	# check whether to use current ACL or define a new one
	if ($newAcl == 0) {
		unless (@ocRoleIn || @mCourseIn) {
			die "\nERROR: When using the current ACL, OC-Role and/or Moodle-ID must be defined. Exiting...\n\n";
		}
		my $aclGet = 'curl ' . $host . '/series/' . $series . '/acl.json';
		print "Attempting to get existing ACL...\n";
		if ($acl = `$aclGet`) {
		print "\nOK\nUsing current ACL:\n\n$acl\n\n";
		}
		else {
			die "Could not retrieve current ACL for OC-Series $series. Exiting...\n\n";
		}
	}
	elsif ($newAcl == 1) {
		unshift (@ocRoleIn, 'ROLE_ADMIN+'); # include (prepend) default OC admin-role, ROLE_ADMIN
		$acl = $aclPre . $aclPost;
		print "New, empty ACL initiated.\n";
	}
	
	
	###################################################
	# define new roles with the respective privileges #
	###################################################
	print "Defining roles with the respective privileges...\n";
	
	# define new roles form Moodle course-ID (--mcourse option)
	foreach (@mCourseIn) {
		my $mciE = $_;
		if ($mciE =~ /^(\d+)([\+\-]?)([\+\-]?)$/) { # check validity of --mcourse input; digit(s) = course-ID, +|- = read(-)/write(+) rights for 'Instructor' (first position) and 'Learner' (second position)
			my $cId = $1;
			my $instrWrite = $2;
			my $learnWrite = $3;
			
			if ($instrWrite eq '' && $learnWrite eq '') { # if both rights' symbols (+,-) are missing, set the default ones (read/read)
				$instrWrite = '-';
				$learnWrite = '-';
			}
			
			# define and insert "Instructor" role
			my $roleInstr = $cId . '_Instructor' . $instrWrite;
			push (@ocRoleIn, $roleInstr);
			
			# define and insert "Learner" role (if needed)
			if ($learnWrite ne '') {
				my $roleLearn = $cId . '_Learner' . $learnWrite;
				push (@ocRoleIn, $roleLearn);
			}
		}
		else {
			print "\tInvalid entry: $mciE; skipping...\n";
			next;
		}
	}
	
	# define and insert custom roles (--role option)
	foreach (@ocRoleIn) {
		my $ocriE = $_;
		if ($ocriE =~ /^([a-z,0-9\_]+)([\+\-]?)$/i) { # check validity of --role input; Alphanumeric plus underscore = OC-Role (string), +|- = read(-)/write(+) rights for that OC-Role
			my $roleName = $1;
			my $roleWrite = $2;
			if ($roleWrite eq '+') {
				$roleWrite = 'true';
			}
			else {
				$roleWrite = 'false'; # if rights' symbol is '-' or missing, set this to 'false'
			}
			my $aclAction = $aclActionBase; # fill in ACL-action template
			$aclAction =~ s/\*\*role\*\*/$roleName/g;
			$aclAction =~ s/\*\*write\*\*/$roleWrite/g;
			
			#$acl =~ /$aclPre(.*)$aclPost/; # regex conditional test
			if ($acl =~ /^$aclPreQ([^\[\]]+)$aclPostQ$/) { # in case of non-empty acl, append new elements (using comma),...
				if ($acl !~ /$aclAction/) { # unless already present
					$acl = $aclPre . $1 . ',' . $aclAction . $aclPost;
				}
				else {
					print "\tRole/Action is already present; skipping...\n";
					next;
				}
			}
			elsif ($acl =~ /^$aclPreQ$aclPostQ$/){ # in case of empty acl, insert the new element
				$acl = $aclPre . $aclAction . $aclPost;
			}
			else {
				die "Unexpected ACL-format: please check integrity and version of ACL. Exiting...\n\n";
			}
			$usrCreateRoles =~ s/\[(.+)\]/\[$1\,\"$roleName\"\]/; # insert current role name to tmp-user create string
			$usrCreateRoles =~ s/\[\]/\["$roleName\"\]/; # same as above (when no previous roles present)
		}
		else {
			print "\tInvalid entry: $ocriE; skipping...\n";
			next;
		}
	}
	print "OK\nNew ACL:\n\n$acl\n\n";
	
	
	######################################
	# Update ACL for the given OC-Series #
	######################################
	
	
	# define curl-command for ACL-update
	print "Defining cURL-command for ACL Update...\n";
	$acl = "\'" . 'acl=' . $acl . "\'";
	$aclCmd = 'curl --digest -u "' . $username . ':' . $password . '" -H "X-Requested-Auth: Digest" --data-urlencode ' . $acl . ' ' . $host . '/series/' . $series . '/accesscontrol';
	print "OK\n";
	
	#execute curl-command for ACL-update
	print "Attemptig to update ACL for Series $series...\n";
	system "$aclCmd";
	print "OK\n";
	
	# create a temporary OC-user with respective roles. (The update of the Series ACL registers the roles, but they are not listed in the Admin-UI, unless a user with the respective roles is created.)
	print ("Defining cURL-command to create tmp user with new roles...\n");
	my $usrCreatePwd = "\'" . 'password=' . rand(10) . '_' . "\'";
	$usrCreateCmd = 'curl --digest -u "' . $username . ':' . $password . '" -H "X-Requested-Auth: Digest" --data "username=tmp_user&name=Temporary User&email=" --data-urlencode ' . $usrCreatePwd . ' --data-urlencode ' . $usrCreateRoles . ' ' . $host . '/user-utils';
	print "OK\nAttempting to create tmp user...\n";
	system "$usrCreateCmd";
	print "OK\n";
	# delete tmp user
	print "Attempting to delete tmp user...\n";
	$usrDeleteCmd = 'curl --digest -u "' . $username . ':' . $password . '" -H "X-Requested-Auth: Digest" -X DELETE ' . $host . '/user-utils/tmp_user.json';
	system "$usrDeleteCmd";
	print "OK\n";
	
	# greet
	print "\nDone!\n\n";
}
exit 0;