use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use flutter_rust_bridge::frb;
use crate::frb_generated::StreamSink;
use crate::proxy_kernel::ProxyServer;

#[frb(sync)]
pub fn generate_ca(private_key_pem: String) -> anyhow::Result<String> {
    use rcgen::{BasicConstraints, Certificate, CertificateParams, DnType, IsCa, KeyPair};
    use time::{Duration, OffsetDateTime};
    
    let key_pair = KeyPair::from_pem(&private_key_pem)?;
    
    let mut params = CertificateParams::new(vec![]);
    params.alg = &rcgen::PKCS_RSA_SHA256;
    params.key_pair = Some(key_pair);
    params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
    params.distinguished_name.push(DnType::CommonName, "PostLens Proxy CA");
    params.distinguished_name.push(DnType::OrganizationName, "PostLens");
    let now = OffsetDateTime::now_utc();
    params.not_before = now - Duration::days(1);
    params.not_after = now + Duration::days(3650);
    
    let ca = Certificate::from_params(params)?;
    let cert_pem = ca.serialize_pem()?;
    
    Ok(cert_pem)
}

#[derive(Clone, Debug)]
pub struct CaptureSession {
    pub id: String,
    pub started_at: i64,
    pub protocol: String,
    pub method: String,
    pub url: String,
    pub host: String,
    pub port: u16,
    pub status_code: Option<u16>,
    pub status_message: Option<String>,
    pub duration_ms: i64,
    pub request_bytes: i64,
    pub response_bytes: i64,
    pub request_headers: HashMap<String, Vec<String>>,
    pub request_body: String,
    pub response_headers: HashMap<String, Vec<String>>,
    pub response_body: String,
    pub error: Option<String>,
    pub client_ip: Option<String>,
    pub client_port: Option<u16>,
    pub server_ip: Option<String>,
    pub process_id: Option<String>,
    pub app_name: Option<String>,
    pub app_path: Option<String>,
}

#[derive(Clone, Debug)]
pub struct ProxyConfig {
    pub port: u16,
    pub enable_ssl_proxying: bool,
    pub ca_cert: Option<String>,
    pub ca_key: Option<String>,
}

#[derive(Clone)]
pub struct ProxyCore {
    handle: Arc<Mutex<Option<tokio::sync::oneshot::Sender<()>>>>,
    sink: Arc<Mutex<Option<StreamSink<CaptureSession>>>>,
}

impl ProxyCore {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            handle: Arc::new(Mutex::new(None)),
            sink: Arc::new(Mutex::new(None)),
        }
    }

    pub fn setup_stream(&self, sink: StreamSink<CaptureSession>) {
        let mut lock = self.sink.blocking_lock();
        *lock = Some(sink);
    }

    pub async fn start(&self, config: ProxyConfig) -> anyhow::Result<u16> {
        let mut handle_lock = self.handle.lock().await;
        if handle_lock.is_some() {
            return Ok(0); // already running
        }
        
        let (tx, rx) = tokio::sync::oneshot::channel();
        *handle_lock = Some(tx);
        
        let port = config.port;
        let actual_config = config.clone();
        
        let sink_lock = self.sink.lock().await;
        let session_sink = sink_lock.clone().expect("StreamSink not set");
        
        let server = match ProxyServer::new(actual_config, session_sink) {
            Ok(s) => s,
            Err(e) => {
                println!("Failed to create ProxyServer: {:?}", e);
                return Err(anyhow::anyhow!("Failed to create ProxyServer: {:?}", e));
            }
        };
        
        // Ensure port is available before spawning
        let addr = format!("0.0.0.0:{}", port).parse::<std::net::SocketAddr>()?;
        let listener = tokio::net::TcpListener::bind(addr).await?;
        let actual_port = listener.local_addr()?.port();
        
        tokio::spawn(async move {
            let _ = server.run_with_listener(listener, rx).await;
        });
        
        Ok(actual_port)
    }

    pub async fn stop(&self) {
        let mut handle_lock = self.handle.lock().await;
        if let Some(tx) = handle_lock.take() {
            let _ = tx.send(());
        }
    }
}
