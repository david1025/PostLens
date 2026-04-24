use hyper_util::client::legacy::Client;
use hyper_rustls::HttpsConnectorBuilder;
use hyper_util::rt::TokioExecutor;
use http_body_util::Full;
use bytes::Bytes;

#[tokio::main]
async fn main() {
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();
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
        .build::<_, Full<Bytes>>(https);

    let req = hyper::Request::builder()
        .uri("https://www.baidu.com")
        .body(Full::new(Bytes::new()))
        .unwrap();

    match client.request(req).await {
        Ok(res) => println!("Success: {}", res.status()),
        Err(e) => println!("Error: {:?}", e),
    }
}
