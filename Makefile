# Shared config: .env is shell-sourced in run/build recipes (not `-include` — spaces break Make).
SIM_DEVICE := iPhone 17 Pro
SIM_UDID ?=
IOS_SIM_TARGET := $(if $(SIM_UDID),$(SIM_UDID),$(SIM_DEVICE))
IOS_DEVICE_UDID ?=
ANDROID_EMULATOR ?= dev_pixel7_api34
ANDROID_DEVICE ?= android

CHIRON_DEBUG_TRACE ?= false
SEED ?= 1

# run-ios: local by default; override with `make run-ios SUPABASE_ENV=prod`
SUPABASE_ENV ?= local
SUPABASE_ENV_FILE_local := .env.local
SUPABASE_ENV_FILE_prod := .env.prod

_SEED_DEFINE = $(if $(filter 0,$(SEED)),--dart-define=SKIP_DEV_SEED=true)

.PHONY: help run-ios run-ios-device run-android ios-sim-open ios-sim-list android-sim-open android-emu-list build-apk build-aab build-ipa gen gen-l10n analyze clean

help: ## Show organized command list
	@echo ""
	@echo "Athlos Makefile"
	@echo "------------------------------------------------------------"
	@printf "  %-20s %s\n" "SIM_DEVICE" "$(SIM_DEVICE)"
	@printf "  %-20s %s\n" "IOS_DEVICE_UDID" "$(if $(IOS_DEVICE_UDID),<definido>,<não definido>)"
	@printf "  %-20s %s\n" "ANDROID_EMULATOR" "$(ANDROID_EMULATOR)"
	@printf "  %-20s %s\n" "SUPABASE_ENV (run-ios)" "$(SUPABASE_ENV)"
	@echo ""
	@echo "Supabase:"
	@echo "  run-ios          → .env.local (sim + Supabase local)"
	@echo "  run-ios SUPABASE_ENV=prod → .env.prod"
	@echo "  run-ios-device   → .env.prod (iPhone físico + cloud)"
	@echo "  run-android      → .env.local"
	@echo ""
	@awk '\
		BEGIN { CYAN="\033[36m"; BOLD="\033[1m"; RESET="\033[0m"; } \
		/^##[[:space:]]+/ { \
			section=$$0; sub(/^##[[:space:]]*/, "", section); \
			printf "\n%s%s%s\n", BOLD, section, RESET; next; \
		} \
		/^[a-zA-Z0-9_-]+:.*##[[:space:]]+/ { \
			split($$0, parts, ":"); target=parts[1]; desc=$$0; \
			sub(/^.*##[[:space:]]*/, "", desc); \
			printf "  %s%-18s%s %s\n", CYAN, target, RESET, desc; \
		}' Makefile
	@echo ""
	@echo "Exemplos:"
	@echo "  make run-ios              # sim + Supabase local"
	@echo "  make run-ios SEED=0"
	@echo "  make run-ios SUPABASE_ENV=prod"
	@echo "  make run-ios-device IOS_DEVICE_UDID=<udid>"
	@echo "  make run-android"
	@echo ""

# Sources .env then $(SUPABASE_ENV_FILE) and runs flutter with dart-defines from the shell env.
define flutter_run
	@test -f $(1) || ( \
		echo "ERROR: missing $(1). Copy from .env.example (see Supabase sections)."; \
		exit 1); \
	set -a && \
	[ -f .env ] && . ./.env; \
	. ./$(1); \
	set +a && \
	test -n "$$SUPABASE_URL" && test -n "$$SUPABASE_ANON_KEY" || ( \
		echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set in $(1)"; \
		exit 1); \
	flutter run $(2) \
		--dart-define=SUPABASE_URL="$$SUPABASE_URL" \
		--dart-define=SUPABASE_ANON_KEY="$$SUPABASE_ANON_KEY" \
		--dart-define=SUPABASE_REDIRECT_URL="$${SUPABASE_REDIRECT_URL:-athlos://auth-callback}" \
		--dart-define=GEMINI_API_KEY="$$GEMINI_API_KEY" \
		$(_SEED_DEFINE) \
		$(3)
endef

# Release/build: hosted Supabase from .env.prod
define flutter_build_defines
	@test -f .env.prod || ( \
		echo "ERROR: missing .env.prod. Copy from .env.example."; \
		exit 1); \
	set -a && \
	[ -f .env ] && . ./.env; \
	. ./.env.prod; \
	set +a && \
	echo "$$SUPABASE_URL" "$$SUPABASE_ANON_KEY" > /dev/null
endef

## Run
run-ios: ## iOS simulator — Supabase local (.env.local); SUPABASE_ENV=prod uses .env.prod
	@xcrun simctl boot "$(IOS_SIM_TARGET)" 2>/dev/null || true
	$(call flutter_run,$(if $(filter prod,$(SUPABASE_ENV)),$(SUPABASE_ENV_FILE_prod),$(SUPABASE_ENV_FILE_local)),-d "$(IOS_SIM_TARGET)",)

run-ios-device: ## Physical iPhone (profile) — Supabase prod (.env.prod)
	@set -a && [ -f .env ] && . ./.env; set +a; \
	if [ -z "$$IOS_DEVICE_UDID" ]; then \
		echo "ERROR: set IOS_DEVICE_UDID=<your_device_udid> in .env"; \
		exit 1; \
	fi; \
	$(call flutter_run,$(SUPABASE_ENV_FILE_prod),--profile -d "$$IOS_DEVICE_UDID",--dart-define=CHIRON_DEBUG_TRACE=$(CHIRON_DEBUG_TRACE) --dart-define=ENV=prod)

run-android: ## Android emulator — Supabase local (.env.local)
	@flutter emulators --launch "$(ANDROID_EMULATOR)" 2>/dev/null || true
	$(call flutter_run,$(SUPABASE_ENV_FILE_local),-d "$(ANDROID_DEVICE)",)

## Devices
ios-sim-open: ## Open iOS Simulator app
	@xcrun simctl boot "$(IOS_SIM_TARGET)" 2>/dev/null || true
	open -a Simulator

ios-sim-list: ## List available iOS simulators
	xcrun simctl list devices available

android-sim-open: ## Launch configured Android emulator
	@flutter emulators --launch "$(ANDROID_EMULATOR)"

android-emu-list: ## List available Android emulators
	flutter emulators

## Build
build-apk: ## Build Android APK release (Supabase from .env.prod)
	@$(call flutter_build_defines); \
	set -a && [ -f .env ] && . ./.env; . ./.env.prod; set +a && \
	flutter build apk --release \
		--dart-define=SUPABASE_URL="$$SUPABASE_URL" \
		--dart-define=SUPABASE_ANON_KEY="$$SUPABASE_ANON_KEY" \
		--dart-define=SUPABASE_REDIRECT_URL="$${SUPABASE_REDIRECT_URL:-athlos://auth-callback}" \
		--dart-define=GEMINI_API_KEY="$$GEMINI_API_KEY" \
		--dart-define=CHIRON_DEBUG_TRACE=$(CHIRON_DEBUG_TRACE)

build-aab: ## Build Android App Bundle release (.env.prod)
	@$(call flutter_build_defines); \
	set -a && [ -f .env ] && . ./.env; . ./.env.prod; set +a && \
	flutter build appbundle --release \
		--dart-define=SUPABASE_URL="$$SUPABASE_URL" \
		--dart-define=SUPABASE_ANON_KEY="$$SUPABASE_ANON_KEY" \
		--dart-define=SUPABASE_REDIRECT_URL="$${SUPABASE_REDIRECT_URL:-athlos://auth-callback}" \
		--dart-define=GEMINI_API_KEY="$$GEMINI_API_KEY"

build-ipa: ## Build iOS IPA release (.env.prod)
	@$(call flutter_build_defines); \
	set -a && [ -f .env ] && . ./.env; . ./.env.prod; set +a && \
	flutter build ipa --release --no-codesign \
		--dart-define=SUPABASE_URL="$$SUPABASE_URL" \
		--dart-define=SUPABASE_ANON_KEY="$$SUPABASE_ANON_KEY" \
		--dart-define=SUPABASE_REDIRECT_URL="$${SUPABASE_REDIRECT_URL:-athlos://auth-callback}" \
		--dart-define=GEMINI_API_KEY="$$GEMINI_API_KEY"

## Generate
gen: ## Run build_runner one-shot
	dart run build_runner build --delete-conflicting-outputs

gen-l10n: ## Generate localization files
	flutter gen-l10n

## Quality
analyze: ## Run Flutter analyzer
	flutter analyze

clean: ## Clean and restore packages
	flutter clean
	flutter pub get
