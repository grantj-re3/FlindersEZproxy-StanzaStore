#!/usr/bin/ruby
#
# Copyright (c) 2017, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Usage 1:  ezp_split_into_indiv_stanzas.rb  INPUT_FILE_WITH_MANY_STANZAS ...
# Usage 2:  cat INPUT_FILE_WITH_MANY_STANZAS |ezp_split_into_indiv_stanzas.rb
#
# PURPOSE
# To support migrating from a monolithic EZproxy stanza file into a system
# where there is one text file per stanza.
#
# This program expects one or more monolithic stanza files as input (either
# as command line arguments or contents piped into STDIN). It will create
# many stanza files as output.
#
# NOTES
# - The file name is derived from the first line of the stanza
#   (typiclly a Title or DBVar line).
#
# - Many characters are ignored (filtered out) for the purpose of
#   creating a filename.
#
# - BEWARE: Some lines in a monolithic stanza file do not have their
#   scope limited to a stanza but they persist from one stanza to
#   the next (eg. Option HttpsHyphens). Once a monolithic file has
#   been split into 1-stanza-per-file by this program then merged
#   (with another program) if they are not merged in the same order
#   then the behaviour of the split-and-merged configuration may be
#   different from the original configuration!
#
##############################################################################
class OutputFile
  # This regex must:
  # - detect the start-line of your stanza (usually Title or DbVar)
  # - capture a stanza label or name or title (suitable for translation
  #   into a filename) between the second set of round brackets

# STANZA_START_REGEX = /^(Title|T)\s+(.*)\s*$/i	# CUSTOMISE
  STANZA_START_REGEX = /^(DbVar\d)\s+(.*)\s*$/i	# CUSTOMISE

  TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

  PREFIX_LINES = [
    "# Auto created on #{Time.now.strftime(TIME_FORMAT)} by program #{File.basename(__FILE__)}",
    "# @groups: flinders",
  ]

  attr_reader :fname

  ############################################################################
  def initialize()
    @fname = nil
    @fh = nil
  end

  ############################################################################
  def write(line)
    @fh.puts line unless line.nil? || line.empty?
  end

  ############################################################################
  def open_new_close_old(label)
    # Close old file
    @fh.close if @fh

    # Open new output file
    @fname = self.class.label2filename(label)
    if @fname.nil?
      @fh = nil
    else
      @fh = File.open(@fname, "w")
      PREFIX_LINES.each{|line| write(line)}
    end
  end

  ############################################################################
  def self.label2filename(label)
    # White-list chars which we deem are acceptable for filenames
    filtered_label = label.gsub(/[^\w :()&-]/, "").strip
    filtered_label.empty? ? nil : filtered_label + ".stz"
  end

end

##############################################################################
# Main
##############################################################################
have_warned_initial_content = false
start_regex = OutputFile::STANZA_START_REGEX
file_out = OutputFile.new
while gets
  line = $_.chomp.strip

  if line.match(start_regex)
    file_out.open_new_close_old($2)

  elsif !have_warned_initial_content && file_out.fname.nil? && !line.empty?
    STDERR.puts "WARNING: Unexpected content before first #{start_regex.inspect} line"
    have_warned_initial_content = true
  end

  next unless file_out.fname		# We don't have an output filename yet!
  file_out.write(line)			# Write line to current output file

end

