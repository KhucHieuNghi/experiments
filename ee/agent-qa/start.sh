#!/bin/bash
# =============================================================================
# ETUS — Local Setup & Start Script
# =============================================================================
# Usage:
#   ./start.sh              — Full setup + start dashboard
#   ./start.sh --skip-build — Skip build (if already built)
#   ./start.sh --run <file> — Run a specific test file instead of dashboard
#   ./start.sh --stop       — Stop running dashboard
#   ./start.sh --status     — Check running services
# =============================================================================

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CLI_BIN="$ROOT_DIR/packages/cli/dist/cli.js"
LOG_FILE="/tmp/etus-dashboard.log"
PID_FILE="/tmp/etus-dashboard.pid"

# =============================================================================
# Helper functions
# =============================================================================

info()  { echo -e "${CYAN}[ETUS]${NC} $1"; }
ok()    { echo -e "${GREEN}[ETUS]${NC} $1"; }
warn()  { echo -e "${YELLOW}[ETUS]${NC} $1"; }
fail()  { echo -e "${RED}[ETUS]${NC} $1"; exit 1; }

check_prereqs() {
  info "Checking prerequisites..."

  if ! command -v node &>/dev/null; then
    fail "Node.js not found. Install Node >= 24."
  fi
  NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VERSION" -lt 24 ]; then
    fail "Node.js >= 24 required. Found: $(node -v)"
  fi
  ok "Node.js $(node -v)"

  if ! command -v pnpm &>/dev/null; then
    fail "pnpm not found. Run: corepack enable"
  fi
  ok "pnpm $(pnpm -v)"
}

do_install() {
  if [ ! -d "node_modules" ]; then
    info "Installing dependencies..."
    pnpm install
    ok "Dependencies installed"
  else
    ok "Dependencies already installed"
  fi
}

do_build() {
  if [ ! -f "$CLI_BIN" ]; then
    info "Building all packages..."
    pnpm build
    ok "Build complete"
  else
    ok "Already built (use --rebuild to force)"
  fi
}

do_force_build() {
  info "Building all packages..."
  pnpm build
  ok "Build complete"
}

ensure_browsers() {
  # Check if Playwright chromium is already installed
  local pw_cache="$HOME/Library/Caches/ms-playwright"
  if [ -d "$pw_cache" ] && ls "$pw_cache"/chromium-*/INSTALLATION_COMPLETE &>/dev/null; then
    ok "Chromium already installed"
  else
    info "Installing Chromium browser..."
    node "$CLI_BIN" install-browsers --chromium
    ok "Chromium installed"
  fi
}

ensure_workspace_files() {
  # Config file
  if [ ! -f "etus-agent.config.yaml" ]; then
    fail "etus-agent.config.yaml not found. Run: node $CLI_BIN init"
  fi

  # hooks.yaml
  if [ ! -f "hooks.yaml" ]; then
    echo "# ETUS Hooks Configuration" > hooks.yaml
    echo "hooks: []" >> hooks.yaml
    ok "Created hooks.yaml"
  fi

  # agent-rules.md
  if [ ! -f "agent-rules.md" ]; then
    cat > agent-rules.md << 'EOF'
# Agent Rules

- Prefer accessibility attributes (role, aria-label) over CSS selectors
- Wait for page to be fully loaded before interacting
- If an element is not visible, scroll to make it visible first
- Use exact text matching for button and link identification
EOF
    ok "Created agent-rules.md"
  fi

  # .env files
  [ ! -f ".env" ] && touch .env
  [ ! -f ".env.secrets.local" ] && touch .env.secrets.local

  # tests directory
  mkdir -p tests
}

ensure_symlink() {
  # Symlink for dashboard child process spawning
  mkdir -p ./node_modules/.bin
  if [ ! -L "./node_modules/.bin/etus-agent" ]; then
    ln -sf "../../packages/cli/dist/cli.js" ./node_modules/.bin/etus-agent
    ok "CLI symlink created"
  fi
}

kill_existing() {
  local killed=0
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      killed=1
    fi
    rm -f "$PID_FILE"
  fi
  # Also kill by port
  lsof -ti :3100 2>/dev/null | xargs kill -9 2>/dev/null || true
  lsof -ti :3471 2>/dev/null | xargs kill -9 2>/dev/null || true
  if [ "$killed" -eq 1 ]; then
    sleep 1
    ok "Stopped existing dashboard"
  fi
}

start_dashboard() {
  kill_existing
  info "Starting dashboard..."

  ETUS_AGENT_CLI_BIN="$CLI_BIN" nohup node "$CLI_BIN" dashboard > "$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_FILE"

  sleep 3

  if ! kill -0 "$pid" 2>/dev/null; then
    fail "Dashboard failed to start. Check: tail $LOG_FILE"
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3100/ 2>/dev/null || echo "000")
  if [ "$http_code" != "200" ]; then
    fail "Dashboard not responding. Check: tail $LOG_FILE"
  fi

  echo ""
  echo -e "${BOLD}════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}  ETUS is running${NC}"
  echo -e "${BOLD}════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Dashboard:  ${CYAN}http://localhost:3100${NC}"
  echo -e "  MCP:        ${CYAN}http://127.0.0.1:3471/mcp${NC}"
  echo -e "  PID:        $pid"
  echo -e "  Log:        $LOG_FILE"
  echo ""
  echo -e "  Stop:       ${YELLOW}./start.sh --stop${NC}"
  echo -e "  Status:     ${YELLOW}./start.sh --status${NC}"
  echo -e "  Run test:   ${YELLOW}./start.sh --run tests/my-test.yaml${NC}"
  echo ""
}

do_stop() {
  kill_existing
  ok "Dashboard stopped"
}

do_status() {
  echo ""
  echo -e "${BOLD}ETUS Status${NC}"
  echo ""

  # Dashboard
  if curl -s -o /dev/null -w "" http://127.0.0.1:3100/ 2>/dev/null; then
    local pid="unknown"
    [ -f "$PID_FILE" ] && pid=$(cat "$PID_FILE")
    ok "Dashboard: running (PID $pid) → http://localhost:3100"
  else
    warn "Dashboard: not running"
  fi

  # MCP
  if curl -s -o /dev/null -w "" http://127.0.0.1:3471/mcp 2>/dev/null; then
    ok "MCP:       running → http://127.0.0.1:3471/mcp"
  else
    warn "MCP:       not running"
  fi

  # Auth
  echo ""
  node "$CLI_BIN" auth status 2>/dev/null || warn "Auth status unavailable"
  echo ""
}

do_run() {
  local target="$1"
  info "Running: $target"
  ETUS_AGENT_CLI_BIN="$CLI_BIN" node "$CLI_BIN" run "$target"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
  --stop)
    do_stop
    exit 0
    ;;
  --status)
    do_status
    exit 0
    ;;
  --run)
    [ -z "${2:-}" ] && fail "Usage: ./start.sh --run <test-file>"
    do_run "$2"
    exit 0
    ;;
  --rebuild)
    check_prereqs
    do_install
    do_force_build
    ensure_browsers
    ensure_workspace_files
    ensure_symlink
    start_dashboard
    ;;
  --skip-build)
    check_prereqs
    do_install
    [ ! -f "$CLI_BIN" ] && fail "Not built yet. Run ./start.sh first."
    ensure_browsers
    ensure_workspace_files
    ensure_symlink
    start_dashboard
    ;;
  ""|--start)
    check_prereqs
    do_install
    do_build
    ensure_browsers
    ensure_workspace_files
    ensure_symlink
    start_dashboard
    ;;
  *)
    echo "Usage: ./start.sh [options]"
    echo ""
    echo "Options:"
    echo "  (no args)      Full setup + start dashboard"
    echo "  --skip-build   Skip build step"
    echo "  --rebuild      Force rebuild all packages"
    echo "  --run <file>   Run a test file"
    echo "  --stop         Stop running dashboard"
    echo "  --status       Check service status"
    echo ""
    exit 1
    ;;
esac
