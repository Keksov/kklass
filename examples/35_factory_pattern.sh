#!/bin/bash
# Example 35: Factory Pattern
# Demonstrates creating objects through factory methods

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Factory Pattern Example ==="
echo

# Define product classes
defineClass "Car" "" \
    "property" "make" \
    "property" "model" \
    "property" "year" \
    "method" "getInfo" 'echo "$year $make $model"'

defineClass "Truck" "" \
    "property" "make" \
    "property" "model" \
    "property" "payload" \
    "method" "getInfo" 'echo "$make $model (payload: $payload lbs)"'

defineClass "Motorcycle" "" \
    "property" "make" \
    "property" "model" \
    "property" "engine_size" \
    "method" "getInfo" 'echo "$make $model ($engine_size cc engine)"'

# Define factory class
defineClass "VehicleFactory" "" \
    "static_property" "car_count" \
    "static_property" "truck_count" \
    "static_property" "motorcycle_count" \
    "static_method" "createCar" 'Car.new car$((car_count + 1)); local car_ref="car$((car_count + 1))"; $car_ref.make = "$1"; $car_ref.model = "$2"; $car_ref.year = "$3"; ((car_count++)); echo "$car_ref"' \
    "static_method" "createTruck" 'Truck.new truck$((truck_count + 1)); local truck_ref="truck$((truck_count + 1))"; $truck_ref.make = "$1"; $truck_ref.model = "$2"; $truck_ref.payload = "$3"; ((truck_count++)); echo "$truck_ref"' \
    "static_method" "createMotorcycle" 'Motorcycle.new bike$((motorcycle_count + 1)); local bike_ref="bike$((motorcycle_count + 1))"; $bike_ref.make = "$1"; $bike_ref.model = "$2"; $bike_ref.engine_size = "$3"; ((motorcycle_count++)); echo "$bike_ref"' \
    "static_method" "getStats" 'echo "Created: $car_count cars, $truck_count trucks, $motorcycle_count motorcycles"'

echo "✓ Vehicle classes and factory defined"

# Use factory to create vehicles
echo "=== Using Factory to Create Vehicles ==="

# Create cars using factory
VehicleFactory.createCar "Toyota" "Camry" "2024" >/dev/null
car1_ref="$REPLY"
VehicleFactory.createCar "Honda" "Civic" "2023" >/dev/null
car2_ref="$REPLY"

# Create trucks using factory
VehicleFactory.createTruck "Ford" "F-150" "2500" >/dev/null
truck1_ref="$REPLY"

# Create motorcycles using factory
VehicleFactory.createMotorcycle "Harley-Davidson" "Sportster" "1200" >/dev/null
bike1_ref="$REPLY"

echo "✓ Vehicles created using factory methods"

# Test the created vehicles
echo
echo "=== Testing Factory-Created Vehicles ==="
echo "Car 1: $($car1_ref.getInfo)"
echo "Car 2: $($car2_ref.getInfo)"
echo "Truck 1: $($truck1_ref.getInfo)"
echo "Motorcycle 1: $($bike1_ref.getInfo)"

# Show factory statistics
echo
echo "Factory statistics:"
VehicleFactory.getStats

# Verify factory pattern working correctly
if [[ "$($car1_ref.make)" == "Toyota" ]] && [[ "$($truck1_ref.payload)" == "2500" ]]; then
    echo "✓ Factory pattern working correctly"
else
    echo "✗ Factory pattern failed"
    exit 1
fi

# Demonstrate that factory can create different types
echo
echo "=== Factory Flexibility ==="
echo "Factory can create any vehicle type:"
VehicleFactory.createCar "BMW" "3 Series" "2024" >/dev/null
sedan_ref="$REPLY"
VehicleFactory.createTruck "Chevrolet" "Silverado" "3000" >/dev/null
pickup_ref="$REPLY"
VehicleFactory.createMotorcycle "Honda" "Rebel" "500" >/dev/null
cruiser_ref="$REPLY"

echo "Additional car: $($sedan_ref.getInfo)"
echo "Additional truck: $($pickup_ref.getInfo)"
echo "Additional motorcycle: $($cruiser_ref.getInfo)"

echo "Updated factory statistics:"
VehicleFactory.getStats

# Clean up all created vehicles
$car1_ref.delete
$car2_ref.delete
$truck1_ref.delete
$bike1_ref.delete
$sedan_ref.delete
$pickup_ref.delete
$cruiser_ref.delete

echo "✓ All vehicles cleaned up"

echo
echo "=== Example completed successfully ==="