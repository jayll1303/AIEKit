---
name: disk-cleanup
description: "Diagnose and clean disk space on Linux servers, especially ML/LLM servers with Docker. Use when disk full, df shows high usage, du mismatch, Docker eating space, deleted files still consuming space, or need to free up disk on EC2/GPU server."
---

# Disk Cleanup for ML Servers

Systematic workflow to diagnose and reclaim disk space on Linux servers running Docker, LLM inference, and ML workloads.

## Scope

This skill handles:
- Diagnosing disk usage discrepancies (df vs du mismatch)
- Finding and cleaning Docker images, containers, volumes, and build cache
- Identifying deleted files still held open by processes
- Cleaning up /var/lib/docker overlay2 layers
- Periodic maintenance commands for ML servers

Does NOT handle:
- Docker container configuration or GPU passthrough (→ docker-gpu-setup)
- Model serving optimization or inference tuning (→ vllm-tgi-inference, sglang-serving)
- System administration beyond disk cleanup

## When to Use

- `df -h` shows disk nearly full (>80%)
- Discrepancy between `df` and `du` totals
- Docker consuming unexpected disk space
- Need to free space before pulling new model images
- Server running slow due to disk pressure
- Periodic maintenance on ML/LLM inference servers

## Quick Diagnosis Workflow

⚠️ **HARD GATE:** Before cleaning anything, ALWAYS run diagnosis first to understand what's consuming space.

### Step 1: Check overall disk usage

```bash
df -h                    # Overview of all mounted filesystems
df -hT                   # Include filesystem type
```

**Validate:** Identify which mount point is full (usually `/` or `/var`).

### Step 2: Find top space consumers from root

```bash
# Top 15 directories from root
sudo du -sh /* 2>/dev/null | sort -hr | head -15

# Drill into /var (common culprit)
sudo du -sh /var/* 2>/dev/null | sort -hr | head -10

# Check /home
sudo du -sh /home/* 2>/dev/null | sort -hr
```

### Step 3: Check for deleted files still open

This is the #1 cause of df/du mismatch — files deleted but processes still holding them open.

```bash
# Find deleted files still consuming space
sudo lsof | grep '(deleted)'

# Alternative
sudo lsof +L1 | grep deleted
```

**Fix:** Kill the process or restart the service holding the deleted file:
```bash
# Find PID from lsof output, then:
sudo kill <PID>
# Or restart the service:
sudo systemctl restart <service-name>
```

### Step 4: Check Docker specifically

```bash
# Docker's view of space usage
docker system df
docker system df -v      # Detailed breakdown

# Actual disk usage (often larger than Docker reports)
sudo du -sh /var/lib/docker 2>/dev/null

# Breakdown by Docker component
sudo du -sh /var/lib/docker/* 2>/dev/null | sort -hr

# overlay2 layers (usually the biggest)
sudo du -sh /var/lib/docker/overlay2 2>/dev/null
```

## Docker Cleanup Commands

### Safe cleanup (run regularly)

```bash
# Remove stopped containers, dangling images, unused networks, unused volumes
docker system prune -f --volumes
```

**What it removes:**
- Stopped containers
- Dangling images (untagged)
- Unused networks
- Unused volumes (with `--volumes` flag)

### Aggressive cleanup (use with caution)

```bash
# Also remove ALL unused images (not just dangling)
docker system prune -a -f --volumes
```

⚠️ **Warning:** This removes images not currently used by any container. You'll need to re-pull them.

### Manual image removal

```bash
# List all images with size
docker image ls --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.ID}}"

# Remove specific image
docker rmi <image_id_or_name>

# Remove multiple old images
docker rmi $(docker images --filter "dangling=true" -q)
```

### Clean container logs

Container logs can grow very large on long-running inference servers:

```bash
# Check log sizes
sudo du -sh /var/lib/docker/containers/*/*.log 2>/dev/null | sort -hr

# Truncate a specific log (keeps file, clears content)
sudo truncate -s 0 /var/lib/docker/containers/<container_id>/<container_id>-json.log

# Or set log rotation in daemon.json (permanent fix)
# /etc/docker/daemon.json:
# {
#   "log-driver": "json-file",
#   "log-opts": {
#     "max-size": "100m",
#     "max-file": "3"
#   }
# }
```

### Clean build cache

```bash
# Remove all build cache
docker builder prune -a -f

# Remove build cache older than 24h
docker builder prune --filter "until=24h" -f
```

## ML Server Specific Cleanup

### Safe to remove on LLM servers

- Old NGC images (check date in tag: `24.01` = Jan 2024)
- Dangling/untagged images
- Stopped containers from testing
- Build cache from image builds
- Unused volumes

### Keep these

- Images currently running (`docker ps` shows them)
- Images you plan to use soon
- Named volumes with model weights or data

### Check what's running before cleanup

```bash
# Running containers
docker ps

# All containers (including stopped)
docker ps -a

# Resource usage
docker stats --no-stream
```

## Interactive Tools

### ncdu (recommended)

```bash
# Install
sudo apt install ncdu    # Ubuntu/Debian
sudo yum install ncdu    # RHEL/CentOS

# Use interactively
sudo ncdu /              # Scan from root
sudo ncdu /var           # Scan /var only
```

Navigate with arrow keys, press `d` to delete.

## Periodic Maintenance Schedule

For ML/LLM servers, run these regularly:

| Frequency | Command | Purpose |
|-----------|---------|---------|
| Weekly | `docker system prune -f --volumes` | Remove stopped containers, dangling images, unused volumes |
| Monthly | `docker builder prune --filter "until=168h" -f` | Clean build cache older than 1 week |
| Before major pulls | `docker system df -v` | Check available space |
| When disk >80% | Full diagnosis workflow | Identify and clean largest consumers |

## Troubleshooting Decision Tree

```
Disk full?
├─ Run df -h → which mount is full?
│
├─ /var full?
│   ├─ Check /var/lib/docker → Docker cleanup
│   ├─ Check /var/log → Log rotation
│   └─ Check /var/cache → Package cache cleanup
│
├─ df and du don't match?
│   └─ Check lsof for deleted files → kill/restart process
│
├─ Docker shows less than du /var/lib/docker?
│   ├─ overlay2 layers from removed images → docker system prune -a
│   └─ Build cache → docker builder prune -a
│
└─ Still can't find space?
    └─ Use ncdu / for interactive exploration
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "I'll just run `docker system prune -a` immediately" | Always diagnose first. You might delete images you need, or the problem might not be Docker at all. |
| "df shows 400GB used, du shows 100GB, so du is wrong" | The difference is usually deleted files still held open by processes. Check `lsof \| grep deleted` first. |
| "I'll delete /var/lib/docker/overlay2 manually" | Never manually delete Docker's internal directories. Use `docker system prune` commands — manual deletion can corrupt Docker's state. |
| "Container logs don't take much space" | Long-running inference servers can have multi-GB logs. Always check `/var/lib/docker/containers/*/*.log`. |

## Quick Reference Commands

```bash
# === DIAGNOSIS ===
df -h                                                    # Disk overview
sudo du -sh /* 2>/dev/null | sort -hr | head -15        # Top directories
sudo lsof | grep '(deleted)'                            # Deleted files still open
docker system df -v                                      # Docker space breakdown
sudo du -sh /var/lib/docker 2>/dev/null                 # Actual Docker disk usage

# === CLEANUP ===
docker system prune -f --volumes                         # Safe cleanup
docker system prune -a -f --volumes                      # Aggressive cleanup
docker builder prune -a -f                               # Build cache
sudo truncate -s 0 /path/to/logfile                     # Clear log file

# === MONITORING ===
docker ps -a                                             # All containers
docker image ls                                          # All images
docker stats --no-stream                                 # Resource usage
```

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to configure Docker GPU passthrough | docker-gpu-setup | Handles Dockerfile, docker-compose GPU config, NVIDIA Container Toolkit |
| Optimizing vLLM/TGI inference server | vllm-tgi-inference | Covers KV cache tuning, tensor parallelism, memory optimization |
| SGLang server configuration | sglang-serving | Handles RadixAttention, structured generation, server tuning |
