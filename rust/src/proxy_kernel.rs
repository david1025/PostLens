use std::collections::HashMap;
use std::convert::Infallible;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::header::{HeaderName, HOST, UPGRADE};
use hyper::server::conn::{http1, http2};
use hyper::service::service_fn;
use hyper::{Method, Request, Response, StatusCode, Uri};
use hyper_util::client::legacy::Client;
use hyper_util::client::legacy::connect::HttpConnector;
use hyper_rustls::{HttpsConnector, HttpsConnectorBuilder};
use hyper_util::rt::{TokioExecutor, TokioIo};
use rcgen::{BasicConstraints, Certificate, CertificateParams, DnType, ExtendedKeyUsagePurpose, IsCa, KeyPair};
use rustls::crypto::aws_lc_rs;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use rustls::server::{ClientHello, ResolvesServerCert};
use rustls::sign::{CertifiedKey, SigningKey};
use tokio::net::{TcpListener, TcpStream};
use tokio_rustls::TlsAcceptor;
use async_compression::tokio::write::{GzipDecoder, DeflateDecoder, BrotliDecoder, ZstdDecoder};
use tokio::io::AsyncWriteExt;
use time::{OffsetDateTime, Duration};

use crate::api::proxy::{CaptureSession, ProxyConfig};
use crate::frb_generated::StreamSink;

use std::sync::atomic::{AtomicU64, Ordering};

static SESSION_COUNTER: AtomicU64 = AtomicU64::new(1);

struct MitmCa {
    ca: Certificate,
    ca_der: Vec<u8>,
}

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
    fn new(ca: Arc<MitmCa>) -> Self {
        Self {
            ca,
            cache: std::sync::Mutex::new(HashMap::new()),
        }
    }
}

impl ResolvesServerCert for MitmCertResolver {
    fn resolve(&self, client_hello: ClientHello<'_>) -> Option<Arc<CertifiedKey>> {
        let host = client_hello.server_name()?.to_string();
        let mut cache = self.cache.lock().ok()?;
        if let Some(v) = cache.get(&host) {
            return Some(v.clone());
        }

        let mut params = CertificateParams::new(vec![host.clone()]);
        params.distinguished_name.push(DnType::CommonName, host.clone());
        params.extended_key_usages.push(ExtendedKeyUsagePurpose::ServerAuth);
        let now = OffsetDateTime::now_utc();
        params.not_before = now - Duration::days(1);
        params.not_after = now + Duration::days(365);
        let leaf = Certificate::from_params(params).ok()?;

        let leaf_cert_der = leaf.serialize_der_with_signer(&self.ca.ca).ok()?;
        let leaf_key_der = leaf.serialize_private_key_der();

        let certs = vec![
            CertificateDer::from(leaf_cert_der),
            CertificateDer::from(self.ca.ca_der.clone()),
        ];

        let key_der = PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(leaf_key_der));
        let key: Arc<dyn SigningKey> = aws_lc_rs::sign::any_supported_type(&key_der).ok()?;
        let certified_key = Arc::new(CertifiedKey::new(certs, key));

        cache.insert(host, certified_key.clone());
        Some(certified_key)
    }
}

pub struct ProxyServer {
    config: ProxyConfig,
    sink: StreamSink<CaptureSession>,
    mitm_acceptor: Option<Arc<TlsAcceptor>>,
    client: Client<HttpsConnector<HttpConnector>, Full<Bytes>>,
}

impl ProxyServer {
    pub fn new(config: ProxyConfig, sink: StreamSink<CaptureSession>) -> anyhow::Result<Self> {
        let _ = aws_lc_rs::default_provider().install_default();

        let mitm_acceptor = if config.enable_ssl_proxying {
            Some(Arc::new(TlsAcceptor::from(Arc::new(build_mitm_server_config(
                &config,
            )?))))
        } else {
            None
        };

        let mut root_store = rustls::RootCertStore::empty();
        root_store.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
        let client_config = rustls::ClientConfig::builder()
            .with_root_certificates(root_store)
            .with_no_client_auth();

        let https = HttpsConnectorBuilder::new()
            .with_tls_config(client_config)
            .https_or_http()
            .enable_http1()
            .enable_http2()
            .build();

        let client = Client::builder(TokioExecutor::new())
            .build(https);

        Ok(Self {
            config,
            sink,
            mitm_acceptor,
            client,
        })
    }

    pub async fn run_with_listener(
        self,
        listener: TcpListener,
        mut shutdown_rx: tokio::sync::oneshot::Receiver<()>,
    ) -> anyhow::Result<()> {
        let server = Arc::new(self);

        loop {
            tokio::select! {
                Ok((stream, addr)) = listener.accept() => {
                    let server_clone = server.clone();
                    tokio::spawn(async move {
                        if let Err(err) = http1::Builder::new()
                            .preserve_header_case(true)
                            .title_case_headers(true)
                            .serve_connection(
                                TokioIo::new(stream),
                                service_fn(move |req| {
                                    let s = server_clone.clone();
                                    async move { s.handle_proxy_request(req, addr).await }
                                }),
                            )
                            .with_upgrades()
                            .await
                        {
                            println!("Error serving connection: {:?}", err);
                        }
                    });
                }
                _ = &mut shutdown_rx => {
                    break;
                }
            }
        }

        Ok(())
    }

    async fn handle_proxy_request(
        self: Arc<Self>,
        mut req: Request<Incoming>,
        client_addr: std::net::SocketAddr,
    ) -> Result<Response<Full<Bytes>>, Infallible> {
        if req.method() == Method::CONNECT {
            let start_time = now_ms();
            let count = SESSION_COUNTER.fetch_add(1, Ordering::Relaxed);
            let session_id = format!("{start_time}_{count}");
            
            let (connect_host, connect_port) = parse_connect_authority(req.uri()).unwrap_or_default();
            let enable_mitm = self.mitm_acceptor.is_some();
            let acceptor = self.mitm_acceptor.clone();
            let proxy_server = self.clone();

            // Log the CONNECT request as a tunnel session
            let session = CaptureSession {
                id: session_id.clone(),
                started_at: start_time,
                protocol: "TUNNEL".to_string(),
                method: "CONNECT".to_string(),
                url: format!("https://{}:{}", connect_host, connect_port),
                host: connect_host.clone(),
                port: connect_port,
                status_code: Some(200),
                status_message: Some("Connection Established".to_string()),
                duration_ms: 0,
                request_bytes: 0,
                response_bytes: 0,
                request_headers: headers_to_map(req.headers()),
                request_body: String::new(),
                response_headers: HashMap::new(),
                response_body: String::new(),
                error: None,
                client_ip: Some(client_addr.ip().to_string()),
                client_port: Some(client_addr.port()),
                server_ip: None,
                process_id: None,
                app_name: None,
                app_path: None,
            };

            // Log the CONNECT request as a tunnel session to show that a connection was attempted
            let _ = self.sink.add(session.clone());

            tokio::spawn(async move {
                let upgraded = match hyper::upgrade::on(&mut req).await {
                    Ok(u) => u,
                    Err(e) => {
                        println!("Failed to upgrade CONNECT request: {:?}", e);
                        return;
                    }
                };

                if enable_mitm {
                    let Some(acceptor) = acceptor else { return; };
                    let tls_stream = match acceptor.accept(TokioIo::new(upgraded)).await {
                        Ok(s) => s,
                        Err(e) => {
                            let mut err_session = session.clone();
                            err_session.id = format!("{}_tls_err", err_session.id);
                            err_session.status_code = Some(502);
                            err_session.status_message = Some("TLS Error".to_string());
                            err_session.error = Some(format!("MITM TLS handshake failed: {:?}", e));
                            let _ = proxy_server.sink.add(err_session);
                            return;
                        }
                    };

                    let alpn = tls_stream
                        .get_ref()
                        .1
                        .alpn_protocol()
                        .map(|v| v.to_vec());

                    let io = TokioIo::new(tls_stream);
                    let handler = MitmHandler {
                        connect_host: connect_host.clone(),
                        connect_port,
                        proxy_server: proxy_server.clone(),
                        client_addr,
                    };

                    let proxy_server_clone = proxy_server.clone();
                    let session_clone = session.clone();

                    if matches!(alpn.as_deref(), Some(b"h2")) {
                        if let Err(e) = http2::Builder::new(TokioExecutor::new())
                            .serve_connection(io, service_fn(move |r| {
                                let h = handler.clone();
                                async move { h.handle_request(r).await }
                            }))
                            .await 
                        {
                            let mut err_session = session_clone;
                            err_session.id = format!("{}_h2_err", err_session.id);
                            err_session.status_code = Some(502);
                            err_session.status_message = Some("H2 Error".to_string());
                            err_session.error = Some(format!("HTTP/2 serve_connection error: {:?}", e));
                            let _ = proxy_server_clone.sink.add(err_session);
                        }
                    } else if let Err(e) = http1::Builder::new()
                        .preserve_header_case(true)
                        .title_case_headers(true)
                        .serve_connection(io, service_fn(move |r| {
                            let h = handler.clone();
                            async move { h.handle_request(r).await }
                        }))
                        .with_upgrades()
                        .await 
                    {
                        let mut err_session = session_clone;
                        err_session.id = format!("{}_h1_err", err_session.id);
                        err_session.status_code = Some(502);
                        err_session.status_message = Some("H1 Error".to_string());
                        err_session.error = Some(format!("HTTP/1.1 serve_connection error: {:?}", e));
                        let _ = proxy_server_clone.sink.add(err_session);
                    }
                } else {
                    let Ok(server) = TcpStream::connect(format!("{}:{}", connect_host, connect_port)).await else {
                        return;
                    };
                    let (mut client_read, mut client_write) = tokio::io::split(TokioIo::new(upgraded));
                    let (mut server_read, mut server_write) = tokio::io::split(server);
                    let _ = tokio::join!(
                        tokio::io::copy(&mut client_read, &mut server_write),
                        tokio::io::copy(&mut server_read, &mut client_write)
                    );
                }
            });

            let mut resp = Response::new(Full::new(Bytes::new()));
            *resp.status_mut() = StatusCode::OK;
            return Ok(resp);
        }

        self.forward_and_capture(req, None, None, client_addr).await
    }

    async fn forward_and_capture(
        self: Arc<Self>,
        mut req: Request<Incoming>,
        force_scheme: Option<&'static str>,
        force_authority: Option<(&str, u16)>,
        client_addr: std::net::SocketAddr,
    ) -> Result<Response<Full<Bytes>>, Infallible> {
        let start_time = now_ms();
        let method = req.method().clone();

        let (target_uri, host, port, scheme) =
            match build_target_uri(&req, force_scheme, force_authority) {
                Ok(v) => v,
                Err(e) => {
                    let mut resp = Response::new(Full::new(Bytes::from(format!("Bad request: {e}"))));
                    *resp.status_mut() = StatusCode::BAD_REQUEST;
                    return Ok(resp);
                }
            };

        let is_upgrade = req.headers().get(UPGRADE).is_some();
        let client_upgrade = if is_upgrade {
            Some(hyper::upgrade::on(&mut req))
        } else {
            None
        };

        let (parts, body) = req.into_parts();
        let req_headers_map = headers_to_map(&parts.headers);
        let req_body_bytes = match body.collect().await {
            Ok(v) => v.to_bytes(),
            Err(e) => {
                let mut resp =
                    Response::new(Full::new(Bytes::from(format!("Failed to read request body: {e}"))));
                *resp.status_mut() = StatusCode::BAD_REQUEST;
                return Ok(resp);
            }
        };

        // Attempt to decompress request body for display
        let decoded_req_body = decompress_body(&req_body_bytes, &req_headers_map).await.unwrap_or_else(|| req_body_bytes.clone());

        let count = SESSION_COUNTER.fetch_add(1, Ordering::Relaxed);
        let session_id = format!("{start_time}_{count}");

        let mut session = CaptureSession {
            id: session_id.clone(),
            started_at: start_time,
            protocol: scheme.to_string(),
            method: method.to_string(),
            url: target_uri.to_string(),
            host: host.to_string(),
            port,
            status_code: None,
            status_message: None,
            duration_ms: 0,
            request_bytes: req_body_bytes.len() as i64,
            response_bytes: 0,
            request_headers: req_headers_map.clone(),
            request_body: decode_body_string(&decoded_req_body, &req_headers_map),
            response_headers: HashMap::new(),
            response_body: String::new(),
            error: None,
            client_ip: Some(client_addr.ip().to_string()),
            client_port: Some(client_addr.port()),
            server_ip: None,
            process_id: None,
            app_name: None,
            app_path: None,
        };

        let _ = self.sink.add(session.clone());

        let mut upstream_req = Request::builder()
            .method(parts.method)
            .uri(target_uri);

        let host_val = if (scheme == "https" && port == 443) || (scheme == "http" && port == 80) {
            host.clone()
        } else {
            format!("{}:{}", host, port)
        };
        upstream_req.headers_mut().unwrap().insert(HOST, hyper::http::HeaderValue::from_str(&host_val).unwrap());
        copy_request_headers(&parts.headers, upstream_req.headers_mut().unwrap());

        if is_upgrade {
            if let Some(upgrade_val) = parts.headers.get(UPGRADE) {
                upstream_req.headers_mut().unwrap().insert(UPGRADE, upgrade_val.clone());
                upstream_req.headers_mut().unwrap().insert(
                    hyper::header::CONNECTION,
                    hyper::http::HeaderValue::from_static("Upgrade"),
                );
            }
        }

        let upstream_req = upstream_req.body(Full::new(req_body_bytes.clone())).unwrap();

        match self.client.request(upstream_req).await {
            Ok(mut res) => {
                let status = res.status();
                let res_headers = res.headers().clone();

                if is_upgrade && status == StatusCode::SWITCHING_PROTOCOLS {
                    let server_upgrade = hyper::upgrade::on(&mut res);
                    if let Some(client_upgrade_fut) = client_upgrade {
                        tokio::spawn(async move {
                            let Ok(client_upgraded) = client_upgrade_fut.await else { return; };
                            let Ok(server_upgraded) = server_upgrade.await else { return; };

                            let (mut c_read, mut c_write) = tokio::io::split(TokioIo::new(client_upgraded));
                            let (mut s_read, mut s_write) = tokio::io::split(TokioIo::new(server_upgraded));

                            let _ = tokio::join!(
                                tokio::io::copy(&mut c_read, &mut s_write),
                                tokio::io::copy(&mut s_read, &mut c_write)
                            );
                        });
                    }

                    session.status_code = Some(status.as_u16());
                    session.status_message = Some("Switching Protocols".to_string());
                    session.response_headers = headers_to_map(&res_headers);
                    session.duration_ms = now_ms() - start_time;
                    let _ = self.sink.add(session);

                    let mut resp = Response::new(Full::new(Bytes::new()));
                    *resp.status_mut() = status;
                    *resp.headers_mut() = res_headers;
                    return Ok(resp);
                }

                let (res_parts, res_body) = res.into_parts();
                let res_bytes = match res_body.collect().await {
                    Ok(v) => v.to_bytes(),
                    Err(_) => Bytes::new(),
                };

                let mut resp = Response::new(Full::new(res_bytes.clone()));
                *resp.status_mut() = status;
                copy_response_headers(&res_parts.headers, resp.headers_mut());

                session.status_code = Some(status.as_u16());
                session.status_message = None;
                session.response_headers = headers_to_map(&res_parts.headers);
                session.response_bytes = res_bytes.len() as i64;
                
                let decoded_res_body = decompress_body(&res_bytes, &session.response_headers).await.unwrap_or_else(|| res_bytes.clone());
                session.response_body = decode_body_string(&decoded_res_body, &session.response_headers);
                session.duration_ms = now_ms() - start_time;
                let _ = self.sink.add(session);

                Ok(resp)
            }
            Err(e) => {
                session.status_message = Some("Error".to_string());
                session.error = Some(e.to_string());
                session.duration_ms = now_ms() - start_time;
                let _ = self.sink.add(session);

                let mut resp = Response::new(Full::new(Bytes::from(format!("Proxy error: {e}"))));
                *resp.status_mut() = StatusCode::BAD_GATEWAY;
                Ok(resp)
            }
        }
    }
}

#[derive(Clone)]
struct MitmHandler {
    connect_host: String,
    connect_port: u16,
    proxy_server: Arc<ProxyServer>,
    client_addr: std::net::SocketAddr,
}

impl MitmHandler {
    async fn handle_request(
        self,
        req: Request<Incoming>,
    ) -> Result<Response<Full<Bytes>>, Infallible> {
        self.proxy_server.forward_and_capture(
            req,
            Some("https"),
            Some((&self.connect_host, self.connect_port)),
            self.client_addr,
        )
        .await
    }
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

fn parse_connect_authority(uri: &Uri) -> Option<(String, u16)> {
    let authority = uri.authority()?.as_str();
    let (h, p) = authority.rsplit_once(':')?;
    let port = p.parse::<u16>().ok()?;
    Some((h.to_string(), port))
}

fn build_target_uri(
    req: &Request<Incoming>,
    force_scheme: Option<&'static str>,
    force_authority: Option<(&str, u16)>,
) -> anyhow::Result<(Uri, String, u16, &'static str)> {
    if let Some((host, port)) = force_authority {
        let scheme = force_scheme.unwrap_or("http");
        let path_and_query = req
            .uri()
            .path_and_query()
            .map(|v| v.as_str())
            .unwrap_or("/");
        let uri = Uri::builder()
            .scheme(scheme)
            .authority(format!("{host}:{port}"))
            .path_and_query(path_and_query)
            .build()?;
        return Ok((uri, host.to_string(), port, scheme));
    }

    if req.uri().scheme_str().is_some() && req.uri().authority().is_some() {
        let scheme = req.uri().scheme_str().unwrap_or("http");
        let host = req.uri().host().unwrap_or("").to_string();
        let port = req
            .uri()
            .port_u16()
            .unwrap_or(if scheme == "https" { 443 } else { 80 });
        return Ok((req.uri().clone(), host, port, if scheme == "https" { "https" } else { "http" }));
    }

    let host_header = req
        .headers()
        .get(HOST)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    let (host, port) = if let Some((h, p)) = host_header.rsplit_once(':') {
        (h.to_string(), p.parse::<u16>().unwrap_or(80))
    } else {
        (host_header.to_string(), 80)
    };
    let scheme = force_scheme.unwrap_or("http");
    let path_and_query = req
        .uri()
        .path_and_query()
        .map(|v| v.as_str())
        .unwrap_or("/");
    let uri = Uri::builder()
        .scheme(scheme)
        .authority(format!("{}:{}", host, port))
        .path_and_query(path_and_query)
        .build()?;
    Ok((uri, host, port, scheme))
}

fn headers_to_map(headers: &hyper::HeaderMap) -> HashMap<String, Vec<String>> {
    let mut out = HashMap::new();
    for (k, v) in headers.iter() {
        out.entry(k.to_string())
            .or_insert_with(Vec::new)
            .push(v.to_str().unwrap_or("").to_string());
    }
    out
}

fn is_hop_by_hop(name: &HeaderName) -> bool {
    let n = name.as_str().to_ascii_lowercase();
    n == "connection"
        || n == "proxy-connection"
        || n == "keep-alive"
        || n == "proxy-authenticate"
        || n == "proxy-authorization"
        || n == "te"
        || n == "trailers"
        || n == "transfer-encoding"
        || n == "upgrade"
}

fn copy_request_headers(src: &hyper::HeaderMap, dst: &mut hyper::HeaderMap) {
    for (k, v) in src.iter() {
        if is_hop_by_hop(k) {
            continue;
        }
        if k == HOST {
            continue;
        }
        dst.append(k, v.clone());
    }
}

fn copy_response_headers(src: &hyper::HeaderMap, dst: &mut hyper::HeaderMap) {
    for (k, v) in src.iter() {
        if is_hop_by_hop(k) {
            continue;
        }
        dst.append(k, v.clone());
    }
}

async fn decompress_body(bytes: &Bytes, headers: &HashMap<String, Vec<String>>) -> Option<Bytes> {
    if bytes.is_empty() {
        return None;
    }
    let encoding = headers
        .get("content-encoding")
        .and_then(|v| v.first())
        .map(|v| v.to_ascii_lowercase())
        .unwrap_or_default();
    
    let mut out = Vec::new();
    if encoding.contains("gzip") {
        let mut decoder = GzipDecoder::new(&mut out);
        decoder.write_all(bytes).await.ok()?;
        decoder.shutdown().await.ok()?;
        Some(Bytes::from(out))
    } else if encoding.contains("deflate") {
        let mut decoder = DeflateDecoder::new(&mut out);
        decoder.write_all(bytes).await.ok()?;
        decoder.shutdown().await.ok()?;
        Some(Bytes::from(out))
    } else if encoding.contains("br") {
        let mut decoder = BrotliDecoder::new(&mut out);
        decoder.write_all(bytes).await.ok()?;
        decoder.shutdown().await.ok()?;
        Some(Bytes::from(out))
    } else if encoding.contains("zstd") {
        let mut decoder = ZstdDecoder::new(&mut out);
        decoder.write_all(bytes).await.ok()?;
        decoder.shutdown().await.ok()?;
        Some(Bytes::from(out))
    } else {
        None
    }
}

fn decode_body_string(bytes: &Bytes, headers: &HashMap<String, Vec<String>>) -> String {
    if bytes.is_empty() {
        return String::new();
    }
    let content_type = headers
        .get("content-type")
        .and_then(|v| v.first())
        .map(|v| v.to_ascii_lowercase())
        .unwrap_or_default();
    let is_textual = content_type.is_empty()
        || content_type.contains("text")
        || content_type.contains("json")
        || content_type.contains("xml")
        || content_type.contains("urlencoded")
        || content_type.contains("javascript");
    if is_textual {
        String::from_utf8_lossy(bytes).to_string()
    } else {
        format!("<!-- Binary data ({} bytes) -->", bytes.len())
    }
}

fn build_mitm_server_config(config: &ProxyConfig) -> anyhow::Result<rustls::ServerConfig> {
    let ca = Arc::new(build_ca(config.ca_cert.as_deref(), config.ca_key.as_deref())?);
    let resolver = Arc::new(MitmCertResolver::new(ca));
    let mut server_config = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_cert_resolver(resolver);
    server_config.alpn_protocols = vec![b"h2".to_vec(), b"http/1.1".to_vec()];
    Ok(server_config)
}

fn build_ca(ca_cert_pem: Option<&str>, ca_key_pem: Option<&str>) -> anyhow::Result<MitmCa> {
    if let (Some(cert_pem), Some(key_pem)) = (ca_cert_pem, ca_key_pem) {
        if !cert_pem.is_empty() && !key_pem.is_empty() {
            let kp = match KeyPair::from_pem(key_pem) {
                Ok(k) => k,
                Err(e) => {
                    return Err(anyhow::anyhow!("Failed to parse key pair: {:?}", e));
                }
            };
            let params = match CertificateParams::from_ca_cert_pem(cert_pem, kp) {
                Ok(p) => p,
                Err(e) => {
                    return Err(anyhow::anyhow!("Failed to parse ca cert pem: {:?}", e));
                }
            };
            let ca = match Certificate::from_params(params) {
                Ok(c) => c,
                Err(e) => {
                    return Err(anyhow::anyhow!("Failed to create certificate from params: {:?}", e));
                }
            };
            let ca_der = match ca.serialize_der() {
                Ok(d) => d,
                Err(e) => {
                    return Err(anyhow::anyhow!("Failed to serialize ca der: {:?}", e));
                }
            };
            return Ok(MitmCa { ca, ca_der });
        }
    }

    let mut params = CertificateParams::default();
    params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
    params.distinguished_name.push(DnType::CommonName, "PostLens Proxy CA");
    let now = OffsetDateTime::now_utc();
    params.not_before = now - Duration::days(1);
    params.not_after = now + Duration::days(3650);
    let ca = Certificate::from_params(params)?;
    let ca_der = ca.serialize_der()?;
    Ok(MitmCa { ca, ca_der })
}
