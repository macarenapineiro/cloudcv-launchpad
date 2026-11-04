"""Azure Function del contador de visitas.

POST /api/visitas  ->  suma una visita y devuelve {"visitas": <total>}
"""

import json
import logging
import os

import azure.functions as func
from azure.data.tables import TableClient
from azure.identity import DefaultAzureCredential

from contador import sumar_visita

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


def abrir_tabla():
    # Sin claves: DefaultAzureCredential usa la identidad administrada de la Function.
    # La dirección y el nombre de la tabla los carga Terraform como configuración.
    return TableClient(
        endpoint=os.environ["TABLE_ENDPOINT"],
        table_name=os.environ["TABLE_NAME"],
        credential=DefaultAzureCredential(),
    )


@app.route(route="visitas", methods=["POST"])
def visitas(req: func.HttpRequest) -> func.HttpResponse:
    try:
        total = sumar_visita(abrir_tabla())
    except Exception:
        logging.exception("Error al actualizar el contador")
        return func.HttpResponse(
            json.dumps({"error": "No se pudo actualizar el contador"}),
            status_code=500,
            mimetype="application/json",
        )

    return func.HttpResponse(
        json.dumps({"visitas": total}),
        status_code=200,
        mimetype="application/json",
    )
