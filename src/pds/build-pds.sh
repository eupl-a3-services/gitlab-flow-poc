#!/bin/bash
mkdir -p opt/dist/pds

PDS_INSTALL=opt/dist/pds/install-pds.sh

_br() {
  {
    echo
  } >> "${PDS_INSTALL}"
}

_text() {
  {
    printf "%s " "$@"
    echo
  } >> "${PDS_INSTALL}"
}

_heredoc() {
  local FOLDER=$1
  local NAME=$2
  local content_file="$(dirname "${BASH_SOURCE[0]}")/${FOLDER}/${NAME}.sh"
  local target_file=""
  local target_own=""
  local target_mod=""

  if [[ "$FOLDER" == "sm" ]]; then
    target_file='${SESSION_MANAGER}/'${NAME}
    target_own='${GUARD_USER}:${GUARD_USER}'
    target_mod="700"
  elif [[ "$FOLDER" == "home" ]]; then
    target_file='/home/${GUARD_USER}/.'${NAME//-/_}
    target_own='${GUARD_USER}:${GUARD_USER}'
    target_mod="600"
  elif [[ "$FOLDER" == "bin" ]]; then
    target_file='/usr/local/bin/pds'
    #target_own='${GUARD_USER}:${GUARD_USER}'
    target_mod="+x"
  else
    echo "Unsupported folder: $FOLDER" >&2
    return 1
  fi

  {
    echo
    echo "cat <<'EOF' > \"${target_file}\""
    cat "${content_file}"
    echo
    echo "EOF"
    echo
    if [[ -n "${target_own}" ]]; then
        echo chown \""${target_own}"\" \""${target_file}"\"
    fi
    if [[ -n "${target_mod}" ]]; then
        echo chmod ${target_mod} \"${target_file}\"
    fi
  } >> "${PDS_INSTALL}"
}

_heredoc_profile (){
  {
    echo
    echo 'cat <<EOF >> "/home/${GUARD_USER}/.bash_profile"'
    echo 'trap "bash /home/${GUARD_USER}/.bash_trap" EXIT SIGHUP SIGTERM SIGINT'
    echo
    echo PDS_REVISION=${AMS_REVISION}
    echo PDS_BUILD=${AMS_BUILD}
    echo
    echo '. /home/${GUARD_USER}/.bash_session'
    echo sm
    echo 'EOF'
  } >> "${PDS_INSTALL}"
}

_script() {
  local FILE=$1
  local NAME=${1//-/_}
  local content_file="$(dirname "${BASH_SOURCE[0]}")/script/${FILE}.sh"
  {
    echo
    echo "${NAME}() {"
    sed 's/^/\t/' "${content_file}"
    echo
    echo "} # ${NAME}"
  } >> "${PDS_INSTALL}"
}


> "${PDS_INSTALL}"

_text '#!/bin/bash'
_br

_text set +o history  # Disable history saving

_br
_text GUARD_USER=pds-guard
_text GUARD_PASS=Pr0dPa55w0rd

_script root-prompt
_script cleanup-user
_script create-user
_script setup-environment

_br
_text "setup_scripts () {"
    _heredoc home bash-profile
    _heredoc_profile
    _heredoc home bash-session
    _heredoc home bash-trap

    _heredoc sm sm
    _heredoc sm session-vault
    _heredoc sm env-session-request
    _heredoc sm kube-session-request
    _heredoc sm session-token

    _heredoc bin pds
_text "} # setup_scripts"

_script main

_br
_text "main"
_text "set -o history  # Re-enable history saving"
_text "pds"

echo -e "${GREEN}✓ File '${PDS_INSTALL}' has been created.${NC}"