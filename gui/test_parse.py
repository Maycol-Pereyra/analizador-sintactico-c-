import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from gui.app import parse_output, run_parser, EJEMPLOS_DIR


def leer(nombre):
    with open(os.path.join(EJEMPLOS_DIR, nombre), encoding="utf-8") as f:
        return f.read()


def test_parse_output_formato():
    out = "NODO|0|Programa\nNODO|1|cadena: \"a|b\"\nERROR|3|7|falla | rara\nRESULTADO|ERRORES|1\n"
    assert parse_output(out) == (
        [(0, "Programa"), (1, 'cadena: "a|b"')],
        [(3, 7, "falla | rara")],
        "ERRORES",
    )


def test_valido_sin_errores():
    nodos, errores, resultado = run_parser(leer("valido.txt"))
    assert resultado == "OK" and not errores and nodos[0] == (0, "Programa")


def test_errores_con_posicion_y_recuperacion():
    nodos, errores, resultado = run_parser(leer("errores.txt"))
    assert resultado == "ERRORES" and not nodos
    assert [e[0] for e in errores] == [1, 2, 4, 6, 7, 10]  # un error por linea defectuosa, el analisis continua


if __name__ == "__main__":
    test_parse_output_formato()
    test_valido_sin_errores()
    test_errores_con_posicion_y_recuperacion()
    print("TODOS LOS TESTS PASARON")
