#!/usr/bin/env python3
"""
SecureOS v5.0.0 - Self-Healing Security System
Autonomous detection and remediation of security issues
"""

import os
import sys
import json
import time
import subprocess
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import hashlib


class SecurityIssue:
    """Represents a detected security issue"""
    
    def __init__(self, issue_type: str, severity: str, description: str, 
                 affected_component: str, remediation_action: str):
        self.id = hashlib.md5(f"{issue_type}{affected_component}{time.time()}".encode()).hexdigest()[:16]
        self.type = issue_type
        self.severity = severity
        self.description = description
        self.affected_component = affected_component
        self.remediation_action = remediation_action
        self.detected_at = datetime.now().isoformat()
        self.remediated = False
        self.remediated_at = None


class SelfHealingEngine:
    """Autonomous security remediation system"""
    
    SEVERITY_LEVELS = ['info', 'low', 'medium', 'high', 'critical']
    
    def __init__(self, config_path: str = "/etc/secureos/v5/self-healing.json"):
        self.config_path = Path(config_path)
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        
        self.config = self._load_config()
        self.issues_db = Path("/var/lib/secureos/self-healing/issues.json")
        self.issues_db.parent.mkdir(parents=True, exist_ok=True)
        
        self.detected_issues: List[SecurityIssue] = []
        self.remediation_history: List[Dict] = []
        
        self._load_history()
    
    def _load_config(self) -> dict:
        """Load self-healing configuration"""
        default_config = {
            'enabled': True,
            'auto_remediate': True,
            'min_severity_auto': 'medium',
            'max_remediation_attempts': 3,
            'notification_enabled': True,
            'dry_run': False,
            'scan_interval_minutes': 60,
            'checks': {
                'permissions': True,
                'services': True,
                'firewall': True,
                'packages': True,
                'config_files': True,
                'users': True,
                'ssh': True,
                'kernel_params': True
            }
        }
        
        if self.config_path.exists():
            with open(self.config_path, 'r') as f:
                return {**default_config, **json.load(f)}
        
        # Save default config
        with open(self.config_path, 'w') as f:
            json.dump(default_config, f, indent=2)
        
        return default_config
    
    def _load_history(self):
        """Load remediation history"""
        if self.issues_db.exists():
            with open(self.issues_db, 'r') as f:
                data = json.load(f)
                self.remediation_history = data.get('history', [])
    
    def _save_history(self):
        """Save remediation history"""
        data = {
            'last_updated': datetime.now().isoformat(),
            'history': self.remediation_history
        }
        with open(self.issues_db, 'w') as f:
            json.dump(data, f, indent=2)
    
    def scan_system(self) -> List[SecurityIssue]:
        """Comprehensive security scan"""
        print("Starting comprehensive security scan...")
        self.detected_issues = []
        
        if self.config['checks']['permissions']:
            self._check_file_permissions()
        
        if self.config['checks']['services']:
            self._check_services()
        
        if self.config['checks']['firewall']:
            self._check_firewall()
        
        if self.config['checks']['packages']:
            self._check_packages()
        
        if self.config['checks']['config_files']:
            self._check_config_files()
        
        if self.config['checks']['users']:
            self._check_users()
        
        if self.config['checks']['ssh']:
            self._check_ssh_config()
        
        if self.config['checks']['kernel_params']:
            self._check_kernel_params()
        
        print(f"Scan complete. Found {len(self.detected_issues)} issues.")
        return self.detected_issues
    
    def _check_file_permissions(self):
        """Check critical file permissions"""
        critical_files = {
            '/etc/passwd': '0644',
            '/etc/shadow': '0640',
            '/etc/gshadow': '0640',
            '/etc/ssh/sshd_config': '0600',
            '/boot/grub/grub.cfg': '0400',
        }
        
        for file_path, expected_perms in critical_files.items():
            if not os.path.exists(file_path):
                continue
            
            stat_info = os.stat(file_path)
            actual_perms = oct(stat_info.st_mode)[-4:]
            
            if actual_perms != expected_perms:
                issue = SecurityIssue(
                    issue_type='incorrect_permissions',
                    severity='high',
                    description=f"{file_path} has permissions {actual_perms}, expected {expected_perms}",
                    affected_component=file_path,
                    remediation_action=f"chmod {expected_perms} {file_path}"
                )
                self.detected_issues.append(issue)
    
    def _check_services(self):
        """Check for unnecessary running services"""
        unwanted_services = [
            'telnet',
            'rsh',
            'rlogin',
            'vsftpd',
            'cups'  # Unless printing is needed
        ]
        
        for service in unwanted_services:
            try:
                result = subprocess.run(
                    ['systemctl', 'is-active', service],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.stdout.strip() == 'active':
                    issue = SecurityIssue(
                        issue_type='unnecessary_service',
                        severity='medium',
                        description=f"Potentially unnecessary service '{service}' is running",
                        affected_component=service,
                        remediation_action=f"systemctl stop {service} && systemctl disable {service}"
                    )
                    self.detected_issues.append(issue)
            except:
                pass
    
    def _check_firewall(self):
        """Check firewall status"""
        try:
            result = subprocess.run(
                ['ufw', 'status'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if 'inactive' in result.stdout.lower():
                issue = SecurityIssue(
                    issue_type='firewall_disabled',
                    severity='critical',
                    description="UFW firewall is not active",
                    affected_component='ufw',
                    remediation_action="ufw --force enable"
                )
                self.detected_issues.append(issue)
        except:
            issue = SecurityIssue(
                issue_type='firewall_missing',
                severity='critical',
                description="UFW firewall is not installed",
                affected_component='ufw',
                remediation_action="apt-get install -y ufw && ufw --force enable"
            )
            self.detected_issues.append(issue)
    
    def _check_packages(self):
        """Check for outdated packages"""
        try:
            # Update package lists
            subprocess.run(['apt-get', 'update'], capture_output=True, timeout=60)
            
            # Check for upgradable packages
            result = subprocess.run(
                ['apt', 'list', '--upgradable'],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            upgradable = [line for line in result.stdout.split('\n') if '/' in line]
            
            if len(upgradable) > 0:
                issue = SecurityIssue(
                    issue_type='outdated_packages',
                    severity='medium',
                    description=f"{len(upgradable)} packages can be upgraded",
                    affected_component='apt',
                    remediation_action="apt-get upgrade -y"
                )
                self.detected_issues.append(issue)
        except:
            pass
    
    def _check_config_files(self):
        """Check critical configuration files"""
        # Check sysctl security settings
        security_params = {
            'net.ipv4.conf.all.accept_source_route': '0',
            'net.ipv4.conf.default.accept_source_route': '0',
            'net.ipv4.conf.all.send_redirects': '0',
            'net.ipv4.conf.default.send_redirects': '0',
            'net.ipv4.icmp_echo_ignore_broadcasts': '1',
            'kernel.dmesg_restrict': '1',
            'kernel.kptr_restrict': '2',
        }
        
        for param, expected_value in security_params.items():
            try:
                result = subprocess.run(
                    ['sysctl', '-n', param],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                actual_value = result.stdout.strip()
                
                if actual_value != expected_value:
                    issue = SecurityIssue(
                        issue_type='insecure_kernel_param',
                        severity='medium',
                        description=f"Kernel parameter {param} is {actual_value}, should be {expected_value}",
                        affected_component=param,
                        remediation_action=f"sysctl -w {param}={expected_value}"
                    )
                    self.detected_issues.append(issue)
            except:
                pass
    
    def _check_users(self):
        """Check for suspicious user accounts"""
        # Check for users with UID 0 (root equivalents)
        try:
            with open('/etc/passwd', 'r') as f:
                for line in f:
                    parts = line.strip().split(':')
                    if len(parts) >= 3:
                        username = parts[0]
                        uid = parts[2]
                        
                        if uid == '0' and username != 'root':
                            issue = SecurityIssue(
                                issue_type='suspicious_user',
                                severity='critical',
                                description=f"User '{username}' has UID 0 (root privileges)",
                                affected_component=username,
                                remediation_action=f"userdel {username}"
                            )
                            self.detected_issues.append(issue)
        except:
            pass
    
    def _check_ssh_config(self):
        """Check SSH configuration security"""
        ssh_config = Path('/etc/ssh/sshd_config')
        
        if not ssh_config.exists():
            return
        
        required_settings = {
            'PermitRootLogin': 'no',
            'PasswordAuthentication': 'no',
            'PermitEmptyPasswords': 'no',
            'X11Forwarding': 'no',
        }
        
        try:
            with open(ssh_config, 'r') as f:
                config_content = f.read()
            
            for setting, expected_value in required_settings.items():
                if f"{setting} {expected_value}" not in config_content:
                    issue = SecurityIssue(
                        issue_type='insecure_ssh_config',
                        severity='high',
                        description=f"SSH config: {setting} should be {expected_value}",
                        affected_component='sshd_config',
                        remediation_action=f"sed -i 's/^#*{setting}.*/{setting} {expected_value}/' /etc/ssh/sshd_config && systemctl restart sshd"
                    )
                    self.detected_issues.append(issue)
        except:
            pass
    
    def _check_kernel_params(self):
        """Check kernel security parameters"""
        # Check if kernel lockdown is enabled
        lockdown_file = Path('/sys/kernel/security/lockdown')
        if lockdown_file.exists():
            try:
                with open(lockdown_file, 'r') as f:
                    content = f.read()
                    if '[none]' in content:
                        issue = SecurityIssue(
                            issue_type='kernel_lockdown_disabled',
                            severity='high',
                            description="Kernel lockdown is disabled",
                            affected_component='kernel',
                            remediation_action="Add lockdown=confidentiality to kernel parameters"
                        )
                        self.detected_issues.append(issue)
            except:
                pass
    
    def remediate_issue(self, issue: SecurityIssue) -> bool:
        """Remediate a specific security issue"""
        print(f"\nRemediating: {issue.description}")
        print(f"Action: {issue.remediation_action}")
        
        if self.config['dry_run']:
            print("[DRY RUN] Would execute remediation")
            return True
        
        try:
            # Execute remediation command
            result = subprocess.run(
                issue.remediation_action,
                shell=True,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            success = result.returncode == 0
            
            # Record in history
            remediation_record = {
                'issue_id': issue.id,
                'issue_type': issue.type,
                'severity': issue.severity,
                'description': issue.description,
                'action': issue.remediation_action,
                'timestamp': datetime.now().isoformat(),
                'success': success,
                'output': result.stdout if success else result.stderr
            }
            
            self.remediation_history.append(remediation_record)
            self._save_history()
            
            if success:
                issue.remediated = True
                issue.remediated_at = datetime.now().isoformat()
                print("✅ Remediation successful")
            else:
                print(f"❌ Remediation failed: {result.stderr}")
            
            return success
            
        except Exception as e:
            print(f"❌ Remediation error: {e}")
            return False
    
    def auto_heal(self):
        """Automatically scan and remediate issues"""
        print("=" * 70)
        print("SecureOS Self-Healing System - Auto Heal")
        print("=" * 70)
        
        # Scan for issues
        issues = self.scan_system()
        
        if not issues:
            print("\n✅ No security issues detected!")
            return
        
        # Group by severity
        by_severity = {}
        for issue in issues:
            by_severity.setdefault(issue.severity, []).append(issue)
        
        # Display summary
        print("\nIssues detected:")
        for severity in self.SEVERITY_LEVELS:
            if severity in by_severity:
                print(f"  {severity.upper()}: {len(by_severity[severity])}")
        
        # Remediate based on configuration
        min_severity_idx = self.SEVERITY_LEVELS.index(self.config['min_severity_auto'])
        
        remediated = 0
        failed = 0
        
        for issue in issues:
            severity_idx = self.SEVERITY_LEVELS.index(issue.severity)
            
            if severity_idx >= min_severity_idx and self.config['auto_remediate']:
                if self.remediate_issue(issue):
                    remediated += 1
                else:
                    failed += 1
            else:
                print(f"\nSkipping (below threshold): {issue.description}")
        
        # Summary
        print("\n" + "=" * 70)
        print(f"Auto-heal complete:")
        print(f"  Total issues: {len(issues)}")
        print(f"  Remediated: {remediated}")
        print(f"  Failed: {failed}")
        print(f"  Skipped: {len(issues) - remediated - failed}")
        print("=" * 70)
    
    def get_status(self) -> dict:
        """Get self-healing system status"""
        return {
            'enabled': self.config['enabled'],
            'auto_remediate': self.config['auto_remediate'],
            'dry_run': self.config['dry_run'],
            'min_severity_auto': self.config['min_severity_auto'],
            'total_remediations': len(self.remediation_history),
            'last_scan': self.remediation_history[-1]['timestamp'] if self.remediation_history else None
        }


def main():
    parser = argparse.ArgumentParser(description='SecureOS Self-Healing System')
    parser.add_argument('command', choices=['scan', 'heal', 'status', 'history', 'config'])
    parser.add_argument('--auto', action='store_true', help='Enable auto-remediation')
    parser.add_argument('--dry-run', action='store_true', help='Dry run mode')
    parser.add_argument('--severity', type=str, choices=['info', 'low', 'medium', 'high', 'critical'],
                       help='Minimum severity for auto-remediation')
    
    args = parser.parse_args()
    
    engine = SelfHealingEngine()
    
    if args.dry_run:
        engine.config['dry_run'] = True
    
    if args.auto:
        engine.config['auto_remediate'] = True
    
    if args.severity:
        engine.config['min_severity_auto'] = args.severity
    
    if args.command == 'scan':
        issues = engine.scan_system()
        
        if not issues:
            print("✅ No security issues detected!")
        else:
            print(f"\nFound {len(issues)} security issues:\n")
            for issue in issues:
                print(f"[{issue.severity.upper()}] {issue.description}")
                print(f"  Component: {issue.affected_component}")
                print(f"  Action: {issue.remediation_action}\n")
    
    elif args.command == 'heal':
        engine.auto_heal()
    
    elif args.command == 'status':
        status = engine.get_status()
        print(json.dumps(status, indent=2))
    
    elif args.command == 'history':
        print(json.dumps(engine.remediation_history, indent=2))
    
    elif args.command == 'config':
        print(json.dumps(engine.config, indent=2))


if __name__ == '__main__':
    main()
