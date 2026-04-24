import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local/database_helper.dart';
import '../../src/rust/api/proxy.dart';

enum CertificateExportFormat { crt, pem, zero, p12 }

class ManagedCertificateInfo {
  final String certPath;
  final String keyPath;
  final Map<String, String?> subject;
  final Map<String, String?> issuer;
  final DateTime? notBefore;
  final DateTime? notAfter;
  final String sha256;
  final String pem;

  const ManagedCertificateInfo({
    required this.certPath,
    required this.keyPath,
    required this.subject,
    required this.issuer,
    required this.notBefore,
    required this.notAfter,
    required this.sha256,
    required this.pem,
  });
}

class CertificateManager {
  static final CertificateManager instance = CertificateManager._internal();
  CertificateManager._internal();

  bool _initialized = false;
  String? _caKeyPem;
  String? _caCertPem;
  RSAPrivateKey? _caPrivateKey;
  final Map<String, SecurityContext> _domainContexts = {};

  RSAPrivateKey? _domainPrivateKey;
  RSAPublicKey? _domainPublicKey;

  Future<void> initialize() async {
    final keyFile = await _getKeyFile();
    final certFile = await _getCertFile();
    if (_initialized && _caKeyPem != null && _caCertPem != null) {
      await _writePemFilesIfMissing(keyFile, certFile);
      return;
    }
    await _migrateLegacyCertificatesIfNeeded(keyFile, certFile);

    if (await keyFile.exists() && await certFile.exists()) {
      await _loadExistingCaCertificate(keyFile, certFile);
    } else {
      await _generateCaCertificate(keyFile, certFile);
    }

    _initialized = true;
  }

  Future<void> regenerateCaCertificate() async {
    final keyFile = await _getKeyFile();
    final certFile = await _getCertFile();

    if (await keyFile.exists()) {
      await keyFile.delete();
    }
    if (await certFile.exists()) {
      await certFile.delete();
    }

    _resetInMemoryState();
    await _generateCaCertificate(keyFile, certFile);
    _initialized = true;
  }

  Future<ManagedCertificateInfo> getCertificateInfo() async {
    await initialize();
    final certPath = await localCertPath;
    final keyPath = await localKeyPath;
    final pem = _caCertPem!;
    final certData = X509Utils.x509CertificateFromPem(pem);
    final tbsCertificate = certData.tbsCertificate;
    final validity = tbsCertificate?.validity;
    final subject = Map<String, String?>.from(tbsCertificate?.subject ?? const {});
    final issuer = Map<String, String?>.from(tbsCertificate?.issuer ?? const {});
    return ManagedCertificateInfo(
      certPath: certPath,
      keyPath: keyPath,
      subject: subject,
      issuer: issuer,
      notBefore: validity?.notBefore,
      notAfter: validity?.notAfter,
      sha256: certData.sha256Thumbprint ?? _calculateSha256Fingerprint(pem),
      pem: pem,
    );
  }

  Future<void> exportCertificate({
    required String outputPath,
    required CertificateExportFormat format,
    String? password,
  }) async {
    await initialize();
    switch (format) {
      case CertificateExportFormat.crt:
      case CertificateExportFormat.pem:
      case CertificateExportFormat.zero:
        await File(outputPath).writeAsString(_caCertPem!);
        break;
      case CertificateExportFormat.p12:
        final bytes = Pkcs12Utils.generatePkcs12(
          _caKeyPem!,
          [_caCertPem!],
          password: password,
        );
        await File(outputPath).writeAsBytes(bytes, flush: true);
        break;
    }
  }

  Future<void> _generateCaCertificate(File keyFile, File certFile) async {
    // 1. Generate RSA KeyPair in Dart
    final keyPair = CryptoUtils.generateRSAKeyPair();
    _caPrivateKey = keyPair.privateKey as RSAPrivateKey;
    _caKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(_caPrivateKey!);

    // 2. Generate the CA certificate using Rust (rcgen) with the generated private key
    // This ensures that the generated CA certificate has the required BasicConstraints (CA:TRUE)
    // and KeyUsage extensions, which are missing when using the basic_utils dart package.
    _caCertPem = generateCa(privateKeyPem: _caKeyPem!);

    await keyFile.writeAsString(_caKeyPem!);
    await certFile.writeAsString(_caCertPem!);
  }

  Future<void> _loadExistingCaCertificate(File keyFile, File certFile) async {
    _caKeyPem = await keyFile.readAsString();
    _caCertPem = await certFile.readAsString();
    _caPrivateKey = _parsePrivateKey(_caKeyPem!);

    // Fix corrupted PKCS#8 headers (from older versions) to ensure Rust rcgen can parse it.
    // If the file was written with the old bug, it will have PKCS#8 headers but PKCS#1 body.
    // By re-encoding it here, we ensure _caKeyPem contains a proper PKCS#8 structure.
    final correctedKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(_caPrivateKey!);
    if (_caKeyPem != correctedKeyPem) {
      _caKeyPem = correctedKeyPem;
      await keyFile.writeAsString(_caKeyPem!);
    }

    // Verify if the certificate has CA extensions. If not, it was generated by the old
    // buggy basic_utils method, which causes ERR_CERT_AUTHORITY_INVALID in browsers.
    final certData = X509Utils.x509CertificateFromPem(_caCertPem!);
    if (certData.tbsCertificate?.extensions == null) {
      // Regenerate the certificate using the correct Rust method.
      _caCertPem = generateCa(privateKeyPem: _caKeyPem!);
      await certFile.writeAsString(_caCertPem!);
      // Reset the installed flag so the user knows they need to re-install it
      await DatabaseHelper.instance.setKeyValue('cert_installed', 'false');
    }
  }

  RSAPrivateKey _parsePrivateKey(String pem) {
    try {
      return CryptoUtils.rsaPrivateKeyFromPem(pem);
    } catch (_) {
      var tempKey = pem.replaceAll('BEGIN PRIVATE KEY', 'BEGIN RSA PRIVATE KEY');
      tempKey = tempKey.replaceAll('END PRIVATE KEY', 'END RSA PRIVATE KEY');
      return CryptoUtils.rsaPrivateKeyFromPemPkcs1(tempKey);
    }
  }

  void _resetInMemoryState() {
    _initialized = false;
    _caKeyPem = null;
    _caCertPem = null;
    _caPrivateKey = null;
    _domainPrivateKey = null;
    _domainPublicKey = null;
    _domainContexts.clear();
  }

  Future<Directory> _getCertDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final certDir = Directory('${dir.path}/PostLens/Certs');
    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }
    return certDir;
  }

  Future<Directory> _getLegacyCertDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/PostLens/Certs');
  }

  Future<void> _migrateLegacyCertificatesIfNeeded(
    File targetKeyFile,
    File targetCertFile,
  ) async {
    if (await targetKeyFile.exists() || await targetCertFile.exists()) {
      return;
    }

    final legacyDir = await _getLegacyCertDirectory();
    final legacyKeyFile = File('${legacyDir.path}/ca.key');
    final legacyCertFile = File('${legacyDir.path}/ca.crt');
    if (!await legacyKeyFile.exists() || !await legacyCertFile.exists()) {
      return;
    }

    await targetKeyFile.writeAsString(await legacyKeyFile.readAsString());
    await targetCertFile.writeAsString(await legacyCertFile.readAsString());
  }

  Future<File> _getKeyFile() async {
    final certDir = await _getCertDirectory();
    return File('${certDir.path}/ca.key');
  }

  Future<File> _getCertFile() async {
    final certDir = await _getCertDirectory();
    return File('${certDir.path}/ca.crt');
  }

  String? get caCertificatePem => _caCertPem;
  String? get caKeyPem => _caKeyPem;

  Future<String> get localCertPath async {
    await initialize();
    final certFile = await _getCertFile();
    await _writePemFilesIfMissing(null, certFile);
    return certFile.path;
  }

  Future<String> get localKeyPath async {
    await initialize();
    final keyFile = await _getKeyFile();
    await _writePemFilesIfMissing(keyFile, null);
    return keyFile.path;
  }

  Future<String> exportCaCertificate() async {
    if (_caCertPem == null) {
      await initialize();
    }
    return _caCertPem!;
  }

  Future<SecurityContext> getCertificateForDomain(String domain) async {
    if (_domainContexts.containsKey(domain)) {
      return _domainContexts[domain]!;
    }

    if (_caPrivateKey == null || _caCertPem == null) {
      await initialize();
    }

    if (_domainPrivateKey == null) {
      // Use isolates if possible, but for now we generate once and reuse
      final keyPair = CryptoUtils.generateRSAKeyPair();
      _domainPrivateKey = keyPair.privateKey as RSAPrivateKey;
      _domainPublicKey = keyPair.publicKey as RSAPublicKey;
    }

    final subject = <String, String>{
      'CN': domain,
      'O': 'PostLens Proxy',
      'C': 'US',
    };

    final csr = X509Utils.generateRsaCsrPem(
      subject,
      _domainPrivateKey!,
      _domainPublicKey!,
      san: [domain],
    );

    // Extract exact subject from our CA certificate to use as issuer
    final caCertData = X509Utils.x509CertificateFromPem(_caCertPem!);
    final subjectData = caCertData.tbsCertificate?.subject ?? const <String, String?>{};
    final Map<String, String> caIssuer = {};
    subjectData.forEach((key, value) {
      if (value != null) {
        caIssuer[key] = value;
      }
    });

    if (caIssuer.isEmpty) {
      caIssuer['CN'] = 'PostLens Proxy CA';
      caIssuer['O'] = 'PostLens';
      caIssuer['C'] = 'US';
    }

    final domainCertPem = X509Utils.generateSelfSignedCertificate(
      _caPrivateKey!,
      csr,
      365,
      issuer: caIssuer,
      sans: [domain],
    );
    final domainKeyPem =
        CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(_domainPrivateKey!);

    final chainPem = '$domainCertPem\n$_caCertPem';

    final context = SecurityContext()
      ..useCertificateChainBytes(chainPem.codeUnits)
      ..usePrivateKeyBytes(domainKeyPem.codeUnits);

    try {
      context.setAlpnProtocols(['http/1.1'], true);
    } catch (_) {
      // Ignore if ALPN is not supported on this platform/version
    }

    _domainContexts[domain] = context;
    return context;
  }

  Future<void> _writePemFilesIfMissing(File? keyFile, File? certFile) async {
    if (keyFile != null && !await keyFile.exists() && _caKeyPem != null) {
      await keyFile.writeAsString(_caKeyPem!, flush: true);
    }
    if (certFile != null && !await certFile.exists() && _caCertPem != null) {
      await certFile.writeAsString(_caCertPem!, flush: true);
    }
  }

  String _calculateSha256Fingerprint(String pem) {
    final normalized = pem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    final derBytes = base64.decode(normalized);
    final digest = sha256.convert(derBytes).bytes;
    return digest
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}
