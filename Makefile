include .env
export

DART_DEFINES = \
	--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
	--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) \
	--dart-define=GEMINI_API_KEY=$(GEMINI_API_KEY)

CHIRON_DEBUG_TRACE ?= false
CHIRON_DEBUG_DEFINE = --dart-define=CHIRON_DEBUG_TRACE=$(CHIRON_DEBUG_TRACE)

SIM_DEVICE = iPhone 17 Pro
SIM_UDID = A60DDE07-87E2-4D7E-A79E-3188235C7783

.PHONY: help run run-ios run-release run-clean-ios sim-boot sim-open build-apk build-apk-debug build-aab build-ipa gen gen-watch gen-l10n analyze clean

help:                 ## Show this help
	@echo "Athlos — available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:[^=]*## .*$$' Makefile | sed 's/:.*##/##/' | awk -F '##' '{gsub(/^[ \t]+|[ \t]+$$/, "", $$1); gsub(/^[ \t]+/, "", $$2); printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' | sort

## ── Dev ──────────────────────────────────────────────

run:                   ## Run debug build with all dart-defines
	flutter run $(DART_DEFINES)

run-ios:               ## Run on iPhone 17 Pro simulator
	@$(MAKE) sim-boot
	flutter run -d $(SIM_UDID) $(DART_DEFINES)

run-release:           ## Run release build
	flutter run --release $(DART_DEFINES)

run-clean-ios:         ## Run debug without dev seed data (fresh user experience)
	@$(MAKE) sim-boot
	flutter run -d $(SIM_UDID) $(DART_DEFINES) --dart-define=SKIP_DEV_SEED=true

## ── Simulator ────────────────────────────────────────

sim-boot:              ## Boot iPhone 17 Pro simulator
	@xcrun simctl boot "$(SIM_UDID)" 2>/dev/null || true

sim-open:              ## Open Simulator.app with iPhone 17 Pro
	@$(MAKE) sim-boot
	open -a Simulator

## ── Build ────────────────────────────────────────────

build-apk:             ## Build release APK
	flutter build apk --release $(DART_DEFINES) $(CHIRON_DEBUG_DEFINE)

build-apk-debug:       ## Build release APK with CHIRON_DEBUG_TRACE=true
	$(MAKE) build-apk CHIRON_DEBUG_TRACE=true

build-aab:             ## Build release App Bundle
	flutter build appbundle --release $(DART_DEFINES)

build-ipa:             ## Build release IPA (no codesign)
	flutter build ipa --release --no-codesign $(DART_DEFINES)

## ── Code Generation ──────────────────────────────────

gen:                   ## Run build_runner (one-shot)
	dart run build_runner build --delete-conflicting-outputs

gen-watch:             ## Run build_runner (watch mode)
	dart run build_runner watch --delete-conflicting-outputs

gen-l10n:              ## Generate localization files
	flutter gen-l10n

## ── Quality ──────────────────────────────────────────

analyze:               ## Run Flutter analyzer
	flutter analyze

clean:                 ## Clean build artifacts
	flutter clean
	flutter pub get
