#!/bin/sh
#
# Copyright (c) 2017-2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Usage 1:  ezp_extract_group_stanzas.sh
# Usage 2:  ezp_extract_group_stanzas.sh  MATCH  OUT_FILE_PATH
#
# The first form writes all output file-paths defined by the config
# variable below. The second form writes the specified output file-path
# after selecting stanza files with "@groups" comments which match the
# specified MATCH argument.
#
##############################################################################
app_dir_tmp=`dirname "$0"`	# Might be relative (eg "." or "..") or absolute
top_dir=`cd "$app_dir_tmp/.." ; pwd`	# Absolute path of parent dir of app dir

# Assumes these dirs already exist
src_dir="$top_dir/stanzas.d"	# CUSTOMISE: Source folder containing 1 file per stanza
dst_dir="$top_dir/conf.d"	# CUSTOMISE: Destination folder for config below
tmp_dir="$top_dir/working"
fname_stanzas="$tmp_dir/stanza_files.psv"
fname_stanzas_sorted="$tmp_dir/stanza_files_sorted.psv"

delim="|"			# Single char delimiter for sort command

# Format of comment lines which match EZproxy groups are:
# - upper or lower or mixed case
# - only first 2 letters are considered for matching
# - fairly flexible regarding spaces (except 2-letter match must occur either
#   immediately after a space or immediately after $re_groups).
#
# Examples:
#   # @groups: fl fm at al
#   # @groups: FL FM AT AL
#   # @groups: FLINders FMC Atl alumNI

# Needs to be unique so we don't accidently match a "normal" comment.
re_delim=":"
re_groups="^# *@groups$re_delim"
re_trial_last_day="^# *@triallastday$re_delim"
re_remark="^# *@rem$re_delim"	# A remark/comment to be excluded from the merged file

# Directives which appear before every stanza (one per line)
pre_directives="
	Option HttpsHyphens
"

# CUSTOMISE
config="
##	MATCH	DEST_FILE_PATH

	fl	$dst_dir/gFlinders.txt
	fm	$dst_dir/gFMC.txt
	at	$dst_dir/gATL.txt
	al	$dst_dir/gAlumni.txt
"

# CUSTOMISE
CAT_RAW="cat"					# Copy stdin to stdout
CAT_CLEAN="perl -pe 's/[^[:ascii:]]//g'"	# Ditto, but strip non-ascii chars
CAT="$CAT_CLEAN"				# Set to CAT_RAW or CAT_CLEAN

# Stanza start mark: Issue warning if not present.
# Although not strictly essential, we use this DbVar directive to mark
# the start of a stanza for the purposes of splitting an EZproxy
# merged/monolithic stanza file. (We previously used it in
# LogFormat/LogSPU directives.)
stanza_start_mark="DbVar0"
re_stanza_start_mark="^$stanza_start_mark[\s].*[\w]"

# Define true and false for bash/sh
TRUE=1
FALSE=""

##############################################################################
show_pre_directives() {
  echo "$pre_directives" |
    while read directive; do
      [ -z "$directive" ] && continue			# Skip blank lines
      echo "$directive"
    done
}

##############################################################################
get_sorted_file_list() {
  # Write unsorted PSV (Pipe-Separated Values) file:
  #
  # Assumes every stanza file has a DbVar0 line.
  # Field 1: The sort-key ie. the text on the DbVar0 line.
  # Field 2: The filename associated with the above DbVar0 line.
  for fpath_stanza in "$src_dir"/*.stz; do
    key=`egrep "^DbVar0" "$fpath_stanza" |head -1`
    echo "$key$delim$fpath_stanza";
  done |eval $CAT > "$fname_stanzas"

  # Write sorted PSV (Pipe-Separated Values) file:
  #
  # Sort records the same as FileMaker (for compatibility with previous system).
  # "LANG=C" sets the collation sequence; in particular will compare column N
  #   with column N (eg. N=3) even if column N contains a space or symbol
  #   character.
  # "sort -f" ignores case when performing comparisons.
  LANG=C sort -f -t"$delim" -k1,1 "$fname_stanzas" > "$fname_stanzas_sorted"

  # Assumes dir is set-GID and multiple users (in the same set-GID group) run this script
  sudo chmod g+w "$fname_stanzas"  "$fname_stanzas_sorted"

  # Send the sorted filenames to stdout
  sed "s/^.*$delim//" "$fname_stanzas_sorted"
}

##############################################################################
will_include_this_file() {
  fpath_stanza="$1"
  will_include=$TRUE		# Assume we will include this stanza-file

  trial_last_day_line=`egrep -i "$re_trial_last_day" "$fpath_stanza" |head -1`
  [ "$trial_last_day_line" ] && {
    fname_stanza=`basename "$fpath_stanza"`

    # This is a trial. Exclude if we are past the trial-expiry date.
    trial_last_day=`echo "$trial_last_day_line" |sed "s!^.*$re_delim *!!;"' s! *$!!'`
    trial_last_day_yyyymmdd=`date -d "$trial_last_day" '+%Y-%m-%d' 2>/dev/null`	# YYYY-MM-DD
    [ $? != 0 -o -z "$trial_last_day" ] && {
      will_include=$FALSE
      echo "Invalid date '$trial_last_day'. Excluding trial stanza-file: $fname_stanza"

    } || {
      today=`date '+%Y-%m-%d'`	# YYYY-MM-DD
      [ $today \> "$trial_last_day_yyyymmdd" ] && {
        will_include=$FALSE
        echo "Last day $trial_last_day_yyyymmdd. Expired trial stanza-file: $fname_stanza"

      } || {
        echo "Last day $trial_last_day_yyyymmdd. Including active trial stanza-file: $fname_stanza"
      }
    }
  }
}

##############################################################################
create_group_file() {
  match="$1"
  fpath_out="$2"
  echo
  echo "Merging stanza-files (matching '$match') into $fpath_out"

  echo							> "$fpath_out"
  get_sorted_file_list |while read fpath_stanza; do
    if egrep -iq "$re_groups($match|.* $match)" "$fpath_stanza"; then
      will_include_this_file "$fpath_stanza"
      if [ "$will_include" ]; then
        fname_stanza=`basename "$fpath_stanza"`

        show_pre_directives				>> "$fpath_out"
        echo "# From stanza-file: $fname_stanza"	>> "$fpath_out"
        eval "$CAT \"$fpath_stanza\"" |
          egrep -iv "$re_remark"			>> "$fpath_out"
        echo						>> "$fpath_out"

        if ! eval "$CAT \"$fpath_stanza\"" |grep -P -iq "$re_stanza_start_mark"; then
          echo "WARNING: Stanza in $fname_stanza does not contain a valid '$stanza_start_mark' line." >&2
        fi
      fi
    fi
  done
}

##############################################################################
verify_params() {
  dirs_config="
	##DirName	DirDescription
	$src_dir	Source
	$tmp_dir	Temporary-working
"

  echo "$dirs_config" |
    while read dir desc; do
      [ -z "$dir" -o -z "$desc" ] && continue		# Skip blank/invalid lines
      ( echo "$dir" |egrep -q "^#" ) && continue	# Skip comments (where 1st non-space char is "#")

      if [ ! -d "$dir" ]; then
        echo "$desc directory not found: '$dir'"
        exit 1
      fi
    done
  res=$?
  [ $res != 0 ] && exit $res

  if [ $# != 2 ]; then
    # Destination folder not used if invoked with 2 args
    if [ ! -d "$dst_dir" ]; then
      echo "Destination directory not found: '$dst_dir'"
      exit 1
    fi
  fi
}

##############################################################################
# Main
##############################################################################
verify_params
if [ $# = 2 ]; then
  # Invoked with 2 args (MATCH & OUT_FILE_PATH)
  create_group_file "$1" "$2"

else
  echo "$config" |
    while read match fpath_out; do
      [ -z "$match" -o -z "$fpath_out" ] && continue	# Skip blank/invalid lines
      ( echo "$match" |egrep -q "^#" ) && continue	# Skip comments (where 1st non-space char is "#")
      create_group_file "$match" "$fpath_out"
    done
fi

