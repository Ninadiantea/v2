const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const http = require('http');
const url = require('url');
const net = require('net');

const app = express();
const PORT = process.env.PORT || 3000;

// Create HTTP server
const server = http.createServer(app);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// In-memory storage for accounts
let accounts = [];
let proxyList = [];

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
                const response = await axios.get(source, { timeout: 10000 });
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
                org: 'Singapore Proxy',
                type: 'proxy'
            }
        ];
        
    } catch (error) {
        console.error('Error fetching proxy list:', error);
        proxyList = [];
    }
}

// Generate configuration with correct format (matching _worker.js)
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
    
    // VLESS Configuration (matching _worker.js format)
    const vlessConfig = `vless://${uuid}@${domain}:${port}?encryption=none&type=ws&host=${domain}&security=tls&sni=${domain}&path=${encodeURIComponent(path)}#${countryFlag} VLESS WS TLS [${name}]`;
    
    // Trojan Configuration
    const trojanConfig = `trojan://${uuid}@${domain}:${port}?security=tls&type=ws&host=${domain}&path=${encodeURIComponent(path)}#${countryFlag} Trojan WS TLS [${name}]`;
    
    // Shadowsocks Configuration
    const ssConfig = `ss://${btoa(`none:${uuid}`)}@${domain}:${port}?plugin=v2ray-plugin;tls;mux=0;mode=websocket;path=${encodeURIComponent(path)};host=${domain}#${countryFlag} SS WS TLS [${name}]`;
    
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
            shadowsocks: ssConfig
        },
        subscription: vlessConfig // Default to VLESS for subscription
    };
}

// Get country flag emoji (matching _worker.js)
function getFlagEmoji(isoCode) {
    if (!isoCode || isoCode.length !== 2) return '🌍';
    
    const codePoints = isoCode
        .toUpperCase()
        .split("")
        .map((char) => 127397 + char.charCodeAt(0));
    return String.fromCodePoint(...codePoints);
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
        service: 'Nautica Proxy Server V2',
        status: 'running',
        domain: process.env.DOMAIN || 'localhost',
        port: PORT,
        accounts: accounts.length,
        proxies: proxyList.length
    });
});

// Create WebSocket server
const wss = new WebSocket.Server({ noServer: true });

// Handle WebSocket connections
wss.on('connection', async (ws, req, proxyIP, proxyPort, uuid) => {
  console.log(`WebSocket connection established to ${proxyIP}:${proxyPort}`);
  
  try {
    // Connect to the target proxy server
    const targetSocket = new net.Socket();
    
    // Connect to the target proxy
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
    
  } catch (error) {
    console.error(`Failed to establish connection to ${proxyIP}:${proxyPort}:`, error);
    ws.close();
  }
});

// Handle upgrade requests
server.on('upgrade', (request, socket, head) => {
  const pathname = url.parse(request.url).pathname;
  
  // Check if the path matches our proxy pattern: /IP-PORT
  const match = pathname.match(/^\/([^-]+)-(\d+)$/);
  
  if (match) {
    const proxyIP = match[1];
    const proxyPort = match[2];
    
    // Extract UUID from headers for authentication (if needed)
    const uuid = request.headers['sec-websocket-protocol'] || null;
    
    console.log(`Upgrade request for ${proxyIP}:${proxyPort}`);
    
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request, proxyIP, proxyPort, uuid);
    });
  } else {
    // Not a proxy request, close the connection
    socket.destroy();
  }
});

// Initialize proxy list on startup
fetchProxyList();

// Use the HTTP server instead of app.listen
server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🌐 Domain: ${process.env.DOMAIN || 'localhost'}`);
    console.log(`📊 Total accounts: ${accounts.length}`);
    console.log(`🔗 Loading proxy list...`);
});
