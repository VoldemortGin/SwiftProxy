# SSLHandler Implementation Guide

## Overview

The SSLHandler provides enterprise-grade SSL/TLS security features for SwiftProxy, including:

- **TLS 1.3** as default with **TLS 1.2** fallback
- **ALPN** (Application-Layer Protocol Negotiation) for HTTP/2 and HTTP/1.1
- **Certificate pinning** for enhanced security
- **OCSP stapling** support for certificate revocation checking
- **Certificate Transparency (CT)** verification
- **Custom trust evaluation** policies

## Architecture

```
SSLHandler (Actor)
├── TLS Configuration
│   ├── Version Management (TLS 1.2/1.3)
│   ├── ALPN Protocols (h2, http/1.1, h3)
│   └── Cipher Suites
├── Certificate Management
│   ├── Certificate Store
│   ├── Certificate Pinning
│   └── Client Certificates
├── Trust Verification
│   ├── Default System Trust
│   ├── Pinned Certificates
│   ├── Custom Validators
│   └── Debug Mode (allowAll)
└── Advanced Features
    ├── OCSP Stapling
    ├── Certificate Transparency
    └── Session Info Extraction
```

## Usage Examples

### Basic TLS Configuration

```swift
// Initialize SSLHandler
let sslHandler = SSLHandler()

// Configure TLS for a connection
let tlsOptions = await sslHandler.configureTLS(
    for: "api.example.com",
    port: 443
)

// Apply to Network.framework connection
let parameters = NWParameters.tls
parameters.defaultProtocolStack.applicationProtocols.insert(tlsOptions, at: 0)
```

### Certificate Pinning

```swift
// Pin certificate from file
try await sslHandler.pinCertificateFromFile(
    "/path/to/certificate.cer",
    for: "secure.example.com"
)

// Set trust policy to use pinned certificates
await sslHandler.setTrustPolicy(.pinned)

// Configure TLS with pinning enabled
let tlsOptions = await sslHandler.configureTLS(
    for: "secure.example.com",
    port: 443
)
```

### Custom Trust Validation

```swift
// Define custom validation logic
let customValidator: ([SecCertificate], String) async -> Bool = { certificates, host in
    // Custom validation logic
    guard !certificates.isEmpty else { return false }

    // Example: Check if host is in allowed list
    let allowedHosts = ["trusted1.example.com", "trusted2.example.com"]
    guard allowedHosts.contains(host) else { return false }

    // Additional custom checks...
    return true
}

// Set custom trust policy
await sslHandler.setTrustPolicy(.custom(customValidator))
```

### TLS Configuration Presets

```swift
// Use secure configuration (TLS 1.3 only)
await sslHandler.updateTLSConfiguration(.secure)

// Use default configuration (TLS 1.3 with 1.2 fallback)
await sslHandler.updateTLSConfiguration(.default)

// Custom configuration
let customConfig = TLSConfiguration(
    minimumTLSVersion: .TLSv13,
    maximumTLSVersion: .TLSv13,
    alpnProtocols: ["h3", "h2", "http/1.1"],
    cipherSuites: [
        tls_ciphersuite_t(rawValue: 0x1301)!, // TLS_AES_128_GCM_SHA256
        tls_ciphersuite_t(rawValue: 0x1302)!, // TLS_AES_256_GCM_SHA384
    ],
    enableOCSPStapling: true,
    enableCertificateTransparency: true
)
await sslHandler.updateTLSConfiguration(customConfig)
```

### Client Certificate Authentication

```swift
// Load client identity from keychain
let identity = loadClientIdentity() // Your implementation

// Configure certificate store
let certificateStore = CertificateStore()
certificateStore.setClientIdentity(identity)

// Initialize SSLHandler with certificate store
let sslHandler = SSLHandler(certificateStore: certificateStore)

// Configure TLS with client certificate
let tlsOptions = await sslHandler.configureTLS(
    for: "client-auth.example.com",
    port: 443,
    requireClientCert: true
)
```

### Extracting Session Information

```swift
// After TLS connection is established
let sessionInfo = await sslHandler.getSessionInfo(from: metadata)

print("Protocol: \(sessionInfo.negotiatedProtocol)")      // e.g., "h2"
print("TLS Version: \(sessionInfo.tlsVersion)")          // e.g., "TLS 1.3"
print("Cipher Suite: \(sessionInfo.cipherSuite)")        // e.g., "TLS_AES_128_GCM_SHA256"
```

## Security Features

### OCSP Stapling

OCSP stapling is enabled by default and provides real-time certificate revocation checking without additional network requests:

```swift
var config = TLSConfiguration.default
config.enableOCSPStapling = true // Enabled by default
await sslHandler.updateTLSConfiguration(config)
```

### Certificate Transparency

Certificate Transparency verification helps detect mis-issued certificates:

```swift
var config = TLSConfiguration.default
config.enableCertificateTransparency = true // Enabled by default
await sslHandler.updateTLSConfiguration(config)
```

### Debug Mode

For development and testing only:

```swift
#if DEBUG
// Allow all certificates (INSECURE - DEBUG ONLY)
await sslHandler.setTrustPolicy(.allowAll)
#endif
```

## Error Handling

```swift
do {
    try await sslHandler.pinCertificateFromFile(
        "/path/to/cert.cer",
        for: "example.com"
    )
} catch AppError.sslError(let reason) {
    print("SSL Error: \(reason)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Always use TLS 1.3** when possible, with TLS 1.2 as fallback
2. **Enable ALPN** for HTTP/2 support
3. **Pin certificates** for critical connections
4. **Enable OCSP stapling** for revocation checking
5. **Use Certificate Transparency** for additional security
6. **Never use `.allowAll`** trust policy in production
7. **Rotate pinned certificates** before expiration
8. **Monitor TLS handshake failures** for security issues

## Performance Considerations

- **Connection Reuse**: TLS sessions are cached automatically by Network.framework
- **ALPN Negotiation**: Reduces round trips by negotiating application protocol during TLS handshake
- **Certificate Caching**: Validated certificates are cached to avoid repeated verification
- **Cipher Suite Selection**: Modern cipher suites provide better performance

## Platform Requirements

- macOS 13.0+
- Swift 6 with strict concurrency
- Network.framework
- Security.framework

## Testing

Run the comprehensive test suite:

```bash
swift test --filter SSLHandlerTests
```

## Troubleshooting

### Common Issues

1. **Certificate Verification Failures**
   - Check certificate chain completeness
   - Verify certificate validity dates
   - Ensure proper hostname matching

2. **TLS Version Incompatibility**
   - Some servers may not support TLS 1.3
   - Use `.default` configuration for maximum compatibility

3. **Certificate Pinning Failures**
   - Verify pinned certificate matches server certificate
   - Check for certificate rotation
   - Ensure certificate data is correctly formatted

4. **Client Certificate Issues**
   - Verify identity is properly loaded from keychain
   - Check certificate and private key pairing
   - Ensure proper keychain access permissions

## Security Audit Checklist

- [ ] TLS 1.3 enabled as primary protocol
- [ ] TLS 1.2 available as fallback only
- [ ] ALPN protocols configured correctly
- [ ] Certificate pinning implemented for sensitive connections
- [ ] OCSP stapling enabled
- [ ] Certificate Transparency verification active
- [ ] No use of `.allowAll` trust policy in production
- [ ] Proper error handling for TLS failures
- [ ] Regular certificate rotation schedule
- [ ] Security logging and monitoring in place

## References

- [Apple Security Framework Documentation](https://developer.apple.com/documentation/security)
- [Network.framework TLS Options](https://developer.apple.com/documentation/network/nwprotocoltls)
- [RFC 8446 - TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446)
- [RFC 6066 - OCSP Stapling](https://datatracker.ietf.org/doc/html/rfc6066)
- [Certificate Transparency](https://certificate.transparency.dev/)