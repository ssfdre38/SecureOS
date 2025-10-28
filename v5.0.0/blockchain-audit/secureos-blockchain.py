#!/usr/bin/env python3
"""
SecureOS v5.0.0 - Blockchain-Based Audit System
Immutable, tamper-proof security event logging using distributed ledger technology
"""

import sys
import json
import hashlib
import time
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
import sqlite3


@dataclass
class Block:
    """Represents a single block in the audit chain"""
    index: int
    timestamp: str
    events: List[Dict]
    previous_hash: str
    nonce: int = 0
    hash: str = ""
    
    def calculate_hash(self) -> str:
        """Calculate SHA-256 hash of the block"""
        block_data = {
            'index': self.index,
            'timestamp': self.timestamp,
            'events': self.events,
            'previous_hash': self.previous_hash,
            'nonce': self.nonce
        }
        block_string = json.dumps(block_data, sort_keys=True)
        return hashlib.sha256(block_string.encode()).hexdigest()
    
    def mine_block(self, difficulty: int = 4):
        """Proof of work - find hash with leading zeros"""
        target = '0' * difficulty
        while not self.hash.startswith(target):
            self.nonce += 1
            self.hash = self.calculate_hash()


class BlockchainAuditLog:
    """Blockchain-based immutable audit logging system"""
    
    def __init__(self, db_path: str = "/var/lib/secureos/blockchain/audit.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        self.chain: List[Block] = []
        self.pending_events: List[Dict] = []
        self.difficulty = 4  # Mining difficulty
        self.block_size = 100  # Max events per block
        
        # Initialize database
        self._init_database()
        
        # Load existing chain or create genesis block
        self._load_chain()
        if not self.chain:
            self._create_genesis_block()
    
    def _init_database(self):
        """Initialize SQLite database for persistence"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS blocks (
                idx INTEGER PRIMARY KEY,
                timestamp TEXT NOT NULL,
                events_json TEXT NOT NULL,
                previous_hash TEXT NOT NULL,
                nonce INTEGER NOT NULL,
                hash TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS pending_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_json TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_block_hash ON blocks(hash)
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_block_timestamp ON blocks(timestamp)
        ''')
        
        conn.commit()
        conn.close()
    
    def _load_chain(self):
        """Load blockchain from database"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM blocks ORDER BY idx ASC')
        rows = cursor.fetchall()
        
        for row in rows:
            block = Block(
                index=row[0],
                timestamp=row[1],
                events=json.loads(row[2]),
                previous_hash=row[3],
                nonce=row[4],
                hash=row[5]
            )
            self.chain.append(block)
        
        # Load pending events
        cursor.execute('SELECT event_json FROM pending_events')
        for row in cursor.fetchall():
            self.pending_events.append(json.loads(row[0]))
        
        conn.close()
    
    def _create_genesis_block(self):
        """Create the first block in the chain"""
        genesis_block = Block(
            index=0,
            timestamp=datetime.now().isoformat(),
            events=[{
                'type': 'genesis',
                'message': 'SecureOS Blockchain Audit Log Initialized',
                'version': '5.0.0'
            }],
            previous_hash='0'
        )
        genesis_block.mine_block(self.difficulty)
        
        self.chain.append(genesis_block)
        self._save_block(genesis_block)
    
    def _save_block(self, block: Block):
        """Save block to database"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO blocks (idx, timestamp, events_json, previous_hash, nonce, hash)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            block.index,
            block.timestamp,
            json.dumps(block.events),
            block.previous_hash,
            block.nonce,
            block.hash
        ))
        
        conn.commit()
        conn.close()
    
    def add_event(self, event: Dict) -> bool:
        """Add security event to pending events"""
        # Add timestamp if not present
        if 'timestamp' not in event:
            event['timestamp'] = datetime.now().isoformat()
        
        # Add to pending events
        self.pending_events.append(event)
        
        # Save to database
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO pending_events (event_json) VALUES (?)',
            (json.dumps(event),)
        )
        conn.commit()
        conn.close()
        
        # Mine new block if we have enough events
        if len(self.pending_events) >= self.block_size:
            return self.mine_pending_block()
        
        return True
    
    def mine_pending_block(self) -> bool:
        """Mine a new block with pending events"""
        if not self.pending_events:
            return False
        
        # Create new block
        new_block = Block(
            index=len(self.chain),
            timestamp=datetime.now().isoformat(),
            events=self.pending_events[:self.block_size],
            previous_hash=self.chain[-1].hash
        )
        
        # Mine the block (proof of work)
        print(f"Mining block {new_block.index}...")
        start_time = time.time()
        new_block.mine_block(self.difficulty)
        elapsed = time.time() - start_time
        print(f"Block mined in {elapsed:.2f} seconds - Hash: {new_block.hash}")
        
        # Add to chain
        self.chain.append(new_block)
        self._save_block(new_block)
        
        # Clear mined events from pending
        self.pending_events = self.pending_events[self.block_size:]
        
        # Clear from database
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        cursor.execute('DELETE FROM pending_events')
        for event in self.pending_events:
            cursor.execute(
                'INSERT INTO pending_events (event_json) VALUES (?)',
                (json.dumps(event),)
            )
        conn.commit()
        conn.close()
        
        return True
    
    def verify_chain(self) -> bool:
        """Verify integrity of the entire blockchain"""
        for i in range(1, len(self.chain)):
            current_block = self.chain[i]
            previous_block = self.chain[i - 1]
            
            # Verify current block's hash
            if current_block.hash != current_block.calculate_hash():
                print(f"❌ Block {i} has been tampered with!")
                return False
            
            # Verify link to previous block
            if current_block.previous_hash != previous_block.hash:
                print(f"❌ Block {i} has invalid previous hash!")
                return False
            
            # Verify proof of work
            if not current_block.hash.startswith('0' * self.difficulty):
                print(f"❌ Block {i} has invalid proof of work!")
                return False
        
        print(f"✅ Blockchain verified - All {len(self.chain)} blocks are valid")
        return True
    
    def search_events(self, query: Dict) -> List[Dict]:
        """Search for events matching criteria"""
        results = []
        
        for block in self.chain:
            for event in block.events:
                match = True
                for key, value in query.items():
                    if key not in event or event[key] != value:
                        match = False
                        break
                
                if match:
                    results.append({
                        'block_index': block.index,
                        'block_hash': block.hash,
                        'block_timestamp': block.timestamp,
                        'event': event
                    })
        
        return results
    
    def get_events_by_timerange(self, start: str, end: str) -> List[Dict]:
        """Get all events within a time range"""
        results = []
        
        for block in self.chain:
            if start <= block.timestamp <= end:
                for event in block.events:
                    results.append({
                        'block_index': block.index,
                        'block_hash': block.hash,
                        'block_timestamp': block.timestamp,
                        'event': event
                    })
        
        return results
    
    def export_compliance_report(self, start_date: str, end_date: str, output_file: str):
        """Export compliance report for auditing"""
        events = self.get_events_by_timerange(start_date, end_date)
        
        report = {
            'report_type': 'SecureOS Blockchain Audit Compliance Report',
            'generated_at': datetime.now().isoformat(),
            'period_start': start_date,
            'period_end': end_date,
            'total_events': len(events),
            'blockchain_verified': self.verify_chain(),
            'events': events,
            'blockchain_info': {
                'total_blocks': len(self.chain),
                'difficulty': self.difficulty,
                'genesis_hash': self.chain[0].hash if self.chain else None,
                'latest_hash': self.chain[-1].hash if self.chain else None
            }
        }
        
        with open(output_file, 'w') as f:
            json.dumps(report, f, indent=2)
        
        print(f"Compliance report exported to {output_file}")
    
    def get_stats(self) -> Dict:
        """Get blockchain statistics"""
        total_events = sum(len(block.events) for block in self.chain)
        
        return {
            'total_blocks': len(self.chain),
            'total_events': total_events,
            'pending_events': len(self.pending_events),
            'difficulty': self.difficulty,
            'genesis_timestamp': self.chain[0].timestamp if self.chain else None,
            'latest_block_hash': self.chain[-1].hash if self.chain else None,
            'chain_valid': self.verify_chain()
        }


def main():
    parser = argparse.ArgumentParser(description='SecureOS Blockchain Audit System')
    parser.add_argument('command', choices=['init', 'add', 'mine', 'verify', 'search', 'export', 'stats'])
    parser.add_argument('--event', type=str, help='Event JSON data')
    parser.add_argument('--query', type=str, help='Search query JSON')
    parser.add_argument('--start', type=str, help='Start date for time range')
    parser.add_argument('--end', type=str, help='End date for time range')
    parser.add_argument('--output', type=str, help='Output file for export')
    parser.add_argument('--db', type=str, default='/var/lib/secureos/blockchain/audit.db', 
                       help='Database path')
    
    args = parser.parse_args()
    
    # Initialize blockchain
    blockchain = BlockchainAuditLog(db_path=args.db)
    
    if args.command == 'init':
        print("Blockchain audit system initialized")
        print(f"Genesis block: {blockchain.chain[0].hash}")
    
    elif args.command == 'add':
        if not args.event:
            print("Error: --event required")
            sys.exit(1)
        
        event = json.loads(args.event)
        blockchain.add_event(event)
        print(f"Event added. Pending events: {len(blockchain.pending_events)}")
    
    elif args.command == 'mine':
        if blockchain.mine_pending_block():
            print("Block mined successfully")
        else:
            print("No pending events to mine")
    
    elif args.command == 'verify':
        blockchain.verify_chain()
    
    elif args.command == 'search':
        if not args.query:
            print("Error: --query required")
            sys.exit(1)
        
        query = json.loads(args.query)
        results = blockchain.search_events(query)
        print(json.dumps(results, indent=2))
    
    elif args.command == 'export':
        if not args.start or not args.end or not args.output:
            print("Error: --start, --end, and --output required")
            sys.exit(1)
        
        blockchain.export_compliance_report(args.start, args.end, args.output)
    
    elif args.command == 'stats':
        stats = blockchain.get_stats()
        print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    main()
