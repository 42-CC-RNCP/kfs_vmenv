#!/bin/bash
set -euo pipefail

echo "[config_system] Chapter 7: bootscripts + devices + network + sysv + profile + inputrc + shells"

# ----------------------------
# Tunables (override via env)
# ----------------------------
HOSTNAME_VALUE="${LFS_HOSTNAME:-lyeh}"
FQDN_VALUE="${LFS_FQDN:-${HOSTNAME_VALUE}.localdomain}"
LANG_VALUE="${LFS_LANG:-en_US.UTF-8}"
UTC_VALUE="${LFS_UTC:-1}"

# Optional overrides for network
LFS_IFACE="${LFS_IFACE:-}"
LFS_IP="${LFS_IP:-}"
LFS_GATEWAY="${LFS_GATEWAY:-}"
LFS_PREFIX="${LFS_PREFIX:-}"
LFS_BROADCAST="${LFS_BROADCAST:-}"
LFS_ONBOOT="${LFS_ONBOOT:-}"
LFS_SERVICE="${LFS_SERVICE:-ipv4-static}"

mkdir -pv /etc/sysconfig /etc/udev/rules.d

# ============================================================
# 7.4 Managing devices
# ============================================================

# 7.4.1.2: generate initial NIC naming rules
if [[ -x /lib/udev/init-net-rules.sh ]]; then
  echo "[7.4] Generating initial persistent net rules (best-effort)..."
  bash /lib/udev/init-net-rules.sh || true
fi

# 7.4.2: choose CD-ROM symlink rule mode
if [[ -f /etc/udev/rules.d/83-cdrom-symlinks.rules ]]; then
  echo "[7.4] Setting CD-ROM symlink rule mode to by-id (optional)..."
  sed -i -e 's/"write_cd_rules"/"write_cd_rules by-id"/' \
    /etc/udev/rules.d/83-cdrom-symlinks.rules || true
fi

# ============================================================
# 7.5 General network configuration
# ============================================================

detect_iface() {
  local dev=""
  dev="$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}' || true)"
  if [[ -z "${dev}" ]]; then
    dev="$(ls -1 /sys/class/net 2>/dev/null | grep -v '^lo$' | head -n1 || true)"
  fi
  echo "${dev:-eth0}"
}

IFACE="${LFS_IFACE:-$(detect_iface)}"
CFG_IF="/etc/sysconfig/ifconfig.${IFACE}"

# Try to infer IP params
if [[ -z "${LFS_IP}" ]]; then
  CIDR="$(ip -o -4 addr show dev "${IFACE}" 2>/dev/null | awk '{print $4; exit}' || true)"
  if [[ -n "${CIDR}" ]]; then
    LFS_IP="${CIDR%/*}"
    [[ -z "${LFS_PREFIX}" ]] && LFS_PREFIX="${CIDR#*/}"
  fi
fi
if [[ -z "${LFS_GATEWAY}" ]]; then
  LFS_GATEWAY="$(ip route show default 2>/dev/null | awk -v dev="${IFACE}" '$0 ~ (" dev "dev" ") {for(i=1;i<=NF;i++) if($i=="via"){print $(i+1); exit}}' || true)"
fi
if [[ -z "${LFS_BROADCAST}" ]]; then
  LFS_BROADCAST="$(ip -o -4 addr show dev "${IFACE}" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="brd"){print $(i+1); exit}}' || true)"
fi
[[ -z "${LFS_PREFIX}" ]] && LFS_PREFIX="24"

# Decide ONBOOT default
if [[ -z "${LFS_ONBOOT}" ]]; then
  if [[ -n "${LFS_IP}" ]]; then LFS_ONBOOT="yes"; else LFS_ONBOOT="no"; fi
fi

echo "[7.5] Writing ${CFG_IF}"
cat > "${CFG_IF}" <<EOF
ONBOOT=${LFS_ONBOOT}
IFACE=${IFACE}
SERVICE=${LFS_SERVICE}
IP=${LFS_IP}
GATEWAY=${LFS_GATEWAY}
PREFIX=${LFS_PREFIX}
BROADCAST=${LFS_BROADCAST}
EOF

echo "[7.5] Writing /etc/resolv.conf"
if [[ -r /proc/1/root/etc/resolv.conf ]]; then
  # best-effort copy from host init's view; keep only relevant lines
  grep -E '^(nameserver|search|domain)\b' /proc/1/root/etc/resolv.conf > /etc/resolv.conf || true
fi
if [[ ! -s /etc/resolv.conf ]]; then
  cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
fi

echo "[7.5] Writing /etc/hostname = ${HOSTNAME_VALUE}"
echo "${HOSTNAME_VALUE}" > /etc/hostname

echo "[7.5] Writing /etc/hosts"
cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 ${FQDN_VALUE} ${HOSTNAME_VALUE}
EOF
if [[ -n "${LFS_IP}" ]]; then
  echo "${LFS_IP} ${FQDN_VALUE} ${HOSTNAME_VALUE}" >> /etc/hosts
fi
cat >> /etc/hosts <<'EOF'
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

# ============================================================
# 7.6 System V bootscripts usage & configuration
# ============================================================

echo "[7.6] Writing /etc/inittab"
cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

echo "[7.6] Writing /etc/sysconfig/udev_retry (empty by default)"
cat > /etc/sysconfig/udev_retry <<'EOF'
# Put subsystem names (words) here if you have devices whose udev rules need retry after mountfs.
# See udev_retry explanation in 7.6.3. :contentReference[oaicite:22]{index=22}
EOF

echo "[7.6] Writing /etc/sysconfig/clock"
cat > /etc/sysconfig/clock <<EOF
UTC=${UTC_VALUE}
CLOCKPARAMS=
EOF

echo "[7.6] Writing /etc/sysconfig/console (US defaults)"
cat > /etc/sysconfig/console <<'EOF'
# Begin /etc/sysconfig/console
# US defaults: do not set KEYMAP/FONT/UNICODE so the system uses defaults.
LOGLEVEL="7"
# End /etc/sysconfig/console
EOF

echo "[7.6] Writing /etc/sysconfig/createfiles (leave empty unless needed)"
cat > /etc/sysconfig/createfiles <<'EOF'
# Add entries here if you need to create files/dirs at boot time (see 7.6.6).
EOF

echo "[7.6] Writing /etc/sysconfig/rc.site (minimal)"
cat > /etc/sysconfig/rc.site <<'EOF'
# Minimal rc.site: extend later if you want IPROMPT etc.
SYSKLOGD_PARMS="-m 0"
EOF
# 7.6.7 sysklogd 建議用 -m 0；7.6.8 rc.site 概念 :contentReference[oaicite:26]{index=26}

# ============================================================
# 7.7 Bash startup files
# ============================================================
echo "[7.7] Writing /etc/profile"
cat > /etc/profile <<EOF
# Global profile
export LANG=${LANG_VALUE}
EOF
# 7.7 指示建立 /etc/profile 並 export LANG :contentReference[oaicite:27]{index=27}

# ============================================================
# 7.8 /etc/inputrc
# ============================================================
echo "[7.8] Writing /etc/inputrc"
cat > /etc/inputrc <<'EOF'
# Readline global config
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none

# word movement
"\eOd": backward-word
"\eOc": forward-word

# linux console keys
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# xterm keys
"\eOH": beginning-of-line
"\eOF": end-of-line

# konsole keys
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF
# 7.8 提供全域 inputrc 範例 :contentReference[oaicite:28]{index=28}

# ============================================================
# 7.9 /etc/shells
# ============================================================
echo "[7.9] Writing /etc/shells"
cat > /etc/shells <<'EOF'
/bin/sh
/bin/bash
EOF
# 7.9 要列出合法 shells :contentReference[oaicite:29]{index=29}

echo "[config_system] Done. Next: Chapter 8 (make system bootable)."
