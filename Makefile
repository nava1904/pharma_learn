.PHONY: dev deps codegen codegen-watch test test-api test-lifecycle test-workflow docker-prod logs

# ── Local Development ─────────────────────────────────────────────────────────

## Start all 3 Dart servers + Supabase (hot-reloadable, no Docker)
dev:
	@echo "Starting Supabase..."
	supabase start &
	@sleep 3
	@echo "Starting PharmaLearn API on :8080..."
	@(cd apps/api_server/pharma_learn/api && dart run bin/server.dart) &
	@echo "Starting Lifecycle Monitor on :8086..."
	@(cd apps/api_server/pharma_learn/lifecycle_monitor && dart run bin/server.dart) &
	@echo "Starting Workflow Engine on :8085..."
	@(cd apps/api_server/pharma_learn/workflow_engine && dart run bin/server.dart) &
	@echo ""
	@echo "╔══════════════════════════════════════════════╗"
	@echo "║         PharmaLearn Running                  ║"
	@echo "║  API:               http://localhost:8080    ║"
	@echo "║  Health:            http://localhost:8080/health ║"
	@echo "║  Lifecycle Monitor: http://localhost:8086    ║"
	@echo "║  Workflow Engine:   http://localhost:8085    ║"
	@echo "║  Supabase Studio:   http://localhost:54323   ║"
	@echo "╚══════════════════════════════════════════════╝"

## Stop all background servers
stop:
	@pkill -f "dart run bin/server.dart" 2>/dev/null || true
	@supabase stop 2>/dev/null || true
	@echo "All servers stopped."

# ── Dependencies ──────────────────────────────────────────────────────────────

## Install dependencies for all packages
deps:
	cd packages/pharmalearn_shared && dart pub get
	cd apps/api_server/pharma_learn/api && dart pub get
	cd apps/api_server/pharma_learn/lifecycle_monitor && dart pub get
	cd apps/api_server/pharma_learn/workflow_engine && dart pub get
	flutter pub get

# ── Code Generation ───────────────────────────────────────────────────────────

## Run Flutter code generation (MobX + injectable + json_serializable + Vyuh)
codegen:
	cd apps/pharma_learn && dart run build_runner build --delete-conflicting-outputs

## Watch mode for Flutter code generation
codegen-watch:
	cd apps/pharma_learn && dart run build_runner watch --delete-conflicting-outputs

## Run server codegen (if needed)
codegen-server:
	cd packages/pharmalearn_shared && dart run build_runner build --delete-conflicting-outputs

# ── Testing ───────────────────────────────────────────────────────────────────

## Run all tests
test: test-api test-lifecycle test-workflow
	flutter test test/

## Run API server tests only
test-api:
	dart test apps/api_server/pharma_learn/api/test/

## Run lifecycle monitor tests only
test-lifecycle:
	dart test apps/api_server/pharma_learn/lifecycle_monitor/test/

## Run workflow engine tests only
test-workflow:
	dart test apps/api_server/pharma_learn/workflow_engine/test/

# ── Production ────────────────────────────────────────────────────────────────

## Build and start all services via Docker Compose (production)
docker-prod:
	docker compose -f docker-compose.prod.yml up --build -d

## View production logs
logs:
	docker compose -f docker-compose.prod.yml logs -f

## Stop production services
docker-stop:
	docker compose -f docker-compose.prod.yml down
