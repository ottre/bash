#!/usr/bin/env bash

## script info
# name: resize.sh
# purpose: resize your screen using xrandr, without having to read the manual
# license: GPL-2
# last updated: september 2014
# authors:
# - ottre
# mandatory dependencies:
# - bash v4
# - xrandr
# - findutils, provides xargs
# - ncurses, provides tput
# optional dependencies:
# - one of the following, for floating point maths:
#   - bc, provides dc
#   - gawk, provides awk
#   - busybox, provides dc and awk

## license info
# resize.sh is distributed under the terms of the GNU General Public License v2,
# see https://www.gnu.org/licenses/gpl-2.0.html

## declare vars
# all variables used outside of subroutines must be listed here,
# in alphabetical order, with a comment if var name isn't self explanatory
set -o nounset
declare -- awk_one_liner='' # se
declare -- blu=''           # terminal colour code
declare -i boost_int=0      # user specified --boost value, rounded off
declare -- boost_old=''     # previously used --boost value, must be string
declare -i boost_old_int=0  # previously used --boost value, rounded off
declare -- boost_usr=''     # user specified --boost value, must be string
declare -- clr=''           # terminal colour code
declare -- config=~/.resize # se
declare -- dependency=''    # se
declare -- dsp_name=''      # display name, must be string
declare -i dsp_max_w=0      # display max. width
declare -i dsp_max_h=0      # display max. height
declare -- grn=''           # terminal colour code
declare -- red=''           # terminal colour code
declare -- regex=''         # se
declare -i ret_val=999      # subroutine return value, default must be >10
declare -- scale=''         # how much to scale screen dimensions, must be string
declare -i scr_cur_h=0      # current screen height
declare -i scr_cur_w=0      # current screen width
declare -i scr_new_h=0      # new screen height
declare -i scr_new_w=0      # new screen width
declare -i scr_rec_max_h=0  # recommended screen max. height
declare -i scr_rec_max_w=0  # recommended screen max. width
declare -i scr_rec_min_h=0  # recommended screen min. height
declare -i scr_rec_min_w=0  # recommended screen min. width
declare -- scr_wh_usr=''    # user specified --screen value, must be string
declare -i skip_opt_flag=0  # flag var (can be 0 or 1), for msg handling
declare -a xrandr_info=()   # se

## define subroutines
# usage() se
#
# no parameters
#
# no return value
usage() {
  cat <<END_USAGE
Usage:
  resize.sh --boost [-]xx[%]
  resize.sh --reset
Options:
  -b   --boost     How much to boost screen size by, percentage value.
                   For example, ${grn}--boost 40%${clr} would allow you to
                   see 40% more of the windows you have open. If that makes
                   text too small to read, try running ${grn}--boost -5%${clr}
                   a few times until you find a screen size you like.
                   Using a negative value will make the script
                   adjust the previously used boost value, so in the example
                   above ${grn}--boost 40%${clr} becomes ${grn}--boost 35%${clr},
                   then ${grn}30%${clr}, then ${grn}25%${clr}, etc.
                   Recommended range is 25 to 50%. Computers with a
                   small screen (eg netbooks) should use a value closer
                   to 25%, computers with a large screen but small display
                   (eg old laptops with a 1024x768 display) should use
                   a value closer to 50%.
  -d   --default   This script has a default boost value of
                   ${grn}--boost 35%${clr}.
    
                   If you would like to make the current boost value
                   the new default, use this option. For example,
                     ${grn}resize.sh --boost 40%${clr} followed by
                     ${grn}resize.sh --default${clr} followed by
                     ${grn}resize.sh --reset${clr} followed by
                     ${grn}resize.sh${clr} 
                   would result in a boost value of ${grn}--boost 40%${clr}.
                   Note this works for the ${grn}--screen${clr} option as well,
                   but hasn't been tested.
  -h   --help      Display this help.
  -r   --reset     Reset screen size to display resolution.
  -s   --screen    Boost screen size to this resolution. For example,
                   ${grn}--screen 1920x1080${clr}.
END_USAGE
}

# in_range() se
#
# three mandatory parameters:
# - $1, integer, arg is number at start of range, no default
# - $2, integer, arg is number at end of range, no default
# - $3, integer, arg is a number to test, no default
#
# returns 0 if $3 is in range
# returns 1 otherwise
in_range() {
  (( $# != 3 )) && die "expected 3 parameters for in_range(), got $#." 2
  (( $3 >= $1 )) && (( $3 <= $2 ))
  return $?
}

# die() se
#
# two optional parameters:
# - $msg, string, arg is an error message, default 'unspecified error'
# - $code, integer, arg is an exit code (1 - 255), default 1
# 
# no return value
die() {
  local -i line=0
  local -- script=''
  # see http://wiki.bash-hackers.org/commands/builtin/caller
  read line script <<< $(caller)
  if
    (( $# == 2 ))
  then
    # ${msg,} converts first char in $msg to lowercase,
    # so we don't get 'Error, Sanity check failed' which looks wrong
    local -- msg="$1"
    msg="${script}: line ${line}: ${red}Error${clr}, ${msg,}"
    local -i code=$2
    in_range 1 255 $code || code=1
  else
    local -- msg="${script}: line ${line}: ${red}unspecified error${clr}."
    local -i code=1
  fi
  # use xargs to collapse whitespace in long error messages
  printf "%s\n" "$msg" | xargs >/dev/stderr
  exit $code
}

# warn() se
#
# one mandatory parameter:
# - $msg, string, arg is a warning message, no default
#
# no return value
warn() {
  (( $# != 1 )) && die "expected 1 parameter for warn(), got $#." 2
  local -- msg="$1"
  printf "%s\n" "${blu}Warning${clr}, ${msg,}" | xargs
}

# reset() see usage()
#
# no parameters
#
# no return value
reset() {
  xrandr --output $dsp_name \
         --mode ${dsp_max_w}x${dsp_max_h} \
         --panning 0x0 \
         --scale 1x1
}

# get_answer() is called if dc and awk aren't installed,
# and we need to do floating point maths
#
# one mandatory parameter:
# - $equation, string, arg is equation we need the answer to, no default
#
# prints answer and returns 0 if user entered something
# returns 1 otherwise
get_answer() {
  (( $# != 1 )) && die "expected 1 parameter for get_answer(), got $#." 2
  local -- equation="$1"
  read -p "Please manually calculate $equation = "
  if
    [[ ${REPLY:+set} = set ]]
  then
    printf "%s" $REPLY
    return 0
  else
    return 1
  fi
}

# get_boost_old() calculates, rounds off and stores in $boost_old_int
# the previously used --boost value
#
# no parameters
#
# returns 0 if we were able to calculate
# returns 1 otherwise
get_boost_old() {
  awk_one_liner="BEGIN{ print (($scr_cur_w / $dsp_max_w) * 100) - 100; }"
  boost_old=$(
    dc         <<< "5 k $scr_cur_w $dsp_max_w / 100 * 100 - p" 2>/dev/null || \
    busybox dc <<< "$scr_cur_w $dsp_max_w / 100 * 100 - p"     2>/dev/null || \
    awk         -- "$awk_one_liner"                            2>/dev/null || \
    busybox awk -- "$awk_one_liner"                            2>/dev/null || \
    get_answer "(($scr_cur_w / $dsp_max_w) * 100) - 100"
  ) || return 1
  boost_old_int=$(printf '%.0f' $boost_old)
  return 0
}

# check_boost() does a sanity check on --boost values
#
# two parameters, first is mandatory, second optional:
# - $percentage, integer, arg is $boost_int or $boost_old_int, no default
# - $adjust_flag, integer, arg is 0 (unset) or 1 (set), default 0
#
# returns 0 if $percentage is sane (25 to 50)
# returns 1 or 2 if $percentage isn't sane (0)
# returns 3 or 4 if $percentage isn't sane (<0)
# returns 5 or 6 if $percentage isn't sane (1 to 24)
# returns 7 or 8 if $percentage isn't sane (>50)
check_boost() {
  (( $# == 0 )) && die "expected at least 1 parameter for check_boost()." 2
  local -i percentage=$1
  if
    (( $percentage < 0 ))
  then
    local -i my_ret_val=3
  elif
    (( $percentage == 00 ))
  then
    local -i my_ret_val=1
  elif
    in_range 01 24 $percentage
  then
    local -i my_ret_val=5
  elif
    in_range 25 50 $percentage
  then
    local -i my_ret_val=0
  else
    local -i my_ret_val=7
  fi
  # increment return value (odd to even) if check_boost() is being called for
  # the second time, after adjusting $boost_int. this allows us to give more
  # specific warnings, 'value isn't sane' vs 'adjusted value isn't sane'.
  local -i adjust_flag=${2:-0}
  if
    (( $adjust_flag )) && \
    (( $my_ret_val  ))
  then
    my_ret_val=$(( $my_ret_val + 1 ))
  fi
  return $my_ret_val
}

# check_screen() does a sanity check on --screen values
#
# no parameters
#
# returns 0 if values are sane (between recommended min. and max.)
# returns 1 if they aren't sane (equal to display max.)
# returns 2 if they aren't sane (less than recommended min.)
# returns 3 if they aren't sane (greater than recommended max.)
check_screen() {
  if
    in_range $scr_rec_min_w $scr_rec_max_w $scr_new_w && \
    in_range $scr_rec_min_h $scr_rec_max_h $scr_new_h
  then
    return 0
  elif
    (( $scr_new_w == $dsp_max_w )) && \
    (( $scr_new_h == $dsp_max_h ))
  then
    return 1
  elif
    (( $scr_new_w < $scr_rec_min_w )) || \
    (( $scr_new_h < $scr_rec_min_h ))
  then
    return 2
  else
    return 3
  fi
}

# save_default() saves the previously used --boost or --screen value
#
# no parameters
#
# no return value
save_default() {
  get_boost_old || die "unable to calculate \$boost_old_int." 2
  check_boost $boost_old_int
  ret_val=$?
  if
    (( $ret_val == 0 ))
  then
    local -i boost_used_w=$(( ($dsp_max_w * ($boost_old_int + 100)) / 100 ))
    # used --boost option
    if
      (( $boost_used_w == $scr_cur_w ))
    then
      printf "%s\n" "boost_int=${boost_old_int}" >$config
      printf "%s\n" "Saved default ${grn}--boost ${boost_old_int}%${clr}."
    # used --screen option
    else
      printf "%s\n" "scr_new_w=${scr_cur_w}" >$config
      printf "%s\n" "scr_new_h=${scr_cur_h}" >>$config
      printf "%s\n" "Saved default ${grn}--screen
                     ${scr_cur_w}x${scr_cur_h}${clr}." | xargs
    fi
  else
    die "sanity check failed." 2
  fi
}

# use_default() retrieves the previously used --boost or --screen value
#
# no parameters
#
# no return value
use_default() {
  [[ -r $config ]] && source $config
  if
    (( $boost_int ))
  then
    warn "defaulting to ${grn}--boost ${boost_int}%${clr}."
  elif
    (( $scr_new_w ))
  then
    warn "defaulting to ${grn}--screen ${scr_new_w}x${scr_new_h}${clr}."
  # --boost 35% is the builtin default, see usage()
  else
    warn "defaulting to ${grn}--boost 35%${clr}."
    boost_int=35
  fi
}

# warn_skip_opt() processes an option that is missing a value,
# moved this code to a sub to make the case statement more readable
#
# one mandatory parameter:
# - $opt, string, arg is $1 in case statement (eg '--boost'), no default
#
# no return value
warn_skip_opt() {
  (( $# != 1 )) && die "expected 1 parameter for warn_skip_opt(), got $#." 2
  local -- opt=$1
  warn "no value for the ${grn}${opt}${clr} option, skipping."
  # flag tells the "handle options" section not to warn about missing options
  skip_opt_flag=1
}

# warn_bad_opt() similar to warn_skip_opt()
#
# one mandatory parameter:
# - $opt, string, arg is $1 in case statement (eg '--bost'), no default
#
# no return value
warn_bad_opt() {
  (( $# != 1 )) && die "expected 1 parameter for warn_bad_opt(), got $#." 2
  local -- opt=$1
  warn "option ${grn}${opt}${clr} not recognised."
}

## assign vars
for dependency in tput xargs xrandr
do
  command -v $dependency >/dev/null || die "dependency check failed." 3
done
if
  (( $(tput colors) >= 8 ))
then
  red="$(tput bold)$(tput setaf 1)"
  grn="$(tput bold)$(tput setaf 2)"
  blu="$(tput bold)$(tput setaf 4)"
  clr="$(tput sgr0)"
fi
# see http://wiki.bash-hackers.org/commands/builtin/mapfile
# quotes are necessary
readarray -t xrandr_info <<< "$(xrandr)"
# FIXME: sometimes gets rounded?
regex="^Screen 0: minimum [0-9]+ x [0-9]+, current ([0-9]+) x ([0-9]+)"
if
  [[ ${xrandr_info[0]} =~ $regex ]]
then
  scr_cur_w=${BASH_REMATCH[1]}
  scr_cur_h=${BASH_REMATCH[2]}
else
  die "regex match failed." 3
fi
regex="^([A-Z0-9]+) connected primary"
if
  [[ ${xrandr_info[1]} =~ $regex ]] || \
  [[ ${xrandr_info[2]} =~ $regex ]]
then
  dsp_name=${BASH_REMATCH[1]}
else
  die "regex match failed." 3
fi
# see xrandr | od -t a for number of spaces to match
# + at end of regex indicates max res
regex="^ {3}([0-9]+)x([0-9]+) {7}[0-9]{2}\.[0-9].\+"
if
  [[ ${xrandr_info[2]} =~ $regex ]] || \
  [[ ${xrandr_info[3]} =~ $regex ]]
then
  dsp_max_w=${BASH_REMATCH[1]}
  dsp_max_h=${BASH_REMATCH[2]}
else
  die "regex match failed." 3
fi
scr_rec_min_w=$(( ($dsp_max_w * 125) / 100 ))
scr_rec_min_h=$(( ($dsp_max_h * 125) / 100 ))
scr_rec_max_w=$(( ($dsp_max_w * 150) / 100 ))
scr_rec_max_h=$(( ($dsp_max_h * 150) / 100 ))

## process options
while
  (( $# >= 1 ))
do
  case $1 in
    '-b' |   '--boost') [[ ${2:+set} = set ]] && boost_usr=$2;     shift 2 || \
                                                 warn_skip_opt $1; shift 1 ;;
    '-d' | '--default') save_default; exit 0;;
    '-h' |    '--help') usage; exit 0;;
    '-r' |   '--reset') reset; exit 0;;
    '-s' |  '--screen') [[ ${2:+set} = set ]] && scr_wh_usr=$2;    shift 2 || \
                                                 warn_skip_opt $1; shift 1 ;;
                     *) warn_bad_opt $1; shift 1;;
  esac
done

## handle options
# handle --boost option
if
  [[ ${boost_usr:+set} = set ]]
then
  regex="^-?[.0-9]+%?$"
  if
    [[ $boost_usr =~ $regex ]]
  then
    # strip percent char and round to nearest integer
    boost_int=$(printf '%.0f' ${boost_usr%\%})
    check_boost $boost_int
    ret_val=$?
    # if $boost_int is negative, adjust and re-check
    # negative values are treated differently, see usage()
    if
      (( $ret_val == 3 ))
    then
      get_boost_old || die "unable to calculate \$boost_old_int." 5
      boost_int=$(( $boost_old_int + $boost_int ))
      check_boost $boost_int 1
      ret_val=$?
    fi
    case $ret_val in
        0) ;;
        1) warn "resetting screen size, ${grn}--boost 0%${clr} is a synonym for
                 ${grn}--reset${clr}."; reset; exit 0;;
        2) warn "resetting screen size, adjusted ${grn}--boost${clr} value is
                 ${grn}0%${clr} which is a synonym for
                 ${grn}--reset${clr}."; reset; exit 0;;
      4|6) warn "adjusted ${grn}--boost${clr} value is ${grn}${boost_int}%${clr},
                 the recommended minimum is 25%.";;
        5) warn "the recommended minimum ${grn}--boost${clr} value is 25%.";;
        7) warn "the recommended maximum ${grn}--boost${clr} value is 50%.";;
        8) warn "adjusted ${grn}--boost${clr} value is ${grn}${boost_int}%${clr},
                 the recommended maximum is 50%.";;
    esac
  else
    warn "discarding value ${grn}${boost_usr}${clr}, not a number."
    use_default
  fi
# handle --screen option
elif
  [[ ${scr_wh_usr:+set} = set ]]
then
  regex="^([0-9]+)x([0-9]+)$"
  if
    [[ $scr_wh_usr =~ $regex ]]
  then
    scr_new_w=${BASH_REMATCH[1]}
    scr_new_h=${BASH_REMATCH[2]}
    check_screen
    ret_val=$?
    case $ret_val in
      0) ;;
      1) warn "resetting screen size, ${grn}--screen
               ${dsp_max_w}x${dsp_max_h}${clr} is a synonym for
               ${grn}--reset${clr}."; reset; exit 0;;
      2) warn "the recommended minimum ${grn}--screen${clr} value is
               ${scr_rec_min_w}x${scr_rec_min_h}.";;
      3) warn "the recommended maximum ${grn}--screen${clr} value is
               ${scr_rec_max_w}x${scr_rec_max_h}.";;
    esac
  else
    warn "discarding value ${grn}${scr_wh_usr}${clr}, not the right format."
    use_default
  fi
# handle skipped option
elif
  (( $skip_opt_flag ))
then
  use_default
# handle no option
else
  warn "no ${grn}--boost${clr} or ${grn}--screen${clr} option in script args."
  use_default
fi

## body of script
# calculate $scr_new_* vars for --boost option
if
  (( $boost_int ))
then
  scr_new_w=$(( ($dsp_max_w * ($boost_int + 100)) / 100 ))
  scr_new_h=$(( ($dsp_max_h * ($boost_int + 100)) / 100 ))
fi
# calculate $scale for both --boost and --screen options
awk_one_liner="BEGIN{ print $scr_new_w / $dsp_max_w; }"
scale=$(
  dc         <<< "5 k $scr_new_w $dsp_max_w / p" 2>/dev/null || \
  busybox dc <<< "$scr_new_w $dsp_max_w / p"     2>/dev/null || \
  awk         -- "$awk_one_liner"                2>/dev/null || \
  busybox awk -- "$awk_one_liner"                2>/dev/null || \
  get_answer "$scr_new_w / $dsp_max_w"
) || die "unable to calculate \$scale." 6
# feedback to user
printf "%s\n" "Display resolution.: ${dsp_max_w}x${dsp_max_h}"
printf "%s\n" "Current screen size: ${scr_cur_w}x${scr_cur_h}"
printf "%s\n" "New screen size....: ${scr_new_w}x${scr_new_h}"
printf "%s\n" "Scale..............: $scale"
printf "%s\n" "Command to run.....: xrandr --output $dsp_name
                                           --mode ${dsp_max_w}x${dsp_max_h}
                                           --panning ${scr_new_w}x${scr_new_h}
                                           --scale ${scale}x${scale}" | xargs
# give user 5 seconds to abort, plenty of time to read any warning messages
warn "running command in 5 seconds, press ${grn}Ctrl-C${clr} to abort."
read -t 5 -N 0
xrandr --output $dsp_name \
       --mode ${dsp_max_w}x${dsp_max_h} \
       --panning ${scr_new_w}x${scr_new_h} \
       --scale ${scale}x${scale}
exit 0
