#!/usr/bin/env bash
#=================================================
# Description: Install the latest version tmate
# System Required: Debian/Ubuntu or other
# Version: 1.1
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================
echo "GITHUB_TOKEN: $GITHUB_TOKEN"

[ $(uname) != Linux ] && {
    echo -e "This operating system is not supported."
    exit 1
}
[ $EUID != 0 ] && SUDO=sudo
$SUDO echo || exit 1
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"

# Determine architecture
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  ARCH="amd64" ;;
    i386|i686) ARCH="i386" ;;
    aarch64) ARCH="arm64v8" ;;
    armv6l)  ARCH="arm32v6" ;;
    armv7l)  ARCH="arm32v7" ;;
    *) 
        echo -e "${ERROR} This architecture is not supported."
        exit 1 ;;
esac

echo -e "${INFO} Check the version of tmate ..."
# Get latest release info and version
release_info=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" https://api.github.com/repos/tmate-io/tmate/releases/latest)
tmate_ver=$(echo "$release_info" | grep -oP '"tag_name": "\K[^"]+' | sed 's/^v//')

[ -z "$tmate_ver" ] && {
    echo -e "${ERROR} Unable to check the version, network failure or API error."
    exit 1
}

[ $(command -v tmate) ] && {
    [[ $(tmate -V) == "tmate $tmate_ver" ]] && {
        echo -e "${INFO} The latest version is installed."
        exit 0
    }
    echo -e "${INFO} Uninstall the old version ..."
    $SUDO rm -rf $(command -v tmate)
}

tmate_name="tmate-${tmate_ver}-static-linux-${ARCH}"
echo -e "${INFO} Download tmate ..."
curl -fsSLO "https://github.com/tmate-io/tmate/releases/download/${tmate_ver}/${tmate_name}.tar.xz" || {
    echo -e "${ERROR} Unable to download tmate, network failure or other error."
    exit 1
}

echo -e "${INFO} Installation tmate ..."
tar Jxvf ${tmate_name}.tar.xz >/dev/null
$SUDO mv ${tmate_name}/tmate /usr/local/bin && echo -e "${INFO} tmate successful installation !" || {
    echo -e "${ERROR} tmate installation failed !"
    exit 1
}

rm -rf ${tmate_name}*
