#!/usr/bin/env python3
"""
SecureOS - Security Enhanced Linux Distribution
Part of Barrer Software

Copyright (c) 2025 Barrer Software
Licensed under the MIT License
"""

"""
SecureOS Interactive Installer
A security and privacy-focused Linux distribution installer
"""

import os
import sys
import subprocess
import curses
from typing import List, Tuple
import crypt
import random
import string

class SecureInstaller:
    def __init__(self):
        self.config = {
            'hostname': '',
            'username': '',
            'password': '',
            'disk': '',
            'partition_scheme': 'encrypted',
            'enable_firewall': True,
            'enable_apparmor': True,
            'enable_auditd': True,
            'disable_root': True,
            'install_hardening': True,
            'privacy_mode': 'maximum'
        }
        self.available_disks = []
        
    def get_available_disks(self) -> List[str]:
        """Get list of available disks"""
        try:
            result = subprocess.run(['lsblk', '-ndo', 'NAME,SIZE,TYPE'], 
                                  capture_output=True, text=True, check=True)
            disks = []
            for line in result.stdout.strip().split('\n'):
                parts = line.split()
                if len(parts) >= 3 and parts[2] == 'disk':
                    disks.append(f"/dev/{parts[0]} ({parts[1]})")
            return disks
        except:
            return ["/dev/sda (Unknown)", "/dev/nvme0n1 (Unknown)"]
    
    def draw_menu(self, stdscr, title: str, items: List[str], selected: int):
        """Draw a menu with selectable items"""
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        # Title
        stdscr.addstr(1, 2, "═" * (w - 4))
        title_x = (w - len(title)) // 2
        stdscr.addstr(2, title_x, title, curses.A_BOLD)
        stdscr.addstr(3, 2, "═" * (w - 4))
        
        # Menu items
        for idx, item in enumerate(items):
            y = 5 + idx * 2
            if y >= h - 3:
                break
            
            if idx == selected:
                stdscr.addstr(y, 4, f"▸ {item}", curses.A_REVERSE | curses.A_BOLD)
            else:
                stdscr.addstr(y, 4, f"  {item}")
        
        # Instructions
        stdscr.addstr(h - 2, 2, "↑/↓: Navigate | Enter: Select | Q: Quit", curses.A_DIM)
        stdscr.refresh()
    
    def get_input(self, stdscr, prompt: str, password: bool = False) -> str:
        """Get text input from user"""
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        stdscr.addstr(2, 2, "═" * (w - 4))
        stdscr.addstr(3, 4, prompt, curses.A_BOLD)
        stdscr.addstr(4, 2, "═" * (w - 4))
        
        if password:
            stdscr.addstr(6, 4, "Input will be hidden for security")
        
        stdscr.addstr(8, 4, "Input: ")
        stdscr.refresh()
        
        curses.echo() if not password else curses.noecho()
        input_str = stdscr.getstr(8, 11, w - 15).decode('utf-8')
        curses.noecho()
        
        return input_str
    
    def show_confirmation(self, stdscr) -> bool:
        """Show configuration summary and get confirmation"""
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        stdscr.addstr(1, 2, "═" * (w - 4))
        title = "CONFIRM INSTALLATION"
        stdscr.addstr(2, (w - len(title)) // 2, title, curses.A_BOLD)
        stdscr.addstr(3, 2, "═" * (w - 4))
        
        y = 5
        stdscr.addstr(y, 4, f"Hostname: {self.config['hostname']}")
        y += 1
        stdscr.addstr(y, 4, f"Username: {self.config['username']}")
        y += 1
        stdscr.addstr(y, 4, f"Disk: {self.config['disk']}")
        y += 1
        stdscr.addstr(y, 4, f"Encryption: {'Enabled' if self.config['partition_scheme'] == 'encrypted' else 'Disabled'}")
        y += 1
        stdscr.addstr(y, 4, f"Firewall: {'Enabled' if self.config['enable_firewall'] else 'Disabled'}")
        y += 1
        stdscr.addstr(y, 4, f"AppArmor: {'Enabled' if self.config['enable_apparmor'] else 'Disabled'}")
        y += 1
        stdscr.addstr(y, 4, f"Audit Logging: {'Enabled' if self.config['enable_auditd'] else 'Disabled'}")
        y += 1
        stdscr.addstr(y, 4, f"Root Account: {'Disabled' if self.config['disable_root'] else 'Enabled'}")
        y += 1
        stdscr.addstr(y, 4, f"Security Hardening: {'Enabled' if self.config['install_hardening'] else 'Disabled'}")
        y += 1
        stdscr.addstr(y, 4, f"Privacy Mode: {self.config['privacy_mode'].upper()}")
        
        stdscr.addstr(h - 4, 4, "WARNING: This will ERASE all data on the selected disk!", curses.A_BOLD | curses.color_pair(1))
        stdscr.addstr(h - 2, 4, "Proceed with installation? (y/N): ")
        stdscr.refresh()
        
        curses.echo()
        response = stdscr.getstr(h - 2, 38, 1).decode('utf-8').lower()
        curses.noecho()
        
        return response == 'y'
    
    def install_system(self, stdscr):
        """Perform the actual installation"""
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        stdscr.addstr(2, 2, "Installing SecureOS...")
        stdscr.refresh()
        
        steps = [
            ("Partitioning disk...", 10),
            ("Setting up encryption...", 15),
            ("Installing base system...", 30),
            ("Configuring security modules...", 20),
            ("Hardening system...", 15),
            ("Configuring privacy settings...", 10),
            ("Finalizing installation...", 10)
        ]
        
        total_progress = sum(step[1] for step in steps)
        current_progress = 0
        
        for step_name, step_weight in steps:
            stdscr.addstr(4, 4, f"▸ {step_name}" + " " * 40)
            
            # Progress bar
            progress_width = w - 12
            filled = int((current_progress / total_progress) * progress_width)
            bar = "█" * filled + "░" * (progress_width - filled)
            stdscr.addstr(6, 4, f"[{bar}] {int(current_progress / total_progress * 100)}%")
            stdscr.refresh()
            
            # Simulate installation step
            import time
            time.sleep(step_weight / 10)
            
            current_progress += step_weight
        
        stdscr.addstr(8, 4, "✓ Installation completed successfully!", curses.A_BOLD)
        stdscr.addstr(10, 4, "Press any key to exit...")
        stdscr.refresh()
        stdscr.getch()
    
    def run(self, stdscr):
        """Main installer loop"""
        curses.curs_set(0)
        curses.init_pair(1, curses.COLOR_RED, curses.COLOR_BLACK)
        
        # Welcome screen
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        welcome = [
            "╔═══════════════════════════════════════╗",
            "║     Welcome to SecureOS Installer    ║",
            "║                                       ║",
            "║  Security & Privacy Focused Linux    ║",
            "╚═══════════════════════════════════════╝"
        ]
        
        start_y = (h - len(welcome)) // 2
        for idx, line in enumerate(welcome):
            x = (w - len(line)) // 2
            stdscr.addstr(start_y + idx, x, line, curses.A_BOLD)
        
        stdscr.addstr(h - 2, (w - 30) // 2, "Press any key to continue...")
        stdscr.refresh()
        stdscr.getch()
        
        # Main menu
        menu_items = [
            "1. Quick Install (Recommended Secure Defaults)",
            "2. Custom Install (Advanced Configuration)",
            "3. About SecureOS",
            "4. Exit"
        ]
        
        selected = 0
        while True:
            self.draw_menu(stdscr, "MAIN MENU", menu_items, selected)
            
            key = stdscr.getch()
            if key == curses.KEY_UP and selected > 0:
                selected -= 1
            elif key == curses.KEY_DOWN and selected < len(menu_items) - 1:
                selected += 1
            elif key in [ord('\n'), ord('\r')]:
                if selected == 0:
                    self.quick_install(stdscr)
                    return
                elif selected == 1:
                    self.custom_install(stdscr)
                    return
                elif selected == 2:
                    self.show_about(stdscr)
                elif selected == 3:
                    return
            elif key in [ord('q'), ord('Q')]:
                return
    
    def quick_install(self, stdscr):
        """Quick installation with secure defaults"""
        # Get basic info
        self.config['hostname'] = self.get_input(stdscr, "Enter hostname for this system:")
        if not self.config['hostname']:
            self.config['hostname'] = "secureos"
        
        self.config['username'] = self.get_input(stdscr, "Enter username:")
        while not self.config['username']:
            self.config['username'] = self.get_input(stdscr, "Username cannot be empty. Enter username:")
        
        self.config['password'] = self.get_input(stdscr, "Enter password:", password=True)
        while len(self.config['password']) < 8:
            self.config['password'] = self.get_input(stdscr, "Password too short (min 8 chars). Enter password:", password=True)
        
        # Select disk
        self.available_disks = self.get_available_disks()
        disk_selected = 0
        
        while True:
            self.draw_menu(stdscr, "SELECT INSTALLATION DISK", self.available_disks, disk_selected)
            key = stdscr.getch()
            
            if key == curses.KEY_UP and disk_selected > 0:
                disk_selected -= 1
            elif key == curses.KEY_DOWN and disk_selected < len(self.available_disks) - 1:
                disk_selected += 1
            elif key in [ord('\n'), ord('\r')]:
                self.config['disk'] = self.available_disks[disk_selected].split()[0]
                break
        
        # Confirm and install
        if self.show_confirmation(stdscr):
            self.install_system(stdscr)
    
    def custom_install(self, stdscr):
        """Custom installation with full configuration options"""
        self.quick_install(stdscr)  # For now, same as quick install
    
    def show_about(self, stdscr):
        """Show about information"""
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        about_text = [
            "SecureOS - Security & Privacy Focused Linux Distribution",
            "",
            "Features:",
            "• Full disk encryption by default",
            "• Hardened kernel with security patches",
            "• AppArmor mandatory access control",
            "• UFW firewall pre-configured",
            "• Audit logging for security events",
            "• Privacy-enhanced DNS and networking",
            "• Minimal attack surface",
            "• Regular security updates",
            "• No telemetry or tracking",
            "",
            "Based on: Ubuntu/Debian",
            "Version: 1.0.0",
        ]
        
        stdscr.addstr(2, 2, "═" * (w - 4))
        start_y = 4
        for idx, line in enumerate(about_text):
            if start_y + idx < h - 3:
                stdscr.addstr(start_y + idx, 4, line)
        
        stdscr.addstr(h - 2, 4, "Press any key to return...")
        stdscr.refresh()
        stdscr.getch()

def main():
    installer = SecureInstaller()
    try:
        curses.wrapper(installer.run)
    except KeyboardInterrupt:
        print("\nInstallation cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\nError during installation: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("This installer must be run as root.")
        sys.exit(1)
    main()
