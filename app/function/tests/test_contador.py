"""Tests de la lógica del contador, sin conectarse a Azure.

Se corren con:  python -m pytest app/function/tests
"""

import os
import sys

import pytest
from azure.core.exceptions import ResourceModifiedError, ResourceNotFoundError

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from contador import sumar_visita  # noqa: E402


class Fila(dict):
    """Imita una fila de la tabla: un diccionario con un etag."""

    def __init__(self, datos, etag):
        super().__init__(datos)
        self.metadata = {"etag": etag}


class TablaFalsa:
    """Imita la tabla de Azure guardando la fila en memoria."""

    def __init__(self, visitas=None, conflictos=0):
        self.datos = None if visitas is None else {"visitas": visitas}
        self.version = 1
        self.conflictos = conflictos  # cuántas veces simular que otra visita llegó antes

    def get_entity(self, partition_key, row_key):
        if self.datos is None:
            raise ResourceNotFoundError("no existe")
        return Fila(dict(self.datos), etag=str(self.version))

    def create_entity(self, entidad):
        self.datos = {"visitas": entidad["visitas"]}

    def update_entity(self, fila, mode, etag, match_condition):
        if self.conflictos > 0:
            self.conflictos -= 1
            self.datos["visitas"] += 1  # otra visita guardó primero
            self.version += 1
            raise ResourceModifiedError("cambió")
        if etag != str(self.version):
            raise ResourceModifiedError("cambió")
        self.datos = {"visitas": fila["visitas"]}
        self.version += 1


def test_primera_visita_crea_el_contador_en_1():
    tabla = TablaFalsa()
    assert sumar_visita(tabla) == 1
    assert tabla.datos["visitas"] == 1


def test_suma_una_visita():
    tabla = TablaFalsa(visitas=41)
    assert sumar_visita(tabla) == 42


def test_visitas_seguidas_van_sumando():
    tabla = TablaFalsa()
    resultados = [sumar_visita(tabla) for _ in range(3)]
    assert resultados == [1, 2, 3]


def test_si_otra_visita_guarda_primero_no_se_pierde_ninguna():
    # Hay 10 visitas; otra visita guarda justo antes que la nuestra.
    tabla = TablaFalsa(visitas=10, conflictos=1)
    assert sumar_visita(tabla) == 12  # la de la otra visita (11) + la nuestra (12)


def test_si_falla_siempre_avisa_con_error():
    tabla = TablaFalsa(visitas=5, conflictos=99)
    with pytest.raises(RuntimeError):
        sumar_visita(tabla)
