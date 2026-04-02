#!/bin/bash

echo "=== CPU Core Layout Analysis for Star Citizen Optimization ==="
echo ""

# Get CPU model
echo "CPU Model:"
grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2
echo ""

# Total core count
TOTAL_CORES=$(nproc)
echo "Total logical CPU cores: $TOTAL_CORES"
echo ""

# Check for Intel hybrid architecture
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1)
if echo "$CPU_MODEL" | grep -qi "intel.*1[2-9]th\|intel.*core.*1[3-9]"; then
    echo "⚠ Intel 12th gen or newer detected - likely has E-cores"
elif echo "$CPU_MODEL" | grep -qi "amd"; then
    echo "ℹ AMD CPU detected - no E-cores (uses same architecture for all cores)"
fi
echo ""

# Detailed core information
echo "=== Core Topology ==="
lscpu -e=CPU,CORE,SOCKET,MAXMHZ,MINMHZ 2>/dev/null || lscpu -e
echo ""

# Frequency-based detection
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    echo "=== Frequency Analysis (Key to identifying P-cores vs E-cores) ==="
    
    # Collect frequency data
    declare -A freq_to_cores
    declare -a all_freqs
    
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        if [ -d "$cpu/cpufreq" ]; then
            cpu_num=$(basename $cpu | sed 's/cpu//')
            max_freq=$(cat $cpu/cpufreq/cpuinfo_max_freq 2>/dev/null || echo "0")
            if [ "$max_freq" != "0" ]; then
                max_freq_mhz=$((max_freq / 1000))
                freq_to_cores[$max_freq_mhz]+="$cpu_num "
                if [[ ! " ${all_freqs[@]} " =~ " ${max_freq_mhz} " ]]; then
                    all_freqs+=($max_freq_mhz)
                fi
            fi
        fi
    done
    
    # Sort frequencies (highest first)
    IFS=$'\n' sorted_freqs=($(sort -rn <<<"${all_freqs[*]}"))
    unset IFS
    
    echo "Core groups by maximum frequency:"
    for freq in "${sorted_freqs[@]}"; do
        cores="${freq_to_cores[$freq]}"
        core_count=$(echo $cores | wc -w)
        # Format cores as comma-separated list
        core_list=$(echo $cores | tr ' ' ',' | sed 's/,$//')
        echo "  ${freq} MHz - Cores: $core_list (${core_count} cores)"
    done
    echo ""
    
    # Determine recommendation
    if [ ${#sorted_freqs[@]} -gt 1 ]; then
        echo "=== ✓ HYBRID ARCHITECTURE DETECTED ==="
        highest_freq="${sorted_freqs[0]}"
        p_cores="${freq_to_cores[$highest_freq]}"
        p_core_list=$(echo $p_cores | tr ' ' ',' | sed 's/,$//')
        p_core_count=$(echo $p_cores | wc -w)
        
        echo ""
        echo "P-CORES (Performance - Use these for gaming):"
        echo "  Frequency: ${highest_freq} MHz"
        echo "  Core IDs: $p_core_list"
        echo "  Count: ${p_core_count} cores"
        echo ""
        
        echo "E-CORES (Efficiency - Avoid for gaming):"
        for i in "${!sorted_freqs[@]}"; do
            if [ $i -gt 0 ]; then
                freq="${sorted_freqs[$i]}"
                cores="${freq_to_cores[$freq]}"
                core_list=$(echo $cores | tr ' ' ',' | sed 's/,$//')
                core_count=$(echo $cores | wc -w)
                echo "  Frequency: ${freq} MHz"
                echo "  Core IDs: $core_list"
                echo "  Count: ${core_count} cores"
            fi
        done
        echo ""
        
        echo "=== 📋 RECOMMENDED CONFIGURATION ==="
        echo ""
        echo "Add this to your Star Citizen launch script:"
        echo ""
        echo "  P_CORES=\"$p_core_list\""
        echo ""
        echo "Then wrap your gamemoderun command with taskset:"
        echo ""
        echo "  taskset -c \$P_CORES gamemoderun \"\$wine_path\"/wine ..."
        echo ""
        echo "This will restrict Star Citizen to use only P-cores (${p_core_count} cores),"
        echo "avoiding scheduling on slower E-cores which can cause stuttering."
        
    else
        echo "=== ✓ UNIFORM ARCHITECTURE DETECTED ==="
        echo ""
        echo "All cores operate at the same frequency (${sorted_freqs[0]} MHz)."
        echo "This CPU does not have E-cores."
        echo "CPU affinity optimization is not needed for core type."
        echo ""
        echo "However, you may still benefit from avoiding specific cores"
        echo "if you have background tasks. Use 'htop' to monitor core usage."
    fi
else
    echo "⚠ Cannot access CPU frequency information."
    echo "Possible reasons:"
    echo "  1. Running in a container/VM"
    echo "  2. Need to run with elevated privileges"
    echo "  3. CPU frequency driver not loaded"
    echo ""
    echo "Try running: sudo ./detect_cpu_cores.sh"
    echo ""
    echo "Alternative method - check /proc/cpuinfo manually:"
    echo ""
    
    # Fallback: group by CPU MHz from /proc/cpuinfo
    echo "Attempting fallback frequency detection from /proc/cpuinfo..."
    awk '/^processor|^cpu MHz/ {
        if ($1 == "processor") proc = $3;
        if ($1 == "cpu") freq[int($4)] = freq[int($4)] " " proc;
    }
    END {
        for (f in freq) print f " MHz: cores" freq[f];
    }' /proc/cpuinfo | sort -rn
fi

echo ""
echo "=== Additional Information ==="
lscpu | grep -E "^CPU\(s\)|Thread|Core|Socket|NUMA|Vendor ID|Model name"
echo ""
echo "To see real-time core usage: htop (press F5 for tree view, F2 to show CPUs)"
