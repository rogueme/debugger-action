#!/usr/bin/env bash
#=================================================
# Description: Install the latest version tmate
# System Required: Debian/Ubuntu or other
# Version: 1.0
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================
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
ARCH=$(uname -m)
if [[ ${ARCH} == "x86_64" ]]; then
    ARCH="amd64"
elif [[ ${ARCH} == "i386" || ${ARCH} == "i686" ]]; then
    ARCH="i386"
elif [[ ${ARCH} == "aarch64" ]]; then
    ARCH="arm64v8"
else
    echo -e "${ERROR} This architecture is not supported."
    exit 1
fi
echo -e "${INFO} Check the version of tmate ..."
curl_args=("-fsSL" "https://api.github.com/repos/tmate-io/tmate/releases/latest" "-o" "tmateapi")
if [ -n "${REPO_TOKEN}" ]; then
    echo -e "${INFO} Using REPO_TOKEN for GitHub API request"
    curl_args+=("-H" "Authorization: Bearer ${REPO_TOKEN}")
fi
http_code=$(curl "${curl_args[@]}" -w "%{http_code}")
if [ "${http_code}" -ne 200 ]; then
    echo -e "${ERROR} GitHub API request failed (HTTP code: ${http_code})"
    echo -e "${ERROR} API response preview: $(cat tmateapi | head -10)"
    exit 1
fi
tmate_ver=$(grep -o '"tag_name": ".*"' tmateapi | head -n 1 \
    | sed 's/"tag_name": "//g' \
    | sed 's/"//g' \
    | sed 's/^v//')
[ -z $tmate_ver ] && {
    echo -e "${ERROR} Unable to check the version, network failure or API error."
    exit 1
}
if [ -z "${tmate_ver}" ]; then
    echo -e "${INFO} Use fallback version: 2.4.0 (failed to parse latest version)"
    tmate_ver="2.4.0"
fi
[ $(command -v tmate) ] && {
    [[ $(tmate -V) != "tmate $tmate_ver" ]] && {
        echo -e "${INFO} Uninstall the old version ..."
        $SUDO rm -rf $(command -v tmate)
    } || {
        echo -e "${INFO} The latest version is installed."
        exit 0
    }
}
tmate_name="tmate-${tmate_ver}-static-linux-${ARCH}"
echo -e "${INFO} Download tmate ..."
curl -fsSLO "https://github.com/tmate-io/tmate/releases/download/v${tmate_ver}/${tmate_name}.tar.xz" || {
    echo -e "${ERROR} Unable to download tmate, network failure or other error."
    exit 1
}
echo -e "${INFO} Installation tmate ..."
tar Jxvf ${tmate_name}.tar.xz >/dev/null
$SUDO mv ${tmate_name}/tmate /usr/local/bin && echo -e "${INFO} tmate successful installation !" || {
    echo -e "${ERROR} tmate installation failed !"
    exit 1
}
rm -rf ${tmate_name}* tmateapi
