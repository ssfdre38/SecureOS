#!/usr/bin/env python3
"""
SecureOS v5.0.0 - AI-Powered Threat Detection Engine
Advanced machine learning for real-time security analysis
"""

import sys
import json
import time
import logging
import argparse
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ML Libraries
try:
    import tensorflow as tf
    from sklearn.ensemble import IsolationForest, RandomForestClassifier
    from sklearn.preprocessing import StandardScaler
    import joblib
except ImportError:
    print("Error: ML libraries not installed. Run: pip3 install tensorflow scikit-learn joblib")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('SecureOS-AI')


class ThreatDetectionEngine:
    """Advanced AI-powered threat detection system"""
    
    def __init__(self, model_path: str = "/var/lib/secureos/ai/models"):
        self.model_path = Path(model_path)
        self.model_path.mkdir(parents=True, exist_ok=True)
        
        # Models
        self.anomaly_detector = None
        self.threat_classifier = None
        self.scaler = StandardScaler()
        
        # Configuration
        self.config = {
            'confidence_threshold': 0.85,
            'anomaly_threshold': -0.5,
            'learning_enabled': False,
            'auto_response': False
        }
        
        # Threat categories based on MITRE ATT&CK
        self.threat_categories = [
            'reconnaissance',
            'initial_access',
            'execution',
            'persistence',
            'privilege_escalation',
            'defense_evasion',
            'credential_access',
            'discovery',
            'lateral_movement',
            'collection',
            'exfiltration',
            'command_control',
            'impact',
            'benign'
        ]
        
        logger.info(f"AI Threat Detection Engine initialized - Model path: {self.model_path}")
    
    def load_models(self) -> bool:
        """Load pre-trained ML models"""
        try:
            # Load anomaly detection model
            anomaly_model_file = self.model_path / "anomaly_detector.pkl"
            if anomaly_model_file.exists():
                self.anomaly_detector = joblib.load(anomaly_model_file)
                logger.info("Anomaly detector model loaded")
            else:
                logger.warning("Anomaly detector not found, initializing new model")
                self.anomaly_detector = IsolationForest(
                    contamination=0.1,
                    random_state=42,
                    n_estimators=100
                )
            
            # Load threat classifier
            classifier_model_file = self.model_path / "threat_classifier.pkl"
            if classifier_model_file.exists():
                self.threat_classifier = joblib.load(classifier_model_file)
                logger.info("Threat classifier model loaded")
            else:
                logger.warning("Threat classifier not found, initializing new model")
                self.threat_classifier = RandomForestClassifier(
                    n_estimators=200,
                    max_depth=20,
                    random_state=42,
                    n_jobs=-1
                )
            
            # Load scaler
            scaler_file = self.model_path / "scaler.pkl"
            if scaler_file.exists():
                self.scaler = joblib.load(scaler_file)
                logger.info("Feature scaler loaded")
            
            return True
            
        except Exception as e:
            logger.error(f"Error loading models: {e}")
            return False
    
    def save_models(self) -> bool:
        """Save trained models to disk"""
        try:
            if self.anomaly_detector:
                joblib.dump(self.anomaly_detector, self.model_path / "anomaly_detector.pkl")
            
            if self.threat_classifier:
                joblib.dump(self.threat_classifier, self.model_path / "threat_classifier.pkl")
            
            joblib.dump(self.scaler, self.model_path / "scaler.pkl")
            
            logger.info("Models saved successfully")
            return True
            
        except Exception as e:
            logger.error(f"Error saving models: {e}")
            return False
    
    def extract_features(self, event: Dict) -> np.ndarray:
        """Extract feature vector from security event"""
        features = []
        
        # System call features
        features.append(event.get('syscall_count', 0))
        features.append(event.get('file_operations', 0))
        features.append(event.get('network_connections', 0))
        features.append(event.get('process_spawns', 0))
        
        # Network features
        features.append(event.get('bytes_sent', 0))
        features.append(event.get('bytes_received', 0))
        features.append(event.get('unique_ips', 0))
        features.append(event.get('failed_connections', 0))
        
        # Process features
        features.append(event.get('cpu_usage', 0.0))
        features.append(event.get('memory_usage', 0.0))
        features.append(event.get('child_processes', 0))
        features.append(1 if event.get('elevated_privileges', False) else 0)
        
        # File system features
        features.append(event.get('files_created', 0))
        features.append(event.get('files_modified', 0))
        features.append(event.get('files_deleted', 0))
        features.append(event.get('registry_changes', 0))
        
        # Time-based features
        hour = datetime.now().hour
        features.append(hour)
        features.append(1 if 22 <= hour or hour <= 6 else 0)  # Night time flag
        
        # Behavioral features
        features.append(event.get('suspicious_strings', 0))
        features.append(event.get('encryption_operations', 0))
        features.append(event.get('lateral_movement_indicators', 0))
        features.append(event.get('persistence_indicators', 0))
        
        return np.array(features).reshape(1, -1)
    
    def detect_anomaly(self, features: np.ndarray) -> Tuple[bool, float]:
        """Detect if behavior is anomalous"""
        if self.anomaly_detector is None:
            return False, 0.0
        
        try:
            # Scale features
            features_scaled = self.scaler.transform(features)
            
            # Predict (-1 for anomaly, 1 for normal)
            prediction = self.anomaly_detector.predict(features_scaled)[0]
            
            # Get anomaly score
            score = self.anomaly_detector.score_samples(features_scaled)[0]
            
            is_anomalous = prediction == -1 or score < self.config['anomaly_threshold']
            
            return is_anomalous, float(score)
            
        except Exception as e:
            logger.error(f"Anomaly detection error: {e}")
            return False, 0.0
    
    def classify_threat(self, features: np.ndarray) -> Tuple[str, float]:
        """Classify the type of threat"""
        if self.threat_classifier is None:
            return 'unknown', 0.0
        
        try:
            # Scale features
            features_scaled = self.scaler.transform(features)
            
            # Get prediction probabilities
            probabilities = self.threat_classifier.predict_proba(features_scaled)[0]
            
            # Get highest confidence prediction
            max_idx = np.argmax(probabilities)
            threat_type = self.threat_categories[max_idx]
            confidence = probabilities[max_idx]
            
            return threat_type, float(confidence)
            
        except Exception as e:
            logger.error(f"Threat classification error: {e}")
            return 'unknown', 0.0
    
    def analyze_event(self, event: Dict) -> Dict:
        """Analyze security event for threats"""
        # Extract features
        features = self.extract_features(event)
        
        # Detect anomaly
        is_anomalous, anomaly_score = self.detect_anomaly(features)
        
        # Classify threat if anomalous
        threat_type = 'benign'
        confidence = 1.0
        
        if is_anomalous:
            threat_type, confidence = self.classify_threat(features)
        
        # Determine severity
        severity = self._calculate_severity(is_anomalous, anomaly_score, confidence)
        
        # Create analysis result
        result = {
            'timestamp': datetime.now().isoformat(),
            'event_id': event.get('id', 'unknown'),
            'is_threat': is_anomalous and confidence >= self.config['confidence_threshold'],
            'anomaly_score': anomaly_score,
            'threat_type': threat_type,
            'confidence': confidence,
            'severity': severity,
            'features': features.tolist()[0],
            'recommended_action': self._recommend_action(is_anomalous, threat_type, confidence)
        }
        
        # Log high-confidence threats
        if result['is_threat'] and confidence >= 0.9:
            logger.warning(f"High-confidence threat detected: {threat_type} (confidence: {confidence:.2f})")
        
        return result
    
    def _calculate_severity(self, is_anomalous: bool, anomaly_score: float, confidence: float) -> str:
        """Calculate threat severity level"""
        if not is_anomalous:
            return 'info'
        
        if confidence >= 0.95 and anomaly_score < -0.7:
            return 'critical'
        elif confidence >= 0.85:
            return 'high'
        elif confidence >= 0.70:
            return 'medium'
        else:
            return 'low'
    
    def _recommend_action(self, is_anomalous: bool, threat_type: str, confidence: float) -> str:
        """Recommend response action"""
        if not is_anomalous:
            return 'monitor'
        
        high_risk_threats = ['execution', 'persistence', 'credential_access', 'exfiltration', 'impact']
        
        if confidence >= 0.95 and threat_type in high_risk_threats:
            return 'block_and_isolate'
        elif confidence >= 0.85:
            return 'block'
        elif confidence >= 0.70:
            return 'alert'
        else:
            return 'monitor'
    
    def train(self, training_data: List[Dict], labels: Optional[List[str]] = None):
        """Train models on historical data"""
        logger.info(f"Training AI models on {len(training_data)} samples...")
        
        # Extract features from all events
        X = np.vstack([self.extract_features(event) for event in training_data])
        
        # Fit scaler
        self.scaler.fit(X)
        X_scaled = self.scaler.transform(X)
        
        # Train anomaly detector (unsupervised)
        logger.info("Training anomaly detector...")
        self.anomaly_detector.fit(X_scaled)
        
        # Train threat classifier if labels provided
        if labels and self.threat_classifier:
            logger.info("Training threat classifier...")
            y = np.array([self.threat_categories.index(label) for label in labels])
            self.threat_classifier.fit(X_scaled, y)
        
        # Save models
        self.save_models()
        logger.info("Training complete!")
    
    def get_status(self) -> Dict:
        """Get engine status"""
        return {
            'engine': 'SecureOS AI Threat Detection',
            'version': '5.0.0',
            'status': 'active',
            'models_loaded': {
                'anomaly_detector': self.anomaly_detector is not None,
                'threat_classifier': self.threat_classifier is not None
            },
            'config': self.config,
            'threat_categories': len(self.threat_categories)
        }


def main():
    parser = argparse.ArgumentParser(description='SecureOS AI Threat Detection Engine')
    parser.add_argument('command', choices=['status', 'analyze', 'train', 'test', 'benchmark'])
    parser.add_argument('--event', type=str, help='JSON event data for analysis')
    parser.add_argument('--dataset', type=str, help='Training dataset path')
    parser.add_argument('--auto-response', action='store_true', help='Enable automatic response')
    parser.add_argument('--threshold', type=float, default=0.85, help='Confidence threshold')
    
    args = parser.parse_args()
    
    # Initialize engine
    engine = ThreatDetectionEngine()
    engine.load_models()
    
    if args.threshold:
        engine.config['confidence_threshold'] = args.threshold
    
    if args.auto_response:
        engine.config['auto_response'] = True
    
    # Execute command
    if args.command == 'status':
        status = engine.get_status()
        print(json.dumps(status, indent=2))
    
    elif args.command == 'analyze':
        if not args.event:
            print("Error: --event required for analyze command")
            sys.exit(1)
        
        event = json.loads(args.event)
        result = engine.analyze_event(event)
        print(json.dumps(result, indent=2))
    
    elif args.command == 'train':
        if not args.dataset:
            print("Error: --dataset required for train command")
            sys.exit(1)
        
        # Load training data
        with open(args.dataset, 'r') as f:
            data = json.load(f)
        
        training_data = data.get('events', [])
        labels = data.get('labels', None)
        
        engine.train(training_data, labels)
        print("Training completed successfully!")
    
    elif args.command == 'test':
        # Run tests on sample data
        print("Running AI engine tests...")
        test_event = {
            'id': 'test-001',
            'syscall_count': 150,
            'file_operations': 25,
            'network_connections': 5,
            'process_spawns': 3,
            'bytes_sent': 10240,
            'bytes_received': 5120,
            'unique_ips': 2,
            'failed_connections': 0,
            'cpu_usage': 15.5,
            'memory_usage': 25.3,
            'child_processes': 2,
            'elevated_privileges': False,
            'files_created': 3,
            'files_modified': 8,
            'files_deleted': 1,
            'registry_changes': 0,
            'suspicious_strings': 0,
            'encryption_operations': 0,
            'lateral_movement_indicators': 0,
            'persistence_indicators': 0
        }
        
        result = engine.analyze_event(test_event)
        print("\nTest Result:")
        print(json.dumps(result, indent=2))
    
    elif args.command == 'benchmark':
        print("Running AI engine benchmark...")
        start_time = time.time()
        
        # Generate test events
        num_events = 1000
        for i in range(num_events):
            test_event = {
                'id': f'bench-{i}',
                'syscall_count': np.random.randint(50, 200),
                'file_operations': np.random.randint(0, 50),
                'network_connections': np.random.randint(0, 20),
                'process_spawns': np.random.randint(0, 10),
                'bytes_sent': np.random.randint(0, 100000),
                'bytes_received': np.random.randint(0, 100000),
                'unique_ips': np.random.randint(0, 10),
                'failed_connections': np.random.randint(0, 5),
                'cpu_usage': np.random.uniform(0, 100),
                'memory_usage': np.random.uniform(0, 100),
                'child_processes': np.random.randint(0, 5),
                'elevated_privileges': np.random.choice([True, False]),
                'files_created': np.random.randint(0, 10),
                'files_modified': np.random.randint(0, 20),
                'files_deleted': np.random.randint(0, 5),
                'registry_changes': np.random.randint(0, 10),
                'suspicious_strings': np.random.randint(0, 3),
                'encryption_operations': np.random.randint(0, 5),
                'lateral_movement_indicators': np.random.randint(0, 2),
                'persistence_indicators': np.random.randint(0, 2)
            }
            engine.analyze_event(test_event)
        
        elapsed = time.time() - start_time
        events_per_sec = num_events / elapsed
        
        print(f"\nBenchmark Results:")
        print(f"  Events processed: {num_events}")
        print(f"  Time elapsed: {elapsed:.2f} seconds")
        print(f"  Throughput: {events_per_sec:.2f} events/second")
        print(f"  Average latency: {(elapsed/num_events)*1000:.2f} ms/event")


if __name__ == '__main__':
    main()
