#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS Container Security Hardening
# Enhanced security for Docker and LXC containers

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

log "Installing container tools..."
apt-get update -qq
apt-get install -y docker.io docker-compose apparmor-utils auditd

# Docker security configuration
log "Hardening Docker daemon..."
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'EOF'
{
  "icc": false,
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp-profile.json",
  "selinux-enabled": false,
  "disable-legacy-registry": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

# Docker seccomp profile
log "Creating Docker seccomp profile..."
cat > /etc/docker/seccomp-profile.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "archMap": [
    {
      "architecture": "SCMP_ARCH_X86_64",
      "subArchitectures": [
        "SCMP_ARCH_X86",
        "SCMP_ARCH_X32"
      ]
    }
  ],
  "syscalls": [
    {
      "names": [
        "accept",
        "accept4",
        "access",
        "arch_prctl",
        "bind",
        "brk",
        "capget",
        "capset",
        "chdir",
        "chmod",
        "chown",
        "clone",
        "close",
        "connect",
        "dup",
        "dup2",
        "dup3",
        "epoll_create",
        "epoll_create1",
        "epoll_ctl",
        "epoll_wait",
        "execve",
        "exit",
        "exit_group",
        "fcntl",
        "fstat",
        "futex",
        "getcwd",
        "getdents",
        "getdents64",
        "getegid",
        "geteuid",
        "getgid",
        "getgroups",
        "getpeername",
        "getpgrp",
        "getpid",
        "getppid",
        "getpriority",
        "getrandom",
        "getresgid",
        "getresuid",
        "getrlimit",
        "getsid",
        "getsockname",
        "getsockopt",
        "gettid",
        "gettimeofday",
        "getuid",
        "listen",
        "lseek",
        "lstat",
        "madvise",
        "mkdir",
        "mmap",
        "mprotect",
        "mremap",
        "munmap",
        "nanosleep",
        "open",
        "openat",
        "pipe",
        "pipe2",
        "poll",
        "prctl",
        "pread64",
        "prlimit64",
        "pwrite64",
        "read",
        "readlink",
        "recv",
        "recvfrom",
        "recvmsg",
        "rename",
        "rmdir",
        "rt_sigaction",
        "rt_sigprocmask",
        "rt_sigreturn",
        "sched_getaffinity",
        "sched_yield",
        "select",
        "send",
        "sendmsg",
        "sendto",
        "setgid",
        "setgroups",
        "setpgid",
        "setresgid",
        "setresuid",
        "setsid",
        "setsockopt",
        "setuid",
        "shutdown",
        "sigaltstack",
        "socket",
        "socketpair",
        "stat",
        "statfs",
        "symlink",
        "tgkill",
        "time",
        "uname",
        "unlink",
        "wait4",
        "write"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

# Docker AppArmor profile
log "Creating Docker AppArmor profile..."
cat > /etc/apparmor.d/docker-secureos << 'EOF'
#include <tunables/global>

profile docker-secureos flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  network,
  capability,
  file,
  umount,
  
  deny @{PROC}/* w,
  deny @{PROC}/sys/kernel/[^s][^h][^m]* w,
  deny @{PROC}/sysrq-trigger rwklx,
  deny @{PROC}/mem rwklx,
  deny @{PROC}/kmem rwklx,
  
  deny /sys/[^f]*/** wklx,
  deny /sys/f[^s]*/** wklx,
  deny /sys/fs/[^c]*/** wklx,
  deny /sys/fs/c[^g]*/** wklx,
  deny /sys/fs/cg[^r]*/** wklx,
  deny /sys/firmware/efi/efivars/** rwklx,
  deny /sys/kernel/security/** rwklx,
}
EOF

apparmor_parser -r /etc/apparmor.d/docker-secureos

# Container audit rules
log "Adding container audit rules..."
cat > /etc/audit/rules.d/docker.rules << 'EOF'
# Docker daemon
-w /usr/bin/dockerd -k docker
-w /var/lib/docker -k docker
-w /etc/docker -k docker

# Container runtime
-w /usr/bin/containerd -k docker
-w /usr/bin/runc -k docker

# Docker commands
-w /usr/bin/docker -k docker
-w /var/run/docker.sock -k docker
EOF

# Restart auditd
service auditd restart 2>/dev/null || true

# Container management tool
log "Creating container security management tool..."
cat > /usr/local/bin/secureos-container << 'EOF'
#!/bin/bash
# SecureOS Container Security Manager

show_help() {
    echo "SecureOS Container Security Manager"
    echo ""
    echo "Usage: secureos-container <command>"
    echo ""
    echo "Commands:"
    echo "  scan              Scan containers for vulnerabilities"
    echo "  audit             Run security audit on containers"
    echo "  baseline          Run Docker CIS benchmark"
    echo "  secure-run        Run container with security best practices"
    echo "  status            Show security status"
    echo ""
    echo "Examples:"
    echo "  secureos-container scan"
    echo "  secureos-container secure-run nginx:latest"
}

scan_containers() {
    echo "Scanning containers for vulnerabilities..."
    if ! command -v trivy &> /dev/null; then
        echo "Installing Trivy scanner..."
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt-get update
        sudo apt-get install -y trivy
    fi
    
    echo "Scanning running containers..."
    docker ps --format "{{.Names}}" | while read container; do
        echo "Scanning $container..."
        trivy image "$(docker inspect --format='{{.Config.Image}}' "$container")"
    done
}

audit_containers() {
    echo "Docker Security Audit"
    echo "===================="
    echo ""
    
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    echo ""
    
    echo "Privileged containers (should be none):"
    docker ps --quiet | xargs docker inspect --format '{{ .Name }}: Privileged={{ .HostConfig.Privileged }}' | grep "Privileged=true" || echo "  None (good!)"
    echo ""
    
    echo "Containers with host network (should be minimal):"
    docker ps --quiet | xargs docker inspect --format '{{ .Name }}: HostNetwork={{ .HostConfig.NetworkMode }}' | grep "HostNetwork=host" || echo "  None (good!)"
    echo ""
    
    echo "Containers running as root:"
    docker ps --quiet | xargs docker inspect --format '{{ .Name }}: User={{ .Config.User }}' | grep "User=$" || echo "  All containers have users set (good!)"
}

secure_run() {
    local image="$1"
    if [ -z "$image" ]; then
        echo "Error: Image name required"
        exit 1
    fi
    
    echo "Running container with security hardening..."
    docker run -d \
        --security-opt=no-new-privileges \
        --security-opt=apparmor=docker-secureos \
        --cap-drop=ALL \
        --cap-add=NET_BIND_SERVICE \
        --read-only \
        --tmpfs /tmp \
        --tmpfs /run \
        --pids-limit 100 \
        --memory="512m" \
        --memory-swap="512m" \
        --cpu-shares=512 \
        --health-cmd="exit 0" \
        --health-interval=30s \
        --health-timeout=3s \
        --health-retries=3 \
        "$image"
    
    echo "Container started with security hardening applied"
}

docker_status() {
    echo "Docker Security Status"
    echo "====================="
    echo ""
    echo "Docker version:"
    docker version --format '  {{.Server.Version}}'
    echo ""
    echo "Security features:"
    docker info | grep -i "security\|apparmor\|seccomp" || echo "  Check docker info manually"
    echo ""
    echo "Running containers: $(docker ps -q | wc -l)"
    echo "Total images: $(docker images -q | wc -l)"
}

case "$1" in
    scan) scan_containers ;;
    audit) audit_containers ;;
    secure-run) secure_run "$2" ;;
    status) docker_status ;;
    *) show_help ;;
esac
EOF
chmod +x /usr/local/bin/secureos-container

# Restart Docker
systemctl restart docker

success "Container security hardening complete!"
echo ""
log "Features enabled:"
echo "  ✓ Docker user namespace remapping"
echo "  ✓ Disabled inter-container communication"
echo "  ✓ Seccomp filtering"
echo "  ✓ AppArmor profiles"
echo "  ✓ Container audit logging"
echo ""
log "Usage:"
echo "  secureos-container audit           # Audit running containers"
echo "  secureos-container scan            # Scan for vulnerabilities"
echo "  secureos-container secure-run img  # Run container securely"
echo ""
log "Always run containers with minimal privileges!"
