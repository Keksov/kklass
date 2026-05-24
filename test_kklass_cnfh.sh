#!/bin/bash
# Тесты для kklass_cnfh.sh (версия с command_not_found_handle)
# Важно: работает только в интерактивном режиме или с set +H

source "$(dirname "${BASH_SOURCE[0]}")/kklass_cnfh.sh"

echo "=== Test 1: Создание класса и объектов ==="
Person.new p1
Person.new p2

echo "p1 объект создан"
echo "p2 объект создан"

echo ""
echo "=== Test 2: Вызов методов ==="
echo "p1.greet:"
p1.greet

echo ""
echo "p2.greet:"
p2.greet

echo ""
echo "=== Test 3: Изменение свойств через сеттеры ==="
p1.setName "Alice"
p1.setAge 25

echo "p1 после изменения:"
p1.greet

echo ""
echo "=== Test 4: Проверка независимости объектов ==="
echo "p1.getName: $(p1.getName)"
echo "p2.getName: $(p2.getName)"

echo ""
echo "=== Test 5: День рождения ==="
echo "p1 текущий возраст: $(p1.getAge)"
p1.birthday
echo "p1 новый возраст: $(p1.getAge)"

echo ""
echo "=== Test 6: Информация об объекте p1 ==="
declare -p p1 2>/dev/null

echo ""
echo "=== Test 7: Создание ещё одного объекта ==="
Person.new p3
p3.greet
p3.setName "Charlie"
p3.setAge 40
p3.greet

echo ""
echo "=== Test 8: Проверка независимости всех трёх ==="
echo "p1: $(p1.getName) - $(p1.getAge) лет"
echo "p2: $(p2.getName) - $(p2.getAge) лет"
echo "p3: $(p3.getName) - $(p3.getAge) лет"

echo ""
echo "=== Все тесты завершены ==="
