# acl2oc 1.0.2

## Licence

**acl2oc (1.0.2)**  
Copyright 2016-2017 Graz University of Technology – "Educational Technology" https://elearning.tugraz.at  

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.  
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.


## Description

This program is a [Perl](https://www.perl.org/)-script which helps update the Access Control List (ACL) of an existing [Opencast](http://www.opencast.org/) series. Custom roles can be defined and granted the desired privileges for a given series. Additionally, the respective roles according to a given [Moodle](https://moodle.org/) course-ID can be generated, so that the use of the [LTI-module](https://docs.opencast.org/latest/admin/modules/ltimodule/) is meaningful.  
By default, the newly defined roles are appended to the existing ones. If desired, the original ACL of the series can be entirely replaced, discarding the previous roles. In the latter case, the standard administrator role `ROLE_ADMIN` with read/write privileges is included.

**NOTE:**  
Developed and tested on UNIX systems. The current version works with Opencast v2.2.4  

### Dependencies  
* [Perl](https://www.perl.org/)
* [cURL](https://curl.haxx.se/) (`--data-urlencode` must be supported)


## Usage

	~ perl acl2oc.pl --series <OC_series_ID> [--role <OC_custom_role> --mcourse <Moodle_course_ID> --host <OC_url> --username <OC_digest_username> --password <OC_digest_password> --newacl]

The `--series` option is mandatory. At least one of the two options (`--role` or `--mcourse`) must be set, unless `--newacl` is used (in which case the new ACL will contain only the default OC-Admin role `ROLE_ADMIN`). The rest are optional (if not explicitly set, the default values will be used).  
As shown above, all options can be entered directly as command-line arguments. Some user-specific options (e.g.: credentials) can be set in the configuration file: `./config/config.ini`

### Options

* **--series _opencast\_series\_ID_**  
The Opencast Series-ID.  
**Note**: Only one Series-ID can be entered.

* **--role _opencast\_custom\_role_**  
Insert one or more Opencast roles[^rolesformat]. By appending the symbols `+` or `-`, the privileges of the role can be defined. The rules are as follows:  
	* a minus symbol `-` grants read rights (default)
	* a plus symbol `+` grants write rights  
	
	For example, `--role ROLE_FOOBAR+` grants this role write privileges to the respective series.  
	As mentioned above, read rights will be granted by default when the symbol is omitted.  
	Multiple roles can be defined by entering multiple arguments: `--role ROLE_FOO --role ROLE_BAR+`

* **--mcourse _moodle\_course\_ID_**  
The Moodle Course-ID (Numeric value). This method follows the same rules regarding the privileges as explained above.  
Note that, in this case, two separate roles can be defined. In order to distinguish between them, two `+` or `-`symbols can be entered, each for the respective role. The first position corresponds to the _Instructor_ role, whereas the second symbol defines the _Learner_ role:
	* `++`	grants both roles write privileges
	* `+-`	grants _Instructor_ write rights and _Learner_ read rights
	* `-`	grants _Instructor_ read rights (the _Learner_ role is entirely omitted)
	* `--`	grants both roles read privileges (default)

	As with the `--role` option, multiple Course-IDs can be entered: `--mcourse 123 --mcourse 45+ --mcourse 6789+-`

* **--host _opencast\_host\_server_**  
The Opencast host server address. This option can be set in the configuration file: `./config/config.ini`  
**Note:** In case of an unencrypted connection (plain HTTP), a warning will be shown.
* **--username _opencast\_digest\_username_**  
The Opencast digest account username. You need this in order to use Opencast's API.
* **--password _opencast\_digest\_password_**  
The Opencast digest account password. You need this in order to use Opencast's API.
* **--newacl**  
Create a new ACL. All new roles as well as the standard Opencast administrator role `ROLE_ADMIN` will be included.  
**Note:** The previous ACL of the respective series will be overwritten.

### The Configuration File
Some user-specific options (e.g.: credentials) can be set in the configuration file: `./config/config.ini`  
The following template can be found in the same directory:

```
# Opencast Server URL (e.g.: https://opencast.myuni.edu)
host:https://opencast.myuni.edu

# Opencast Digest User credentials (check "../etc/custom.properties" in your OC installation)
user:******
pass:******
```
**Note:** Options entered directly as command-line arguments have priority over those set in the configuration file.

## Examples

* Append a new, custom role to the ACL of the given series, granting it write privileges:  
	
		perl acl2oc.pl --series <series_ID> --role ROLE_FOO+
  
* Create a new ACL (discarding the old one) with the roles *ROLE_ADMIN* (read/write), *123_Instructor* (read), *123_Learner* (read), *67_Instructor* (read):  
	
		perl acl2oc.pl --series <series_ID> --mcourse 123 --mcourse 67- --newacl

* Append the following roles: *ROLE_BAR* (read), *45_Instructor* (read/write), *45_Learner* (read); set the Opencast host URL, as well as the corresponding credentials:

		perl acl2oc.pl --series <series_ID> --mcourse 45+- --role ROLE_BAR --host https://opencast.ouruni.at --username ourdigestname --password ourdigestpass

[^rolesformat]: Name of role (string). It is advisable to use only alphanumeric characters and the underscore `_` character.