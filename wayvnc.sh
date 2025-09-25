#!/usr/bin/env bash
# Adapted from: https://github.com/Zellington3/Ghost-Monitor-Wayvnc-Hyprland/blob/main/wayvnc-ghost-monitor.zsh

# === CONFIG ===
VIRTUAL_MONITOR="HEADLESS-2"
VIRTUAL_WORKSPACE=9
REAL_MONITOR="DP-1"

# === CLEANUP FUNCTION ===
cleanup() {
  printf "\n[wayvnc] Cleaning up...\n"
  hyprctl dispatch moveworkspacetomonitor "$VIRTUAL_WORKSPACE" "$REAL_MONITOR"
  hyprctl dispatch focusmonitor "$REAL_MONITOR"
  pkill wayvnc
  printf "[wayvnc] Cleanup done.\n"
  exit 0
}

# === Trap Exit for Cleanup ===
trap cleanup INT TERM EXIT

# === Check if HEADLESS-2 is already active, create it if not ===
if ! hyprctl monitors | grep -q "$VIRTUAL_MONITOR"; then
  printf "[wayvnc] Creating %s dynamically...\n" "$VIRTUAL_MONITOR"
  hyprctl output create headless "$VIRTUAL_MONITOR"
  sleep 0.5
fi

# === Assign workspace and activate it ===
printf "[wayvnc] Moving workspace %s to %s...\n" "$VIRTUAL_WORKSPACE" "$VIRTUAL_MONITOR"
hyprctl dispatch moveworkspacetomonitor "$VIRTUAL_WORKSPACE" "$VIRTUAL_MONITOR"
sleep 0.2
hyprctl dispatch workspace "$VIRTUAL_WORKSPACE"
sleep 0.2

# === Return focus to your real monitor so you don't get stuck on the headless one ===
hyprctl dispatch focusmonitor "$REAL_MONITOR"

# === Start WayVNC ===
printf "[wayvnc] Starting WayVNC on %s...\n" "$VIRTUAL_MONITOR"
wayvnc $([[ $DEBUG ]] && echo -Ldebug) -g -f 60 -r -o "$VIRTUAL_MONITOR"
