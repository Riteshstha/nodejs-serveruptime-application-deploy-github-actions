#!/bin/bash
LOG=${1:-/var/log/nginx/portfolio.access.log}

# real page views: GET requests with status 200, no bots
DATA=$(grep -E '"GET [^"]*" 200 ' "$LOG" | grep -viE 'bot|crawl|spider|curl|uptime')

echo "Total page views:  $(echo "$DATA" | grep -c .)"
echo "Unique visitors:   $(echo "$DATA" | awk '{print $1}' | sort -u | grep -c .)"

echo; echo "== Visits per day =="
echo "$DATA" | awk '{print substr($4,2,11)}' | sort | uniq -c

echo; echo "== Top visitors (IP) =="
echo "$DATA" | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

echo; echo "== Top pages =="
echo "$DATA" | awk '{print $7}' | sort | uniq -c | sort -rn | head -10

echo; echo "== Last 10 visits =="
echo "$DATA" | tail -10 | awk '{print $4, $1, $7}'
