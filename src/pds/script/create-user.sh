echo -e "${CYAN}${FUNCNAME}${NC}"
useradd -m -d /home/"${GUARD_USER}" -s /bin/bash "${GUARD_USER}"
echo "${GUARD_USER}:${GUARD_PASS}" | chpasswd