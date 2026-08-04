#  Smart PCAPNG to HC22000 Converter (`pcapng2hc22000`)

An interactive Bash wrapper for `hcxpcapngtool` designed to rapidly convert `.pcapng`, `.pcap`, and `.cap` Wi-Fi captures into Hashcat `-m 22000` format. 

Built for penetration testers and security researchers who need fast, batch-processing workflows tailored for online cracking services and manual hash extraction.

---

##  Features

-  **Interactive Multi-Selection**: Uses `fzf` for fuzzy multi-select menus. Automatically falls back to a numbered Bash menu if `fzf` isn't installed.
-  **Batch or Single Aggregation**: Convert files individually or merge extracted hashes into a single `.hc22000` file.
-  **Automated Recovery Pass**: Automatically detects files that yield `0` valid standard hashes and offers an aggressive retry pass using `--all --ignore-ie --nonce-error-corrections=8`.
-  **Metadata Extraction**: Optional extraction of ESSID lists (`-E`), Probe Requests (`-R`), Identities/Usernames (`-I`, `-U`), and Access Point CSV info (`--csv`).
-  **Gzip Compression Compatible**: Natively handles compressed `.gz` capture files without needing manual decompression.

---

##  Prerequisites & Installation

The script requires `hcxtools` (specifically `hcxpcapngtool`). `fzf` is optional but recommended for an interactive UI experience.

### Installing Dependencies by OS / Package Manager

#### **Debian / Ubuntu / Kali Linux**
```bash
sudo apt update
sudo apt install hcxtools fzf -y
```
#### **Arch Linux / Manjaro**
```bash
sudo pacman -S hcxtools fzf
```
#### **Fedora / RHEL**
```bash
sudo dnf install hcxtools fzf
````
**Building hcxtools from Source (Latest Version)**

If your distribution's repository has an outdated package, you can build directly from upstream:
```bash
git clone [https://github.com/ZerBea/hcxtools.git](https://github.com/ZerBea/hcxtools.git)
cd hcxtools
make
sudo make install
```
###**Quick Start**
Clone the repository:
```bash
git clone [https://github.com/HITMAN098/pcapng2hc22000.git](https://github.com/HITMAN098/pcapng2hc22000.git)
cd pcapng2hc22000
```
Make the script executable:
```bash
chmod +x pcapng2hc22000.sh
```
Run the script:

  Inside the directory containing your .pcapng files:
  ```bash
./pcapng2hc22000.sh
```
  Or pass a target path as an argument:
  ```bash
./pcapng2hc22000.sh /path/to/captures/
```

