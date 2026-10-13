import os
import csv
import json
from datetime import datetime

CONFIG_PATH = "Helpers/config.json"
ASSETS_PATH = "Helpers/assets.csv"
REPORTS_DIR = "reports"
ATTENDANCE_LOG_PATH = os.path.join(REPORTS_DIR, "attendance.log")
ABSENT_LOG_PATH = os.path.join(REPORTS_DIR, "absent.log")

NAME_COL = "Names"
EMAIL_COL = "Email"
ATTEND_COL = "Attendance Count"
ABSENT_COL = "Absence Count"

def load_config(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Config file not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Config file is not valid JSON: {exc}")
    
    required_top = ["thresholds", "run_mode", "total_sessions"]
    for key in required_top:
        if key not in config:
            raise ValueError(f"Config is missing required key: '{key}'")
    for key in ["warning", "failure"]:
        if key not in config["thresholds"]:
            raise ValueError(f"Config['thresholds'] is missing key: '{key}'")
    
    if config["total_sessions"] <= 0:
        raise ValueError("Config 'total_sessions' must be greater than 0")
    
    return config

def load_roster(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Roster file not found: {path}")
    with open(path, mode="r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)
    if not fieldnames or not rows:
        raise ValueError(f"Roster file is empty: {path}")
    return fieldnames, rows

def main():
    os.makedirs(REPORTS_DIR, exist_ok=True)
    config_file = CONFIG_PATH if os.path.exists(CONFIG_PATH) else "config.json"
    assets_file = ASSETS_PATH if os.path.exists(ASSETS_PATH) else "assets.csv"

    config = load_config(config_file)
    fieldnames, rows = load_roster(assets_file)

    print("=== Student Attendance Tracker ===")
    print(f"Thresholds -> Warning: {config['thresholds']['warning']}%, Failure: {config['thresholds']['failure']}%")

    att_logs = []
    abs_logs = []

    for row in rows:
        name = row[NAME_COL]
        email = row[EMAIL_COL]
        att_cnt = int(row[ATTEND_COL])
        abs_cnt = int(row[ABSENT_COL])

        while True:
            choice = input(f"Is {name} ({email}) present? [y/n]: ").strip().lower()
            if choice in ['y', 'yes']:
                att_cnt += 1
                att_logs.append(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - PRESENT: {name} ({email})")
                break
            elif choice in ['n', 'no']:
                abs_cnt += 1
                abs_logs.append(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - ABSENT: {name} ({email})")
                break
            else:
                print("Please enter 'y' or 'n'.")
        row[ATTEND_COL] = str(att_cnt)
        row[ABSENT_COL] = str(abs_cnt)

    with open(assets_file, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    if att_logs:
        with open(ATTENDANCE_LOG_PATH, "a", encoding="utf-8") as f:
            for log in att_logs:
                f.write(log + "\n")
    if abs_logs:
        with open(ABSENT_LOG_PATH, "a", encoding="utf-8") as f:
            for log in abs_logs:
                f.write(log + "\n")

    print("\nAttendance session completed successfully. Logs written to reports/")

if __name__ == "__main__":
    main()
