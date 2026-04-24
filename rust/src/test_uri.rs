use hyper::Uri;

fn main() {
    let uri = "example.com:443".parse::<Uri>().unwrap();
    println!("authority: {:?}", uri.authority().map(|a| a.as_str()));
    println!("path_and_query: {:?}", uri.path_and_query().map(|p| p.as_str()));
}
