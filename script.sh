#!/bin/bash

set -eo pipefail

uriencode() {
  s="${1//'%'/%25}"
  s="${s//' '/%20}"
  s="${s//'"'/%22}"
  s="${s//'#'/%23}"
  s="${s//'$'/%24}"
  s="${s//'&'/%26}"
  s="${s//'+'/%2B}"
  s="${s//','/%2C}"
  s="${s//'/'/%2F}"
  s="${s//':'/%3A}"
  s="${s//';'/%3B}"
  s="${s//'='/%3D}"
  s="${s//'?'/%3F}"
  s="${s//'@'/%40}"
  s="${s//'['/%5B}"
  s="${s//']'/%5D}"
  printf %s "$s"
}

# For mount docker volume, do not directly use '/tmp' as the dir
TMATE_TERM="${TMATE_TERM:-screen-256color}"
TIMESTAMP="$(date +%s%3N)"
TMATE_DIR="/tmp/tmate-${TIMESTAMP}"
TMATE_SOCK="${TMATE_DIR}/session.sock"
TMATE_SESSION_NAME="tmate-${TIMESTAMP}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# Shorten this URL to avoid mask by Github Actions Runner
README_URL="https://github.com/tete1030/safe-debugger-action/blob/master/README.md"
README_URL_SHORT="$(curl -si https://git.io -F "url=${README_URL}" | tr -d '\r' | sed -En 's/^Location: (.*)/\1/p')"
CONTINUE_FILE="/tmp/continue"
cleanup() {
  if [ -n "${container_id}" ] && [ "x${docker_type}" = "ximage" ]; then
    echo "Current docker container will be saved to your image: ${TMATE_DOCKER_IMAGE_EXP}"
    docker stop -t1 "${container_id}" > /dev/null
    docker commit --message "Commit from safe-debugger-action" "${container_id}" "${TMATE_DOCKER_IMAGE_EXP}"
    docker rm -f "${container_id}" > /dev/null
  fi
  tmate -S "${TMATE_SOCK}" kill-server || true
  sed -i '/alias attach_docker/d' ~/.bashrc || true
  rm -rf "${TMATE_DIR}"
}

if [[ -n "$SKIP_DEBUGGER" ]]; then
  echo "Skipping debugger because SKIP_DEBUGGER enviroment variable is set"
  exit
fi

# Install tmate on macOS or Ubuntu
echo Setting up tmate and openssl...
if [ -x "$(command -v brew)" ]; then
  brew install tmate > /tmp/brew.log
fi
if [ -x "$(command -v apt-get)" ]; then
  "${SCRIPT_DIR}/tmate.sh"
fi

# Generate ssh key if needed
[ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# Run deamonized tmate
echo Running tmate...

now_date="$(date)"
timeout=$(( ${TIMEOUT_MIN:=30}*60 ))
kill_date="$(date -d "${now_date} + ${timeout} seconds")"

TMATE_SESSION_PATH="$(pwd)"
mkdir "${TMATE_DIR}"

container_id=''
if [ -n "${TMATE_DOCKER_IMAGE}" ] || [ -n "${TMATE_DOCKER_CONTAINER}" ]; then
  if [ -n "${TMATE_DOCKER_CONTAINER}" ]; then
    docker_type="container"
    container_id="${TMATE_DOCKER_CONTAINER}"
  else
    docker_type="image"
    if [ -z "${TMATE_DOCKER_IMAGE_EXP}" ]; then
      TMATE_DOCKER_IMAGE_EXP="${TMATE_DOCKER_IMAGE}"
    fi
    echo "Creating docker container for running tmate"
    container_id=$(docker create -t "${TMATE_DOCKER_IMAGE}")
    docker start "${container_id}"
  fi
  DK_SHELL="docker exec -e TERM='${TMATE_TERM}' -it '${container_id}' /bin/bash -il"
  DOCKER_MESSAGE_CMD='printf "This window is running in Docker '"${docker_type}"'.\nTo attach to Github Actions runner, exit current shell\nor create a new tmate window by \"Ctrl-b, c\"\n(This shortcut is only available when connecting through ssh)\n\n"'
  FIRSTWIN_MESSAGE_CMD='printf "This window is now running in GitHub Actions runner.\nTo attach to your Docker '"${docker_type}"' again, use \"attach_docker\" command\n\n"'
  SECWIN_MESSAGE_CMD='printf "The first window of tmate has already been attached to your Docker '"${docker_type}"'.\nThis window is running in GitHub Actions runner.\nTo attach to your Docker '"${docker_type}"' again, use \"attach_docker\" command\n\n"'
  echo "unalias attach_docker 2>/dev/null || true ; alias attach_docker='${DK_SHELL}'" >> ~/.bashrc
  (
    cd "${TMATE_DIR}"
    TERM="${TMATE_TERM}" tmate -v -S "${TMATE_SOCK}" new-session -s "${TMATE_SESSION_NAME}" -c "${TMATE_SESSION_PATH}" -d "/bin/bash --noprofile --norc -c '${DOCKER_MESSAGE_CMD} ; ${DK_SHELL} ; ${FIRSTWIN_MESSAGE_CMD} ; /bin/bash -li'" \; set-option default-command "/bin/bash --noprofile --norc -c '${SECWIN_MESSAGE_CMD} ; /bin/bash -li'" \; set-option default-terminal "${TMATE_TERM}"
  )
else
  echo "unalias attach_docker 2>/dev/null || true" >> ~/.bashrc
  (
    cd "${TMATE_DIR}"
    TERM="${TMATE_TERM}" tmate -v -S "${TMATE_SOCK}" new-session -s "${TMATE_SESSION_NAME}" -c "${TMATE_SESSION_PATH}" -d \; set-option default-terminal "${TMATE_TERM}"
  )
fi

tmate -S "${TMATE_SOCK}" wait tmate-ready
TMATE_PID="$(tmate -S "${TMATE_SOCK}" display -p '#{pid}')"
TMATE_SERVER_LOG="${TMATE_DIR}/tmate-server-${TMATE_PID}.log"
if [ ! -f "${TMATE_SERVER_LOG}" ]; then
  echo "::error::No server log found" >&2
  echo "Files in TMATE_DIR:" >&2
  ls -l "${TMATE_DIR}"
  exit 1
fi


SSH_LINE="$(tmate -S "${TMATE_SOCK}" display -p '#{tmate_ssh}' |cut -d ' ' -f2)"
WEB_LINE="$(tmate -S "${TMATE_SOCK}" display -p '#{tmate_web}')"

  MSG="SSH: ${SSH_LINE}\nWEB: ${WEB_LINE}"
  echo -e "\e[32m  \e[0m"
  echo -e " SSH：\e[32m ${SSH_LINE} \e[0m"
  echo -e " Web：\e[33m ${WEB_LINE} \e[0m"
  echo -e "\e[32m  \e[0m"
  
TIMEOUT_MESSAGE="如果您未连接SSH，则在${timeout}秒内自动跳过，要立即跳过此步骤，只需连接SSH并退出即可"
echo -e "$TIMEOUT_MESSAGE"

if [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]] && [[ "$INFORMATION_NOTICE" == "TG" ]]; then
  echo -n "Sending information to Telegram Bot......"
  curl -k --data chat_id="${TELEGRAM_CHAT_ID}" --data "text=  Web: ${WEB_LINE}
  
  SSH: ${SSH_LINE}" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
elif [[ -n "$PUSH_PLUS_TOKEN" ]] && [[ "$INFORMATION_NOTICE" == "PUSH" ]]; then
  echo -n "Sending information to pushplus......"
  curl -k --data token=${PUSH_PLUS_TOKEN} --data title="SSH连接代码" --data "content=Web: ${WEB_LINE}
  
  SSH: ${SSH_LINE}" "http://www.pushplus.plus/send"
fi

echo ""
echo ______________________________________________________________________________________________
echo ""

# Wait for connection to close or timeout
display_int=${DISP_INTERVAL_SEC:=30}
timecounter=0

user_connected=0
while [ -S "${TMATE_SOCK}" ]; do
  connected=0
  grep -qE '^[[:digit:]\.]+ A mate has joined' "${TMATE_SERVER_LOG}" && connected=1
  if [ ${connected} -eq 1 ] && [ ${user_connected} -eq 0 ]; then
    echo "你刚刚连接超时,现在已禁用"
    user_connected=1
  fi
  if [ ${user_connected} -ne 1 ]; then
    if (( timecounter > timeout )); then
      echo "等待连接超时,现在跳过SSH此步骤"
      cleanup

      if [ "x$TIMEOUT_FAIL" = "x1" ] || [ "x$TIMEOUT_FAIL" = "xtrue" ]; then
        exit 1
      else
        exit 0
      fi
    fi
  fi

  if (( timecounter % display_int == 0 )); then
      echo "您可以使用SSH终端连接，或者使用网页直接连接"
      echo "终端连接IP为SSH:后面的代码，网页连接直接点击Web后面的链接，然后以[ctrl+c]开始和[ctrl+d]结束"
      echo "容器编译需要先执行 'docker exec -it --user root openwrt-builder bash -c \"cd /workdir && bash\"' 进入容器项目共享目录"
      echo "命令：cd openwrt && make menuconfig"
      echo -e "提示: 运行 'touch ${CONTINUE_FILE}' 可跳过SSH终端执行下一个步骤."
      echo -e "\e[32m  \e[0m"
      echo -e " SSH: \e[32m ${SSH_LINE} \e[0m"
      echo -e " Web: \e[33m ${WEB_LINE} \e[0m"
      echo -e "\e[32m  \e[0m"
      
     [ "x${user_connected}" != "x1" ] && (
       echo -e "\n如果您还不连接SSH，\e[31m将在\e[0m $(( timeout-timecounter )) 秒内自动跳过"
       echo "要立即跳过此步骤，只需连接SSH并正确退出即可"
     )
    echo ______________________________________________________________________________________________
  fi

  sleep 1
  if [[ -e ${CONTINUE_FILE} ]]; then
      echo -e "${INFO} Continue to the next step."
      exit 0
  fi
  timecounter=$((timecounter+1))
done

echo "The connection is terminated."
cleanup
