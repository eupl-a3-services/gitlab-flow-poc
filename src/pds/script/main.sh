RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Exiting.${NC}"
    return 1
fi
if [ -z "${GUARD_USER}" ] || [ -z "${GUARD_PASS}" ]; then
    echo -e "${RED}GUARD_USER or GUARD_PASS is not set. Exiting.${NC}"
    return 2
fi

echo -e "${MAGENTA}${FUNCNAME}${NC}"
root_prompt
cleanup_user
create_user
setup_environment
setup_scripts

unset GUARD_USER
unset GUARD_PASS
echo -e "${GREEN}Setup finished. You can now run 'pds' to activate the Production Deployment Session.${NC}"