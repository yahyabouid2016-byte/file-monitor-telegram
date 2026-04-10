$ Real-Time File Access Monitoring System

> Automated alert system for file server activity using Windows Server, PowerShell, n8n, and Telegram.


$$ Overview

This project implements a **proactive security monitoring system** that detects file operations (creation, deletion, renaming) on a shared Windows file server and instantly notifies the administrator via Telegram.

**Problem:** Standard Windows event logs are passive — they're usually checked *after* an incident occurs.  
**Solution:** An integrated ecosystem that continuously audits file access and sends real-time alerts.

---

$$ Infrastructure Architecture

The system is split across **3 machines**, each with a distinct role:

```
┌─────────────────┐        ┌──────────────────────────┐        ┌─────────────────┐
│   Server 1 (DC) │◄──────►│  Server 2 (NAT + Monitor)│◄──────►│  Client Machine │
│                 │  Auth  │                          │  SMB   │                 │
│  - AD DS        │        │  - File Server           │        │  - User worksta-│
│  - DNS          │        │  - NAT Gateway           │        │    tion         │
│  - GPO Policies │        │  - PowerShell Watcher    │        │  - Simulates    │
│                 │        │  - n8n Automation        │        │    end users    │
└─────────────────┘        └──────────┬───────────────┘        └─────────────────┘
                                      │ NAT (Outbound)
                                      ▼
                               Internet / n8n Cloud
                                      │
                                      ▼
                               Telegram Bot → Admin
```

---

$$ How It Works — Alert Flow

When a user performs a file operation on `\\SRV2\"TARGET-File"`, the following chain is triggered:

| Step | Component | Action |
|------|-----------|--------|
| 1 | **Client** | User creates/deletes/renames a file via SMB |
| 2 | **Server 1 (DC)** | GPO "Audit Object Access" is active → authorizes audit logging |
| 3 | **Server 2 (FS)** | SACL on `C:\TARGET-File` triggers a Security Event |
| 4 | **Server 2 (PowerShell)** | `FileSystemWatcher` intercepts the event in real-time |
| 5 | **Server 2 (NAT)** | Script sends JSON payload via NAT gateway to the internet |
| 6 | **n8n (Cloud)** | Webhook receives the JSON data |
| 7 | **Telegram** | n8n relays a formatted message to the Telegram bot |
| 8 | **Admin** | Instant push notification on mobile device |

---

$$ Implementation Phases

$$$ Phase 1 — Audit Policy on the Domain Controller (Server 1)

**Step 1: Active Directory Structure**
- Create dedicated Organizational Units (OUs) for granular management
- Add user accounts to monitor (e.g., regular domain users)

**Step 2: Deploy Audit GPO**
- Policy: `Audit Object Access` → Enable **Success** and **Failure**
- Scope: Applied domain-wide for full coverage
- Effect: Forces member servers to generate detailed Security events for configured file/folder access

---

$$$ Phase 2 — Configure the Monitored Share (Server 2)

**Step 1: Create SMB Shared Folder**
- Path: `C:\TARGET-File
- Accessible by domain users via `\\SRV2\TARGET-File

**Step 2: Configure SACL (System Access Control List)**
- Applied to `C:\TARGET-File
- Audited events: **File Creation** and **Deletion** for all users
- Result: GPO *enables* auditing globally; SACL *designates* the specific target

---

$$$ Phase 3 — NAT Gateway for External Communication (Server 2)

**Challenge:** The PowerShell script runs on an internal server and needs to reach n8n on the internet.

**Solution:** Install the `Routing and Remote Access` role to act as a NAT gateway.
- Internal machines (including Server 2 itself) route outbound traffic through the public interface
- Internal IPs are masked — only the public IP is exposed to the internet

> ⚠️ Without this, the monitoring script would be isolated and unable to send alerts.

---

### Phase 4 — PowerShell Monitoring Script (Server 2)

The script uses `.NET FileSystemWatcher` to **actively subscribe** to filesystem events (not passive log polling).

**Monitored Events:**
- `Created` — A new file was created
- `Deleted` — An existing file was deleted
- `Renamed` — A file was renamed

**Alert Process:**
1. `FileSystemWatcher` intercepts an event on the watched folder
2. Script collects event metadata (action type, filename, timestamp)
3. Data is formatted as a JSON object
4. JSON is sent via `Invoke-RestMethod` to the n8n Webhook URL

```powershell
# Core watcher setup
$watcher = New-Object IO.FileSystemWatcher
$watcher.Path = "C:\TARGET-File
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# On event — send alert
$body = @{
    action    = $event.SourceEventArgs.ChangeType
    fileName  = $event.SourceEventArgs.Name
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    server    = $env:COMPUTERNAME
} | ConvertTo-Json

Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $body -ContentType "application/json"
```

---

### Phase 5 — Persistence via Task Scheduler (Server 2)

To ensure the script runs continuously as a background service:

- **Trigger:** `At system startup`
- **Option 1:** `Run whether user is logged on or not`
- **Option 2:** `Run with highest privileges` 

This guarantees 24/7 monitoring that survives reboots and requires no user session.

---

### Phase 6 — n8n Automation & Telegram Notification (Cloud)

**n8n Workflow:**

```
[Webhook Node] ──► [Processing Node (optional)] ──► [Telegram Node]
  Receives JSON         Format message,                 Sends alert to
  from PowerShell       add context                     admin's Telegram
```

1. **Webhook Node** — Exposes a unique URL; listens for POST requests from PowerShell
2. **Processing Node** *(optional)* — Format the message, add server name, apply conditional logic
3. **Telegram Node** — Connects to Telegram Bot API; sends the formatted alert to admin or a dedicated channel

**Example notification received by admin:**
```
[ALERT] File deleted: Rapport_Confidentiel.docx on SRV2
Path: C:\TARGET-File\Rapport_Confidentiel.docx
Time: 2024-11-15 14:32:07
Server: SRV2
```

---

## Tech Stack

| Component | Technology |

| OS / Directory | Windows Server 2019 + Active Directory DS |
| Audit Policy | Group Policy (GPO) — Audit Object Access |
| File Permissions | SACL (System Access Control List) |
| Monitoring Script | PowerShell + `.NET FileSystemWatcher` |
| Network | NAT via Routing and Remote Access role |
| Automation | n8n (self-hosted or cloud) |
| Notification | Telegram Bot API |

---

## Key Benefits

- **Full Visibility** — Every action on sensitive files is traced
- **Immediate Response** — Near-zero delay between event and detection
- **Robust Automation** — 24/7 surveillance with no manual intervention required
- **Layered Security** — GPO + SACL + PowerShell + Cloud automation working in concert

---

## Repository Structure

```
.
├── scripts/
│   └── FileWatcher.ps1        # Main PowerShell monitoring script
├── gpo/
│   └── audit-policy.md        # GPO configuration guide
├── n8n/
│   └── workflow.json          # n8n workflow export
└── README.md
```

---

## Quick Start

1. **Server 1 (DC):** Apply the Audit Object Access GPO to the domain
2. **Server 2 (FS):** Create `C:\DATA_SECURE`, configure SACL for file creation/deletion auditing
3. **Server 2 (NAT):** Install and configure the Routing and Remote Access role
4. **n8n:** Import `workflow.json`, configure your Telegram bot token and chat ID, activate the workflow
5. **Server 2 (Script):** Edit `FileWatcher.ps1` with your n8n Webhook URL, schedule via Task Scheduler with the settings above

---

## License

MIT License — feel free to adapt this for your own infrastructure monitoring needs.
