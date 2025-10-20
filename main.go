package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	sdk "agones.dev/agones/sdks/go"
)

// main intercepts the stdout of the Necesse gameserver and uses it
// to determine when the server is ready. We consider the server ready
// once the line "Type help for list of commands." appears.
func main() {
	input := flag.String("i", "", "path to necesseserver.sh")
	args := flag.String("args", "", "additional arguments to pass to the script")
	flag.Parse()

	if strings.TrimSpace(*input) == "" {
		log.Fatal(">>> Missing -i path to necesseserver.sh")
	}

	// Parse -args into a slice; tolerate empty string and simple outer quotes.
	var argsList []string
	if trimmed := strings.TrimSpace(*args); trimmed != "" {
		argsList = strings.Fields(strings.Trim(trimmed, "'"))
	}

	fmt.Println(">>> Connecting to Agones with the SDK")
	s, err := sdk.NewSDK()
	if err != nil {
		log.Fatalf(">>> Could not connect to sdk: %v", err)
	}

	fmt.Println(">>> Starting health checking")
	go doHealth(s)

	fmt.Println(">>> Starting wrapper for necesse!")
	fmt.Printf(">>> Path to necesse server script: %s %v\n", *input, argsList)

	cmd := exec.Command(*input, argsList...) // #nosec G204

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatalf(">>> Failed to get stdout pipe: %v", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatalf(">>> Failed to get stderr pipe: %v", err)
	}

	// Ready once we see the help line.
	const helpLine = "Type help for list of commands."

	var once sync.Once
	ready := func(trigger string) {
		once.Do(func() {
			fmt.Printf(">>> Moving to READY (trigger: %s)\n", trigger)
			if err := s.Ready(); err != nil {
				log.Fatalf(">>> Could not send ready message: %v", err)
			}
		})
	}

	// Forward stderr directly.
	go func() {
		if _, err := io.Copy(os.Stderr, stderr); err != nil && !isBenignPipeError(err) {
			log.Printf(">>> STDERR copy error: %v", err)
		}
	}()

	// Scan stdout line-by-line, forward, and detect readiness.
	go func() {
		sc := bufio.NewScanner(stdout)
		// If your server logs extremely long lines, you can increase the buffer:
		// buf := make([]byte, 0, 256*1024)
		// sc.Buffer(buf, 1024*1024)
		for sc.Scan() {
			line := sc.Text()
			fmt.Fprintln(os.Stdout, line)
			if strings.Contains(line, helpLine) {
				ready("help-line")
			}
		}
		if err := sc.Err(); err != nil && !isBenignPipeError(err) {
			log.Printf(">>> STDOUT scan error: %v", err)
		}
	}()

	if err := cmd.Start(); err != nil {
		log.Fatalf(">>> Error starting server script: %v", err)
	}
	err = cmd.Wait()
	log.Fatal(">>> necesse shutdown unexpectedly: ", err)
}

// doHealth sends the regular Health pings.
func doHealth(sdk *sdk.SDK) {
	tick := time.Tick(2 * time.Second)
	for {
		if err := sdk.Health(); err != nil {
			log.Fatalf("[wrapper] Could not send health ping, %v", err)
		}
		<-tick
	}
}

// isBenignPipeError filters common pipe/FD errors that occur on process exit.
func isBenignPipeError(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "use of closed network connection") ||
		strings.Contains(msg, "file already closed") ||
		strings.Contains(msg, "broken pipe")
}
