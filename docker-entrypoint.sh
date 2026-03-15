#!/bin/sh
# Auto-generate config.json from environment variables if it doesn't exist.
# This allows Paperclip to run on Railway (or any cloud host) without a persistent volume
# for the config file, while still using an external PostgreSQL database.
set -e

CONFIG_DIR="/paperclip/instances/default"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[entrypoint] Generating config.json from environment variables..."

  # Use node to safely build JSON (avoids shell quoting and escaping issues)
  node -e "
const fs = require('fs');
const dir = '/paperclip/instances/default';

const config = {
  '\$meta': { version: 1, updatedAt: new Date().toISOString(), source: 'env' },
  database: {
    mode: 'postgres',
    connectionString: process.env.DATABASE_URL,
    backup: { enabled: false }
  },
  logging: { mode: 'file', logDir: dir + '/logs' },
  server: {
    deploymentMode: process.env.PAPERCLIP_DEPLOYMENT_MODE || 'authenticated',
    exposure: process.env.PAPERCLIP_DEPLOYMENT_EXPOSURE || 'public',
    host: process.env.HOST || '0.0.0.0',
    port: Number(process.env.PORT) || 3100,
    allowedHostnames: (process.env.PAPERCLIP_ALLOWED_HOSTNAMES || '')
      .split(',').map(h => h.trim()).filter(Boolean),
    serveUi: process.env.SERVE_UI !== 'false'
  },
  auth: {
    baseUrlMode: 'explicit',
    publicBaseUrl: process.env.PAPERCLIP_PUBLIC_URL,
    disableSignUp: process.env.PAPERCLIP_AUTH_DISABLE_SIGN_UP === 'true'
  },
  storage: {
    provider: 'local_disk',
    localDisk: { baseDir: dir + '/storage' }
  },
  secrets: {
    provider: 'local_encrypted',
    strictMode: false,
    localEncrypted: { keyFilePath: dir + '/secrets.key' }
  }
};

fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(dir + '/config.json', JSON.stringify(config, null, 2));
console.log('[entrypoint] config.json generated from env vars.');
"
else
  echo "[entrypoint] config.json already exists, skipping generation."
fi

# Hand off to the Paperclip server
exec node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
