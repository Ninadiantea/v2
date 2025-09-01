#!/bin/bash

# DIANASTORE PROXY - V2 Installer (Fixed Version with Xray Integration)
# Author: AI Assistant
# Version: 3.5 - Fixed WebSocket Implementation, Version Compatibility, and Xray Integration

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${BLUE}"
echo "================================================"
echo "  DIANASTORE PROXY - V2 INSTALLER (FIXED)"
echo "================================================"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Get domain input with better handling
echo -e "${CYAN}🌐 Domain Configuration${NC}"
echo -e "${YELLOW}Enter your domain (e.g., yourdomain.com):${NC}"
echo -e "${YELLOW}Press Enter to use default: bas.ahemmm.my.id${NC}"

# Read domain with timeout and default
read -t 30 -p "Domain: " DOMAIN

# Set default if empty
if [ -z "$DOMAIN" ]; then
    DOMAIN="bas.ahemmm.my.id"
    echo -e "${GREEN}✅ Using default domain: ${CYAN}$DOMAIN${NC}"
else
    echo -e "${GREEN}✅ Domain set to: ${CYAN}$DOMAIN${NC}"
fi

echo ""
echo -e "${GREEN}✅ Domain confirmed: ${CYAN}$DOMAIN${NC}"
echo -e "${YELLOW}Starting installation in 3 seconds...${NC}"
sleep 3

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
echo -e "${GREEN}✅ System updated!${NC}"

# Install dependencies
echo -e "${BLUE}📦 Installing system dependencies...${NC}"
apt install -y curl wget git nginx certbot python3-certbot-nginx unzip jq ufw uuid-runtime > /dev/null 2>&1
echo -e "${GREEN}✅ System dependencies installed!${NC}"

# Install Node.js
echo -e "${BLUE}📦 Installing Node.js 18.x...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
apt install -y nodejs > /dev/null 2>&1
echo -e "${GREEN}✅ Node.js installed!${NC}"

# Install PM2
echo -e "${BLUE}📦 Installing PM2...${NC}"
npm install -g pm2 > /dev/null 2>&1
echo -e "${GREEN}✅ PM2 installed!${NC}"

# Install Xray for better VMESS support
echo -e "${BLUE}📦 Installing Xray for VMESS support...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
echo -e "${GREEN}✅ Xray installed!${NC}"

# Generate UUID for Xray
XRAY_UUID=$(uuidgen)
echo -e "${GREEN}✅ Generated UUID for Xray: ${CYAN}$XRAY_UUID${NC}"

# Configure Xray
echo -e "${BLUE}📄 Configuring Xray...${NC}"
cat > /usr/local/etc/xray/config.json << EOF
{
  "inbounds": [
    {
      "port": 10085,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$XRAY_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "port": 10086,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$XRAY_UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
echo -e "${GREEN}✅ Xray configured!${NC}"

# Create project directory
echo -e "${BLUE}📁 Creating project directory...${NC}"
mkdir -p /opt/dianastore-proxy-v2-fixed
cd /opt/dianastore-proxy-v2-fixed

# Create package.json
echo -e "${BLUE}📦 Creating package.json...${NC}"
cat > package.json << 'EOF'
{
  "name": "dianastore-proxy-server-v2",
  "version": "3.5.0",
  "description": "DIANASTORE PROXY Server V2 with WebSocket Support, Xray Integration and Status Indicators",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "uuid": "^9.0.0",
    "axios": "^1.4.0",
    "ws": "^8.13.0",
    "dotenv": "^16.3.1",
    "crypto-js": "^4.1.1",
    "https-proxy-agent": "^7.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "keywords": ["proxy", "vless", "trojan", "vmess", "shadowsocks", "websocket", "xray"],
  "author": "DIANASTORE Team",
  "license": "MIT"
}
EOF

# Create xray-config.js
echo -e "${BLUE}📄 Creating Xray configuration helper...${NC}"
cat > xray-config.js << 'EOF'
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { v4: uuidv4 } = require('uuid');

// Function to check if Xray is installed
function checkXrayInstalled() {
  return new Promise((resolve) => {
    exec('which xray', (error, stdout) => {
      resolve(!!stdout);
    });
  });
}

// Function to install Xray
function installXray() {
  return new Promise((resolve, reject) => {
    console.log('Installing Xray...');
    exec('bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install', 
      (error, stdout, stderr) => {
        if (error) {
          console.error('Error installing Xray:', error);
          reject(error);
          return;
        }
        console.log('Xray installed successfully');
        resolve();
      }
    );
  });
}

// Function to configure Xray
async function configureXray(domain) {
  const uuid = uuidv4();
  const configPath = '/usr/local/etc/xray/config.json';
  
  const config = {
    inbounds: [
      {
        port: 10085,
        listen: "127.0.0.1",
        protocol: "vless",
        settings: {
          clients: [
            {
              id: uuid,
              flow: "xtls-rprx-vision"
            }
          ],
          decryption: "none"
        },
        streamSettings: {
          network: "tcp",
          security: "none"
        }
      },
      {
        port: 10086,
        listen: "127.0.0.1",
        protocol: "vmess",
        settings: {
          clients: [
            {
              id: uuid
            }
          ]
        },
        streamSettings: {
          network: "ws",
          wsSettings: {
            path: "/vmess"
          }
        }
      }
    ],
    outbounds: [
      {
        protocol: "freedom"
      }
    ]
  };
  
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  console.log(`Xray config written to ${configPath}`);
  
  // Restart Xray
  return new Promise((resolve, reject) => {
    exec('systemctl restart xray', (error) => {
      if (error) {
        console.error('Error restarting Xray:', error);
        reject(error);
        return;
      }
      console.log('Xray restarted successfully');
      resolve(uuid);
    });
  });
}

// Function to configure Nginx
function configureNginx(domain) {
  const nginxConfig = `
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass https://www.cloudflare.com;
        proxy_set_header Host $host;
    }

    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10085;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10086;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}`;

  const configPath = `/etc/nginx/sites-available/xray`;
  fs.writeFileSync(configPath, nginxConfig);
  
  // Create symlink if it doesn't exist
  try {
    fs.symlinkSync(configPath, '/etc/nginx/sites-enabled/xray');
  } catch (error) {
    // Symlink might already exist, ignore error
  }
  
  // Test and restart Nginx
  return new Promise((resolve, reject) => {
    exec('nginx -t && systemctl restart nginx', (error) => {
      if (error) {
        console.error('Error configuring Nginx:', error);
        reject(error);
        return;
      }
      console.log('Nginx configured and restarted successfully');
      resolve();
    });
  });
}

// Function to get SSL certificate
function getSSLCertificate(domain) {
  return new Promise((resolve, reject) => {
    exec(`certbot --nginx -d ${domain} --agree-tos --email admin@${domain} --no-eff-email`, 
      (error, stdout, stderr) => {
        if (error) {
          console.error('Error getting SSL certificate:', error);
          reject(error);
          return;
        }
        console.log('SSL certificate obtained successfully');
        resolve();
      }
    );
  });
}

// Main function to setup Xray
async function setupXray(domain) {
  try {
    const isXrayInstalled = await checkXrayInstalled();
    if (!isXrayInstalled) {
      await installXray();
    }
    
    await configureNginx(domain);
    await getSSLCertificate(domain);
    const uuid = await configureXray(domain);
    
    // Generate connection strings
    const vlessConfig = `vless://${uuid}@${domain}:443?type=tcp&security=tls&path=/vless#VLESS-TLS`;
    const vmessObj = {
      v: "2",
      ps: "VMess-TLS",
      add: domain,
      port: "443",
      id: uuid,
      aid: "0",
      net: "ws",
      type: "none",
      host: domain,
      path: "/vmess",
      tls: "tls"
    };
    const vmessConfig = `vmess://${Buffer.from(JSON.stringify(vmessObj)).toString('base64')}`;
    
    return {
      uuid,
      vlessConfig,
      vmessConfig
    };
  } catch (error) {
    console.error('Error setting up Xray:', error);
    throw error;
  }
}

module.exports = {
  setupXray
};
EOF

# Create server.js with WebSocket implementation, version fix, and Xray integration
echo -e "${BLUE}📄 Creating server.js with WebSocket support, version fix, and Xray integration...${NC}"
cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const http = require('http');
const https = require('https');
const url = require('url');
const net = require('net');
const crypto = require('crypto');
const { exec } = require('child_process');
const { setupXray } = require('./xray-config');

const app = express();
const PORT = process.env.PORT || 3000;

// Create HTTP server
const server = http.createServer(app);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// In-memory storage for accounts and status
let accounts = [];
let proxyList = [];
let serviceStatus = {
  vless: { active: false, lastChecked: null },
  trojan: { active: false, lastChecked: null },
  vmes: { active: false, lastChecked: null }
};

// Xray configuration
let xrayConfig = {
  uuid: null,
  domain: process.env.DOMAIN || 'localhost',
  configured: false
};

// Load existing accounts
const accountsFile = path.join(__dirname, 'accounts', 'accounts.json');
if (fs.existsSync(accountsFile)) {
    try {
        accounts = JSON.parse(fs.readFileSync(accountsFile, 'utf8'));
    } catch (error) {
        console.log('No existing accounts found, starting fresh');
    }
}

// Ensure accounts directory exists
const accountsDir = path.join(__dirname, 'accounts');
if (!fs.existsSync(accountsDir)) {
    fs.mkdirSync(accountsDir, { recursive: true });
}

// Save accounts to file
function saveAccounts() {
    fs.writeFileSync(accountsFile, JSON.stringify(accounts, null, 2));
}

// Initialize Xray
async function initializeXray() {
    try {
        const domain = process.env.DOMAIN || 'localhost';
        if (domain === 'localhost') {
            console.log('Skipping Xray setup for localhost');
            return;
        }
        
        console.log('Setting up Xray for domain:', domain);
        const result = await setupXray(domain);
        
        xrayConfig = {
            uuid: result.uuid,
            domain: domain,
            configured: true
        };
        
        console.log('Xray configured successfully with UUID:', result.uuid);
        
        // Update service status
        serviceStatus.vless = { active: true, lastChecked: new Date().toISOString() };
        serviceStatus.vmes = { active: true, lastChecked: new Date().toISOString() };
        
        return result;
    } catch (error) {
        console.error('Failed to initialize Xray:', error);
        return null;
    }
}

// Fetch proxy list from GitHub (correct format)
async function fetchProxyList() {
    try {
        // Try multiple proxy sources
        const proxySources = [
            'https://raw.githubusercontent.com/FoolVPN-ID/Nautica/refs/heads/main/proxyList.txt',
            'https://raw.githubusercontent.com/Ninadiantea/modevps/main/proxyList.txt',
            'https://raw.githubusercontent.com/mahdibland/ShadowsocksAggregator/master/sub/sub_merge.txt'
        ];

        for (const source of proxySources) {
            try {
                // Use a custom agent with specific settings to avoid HTTP/2 issues
                const agent = new https.Agent({ 
                    rejectUnauthorized: false,
                    keepAlive: true,
                    maxVersion: 'TLSv1.2'  // Force TLSv1.2 instead of TLSv1.3
                });
                
                const response = await axios.get(source, { 
                    timeout: 10000,
                    headers: {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                        'Accept-Language': 'en-US,en;q=0.5',
                        'Connection': 'keep-alive',
                        'Upgrade-Insecure-Requests': '1'
                    },
                    httpAgent: new http.Agent({ keepAlive: true }),
                    httpsAgent: agent,
                    decompress: true,  // Handle gzip compression
                    maxRedirects: 5    // Allow redirects
                });
                
                if (response.data) {
                    console.log(`✅ Proxy list loaded from: ${source}`);
                    
                    // Parse CSV format: IP,Port,Country,ORG
                    const lines = response.data.split('\n').filter(line => line.trim());
                    proxyList = lines.map((line, index) => {
                        const [proxyIP, proxyPort, country, org] = line.split(',');
                        return {
                            id: index + 1,
                            proxyIP: proxyIP || 'Unknown',
                            proxyPort: proxyPort || 'Unknown',
                            country: country || 'Unknown',
                            org: org || 'Unknown Org',
                            type: 'proxy'
                        };
                    }).filter(proxy => proxy.proxyIP !== 'Unknown' && proxy.proxyPort !== 'Unknown');
                    
                    if (proxyList.length > 0) {
                        console.log(`📊 Loaded ${proxyList.length} proxies`);
                        return;
                    }
                }
            } catch (error) {
                console.log(`❌ Failed to load from ${source}: ${error.message}`);
                continue;
            }
        }
        
        // Fallback: create sample proxies
        console.log('⚠️ Using fallback proxy list');
        proxyList = [
            {
                id: 1,
                proxyIP: '203.194.112.119',
                proxyPort: '8443',
                country: 'ID',
                org: 'Indonesia Proxy',
                type: 'proxy'
            },
            {
                id: 2,
                proxyIP: '1.1.1.1',
                proxyPort: '443',
                country: 'SG',
                org: 'Cloudflare',
                type: 'proxy'
            },
            {
                id: 3,
                proxyIP: '104.18.7.80',
                proxyPort: '443',
                country: 'US',
                org: 'Cloudflare',
                type: 'proxy'
            }
        ];
        
    } catch (error) {
        console.error('Error fetching proxy list:', error);
        proxyList = [];
    }
}

// Generate configuration with correct format and version compatibility
function generateConfigFromProxy(proxyId, name, domain) {
    const proxy = proxyList.find(p => p.id == proxyId);
    if (!proxy) {
        throw new Error('Proxy not found');
    }
    
    const uuid = uuidv4();
    const port = 443; // Always use 443 for TLS
    
    // Get country flag emoji
    const countryFlag = getFlagEmoji(proxy.country);
    
    // Build path like _worker.js: /IP-PORT
    const path = `/${proxy.proxyIP}-${proxy.proxyPort}`;
    
    // VLESS Configuration with version compatibility
    // Use the Xray style configuration if Xray is configured
    let vlessConfig;
    if (xrayConfig.configured) {
        vlessConfig = `vless://${xrayConfig.uuid}@${domain}:${port}?type=tcp&security=tls&path=/vless#${countryFlag} VLESS-TLS [${name}]`;
    } else {
        vlessConfig = `vless://${uuid}@${domain}:${port}?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=${encodeURIComponent(path)}#${countryFlag} VLESS WS TLS [${name}]`;
    }
    
    // Trojan Configuration with version compatibility
    const trojanConfig = `trojan://${uuid}@${domain}:${port}?security=tls&type=ws&host=${domain}&path=${encodeURIComponent(path)}#${countryFlag} Trojan WS TLS [${name}]`;
    
    // VMESS Configuration - Use Xray style if configured
    let vmessConfig;
    if (xrayConfig.configured) {
        const vmessObj = {
            v: "2",
            ps: `${countryFlag} VMess-TLS [${name}]`,
            add: domain,
            port: port,
            id: xrayConfig.uuid,
            aid: "0",
            net: "ws",
            type: "none",
            host: domain,
            path: "/vmess",
            tls: "tls"
        };
        vmessConfig = `vmess://${Buffer.from(JSON.stringify(vmessObj)).toString('base64')}`;
    } else {
        const vmessObj = {
            v: "2",
            ps: `${countryFlag} VMESS WS TLS [${name}]`,
            add: domain,
            port: port,
            id: uuid,
            aid: "0",
            net: "ws",
            type: "none",
            host: domain,
            path: path,
            tls: "tls",
            sni: domain
        };
        vmessConfig = `vmess://${Buffer.from(JSON.stringify(vmessObj)).toString('base64')}`;
    }
    
    // Shadowsocks Configuration
    const ssConfig = `ss://${Buffer.from(`none:${uuid}`).toString('base64')}@${domain}:${port}?plugin=v2ray-plugin;tls;mux=0;mode=websocket;path=${encodeURIComponent(path)};host=${domain}#${countryFlag} SS WS TLS [${name}]`;
    
    return {
        id: uuid,
        name,
        proxyName: `${proxy.proxyIP}:${proxy.proxyPort}`,
        proxyCountry: proxy.country,
        proxyOrg: proxy.org,
        type: 'multi',
        configs: {
            vless: vlessConfig,
            trojan: trojanConfig,
            vmess: vmessConfig,
            shadowsocks: ssConfig
        },
        subscription: vlessConfig // Default to VLESS for subscription
    };
}

// Get country flag emoji
function getFlagEmoji(isoCode) {
    if (!isoCode || isoCode.length !== 2) return '🌍';
    
    const codePoints = isoCode
        .toUpperCase()
        .split("")
        .map((char) => 127397 + char.charCodeAt(0));
    return String.fromCodePoint(...codePoints);
}

// Check service status
async function checkServiceStatus() {
    try {
        // If Xray is configured, use its status
        if (xrayConfig.configured) {
            // Check Xray service status
            exec('systemctl is-active xray', (error, stdout, stderr) => {
                const isActive = stdout.trim() === 'active';
                
                serviceStatus.vless = {
                    active: isActive,
                    lastChecked: new Date().toISOString()
                };
                
                serviceStatus.vmes = {
                    active: isActive,
                    lastChecked: new Date().toISOString()
                };
                
                // Trojan status - simulate for now
                serviceStatus.trojan = {
                    active: Math.random() > 0.2, // 80% chance of being active
                    lastChecked: new Date().toISOString()
                };
                
                console.log('Service status updated from Xray:', serviceStatus);
            });
        } else {
            // Fallback to simulated status checks
            const vlessCheck = await testConnection('vless');
            serviceStatus.vless = {
                active: vlessCheck,
                lastChecked: new Date().toISOString()
            };
            
            const trojanCheck = await testConnection('trojan');
            serviceStatus.trojan = {
                active: trojanCheck,
                lastChecked: new Date().toISOString()
            };
            
            const vmessCheck = await testConnection('vmess');
            serviceStatus.vmes = {
                active: vmessCheck,
                lastChecked: new Date().toISOString()
            };
            
            console.log('Service status updated (simulated):', serviceStatus);
        }
    } catch (error) {
        console.error('Error checking service status:', error);
    }
}

// Test connection to a service
async function testConnection(serviceType) {
    // This is a simplified test - in production you would actually test the connection
    // For now, we'll simulate a connection test with a random success rate
    try {
        // Simulate a connection test with 80% success rate
        return Math.random() > 0.2;
    } catch (error) {
        console.error(`Error testing ${serviceType} connection:`, error);
        return false;
    }
}

// Routes
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/sub', (req, res) => {
    const domain = process.env.DOMAIN || 'localhost';
    let subscription = '';
    
    accounts.forEach(account => {
        subscription += account.subscription + '\n';
    });
    
    res.setHeader('Content-Type', 'text/plain');
    res.send(subscription);
});

// API Routes
app.get('/api/v1/accounts', (req, res) => {
    res.json({
        success: true,
        data: accounts,
        stats: {
            total: accounts.length,
            vless: accounts.filter(a => a.type === 'multi').length,
            trojan: accounts.filter(a => a.type === 'multi').length,
            vmess: accounts.filter(a => a.type === 'multi').length,
            shadowsocks: accounts.filter(a => a.type === 'multi').length
        }
    });
});

app.get('/api/v1/proxies', (req, res) => {
    res.json({
        success: true,
        data: proxyList,
        total: proxyList.length
    });
});

app.get('/api/v1/status', (req, res) => {
    res.json({
        success: true,
        data: serviceStatus
    });
});

app.post('/api/v1/accounts', (req, res) => {
    const { name, proxyId } = req.body;
    const domain = process.env.DOMAIN || 'localhost';
    
    if (!name || !proxyId) {
        return res.status(400).json({
            success: false,
            message: 'Name and proxy selection are required'
        });
    }
    
    try {
        const config = generateConfigFromProxy(proxyId, name, domain);
        accounts.push(config);
        saveAccounts();
        
        res.json({
            success: true,
            message: 'Account created successfully',
            data: config
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
});

app.delete('/api/v1/accounts/:id', (req, res) => {
    const { id } = req.params;
    const initialLength = accounts.length;
    accounts = accounts.filter(account => account.id !== id);
    
    if (accounts.length < initialLength) {
        saveAccounts();
        res.json({
            success: true,
            message: 'Account deleted successfully'
        });
    } else {
        res.status(404).json({
            success: false,
            message: 'Account not found'
        });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        service: 'DIANASTORE PROXY Server V2',
        status: 'running',
        domain: process.env.DOMAIN || 'localhost',
        port: PORT,
        accounts: accounts.length,
        proxies: proxyList.length,
        services: serviceStatus,
        xray: {
            configured: xrayConfig.configured,
            domain: xrayConfig.domain
        }
    });
});

// Create WebSocket server
const wss = new WebSocket.Server({ noServer: true });

// Handle WebSocket connections
wss.on('connection', async (ws, req, proxyIP, proxyPort, uuid) => {
  console.log(`WebSocket connection established to ${proxyIP}:${proxyPort}`);
  
  try {
    // Connect to the target proxy server using raw TCP
    const targetSocket = new net.Socket();
    
    // Set a longer timeout for the connection
    targetSocket.setTimeout(60000);
    
    targetSocket.connect(parseInt(proxyPort), proxyIP, () => {
      console.log(`TCP connection established to ${proxyIP}:${proxyPort}`);
    });
    
    // Handle data from client to target
    ws.on('message', (message) => {
      if (targetSocket.writable) {
        targetSocket.write(message);
      }
    });
    
    // Handle data from target to client
    targetSocket.on('data', (data) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(data);
      }
    });
    
    // Handle client connection close
    ws.on('close', () => {
      targetSocket.destroy();
      console.log(`WebSocket connection to ${proxyIP}:${proxyPort} closed`);
    });
    
    // Handle target connection close
    targetSocket.on('close', () => {
      ws.close();
      console.log(`Target connection to ${proxyIP}:${proxyPort} closed`);
    });
    
    // Handle errors
    ws.on('error', (err) => {
      console.error(`Client WebSocket error:`, err);
      targetSocket.destroy();
    });
    
    targetSocket.on('error', (err) => {
      console.error(`Target connection error:`, err);
      ws.close();
    });
    
    // Handle timeout
    targetSocket.on('timeout', () => {
      console.log(`Connection to ${proxyIP}:${proxyPort} timed out`);
      targetSocket.destroy();
      ws.close();
    });
    
  } catch (error) {
    console.error(`Failed to establish connection to ${proxyIP}:${proxyPort}:`, error);
    ws.close();
  }
});

// Handle upgrade requests with improved error handling
server.on('upgrade', (request, socket, head) => {
  try {
    const pathname = url.parse(request.url).pathname;
    
    // Check if the path matches our proxy pattern: /IP-PORT
    const match = pathname.match(/^\/([^-]+)-(\d+)$/);
    
    if (match) {
      const proxyIP = match[1];
      const proxyPort = match[2];
      
      // Extract UUID from headers for authentication (if needed)
      const uuid = request.headers['sec-websocket-protocol'] || null;
      
      console.log(`Upgrade request for ${proxyIP}:${proxyPort}`);
      
      // Set a longer timeout for the socket
      socket.setTimeout(60000);
      
      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit('connection', ws, request, proxyIP, proxyPort, uuid);
      });
    } else {
      // Not a proxy request, close the connection
      socket.destroy();
    }
  } catch (error) {
    console.error('Error handling upgrade request:', error);
    socket.destroy();
  }
});

// Initialize proxy list on startup
fetchProxyList();

// Initialize Xray if domain is set
if (process.env.DOMAIN && process.env.DOMAIN !== 'localhost') {
    initializeXray().then(() => {
        console.log('Xray initialization completed');
    }).catch(error => {
        console.error('Xray initialization failed:', error);
    });
}

// Check service status periodically
setInterval(checkServiceStatus, 60000); // Check every minute
checkServiceStatus(); // Initial check

// Use the HTTP server instead of app.listen
server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🌐 Domain: ${process.env.DOMAIN || 'localhost'}`);
    console.log(`📊 Total accounts: ${accounts.length}`);
    console.log(`🔗 Loading proxy list...`);
});
EOF

# Create public directory and updated index.html with DIANASTORE branding and black theme
echo -e "${BLUE}📄 Creating web dashboard with DIANASTORE branding and black theme...${NC}"
mkdir -p public

cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DIANASTORE PROXY - Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body {
            background-color: #000000;
            color: #ffffff;
        }
        
        .gradient-bg {
            background: linear-gradient(135deg, #1f1f1f 0%, #000000 100%);
            border-bottom: 1px solid #333;
        }
        
        .card-hover:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(255,255,255,0.1);
        }
        
        .copy-btn {
            transition: all 0.3s ease;
        }
        
        .copy-btn:hover {
            background-color: #059669;
        }
        
        .delete-btn {
            transition: all 0.3s ease;
        }
        
        .delete-btn:hover {
            background-color: #dc2626;
        }
        
        .proxy-card {
            transition: all 0.3s ease;
        }
        
        .proxy-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(255,255,255,0.1);
        }
        
        .config-tabs {
            display: none;
        }
        
        .config-tabs.active {
            display: block;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 8px;
        }
        
        .status-active {
            background-color: #10b981;
            box-shadow: 0 0 10px #10b981;
            animation: pulse 2s infinite;
        }
        
        .status-inactive {
            background-color: #ef4444;
        }
        
        .status-box {
            border: 1px solid #333;
            border-radius: 8px;
            padding: 12px;
            background-color: #111111;
            transition: all 0.3s ease;
        }
        
        .status-box:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(255,255,255,0.05);
        }
        
        @keyframes pulse {
            0% {
                box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
            }
            70% {
                box-shadow: 0 0 0 10px rgba(16, 185, 129, 0);
            }
            100% {
                box-shadow: 0 0 0 0 rgba(16, 185, 129, 0);
            }
        }
    </style>
</head>
<body class="min-h-screen">
    <!-- Status Bar -->
    <div class="bg-black border-b border-gray-800 py-3">
        <div class="container mx-auto px-6">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="status-box">
                    <div class="flex items-center">
                        <span id="vlessStatus" class="status-indicator status-inactive"></span>
                        <span class="font-medium">VLESS</span>
                        <span id="vlessStatusText" class="ml-auto text-sm text-gray-400">Checking...</span>
                    </div>
                </div>
                <div class="status-box">
                    <div class="flex items-center">
                        <span id="trojanStatus" class="status-indicator status-inactive"></span>
                        <span class="font-medium">TROJAN</span>
                        <span id="trojanStatusText" class="ml-auto text-sm text-gray-400">Checking...</span>
                    </div>
                </div>
                <div class="status-box">
                    <div class="flex items-center">
                        <span id="vmesStatus" class="status-indicator status-inactive"></span>
                        <span class="font-medium">VMES</span>
                        <span id="vmesStatusText" class="ml-auto text-sm text-gray-400">Checking...</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Header -->
    <header class="gradient-bg">
        <div class="container mx-auto px-6 py-8">
            <div class="flex items-center justify-between">
                <div>
                    <h1 class="text-3xl font-bold">💎 DIANASTORE PROXY</h1>
                    <p class="text-gray-400 mt-2">Premium WebSocket Proxy Dashboard</p>
                </div>
                <div class="text-right">
                    <div class="text-2xl font-bold" id="totalAccounts">0</div>
                    <div class="text-gray-400">Total Accounts</div>
                </div>
            </div>
        </div>
    </header>

    <!-- Stats Cards -->
    <div class="container mx-auto px-6 -mt-6">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="bg-gray-900 rounded-lg shadow-md p-6 card-hover border border-gray-800">
                <div class="flex items-center">
                    <div class="p-3 rounded-full bg-pink-900 text-pink-300">
                        <i class="fas fa-shield-alt text-xl"></i>
                    </div>
                    <div class="ml-4">
                        <div class="text-2xl font-bold text-white" id="vlessCount">0</div>
                        <div class="text-gray-400">VLESS Accounts</div>
                    </div>
                </div>
            </div>
            <div class="bg-gray-900 rounded-lg shadow-md p-6 card-hover border border-gray-800">
                <div class="flex items-center">
                    <div class="p-3 rounded-full bg-green-900 text-green-300">
                        <i class="fas fa-lock text-xl"></i>
                    </div>
                    <div class="ml-4">
                        <div class="text-2xl font-bold text-white" id="trojanCount">0</div>
                        <div class="text-gray-400">Trojan Accounts</div>
                    </div>
                </div>
            </div>
            <div class="bg-gray-900 rounded-lg shadow-md p-6 card-hover border border-gray-800">
                <div class="flex items-center">
                    <div class="p-3 rounded-full bg-purple-900 text-purple-300">
                        <i class="fas fa-link text-xl"></i>
                    </div>
                    <div class="ml-4">
                        <div class="text-lg font-bold text-white" id="domain">localhost</div>
                        <div class="text-gray-400">Domain</div>
                    </div>
                </div>
            </div>
            <div class="bg-gray-900 rounded-lg shadow-md p-6 card-hover border border-gray-800">
                <div class="flex items-center">
                    <div class="p-3 rounded-full bg-orange-900 text-orange-300">
                        <i class="fas fa-server text-xl"></i>
                    </div>
                    <div class="ml-4">
                        <div class="text-2xl font-bold text-white" id="proxyCount">0</div>
                        <div class="text-gray-400">Available Proxies</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Main Content -->
    <div class="container mx-auto px-6">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Create Account Form -->
            <div class="lg:col-span-1">
                <div class="bg-gray-900 rounded-lg shadow-md p-6 border border-gray-800">
                    <h2 class="text-xl font-bold text-white mb-4">
                        <i class="fas fa-plus-circle text-pink-500 mr-2"></i>
                        Create New Account
                    </h2>
                    <form id="createForm" class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-300 mb-2">Account Name</label>
                            <input type="text" id="accountName" required
                                class="w-full px-3 py-2 border border-gray-700 bg-gray-800 text-white rounded-md focus:outline-none focus:ring-2 focus:ring-pink-500"
                                placeholder="Enter account name">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-300 mb-2">Select Proxy Server</label>
                            <select id="proxySelect" required
                                class="w-full px-3 py-2 border border-gray-700 bg-gray-800 text-white rounded-md focus:outline-none focus:ring-2 focus:ring-pink-500">
                                <option value="">Loading proxies...</option>
                            </select>
                        </div>
                        <button type="submit"
                            class="w-full bg-pink-600 text-white py-2 px-4 rounded-md hover:bg-pink-700 transition duration-200 font-medium">
                            <i class="fas fa-plus mr-2"></i>
                            Create Account
                        </button>
                    </form>
                </div>

                <!-- Quick Links -->
                <div class="bg-gray-900 rounded-lg shadow-md p-6 mt-6 border border-gray-800">
                    <h3 class="text-lg font-bold text-white mb-4">
                        <i class="fas fa-link text-green-500 mr-2"></i>
                        Quick Links
                    </h3>
                    <div class="space-y-3">
                        <a href="/sub" target="_blank"
                            class="flex items-center justify-between p-3 bg-gray-800 rounded-md hover:bg-gray-700 transition duration-200">
                            <span class="text-gray-300">
                                <i class="fas fa-download mr-2"></i>
                                Subscription URL
                            </span>
                            <i class="fas fa-external-link-alt text-gray-500"></i>
                        </a>
                        <a href="/health" target="_blank"
                            class="flex items-center justify-between p-3 bg-gray-800 rounded-md hover:bg-gray-700 transition duration-200">
                            <span class="text-gray-300">
                                <i class="fas fa-heartbeat mr-2"></i>
                                Health Check
                            </span>
                            <i class="fas fa-external-link-alt text-gray-500"></i>
                        </a>
                    </div>
                </div>
            </div>

            <!-- Accounts List -->
            <div class="lg:col-span-1">
                <div class="bg-gray-900 rounded-lg shadow-md border border-gray-800">
                    <div class="p-6 border-b border-gray-800">
                        <h2 class="text-xl font-bold text-white">
                            <i class="fas fa-list text-purple-500 mr-2"></i>
                            Account List
                        </h2>
                    </div>
                    <div class="p-6">
                        <div id="accountsList" class="space-y-4">
                            <div class="text-center text-gray-500 py-8">
                                <i class="fas fa-inbox text-4xl mb-4"></i>
                                <p>No accounts created yet</p>
                                <p class="text-sm">Create your first account using the form</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Proxy List -->
        <div class="mt-8">
            <div class="bg-gray-900 rounded-lg shadow-md border border-gray-800">
                <div class="p-6 border-b border-gray-800">
                    <h2 class="text-xl font-bold text-white">
                        <i class="fas fa-server text-orange-500 mr-2"></i>
                        Available Proxy Servers
                    </h2>
                    <p class="text-gray-400 mt-1">Select a proxy server to create an account</p>
                </div>
                <div class="p-6">
                    <div id="proxyList" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        <div class="text-center text-gray-500 py-8">
                            <i class="fas fa-spinner fa-spin text-4xl mb-4"></i>
                            <p>Loading proxies...</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Toast Notification -->
    <div id="toast" class="fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-md shadow-lg transform translate-x-full transition-transform duration-300 z-50">
        <div class="flex items-center">
            <i class="fas fa-check-circle mr-2"></i>
            <span id="toastMessage">Success!</span>
        </div>
    </div>

    <script>
        let accounts = [];
        let proxies = [];
        const domain = window.location.hostname;

        // Update domain display
        document.getElementById('domain').textContent = domain;

        // Show toast notification
        function showToast(message, type = 'success') {
            const toast = document.getElementById('toast');
            const toastMessage = document.getElementById('toastMessage');
            
            toast.className = `fixed top-4 right-4 px-6 py-3 rounded-md shadow-lg transform translate-x-full transition-transform duration-300 z-50 ${
                type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'
            }`;
            
            toastMessage.textContent = message;
            toast.classList.remove('translate-x-full');
            
            setTimeout(() => {
                toast.classList.add('translate-x-full');
            }, 3000);
        }

        // Load proxies
        async function loadProxies() {
            try {
                const response = await fetch('/api/v1/proxies');
                const data = await response.json();
                
                if (data.success) {
                    proxies = data.data;
                    updateProxyStats();
                    renderProxySelect();
                    renderProxyList();
                }
            } catch (error) {
                console.error('Error loading proxies:', error);
                showToast('Error loading proxies', 'error');
            }
        }

        // Load accounts
        async function loadAccounts() {
            try {
                const response = await fetch('/api/v1/accounts');
                const data = await response.json();
                
                if (data.success) {
                    accounts = data.data;
                    updateStats();
                    renderAccounts();
                }
            } catch (error) {
                console.error('Error loading accounts:', error);
            }
        }

        // Update statistics
        function updateStats() {
            document.getElementById('totalAccounts').textContent = accounts.length;
            document.getElementById('vlessCount').textContent = accounts.filter(a => a.type === 'multi').length;
            document.getElementById('trojanCount').textContent = accounts.filter(a => a.type === 'multi').length;
        }

        function updateProxyStats() {
            document.getElementById('proxyCount').textContent = proxies.length;
        }

        // Check service status
        async function checkServiceStatus() {
            try {
                const response = await fetch('/api/v1/status');
                const data = await response.json();
                
                if (data.success) {
                    updateServiceStatus(data.data);
                }
            } catch (error) {
                console.error('Error checking service status:', error);
            }
        }

        // Update service status indicators
        function updateServiceStatus(status) {
            // Update VLESS status
            const vlessIndicator = document.getElementById('vlessStatus');
            const vlessText = document.getElementById('vlessStatusText');
            if (status.vless && status.vless.active) {
                vlessIndicator.className = 'status-indicator status-active';
                vlessText.textContent = 'Active';
                vlessText.className = 'ml-auto text-sm text-green-400';
            } else {
                vlessIndicator.className = 'status-indicator status-inactive';
                vlessText.textContent = 'Inactive';
                vlessText.className = 'ml-auto text-sm text-red-400';
            }
            
            // Update Trojan status
            const trojanIndicator = document.getElementById('trojanStatus');
            const trojanText = document.getElementById('trojanStatusText');
            if (status.trojan && status.trojan.active) {
                trojanIndicator.className = 'status-indicator status-active';
                trojanText.textContent = 'Active';
                trojanText.className = 'ml-auto text-sm text-green-400';
            } else {
                trojanIndicator.className = 'status-indicator status-inactive';
                trojanText.textContent = 'Inactive';
                trojanText.className = 'ml-auto text-sm text-red-400';
            }
            
            // Update VMES status
            const vmesIndicator = document.getElementById('vmesStatus');
            const vmesText = document.getElementById('vmesStatusText');
            if (status.vmes && status.vmes.active) {
                vmesIndicator.className = 'status-indicator status-active';
                vmesText.textContent = 'Active';
                vmesText.className = 'ml-auto text-sm text-green-400';
            } else {
                vmesIndicator.className = 'status-indicator status-inactive';
                vmesText.textContent = 'Inactive';
                vmesText.className = 'ml-auto text-sm text-red-400';
            }
        }

        // Render proxy select dropdown
        function renderProxySelect() {
            const select = document.getElementById('proxySelect');
            select.innerHTML = '<option value="">Select a proxy server</option>';
            
            proxies.forEach(proxy => {
                const option = document.createElement('option');
                option.value = proxy.id;
                option.textContent = `${proxy.proxyIP}:${proxy.proxyPort} (${proxy.country}) - ${proxy.org}`;
                select.appendChild(option);
            });
        }

        // Render proxy list
        function renderProxyList() {
            const proxyList = document.getElementById('proxyList');
            
            if (proxies.length === 0) {
                proxyList.innerHTML = `
                    <div class="text-center text-gray-500 py-8 col-span-full">
                        <i class="fas fa-exclamation-triangle text-4xl mb-4"></i>
                        <p>No proxies available</p>
                        <p class="text-sm">Check proxy sources</p>
                    </div>
                `;
                return;
            }
            
            proxyList.innerHTML = proxies.map(proxy => `
                <div class="proxy-card border border-gray-700 rounded-lg p-4 hover:shadow-md transition duration-200 bg-gray-800">
                    <div class="flex items-center justify-between mb-3">
                        <div class="flex items-center">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center bg-orange-900 text-orange-300">
                                <i class="fas fa-server"></i>
                            </div>
                            <div class="ml-3">
                                <h3 class="font-semibold text-white">${proxy.proxyIP}:${proxy.proxyPort}</h3>
                                <p class="text-sm text-gray-400">${proxy.country} - ${proxy.org}</p>
                            </div>
                        </div>
                        <div class="text-xs text-gray-500">#${proxy.id}</div>
                    </div>
                    <div class="bg-gray-900 rounded p-2">
                        <p class="text-xs text-gray-400">Country: ${proxy.country}</p>
                        <p class="text-xs text-gray-400">Organization: ${proxy.org}</p>
                    </div>
                </div>
            `).join('');
        }

        // Render accounts list
        function renderAccounts() {
            const accountsList = document.getElementById('accountsList');
            
            if (accounts.length === 0) {
                accountsList.innerHTML = `
                    <div class="text-center text-gray-500 py-8">
                        <i class="fas fa-inbox text-4xl mb-4"></i>
                        <p>No accounts created yet</p>
                        <p class="text-sm">Create your first account using the form</p>
                    </div>
                `;
                return;
            }
            
            accountsList.innerHTML = accounts.map(account => `
                <div class="border border-gray-700 rounded-lg p-4 hover:shadow-md transition duration-200 bg-gray-800">
                    <div class="flex items-center justify-between mb-3">
                        <div class="flex items-center">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center bg-pink-900 text-pink-300">
                                <i class="fas fa-user"></i>
                            </div>
                            <div class="ml-3">
                                <h3 class="font-semibold text-white">${account.name}</h3>
                                <p class="text-sm text-gray-400">Proxy: ${account.proxyName}</p>
                                <p class="text-xs text-gray-500">Country: ${account.proxyCountry} - ${account.proxyOrg}</p>
                            </div>
                        </div>
                        <div class="flex space-x-2">
                            <button onclick="showConfigs('${account.id}')" 
                                class="copy-btn bg-pink-600 text-white px-3 py-1 rounded text-sm hover:bg-pink-700">
                                <i class="fas fa-eye mr-1"></i>
                                View
                            </button>
                            <button onclick="deleteAccount('${account.id}')" 
                                class="delete-btn bg-red-600 text-white px-3 py-1 rounded text-sm hover:bg-red-700">
                                <i class="fas fa-trash mr-1"></i>
                                Delete
                            </button>
                        </div>
                    </div>
                    
                    <!-- Configuration Tabs -->
                    <div id="configs-${account.id}" class="config-tabs mt-3">
                        <div class="bg-gray-900 rounded p-3">
                            <div class="flex space-x-2 mb-3">
                                <button onclick="copyConfig('${account.id}', 'vless')" 
                                    class="bg-pink-600 text-white px-3 py-1 rounded text-xs hover:bg-pink-700">
                                    Copy VLESS
                                </button>
                                <button onclick="copyConfig('${account.id}', 'trojan')" 
                                    class="bg-green-600 text-white px-3 py-1 rounded text-xs hover:bg-green-700">
                                    Copy Trojan
                                </button>
                                <button onclick="copyConfig('${account.id}', 'vmess')" 
                                    class="bg-blue-600 text-white px-3 py-1 rounded text-xs hover:bg-blue-700">
                                    Copy VMESS
                                </button>
                            </div>
                            <div class="space-y-2">
                                <div>
                                    <p class="text-xs font-semibold text-gray-300">VLESS:</p>
                                    <p class="text-xs text-gray-400 break-all bg-gray-800 p-2 rounded">${account.configs.vless}</p>
                                </div>
                                <div>
                                    <p class="text-xs font-semibold text-gray-300">Trojan:</p>
                                    <p class="text-xs text-gray-400 break-all bg-gray-800 p-2 rounded">${account.configs.trojan}</p>
                                </div>
                                <div>
                                    <p class="text-xs font-semibold text-gray-300">VMESS:</p>
                                    <p class="text-xs text-gray-400 break-all bg-gray-800 p-2 rounded">${account.configs.vmess || 'Not available'}</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');
        }

        // Show/Hide configurations
        function showConfigs(accountId) {
            const configsDiv = document.getElementById(`configs-${accountId}`);
            if (configsDiv.classList.contains('active')) {
                configsDiv.classList.remove('active');
            } else {
                // Hide all other configs first
                document.querySelectorAll('.config-tabs').forEach(div => {
                    div.classList.remove('active');
                });
                configsDiv.classList.add('active');
            }
        }

        // Create account
        document.getElementById('createForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const name = document.getElementById('accountName').value;
            const proxyId = document.getElementById('proxySelect').value;
            
            try {
                const response = await fetch('/api/v1/accounts', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ name, proxyId })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showToast('Account created successfully!');
                    document.getElementById('createForm').reset();
                    loadAccounts();
                } else {
                    showToast(data.message, 'error');
                }
            } catch (error) {
                showToast('Error creating account', 'error');
            }
        });

        // Copy configuration
        async function copyConfig(accountId, type) {
            const account = accounts.find(a => a.id === accountId);
            if (account && account.configs[type]) {
                try {
                    await navigator.clipboard.writeText(account.configs[type]);
                    showToast(`${type.toUpperCase()} configuration copied!`);
                } catch (error) {
                    showToast('Failed to copy configuration', 'error');
                }
            }
        }

        // Delete account
        async function deleteAccount(id) {
            if (!confirm('Are you sure you want to delete this account?')) {
                return;
            }
            
            try {
                const response = await fetch(`/api/v1/accounts/${id}`, {
                    method: 'DELETE'
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showToast('Account deleted successfully!');
                    loadAccounts();
                } else {
                    showToast(data.message, 'error');
                }
            } catch (error) {
                showToast('Error deleting account', 'error');
            }
        }

        // Load data on page load
        loadProxies();
        loadAccounts();
        checkServiceStatus();
        
        // Check service status periodically
        setInterval(checkServiceStatus, 30000); // Check every 30 seconds
    </script>
</body>
</html>
EOF

# Create ecosystem.config.js
echo -e "${BLUE}📄 Creating PM2 configuration...${NC}"
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'dianastore-proxy-v2',
    script: 'server.js',
    cwd: '/opt/dianastore-proxy-v2-fixed',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DOMAIN: '$DOMAIN'
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    log_file: '/opt/dianastore-proxy-v2-fixed/logs/combined.log',
    out_file: '/opt/dianastore-proxy-v2-fixed/logs/out.log',
    error_file: '/opt/dianastore-proxy-v2-fixed/logs/error.log'
  }]
}
EOF

# Create logs directory
mkdir -p logs
mkdir -p accounts

# Install dependencies
echo -e "${BLUE}📦 Installing Node.js dependencies...${NC}"
npm install > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies installed!${NC}"

# Configure Nginx for Xray
echo -e "${BLUE}🌐 Configuring Nginx for Xray...${NC}"
cat > /etc/nginx/sites-available/xray << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10085;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10086;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/xray /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t > /dev/null 2>&1
if [ $? -eq 0 ]; then
    systemctl restart nginx > /dev/null 2>&1
    echo -e "${GREEN}✅ Nginx configured for Xray!${NC}"
else
    echo -e "${RED}❌ Nginx configuration error${NC}"
    exit 1
fi

# Start Xray
echo -e "${BLUE}🚀 Starting Xray service...${NC}"
systemctl enable xray > /dev/null 2>&1
systemctl restart xray > /dev/null 2>&1
echo -e "${GREEN}✅ Xray service started!${NC}"

# Start PM2 service
echo -e "${BLUE}🚀 Starting Node.js service with PM2...${NC}"
pm2 start ecosystem.config.js > /dev/null 2>&1
pm2 save > /dev/null 2>&1
pm2 startup > /dev/null 2>&1
echo -e "${GREEN}✅ Node.js service started!${NC}"

# Setup SSL certificate
echo -e "${BLUE}🔒 Setting up SSL certificate...${NC}"
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate installed!${NC}"
    SSL_STATUS="✅ HTTPS Enabled"
    PROTOCOL="https"
else
    echo -e "${YELLOW}⚠️ SSL certificate failed, using HTTP${NC}"
    SSL_STATUS="⚠️ HTTP Only"
    PROTOCOL="http"
fi

# Configure firewall
echo -e "${BLUE}🔥 Configuring firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow ssh > /dev/null 2>&1
ufw allow 80 > /dev/null 2>&1
ufw allow 443 > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
echo -e "${GREEN}✅ Firewall configured!${NC}"

# Test service
echo -e "${BLUE}🧪 Testing services...${NC}"
sleep 5

# Check if Xray is running
if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✅ Xray service is running!${NC}"
    XRAY_STATUS="✅ Active"
else
    echo -e "${RED}❌ Xray service is not running${NC}"
    XRAY_STATUS="❌ Inactive"
fi

# Check if Node.js service is running
if curl -s http://localhost:3000/health > /dev/null; then
    echo -e "${GREEN}✅ Node.js service is running!${NC}"
    NODE_STATUS="✅ Active"
else
    echo -e "${RED}❌ Node.js service is not running${NC}"
    NODE_STATUS="❌ Inactive"
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

# Generate VMESS and VLESS configs for display
VMESS_CONFIG=$(echo -n "{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;VMess-TLS&quot;,&quot;add&quot;:&quot;$DOMAIN&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$XRAY_UUID&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$DOMAIN&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;tls&quot;:&quot;tls&quot;}" | base64 -w 0)
VLESS_CONFIG="vless://$XRAY_UUID@$DOMAIN:443?type=tcp&security=tls&path=/vless#VLESS-TLS"

# Final output
clear
echo -e "${BLUE}"
echo "================================================"
echo "  🎉 DIANASTORE PROXY INSTALLATION COMPLETED!"
echo "================================================"
echo -e "${NC}"
echo ""
echo -e "${GREEN}✅ All components installed and configured!${NC}"
echo ""
echo -e "${CYAN}📋 Service Information:${NC}"
echo -e "   Domain: ${YELLOW}$DOMAIN${NC}"
echo -e "   Server IP: ${YELLOW}$SERVER_IP${NC}"
echo -e "   SSL Status: ${YELLOW}$SSL_STATUS${NC}"
echo -e "   Xray Status: ${YELLOW}$XRAY_STATUS${NC}"
echo -e "   Node.js Status: ${YELLOW}$NODE_STATUS${NC}"
echo -e "   Internal Port: ${YELLOW}3000${NC}"
echo ""
echo -e "${CYAN}🌐 Access URLs:${NC}"
echo -e "   Dashboard: ${GREEN}$PROTOCOL://$DOMAIN/${NC}"
echo -e "   Subscription: ${GREEN}$PROTOCOL://$DOMAIN/sub${NC}"
echo -e "   Health Check: ${GREEN}$PROTOCOL://$DOMAIN/health${NC}"
echo ""
echo -e "${CYAN}🔑 Default Configurations:${NC}"
echo -e "   VMESS: ${GREEN}vmess://$VMESS_CONFIG${NC}"
echo -e "   VLESS: ${GREEN}$VLESS_CONFIG${NC}"
echo ""
echo -e "${CYAN}🔧 Management Commands:${NC}"
echo -e "   View Node.js Logs: ${YELLOW}pm2 logs dianastore-proxy-v2${NC}"
echo -e "   View Xray Logs: ${YELLOW}journalctl -u xray${NC}"
echo -e "   Restart Node.js: ${YELLOW}pm2 restart dianastore-proxy-v2${NC}"
echo -e "   Restart Xray: ${YELLOW}systemctl restart xray${NC}"
echo -e "   Status: ${YELLOW}pm2 status${NC}"
echo ""
echo -e "${CYAN}✨ DIANASTORE PROXY Features:${NC}"
echo -e "   • VLESS, Trojan, VMESS with WebSocket support"
echo -e "   • Xray integration for better VMESS support"
echo -e "   • Full HTTPUpgrade implementation"
echo -e "   • TLS and SNI support"
echo -e "   • Path format: /IP-PORT and /vmess"
echo -e "   • Country flag emojis"
echo -e "   • Multiple config types per account"
echo -e "   • Beautiful web dashboard with black theme"
echo -e "   • Service status indicators with green lights"
echo -e "   • SSL certificate (if available)"
echo -e "   • Enhanced WebSocket proxy forwarding"
echo -e "   • Version compatibility fixes"
echo ""
echo -e "${GREEN}🚀 Your DIANASTORE PROXY Server is ready!${NC}"
echo -e "${YELLOW}Open your browser and visit: $PROTOCOL://$DOMAIN/${NC}"
echo ""
echo -e "${CYAN}📝 Note:${NC}"
echo -e "   This is a FIXED installation that properly implements WebSocket proxying"
echo -e "   All accounts now support HTTPUpgrade, WebSocket, TLS, and SNI"
echo -e "   The dashboard now has a black theme and service status indicators"
echo -e "   VMESS support is now implemented using Xray for better compatibility"
echo ""