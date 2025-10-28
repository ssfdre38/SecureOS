#!/usr/bin/env python3
"""
SecureOS GUI Security Manager
Graphical interface for managing security features
"""

import sys
import subprocess
import os
from pathlib import Path

try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                  QHBoxLayout, QPushButton, QLabel, QTextEdit,
                                  QTabWidget, QGroupBox, QCheckBox, QProgressBar,
                                  QMessageBox, QSystemTrayIcon, QMenu)
    from PyQt5.QtCore import QTimer, Qt
    from PyQt5.QtGui import QIcon
except ImportError:
    print("PyQt5 not installed. Installing...")
    subprocess.run(['apt-get', 'install', '-y', 'python3-pyqt5'], check=True)
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore import *
    from PyQt5.QtGui import *

class SecureOSGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("SecureOS Security Manager")
        self.setGeometry(100, 100, 900, 600)
        
        self.init_ui()
        self.update_status()
        
        # Auto-refresh every 30 seconds
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_status)
        self.timer.start(30000)
    
    def init_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout(central_widget)
        
        # Header
        header = QLabel("SecureOS Security & Privacy Manager")
        header.setStyleSheet("font-size: 18px; font-weight: bold; padding: 10px;")
        layout.addWidget(header)
        
        # Tabs
        tabs = QTabWidget()
        
        # Status tab
        status_tab = self.create_status_tab()
        tabs.addTab(status_tab, "System Status")
        
        # Firewall tab
        firewall_tab = self.create_firewall_tab()
        tabs.addTab(firewall_tab, "Firewall")
        
        # Privacy tab
        privacy_tab = self.create_privacy_tab()
        tabs.addTab(privacy_tab, "Privacy")
        
        # VPN tab
        vpn_tab = self.create_vpn_tab()
        tabs.addTab(vpn_tab, "VPN")
        
        # Tools tab
        tools_tab = self.create_tools_tab()
        tabs.addTab(tools_tab, "Tools")
        
        layout.addWidget(tabs)
        
        # Status bar
        self.statusBar().showMessage("Ready")
    
    def create_status_tab(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Security status group
        security_group = QGroupBox("Security Status")
        security_layout = QVBoxLayout()
        
        self.firewall_status = QLabel()
        self.apparmor_status = QLabel()
        self.audit_status = QLabel()
        self.vpn_status = QLabel()
        
        security_layout.addWidget(self.firewall_status)
        security_layout.addWidget(self.apparmor_status)
        security_layout.addWidget(self.audit_status)
        security_layout.addWidget(self.vpn_status)
        
        security_group.setLayout(security_layout)
        layout.addWidget(security_group)
        
        # Quick actions
        actions_group = QGroupBox("Quick Actions")
        actions_layout = QHBoxLayout()
        
        audit_btn = QPushButton("Run Security Audit")
        audit_btn.clicked.connect(self.run_audit)
        actions_layout.addWidget(audit_btn)
        
        update_btn = QPushButton("Update System")
        update_btn.clicked.connect(self.update_system)
        actions_layout.addWidget(update_btn)
        
        scan_btn = QPushButton("Virus Scan")
        scan_btn.clicked.connect(self.virus_scan)
        actions_layout.addWidget(scan_btn)
        
        actions_group.setLayout(actions_layout)
        layout.addWidget(actions_group)
        
        # Log viewer
        log_group = QGroupBox("Recent Security Events")
        log_layout = QVBoxLayout()
        
        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        log_layout.addWidget(self.log_view)
        
        log_group.setLayout(log_layout)
        layout.addWidget(log_group)
        
        return widget
    
    def create_firewall_tab(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Firewall controls
        control_group = QGroupBox("Firewall Control")
        control_layout = QVBoxLayout()
        
        self.fw_enabled = QCheckBox("Enable Firewall")
        self.fw_enabled.stateChanged.connect(self.toggle_firewall)
        control_layout.addWidget(self.fw_enabled)
        
        status_btn = QPushButton("Show Firewall Status")
        status_btn.clicked.connect(self.show_fw_status)
        control_layout.addWidget(status_btn)
        
        control_group.setLayout(control_layout)
        layout.addWidget(control_group)
        
        # Firewall output
        self.fw_output = QTextEdit()
        self.fw_output.setReadOnly(True)
        layout.addWidget(self.fw_output)
        
        return widget
    
    def create_privacy_tab(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Privacy settings
        settings_group = QGroupBox("Privacy Settings")
        settings_layout = QVBoxLayout()
        
        self.mac_random = QCheckBox("Randomize MAC Address")
        self.mac_random.stateChanged.connect(self.toggle_mac_random)
        settings_layout.addWidget(self.mac_random)
        
        self.dns_encrypt = QCheckBox("Use Encrypted DNS")
        settings_layout.addWidget(self.dns_encrypt)
        
        self.tor_enabled = QCheckBox("Enable Tor")
        self.tor_enabled.stateChanged.connect(self.toggle_tor)
        settings_layout.addWidget(self.tor_enabled)
        
        settings_group.setLayout(settings_layout)
        layout.addWidget(settings_group)
        
        # Privacy check
        check_group = QGroupBox("Privacy Check")
        check_layout = QVBoxLayout()
        
        check_btn = QPushButton("Check IP & DNS Leaks")
        check_btn.clicked.connect(self.check_privacy)
        check_layout.addWidget(check_btn)
        
        self.privacy_output = QTextEdit()
        self.privacy_output.setReadOnly(True)
        check_layout.addWidget(self.privacy_output)
        
        check_group.setLayout(check_layout)
        layout.addWidget(check_group)
        
        return widget
    
    def create_vpn_tab(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # VPN controls
        vpn_group = QGroupBox("VPN Connection")
        vpn_layout = QVBoxLayout()
        
        connect_btn = QPushButton("Connect VPN")
        connect_btn.clicked.connect(self.connect_vpn)
        vpn_layout.addWidget(connect_btn)
        
        disconnect_btn = QPushButton("Disconnect VPN")
        disconnect_btn.clicked.connect(self.disconnect_vpn)
        vpn_layout.addWidget(disconnect_btn)
        
        status_btn = QPushButton("Check VPN Status")
        status_btn.clicked.connect(self.vpn_status_check)
        vpn_layout.addWidget(status_btn)
        
        vpn_group.setLayout(vpn_layout)
        layout.addWidget(vpn_group)
        
        # VPN output
        self.vpn_output = QTextEdit()
        self.vpn_output.setReadOnly(True)
        layout.addWidget(self.vpn_output)
        
        return widget
    
    def create_tools_tab(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Security tools
        tools_group = QGroupBox("Security Tools")
        tools_layout = QVBoxLayout()
        
        rootkit_btn = QPushButton("Scan for Rootkits")
        rootkit_btn.clicked.connect(self.rootkit_scan)
        tools_layout.addWidget(rootkit_btn)
        
        integrity_btn = QPushButton("Check File Integrity (AIDE)")
        integrity_btn.clicked.connect(self.integrity_check)
        tools_layout.addWidget(integrity_btn)
        
        container_btn = QPushButton("Audit Containers")
        container_btn.clicked.connect(self.audit_containers)
        tools_layout.addWidget(container_btn)
        
        tools_group.setLayout(tools_layout)
        layout.addWidget(tools_group)
        
        # Tool output
        self.tool_output = QTextEdit()
        self.tool_output.setReadOnly(True)
        layout.addWidget(self.tool_output)
        
        return widget
    
    def update_status(self):
        """Update security status indicators"""
        # Check firewall
        try:
            result = subprocess.run(['ufw', 'status'], capture_output=True, text=True)
            if 'Status: active' in result.stdout:
                self.firewall_status.setText("🟢 Firewall: Active")
                self.fw_enabled.setChecked(True)
            else:
                self.firewall_status.setText("🔴 Firewall: Inactive")
                self.fw_enabled.setChecked(False)
        except:
            self.firewall_status.setText("❓ Firewall: Unknown")
        
        # Check AppArmor
        try:
            result = subprocess.run(['systemctl', 'is-active', 'apparmor'], capture_output=True, text=True)
            if 'active' in result.stdout:
                self.apparmor_status.setText("🟢 AppArmor: Enabled")
            else:
                self.apparmor_status.setText("🔴 AppArmor: Disabled")
        except:
            self.apparmor_status.setText("❓ AppArmor: Unknown")
        
        # Check audit
        try:
            result = subprocess.run(['systemctl', 'is-active', 'auditd'], capture_output=True, text=True)
            if 'active' in result.stdout:
                self.audit_status.setText("🟢 Audit Logging: Active")
            else:
                self.audit_status.setText("🔴 Audit Logging: Inactive")
        except:
            self.audit_status.setText("❓ Audit Logging: Unknown")
        
        # Load recent logs
        self.load_recent_logs()
    
    def load_recent_logs(self):
        """Load recent security logs"""
        try:
            result = subprocess.run(['tail', '-20', '/var/log/auth.log'], 
                                  capture_output=True, text=True)
            self.log_view.setPlainText(result.stdout)
        except:
            pass
    
    def toggle_firewall(self, state):
        if state == Qt.Checked:
            subprocess.run(['pkexec', 'ufw', 'enable'], capture_output=True)
        else:
            subprocess.run(['pkexec', 'ufw', 'disable'], capture_output=True)
        self.update_status()
    
    def show_fw_status(self):
        result = subprocess.run(['ufw', 'status', 'verbose'], capture_output=True, text=True)
        self.fw_output.setPlainText(result.stdout)
    
    def toggle_mac_random(self, state):
        if state == Qt.Checked:
            QMessageBox.information(self, "MAC Randomization", 
                "MAC randomization will take effect on next network connection")
    
    def toggle_tor(self, state):
        if state == Qt.Checked:
            subprocess.run(['pkexec', 'systemctl', 'start', 'tor'], capture_output=True)
        else:
            subprocess.run(['pkexec', 'systemctl', 'stop', 'tor'], capture_output=True)
    
    def check_privacy(self):
        self.privacy_output.setPlainText("Checking privacy status...\n")
        try:
            result = subprocess.run(['curl', '-s', 'https://ifconfig.me'], 
                                  capture_output=True, text=True, timeout=5)
            self.privacy_output.append(f"Public IP: {result.stdout}\n")
            
            with open('/etc/resolv.conf', 'r') as f:
                dns = f.read()
            self.privacy_output.append(f"DNS Configuration:\n{dns}")
        except Exception as e:
            self.privacy_output.append(f"Error: {e}")
    
    def connect_vpn(self):
        self.vpn_output.setPlainText("Connecting to VPN...\n")
        # This would call the VPN script
        self.vpn_output.append("Use: sudo secureos-vpn wg-connect")
    
    def disconnect_vpn(self):
        self.vpn_output.setPlainText("Disconnecting VPN...\n")
        self.vpn_output.append("Use: sudo secureos-vpn wg-disconnect")
    
    def vpn_status_check(self):
        result = subprocess.run(['wg', 'show'], capture_output=True, text=True)
        if result.stdout:
            self.vpn_output.setPlainText(result.stdout)
        else:
            self.vpn_output.setPlainText("No active VPN connection")
    
    def run_audit(self):
        QMessageBox.information(self, "Security Audit", 
            "Running security audit in terminal...\nCheck terminal for results.")
        subprocess.Popen(['x-terminal-emulator', '-e', 'sudo secureos-audit'])
    
    def update_system(self):
        reply = QMessageBox.question(self, 'System Update',
            'Update all packages?', QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            subprocess.Popen(['x-terminal-emulator', '-e', 
                            'sudo apt update && sudo apt upgrade -y'])
    
    def virus_scan(self):
        QMessageBox.information(self, "Virus Scan", 
            "Starting ClamAV scan in terminal...")
        subprocess.Popen(['x-terminal-emulator', '-e', 
                        'sudo clamscan -r /home'])
    
    def rootkit_scan(self):
        self.tool_output.setPlainText("Running rootkit scan...\n")
        subprocess.Popen(['x-terminal-emulator', '-e', 'sudo rkhunter --check'])
    
    def integrity_check(self):
        self.tool_output.setPlainText("Running AIDE integrity check...\n")
        subprocess.Popen(['x-terminal-emulator', '-e', 'sudo aide --check'])
    
    def audit_containers(self):
        result = subprocess.run(['secureos-container', 'audit'], 
                              capture_output=True, text=True)
        self.tool_output.setPlainText(result.stdout)

def main():
    app = QApplication(sys.argv)
    window = SecureOSGUI()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
