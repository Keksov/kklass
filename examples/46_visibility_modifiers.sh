#!/bin/bash
# Example 46: Visibility Modifiers (private / protected / public)
# Demonstrates access-control sections in the declarative (Pascal-style) API.
# A private or protected member accessed from OUTSIDE its class emits a warning
# on stderr — it is a diagnostic aid, not a hard block (the value is still returned).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Visibility Modifiers Example ==="
echo

# BankAccount: a private field, a protected helper, and a public API.
declareClass "BankAccount" ""
privateSection
    field "balance"
protectedSection
    procedure "audit"
publicSection
    constructor "Create"
    procedure "deposit"
    procedure "withdraw"
    func "getBalance"
endClass

implementConstructor "BankAccount" 'balance="${1:-0}"'
implement "BankAccount.audit" 'echo "[audit] balance is now $balance" >&2'
implement "BankAccount.deposit" 'balance=$((balance + $1)); $this.audit'
implement "BankAccount.withdraw" 'if (( $1 > balance )); then echo "Insufficient funds" >&2; return 1; fi; balance=$((balance - $1)); $this.audit'
implement "BankAccount.getBalance" 'RESULT="$balance"'
endImplementation "BankAccount"

# Create an account with an initial balance (constructor receives 50).
BankAccount.new account 50
echo "Initial balance (public getBalance): $(account.getBalance)"

# The public API works cleanly. deposit/withdraw call the PROTECTED 'audit'
# internally — no visibility warning, because that call is from within the class.
account.deposit 100
account.withdraw 30
echo "Balance after deposit(100)/withdraw(30): $(account.getBalance)"
echo

# Reading the PRIVATE field directly from outside emits a warning on stderr but
# still returns the value (kklass warns, it does not hard-block).
echo "Reading private 'balance' from outside the class:"
warning="$(account.balance 2>&1 >/dev/null)"
value="$(account.balance 2>/dev/null)"
echo "  returned value: $value"
if [[ "$warning" == *private*BankAccount.balance* ]]; then
    echo "  ✓ got the expected visibility warning:"
    echo "    $warning"
else
    echo "  ✗ expected a private-access warning, got: '$warning'"
    exit 1
fi
echo

# Sanity-check the final balance (50 + 100 - 30 = 120).
if [[ "$(account.getBalance)" == "120" ]]; then
    echo "✓ Visibility modifiers working correctly"
else
    echo "✗ Unexpected balance: $(account.getBalance)"
    exit 1
fi

account.delete
echo
echo "=== Example completed successfully ==="
