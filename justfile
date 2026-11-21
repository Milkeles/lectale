# Recipes for working on Lectale. `just` lists them.

set shell := ["bash", "-euo", "pipefail", "-c"]

# List the recipes
default:
    @just --list

# Get the packages and install the git hooks
setup:
    flutter pub get
    cd apps/edge_api && npm ci
    prek install

# Run every test suite
test: test-spec test-tools test-edge test-flutter

# Run the bundled and corrected API contract tests
test-spec:
    cd spec/v4.0 && for t in tools/test_*.py; do python3 "$t"; done
    python3 tool/test_openapi_contract.py

# Test the project rule check and the agent guard hook
test-tools:
    python3 -m unittest discover -s tool -p 'test_*.py'

# Typecheck and test the Worker in workerd
test-edge:
    cd apps/edge_api && npm run typecheck && npm test

# Run the Flutter tests
test-flutter *args:
    cd apps/flutter_client && flutter test {{ args }}

# Check formatting, analysis and the project rules
lint: check-rules
    dart format --output=none --set-exit-if-changed apps
    dart analyze --fatal-infos

# Check the rules in tool/check_rules.py on every tracked file
check-rules:
    python3 tool/check_rules.py

# Regenerate the Dart API client from the corrected OpenAPI contract
generate:
    dart run swagger_parser -f contracts/swagger_parser.yaml
    dart format packages/api_client
    cd tool/codegen && npm ci && npm run generate

# Build the web app and serve it with the Worker on localhost:8787
run-web:
    cd apps/flutter_client && flutter build web
    cd apps/edge_api && npx wrangler dev

# Build the web app into apps/flutter_client/build/web
build-web:
    cd apps/flutter_client && flutter build web --release

# Build the Linux app
build-linux:
    cd apps/flutter_client && flutter build linux --release

# Build the Android app (debug-signed)
build-android:
    cd apps/flutter_client && flutter build apk --debug

# Build the Windows app (run on Windows)
build-windows:
    cd apps/flutter_client && flutter build windows --release

# Build the iOS app without signing (run on macOS)
build-ios:
    cd apps/flutter_client && flutter build ios --release --no-codesign

# Build the macOS app (run on macOS)
build-macos:
    cd apps/flutter_client && flutter build macos --release

# List Dart and npm packages with newer versions
outdated:
    flutter pub outdated
    cd apps/edge_api && npm outdated || true

# Scan both lockfiles for known vulnerabilities
scan:
    osv-scanner scan source --lockfile=pubspec.lock --lockfile=apps/edge_api/package-lock.json

# Audit the GitHub Actions workflows
audit:
    zizmor .github/workflows .github/actions
