package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"runtime"
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
	store      sync.Map // Use sync.Map instead of map with mutex for better concurrency
	urlCount   atomic.Int64
	clickCount atomic.Int64
}

// NewURLStore creates a new URLStore
func NewURLStore() *URLStore {
	return &URLStore{}
}

// Add a URL to the store
func (s *URLStore) Add(shortCode string, url *URL) {
	s.store.Store(shortCode, url)
	s.urlCount.Add(1)
}

// Get a URL by short code
func (s *URLStore) Get(shortCode string) (*URL, bool) {
	value, exists := s.store.Load(shortCode)
	if !exists {
		return nil, false
	}
	return value.(*URL), true
}

// IncrementAccessCount increments the access count for a URL
func (s *URLStore) IncrementAccessCount(shortCode string) bool {
	value, exists := s.store.Load(shortCode)
	if !exists {
		return false
	}

	url := value.(*URL)
	newCount := atomic.AddInt64(&url.AccessCount, 1)
	s.clickCount.Add(1) // Update total click count

	// No need to store back since we're modifying the pointer's data
	_ = newCount
	return true
}

// GetAll returns all URLs
func (s *URLStore) GetAll() []*URL {
	var urls []*URL

	// Range over the sync.Map
	s.store.Range(func(key, value interface{}) bool {
		urls = append(urls, value.(*URL))
		return true
	})

	return urls
}

// Count returns the number of URLs in the store
func (s *URLStore) Count() int64 {
	return s.urlCount.Load()
}

// TotalClicks returns the total number of clicks across all URLs
func (s *URLStore) TotalClicks() int64 {
	return s.clickCount.Load()
}

func main() {
	// Initialize the URL store
	urlStore := NewURLStore()

	// Load the index HTML
	indexHTML, err := os.ReadFile("static/index.html")
	if err != nil {
		indexHTML = []byte("<h1>Failed to load index.html</h1>")
	}

	// Check if running in Docker or container environment
	inContainer := os.Getenv("IN_CONTAINER") == "true"

	// Create a new Fiber app with optimized settings
	app := fiber.New(fiber.Config{
		Prefork:               !inContainer, // Disable prefork in container to prevent port conflicts
		ServerHeader:          "Fiber",
		StrictRouting:         true,
		CaseSensitive:         true,
		BodyLimit:             1 * 1024 * 1024, // 1MB
		ReadTimeout:           5 * time.Second,
		WriteTimeout:          5 * time.Second,
		IdleTimeout:           10 * time.Second,
		DisableStartupMessage: true,       // Reduce startup overhead
		ReduceMemoryUsage:     true,       // Optimize memory usage
		Concurrency:           256 * 1024, // Higher concurrency limit
		// JSONEncoder and JSONDecoder can be customized with custom encoders
	})

	// Get environment variables for performance tuning
	maxProcs := os.Getenv("GOMAXPROCS")
	if maxProcs == "" {
		// Default to number of CPUs
		maxProcs = fmt.Sprintf("%d", runtime.NumCPU())
		os.Setenv("GOMAXPROCS", maxProcs)
	}

	// Add middleware for better performance and monitoring
	app.Use(compress.New(compress.Config{
		Level: compress.LevelBestSpeed,
	}))
	app.Use(cors.New())
	app.Use(logger.New(logger.Config{
		Format: "${time} | ${status} | ${latency} | ${method} | ${path}\n",
	}))

	// Define routes
	app.Get("/", func(c *fiber.Ctx) error {
		return c.Type("html").Send(indexHTML)
	})

	// Use a pooled object for request/response to reduce allocations
	type pooledURLResponse struct {
		resp URLResponse
		req  CreateURLRequest
	}

	// Set up a sync.Pool for URLResponse objects to reduce garbage collection
	urlRespPool := sync.Pool{
		New: func() interface{} {
			return new(pooledURLResponse)
		},
	}

	app.Post("/api/shorten", func(c *fiber.Ctx) error {
		// Get object from pool
		pooled := urlRespPool.Get().(*pooledURLResponse)
		defer urlRespPool.Put(pooled)

		// Reset values
		pooled.req.URL = ""

		if err := c.BodyParser(&pooled.req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
		}

		// Basic URL validation
		if !strings.HasPrefix(pooled.req.URL, "http://") && !strings.HasPrefix(pooled.req.URL, "https://") {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid URL provided"})
		}

		// Generate short code
		shortCode, _ := gonanoid.New(6)

		// Generate unique ID
		id, _ := gonanoid.New(10)

		// Create URL object
		url := &URL{
			ID:          id,
			OriginalURL: pooled.req.URL,
			ShortCode:   shortCode,
			CreatedAt:   time.Now(),
			AccessCount: 0,
		}

		// Save to in-memory store
		urlStore.Add(shortCode, url)

		// Get base URL from environment or use default
		baseURL := os.Getenv("BASE_URL")
		if baseURL == "" {
			baseURL = "http://localhost:3000"
		}

		// Prepare response using the pooled object
		pooled.resp.OriginalURL = url.OriginalURL
		pooled.resp.ShortCode = url.ShortCode
		pooled.resp.ShortURL = fmt.Sprintf("%s/%s", baseURL, url.ShortCode)
		pooled.resp.CreatedAt = url.CreatedAt
		pooled.resp.AccessCount = url.AccessCount

		// Return the shortened URL
		return c.JSON(pooled.resp)
	})

	app.Get("/:shortCode", func(c *fiber.Ctx) error {
		shortCode := c.Params("shortCode", "")
		if shortCode == "" {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "URL not found"})
		}

		// Get URL from store
		url, exists := urlStore.Get(shortCode)
		if !exists {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "URL not found"})
		}

		// Increment access count asynchronously to avoid blocking
		go urlStore.IncrementAccessCount(shortCode)

		// Redirect to original URL
		c.Set(fiber.HeaderCacheControl, "public, max-age=86400") // Cache for 24 hours
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

		// Pre-allocate the exact size needed to avoid resizing
		responses := make([]URLResponse, 0, len(urls))

		// Process in batches for better cache locality
		const batchSize = 64
		for i := 0; i < len(urls); i += batchSize {
			end := i + batchSize
			if end > len(urls) {
				end = len(urls)
			}

			// Process this batch
			for j := i; j < end; j++ {
				url := urls[j]
				responses = append(responses, URLResponse{
					OriginalURL: url.OriginalURL,
					ShortCode:   url.ShortCode,
					ShortURL:    fmt.Sprintf("%s/%s", baseURL, url.ShortCode),
					CreatedAt:   url.CreatedAt,
					AccessCount: url.AccessCount,
				})
			}
		}

		// Sort by creation date descending - use more efficient sort if possible
		if len(responses) > 0 {
			sort.Slice(responses, func(i, j int) bool {
				return responses[i].CreatedAt.After(responses[j].CreatedAt)
			})
		}

		// Set cache headers for better client-side caching
		c.Set(fiber.HeaderCacheControl, "private, max-age=10") // Cache for 10 seconds
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

		// Pre-allocate the exact size needed
		responses := make([]URLResponse, 0, len(urls))

		// Convert to response DTOs with better batch processing
		const batchSize = 64
		for i := 0; i < len(urls); i += batchSize {
			end := i + batchSize
			if end > len(urls) {
				end = len(urls)
			}

			for j := i; j < end; j++ {
				url := urls[j]
				responses = append(responses, URLResponse{
					OriginalURL: url.OriginalURL,
					ShortCode:   url.ShortCode,
					ShortURL:    fmt.Sprintf("%s/%s", baseURL, url.ShortCode),
					CreatedAt:   url.CreatedAt,
					AccessCount: url.AccessCount,
				})
			}
		}

		// Sort by access count descending - use more efficient sort if possible
		if len(responses) > 0 {
			sort.Slice(responses, func(i, j int) bool {
				return responses[i].AccessCount > responses[j].AccessCount
			})
		}

		// Use cached count values for better performance
		analytics := AnalyticsResponse{
			TotalURLs:   urlStore.Count(),
			TotalClicks: urlStore.TotalClicks(),
			URLs:        responses,
		}

		// Set cache headers
		c.Set(fiber.HeaderCacheControl, "private, max-age=5") // Cache for 5 seconds
		return c.JSON(analytics)
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

	// Better logging about the server mode
	isPrefork := app.Config().Prefork
	cpuCount := runtime.NumCPU()
	if isPrefork {
		log.Printf("Starting in prefork mode with %d CPU cores", cpuCount)
	} else {
		if inContainer {
			log.Printf("Starting in single process mode (prefork disabled in container environment)")
		} else {
			log.Printf("Starting in single process mode (prefork disabled)")
		}
	}

	log.Printf("Listening on 0.0.0.0:%s", port)
	if err := app.Listen(fmt.Sprintf("0.0.0.0:%s", port)); err != nil {
		log.Fatalf("Error starting server: %v", err)
	}
}
