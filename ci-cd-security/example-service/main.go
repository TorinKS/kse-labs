package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type Response struct {
	Status    string `json:"status"`
	Message   string `json:"message"`
	Timestamp string `json:"timestamp"`
}

type HelloRequest struct {
	Name string `json:"name"`
}

type HelloResponse struct {
	Greeting  string `json:"greeting"`
	Timestamp string `json:"timestamp"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/hello", helloHandler)
	http.HandleFunc("/api/v1/hello", helloAPIHandler)
	http.HandleFunc("/version", versionHandler)

	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

// GET /health - Health check
func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	resp := Response{
		Status:    "healthy",
		Message:   "Service is running",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	jsonResponse(w, http.StatusOK, resp)
}

// GET /hello?name=World - Simple hello endpoint
func helloHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	name := r.URL.Query().Get("name")
	if name == "" {
		name = "World"
	}

	resp := HelloResponse{
		Greeting:  "Hello, " + name + "!",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	jsonResponse(w, http.StatusOK, resp)
}

// POST /api/v1/hello - Hello with JSON body
func helloAPIHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req HelloRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		req.Name = "World"
	}

	resp := HelloResponse{
		Greeting:  "Hello, " + req.Name + "!",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	jsonResponse(w, http.StatusOK, resp)
}

// GET /version - Version info
func versionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	resp := map[string]string{
		"version": "1.0.0",
		"service": "example-service",
	}
	jsonResponse(w, http.StatusOK, resp)
}

func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
