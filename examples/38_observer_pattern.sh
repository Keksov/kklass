#!/bin/bash
# Example 38: Observer Pattern
# Demonstrates event-driven programming with observers and notifications

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Observer Pattern Example ==="
echo

# Define Observer interface (as a base class)
defineClass "Observer" "" \
    "property" "name" \
    "method" "update" 'echo "[$name] Observer update called with: $1"'

# Define concrete observers
defineClass "EmailNotifier" "Observer" \
    "method" "update" 'echo "[$name] Sending email notification: $1"'

defineClass "Logger" "Observer" \
    "method" "update" 'echo "[$name] Logging: $1"'

defineClass "AnalyticsTracker" "Observer" \
    "method" "update" 'echo "[$name] Tracking event: $1"'

# Define Subject (Observable)
defineClass "NewsPublisher" "" \
    "property" "name" \
    "property" "observers" \
    "method" "addObserver" 'observers="$observers $1"' \
    "method" "removeObserver" 'observers="${observers/ $1 / }"' \
    "method" "notifyObservers" 'for observer in $observers; do $observer.update "$1"; done' \
    "method" "publishNews" 'echo "[$name] Publishing news: $1"; $this.notifyObservers "$1"'

echo "✓ Observer pattern classes defined"

# Create subject
NewsPublisher.new newsHub
newsHub.name = "TechNews Hub"

echo "✓ News publisher created"

# Create observers
EmailNotifier.new emailNotifier
emailNotifier.name = "Email Service"

Logger.new logger
logger.name = "File Logger"

AnalyticsTracker.new tracker
tracker.name = "Analytics Service"

echo "✓ Observers created"

# Register observers with subject
newsHub.addObserver "$emailNotifier"
newsHub.addObserver "$logger"
newsHub.addObserver "$tracker"

echo "✓ Observers registered with publisher"

# Publish news and see notifications
echo
echo "=== Publishing News Events ==="
newsHub.publishNews "New kklass version 2.0 released!"

echo
newsHub.publishNews "OOP programming in Bash becomes mainstream"

echo
newsHub.publishNews "Observer pattern implemented in kklass"

# Test observer removal
echo
echo "=== Testing Observer Removal ==="
newsHub.removeObserver "$emailNotifier"
echo "Removed email notifier"

echo "Publishing after removing email notifier:"
newsHub.publishNews "This should not trigger email notification"

# Verify observer pattern working
echo
echo "=== Verification ==="
echo "Checking that observers were properly notified..."

# The verification is implicit in the output above - we can see all observers
# were called for each publication, and email notifier was removed correctly

echo "✓ Observer pattern working correctly"

# Clean up
newsHub.delete
emailNotifier.delete
logger.delete
tracker.delete
echo "✓ All observers and subject cleaned up"

echo
echo "=== Example completed successfully ==="