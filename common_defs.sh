#!/bin/bash

TMP_DIR="/tmp"
MEDIA_DIR="/media"
MEDIA_USER_DIR="${MEDIA_DIR}/${USER}"
DEV_DISK_BY_UUID_DIR="/dev/disk/by-uuid"

colored_echo() {
    local exp=$1
    local color=$2
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput setaf $color
    [ "$3" == "bold" ] && tput bold
    echo -e $exp 1>&2
    tput sgr0
}

error_exit() {
  colored_echo "$1\n" red bold
  exit 1
}

print_usage() {
  echo -e "\n  Usage: ${0##*/} $1"
  example="example:"
  z=2
  while [ -n "${!z}" ]; do 
    echo -e   "$example ${0##*/} ${!z}"
    example="        "
    let z+=1
  done
  echo
  exit 1
}

print_var_name_value() {
  if [ -z "${2}" ]; then
    echo "$1 = ${!1}"
  else
    colored_echo "$1 = ${!1}" $2 $3
  fi
}

get_param_from_file() {
  shopt -s extglob
  while IFS='= ' read lhs rhs
  do
    if [[ ! $lhs =~ ^\ *# && -n $lhs && "$lhs" == "$2" ]]; then
        rhs="${rhs%%\#*}"    # Del in line right comments
        rhs="${rhs%%*( )}"   # Del trailing spaces
        rhs="${rhs%\"*}"     # Del opening string quotes
        rhs="${rhs#\"*}"     # Del closing string quotes
        echo "$rhs"
    fi
  done < $1
}
