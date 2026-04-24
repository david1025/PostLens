#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();
    flutter_rust_bridge::setup_default_user_utils();
}
