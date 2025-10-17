#!/bin/bash
#SCRIPT_NAME=/usr/local/bin/key-value-preview; cat <<"EOS" > ${SCRIPT_NAME}

function key_value_preview(){
    local HEADER="$1"
    local ROW="$2"
    local KEY VALUE
    IFS='|' read -r -a KEYS <<< "${HEADER}"
    IFS='|' read -r -a VALUES <<< "${ROW}"

    if [[ "$ROW" != *"|"* ]]; then
        echo "$ROW"
        return
    fi

    for index in "${!KEYS[@]}"; do
        KEY=$(echo "${KEYS[index]}" | sed 's/^[ \t]*//;s/[ \t]*$//'):
        VALUE=$(echo "${VALUES[index]}" | sed 's/^[ \t]*//;s/[ \t]*$//')
        printf "\e[36m%-22s\e[0m%s\n" "$KEY" "$VALUE"
    done
}

key_value_preview "$@"

exit 0
EOS
chmod 755 ${SCRIPT_NAME}
${SCRIPT_NAME}