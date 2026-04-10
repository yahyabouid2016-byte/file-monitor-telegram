# GPO Audit Policy Configuration

## Overview
This document describes how to configure the Group Policy audit settings
required for the real-time file monitoring system.

---

## Step 1: Open Group Policy Management Console (GPMC)
- Server Manager → Tools → Group Policy Management

## Step 2: Create a New GPO
- Right-click your domain → **Create a GPO in this domain**
- Name: `File-Audit-Policy`

## Step 3: Configure Advanced Audit Policy
Navigate to:
```
Computer Configuration → Policies → Windows Settings
→ Security Settings → Advanced Audit Policy Configuration
→ System Audit Policies → Object Access
```
Enable the following:
- **Audit File System** → Success + Failure
- **Audit Handle Manipulation** → Success + Failure

## Step 4: Configure SACL on the Monitored Folder
- Right-click `C:\TARGET → Properties → Security → Advanced → Auditing
- Add entry: **Everyone** → **Success + Failure**
- Audited permissions: Create files, Delete, Write Data

## Step 5: Link GPO to Domain
- Right-click domain → **Link an Existing GPO**
- Select `File-Audit-Policy`

## Step 6: Force Policy Update
```powershell
gpupdate /force
```

---

## Verified Event IDs Generated

| Event ID | Action |
|----------|--------|
| 4663 | File access attempt |
| 4660 | File deleted |
| 4656 | Handle to object requested |

---

## Notes
- SACL targets the specific folder; GPO enables auditing globally.
- Without both configured, Security events will not be generated.
