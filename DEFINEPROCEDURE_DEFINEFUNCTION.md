# defineProcedure and defineFunction

This document describes the `defineProcedure` and `defineFunction` functions in kklass - convenience wrappers around `defineMethod` for different method types.

## Overview

Both functions are wrappers around `defineMethod` that provide explicit semantic intent:

- **`defineProcedure`**: Defines a method that performs an action but doesn't return a value
- **`defineFunction`**: Defines a method that computes and returns a value

## defineProcedure

### Syntax
```bash
defineProcedure CLASS_NAME PROCEDURE_NAME BODY
```

### Parameters
- `CLASS_NAME`: Name of the class to add the procedure to
- `PROCEDURE_NAME`: Name of the procedure
- `BODY`: Bash code to execute (can modify properties via dot notation)

### Usage Example
```bash
defineClass "Logger" "" \
    "property" "messages"

defineProcedure "Logger" "log" '
    if [[ -z "$messages" ]]; then
        messages="$1"
    else
        messages="$messages"$'\n'"$1"
    fi
'

Logger.new logger
logger.log "First message"
logger.log "Second message"

echo "$(logger.messages)"
```

### Characteristics
- Executes code in the context of the instance
- Can access and modify instance properties as local variables
- Properties are automatically written back to the instance
- Does not return a value (output via stdout is discarded)
- Useful for state mutations and side effects

## defineFunction

### Syntax
```bash
defineFunction CLASS_NAME FUNCTION_NAME BODY
```

### Parameters
- `CLASS_NAME`: Name of the class to add the function to
- `FUNCTION_NAME`: Name of the function
- `BODY`: Bash code that sets `RESULT` variable to the return value

### Usage Example
```bash
defineClass "Temperature" "" \
    "property" "celsius"

defineFunction "Temperature" "toFahrenheit" '
    RESULT=$((celsius * 9 / 5 + 32))
'

Temperature.new temp
temp.celsius = "100"
temp.toFahrenheit

echo "Result in ${TEMPERATURE_TOFAHRENHEIT}: ${TEMPERATURE_TOFAHRENHEIT}"
```

### Characteristics
- Executes code in the context of the instance
- Can access and modify instance properties as local variables
- MUST set the `RESULT` variable to the return value
- Properties are automatically written back to the instance
- Function result is stored in a global variable: `${CLASSNAME_FUNCTIONNAME}` (uppercase, spaces/dots → underscores)
- Result can be retrieved via the automatically created global variable
- Useful for computations that produce a value

## Result Storage for Functions

When a function is called, the result is stored in a global variable created by the `kk.result` function:

### Naming Convention
The variable name is derived from the format: `ClassName.functionName` → `CLASSNAME_FUNCTIONNAME`

Examples:
- `Temperature.toFahrenheit` → `${TEMPERATURE_TOFAHRENHEIT}`
- `StringUtils.reverseString` → `${STRINGUTILS_REVERSESTRING}`
- `Calculator.square` → `${CALCULATOR_SQUARE}`

## Implementation Details

Both `defineProcedure` and `defineFunction`:

1. Validate that the class exists
2. Delegate to `defineMethod` with the appropriate method type
3. Support dynamic addition to classes (like `defineMethod`)
4. Work with the same property injection and writeback mechanism as `defineMethod`

### Method Types
- `defineProcedure` uses method type: `"method"`
- `defineFunction` uses method type: `"function"`

The difference is that functions automatically append a `kk.result` call to store the `RESULT` variable in a global accessible location.

## Mixing Procedures and Functions

You can freely mix procedures and functions in the same class:

```bash
defineClass "StringCounter" "" \
    "property" "text" \
    "property" "length"

defineFunction "StringCounter" "getLength" '
    RESULT=${#text}
'

defineProcedure "StringCounter" "setText" '
    text="$1"
'

StringCounter.new sc
sc.setText "hello world"
sc.getLength

echo "Text: $(sc.text)"
echo "Length: ${STRINGCOUNTER_GETLENGTH}"
```

## Error Handling

Both functions validate their inputs:

```bash
# Returns error if class doesn't exist
defineProcedure "NonExistentClass" "test" 'echo "test"'

# Returns error if class name is empty
defineProcedure "" "test" 'echo "test"'

# Returns error if procedure/function name is empty
defineProcedure "MyClass" "" 'echo "test"'

# Returns error if body is empty
defineProcedure "MyClass" "test" ''
```

## See Also
- `defineMethod` - Lower-level method definition
- `defineClass` - Class definition
- `kk.result` - Result storage mechanism
- `kk.var` - Variable name normalization
