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

src_dir="$HOME/myEzproxy/stanzas.d"	# CUSTOMISE: Source folder containing 1 file per stanza
dst_dir="$HOME/myEzproxy/conf.d"	# CUSTOMISE: Destination folder for config below

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
create_group_file() {
  match="$1"
  fpath_out="$2"
  echo
  echo "Merging stanza-files (matching '$match') into $fpath_out"

  echo							> "$fpath_out"
  ls -1 "$src_dir"/*.stz |
    sed 's/\.stz$//' |
    LANG=C sort -f |
    sed 's/$/.stz/' |
    while read fpath_stanza; do
      if egrep -iq "$prefix_re($match|.* $match)" "$fpath_stanza"; then
        fname_stanza=`basename "$fpath_stanza"`
        echo "  $fname_stanza"
        show_pre_directives				>> "$fpath_out"
        echo "# From stanza-file: $fname_stanza"	>> "$fpath_out"
        cat "$fpath_stanza"				>> "$fpath_out"
        echo						>> "$fpath_out"
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

