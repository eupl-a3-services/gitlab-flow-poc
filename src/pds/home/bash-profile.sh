[[ $- != *i* ]] && return

PS1="\[\033[0;32m\]\u\[\033[0m\]\[\033[0;33m\]@\[\033[0;36m\]\h:\w\$ \[\033[0m\]"

printb() {
    local message=$1

    local NC="\033[0m"
    local GREEN_BG="\033[7;32m"

    echo -e "${GREEN_BG}  ${message}  ${NC}"
}

printc() {
    local color_name=$1
    local prefix=$2
    local message=$3

    local NC="\033[0m"
    local color

    case "$color_name" in
        RED)     color="\033[0;31m" ;;
        GREEN)   color="\033[0;32m" ;;
        YELLOW)  color="\033[0;33m" ;;
        BLUE)    color="\033[0;34m" ;;
        MAGENTA) color="\033[0;35m" ;;
        CYAN)    color="\033[0;36m" ;;
        *)       color="$NC" ;;
    esac

    echo -e "${color}[${prefix}]${NC} ${message}"
}

export -f printb
export -f printc
