#!/usr/bin/env bash
set -o nounset

## script info
# name: dl-podcast.sh
# purpose: downloads the last podcast (or vodcast) added to podbeuter queue.
#          script is supposed to be run by GNU Direvent every time queue file
#          is modified.
# license: GPL-2
# last updated: september 2014
# authors:
# - ottre
# mandatory dependencies:
# - bash v4
# - gnu coreutils, provides tac and touch
# - gnu direvent
# - grep
# - wget
# optional dependencies:
# - none

## license info
# dl-podcast.sh is distributed under the terms of the
# GNU General Public License v2, see https://www.gnu.org/licenses/gpl-2.0.html

## declare vars
declare -- download_file=''  # output file (full path) of current download
declare -- download_url=''   # URL of current download
declare -- downloaded_log='' # log of previous downloads
declare -- queue_file=''     # podbeuter queue file
declare -- regex=''          # se

## define subroutines
# proc_download_file() changes $download_file based on $extension
#
# one mandatory parameter:
# - $extension, string, arg is regex capture ('torrent' or 'mp3'), no default
#
# no return value
proc_download_file() {
  local -- extension="$1"
  if
    [[ $extension = torrent ]]
  then
    # can't shorten this to ~/torrent... as direvent v5 doesn't update env vars,
    # $HOME could be /root and ~ is an alias for $HOME
    local -- torrents_dir="/home/$(whoami)/torrent.downloads/torrent"
    # strip mp3 dir
    download_file="${download_file##*/}"
    # prepend torrents dir, strip trailing quote
    download_file="${torrents_dir}/${download_file:0:-1}"
  else
    # strip quotes
    download_file="${download_file:1:-1}"
  fi
}

# downloaded() checks if $download_file appears in $downloaded_log
#
# no parameters
#
# returns 0 if we got a match, has been downloaded
# returns 1 otherwise
downloaded() {
  if
    grep -q "$download_file" "$downloaded_log" 2>/dev/null
  then
    return 0
  else
    return 1
  fi
}

## assign vars
queue_file="$1"
downloaded_log="${BASH_SOURCE##*/}.log"
regex="^https?://.*\.(mp3|ogg|torrent)"

## body of script
tac "$queue_file" | while read download_url download_file; do
  if
    [[ $download_url =~ $regex ]]
  then
    proc_download_file "${BASH_REMATCH[1]}"
    if
      ! downloaded
    then
      wget -q -t1 -O "$download_file" "$download_url" && \
      printf '%(%c)T %s\n' -1 "downloaded $download_file" >> "$downloaded_log"
    fi
  fi
done
