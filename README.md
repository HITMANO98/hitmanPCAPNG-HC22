![Platform](https://img.shields.io/badge/platform-Linux-black?logo=linux)
![Shell](https://img.shields.io/badge/shell-Bash-green?logo=gnubash)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-active-success)
![Platform](https://img.shields.io/badge/platform-Linux-black?logo=linux)
![Shell](https://img.shields.io/badge/shell-Bash-green?logo=gnubash)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-active-success)

# ⚡ hitmanPCAPNG / HC22 Ultimate Suite

> **Advanced Wireless Capture Processing & Auditing Suite**

**hitmanPCAPNG-HC22** is an automated Linux CLI suite for processing, extracting, validating, auditing, and organizing wireless capture files.

Built around the **hcxtools** ecosystem, it turns a directory full of `.pcap`, `.cap`, and `.pcapng` files into a streamlined automated workflow — from capture extraction and recovery through local auditing, cloud submission, notifications, result tracking, and archival.

---

## 🖥️ Interface 
![HC22 Dashboard](assets/menu.png)

HC22 provides a terminal-based interactive dashboard for managing the complete capture-processing workflow.

```text
⚡ 1-Click Express Pipeline
👁 Directory Watchdog
🛠 Custom Workflow Builder
📂 Capture File Inspector
⚙ Settings / API Keys / Webhooks
```

Launch the interface with:

```bash
./hitman.sh
```

---

## 🚀 Features

### 🛡️ 3-Tier Aggressive Extraction Engine

Progressive capture processing with multiple recovery levels:

| Pass       | Mode              | Purpose                                               |
| ---------- | ----------------- | ----------------------------------------------------- |
| **PASS 1** | Standard          | Fast processing of clean captures                     |
| **PASS 2** | 8-bit Correction  | Recovery from noisy or weak captures                  |
| **PASS 3** | 16-bit + Recovery | Maximum recovery of corrupted or incomplete exchanges |

The engine automatically escalates through the recovery pipeline when necessary.

---

### 🔍 Quality Control & De-Duplication

Automatically clean and normalize extracted results.

* Invalid result filtering
* BSSID / ESSID de-duplication
* `hcxhashtool` integration
* Duplicate prevention
* Cleaner final datasets
* Automated processing validation

---

### ☁️ Multi-Cloud Connectors

Automated integration with supported external auditing and recovery platforms:

* [WPA-SEC](https://wpa-sec.stanev.org)
* [OnlineHashCrack](https://api.onlinehashcrack.com)
* [PwnCrack](https://pwncrack.org)
* [Hashmob](https://hashmob.net)
* [WiGLE](https://wigle.net)

Connectors can be configured through the built-in configuration manager.

---

### 👁️ Directory Watchdog

Automatically detect and process new capture files as they appear.

Powered by `inotifywait` when available, with an automatic polling fallback.

Designed for automated capture pipelines and workflows involving:

* Pwnagotchi
* WiFi Pineapple
* Custom capture collectors
* Wireless auditing stations

```bash
./hitman.sh --watch /root/captures/
```

---

### ⚡ Local Quick-Audit Pre-Check

Perform a local `hashcat` dictionary pre-check before external submission.

Configurable wordlists allow you to prioritize frequently used dictionaries such as:

```text
rockyou.txt
```

This allows locally recoverable results to be identified before proceeding with additional processing.

---

### 🔔 Real-Time Notifications

Keep track of long-running jobs with automated notifications.

Supported integrations include:

* Discord Webhooks
* Telegram Bots
* Successful result notifications
* Batch completion notifications
* Processing status alerts

---

### 📊 Master Results Database

Automatically consolidate processed results into:

```text
hitman_master.csv
```

Processed captures are automatically organized into:

```text
./archived_pcaps/
```

Your workspace stays clean while maintaining a centralized record of processed results.

---

# 📋 Requirements

### Required

* Linux (Duh lol)
* Bash
* `hcxtools`
* `curl`
* `jq`

### Recommended

* `hcxhashtool`
* `hashcat`
* `inotify-tools`

---

# 📦 Installation

## Debian / Ubuntu / Kali / Parrot

```bash
sudo apt update
sudo apt install -y hcxtools curl jq hashcat inotify-tools
```

## Arch Linux / Manjaro

```bash
sudo pacman -S hcxtools curl jq hashcat inotify-tools
```

---

# ⚙️ Setup

Clone the repository:

```bash
git clone https://github.com/HITMANO98/hitmanPCAPNG-HC22.git
cd hitmanPCAPNG-HC22
```

Make the script executable:

```bash
chmod +x hitman.sh
```

Launch the configuration manager:

```bash
./hitman.sh --config
```

Configuration is stored at:

```text
~/.config/hitman_pcap/config.conf
```

---

# 🕹️ Usage

## Interactive Mode

Launch the main HC22 dashboard:

```bash
./hitman.sh
```

The interactive interface provides access to the complete suite:

| Mode                    | Description                                    |
| ----------------------- | ---------------------------------------------- |
| ⚡ **Express Pipeline**  | Automated capture processing workflow          |
| 👁 **Watchdog**         | Automatically process newly detected captures  |
| 🛠 **Workflow Builder** | Select files and control individual services   |
| 📂 **File Inspector**   | Inspect capture and HC22000 files              |
| ⚙ **Configuration**     | Manage APIs, webhooks, and automation settings |

---

## ⚡ Automated Mode

Run the automated processing pipeline in the current directory:

```bash
./hitman.sh --auto
```

---

## 👁️ Watch Mode

Monitor a directory for incoming capture files:

```bash
./hitman.sh --watch /root/captures/
```

New captures are automatically detected and passed through the processing pipeline.

---

## ⚙️ Configuration

Open the configuration manager:

```bash
./hitman.sh --config
```

---

## ❓ Help

Display the command-line reference:

```bash
./hitman.sh --help
```

---

# 🖥️ Command-Line Reference

| Option                | Description                                         | Example                               |
| --------------------- | --------------------------------------------------- | ------------------------------------- |
| `-a`, `--auto`        | Run the automated pipeline in the current directory | `./hitman.sh --auto`                  |
| `-w`, `--watch [dir]` | Monitor a directory for new captures                | `./hitman.sh --watch /root/captures/` |
| `-c`, `--config`      | Open the configuration manager                      | `./hitman.sh --config`                |
| `-h`, `--help`        | Display the help menu                               | `./hitman.sh --help`                  |

---

# 🔄 Processing Pipeline

```text
 ┌──────────────────────────────┐
 │        Capture Files         │
 │    .pcap / .cap / .pcapng    │
 └──────────────┬───────────────┘
                │
                ▼
 ┌──────────────────────────────┐
 │      Extraction Engine       │
 │        hcxpcapngtool         │
 └──────────────┬───────────────┘
                │
                ▼
 ┌──────────────────────────────┐
 │       Recovery Pipeline      │
 │   PASS 1 → PASS 2 → PASS 3  │
 └──────────────┬───────────────┘
                │
                ▼
 ┌──────────────────────────────┐
 │   Quality / De-Duplication   │
 └──────────────┬───────────────┘
                │
                ▼
 ┌──────────────────────────────┐
 │     Local Quick-Audit        │
 │          Optional            │
 └──────────────┬───────────────┘
                │
       ┌────────┼────────┐
       ▼        ▼        ▼
    Local    Cloud     Master
    Audit    APIs       CSV
       │        │        │
       └────────┼────────┘
                │
                ▼
 ┌──────────────────────────────┐
 │          Archiving            │
 │       ./archived_pcaps/      │
 └──────────────────────────────┘
```

---

# 📂 Output

| Path                                | Description               |
| ----------------------------------- | ------------------------- |
| `hitman_master.csv`                 | Master results database   |
| `./archived_pcaps/`                 | Processed capture archive |
| `~/.config/hitman_pcap/config.conf` | Application configuration |

---

# 🧰 Dependencies

| Tool            | Function                          |
| --------------- | --------------------------------- |
| `hcxtools`      | Capture extraction and processing |
| `hcxpcapngtool` | Capture-to-hash conversion        |
| `hcxhashtool`   | Filtering and de-duplication      |
| `hashcat`       | Local password auditing           |
| `curl`          | API communication                 |
| `jq`            | JSON processing                   |
| `inotifywait`   | Real-time filesystem monitoring   |

---

# 🧠 Architecture

HC22 is built around a progressive processing pipeline:

```text
Capture
   │
   ▼
Extraction
   │
   ├── PASS 1 — Standard
   │
   ├── PASS 2 — 8-bit Correction
   │
   └── PASS 3 — 16-bit + Recovery
   │
   ▼
Quality Control
   │
   ▼
De-Duplication
   │
   ├──────────────┬──────────────┐
   ▼              ▼              ▼
Local Audit   Cloud APIs    Master CSV
   │              │              │
   └──────────────┴──────────────┘
                  │
                  ▼
               Archive
```

---

# 🛣️ Roadmap

* [x] Enhanced terminal UI
* [ ] Parallel capture processing
* [ ] Advanced capture quality scoring
* [ ] Expanded cloud connector support
* [ ] Improved API retry handling
* [ ] SQLite backend
* [ ] Advanced result analytics
* [ ] Additional export formats
* [ ] Plugin-based connector system
* [ ] Configuration import/export
* [ ] Expanded logging and diagnostics
* [ ] Automatic dependency detection

---

# 🙏 Credits

Special thanks to **[@ZerBea](https://github.com/ZerBea)** and the contributors behind **hcxtools** and **hcxdumptool**.

---

# 📄 License

**MIT License**

---

<div align="center">

### ⚡ hitmanPCAPNG

**Capture → Extract → Recover → Audit → Analyze → Archive**

*Built for serious wireless security workflows.*

</div>
