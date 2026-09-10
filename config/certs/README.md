# Extra CA certificates

Any `*.pem` file in this directory is trusted by tools inside the container.
`config/launch.sh` concatenates them with the system CA bundle at launch and
points `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`,
`CURL_CA_BUNDLE` and `GIT_SSL_CAINFO` at the result.

Because `config/` is bind-mounted read-only into the container, adding or
updating a cert here takes effect on the next `mosh` launch — no image rebuild
and no `mosh fresh` required.

## nist-ca.pem

Needed to reach the NIST LiteLLM gateway (`ANTHROPIC_BASE_URL`). Without it
Claude Code fails with "SSL certificate verification failed".

Two problems make this necessary:

1. The gateway's certificate is issued by `NISTIssuingCA03`, an internal NIST
   enterprise CA that is not in the stock Debian trust store. macOS trusts it
   via Keychain, which is why host-native Claude Code works without this file.
2. The server sends only its leaf certificate and omits the intermediate, so
   trusting the root alone is not enough. This bundle therefore contains
   **both** the intermediate and the root.

Contents:

| Cert | Subject | SHA-256 fingerprint |
|------|---------|---------------------|
| intermediate | `DC=GOV, DC=NIST, DC=campus, CN=NISTIssuingCA03` | `B2:0E:16:AB:9C:BD:4D:5F:C2:62:99:5B:EC:6B:26:80:D3:91:CF:3C:BC:90:03:13:A7:B0:F2:4D:25:E6:EB:A9` |
| root | `CN=NISTRoot02` (self-signed) | `6C:4A:F9:F7:08:3C:D8:02:C1:A4:63:85:AC:83:24:D1:43:13:D3:07:35:42:0A:38:B0:60:2D:21:F4:5B:83:FD` |

### Provenance and verification

These were downloaded over **plain HTTP** from the URLs advertised in the
certificates' Authority Information Access extensions:

    http://nistpki.nist.gov/CertEnroll/DEBECA03.campus.NIST.GOV_NISTIssuingCA03.crt
    http://nistpki.nist.gov/CertEnroll/NISTrootCA02_NISTRoot02.crt

Plain HTTP is spoofable, so **verify the fingerprints above against a trusted
source** before relying on this bundle. On macOS, compare with Keychain:

```bash
security find-certificate -a -c NISTRoot02 -p /Library/Keychains/System.keychain \
  | openssl x509 -noout -fingerprint -sha256
```

To regenerate:

```bash
curl -o inter.crt http://nistpki.nist.gov/CertEnroll/DEBECA03.campus.NIST.GOV_NISTIssuingCA03.crt
curl -o root.crt  http://nistpki.nist.gov/CertEnroll/NISTrootCA02_NISTRoot02.crt
openssl x509 -inform DER -in inter.crt -out inter.pem
openssl x509 -inform DER -in root.crt  -out root.pem
cat inter.pem root.pem > nist-ca.pem
```
