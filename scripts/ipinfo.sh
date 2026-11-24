#!/bin/bash
# Usage: sudo ~/ipinfo.sh <public-ip>
IP=$1
LOGBASE=/var/log/nginx/portfolio.access.log

[ -z "$IP" ] && { echo "Usage: sudo $0 <public-ip>"; exit 1; }
if ! [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || $IP =~ ^[0-9a-fA-F:]+$ ]]; then
  echo "'$IP' is not a valid IP address"; exit 1
fi

hr() { echo "------------------------------------------------------------"; }

echo; hr; echo " IP REPORT: $IP"; hr

# ---------- 1. Geolocation and network owner ----------
J=$(curl -s -m 5 "http://ip-api.com/json/$IP?fields=status,message,continent,country,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,reverse,mobile,proxy,hosting,query")
python3 - "$J" <<'PY'
import sys, json
try:
    d = json.loads(sys.argv[1])
except Exception:
    print(" Lookup failed (no internet, or rate limit reached)"); sys.exit()
if d.get("status") != "success":
    print(" Lookup failed:", d.get("message", "unknown error")); sys.exit()

yn = lambda b: "Yes" if b else "No"
rows = [
    ("Continent",       d.get("continent")),
    ("Country",         d.get("country")),
    ("Region",          d.get("regionName")),
    ("City",            d.get("city")),
    ("ZIP",             d.get("zip") or "-"),
    ("Coordinates",     f'{d.get("lat")}, {d.get("lon")}'),
    ("Map",             f'https://www.google.com/maps?q={d.get("lat")},{d.get("lon")}'),
    ("Timezone",        d.get("timezone")),
    ("ISP",             d.get("isp")),
    ("Organization",    d.get("org") or "-"),
    ("AS number",       d.get("as")),
    ("AS name",         d.get("asname")),
    ("Reverse DNS",     d.get("reverse") or "-"),
    ("Mobile network",  yn(d.get("mobile"))),
    ("Proxy / VPN",     yn(d.get("proxy"))),
    ("Datacenter/Cloud", yn(d.get("hosting"))),
]
for k, v in rows:
    print(f" {k:<17}{v}")

print()
if d.get("hosting"):
    v = "Datacenter/cloud IP: very likely a bot, scanner or server, not a person"
elif d.get("proxy"):
    v = "Proxy/VPN: real location is hidden"
elif d.get("mobile"):
    v = "Mobile carrier: IP is shared by many users, location is approximate"
else:
    v = "Looks like a normal residential or business connection"
print(" Verdict:", v)
PY

# ---------- 2. Whois ----------
echo; hr; echo " WHOIS (registry data)"; hr
if command -v whois >/dev/null; then
  whois "$IP" 2>/dev/null \
    | grep -iE '^(netname|orgname|org-name|descr|country|cidr|inetnum|netrange|abuse-mailbox|orgabuseemail)' \
    | sort -u | head -12 | sed 's/^/ /'
else
  echo " whois not installed (sudo apt install whois)"
fi

# ---------- 3. Activity on your site ----------
echo; hr; echo " ACTIVITY ON YOUR PORTFOLIO"; hr
FILES=$(ls -1 ${LOGBASE}* 2>/dev/null | sort -rV)
if [ -z "$FILES" ]; then
  echo " No log files found at $LOGBASE"; echo; exit 0
fi
HITS=$(zcat -f $FILES 2>/dev/null | awk -v ip="$IP" '$1==ip')
if [ -z "$HITS" ]; then
  echo " No requests from this IP in your portfolio logs."
  echo " (Run with sudo if the log is not readable.)"; echo; exit 0
fi

echo " Total requests:  $(echo "$HITS" | grep -c .)"
echo " First seen:      $(echo "$HITS" | head -1 | awk '{print substr($4,2), $5}' | tr -d ']')"
echo " Last seen:       $(echo "$HITS" | tail -1 | awk '{print substr($4,2), $5}' | tr -d ']')"
SUS=$(echo "$HITS" | grep -ciE '\.env|\.git|wp-login|wp-admin|phpmyadmin|/admin|/config|\.php|shell|passwd')
echo " Suspicious paths: $SUS request(s) (.env, wp-login, .php, admin, ...)"

echo; echo " Status codes:"
echo "$HITS" | awk '{print $9}' | sort | uniq -c | sort -rn | sed 's/^/   /'

echo; echo " Methods:"
echo "$HITS" | awk '{print $6}' | tr -d '"' | sort | uniq -c | sort -rn | sed 's/^/   /'

echo; echo " Pages requested:"
echo "$HITS" | awk '{print $7}' | sort | uniq -c | sort -rn | head -10 | sed 's/^/   /'

echo; echo " Browsers / user agents:"
echo "$HITS" | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -5 | cut -c1-110 | sed 's/^/   /'

echo; echo " Referrers:"
echo "$HITS" | awk -F'"' '{print $4}' | sort | uniq -c | sort -rn | head -5 | sed 's/^/   /'

echo; echo " Last 10 requests:"
echo "$HITS" | tail -10 | awk '{print "   " substr($4,2), $6, $7, $9}' | tr -d '"'
echo
