#!/usr/bin/env bash

shopt -s nullglob

ARCHIVE_DIR="/opt/postgres/.archive"

BOLD="\033[1m"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

cutoff_30d=$(date -d '30 days ago' +%s)
cutoff_6m=$(date -d '6 months ago' +%s)
cutoff_24m=$(date -d '24 months ago' +%s)

echo -e "${YELLOW}Scanning: $ARCHIVE_DIR${NC}"
echo

for dir in "$ARCHIVE_DIR"/*; do
    [[ -d "$dir" ]] || continue

    files=( "$dir"/*.dump.tar.gz )
    (( ${#files[@]} == 0 )) && continue

    echo -e "${YELLOW}DIR: $dir${NC}"

    tmp=$(mktemp)

    count_30d=0
    count_mon=0
    count_1st=0
    count_del=0
    count_keep=0

    for file in "${files[@]}"; do
        [[ -f "$file" ]] || continue

        filename=$(basename "$file")

        if [[ ! "$filename" =~ ^.+-([0-9]{6})-([0-9]{6})-b\.dump\.tar\.gz$ ]]; then
            continue
        fi

        yymmdd="${BASH_REMATCH[1]}"
        hhmmss="${BASH_REMATCH[2]}"

        yy=${yymmdd:0:2}
        mm=${yymmdd:2:2}
        dd=${yymmdd:4:2}

        HH=${hhmmss:0:2}
        MI=${hhmmss:2:2}
        SS=${hhmmss:4:2}

        year=$((2000 + 10#$yy))

        ts=$(date -d "${year}-${mm}-${dd} ${HH}:${MI}:${SS}" +%s 2>/dev/null) || continue

        labels=()

        (( ts >= cutoff_30d )) && labels+=("30D")

        if (( ts >= cutoff_6m )); then
            [[ "$(date -d "@$ts" +%u)" == "1" ]] && labels+=("MON")
        fi

        if (( ts >= cutoff_24m )); then
            [[ "$(date -d "@$ts" +%d)" == "01" ]] && labels+=("1ST")
        fi

        relpath="${file#$ARCHIVE_DIR/}"

        if ((${#labels[@]} == 0)); then
            tag="DEL"
            color="$RED"
            ((count_del++))
            rm -f "$file"
        else
            tag=$(IFS=,; echo "${labels[*]}")
            ((count_keep++))

            [[ " ${labels[*]} " == *" 30D "* ]] && ((count_30d++))
            [[ " ${labels[*]} " == *" MON "* ]] && ((count_mon++))
            [[ " ${labels[*]} " == *" 1ST "* ]] && ((count_1st++))

            if [[ " ${labels[*]} " == *" 30D "* ]]; then
                color="$GREEN"
            elif [[ " ${labels[*]} " == *" MON "* ]]; then
                color="$BLUE"
            else
                color="$MAGENTA"
            fi
        fi

        printf '%s|%b[%-11s] %s%b\n' \
            "$ts" \
            "$color" \
            "$tag" \
            "$relpath" \
            "$NC" >> "$tmp"

    done

    sort -t'|' -k1,1nr "$tmp" | cut -d'|' -f2-

    rm -f "$tmp"

    echo
    printf "${BOLD}Retention Summary:\n${NC}"

    printf "  %-7s %-28s %s\n" "POLICY" "DESCRIPTION" "COUNT"
    echo "  -----------------------------------------------"
    printf "  ${GREEN}%-7s${NC} %-28s %d\n" "30D"  "last 30 days"        "$count_30d"
    printf "  ${BLUE}%-7s${NC} %-28s %d\n" "MON"  "Mondays (6 months)"   "$count_mon"
    printf "  ${MAGENTA}%-7s${NC} %-28s %d\n" "1ST"  "first day (24 months)" "$count_1st"
    printf "  ${RED}%-7s${NC} %-28s %d\n" "DEL"  "delete candidates"     "$count_del"
    echo "  -----------------------------------------------"
    printf "  %-7s %-28s %d\n" "TOTAL" "all files (current)" "$((count_keep + count_del))"
    echo "  ==============================================="
    printf "  %-7s %-28s %d\n" "KEEP" "all files total" "$count_keep"

    echo

done

df -h "$ARCHIVE_DIR" | awk -v dir="$ARCHIVE_DIR" 'NR==2 {
    # Definícia farieb
    BOLD="\033[1m"
    CYAN="\033[36m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RESET="\033[0m"
    
    # Výpočet percent pre dynamickú farbu (voliteľné, ak je nad 85%, zmení sa na žltú/červenú)
    split($5, pct, "%")
    color_used = GREEN
    if (pct[1] >= 85) color_used = YELLOW
    
    print BOLD "Archive Summary:" RESET
    print "  Directory: " CYAN dir RESET
    print "  Storage:   " $6
    print "  Size:      " $2
    print "  Used:      " color_used $3 " (" $5 ")" RESET
    print "  Avail:     " GREEN $4 RESET
    print ""
}'
echo -e "${YELLOW}Done${NC}"
