import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_main():
    """Test that the root endpoint returns a 200 status code."""
    response = client.get("/")
    assert response.status_code == 200
    assert "<html" in response.text.lower()

def test_create_short_url():
    """Test that the API can create a shortened URL."""
    response = client.post(
        "/api/shorten",
        json={"url": "https://example.com"}
    )
    assert response.status_code == 200
    assert "original_url" in response.json()
    assert "short_code" in response.json()
    assert response.json()["original_url"] == "https://example.com"
    assert len(response.json()["short_code"]) == 6

def test_redirect():
    """Test that the API redirects to the original URL."""
    # First create a shortened URL
    create_response = client.post(
        "/api/shorten",
        json={"url": "https://example.com/redirect-test"}
    )
    short_code = create_response.json()["short_code"]
    
    # Then test the redirect
    response = client.get(f"/{short_code}", allow_redirects=False)
    assert response.status_code == 301
    assert response.headers["location"] == "https://example.com/redirect-test"

def test_get_all_urls():
    """Test that the API returns a list of all URLs."""
    response = client.get("/api/urls")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_get_analytics():
    """Test that the API returns analytics data."""
    response = client.get("/api/analytics")
    assert response.status_code == 200
    assert "total_urls" in response.json()
    assert "total_clicks" in response.json()
    assert "urls" in response.json()
