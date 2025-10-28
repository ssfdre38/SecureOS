#!/usr/bin/env python3
"""
SecureOS - Security Enhanced Linux Distribution
Part of Barrer Software

Copyright (c) 2025 Barrer Software
Licensed under the MIT License
"""

"""
SecureOS v3.0.0 Advanced Installer
Desktop and Server installation with role selection
"""

import curses
import subprocess
import os
import sys
from pathlib import Path

class SecureOSInstallerV3:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.install_type = None  # 'desktop' or 'server'
        self.server_roles = []
        curses.curs_set(0)
        self.setup_colors()
        
    def setup_colors(self):
        curses.init_pair(1, curses.COLOR_CYAN, curses.COLOR_BLACK)
        curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)
        curses.init_pair(4, curses.COLOR_RED, curses.COLOR_BLACK)
        
    def draw_box(self, y, x, height, width, title=""):
        """Draw a box with optional title"""
        self.stdscr.attron(curses.color_pair(1))
        
        # Draw corners and edges
        self.stdscr.addch(y, x, curses.ACS_ULCORNER)
        self.stdscr.addch(y, x + width - 1, curses.ACS_URCORNER)
        self.stdscr.addch(y + height - 1, x, curses.ACS_LLCORNER)
        self.stdscr.addch(y + height - 1, x + width - 1, curses.ACS_LRCORNER)
        
        for i in range(1, width - 1):
            self.stdscr.addch(y, x + i, curses.ACS_HLINE)
            self.stdscr.addch(y + height - 1, x + i, curses.ACS_HLINE)
            
        for i in range(1, height - 1):
            self.stdscr.addch(y + i, x, curses.ACS_VLINE)
            self.stdscr.addch(y + i, x + width - 1, curses.ACS_VLINE)
            
        if title:
            title_text = f" {title} "
            self.stdscr.addstr(y, x + (width - len(title_text)) // 2, title_text)
            
        self.stdscr.attroff(curses.color_pair(1))
    
    def show_welcome(self):
        """Show welcome screen"""
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()
        
        # Banner
        banner = [
            "╔═══════════════════════════════════════════════════════╗",
            "║          SecureOS v3.0.0 Advanced Installer          ║",
            "║        Security & Privacy Enhanced Distribution       ║",
            "╚═══════════════════════════════════════════════════════╝"
        ]
        
        start_y = height // 4
        for i, line in enumerate(banner):
            self.stdscr.addstr(start_y + i, (width - len(line)) // 2, line, 
                             curses.color_pair(2) | curses.A_BOLD)
        
        info = [
            "",
            "Welcome to SecureOS!",
            "",
            "This installer will guide you through:",
            "  • Desktop or Server installation",
            "  • Server role selection (web, VPN, file server, etc.)",
            "  • Security hardening configuration",
            "  • Full disk encryption setup",
            "",
            "Press any key to continue..."
        ]
        
        info_start = start_y + len(banner) + 2
        for i, line in enumerate(info):
            self.stdscr.addstr(info_start + i, (width - len(line)) // 2, line)
        
        self.stdscr.refresh()
        self.stdscr.getch()
    
    def select_install_type(self):
        """Choose between Desktop and Server installation"""
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()
        
        title = "Select Installation Type"
        self.stdscr.addstr(2, (width - len(title)) // 2, title, 
                          curses.color_pair(2) | curses.A_BOLD)
        
        options = [
            ("Desktop", "Full desktop environment with GUI tools"),
            ("Server", "Minimal server with role-based configuration")
        ]
        
        current = 0
        
        while True:
            start_y = 6
            for idx, (name, desc) in enumerate(options):
                y = start_y + (idx * 4)
                
                if idx == current:
                    attr = curses.color_pair(2) | curses.A_REVERSE
                else:
                    attr = curses.A_NORMAL
                
                self.stdscr.addstr(y, 10, f"[{'*' if idx == current else ' '}] {name}", attr | curses.A_BOLD)
                self.stdscr.addstr(y + 1, 14, desc, curses.color_pair(1))
            
            self.stdscr.addstr(height - 3, 10, "Use ↑↓ to select, Enter to continue")
            self.stdscr.refresh()
            
            key = self.stdscr.getch()
            
            if key == curses.KEY_UP:
                current = max(0, current - 1)
            elif key == curses.KEY_DOWN:
                current = min(len(options) - 1, current + 1)
            elif key in [curses.KEY_ENTER, 10, 13]:
                self.install_type = options[current][0].lower()
                break
        
        return self.install_type
    
    def select_server_roles(self):
        """Select server roles to install"""
        if self.install_type != 'server':
            return []
        
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()
        
        title = "Select Server Roles (Space to toggle, Enter when done)"
        self.stdscr.addstr(2, (width - len(title)) // 2, title, 
                          curses.color_pair(2) | curses.A_BOLD)
        
        roles = [
            ("base", "Base Server (minimal install)", True),
            ("web", "Web Host (nginx, Apache, PHP, MySQL)", False),
            ("vpn", "VPN Server (WireGuard, OpenVPN)", False),
            ("dev", "Development Environment (git, docker, build tools)", False),
            ("vscode-web", "VS Code Server (web-based IDE)", False),
            ("file", "File Server (Samba, NFS, ZFS)", False),
            ("zfs-web", "ZFS Web Interface (Cockpit + ZFS)", False),
            ("mail", "Mail Server (Postfix, Dovecot)", False),
            ("database", "Database Server (PostgreSQL, MySQL, Redis)", False),
            ("monitoring", "Monitoring Stack (Prometheus, Grafana)", False),
            ("container", "Container Host (Docker, Kubernetes)", False),
            ("backup", "Backup Server (Bacula, rsync)", False),
        ]
        
        selected = [i for i, r in enumerate(roles) if r[2]]
        current = 0
        
        while True:
            start_y = 5
            for idx, (role_id, desc, default) in enumerate(roles):
                y = start_y + idx
                
                if y >= height - 4:
                    break
                
                is_selected = idx in selected
                is_current = idx == current
                
                checkbox = '[X]' if is_selected else '[ ]'
                
                if is_current:
                    attr = curses.color_pair(2) | curses.A_REVERSE
                else:
                    attr = curses.color_pair(2) if is_selected else curses.A_NORMAL
                
                self.stdscr.addstr(y, 5, f"{checkbox} {role_id.upper()}: {desc}", attr)
            
            self.stdscr.addstr(height - 3, 5, "↑↓: Navigate  Space: Toggle  Enter: Continue")
            self.stdscr.refresh()
            
            key = self.stdscr.getch()
            
            if key == curses.KEY_UP:
                current = max(0, current - 1)
            elif key == curses.KEY_DOWN:
                current = min(len(roles) - 1, current + 1)
            elif key == ord(' '):
                if current in selected:
                    if current != 0:  # Can't deselect base
                        selected.remove(current)
                else:
                    selected.append(current)
            elif key in [curses.KEY_ENTER, 10, 13]:
                self.server_roles = [roles[i][0] for i in sorted(selected)]
                break
        
        return self.server_roles
    
    def show_summary(self):
        """Show installation summary"""
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()
        
        title = "Installation Summary"
        self.stdscr.addstr(2, (width - len(title)) // 2, title, 
                          curses.color_pair(2) | curses.A_BOLD)
        
        y = 5
        self.stdscr.addstr(y, 5, f"Installation Type: {self.install_type.upper()}", 
                          curses.color_pair(2) | curses.A_BOLD)
        y += 2
        
        if self.install_type == 'server':
            self.stdscr.addstr(y, 5, "Selected Roles:", curses.A_BOLD)
            y += 1
            for role in self.server_roles:
                self.stdscr.addstr(y, 7, f"• {role}", curses.color_pair(1))
                y += 1
        else:
            self.stdscr.addstr(y, 5, "• XFCE Desktop Environment")
            y += 1
            self.stdscr.addstr(y, 5, "• Full GUI applications")
            y += 1
            self.stdscr.addstr(y, 5, "• Security tools included")
            y += 1
        
        y += 2
        self.stdscr.addstr(y, 5, "Security Features:", curses.A_BOLD)
        y += 1
        security_features = [
            "✓ Full disk encryption (LUKS2)",
            "✓ AppArmor mandatory access control",
            "✓ Firewall (UFW) pre-configured",
            "✓ Audit logging enabled",
            "✓ Automatic security updates"
        ]
        for feature in security_features:
            self.stdscr.addstr(y, 7, feature, curses.color_pair(2))
            y += 1
        
        y += 2
        self.stdscr.addstr(y, 5, "Continue with installation? (y/n): ")
        self.stdscr.refresh()
        
        while True:
            key = self.stdscr.getch()
            if key in [ord('y'), ord('Y')]:
                return True
            elif key in [ord('n'), ord('N')]:
                return False
    
    def run(self):
        """Main installation flow"""
        try:
            self.show_welcome()
            self.select_install_type()
            
            if self.install_type == 'server':
                self.select_server_roles()
            
            if self.show_summary():
                # Write config file for actual installer
                config = {
                    'install_type': self.install_type,
                    'server_roles': self.server_roles
                }
                
                with open('/tmp/secureos-install-config.txt', 'w') as f:
                    f.write(f"INSTALL_TYPE={self.install_type}\n")
                    if self.server_roles:
                        f.write(f"SERVER_ROLES={','.join(self.server_roles)}\n")
                
                self.stdscr.clear()
                self.stdscr.addstr(10, 10, "Configuration saved!", 
                                 curses.color_pair(2) | curses.A_BOLD)
                self.stdscr.addstr(11, 10, "Starting installation...")
                self.stdscr.refresh()
                self.stdscr.getch()
                
                return True
            else:
                return False
                
        except KeyboardInterrupt:
            return False

def main():
    if os.geteuid() != 0:
        print("Error: This installer must be run as root")
        sys.exit(1)
    
    result = curses.wrapper(lambda stdscr: SecureOSInstallerV3(stdscr).run())
    
    if result:
        print("\n✓ Configuration complete!")
        print("  Configuration saved to: /tmp/secureos-install-config.txt")
        print("\nNext: Run the actual installation with:")
        print("  sudo bash /usr/local/lib/secureos-installer/install-system.sh")
    else:
        print("\nInstallation cancelled.")

if __name__ == '__main__':
    main()
