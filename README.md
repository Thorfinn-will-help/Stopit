# StopIt ⚡

A lightweight PowerShell process manager for Windows that helps manage background processes and free up system resources.

### 🚀 How It Helps
- 🎮 **Gamers:** Reduce unnecessary background activity.
- 💻 **Developers:** Manage processes while coding.
- 🧮 **Engineering Students:** Run Python scripts and XFOIL simulations.
- 🖥️ **Low-End PC Users:** Manage limited RAM and system resources.

### ⚙️ Commands

| Command | Meaning |
|---|---|
| `D(1,3)` | Deny process names and stop matching instances |
| `A(1,3)` | Allow selected process names |
| `F(2)` | Force-stop one process instance |
| `F(2-5)` | Force-stop multiple instances |
| `L` | Refresh process list |
| `P` | Show/hide protected processes |
| `?` | Display help |
| `Q` | Exit StopIt |

*Numbers refer to process rows displayed in the dashboard.*

### 📥 Requirements
- Windows 10/11
- PowerShell 5.1+

### ▶️ Run
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\StopIt.ps1
```

### ⚠️ Warning
Stopping essential processes can cause system instability or data loss. The protection list is limited, and performance improvements are not guaranteed.

### 📄 License
MIT License, if included in the repository.
