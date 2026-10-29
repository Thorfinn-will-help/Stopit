# Compute Mode ⚡

A lightweight PowerShell process manager for Windows that helps manage background processes and free up system resources.

### 🚀 How It Helps
- 🎮 **Gamers:** Reduce unnecessary background activity.
- 💻 **Developers:** Manage processes while coding.
- 🧮 **Engineering Students:** Run Python scripts and XFOIL simulations with fewer competing processes.
- 🖥️ **Low-End PC Users:** Manage limited RAM and system resources.

### ⚙️ Commands

| Command | Meaning |
|---|---|
| `D(1,3)` | Deny selected process names and stop matching instances |
| `A(1,3)` | Allow selected process names |
| `F(2)` | Force-stop a selected process |
| `F(2-5)` | Force-stop multiple processes |
| `L` | Refresh process list |
| `P` | Show/hide protected processes |
| `?` | Display help |
| `Q` | Exit program |

*Numbers refer to process rows displayed in the dashboard.*

### 📥 Requirements
- Windows 10/11
- PowerShell 5.1+

### ▶️ Run
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\ComputeMode.ps1
```

### ⚠️ Warning
Stopping essential processes can cause instability or data loss. The protection list is limited, and performance improvements are not guaranteed.

### 📄 License
MIT, if included in the repository.
