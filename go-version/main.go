package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/compress"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	gonanoid "github.com/matoous/go-nanoid/v2"
)

// URL model
type URL struct {
	ID          string    `json:"id"`
	OriginalURL string    `json:"original_url"`
	ShortCode   string    `json:"short_code"`
	CreatedAt   time.Time `json:"created_at"`
	AccessCount int64     `json:"access_count"`
}

// CreateURLRequest model
type CreateURLRequest struct {
	URL string `json:"url"`
}

// URLResponse model
type URLResponse struct {
	OriginalURL string    `json:"original_url"`
	ShortCode   string    `json:"short_code"`
	ShortURL    string    `json:"short_url"`
	CreatedAt   time.Time `json:"created_at"`
	AccessCount int64     `json:"access_count"`
}

// AnalyticsResponse model
type AnalyticsResponse struct {
	TotalURLs   int64         `json:"total_urls"`
	TotalClicks int64         `json:"total_clicks"`
	URLs        []URLResponse `json:"urls"`
}

// URLStore is a high-performance URL storage
type URLStore struct {
	store      map[string]*URL
	storeMutex sync.RWMutex
}

// NewURLStore creates a new URLStore
func NewURLStore() *URLStore {
	return &URLStore{
		store: make(map[string]*URL),
	}
}

// Add a URL to the store
func (s *URLStore) Add(shortCode string, url *URL) {
	s.storeMutex.Lock()
	defer s.storeMutex.Unlock()
	s.store[shortCode] = url
}

// Get a URL by short code
func (s *URLStore) Get(shortCode string) (*URL, bool) {
	s.storeMutex.RLock()
	defer s.storeMutex.RUnlock()
	url, exists := s.store[shortCode]
	return url, exists
}

// IncrementAccessCount increments the access count for a URL
func (s *URLStore) IncrementAccessCount(shortCode string) bool {
	s.storeMutex.RLock()
	url, exists := s.store[shortCode]
	s.storeMutex.RUnlock()

	if !exists {
		return false
	}

	// Use atomic operation for concurrent safety
	atomic.AddInt64(&url.AccessCount, 1)
	return true
}

// GetAll returns all URLs
func (s *URLStore) GetAll() []*URL {
	s.storeMutex.RLock()
	defer s.storeMutex.RUnlock()

	urls := make([]*URL, 0, len(s.store))
	for _, url := range s.store {
		urls = append(urls, url)
	}
	return urls
}

// Count returns the number of URLs in the store
func (s *URLStore) Count() int64 {
	s.storeMutex.RLock()
	defer s.storeMutex.RUnlock()
	return int64(len(s.store))
}

// TotalClicks returns the total number of clicks across all URLs
func (s *URLStore) TotalClicks() int64 {
	s.storeMutex.RLock()
	defer s.storeMutex.RUnlock()

	var total int64
	for _, url := range s.store {
		total += url.AccessCount
	}
	return total
}

func main() {
	// Initialize the URL store
	urlStore := NewURLStore()

	// Load the index HTML
	indexHTML, err := os.ReadFile("static/index.html")
	if err != nil {
		indexHTML = []byte("<h1>Failed to load index.html</h1>")
	}

	// Create a new Fiber app with optimized settings
	app := fiber.New(fiber.Config{
		Prefork:       false, // Set to true in production for better performance on multi-core systems
		ServerHeader:  "Fiber",
		StrictRouting: true,
		CaseSensitive: true,
		BodyLimit:     1 * 1024 * 1024, // 1MB
		ReadTimeout:   5 * time.Second,
		WriteTimeout:  5 * time.Second,
		IdleTimeout:   10 * time.Second,
	})

	// Add middleware for better performance and monitoring
	app.Use(compress.New())
	app.Use(cors.New())
	app.Use(logger.New(logger.Config{
		Format: "${time} | ${status} | ${latency} | ${method} | ${path}\n",
	}))

	// Define routes
	app.Get("/", func(c *fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMETextHTML)
		return c.Send(indexHTML)
	})

	app.Post("/api/shorten", func(c *fiber.Ctx) error {
		start := time.Now()

		var req CreateURLRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
		}

		// Basic URL validation
		if !strings.HasPrefix(req.URL, "http://") && !strings.HasPrefix(req.URL, "https://") {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid URL provided"})
		}

		// Generate short code
		shortCode, _ := gonanoid.New(6)

		// Generate unique ID
		id, _ := gonanoid.New(10)

		// Create URL object
		url := &URL{
			ID:          id,
			OriginalURL: req.URL,
			ShortCode:   shortCode,
			CreatedAt:   time.Now(),
			AccessCount: 0,
		}

		// Save to in-memory store
		urlStore.Add(shortCode, url)

		// Log the time taken
		elapsed := time.Since(start)
		log.Printf("[create_short_url] Time taken: %v", elapsed)

		// Get base URL from environment or use default
		baseURL := os.Getenv("BASE_URL")
		if baseURL == "" {
			baseURL = "http://localhost:3000"
		}

		// Return the shortened URL
		return c.JSON(URLResponse{
			OriginalURL: url.OriginalURL,
			ShortCode:   url.ShortCode,
			ShortURL:    fmt.Sprintf("%s/%s", baseURL, url.ShortCode),
			CreatedAt:   url.CreatedAt,
			AccessCount: url.AccessCount,
		})
	})

	app.Get("/:shortCode", func(c *fiber.Ctx) error {
		shortCode := c.Params("shortCode")

		// Get URL from store and increment access count
		url, exists := urlStore.Get(shortCode)
		if !exists {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "URL not found"})
		}

		// Increment access count
		urlStore.IncrementAccessCount(shortCode)

		// Redirect to original URL
		return c.Redirect(url.OriginalURL, fiber.StatusMovedPermanently)
	})

	app.Get("/api/urls", func(c *fiber.Ctx) error {
		// Get all URLs
		urls := urlStore.GetAll()

		// Get base URL from environment or use default
		baseURL := os.Getenv("BASE_URL")
		if baseURL == "" {
			baseURL = "http://localhost:3000"
		}

		// Convert to response DTOs
		responses := make([]URLResponse, 0, len(urls))
		for _, url := range urls {
			responses = append(responses, URLResponse{
				OriginalURL: url.OriginalURL,
				ShortCode:   url.ShortCode,
				ShortURL:    fmt.Sprintf("%s/%s", baseURL, url.ShortCode),
				CreatedAt:   url.CreatedAt,
				AccessCount: url.AccessCount,
			})
		}

		// Sort by creation date descending
		sort.Slice(responses, func(i, j int) bool {
			return responses[i].CreatedAt.After(responses[j].CreatedAt)
		})

		return c.JSON(responses)
	})

	app.Get("/api/analytics", func(c *fiber.Ctx) error {
		// Get all URLs
		urls := urlStore.GetAll()

		// Get base URL from environment or use default
		baseURL := os.Getenv("BASE_URL")
		if baseURL == "" {
			baseURL = "http://localhost:3000"
		}

		// Convert to response DTOs
		responses := make([]URLResponse, 0, len(urls))
		for _, url := range urls {
			responses = append(responses, URLResponse{
				OriginalURL: url.OriginalURL,
				ShortCode:   url.ShortCode,
				ShortURL:    fmt.Sprintf("%s/%s", baseURL, url.ShortCode),
				CreatedAt:   url.CreatedAt,
				AccessCount: url.AccessCount,
			})
		}

		// Sort by access count descending
		sort.Slice(responses, func(i, j int) bool {
			return responses[i].AccessCount > responses[j].AccessCount
		})

		// Calculate analytics
		return c.JSON(AnalyticsResponse{
			TotalURLs:   urlStore.Count(),
			TotalClicks: urlStore.TotalClicks(),
			URLs:        responses,
		})
	})

	// Setup graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-quit
		fmt.Println("Shutting down server...")
		if err := app.Shutdown(); err != nil {
			fmt.Printf("Error shutting down server: %v\n", err)
		}
	}()

	// Start the server
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	log.Printf("Listening on 0.0.0.0:%s", port)
	if err := app.Listen(fmt.Sprintf("0.0.0.0:%s", port)); err != nil {
		log.Fatalf("Error starting server: %v", err)
	}
}
