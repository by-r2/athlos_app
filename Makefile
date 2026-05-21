-include .env
export

SIM_DEVICE ?= iPhone 17 Pro
SIM_UDID ?=
IOS_SIM_TARGET := $(if $(SIM_UDID),$(SIM_UDID),$(SIM_DEVICE))
IOS_DEVICE_UDID ?=
ANDROID_EMULATOR ?= dev_pixel7_api34
ANDROID_DEVICE ?= android

CHIRON_DEBUG_TRACE ?= false
SEED ?= 1

DART_DEFINES = \
	--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
	--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) \
	--dart-define=SUPABASE_REDIRECT_URL=$(or $(SUPABASE_REDIRECT_URL),athlos://auth-callback) \
	--dart-define=GEMINI_API_KEY=$(GEMINI_API_KEY)

_SEED_DEFINE = $(if $(filter 0,$(SEED)),--dart-define=SKIP_DEV_SEED=true)
DEBUG_DART_DEFINES = $(DART_DEFINES) $(_SEED_DEFINE)
PROD_DART_DEFINES = $(DART_DEFINES) --dart-define=CHIRON_DEBUG_TRACE=$(CHIRON_DEBUG_TRACE) --dart-define=ENV=prod

.PHONY: help run-ios run-ios-device run-android ios-sim-open ios-sim-list android-sim-open android-emu-list build-apk build-aab build-ipa gen gen-l10n analyze clean

help: ## Show organized command list
	@echo ""
	@echo "Athlos Makefile"
	@echo "------------------------------------------------------------"
	@printf "  %-20s %s\n" "SIM_DEVICE" "$(SIM_DEVICE)"
	@printf "  %-20s %s\n" "IOS_DEVICE_UDID" "$(if $(IOS_DEVICE_UDID),<definido>,<não definido>)"
	@printf "  %-20s %s\n" "ANDROID_EMULATOR" "$(ANDROID_EMULATOR)"
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
	@echo "  make run-ios"
	@echo "  make run-ios SEED=0"
	@echo "  make run-ios-device IOS_DEVICE_UDID=<your_device_udid>"
	@echo "  make run-android ANDROID_EMULATOR=dev_pixel7_api34"
	@echo ""

## Run
run-ios: ## Run debug on iOS simulator (name or UDID)
	@xcrun simctl boot "$(IOS_SIM_TARGET)" 2>/dev/null || true
	flutter run -d "$(IOS_SIM_TARGET)" $(DEBUG_DART_DEFINES)

run-ios-device: ## Run profile on physical iPhone (near-prod, free signing)
	@if [ -z "$(IOS_DEVICE_UDID)" ]; then \
		echo "ERROR: set IOS_DEVICE_UDID=<your_device_udid>"; \
		exit 1; \
	fi
	flutter run --profile -d "$(IOS_DEVICE_UDID)" $(PROD_DART_DEFINES)

run-android: ## Run debug on Android emulator
	@flutter emulators --launch "$(ANDROID_EMULATOR)" 2>/dev/null || true
	flutter run -d "$(ANDROID_DEVICE)" $(DEBUG_DART_DEFINES)

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
build-apk: ## Build Android APK release
	flutter build apk --release $(DART_DEFINES) --dart-define=CHIRON_DEBUG_TRACE=$(CHIRON_DEBUG_TRACE)

build-aab: ## Build Android App Bundle release
	flutter build appbundle --release $(DART_DEFINES)

build-ipa: ## Build iOS IPA release (no codesign)
	flutter build ipa --release --no-codesign $(DART_DEFINES)

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
