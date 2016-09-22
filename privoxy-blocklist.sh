#!/bin/bash
#
######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: lord-weber-andrwe <at> andrwe <dot> org
#                  Version: 0.3
#                  URL: http://andrwe.dyndns.org/doku.php/scripting/bash/privoxy-blocklist
#
#									Edited by Jerry Waller
##################
#                  Summary: 
#                   This script downloads, converts and installs
#                   AdblockPlus lists into Privoxy
######################################################################

######################################################################
#                 TODO:
#                  - implement:
#                     domain-based filter
#                     id->class combination
#                     class->id combination
######################################################################
# array of URL for AdblockPlus lists
#  for more sources just add it within the round brackets
URLS=("https://easylist-downloads.adblockplus.org/easyprivacy+easylist.txt" "https://easylist-downloads.adblockplus.org/easylistgermany.txt" "https://easylist-downloads.adblockplus.org/antiadblockfilters.txt")
PRIVOXY_USER="privoxy"
PRIVOXY_GROUP="privoxy"
PRIVOXY_CONF="/usr/local/etc/privoxy/config"
PRIVOXY_DIR="$(dirname ${PRIVOXY_CONF})" # set privoxy config dir
TMPNAME="$(basename ${0})" # name for lock file (default: script name)
TMPDIR="/tmp/${TMPNAME}" # directory for temporary files
install -d -m700 ${TMPDIR} # create temporary directory and lock file
# Debug-level
#   -1 = quiet
#    0 = normal
#    1 = verbose
#    2 = more verbose (debugging)
#    3 = incredibly loud (function debugging)
DBG=-1
VERBOSE="" # used for install, rm
#VERBOSE="-v" # used for install, rm

function usage()
{
  echo "${TMPNAME} is a script to convert AdBlockPlus-lists into Privoxy-lists and install them."
  echo " "
  echo "Options:"
  echo "      -h:    Show this help."
  echo "      -q:    Don't give any output."
  echo "      -v 1:  Enable verbosity 1. Show a little bit more output."
  echo "      -v 2:  Enable verbosity 2. Show a lot more output."
  echo "      -v 3:  Enable verbosity 3. Show all possible output and don't delete temporary files.(For debugging only!!)"
  echo "      -r:    Remove all lists build by this script."
}

function debug()
{
  [ ${DBG} -ge ${2} ] && echo -e "${1}"
}

function main()
{
  for url in ${URLS[@]}; do
    file=${TMPDIR}/$(basename ${url})
    actionfile=${file%\.*}.script.action
    filterfile=${file%\.*}.script.filter
    list=$(basename ${file%\.*})

    # download list
    curl -o ${file} ${url} >${TMPDIR}/curl-${url//\//#}.log 2>&1
    [ "$(grep -E '^.*\[Adblock.*\].*$' ${file})" == "" ] && echo "The list recieved from ${url} isn't an AdblockPlus list. Skipped" && continue

    # convert AdblockPlus list to Privoxy list
    # blacklist of urls
    echo -e "{ +block{${list}} }" > ${actionfile}
    sed '/^!.*/d;1,1 d;/^@@.*/d;/\$.*/d;/#/d;s/\./\\./g;s/\?/\\?/g;s/\*/.*/g;s/(/\\(/g;s/)/\\)/g;s/\[/\\[/g;s/\]/\\]/g;s/\^/[\/\&:\?=_]/g;s/^||/\./g;s/^|/^/g;s/|$/\$/g;/|/d' ${file} >> ${actionfile}

    echo "FILTER: ${list} Tag filter of ${list}" > ${filterfile}
    # set filter for html elements
    sed '/^#/!d;s/^##//g;s/^#\(.*\)\[.*\]\[.*\]*/s@<([a-zA-Z0-9]+)\\s+.*id=.?\1.*>.*<\/\\1>@@g/g;s/^#\(.*\)/s@<([a-zA-Z0-9]+)\\s+.*id=.?\1.*>.*<\/\\1>@@g/g;s/^\.\(.*\)/s@<([a-zA-Z0-9]+)\\s+.*class=.?\1.*>.*<\/\\1>@@g/g;s/^a\[\(.*\)\]/s@<a.*\1.*>.*<\/a>@@g/g;s/^\([a-zA-Z0-9]*\)\.\(.*\)\[.*\]\[.*\]*/s@<\1.*class=.?\2.*>.*<\/\1>@@g/g;s/^\([a-zA-Z0-9]*\)#\(.*\):.*[:[^:]]*[^:]*/s@<\1.*id=.?\2.*>.*<\/\1>@@g/g;s/^\([a-zA-Z0-9]*\)#\(.*\)/s@<\1.*id=.?\2.*>.*<\/\1>@@g/g;s/^\[\([a-zA-Z]*\).=\(.*\)\]/s@\1^=\2>@@g/g;s/\^/[\/\&:\?=_]/g;s/\.\([a-zA-Z0-9]\)/\\.\1/g' ${file} >> ${filterfile}
    echo "{ +filter{${list}} }" >> ${actionfile}
    echo "*" >> ${actionfile}

    # create domain based blacklist
#    domains=$(sed '/^#/d;/#/!d;s/,~/,\*/g;s/~/;:\*/g;s/^\([a-zA-Z]\)/;:\1/g' ${file})
#    [ -n "${domains}" ] && debug "... creating domainbased filterfiles ..." 1
#    ifs=$IFS
#    IFS=";:"
#    for domain in ${domains}
#    do
#      dns=$(echo ${domain} | awk -F ',' '{print $1}' | awk -F '#' '{print $1}')
#      sed '' ${file} > ${file%\.*}-${dns%~}.script.filter
#      echo "{ +filter{${list}-${dns}} }" >> ${actionfile}
#      echo "${dns}" >> ${actionfile}
#    done
#    IFS=${ifs}

    # whitelist of urls
    echo "{ -block }" >> ${actionfile}
    sed '/^@@.*/!d;s/^@@//g;/\$.*/d;/#/d;s/\./\\./g;s/\?/\\?/g;s/\*/.*/g;s/(/\\(/g;s/)/\\)/g;s/\[/\\[/g;s/\]/\\]/g;s/\^/[\/\&:\?=_]/g;s/^||/\./g;s/^|/^/g;s/|$/\$/g;/|/d' ${file} >> ${actionfile}
    # whitelist of image urls
    echo "{ -block +handle-as-image }" >> ${actionfile}
    sed '/^@@.*/!d;s/^@@//g;/\$.*image.*/!d;s/\$.*image.*//g;/#/d;s/\./\\./g;s/\?/\\?/g;s/\*/.*/g;s/(/\\(/g;s/)/\\)/g;s/\[/\\[/g;s/\]/\\]/g;s/\^/[\/\&:\?=_]/g;s/^||/\./g;s/^|/^/g;s/|$/\$/g;/|/d' ${file} >> ${actionfile}
    
    # install Privoxy actionsfile
    install -o ${PRIVOXY_USER} -g ${PRIVOXY_GROUP} ${VERBOSE} ${actionfile} ${PRIVOXY_DIR}
    if [ "$(grep $(basename ${actionfile}) ${PRIVOXY_CONF})" == "" ]; then
      sed "s/^actionsfile user\.action/actionsfile $(basename ${actionfile})\nactionsfile user.action/" ${PRIVOXY_CONF} > ${TMPDIR}/config
      install -o ${PRIVOXY_USER} -g ${PRIVOXY_GROUP} ${VERBOSE} ${TMPDIR}/config ${PRIVOXY_CONF}
    fi	

    # install Privoxy filterfile
    install -o ${PRIVOXY_USER} -g ${PRIVOXY_GROUP} ${VERBOSE} ${filterfile} ${PRIVOXY_DIR}
    echo "---------"
    echo grep $(basename ${filterfile}) ${PRIVOXY_CONF}
    echo "---------"
    if [ "$(grep $(basename ${filterfile}) ${PRIVOXY_CONF})" == "" ]; then
      sed "s/^\(#*\)filterfile user\.filter/filterfile $(basename ${filterfile})\n\1filterfile user.filter/" ${PRIVOXY_CONF} > ${TMPDIR}/config
      install -o ${PRIVOXY_USER} -g ${PRIVOXY_GROUP} ${VERBOSE} ${TMPDIR}/config ${PRIVOXY_CONF}
    fi	
  done
}

# set command to be run on exit
[ ${DBG} -le 2 ] && trap "rm -fr ${TMPDIR}; exit" INT TERM EXIT

# check lock file
if [ -f "${TMPDIR}/${TMPNAME}.lock" ]; then
  read -r fpid <"${TMPDIR}/${TMPNAME}.lock"
  ppid=$(pidof -o %PPID -x "${TMPNAME}")
  if [[ $fpid = "${ppid}" ]]; then
    echo "An Instance of ${TMPNAME} is already running. Exit" && exit 1
  else
    rm -f "${TMPDIR}/${TMPNAME}.lock"
  fi
fi

# safe PID in lock-file
echo $$ > "${TMPDIR}/${TMPNAME}.lock"

main

# restore default exit command
trap - INT TERM EXIT
[ ${DBG} -lt 3 ] && rm -r ${VERBOSE} "${TMPDIR}"
exit 0
