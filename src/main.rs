use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    response::{Html, IntoResponse, Redirect, Response},
    routing::{get, post},
};
use chrono::{DateTime, Utc};
use dashmap::DashMap;
use nanoid::nanoid;
use serde::{Deserialize, Serialize};
use std::time::Instant;
use std::{
    env,
    net::SocketAddr,
    sync::Arc,
};
use thiserror::Error;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

// App state
#[derive(Clone)]
struct AppState {
    urls: Arc<DashMap<String, Url>>,
    index_html: String,
}

// URL model
#[derive(Debug, Serialize, Deserialize, Clone)]
struct Url {
    id: String,
    original_url: String,
    short_code: String,
    created_at: DateTime<Utc>,
    access_count: i64,
}

// DTO for creating a new short URL
#[derive(Debug, Deserialize)]
struct CreateUrlRequest {
    url: String,
}

// DTO for URL response
#[derive(Debug, Serialize)]
struct UrlResponse {
    original_url: String,
    short_code: String,
    short_url: String,
    created_at: DateTime<Utc>,
    access_count: i64,
}

// DTO for analytics response
#[derive(Debug, Serialize)]
struct AnalyticsResponse {
    total_urls: i64,
    total_clicks: i64,
    urls: Vec<UrlResponse>,
}

// Error types
#[derive(Debug, Error)]
enum AppError {
    #[error("Not found")]
    NotFound,
    #[error("Invalid URL")]
    InvalidUrl,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::NotFound => (StatusCode::NOT_FOUND, "URL not found".to_string()),
            AppError::InvalidUrl => (StatusCode::BAD_REQUEST, "Invalid URL provided".to_string()),
        };
        (status, Json(serde_json::json!({ "error": message }))).into_response()
    }
}

type Result<T> = std::result::Result<T, AppError>;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into()),
        ))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let index_html = tokio::fs::read_to_string("static/index.html")
        .await
        .unwrap_or_else(|_| "<h1>Failed to load index.html</h1>".to_string());
    let state = Arc::new(AppState {
        urls: Arc::new(DashMap::new()),
        index_html,
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/", get(index_handler))
        .route("/api/shorten", post(create_short_url))
        .route("/api/urls", get(get_all_urls))
        .route("/api/analytics", get(get_analytics))
        .route("/{short_code}", get(redirect_to_original))
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    tracing::info!("Listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    // Graceful shutdown: listen for SIGINT or SIGTERM
    let shutdown_signal = async {
        use tokio::signal;
        
        // SIGINT handler (Ctrl+C)
        let ctrl_c = async {
            signal::ctrl_c().await.expect("Failed to install CTRL+C handler");
            tracing::info!("Received SIGINT (Ctrl+C), shutting down");
        };

        // SIGTERM handler (docker stop, kill -15, etc.)
        #[cfg(unix)]
        let terminate = async {
            signal::unix::signal(signal::unix::SignalKind::terminate())
                .expect("Failed to install SIGTERM handler")
                .recv()
                .await;
            tracing::info!("Received SIGTERM, shutting down");
        };

        #[cfg(not(unix))]
        let terminate = std::future::pending::<()>();

        // Wait for either signal
        tokio::select! {
            _ = ctrl_c => {},
            _ = terminate => {},
        }
    };

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal)
        .await?;
    Ok(())
}

// Handlers

// Serve index.html from static directory (now from memory)
async fn index_handler(State(state): State<Arc<AppState>>) -> Html<String> {
    Html(state.index_html.clone())
}

// Create a short URL
async fn create_short_url(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<CreateUrlRequest>,
) -> Result<Json<UrlResponse>> {
    let start = Instant::now();
    
    // Basic URL validation 
    if !payload.url.starts_with("http://") && !payload.url.starts_with("https://") {
        return Err(AppError::InvalidUrl);
    }
    
    // Generate a short code (only clone once for the URL struct)
    let short_code = nanoid!(6);
    
    // Get current time
    let now = Utc::now();
    
    // Get base URL from environment or use default
    let base_url = env::var("BASE_URL").unwrap_or_else(|_| "http://localhost:3000".to_string());
    
    // Create URL object (avoid cloning where possible)
    let url = Url {
        id: nanoid!(10),
        original_url: payload.url,
        short_code: short_code.clone(),
        created_at: now,
        access_count: 0,
    };
    
    // Save to in-memory store
    state.urls.insert(short_code.clone(), url.clone());
    
    // Log the time taken
    let elapsed = start.elapsed();
    tracing::debug!("[create_short_url] Time taken: {:?}", elapsed);
    
    // Return the shortened URL (avoid unnecessary clones)
    let short_url = format!("{}/{}", base_url, short_code);
    
    Ok(Json(UrlResponse {
        original_url: url.original_url,
        short_code: url.short_code,
        short_url,
        created_at: url.created_at,
        access_count: url.access_count,
    }))
}

// Redirect to original URL
async fn redirect_to_original(
    State(state): State<Arc<AppState>>,
    Path(short_code): Path<String>,
) -> Result<Redirect> {
    // Get the URL entry if it exists
    let mut entry = state.urls.get_mut(&short_code).ok_or(AppError::NotFound)?;

    // Increment access count
    entry.access_count += 1;

    // Redirect to the original URL (clone only what we need)
    Ok(Redirect::permanent(&entry.original_url))
}

// Get all URLs
async fn get_all_urls(State(state): State<Arc<AppState>>) -> Result<Json<Vec<UrlResponse>>> {
    // Get base URL from environment or use default
    let base_url = env::var("BASE_URL").unwrap_or_else(|_| "http://localhost:3000".to_string());

    // Transform to response DTOs without locking the entire map
    let mut url_responses: Vec<_> = state.urls
        .iter()
        .map(|entry| {
            let url = entry.value();
            UrlResponse {
                original_url: url.original_url.clone(),
                short_code: url.short_code.clone(),
                short_url: format!("{}/{}", base_url, url.short_code),
                created_at: url.created_at,
                access_count: url.access_count,
            }
        })
        .collect();

    // Sort by creation date descending
    url_responses.sort_by(|a, b| b.created_at.cmp(&a.created_at));

    Ok(Json(url_responses))
}

// Get analytics
async fn get_analytics(State(state): State<Arc<AppState>>) -> Result<Json<AnalyticsResponse>> {
    // Calculate totals and get URLs in one pass without locking everything
    let total_urls = state.urls.len() as i64;
    let mut total_clicks: i64 = 0;
    
    // Get base URL from environment or use default
    let base_url = env::var("BASE_URL").unwrap_or_else(|_| "http://localhost:3000".to_string());

    // Transform to response DTOs
    let mut url_responses: Vec<_> = state.urls
        .iter()
        .map(|entry| {
            let url = entry.value();
            total_clicks += url.access_count;
            UrlResponse {
                original_url: url.original_url.clone(),
                short_code: url.short_code.clone(),
                short_url: format!("{}/{}", base_url, url.short_code),
                created_at: url.created_at,
                access_count: url.access_count,
            }
        })
        .collect();

    // Sort by access count descending
    url_responses.sort_by(|a, b| b.access_count.cmp(&a.access_count));

    Ok(Json(AnalyticsResponse {
        total_urls,
        total_clicks,
        urls: url_responses,
    }))
}
