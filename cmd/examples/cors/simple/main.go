package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
)

// Notice the %s inside the fetch() call. This is where we will inject the URL.
const htmlTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Simple CORS</h1>
    <div id="output"></div>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
        	// The Go server will replace the placeholder below...
            fetch("%s/v1/healthcheck").then(
                function (response) {
                    response.text().then(function (text) {
                        document.getElementById("output").innerHTML = text;
                    });
                },
                function(err) {
                    document.getElementById("output").innerHTML = err;
                }
            );
        });
    </script>
</body>
</html>`

func main() {
	addr := flag.String("addr", ":4001", "Server address")
	flag.Parse()

	// Read the environment variable.
	apiUrl := os.Getenv("API_URL")

	// Provide a sensible fallback just in case the .envrc isn't loaded
	if apiUrl == "" {
		log.Println("Warning: API_URL environment variable not found. Defaulting to localhost.")
		apiUrl = "http://localhost:4000"
	}

	log.Printf("starting frontend server on %s", *addr)
	log.Printf("frontend will make API calls to %s", apiUrl)

	err := http.ListenAndServe(*addr, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Inject the apiUrl into the htmlTemplate and send it to the browser
		htmlContent := fmt.Sprintf(htmlTemplate, apiUrl)
		w.Write([]byte(htmlContent))
	}))
	log.Fatal(err)
}
