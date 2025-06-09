echo -e "${CYAN}${FUNCNAME}${NC}"
if id -u "${GUARD_USER}" >/dev/null 2>&1; then
    echo -e "${YELLOW}User ${GUARD_USER} exists, deleting...${NC}"
    userdel -r "${GUARD_USER}"
fi