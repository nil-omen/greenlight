package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
)

const htmlTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Preflight CORS</h1>
    <div id="output"></div>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            fetch("%s/v1/tokens/authentication", {
                method: "POST",
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    email: 'alice@example.com',
                    password: 'pa55word'
                })
            }).then(
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

	apiUrl := os.Getenv("API_URL")

	if apiUrl == "" {
		log.Println("Warning: API_URL environment variable not found. Defaulting to localhost.")
		apiUrl = "http://localhost:4000"
	}

	log.Printf("starting frontend server on %s", *addr)
	log.Printf("frontend will make API calls to %s", apiUrl)

	err := http.ListenAndServe(*addr, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		htmlContent := fmt.Sprintf(htmlTemplate, apiUrl)
		_, err := w.Write([]byte(htmlContent))
		if err != nil {
			log.Println("write error:", err)
		}
	}))
	log.Fatal(err)
}
