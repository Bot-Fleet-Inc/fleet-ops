# Nvidia A10 GPU Passthrough Configuration

**Status**: Draft
**Version**: 2.0
**Last Updated**: 2026-02-27
**Site**: Vennelsborg (Site 1)

---

## Overview

The LLM inference VM (VMID 450, `prod-llm-inference-01`) receives a dedicated Nvidia A10 GPU via PCI passthrough. This GPU runs vLLM and Ollama to serve inference requests from bot fleet VMs on VLAN 1010.

### Nvidia A10 Specifications

| Property | Value |
|----------|-------|
| GPU | Nvidia A10 |
| Architecture | Ampere |
| VRAM | 24 GB GDDR6 |
| FP16 Performance | 31.2 TFLOPS |
| TDP | 150W |
| Form Factor | Single-slot, passive cooling |
| PCIe | Gen 4 x16 |

---

## Host Configuration (Proxmox Node)

These changes are applied to the Proxmox host that will run the LLM inference VM.

### Step 1: Enable IOMMU

Edit `/etc/default/grub`:

```bash
# For Intel CPU:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# For AMD CPU:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Update GRUB:

```bash
update-grub
```

### Step 2: Load VFIO Modules

Add to `/etc/modules`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

### Step 3: Blacklist Nvidia Drivers on Host

Create `/etc/modprobe.d/blacklist-nvidia.conf`:

```
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
```

### Step 4: Bind GPU to VFIO

Identify the GPU PCI ID:

```bash
lspci -nn | grep -i nvidia
# Example output: 41:00.0 3D controller [0302]: NVIDIA Corporation GA102GL [A10] [10de:2236] (rev a1)
```

Create `/etc/modprobe.d/vfio.conf`:

```
options vfio-pci ids=10de:2236
```

Note: Replace `10de:2236` with the actual PCI vendor:device ID from your system. If the GPU has an audio function, include that ID too (comma-separated).

### Step 5: Rebuild Initramfs and Reboot

```bash
update-initramfs -u -k all
reboot
```

### Step 6: Verify VFIO Binding

After reboot:

```bash
# Verify IOMMU is enabled
dmesg | grep -i iommu

# Verify GPU is bound to vfio-pci
lspci -nnk -s 41:00.0
# Should show: Kernel driver in use: vfio-pci
```

---

## VM Configuration (VMID 450)

### Proxmox VM Settings

```bash
# Machine type must be Q35 for PCIe passthrough
qm set 450 --machine q35
qm set 450 --bios ovmf

# PCI passthrough — replace PCI_ADDRESS with actual address (e.g., 0000:41:00.0)
qm set 450 --hostpci0 <PCI_ADDRESS>,pcie=1

# Resource allocation
qm set 450 --cores 8 --memory 32768
qm set 450 --scsi0 local-zfs:256
qm set 450 --net0 virtio,bridge=vnet-llm
qm set 450 --ipconfig0 ip=172.16.11.10/24,gw=172.16.11.1
```

### Guest OS (Ubuntu 24.04) — Nvidia Driver Installation

```bash
# Install Nvidia driver (inside the VM)
sudo apt update
sudo apt install -y nvidia-driver-550-server nvidia-utils-550-server

# Verify GPU is visible
nvidia-smi
```

Expected output:

```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 550.xx       Driver Version: 550.xx       CUDA Version: 12.x    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA A10          Off  | 00000000:00:10.0 Off |                    0 |
|  0%   30C    P8     15W / 150W|      0MiB / 23028MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

---

## LLM Service Configuration

### vLLM (Primary — OpenAI-compatible API)

```bash
# Install vLLM
pip install vllm

# Start vLLM server
python -m vllm.entrypoints.openai.api_server \
  --model <MODEL_PATH> \
  --host 0.0.0.0 \
  --port 8000 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 8192
```

**Systemd service** (`/etc/systemd/system/vllm.service`):

```ini
[Unit]
Description=vLLM OpenAI-compatible API Server
After=network.target

[Service]
Type=simple
User=llm
WorkingDirectory=/opt/llm
ExecStart=/opt/llm/venv/bin/python -m vllm.entrypoints.openai.api_server \
  --model /opt/llm/models/current \
  --host 0.0.0.0 \
  --port 8000 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 8192
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Ollama (Secondary — for smaller models)

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Configure to listen on all interfaces
# Edit /etc/systemd/system/ollama.service.d/override.conf:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Service Ports

| Service | Port | Protocol | API Compatibility |
|---------|------|----------|-------------------|
| vLLM | 8000 | HTTP | OpenAI Chat Completions API |
| Ollama | 11434 | HTTP | Ollama API (+ OpenAI compat endpoint) |

Both ports are reachable from VLAN 1010 (Bot Fleet) via UniFi firewall rule B1.

---

## Model Management

### Loading Models (Air-Gapped)

VLAN 1011 has zero internet access. Models must be loaded manually:

**Option A: SCP from admin workstation**

```bash
# From admin workstation (VLAN 1) to LLM VM
scp -r /path/to/model/ llm@172.16.11.10:/opt/llm/models/
```

**Option B: NFS mount from storage VLAN**

If a shared storage path is configured, mount it temporarily for model transfer.

### Model Selection Guidelines

The A10 has 24 GB VRAM. Model size constraints:

| Model Size | Parameters | Fits in 24GB VRAM | Notes |
|-----------|------------|---------------------|-------|
| 7B (Q4) | ~7B | Yes (~4 GB) | Fast, good for simple tasks |
| 13B (Q4) | ~13B | Yes (~8 GB) | Good balance of quality and speed |
| 34B (Q4) | ~34B | Yes (~20 GB) | High quality, slower |
| 70B (Q4) | ~70B | No (~40 GB) | Does not fit — needs multi-GPU |

Recommended starting configuration: **13B quantized model** via vLLM for general-purpose bot inference.

### Model Directory Structure

```
/opt/llm/
├── models/
│   ├── current -> codellama-13b-instruct/  # Symlink to active model
│   ├── codellama-13b-instruct/
│   ├── mistral-7b-instruct/
│   └── README.md                            # Model inventory
├── venv/                                     # Python virtual environment
└── logs/
```

---

## Monitoring

### GPU Health Check

```bash
# Quick status
nvidia-smi

# Continuous monitoring (refresh every 2s)
nvidia-smi -l 2

# GPU temperature
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader

# Memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
```

### Service Health

```bash
# Check vLLM is responding
curl -s http://172.16.11.10:8000/v1/models | jq .

# Check Ollama is responding
curl -s http://172.16.11.10:11434/api/tags | jq .
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `nvidia-smi` not found | Driver not installed in guest | Install `nvidia-driver-550-server` |
| No GPU visible in VM | VFIO not bound on host | Check `/etc/modprobe.d/vfio.conf` PCI ID |
| GPU visible but CUDA fails | Driver mismatch | Ensure guest driver matches CUDA version |
| vLLM OOM error | Model too large for 24GB | Use a smaller or more quantized model |
| Bots can't reach LLM | Firewall blocking | Verify rule B1 (VLAN 1010 -> VLAN 1011, TCP/8000,11434) |
| Model loading fails | No internet on VLAN 1011 | Models must be loaded via SCP/NFS, not downloaded |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-27 | Claude Code (Developer) | Initial A10 GPU passthrough and LLM service configuration |
| 2.0 | 2026-02-27 | Claude Code (Developer) | Revised: IPs to 172.16.11.x, VLAN 81 -> 1011, vmbr81 -> vnet-llm, Site 2 -> Site 1 |
