#!/usr/bin/env python3
"""
Tdarr Mock License Server
Emulates api.tdarr.io endpoints for development/testing
Returns success for all license validation requests
"""

from flask import Flask, request, jsonify
import logging
import os
from OpenSSL import crypto

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def generate_self_signed_cert():
    """
    Generate self-signed certificate on startup if not exists
    Returns paths to certificate and key files
    """
    cert_file = '/tmp/server.crt'
    key_file = '/tmp/server.key'

    if os.path.exists(cert_file) and os.path.exists(key_file):
        logger.info("Using existing self-signed certificate")
        return cert_file, key_file

    logger.info("Generating new self-signed certificate for api.tdarr.io")

    # Create key pair
    k = crypto.PKey()
    k.generate_key(crypto.TYPE_RSA, 2048)

    # Create self-signed cert
    cert = crypto.X509()
    cert.get_subject().CN = "api.tdarr.io"
    cert.set_serial_number(1000)
    cert.gmtime_adj_notBefore(0)
    cert.gmtime_adj_notAfter(10*365*24*60*60)  # 10 years validity
    cert.set_issuer(cert.get_subject())
    cert.set_pubkey(k)
    cert.sign(k, 'sha256')

    # Write certificate file
    with open(cert_file, "wb") as f:
        f.write(crypto.dump_certificate(crypto.FILETYPE_PEM, cert))

    # Write key file
    with open(key_file, "wb") as f:
        f.write(crypto.dump_privatekey(crypto.FILETYPE_PEM, k))

    logger.info(f"Certificate generated: {cert_file}")
    return cert_file, key_file

@app.route('/api/v2/verify-key', methods=['POST'])
def verify_key():
    """
    License key verification endpoint
    Returns success for any GUID/key
    """
    data = request.get_json()
    tdarr_key = data.get('tdarrKey', 'unknown')

    logger.info(f"License verification request for key: {tdarr_key[:8]}...")

    # Return just the boolean true as the response body
    # Tdarr checks: c.status === 200 && c.data === true
    return jsonify(True), 200

@app.route('/api/v2/user-stats/update', methods=['POST'])
def update_stats():
    """
    User statistics update endpoint
    Accepts stats but does nothing with them
    """
    data = request.get_json()
    tdarr_key = data.get('tdarrKey', 'unknown')
    server_id = data.get('serverId', 'unknown')

    logger.info(f"Stats update from server {server_id[:8]}...")

    return jsonify({
        'result': True,
        'message': 'Statistics updated (mock server)'
    }), 200

@app.route('/api/v2/user-stats/push-notif', methods=['POST'])
def push_notification():
    """
    Push notification endpoint
    Logs notification but doesn't actually send anything
    """
    data = request.get_json()
    tdarr_key = data.get('tdarrKey', 'unknown')
    message = data.get('message', 'No message')

    logger.info(f"Push notification: {message}")

    return jsonify({
        'result': True,
        'message': 'Notification sent (mock server)'
    }), 200

@app.route('/api/v2/updater-config', methods=['GET'])
def updater_config():
    """
    Auto-updater configuration endpoint
    Returns empty config to prevent auto-updates
    """
    logger.info("Updater config requested")

    return jsonify({
        'pkgIndex': '',
        'url': '',
        'message': 'Auto-update disabled (mock server)'
    }), 200

@app.route('/api/v2/download-plugins', methods=['GET'])
def download_plugins():
    """
    Plugin download endpoint
    Returns empty response to prevent plugin overwriting during development
    """
    logger.info("Plugin download requested (skipped in mock server)")

    # Return empty response to skip plugin download
    # This prevents overwriting local plugin development
    return b'', 200

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'server': 'mock-license-server'}), 200

@app.route('/', methods=['GET'])
def root():
    """Root endpoint for verification"""
    return jsonify({
        'server': 'Tdarr Mock License Server',
        'status': 'running',
        'endpoints': [
            'POST /api/v2/verify-key',
            'POST /api/v2/user-stats/update',
            'POST /api/v2/user-stats/push-notif',
            'GET /api/v2/updater-config',
            'GET /api/v2/download-plugins'
        ]
    }), 200

if __name__ == '__main__':
    cert_file, key_file = generate_self_signed_cert()
    logger.info("Starting Tdarr Mock License Server on port 443 (HTTPS)")
    app.run(host='0.0.0.0', port=443, ssl_context=(cert_file, key_file), debug=True)