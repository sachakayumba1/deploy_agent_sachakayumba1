#!/usr/bin/env bash
# ==============================================================================
# Master Script: deploy_agent.sh
# Author: sachakayumba1
# ==============================================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$ROOT/templates"
PROJECT=""
DEPLOYING=0

interrupt_deployment() {
    [ "$DEPLOYING" -eq 1 ] || return
    trap '' INT TSTP
    echo ""
    echo "[!] Deployment interrupted by signal (Ctrl+C or Ctrl+Z)."
    if [ -n "$PROJECT" ] && [ -d "$PROJECT" ]; then
        ZIP_NAME="${PROJECT}_archive.zip"
        echo "[*] Packaging incomplete deployment into $ZIP_NAME..."
        zip -rq "$ZIP_NAME" "$PROJECT"
        echo "[+] Archive created: $ZIP_NAME"
        rm -rf "$PROJECT"
    fi
    echo "[+] Clean exit completed."
    exit 1
}

preflight_checks() {
    echo "[*] Running pre-flight checks..."
    for cmd in python3 zip; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "[ERROR] Required tool '$cmd' is not installed. Aborting."
            exit 1
        fi
    done
    for f in attendance_checker.py assets.csv config.json; do
        if [ ! -f "$TEMPLATES/$f" ]; then
            echo "[ERROR] Missing template file: templates/$f"
            exit 1
        fi
    done
    echo "[+] Pre-flight checks passed."
}

feature_deploy() {
    preflight_checks
    
    read -p "Enter project suffix name (e.g., demo): " suffix
    [ -z "$suffix" ] && suffix="default"
    PROJECT="attendance_tracker_${suffix}"
    
    if [ -e "$PROJECT" ]; then
        read -p "Directory '$PROJECT' already exists. Overwrite? [y/N]: " ovr
        if [[ ! "$ovr" =~ ^[Yy]$ ]]; then
            echo "[*] Deployment aborted."
            return
        fi
        rm -rf "$PROJECT"
    fi

    DEPLOYING=1
    trap 'interrupt_deployment' INT TSTP

    echo "[*] Creating project directory structure..."
    mkdir -p "$PROJECT/Helpers" "$PROJECT/reports" "$PROJECT/archives/attendance" "$PROJECT/archives/absent"

    echo "[*] Deploying application and configuration files..."
    cp "$TEMPLATES/attendance_checker.py" "$PROJECT/"
    cp "$TEMPLATES/config.json" "$PROJECT/Helpers/config.json"

    echo "--------------------------------------------------"
    echo "Roster Build Options:"
    echo "  [A] Copy from template roster"
    echo "  [B] Generate fresh roster"
    read -p "Select option [A/B]: " roption

    if [[ "$roption" =~ ^[Bb]$ ]]; then
        read -p "Enter number of students for fresh roster: " count
        [[ "$count" =~ ^[0-9]+$ ]] || count=3
        
        cat << 'CSVHEAD' > "$PROJECT/Helpers/assets.csv"
Email,Names,Attendance Count,Absence Count
CSVHEAD
        
        names=("Alice" "Bob" "Charlie" "Diana" "Ethan" "Fatima" "George" "Hannah" "Ibrahim" "Jasmine")
        for ((i=0; i<count; i++)); do
            idx=$((i % ${#names[@]}))
            n="${names[$idx]}"
            email="${n,,}@example.com"
            echo "${email},${n},0,0" >> "$PROJECT/Helpers/assets.csv"
        done
        
        sed -i 's/"total_sessions": *[0-9]*/"total_sessions": 1/' "$PROJECT/Helpers/config.json"
        echo "[+] Generated fresh roster with $count students (total_sessions set to 1)."
    else
        read -p "How many students to copy from template (max 10)? " scount
        [[ "$scount" =~ ^[0-9]+$ ]] || scount=10
        head -n $((scount + 1)) "$TEMPLATES/assets.csv" > "$PROJECT/Helpers/assets.csv"
        echo "[+] Copied $scount student rows from template roster (total_sessions default: 5)."
    fi

    echo "[*] Setting strict permissions..."
    chmod +x "$PROJECT/attendance_checker.py"
    chmod 600 "$PROJECT/Helpers/config.json"
    echo "[+] Permissions set: attendance_checker.py is executable (+x), config.json is owner read/write only (600)."

    read -p "Do you want to update attendance alert thresholds in config.json? [y/N]: " upd_th
    if [[ "$upd_th" =~ ^[Yy]$ ]]; then
        read -p "Enter new Warning threshold percentage (default 75): " w_val
        read -p "Enter new Failure threshold percentage (default 50): " f_val
        [[ "$w_val" =~ ^[0-9]+$ ]] || w_val=75
        [[ "$f_val" =~ ^[0-9]+$ ]] || f_val=50
        
        sed -i "s/\"warning\": *[0-9]*/\"warning\": $w_val/" "$PROJECT/Helpers/config.json"
        sed -i "s/\"failure\": *[0-9]*/\"failure\": $f_val/" "$PROJECT/Helpers/config.json"
        echo "[+] Thresholds updated successfully in config.json."
    fi

    DEPLOYING=0
    trap - INT TSTP

    echo "[+] Deployment complete! Verifying by running the application now..."
    cd "$PROJECT" || exit
    python3 attendance_checker.py
    cd "$ROOT" || exit
}

feature_run() {
    read -p "Enter project directory name to run (e.g., attendance_tracker_demo): " target_proj
    if [ ! -d "$target_proj" ]; then
        echo "[ERROR] Directory '$target_proj' does not exist."
        return
    fi
    if [ ! -f "$target_proj/attendance_checker.py" ]; then
        echo "[ERROR] attendance_checker.py not found in $target_proj."
        return
    }
    echo "[*] Running application in $target_proj..."
    cd "$target_proj" || exit
    python3 attendance_checker.py
    cd "$ROOT" || exit
}

feature_archive() {
    read -p "Enter project directory name to archive logs for: " target_proj
    if [ ! -d "$target_proj" ]; then
        echo "[ERROR] Directory '$target_proj' does not exist."
        return
    }
    
    reports_dir="$target_proj/reports"
    archives_dir="$target_proj/archives"
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    mkdir -p "$archives_dir/attendance" "$archives_dir/absent"
    
    archived_any=0
    
    att_log="$reports_dir/attendance.log"
    if [ -f "$att_log" ]; then
        dest="$archives_dir/attendance/attendance_${timestamp}.log"
        mv "$att_log" "$dest"
        echo "[+] Archived attendance log -> $dest"
        archived_any=1
    else
        echo "[-] No attendance.log found in $reports_dir."
    fi
    
    abs_log="$reports_dir/absent.log"
    if [ -f "$abs_log" ]; then
        dest="$archives_dir/absent/absent_${timestamp}.log"
        mv "$abs_log" "$dest"
        echo "[+] Archived absent log -> $dest"
        archived_any=1
    else
        echo "[-] No absent.log found in $reports_dir (no absences recorded)."
    fi
    
    if [ "$archived_any" -eq 1 ]; then
        echo "[+] Log archival completed successfully."
    else
        echo "[*] No logs available to archive."
    fi
}

main_menu() {
    while true; do
        echo ""
        echo "============================================="
        echo "   AUTOMATED DEPLOYMENT & AGENT MANAGER"
        echo "============================================="
        echo "1. Deploy Application (Feature 1)"
        echo "2. Run Application (Feature 2)"
        echo "3. Archive Logs (Feature 3)"
        echo "4. Exit"
        read -p "Select an option [1-4]: " choice
        case $choice in
            1) feature_deploy ;;
            2) feature_run ;;
            3) feature_archive ;;
            4) echo "Exiting. Goodbye!"; exit 0 ;;
            *) echo "[ERROR] Invalid selection. Choose 1-4." ;;
        esac
    done
}

main_menu
