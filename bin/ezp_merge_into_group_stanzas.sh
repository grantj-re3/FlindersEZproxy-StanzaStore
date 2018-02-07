#!/bin/sh
#
# Copyright (c) 2017, Flinders University, South Australia. All rights reserved.
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
fname_stanzas="$tmp_dir/stanaz_files.psv"
fname_stanzas_sorted="$tmp_dir/stanaz_files_sorted.psv"

delim="|"			# Single char delimiter for sort command

# Format of comment lines which match EZproxy groups are:
# - upper or lower or mixed case
# - only first 2 letters are considered for matching
# - fairly flexible regarding spaces (except 2-letter match must occur either
#   immediately after a space or immediately after $prefix_re).
#
# Examples:
#   # @groups: fl fm at al
#   # @groups: FL FM AT AL
#   # @groups: FLINders FMC Atl alumNI

# Needs to be unique so we don't accidently match a "normal" comment.
prefix_re="^# *@groups:"

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
  done > "$fname_stanzas"

  # Write sorted PSV (Pipe-Separated Values) file:
  #
  # Sort records the same as FileMaker (for compatibility with previous system).
  # "LANG=C" sets the collation sequence; in particular will compare column N
  #   with column N (eg. N=3) even if column N contains a space or symbol
  #   character.
  # "sort -f" ignores case when performing comparisons.
  LANG=C sort -f -t"$delim" -k1,1 "$fname_stanzas" > "$fname_stanzas_sorted"

  # Send the sorted filenames to stdout
  sed "s/^.*$delim//" "$fname_stanzas_sorted"
}

##############################################################################
create_group_file() {
  match="$1"
  fpath_out="$2"
  echo
  echo "Merging stanza-files (matching '$match') into $fpath_out"

  echo						> "$fpath_out"
  get_sorted_file_list |while read fpath_stanza; do
    if egrep -iq "$prefix_re($match|.* $match)" "$fpath_stanza"; then
      fname_stanza=`basename "$fpath_stanza"`

      show_pre_directives			>> "$fpath_out"
      echo "# From stanza-file: $fname_stanza"	>> "$fpath_out"
      cat "$fpath_stanza"			>> "$fpath_out"
      echo					>> "$fpath_out"
    fi
  done
}

##############################################################################
verify_params() {
  if [ ! -d "$src_dir" ]; then
    echo "Source directory not found: '$src_dir'"
    exit 1
  fi

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

