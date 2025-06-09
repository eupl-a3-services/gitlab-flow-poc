RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}${FUNCNAME}${NC}"
if [ "$EUID" -ne 0 ]; then
    echo -e "$RED" "ERROR: This script must be run as root." ${NC}
    return
fi
if [ -z "${GUARD_USER+x}" ]; then
    echo -e "$RED" "ERROR: Environment variable GUARD_USER is not set."${NC}
    return
fi
chmod 777 /cache-volume
chmod 777 /secure-storage

SESSION_MANAGER=/opt/session-manager
mkdir -p ${SESSION_MANAGER}
rm -rf "${SESSION_MANAGER}"/*

mkdir -p /secure-storage/key
mkdir -p /secure-storage/env
mkdir -p /secure-storage/kube

chmod 777 /secure-storage/key
chmod 777 /secure-storage/env
chmod 777 /secure-storage/kube