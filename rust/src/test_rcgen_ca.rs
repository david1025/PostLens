use rcgen::{BasicConstraints, Certificate, CertificateParams, DnType, IsCa, KeyPair};
fn main() {
    let key_pair = KeyPair::generate(&rcgen::PKCS_RSA_SHA256).unwrap();
    let mut params = CertificateParams::new(vec![]);
    params.alg = &rcgen::PKCS_RSA_SHA256;
    params.key_pair = Some(key_pair);
    params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
    params.distinguished_name.push(DnType::CommonName, "PostLens Proxy CA");
    
    let ca = Certificate::from_params(params).unwrap();
    let cert_pem = ca.serialize_pem().unwrap();
    println!("{}", cert_pem);
}
