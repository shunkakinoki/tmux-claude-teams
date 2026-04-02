package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

type AgentEvent struct {
	Event       string `json:"event"`
	AgentID     string `json:"agent_id"`
	Description string `json:"description,omitempty"`
	Result      string `json:"result,omitempty"`
}

type AgentState struct {
	PaneID      string
	Description string
	StatusFile  string
}

var (
	agents     = make(map[string]*AgentState)
	mu         sync.Mutex
	tmuxBin    string
	targetPane string
	pluginDir  string
)

func main() {
	socketPath := flag.String("socket", "/tmp/claude-teams.sock", "unix socket path")
	tmux := flag.String("tmux", "tmux", "path to real tmux binary")
	pane := flag.String("pane", "", "target tmux pane ID")
	dir := flag.String("plugin-dir", "", "plugin directory")
	parentPID := flag.Int("parent-pid", 0, "parent PID to watch")
	flag.Parse()

	tmuxBin = *tmux
	targetPane = *pane
	pluginDir = *dir

	os.Remove(*socketPath)

	listener, err := net.Listen("unix", *socketPath)
	if err != nil {
		log.Fatalf("listen: %v", err)
	}
	defer os.Remove(*socketPath)
	defer listener.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Watch parent process
	if *parentPID > 0 {
		go watchParent(*parentPID, cancel)
	}

	// Handle signals
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		select {
		case <-sig:
			cancel()
		case <-ctx.Done():
		}
	}()

	// Close listener when context is done
	go func() {
		<-ctx.Done()
		listener.Close()
	}()

	log.Printf("daemon started on %s (watching pane %s)", *socketPath, targetPane)

	for {
		conn, err := listener.Accept()
		if err != nil {
			if ctx.Err() != nil {
				break
			}
			continue
		}
		go handleConn(conn)
	}

	cleanup()
}

func watchParent(pid int, cancel context.CancelFunc) {
	for {
		if err := syscall.Kill(pid, 0); err != nil {
			log.Printf("parent %d exited, shutting down", pid)
			cancel()
			return
		}
		time.Sleep(2 * time.Second)
	}
}

func handleConn(conn net.Conn) {
	defer conn.Close()

	var evt AgentEvent
	if err := json.NewDecoder(conn).Decode(&evt); err != nil {
		log.Printf("decode error: %v", err)
		return
	}

	switch evt.Event {
	case "agent_start":
		handleAgentStart(evt)
	case "agent_stop":
		handleAgentStop(evt)
	}

	conn.Write([]byte(`{"ok":true}` + "\n"))
}

func handleAgentStart(evt AgentEvent) {
	mu.Lock()
	defer mu.Unlock()

	if _, exists := agents[evt.AgentID]; exists {
		return
	}

	// Create status file
	statusFile := fmt.Sprintf("/tmp/claude-teams-agent-%s.status", sanitizeID(evt.AgentID))
	desc := evt.Description
	if len(desc) > 200 {
		desc = desc[:200] + "..."
	}
	os.WriteFile(statusFile, []byte("RUNNING\n"+desc), 0644)

	// Create tmux split pane running pane-status.sh
	paneScript := pluginDir + "/scripts/pane-status.sh"
	cmd := exec.Command(tmuxBin, "split-window", "-h", "-t", targetPane,
		fmt.Sprintf("%s %s", paneScript, statusFile))
	if err := cmd.Run(); err != nil {
		log.Printf("split-window failed: %v", err)
		os.Remove(statusFile)
		return
	}

	// Get the new pane ID
	out, err := exec.Command(tmuxBin, "display-message", "-p", "-t", "{last}", "#{pane_id}").Output()
	if err != nil {
		log.Printf("display-message failed: %v", err)
		return
	}
	paneID := strings.TrimSpace(string(out))

	// Rebalance layout
	exec.Command(tmuxBin, "select-layout", "-t", targetPane, "main-vertical").Run()

	agents[evt.AgentID] = &AgentState{
		PaneID:      paneID,
		Description: desc,
		StatusFile:  statusFile,
	}

	log.Printf("agent_start: %s -> pane %s (%s)", evt.AgentID, paneID, desc)
}

func handleAgentStop(evt AgentEvent) {
	mu.Lock()
	agent, exists := agents[evt.AgentID]
	if !exists {
		mu.Unlock()
		return
	}
	delete(agents, evt.AgentID)
	mu.Unlock()

	// Update status file to DONE
	result := evt.Result
	if result == "" {
		result = "completed"
	}
	if len(result) > 500 {
		result = result[:500] + "..."
	}
	os.WriteFile(agent.StatusFile, []byte("DONE\n"+result), 0644)

	log.Printf("agent_stop: %s (pane %s)", evt.AgentID, agent.PaneID)

	// Wait for pane-status.sh to show the result, then kill pane
	go func() {
		time.Sleep(3 * time.Second)
		exec.Command(tmuxBin, "kill-pane", "-t", agent.PaneID).Run()
		exec.Command(tmuxBin, "select-layout", "-t", targetPane, "main-vertical").Run()
		os.Remove(agent.StatusFile)
	}()
}

func cleanup() {
	mu.Lock()
	defer mu.Unlock()
	for id, agent := range agents {
		exec.Command(tmuxBin, "kill-pane", "-t", agent.PaneID).Run()
		os.Remove(agent.StatusFile)
		delete(agents, id)
	}
}

func sanitizeID(id string) string {
	r := strings.NewReplacer("/", "-", " ", "-", ":", "-")
	s := r.Replace(id)
	if len(s) > 40 {
		s = s[:40]
	}
	return s
}
