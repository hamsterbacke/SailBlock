#!/bin/bash
#set -x
#set -e
# this script compiles privoxy with static pcre and zlib for ARM with soft floating.
# those packages are needed for crosscompiling on a i686 with ubuntu 15.04:
# apt-get install autoconf g++-arm-linux-gnueabi gcc-arm-linux-gnueabi binutils-arm-linux-gnueabi libc6-armel-cross libc6-dev-armel-cross

COMPILE_ROOT=$(pwd)
rm -r ~/bin/privoxy
mkdir -p ~/bin/privoxy
cd ~/bin/privoxy
BASE=$(pwd)
SRC="${BASE}/src"
mkdir -p ${SRC}
WGET="wget -nc --prefer-family=IPv4"
DEST="${BASE}/opt"
CC="arm-linux-gnueabi-gcc"
CXX="arm-linux-gnueabi-g++"
LDFLAGS="-L${DEST}/lib"
CPPFLAGS="-I${DEST}/include"
CXXFLAGS="-Os -s"
MAKE="make -j$(nproc)"
CONFIGURE="./configure --host=arm-linux"
PCRE_DL_LINK="http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.38.tar.gz"
ZLIB_DL_LINK="http://zlib.net/zlib-1.2.8.tar.gz"
PRIVOXY_DL_LINK="http://downloads.sourceforge.net/project/ijbswa/Sources/3.0.23%20%28stable%29/privoxy-3.0.23-stable-src.tar.gz"

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir -p ${SRC}/zlib
cd ${SRC}/zlib
${WGET} ${ZLIB_DL_LINK}
tar zxvf ${ZLIB_DL_LINK##*/}
cd $(echo -n ${ZLIB_DL_LINK##*/} | sed 's/.tar.gz//')

LDFLAGS=${LDFLAGS} \
CPPFLAGS=${CPPFLAGS} \
CROSS_PREFIX=arm-linux-gnueabi- \
./configure \
--prefix=/opt

${MAKE}
make install DESTDIR=${BASE}

######## ####################################################################
# PCRE # ####################################################################
######## ####################################################################

mkdir -p ${SRC}/pcre
cd ${SRC}/pcre
${WGET} ${PCRE_DL_LINK}
tar zxvf ${PCRE_DL_LINK##*/}
cd $(echo -n ${PCRE_DL_LINK##*/} | sed 's/.tar.gz//')

CC=${CC} \
CXX=${CXX} \
LDFLAGS=${LDFLAGS} \
CPPFLAGS=${CPPFLAGS} \
${CONFIGURE} \
--prefix=/opt

${MAKE}
make install DESTDIR=${BASE}

########### #################################################################
# PRIVOXY # #################################################################
########### #################################################################

mkdir -p ${SRC}/privoxy
cd ${SRC}/privoxy
${WGET} ${PRIVOXY_DL_LINK}
tar zxvf ${PRIVOXY_DL_LINK##*/}
cd $(echo -n ${PRIVOXY_DL_LINK##*/} | sed 's/-src.tar.gz//')

autoheader
autoconf

CC=${CC} \
CXX=${CXX} \
CPPFLAGS=${CPPFLAGS} \
CXXFLAGS=${CXXFLAGS} \
LDFLAGS=${LDFLAGS} \
${CONFIGURE}

${MAKE}
#${MAKE} LIBS="-static -lpcre -lz"
make install DESTDIR=${BASE}/privoxy

cp -p "${COMPILE_ROOT}/privoxy-blocklist.sh" "${BASE}/privoxy/usr/local/etc/privoxy/"
cp -p "${COMPILE_ROOT}/privoxy-iptables-start.sh" "${BASE}/privoxy/usr/local/etc/privoxy/"
cp -p "${COMPILE_ROOT}/privoxy-iptables-stop.sh" "${BASE}/privoxy/usr/local/etc/privoxy/"
cp -p "${COMPILE_ROOT}/controller.sh" "${BASE}/privoxy/usr/local/etc/privoxy/"

# configure privoxy to accept intercepted requests
sed -i -e 's/accept-intercepted-requests 0/accept-intercepted-requests 1/' \
       -e 's/enforce-blocks 0/enforce-blocks 1/' "${BASE}/privoxy/usr/local/etc/privoxy/config"

# configure anti adlbock filter
cat <<-'EOFTEXT' >> "${BASE}/privoxy/usr/local/etc/privoxy/user.filter"
	FILTER: GM_function
	s@(^[^;]*?(?:<head[^>]*?>|<body[^>]*?>|<script[^>]*?>[^>]*?</script>))@<script src="https://raw.githubusercontent.com/reek/anti-adblock-killer/master/anti-adblock-killer.user.js"></script>\n$1@i
	
	FILTER: fixaakiller
	s@if \(Aak\.getScriptManager\(\)\) \{\s*?\
	      Aak\.registerCommands\(\);\s*?\
	      Aak\.update\.automatic\(\);\s*?\
	      Aak\.listDetect\(\);\s*?\
	      Aak\.blockDetect\(\);\s*?\
	    \} else \{ \/\/ Native\s*?\
	      throw "Sorry\! No Native support\.\.";\s*?\
	    \}\
	@//if (Aak.getScriptManager()) {\n\
	      Aak.registerCommands();\n\
	      Aak.update.automatic();\n\
	      Aak.listDetect();\n\
	      Aak.blockDetect();\n\
	    //} else { // Native\n\
	    //  throw "Sorry! No Native support..";\n\
	    //}@i

	FILTER: aakiller
	s@(<(?:\/body)[^>]*?>)@$1\n\<script src="https://raw.githubusercontent.com/reek/anti-adblock-killer/master/anti-adblock-killer.user.js" type="text/javascript"></script>\n\@i
EOFTEXT
cat <<-'EOFTEXT' >> "${BASE}/privoxy/usr/local/etc/privoxy/user.action"
	### enable greasemonkey for privoxy
	{+filter{GM_function}}
	/
	
	### enable fixer for reek
	{+filter{fixaakiller}}
	raw.githubusercontent.com/reek/anti-adblock-killer/master/
	
	### enable antiadblockkiller script to work with privoxy
	{+filter{aakiller}}
EOFTEXT

cd "${COMPILE_ROOT}"
fpm -s dir -t rpm -n privoxy -v $(cat "${BASE}/privoxy/usr/local/etc/privoxy/config" | head -n1 | awk '{print $7}') -C "${BASE}/privoxy" -a noarch --rpm-user privoxy --rpm-group privoxy --before-install /home/hamster/bin/privoxy-pre-install.sh --after-install /home/hamster/bin/privoxy-post-install.sh --before-remove /home/hamster/bin/privoxy-pre-remove.sh
