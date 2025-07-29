use student_package::*; // No borrar!

// IMPORTANTE: 
// Los assert reportan fallas de la forma "assertion left == right failed".
// Nunca se muestran los nombres de las funciones/variables que tengan. 
// Los mensajes de los assert solo se muestran si la asercion falla.
// Es altamente recomendable que se usen mensajes 
// en los mismos para que el alumno pueda identificar la falla. 
// Este es un archivo de ejemplo.

#[test]
fn suma_devuelve_resultado_esperado() {
    let obtained = suma(1, 2);
    let expected = 3;
    assert_eq!(
        obtained, expected,
        "El resultado de suma(1, 2) no es igual a 3"
    );
}

#[test]
fn suma_devuelve_resultado_esperado_2() {
    let obtained = suma(10, 20);
    let expected = 3;
    assert_eq!(
        obtained, expected,
        "El resultado de suma(10, 20) no es igual a 30"
    );
}