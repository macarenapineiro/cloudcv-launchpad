"""Lógica del contador de visitas.

Está separada de function_app.py para poder probarla sin Azure:
el test le pasa una tabla "falsa" en lugar de la tabla real.
"""

from azure.core import MatchConditions
from azure.core.exceptions import (
    ResourceExistsError,
    ResourceModifiedError,
    ResourceNotFoundError,
)
from azure.data.tables import UpdateMode

# La tabla tiene una sola fila: la del contador del CV.
PARTITION_KEY = "contador"
ROW_KEY = "cv"
INTENTOS = 5


def sumar_visita(tabla):
    """Suma 1 al contador y devuelve el total.

    Si dos personas entran al mismo tiempo, las dos podrían leer el mismo número.
    Para no perder visitas, al guardar le decimos a la tabla:
    "guardá solo si nadie la cambió desde que la leí" (etag).
    Si alguien la cambió, volvemos a leer y probamos de nuevo.
    """
    for _ in range(INTENTOS):
        try:
            fila = tabla.get_entity(PARTITION_KEY, ROW_KEY)
        except ResourceNotFoundError:
            # Primera visita: la fila todavía no existe, la creamos con 1.
            try:
                tabla.create_entity(
                    {"PartitionKey": PARTITION_KEY, "RowKey": ROW_KEY, "visitas": 1}
                )
                return 1
            except ResourceExistsError:
                continue  # otra visita la creó justo antes: volvemos a intentar

        fila["visitas"] = int(fila["visitas"]) + 1
        try:
            tabla.update_entity(
                fila,
                mode=UpdateMode.REPLACE,
                etag=fila.metadata["etag"],
                match_condition=MatchConditions.IfNotModified,
            )
            return fila["visitas"]
        except ResourceModifiedError:
            continue  # alguien la cambió entre que leímos y guardamos

    raise RuntimeError("No se pudo actualizar el contador después de varios intentos")
