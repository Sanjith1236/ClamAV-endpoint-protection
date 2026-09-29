# Clamav-endpoint-protection

Real-time malware protection in Ubuntu, built on ClamAV. A small Bash script watches your directories, hands every new or changed file to the ClamAV daemon, quarantines anything infected and logs the event. systemd keeps it running from boot.

I wanted to see how far free, open-source tools could go as everyday endpoint protection, with no paid software and no heavy setup. This project is the answer: a lightweight setup that is easy to read, easy to test and good enough for personal machines, labs and small organizations.

## Contents
- [Features](#features)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Testing with EICAR](#testing-with-eicar)
- [Checking logs and quarantine](#checking-logs-and-quarantine)
- [Known limitations](#known-limitations)
- [Ideas for later](#ideas-for-later)
- [Author](#author)

## Features
- Automatic virus signature updates with **freshclam**
- Fast scanning through the **clamd** daemon, so the signature database is not reloaded for every file
- Real-time monitoring of new, modified and moved-in files using **inotify-tools**
- Infected files are moved to a **quarantine** folder automatically
- Detections go to a dedicated **log file** and to the **system journal**
- Desktop notification when malware is found
- Runs as a **systemd service** that starts at boot and restarts itself if it crashes

## How it works
  file created / modified / moved in
                 │
                 ▼
   inotifywait (watching /home)
                 │
                 ▼
   clamdscan  ──►  clamd daemon
                 │
      ┌──────────┴───────────┐
    clean                 infected
      │                      │
  nothing to do     move to /var/quarantine
                    + write to realtime.log
                    + notify-send + journal entry
freshclam runs in the background and keeps the signature database current, so detection stays up to date without manual work.

## Requirements
- Ubuntu Server 24.04 LTS (other Debian-based systems should work too)
- Root or sudo access
- Packages: `clamav`, `clamav-daemon`, `clamav-freshclam`, `clamtk`, `inotify-tools`, `libnotify-bin`
- systemd

## Installation

### 1. Update the system
sudo apt update
sudo apt upgrade -y

### 2. Install the packages
sudo apt install clamav clamav-daemon clamav-freshclam clamtk inotify-tools libnotify-bin -y

### 3. Update the virus database
The freshclam service locks the database while it runs, so stop it first, update manually, then start it again.

sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl enable clamav-freshclam
sudo systemctl start clamav-freshclam

### 4. Enable the ClamAV daemon
sudo systemctl enable clamav-daemon
sudo systemctl restart clamav-daemon
sudo systemctl status clamav-daemon

### 5. Create the quarantine folder
sudo mkdir -p /var/quarantine
sudo chmod 700 /var/quarantine

### 6. Create the log file
sudo touch /var/log/clamav/realtime.log
sudo chmod 664 /var/log/clamav/realtime.log
sudo chown root:clamav /var/log/clamav/realtime.log

### 7. Add the monitoring script
# Create and edit the script on your system
sudo nano /usr/local/bin/clamav-realtime.sh
Paste the script contents into the editor, save with `Ctrl+O`, and exit with `Ctrl+X`.

Make the script executable:
sudo chmod +x /usr/local/bin/clamav-realtime.sh

(Optional) To monitor folders other than `/home`, modify the `WATCH_DIR` variable inside the script.

### 8. Create the systemd service
# Create and edit the systemd service file
sudo nano /etc/systemd/system/clamav-realtime.service
Paste the service file contents into the editor, save, and exit.

### 9. Start it
sudo systemctl daemon-reload
sudo systemctl enable clamav-realtime.service
sudo systemctl start clamav-realtime.service
sudo systemctl status clamav-realtime.service

## Testing with EICAR

Never test with real malware. The EICAR file is a harmless test string that every antivirus is built to flag. Download it into a folder that is being watched (for example your home directory):

cd ~
wget https://secure.eicar.org/eicar.com

Expected result:

- The file is scanned and matches a signature
- It is moved to `/var/quarantine` automatically
- The event is written to `/var/log/clamav/realtime.log`

## Checking logs and quarantine
# detection log
cat /var/log/clamav/realtime.log

# quarantined files
ls -l /var/quarantine

# live service output
sudo journalctl -u clamav-realtime.service -f

## Known limitations
- **Signature-based only.** ClamAV can miss brand new (zero-day) threats and has no behavioral analysis, machine learning or ransomware protection.
- **Desktop notifications.** `notify-send` called from a root systemd service usually cannot reach a logged-in user's desktop session. The quarantine, log and journal entries still work; on a server this does not matter.
- **Filenames.** The script uses a plain `read`, so files with unusual names (backslashes, leading or trailing spaces, newlines) may not be handled correctly. Using `IFS= read -r FILE` is a safe improvement.
- **Large directories.** inotify has a watch limit. If you monitor a big tree, raise `fs.inotify.max_user_watches`.
- **Busy folders.** Scanning every modify event can be heavy on CPU and disk I/O in folders with constant writes.
- **Setup is manual.** Real-time monitoring, quarantine and notifications are not built into ClamAV, so they need this extra scripting.

## Ideas for later
- Email alerts and centralized log shipping (SIEM integration)
- Cloud-based threat intelligence lookups
- Scheduled full scans and a daily detection report
- Exclusion list for trusted paths
- A helper command to restore false positives from quarantine

## Author
Sanjith S, HackWise Academy

## License

MIT. See the `LICENSE` file for details.
