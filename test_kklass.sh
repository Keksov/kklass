#!/bin/bash
# Тесты для kklass_cnfh.sh

source ./kklass_cnfh.sh

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

test_count=0
pass_count=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected="$3"
    
    test_count=$((test_count + 1))
    
    local result
    result=$(eval "$test_cmd" 2>&1)
    
    if [[ "$result" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: $expected"
        echo "  Got: $result"
    fi
}

# TEST 1: Создание объекта класса Person и проверка начальных значений
echo "=== TEST 1: Constructor and initial values ==="
Person.new person1
person1.getName
echo "---"
