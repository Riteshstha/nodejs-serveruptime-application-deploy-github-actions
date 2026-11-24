#!/bin/bash
# Usage: sudo ~/visitors_table.sh [IP_TO_EXCLUDE]
LOGBASE=/var/log/nginx/portfolio.access.log
EXCLUDE=${1:-none}
CACHE=/var/tmp/visitor_geo_cache
touch "$CACHE"

# oldest -> newest, including rotated and gzipped logs
FILES=$(ls -1 ${LOGBASE}* 2>/dev/null | grep -v error | sort -rV)

# real page views only: GET with 200/304, no bots, no excluded IP
DATA=$(zcat -f $FILES | grep -E '"GET [^"]*" (200|304) ' \
        | grep -viE 'bot|crawl|spider|curl|uptime|python|scanner' \
        | grep -v "^$EXCLUDE ")

[ -z "$DATA" ] && { echo "No visits found."; exit 0; }

echo "Total page views: $(echo "$DATA" | grep -c .)"
echo "Unique visitors:  $(echo "$DATA" | awk '{print $1}' | sort -u | grep -c .)"
echo

geo() {
  local ip=$1 line r
  line=$(grep -m1 "^$ip|" "$CACHE")
  if [ -z "$line" ]; then
    r=$(curl -s -m 3 "http://ip-api.com/line/$ip?fields=country,city,isp" | paste -sd'|')
    [ "$(echo "$r" | tr -cd '|' | wc -c)" -ne 2 ] && r="-|-|-"
    echo "$ip|$r" >> "$CACHE"
    line="$ip|$r"
  fi
  echo "${line#*|}"
}

{
echo "IP|VISITS|COUNTRY|CITY|ISP|BROWSER|OS|FIRST SEEN|LAST SEEN|LAST PAGE"
echo "$DATA" | awk '
{
  ip=$1; ts=substr($4,2); split($0,q,"\""); ua=q[6]
  cnt[ip]++
  if (!(ip in first)) first[ip]=ts
  last[ip]=ts; page[ip]=$7

  b="Other"
  if (ua ~ /Edg/) b="Edge"
  else if (ua ~ /OPR/) b="Opera"
  else if (ua ~ /Firefox/) b="Firefox"
  else if (ua ~ /Chrome/) b="Chrome"
  else if (ua ~ /Safari/) b="Safari"
  br[ip]=b

  o="Other"
  if (ua ~ /Windows/) o="Windows"
  else if (ua ~ /Android/) o="Android"
  else if (ua ~ /iPhone|iPad/) o="iOS"
  else if (ua ~ /Mac OS X/) o="macOS"
  else if (ua ~ /Linux/) o="Linux"
  os[ip]=o
}
END { for (ip in cnt) print ip"|"cnt[ip]"|"br[ip]"|"os[ip]"|"first[ip]"|"last[ip]"|"page[ip] }' \
| sort -t'|' -k2 -nr \
| while IFS='|' read -r ip n b o f l p; do
    echo "$ip|$n|$(geo "$ip")|$b|$o|$f|$l|$p"
  done
} | column -t -s'|'
