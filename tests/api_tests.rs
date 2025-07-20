use reqwest;
use serde_json::Value;
use std::process::{Child, Command};
use std::thread::sleep;
use std::time::Duration;

// Helper function to start the server
fn start_server() -> Child {
    println!("Starting server...");
    let server = Command::new("cargo")
        .args(["run", "--release"])
        .spawn()
        .expect("Failed to start the server");

    // Give the server some time to start
    sleep(Duration::from_secs(2));

    server
}

// Test creating a short URL
#[tokio::test]
async fn test_create_short_url() {
    let mut server = start_server();

    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:3000/api/shorten")
        .json(&serde_json::json!({
            "url": "https://www.rust-lang.org"
        }))
        .send()
        .await
        .expect("Failed to execute request");

    assert!(response.status().is_success());

    let body = response
        .json::<Value>()
        .await
        .expect("Failed to parse response");

    assert!(body.get("short_code").is_some());
    assert!(body.get("short_url").is_some());
    assert_eq!(body["original_url"], "https://www.rust-lang.org");

    let short_code = body["short_code"].as_str().unwrap();

    // Test the redirect
    let redirect_response = client
        .get(format!("http://localhost:3000/{}", short_code))
        .send()
        .await
        .expect("Failed to execute redirect request");

    assert!(redirect_response.status().is_success());

    // Stop the server
    server.kill().expect("Failed to kill the server");
}

// Test analytics endpoint
#[tokio::test]
async fn test_analytics() {
    let mut server = start_server();

    // Create a short URL first
    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:3000/api/shorten")
        .json(&serde_json::json!({
            "url": "https://www.rust-lang.org"
        }))
        .send()
        .await
        .expect("Failed to execute request");

    let body = response
        .json::<Value>()
        .await
        .expect("Failed to parse response");
    let short_code = body["short_code"].as_str().unwrap();

    // Visit the short URL to increment the counter
    let _ = client
        .get(format!("http://localhost:3000/{}", short_code))
        .send()
        .await
        .expect("Failed to execute redirect request");

    // Get analytics
    let analytics_response = client
        .get("http://localhost:3000/api/analytics")
        .send()
        .await
        .expect("Failed to execute analytics request");

    assert!(analytics_response.status().is_success());

    let analytics_body = analytics_response
        .json::<Value>()
        .await
        .expect("Failed to parse analytics response");

    assert!(analytics_body.get("total_urls").is_some());
    assert!(analytics_body.get("total_clicks").is_some());
    assert!(analytics_body.get("urls").is_some());

    // Stop the server
    server.kill().expect("Failed to kill the server");
}

// Test invalid URL
#[tokio::test]
async fn test_invalid_url() {
    let mut server = start_server();

    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:3000/api/shorten")
        .json(&serde_json::json!({
            "url": "invalid-url"
        }))
        .send()
        .await
        .expect("Failed to execute request");

    assert_eq!(response.status().as_u16(), 400); // Bad Request

    // Stop the server
    server.kill().expect("Failed to kill the server");
}

// Test not found
#[tokio::test]
async fn test_not_found() {
    let mut server = start_server();

    let client = reqwest::Client::new();
    let response = client
        .get("http://localhost:3000/nonexistent")
        .send()
        .await
        .expect("Failed to execute request");

    assert_eq!(response.status().as_u16(), 404); // Not Found

    // Stop the server
    server.kill().expect("Failed to kill the server");
}
