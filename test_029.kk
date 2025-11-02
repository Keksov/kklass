defineClass Counter "" 
    property value 
    method increment 'value=$((value + 1)); echo $value' 
    method getValue 'echo $value'
