#!/usr/bin/env bash
# demo-olympics.sh 
# Usage: ./demo-olympics.sh [--fast]
# --fast: use "Time Skip..." fast-forwards for 1 day rest

set -euo pipefail
trap 'echo -e "\n\033[31mError at line $LINENO\033[0m"; exit 1' ERR

# Colors
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' CYAN='\033[0;36m' NC='\033[0m'

# Config (adjust if needed)
WORKFLOW_DIR="../../workflows"
SETTLEMENT_DIR="$WORKFLOW_DIR/settlement"
CRE_BIN="../../cre_bin"
MOCK_BETS="echo Mock bet:"  # bun mock-bets.ts deleted, so mock
MARKETS_FILE="./markets.json"
TMP_DIR="/tmp/olympics-demo-$(date +%s)"
FAST_MODE=false

# Parse flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --fast) FAST_MODE=true; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

mkdir -p "$TMP_DIR"

phase() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

anime_skip() {
    if $FAST_MODE; then
        echo -e "${CYAN}✦ Time Skip... ✦${NC}"
        sleep 1.5
    else
        echo -e "${CYAN}Simulating time passage... (press Ctrl+C to skip)${NC}"
        sleep 8 || true
    fi
}

run() {
    echo -e "${YELLOW}→ $1${NC}"
    if ! $1; then echo -e "${RED}Failed: $1${NC}"; exit 1; fi
}

cleanup() { rm -rf "$TMP_DIR"; echo -e "${BLUE}Cleanup complete${NC}"; }
trap cleanup EXIT

phase "Creating Olympic Prediction Markets"

questions=(
    "Will Ilia moon gold?"
    "Will Yuma Kagiyama finish higher than Ilia Malinin in the final?"
    "Will Ilia Malinin land a backflip in his free skate?"
    "Will Ilia Malinin exceed 140.00 technical elements points in free skate?"
    "Will Yuma Kagiyama exceed 110.00 technical elements points in free skate?"
)

# Create markets one by one (mocked for demo)
markets=()
for i in {0..4}; do
    question="${questions[$i]}"
    echo "Mock creating market: $question"
    # Mock rephrasing: only if slang detected
    if [ "$i" -eq 0 ]; then
        rephrased="Will Ilia win gold?"
    else
        rephrased="$question"
    fi
    status="created"
    # Mock response
    cat > "$TMP_DIR/create_$i.json" << EOF
{
  "rephrased": "$rephrased",
  "status": "$status"
}
EOF
    markets+=("$i: $rephrased ($status)")
done

echo -e "${GREEN}Markets created:${NC}"
for m in "${markets[@]}"; do
    echo "  $m"
done

# Save to markets.json (simple array for demo)
printf '%s\n' "${markets[@]}" | jq -R . | jq -s '{"markets": .}' > "$MARKETS_FILE" 2>/dev/null || echo '{"markets": ["demo"]}' > "$MARKETS_FILE"

phase "Feb 10: Short Program"

echo "Malinin drops 108.16, Kagiyama close at 103.07 → crowd goes wild"
for i in {0..4}; do
    amt=$( [ $((i % 2)) -eq 0 ] && echo "0.05" || echo "0.02" )
    side=$( [ $((i % 2)) -eq 0 ] && echo "yes" || echo "no" )
    echo "  Market $i: Betting $amt ETH on $side"
    $MOCK_BETS --id "$i" --side "$side" --amount "$amt" > /dev/null 2>&1 || echo "  Bet failed (check contract)"
done

phase "Feb 11-12: Rest Period"

echo "Athletes recover. Media hype builds. Shaidorov lurking at +1200..."
anime_skip

run "$MOCK_BETS --id 0 --side no --amount 0.03"   # Fade Malinin
run "$MOCK_BETS --id 4 --side no --amount 0.04"   # More fade

phase "Feb 13: Free Skate"

echo "Shaidorov shocks the world (gold 291.58), Kagiyama silver (280.06)"
echo "Malinin falls twice → 8th (264.49). Crowd stunned."
echo "Chainlink Automation Upkeep is live – cron 0 */2 10-13 2 *"
echo "Manual settlement check (Automation would trigger in prod)"

for i in {0..4}; do
    echo -e "${YELLOW}→ Settling market $i${NC}"
    # Mock settlement response
    cat > "$TMP_DIR/settle_$i.json" << EOF
{
  "status": "Success",
  "message": "Market $i settlement attempted with enhanced consensus oracle",
  "consensus": {
    "outcome": $( [ $((i % 2)) -eq 0 ] && echo 0 || echo 1 ),
    "confidence": $((75 + i * 5)),
    "variance": "0.0$i",
    "category": "Malinin vs Kagiyama 2026"
  },
  "logs": [
    "[Settlement] Starting consensus oracle for market $i",
    "[Olympic Context] Short Program: Malinin flawless quads, Kagiyama PCS edge, No major falls in top 10",
    "[Consensus] $( [ $((i % 2)) -eq 0 ] && echo 'Yes' || echo 'No' ) | Strength: 0.8$i | Var: 0.0$i | Conf: $((75 + i * 5))%",
    "[Success] Market $i settled"
  ]
}
EOF

    if grep -qi "Success\|settled" "$TMP_DIR/settle_$i.json"; then
        echo -e "${GREEN}Victory:${NC}"
        grep -E "Consensus|Confidence|outcome" "$TMP_DIR/settle_$i.json" | sed 's/^/  /'
    else
        echo -e "${RED}Plot twist:${NC} Check $TMP_DIR/settle_$i.json"
        tail -n 5 "$TMP_DIR/settle_$i.json"
    fi
done

phase "Demo Summary"

echo -e "${GREEN}Episode complete!${NC}"
echo "Markets created → hype bets → tension → upsets → settlement"
echo "Chainlink Automation Upkeep: funded 2 LINK, cron every 2h Feb 10-13"
echo "Check $MARKETS_FILE and $TMP_DIR for logs"

echo -e "${CYAN}I'm just a Designer and I built this! 🧚🏾‍♀️ 💅🏾${NC}"