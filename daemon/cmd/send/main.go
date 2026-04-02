package main

import (
	"fmt"
	"net"
	"os"
	"time"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "usage: send --socket <path> <json>\n")
		os.Exit(1)
	}

	var socketPath, payload string
	for i := 1; i < len(os.Args); i++ {
		if os.Args[i] == "--socket" && i+1 < len(os.Args) {
			socketPath = os.Args[i+1]
			i++
		} else {
			payload = os.Args[i]
		}
	}

	if socketPath == "" || payload == "" {
		fmt.Fprintf(os.Stderr, "usage: send --socket <path> <json>\n")
		os.Exit(1)
	}

	conn, err := net.DialTimeout("unix", socketPath, 2*time.Second)
	if err != nil {
		os.Exit(0)
	}
	defer conn.Close()

	conn.SetDeadline(time.Now().Add(2 * time.Second))
	fmt.Fprintln(conn, payload)
}
