package main

import (
	"context"
	"encoding/json"
	"flag"
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
	PaneID      string `json:"pane_id"`
	Description string `json:"description,omitempty"`
	Result      string `json:"result,omitempty"`
}

type AgentState struct {
	AgentPaneID string // the new pane created for this agent
	LeaderPane  string // the pane Claude is running in
	Description string
	StatusFile  string
}

var (
	agents    = make(map[string]*AgentState)
	mu        sync.Mutex
	tmuxBin   string
	pluginDir string
)

func main() {
	socketPath := flag.String("socket", "/tmp/claude-teams.sock", "unix socket path")
	tmux := flag.String("tmux", "tmux", "path to real tmux binary")
	dir := flag.String("plugin-dir", "", "plugin directory")
	flag.Parse()

	tmuxBin = *tmux
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

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		select {
		case <-sig:
			cancel()
		case <-ctx.Done():
		}
	}()

	go func() {
		<-ctx.Done()
		listener.Close()
	}()

	log.Printf("daemon started on %s", *socketPath)

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

	leaderPane := evt.PaneID
	if leaderPane == "" {
		log.Printf("agent_start: no pane_id, skipping")
		return
	}

	// Create status file
	statusFile := "/tmp/claude-teams-agent-" + sanitizeID(evt.AgentID) + ".status"
	desc := evt.Description
	if len(desc) > 200 {
		desc = desc[:200] + "..."
	}
	os.WriteFile(statusFile, []byte("RUNNING\n"+desc), 0644)

	// Create tmux split pane
	paneScript := pluginDir + "/scripts/pane-status.sh"
	cmd := exec.Command(tmuxBin, "split-window", "-h", "-t", leaderPane, paneScript+" "+statusFile)
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
	agentPaneID := strings.TrimSpace(string(out))

	// Rebalance: leader left, agents stacked right
	exec.Command(tmuxBin, "select-layout", "-t", leaderPane, "main-vertical").Run()

	agents[evt.AgentID] = &AgentState{
		AgentPaneID: agentPaneID,
		LeaderPane:  leaderPane,
		Description: desc,
		StatusFile:  statusFile,
	}

	log.Printf("agent_start: %s -> pane %s (leader %s, %s)", evt.AgentID, agentPaneID, leaderPane, desc)
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

	result := evt.Result
	if result == "" {
		result = "completed"
	}
	if len(result) > 500 {
		result = result[:500] + "..."
	}
	os.WriteFile(agent.StatusFile, []byte("DONE\n"+result), 0644)

	log.Printf("agent_stop: %s (pane %s)", evt.AgentID, agent.AgentPaneID)

	go func() {
		time.Sleep(3 * time.Second)
		exec.Command(tmuxBin, "kill-pane", "-t", agent.AgentPaneID).Run()
		exec.Command(tmuxBin, "select-layout", "-t", agent.LeaderPane, "main-vertical").Run()
		os.Remove(agent.StatusFile)
	}()
}

func cleanup() {
	mu.Lock()
	defer mu.Unlock()
	for id, agent := range agents {
		exec.Command(tmuxBin, "kill-pane", "-t", agent.AgentPaneID).Run()
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
