#!/usr/bin/env bash
# wol.sh — Wake-on-LAN with ARP/hostname discovery
# Version: 1.0.0
#
# Usage:
#   wol.sh                    interactive menu
#   wol.sh <hostname|MAC>     wake a specific host directly
#
# Merges ARP table, /etc/hosts, and known-hosts list into a single menu.
# Selects any reachable host by number, hostname, or MAC.

set -euo pipefail

# ── Known hosts (static fallback — always present in menu) ───────────────────
# Format: "hostname MAC"
KNOWN_HOSTS=(
    "ishimura fc:9d:05:04:91:c6"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

_have() { command -v "$1" &>/dev/null; }

_die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

_wol() {
    local mac="$1" label="${2:-$1}"
    printf 'Sending magic packet to \033[1m%s\033[0m (%s)…\n' "$label" "$mac"
    if _have wol; then
        wol "$mac"
    elif _have wakeonlan; then
        wakeonlan "$mac"
    elif _have etherwake; then
        sudo etherwake "$mac"
    else
        _die "no WoL tool found (install: wol, wakeonlan, or etherwake)"
    fi
}

# Normalise MAC to lowercase colon-separated.
_norm_mac() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/-/:/g'
}

# Return true if string looks like a MAC address.
_is_mac() {
    [[ "$1" =~ ^([0-9a-fA-F]{2}[:\-]){5}[0-9a-fA-F]{2}$ ]]
}

# ── Host discovery ────────────────────────────────────────────────────────────

# Builds an associative array: _hosts[hostname]="mac"
# Sources: ARP table, /etc/hosts cross-referenced with ARP, known-hosts list.
declare -A _hosts   # hostname → mac
declare -A _seen    # mac → 1  (dedup)

_discover_arp() {
    # arp -n: numeric, avoids reverse-DNS hangs
    # format: Address HWtype HWaddress Flags Iface
    while read -r ip _ mac _ _; do
        [[ "$mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] || continue
        mac=$(_norm_mac "$mac")
        [[ "${_seen[$mac]+x}" ]] && continue
        _seen["$mac"]=1

        # Try to resolve IP → hostname via /etc/hosts then reverse DNS (fast timeout)
        local name=""
        # /etc/hosts lookup
        name=$(awk -v ip="$ip" '$1==ip && NF>=2 {print $2; exit}' /etc/hosts 2>/dev/null || true)
        # avahi/mdns (.local) — only if getent is fast
        if [[ -z "$name" ]]; then
            name=$(getent hosts "$ip" 2>/dev/null | awk '{print $2; exit}' || true)
        fi
        [[ -z "$name" ]] && name="$ip"

        _hosts["$name"]="$mac"
    done < <(arp -n 2>/dev/null | tail -n +2)
}

_load_known() {
    for entry in "${KNOWN_HOSTS[@]}"; do
        local hname mac
        read -r hname mac <<< "$entry"
        mac=$(_norm_mac "$mac")
        # Only add if not already discovered via ARP (ARP entry takes precedence)
        local already=false
        for v in "${_hosts[@]}"; do
            [[ "$v" == "$mac" ]] && already=true && break
        done
        $already || _hosts["$hname"]="$mac"
    done
}

# ── Menu ──────────────────────────────────────────────────────────────────────

_menu() {
    local -a keys=()
    mapfile -t keys < <(printf '%s\n' "${!_hosts[@]}" | sort)

    if (( ${#keys[@]} == 0 )); then
        printf '\033[33mNo hosts discovered.\033[0m\n'
        printf 'Pass a hostname or MAC directly: %s <host|MAC>\n' "$(basename "$0")"
        exit 1
    fi

    printf '\n\033[1mWake which device?\033[0m\n\n'
    local i=1
    for k in "${keys[@]}"; do
        printf '  \033[36m%2d\033[0m  %-24s %s\n' "$i" "$k" "${_hosts[$k]}"
        (( i++ ))
    done
    printf '\n  \033[90m q\033[0m  quit\n\n'

    while true; do
        read -rp $'  > ' sel
        [[ "$sel" == "q" || "$sel" == "" ]] && exit 0

        # Numeric selection
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#keys[@]} )); then
            local chosen="${keys[$((sel-1))]}"
            _wol "${_hosts[$chosen]}" "$chosen"
            return
        fi

        # Hostname match
        if [[ "${_hosts[$sel]+x}" ]]; then
            _wol "${_hosts[$sel]}" "$sel"
            return
        fi

        # MAC match (direct)
        if _is_mac "$sel"; then
            _wol "$(_norm_mac "$sel")"
            return
        fi

        printf '  \033[31mUnknown selection:\033[0m %s\n' "$sel"
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────

_discover_arp
_load_known

if (( $# >= 1 )); then
    target="$1"
    if _is_mac "$target"; then
        _wol "$(_norm_mac "$target")"
    elif [[ "${_hosts[$target]+x}" ]]; then
        _wol "${_hosts[$target]}" "$target"
    else
        # Try resolving via getent then ARP
        ip=$(getent hosts "$target" 2>/dev/null | awk '{print $1; exit}' || true)
        if [[ -n "$ip" ]]; then
            mac=$(arp -n 2>/dev/null | awk -v ip="$ip" '$1==ip {print $3; exit}' || true)
            if [[ -n "$mac" && "$mac" != "<incomplete>" ]]; then
                _wol "$(_norm_mac "$mac")" "$target"
            else
                # Host resolves but not in ARP — fall back to known list
                for entry in "${KNOWN_HOSTS[@]}"; do
                    read -r kh km <<< "$entry"
                    if [[ "$kh" == "$target" ]]; then
                        _wol "$(_norm_mac "$km")" "$target"
                        exit 0
                    fi
                done
                _die "host '$target' resolves to $ip but has no ARP entry and is not in known-hosts"
            fi
        else
            _die "cannot resolve '$target' — not in ARP table, /etc/hosts, or known-hosts"
        fi
    fi
else
    _menu
fi
