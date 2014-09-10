#!/usr/bin/env bash
set -o nounset

## script info
# name: dl-podcast.sh
# purpose: downloads the last podcast added to podbeuter queue. script is
#          supposed to be run by GNU Direvent every time queue file is modified.
# license: GPL-2
# last updated: september 2014
# authors:
# - ottre
# mandatory dependencies:
# - bash v4
# - gnu coreutils, provides tac and mkdir
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
declare -i downloaded=0      # number of times output file appears in log
declare -- downloaded_log='' # log of previous downloads
declare -- queue_file=''     # podbeuter queue file
declare -- regex=''          # se

## assign vars
queue_file="$1"
downloaded_log="${BASH_SOURCE##*/}.log"
[[ ! -f $downloaded_log ]] && touch "$downloaded_log"
regex="^http://.*\.(mp3|ogg)$"

## body of script
tac "$queue_file" | while read download_url download_file; do
  download_file="${download_file//\"}"
  downloaded=$(grep -c "$download_file" "$downloaded_log")
  if
    (( ! $downloaded )) && \
    [[ $download_url =~ $regex ]]
  then
    wget -q -t1 -O "$download_file" "$download_url" && \
    printf '%s\n' "$(date +%s) downloaded $download_file" >> "$downloaded_log"
  fi
done
