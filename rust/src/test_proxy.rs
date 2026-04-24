use rcgen::{BasicConstraints, Certificate, CertificateParams, DnType, IsCa};
use std::sync::Arc;
use rustls::server::{ClientHello, ResolvesServerCert};
use rustls::sign::CertifiedKey;
use std::collections::HashMap;

#[allow(dead_code)]
struct MitmCa {
    ca: Certificate,
    ca_der: Vec<u8>,
}

#[allow(dead_code)]
fn build_ca(_ca_cert_pem: Option<&str>, _ca_key_pem: Option<&str>) -> anyhow::Result<MitmCa> {
    let mut params = CertificateParams::default();
    params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
    params.distinguished_name.push(DnType::CommonName, "PostLens Proxy CA");
    let ca = Certificate::from_params(params)?;
    let ca_der = ca.serialize_der()?;
    Ok(MitmCa { ca, ca_der })
}

#[allow(dead_code)]
struct MitmCertResolver {
    ca: Arc<MitmCa>,
    cache: std::sync::Mutex<HashMap<String, Arc<CertifiedKey>>>,
}

impl std::fmt::Debug for MitmCertResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("MitmCertResolver").finish()
    }
}

impl MitmCertResolver {
    #[allow(dead_code)]
    fn new(ca: Arc<MitmCa>) -> Self {
        Self {
            ca,
            cache: std::sync::Mutex::new(HashMap::new()),
        }
    }
}

impl ResolvesServerCert for MitmCertResolver {
    fn resolve(&self, _client_hello: ClientHello<'_>) -> Option<Arc<CertifiedKey>> {
        None
    }
}

fn build_mitm_server_config() -> anyhow::Result<rustls::ServerConfig> {
    let ca = Arc::new(build_ca(None, None)?);
    let resolver = Arc::new(MitmCertResolver::new(ca));
    let mut server_config = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_cert_resolver(resolver);
    server_config.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    Ok(server_config)
}

fn main() {
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();
    match build_mitm_server_config() {
        Ok(_) => println!("Success mitm config"),
        Err(e) => println!("Error: {:?}", e),
    }
}
