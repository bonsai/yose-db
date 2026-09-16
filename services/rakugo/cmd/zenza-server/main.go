package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	rakugo "github.com/bonsai/yose-db/services/rakugo"
	zenza "github.com/bonsai/yose-db/services/rakugo/internal/zenza"
)

// The zenza-count HTTP service. Serves the committed zenza_counts.json
// snapshot (read-only, embedded at build time).
//
// GET /rakugo/zenza_counts — generated dataset
// GET /healthz               — liveness
func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthz)
	mux.HandleFunc("GET /rakugo/zenza_counts", serveCounts)

	log.Printf("rakugo-zenza listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func serveCounts(w http.ResponseWriter, r *http.Request) {
	var d zenza.Dataset
	if err := json.Unmarshal(rakugo.CountsJSON, &d); err != nil {
		http.Error(w, "zenza_counts.json is invalid: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Write(rakugo.CountsJSON)
}

func healthz(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "ok")
}
