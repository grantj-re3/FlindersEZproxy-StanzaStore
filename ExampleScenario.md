# FlindersEZproxy-StanzaStore: Example scenario


## Environment

- Red Hat Enterprise Linux Server release 6.10 (Santiago)
- Linux 2.6.32-754.24.3.el6.x86_64 #1 SMP Tue Nov 12 06:01:24 EST 2019 x86_64 x86_64 x86_64 GNU/Linux
- GNU bash, version 4.1.2(1)-release (x86_64-redhat-linux-gnu)
- GNU coreutils 8.4 (which includes the date command)

### EZproxy environment

Imagine the following EZproxy filesystem layout with 4 EZproxy groups

```
/ezproxy/config.txt
/ezproxy/FlindersEZproxy-StanzaStore/stanzas.d/*.stz
/ezproxy/FlindersEZproxy-StanzaStore/conf.d/gFlinders.txt
/ezproxy/FlindersEZproxy-StanzaStore/conf.d/gFMC.txt
/ezproxy/FlindersEZproxy-StanzaStore/conf.d/gAlumni.txt
/ezproxy/FlindersEZproxy-StanzaStore/conf.d/gATL.txt
```

Within config.txt you define the 4 groups with the fragment:

```
Group Flinders
IncludeFile /ezproxy/FlindersEZproxy-StanzaStore/conf.d/gFlinders.txt

Group FMC
IncludeFile /ezproxy/FlindersEZproxy-StanzaStore/conf.d/gFMC.txt

Group Alumni
IncludeFile /ezproxy/FlindersEZproxy-StanzaStore/conf.d/gAlumni.txt

Group ATL
IncludeFile /ezproxy/FlindersEZproxy-StanzaStore/conf.d/gATL.txt
```

I will refer to the files *.stz in the stanza.d folder as individual stanza files.

I will refer to the files gFlinders.txt, gFMC.txt, gAlumni.txt and gATL.txt as group or aggregated stanza files.

### ezp_merge_into_group_stanzas.sh environment

It is assumed that the ezp_merge_into_group_stanzas.sh program has the following assigned to the *config* variable (where $dst_dir corresponds to the path to the conf.d folder).

```
	fl	$dst_dir/gFlinders.txt
	fm	$dst_dir/gFMC.txt
	at	$dst_dir/gATL.txt
	al	$dst_dir/gAlumni.txt
```


## The individual stanza filenames *.stz

Each of the above aggregated files within conf.d contains a list of (perhaps hundreds of) EZproxy stanzas. They are built from individual stanza files (one text-file per stanza) using the program ezp_merge_into_group_stanzas.sh.

In our example, each stanza file starts with a DbVar0 directive which gives the generic stanza name/label. The label is typically free of specific information about stanza version or date (which is more likely to appear in the EZproxy stanza Title directive). The label typically consists of a limited range of characters suitable for filenames (eg. upper and lower case alphabetic characters, numbers, dot, space, hyphen, underscore; probably ampersand, colon round brackets and several other characters are also acceptable).

It is strongly recommended that the name of the stanza file is identical to the label which follows the DbVar0 directive (plus the addition of the file extension ".stz"). For example, for the fictitious vendor "Future Fizicks" you would have filename "Future Fizicks.stz" and DbVar0 line "DbVar0 Future Fizicks". 

It is also likely that the EZproxy Title directive is the same or similar. Eg.

```
T Future Fizicks
T Future Fizicks (updated 2019-12-25)
Title Future Fizicks (version 1)
```


## Instructions for the ezp_merge_into_group_stanzas.sh program

The format of the stanza files allows for ezp_merge_into_group_stanzas.sh instructions to be entered on EZproxy comment lines. (A line beginning with a "#" character is an EZproxy comment.) The ezp_merge_into_group_stanzas.sh program understands the following instructions.
- @groups - one per (active) individual stanza file
- @rem - zero or more per individual stanza file
- @triallastday - zero or one per individual stanza file

For example:
```
# @groups: alumni atl
# @rem: Convert stanza to https version in March
# @triallastday: 2020-06-01
```

These instructions can appear on any line within an individual stanza file but are typically expected to appear at or near the top so that they are easily human readable. These instructions can appear in any order.

To reiterate, EZproxy will ignore these lines because they are EZproxy comments. However the ezp_merge_into_group_stanzas.sh program will interpret the lines as instructions as described below.


### The @groups instruction

The @groups line must appear once in every (active) stanza file. If it is omitted the individual stanza file content will not appear in any of the aggregated/group files (hence the stanza file will be inactive). The purpose of the instruction is to tell the ezp_merge_into_group_stanzas.sh program to add this individual stanza file to the specified list of aggregated (ie. group) files. The list of groups can appear in any order or in upper or lower case characters. The groups must be separated by one or more spaces.

For the ezp_merge_into_group_stanzas.sh environment given at the top of this page, only the first 2 characters of each group is recognised. Hence the strings alumni, alumn, alum, alu, al, ALUMNI, ALUMN, ALUM, ALU, AL, alWrong, ALjunk, alpine, algebra and alexander will all be associated with the "Alumni" group and the "gAlumni.txt" aggregate file. Hence, if any one of the following @groups instructions appears within an individual stanza file, the content of that file will be added to gAlumni.txt and gATL.txt and the content of that file will *not* appear in gFlinders.txt and gFMC.txt.

```
# @groups: alumni atl
# @groups: alu atl
# @groups: al at
# @groups: AT AL
# @groups: atomic algebra
```


### How to make a stanza inactive

You can make an individual stanza inactive by doing something which results in that file being omitted from all aggregated files. Some suggestions are:

- Delete the stanza file. Not advisable if you believe you may use the stanza again and the stanza is not available elsewhere.
- Move the stanza file to a different directory (so it is not in the stanza.d directory and therefore not processed).
- Rename the stanza file so it does not end with the extension ".stz". Eg. Perhaps "My Stanza.stz.disabled".
- Change the @groups line so it is not recognised by ezp_merge_into_group_stanzas.sh. For example, one of the following:

```
# @rem: @groups: alumni atl
# Disabled @groups: alumni atl
## @groups: alumni atl
```


### The @rem instruction

The @rem instruction is a remark line or comment line which you can enter into an individual stanza file but the line will be omitted from the aggregated stanza file. @rem instruction lines can appear zero or more times within an individual stanza file.


### The @triallastday instruction

The @triallastday instruction allows one to specify a date after which the stanza will no longer be included in any aggregated stanza file. This instruction can appear zero or one time within an individual stanza file. The purpose is to allow a stanza to be included in the aggregated file until the specified/trial date, after which whenever the ezp_merge_into_group_stanzas.sh program is run the content of the individual stanza file will be omitted.

The date format which follows the "@triallastday" text can be any format permitted by the Linux/Unix date command. For the date command which comes with GNU coreutils 8.4, this includes:
- 2018-08-01, 2018-8-1, 2018-8-01, 2018-08-1
- 01 AUG 2018, 1 august 2018, 1 Aug 2018, 01 August 2018
- aug 1 2018, AUGUST 01 2018, Aug 01 2018, August 1 2018

It is preferable to chose a consistent format. I prefer the YYYY-MM-DD format (eg. 2018-08-01) as it makes machine sorting and comparison simpler.

Below is a list of valid examples for an individual stanza which will no longer appear in any aggregated file if the ezp_merge_into_group_stanzas.sh program is run after the first day of August 2018. Only one of the lines below is permitted within an individual stanza file.

```
# @triallastday: 2018-08-01
# @triallastday: 1 Aug 2018
# @triallastday: 01 August 2018
```


## Example stanza with ezp_merge_into_group_stanzas.sh instructions

```
# @groups: alumni atl
# @rem: Convert stanza to https version in March
# @triallastday: 2018-08-01
DbVar0 Science Databases
Title Science Databases
URL http://www.sciencedb.com
Domain sciencedb.com
```


## References

- https://www.oclc.org/en/ezproxy.html
- https://help.oclc.org/Library_Management/EZproxy/EZproxy_configuration/Introduction_to_database_stanza_directives
- https://help.oclc.org/Library_Management/EZproxy/Configure_resources
- https://help.oclc.org/Library_Management/EZproxy/Database_stanzas

