#!/bin/bash
# =============================================================================
# ETUS — Local Setup & Start Script
# =============================================================================
# Usage:
#   ./start.sh              — Full setup + start all services
#   ./start.sh --skip-build — Skip build (if already built)
#   ./start.sh --rebuild    — Force rebuild all packages
#   ./start.sh --run <file> — Run a specific test file
#   ./start.sh --stop       — Stop all running services
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
DASH_LOG="/tmp/etus-dashboard.log"
DASH_PID_FILE="/tmp/etus-dashboard.pid"
DOCS_LOG="/tmp/etus-docs.log"
DOCS_PID_FILE="/tmp/etus-docs.pid"
DOCS_PORT=8090
DASH_PORT=3100
MCP_PORT=3471

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

  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — docs site will not start"
  fi
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
    printf "# ETUS Hooks Configuration\nhooks: []\n" > hooks.yaml
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
  mkdir -p ./node_modules/.bin
  if [ ! -L "./node_modules/.bin/etus-agent" ]; then
    ln -sf "../../packages/cli/dist/cli.js" ./node_modules/.bin/etus-agent
    ok "CLI symlink created"
  fi
}

kill_existing() {
  local killed=0

  # Kill dashboard
  if [ -f "$DASH_PID_FILE" ]; then
    local pid
    pid=$(cat "$DASH_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      killed=1
    fi
    rm -f "$DASH_PID_FILE"
  fi

  # Kill docs
  if [ -f "$DOCS_PID_FILE" ]; then
    local pid
    pid=$(cat "$DOCS_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      killed=1
    fi
    rm -f "$DOCS_PID_FILE"
  fi

  # Kill by port
  lsof -ti :$DASH_PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
  lsof -ti :$MCP_PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
  lsof -ti :$DOCS_PORT 2>/dev/null | xargs kill -9 2>/dev/null || true

  if [ "$killed" -eq 1 ]; then
    sleep 1
    ok "Stopped existing services"
  fi
}

start_all() {
  kill_existing
  info "Starting all services..."

  # Start dashboard (includes MCP)
  ETUS_AGENT_CLI_BIN="$CLI_BIN" nohup node "$CLI_BIN" dashboard > "$DASH_LOG" 2>&1 &
  local dash_pid=$!
  echo "$dash_pid" > "$DASH_PID_FILE"

  # Start docs site
  if command -v python3 &>/dev/null && [ -d "$ROOT_DIR/docs/site" ]; then
    cd "$ROOT_DIR/docs/site"
    nohup python3 -m http.server $DOCS_PORT > "$DOCS_LOG" 2>&1 &
    local docs_pid=$!
    echo "$docs_pid" > "$DOCS_PID_FILE"
    cd "$ROOT_DIR"
  fi

  sleep 4

  # Verify dashboard
  if ! kill -0 "$dash_pid" 2>/dev/null; then
    fail "Dashboard failed to start. Check: tail $DASH_LOG"
  fi

  local dash_http
  dash_http=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$DASH_PORT/ 2>/dev/null || echo "000")
  if [ "$dash_http" != "200" ]; then
    fail "Dashboard not responding. Check: tail $DASH_LOG"
  fi

  # Verify docs
  local docs_status="not started"
  if [ -f "$DOCS_PID_FILE" ]; then
    local docs_http
    docs_http=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$DOCS_PORT/ 2>/dev/null || echo "000")
    if [ "$docs_http" = "200" ]; then
      docs_status="running"
    fi
  fi

  echo ""
  echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}  ETUS is running${NC}"
  echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${BOLD}Dashboard${NC}     http://localhost:$DASH_PORT"
  echo -e "  ${BOLD}MCP Server${NC}    http://127.0.0.1:$MCP_PORT/mcp"
  if [ "$docs_status" = "running" ]; then
    echo -e "  ${BOLD}Documentation${NC} http://localhost:$DOCS_PORT"
    echo -e "  ${BOLD}Integration${NC}   http://localhost:$DOCS_PORT/integration-guide.html"
  fi
  echo ""
  echo -e "  ${CYAN}Logs:${NC}"
  echo -e "    Dashboard   tail -f $DASH_LOG"
  if [ -f "$DOCS_PID_FILE" ]; then
    echo -e "    Docs        tail -f $DOCS_LOG"
  fi
  echo ""
  echo -e "  ${YELLOW}Commands:${NC}"
  echo -e "    Stop        ./start.sh --stop"
  echo -e "    Status      ./start.sh --status"
  echo -e "    Run test    ./start.sh --run tests/my-test.yaml"
  echo ""
}

do_stop() {
  kill_existing
  ok "All services stopped"
}

do_status() {
  echo ""
  echo -e "${BOLD}ETUS Services${NC}"
  echo ""

  # Dashboard
  local dash_code
  dash_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$DASH_PORT/ 2>/dev/null || echo "000")
  if [ "$dash_code" = "200" ]; then
    local pid="?"
    [ -f "$DASH_PID_FILE" ] && pid=$(cat "$DASH_PID_FILE")
    ok "Dashboard:     http://localhost:$DASH_PORT  (PID $pid)"
  else
    warn "Dashboard:     not running"
  fi

  # MCP
  local mcp_code
  mcp_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$MCP_PORT/mcp 2>/dev/null || echo "000")
  if [ "$mcp_code" = "405" ] || [ "$mcp_code" = "406" ]; then
    ok "MCP Server:    http://127.0.0.1:$MCP_PORT/mcp"
  else
    warn "MCP Server:    not running"
  fi

  # Docs
  local docs_code
  docs_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$DOCS_PORT/ 2>/dev/null || echo "000")
  if [ "$docs_code" = "200" ]; then
    local pid="?"
    [ -f "$DOCS_PID_FILE" ] && pid=$(cat "$DOCS_PID_FILE")
    ok "Documentation: http://localhost:$DOCS_PORT  (PID $pid)"
  else
    warn "Documentation: not running"
  fi

  # Auth
  echo ""
  node "$CLI_BIN" auth status 2>/dev/null | grep -v "PostHog" || warn "Auth status unavailable"
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
    start_all
    ;;
  --skip-build)
    check_prereqs
    do_install
    [ ! -f "$CLI_BIN" ] && fail "Not built yet. Run ./start.sh first."
    ensure_browsers
    ensure_workspace_files
    ensure_symlink
    start_all
    ;;
  ""|--start)
    check_prereqs
    do_install
    do_build
    ensure_browsers
    ensure_workspace_files
    ensure_symlink
    start_all
    ;;
  *)
    echo ""
    echo "  ETUS — Start Script"
    echo ""
    echo "  Usage: ./start.sh [option]"
    echo ""
    echo "  Options:"
    echo "    (no args)      Full setup + build + start all services"
    echo "    --skip-build   Start without rebuilding"
    echo "    --rebuild      Force rebuild then start"
    echo "    --run <file>   Run a specific test file"
    echo "    --stop         Stop all services"
    echo "    --status       Show service status"
    echo ""
    exit 1
    ;;
esac
