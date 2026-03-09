# 🏅 Olympics Prediction Market - Makefile
# Simple commands for development and demo

.PHONY: help demo test deploy clean install security-check

# Default target
help:
	@echo "🏅 Olympics Prediction Market Commands:"
	@echo ""
	@echo "  make install       - Install all dependencies"
	@echo "  make test          - Run core tests"
	@echo "  make deploy        - Deploy to local Anvil chain"
	@echo "  make demo          - Run full Olympics demo"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make security-check - Verify no secrets committed"
	@echo ""
	@echo "🚀 Quick start:"
	@echo "  make install && make test && make deploy && make demo"
	@echo ""
	@echo "🔒 Security:"
	@echo "  make security-check # Verify no private keys in repo"

# Install all dependencies
install:
	@echo "📦 Installing dependencies..."
	forge install
	npm install
	npm run workflow:install
	@echo "✅ Dependencies installed!"

# Run core tests
test:
	@echo "🧪 Running core tests..."
	forge test --match-test testCreateMarket --via-ir
	@echo "✅ Core functionality verified!"

# Deploy to local Anvil chain
deploy:
	@echo "🏗️ Deploying to local chain..."
	@if ! pgrep -f "anvil" > /dev/null; then \
		echo "Starting Anvil..."; \
		anvil & \
		sleep 2; \
	fi
	forge script contracts/script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ Contracts deployed!"

# Run full demo
demo:
	@echo "🎭 Running Olympics prediction market demo..."
	./scripts/demo/demo-olympics.sh
	@echo "🎉 Demo complete!"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	forge clean
	rm -rf cache/
	rm -rf out/
	@echo "✅ Clean complete!"

# Development setup (install + test)
setup: install test
	@echo "🚀 Development setup complete!"

# Full development cycle (install + test + deploy + demo)
dev: setup deploy demo
	@echo "🎯 Full development cycle complete!"

# Security check - verify no secrets committed
security-check:
	@echo "🔒 Checking for committed secrets..."
	@if git ls-files | grep -q "^\.env$$"; then \
		echo "❌ ERROR: .env file is tracked! Remove it with: git rm --cached .env"; \
		exit 1; \
	fi
	@for file in $$(git ls-files); do \
		if grep -q "PRIVATE_KEY.*=" "$$file" 2>/dev/null && ! grep -q "example" "$$file" && ! echo "$$file" | grep -q "\.env\.example$$"; then \
			echo "❌ WARNING: Found potential private key in tracked file: $$file"; \
			exit 1; \
		fi; \
	done
	@echo "✅ No secrets detected in tracked files"
	@echo "🔐 Repository is secure for public sharing"
