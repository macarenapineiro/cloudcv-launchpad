# Runbook: desplegar, probar y destruir

Guía paso a paso para operar CloudCV Launchpad. Está pensada para seguirla en orden, incluso el día de la demo.

## 0. Qué hace cada pieza

| Pieza | Qué es |
| --- | --- |
| Bootstrap (`infra/bootstrap`) | Se aplica una sola vez a mano, con state local. Crea el state remoto, la identidad del pipeline, sus permisos y el presupuesto. No se destruye |
| Entorno `dev` (`infra/envs/dev`) | Todo lo del proyecto: sitio, tabla, Function, dashboard y alerta. Lo crea y lo borra el pipeline |
| `plan.yml` | En cada Pull Request corre `plan` y lo publica como comentario |
| `deploy.yml` | Al unir a `main`, corre `apply` y queda esperando la aprobación del environment `dev` |
| `destroy.yml` | Se dispara a mano. Pide escribir `destruir` y también espera aprobación |

## 1. Antes de empezar

- [ ] En GitHub, las variables del repo `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` y `AZURE_SUBSCRIPTION_ID`.
- [ ] En GitHub, el secret `ALERT_EMAILS` (lista JSON con los mails de las dos integrantes).
- [ ] El environment `dev` con las dos integrantes como revisoras y solo la rama `main` permitida.
- [ ] El presupuesto de USD 10 activo: `cd infra/bootstrap && tofu state list | grep budget`.
- [ ] Sesión de Azure CLI vigente: `az login --use-device-code`. Si da `ExpiredAuthenticationToken`, repetir el login.

## 2. Desplegar

1. Abrir un Pull Request contra `main`. Los chequeos arrancan solos (fmt, validate, tflint, Checkov, tests de la Function y `plan`).
2. Leer el comentario del plan en el PR: tiene que decir `Plan: N to add` y no mostrar ningún mail (aparecen como `***@***`).
3. Unir el PR con **Merge commit**.
4. Si el cambio toca infraestructura o la aplicación, `deploy.yml` arranca solo. Para lanzarlo a mano: pestaña **Actions**, workflow **deploy**, **Run workflow**, rama `main`.
5. El job espera aprobación: abrir la ejecución, apretar **Review deployments**, marcar `dev` y **Approve and deploy**.
6. Al terminar, el último paso imprime la dirección del sitio y de la API.

Tiempo del primer despliegue (36 recursos desde cero): **unos 4 minutos**. El `apply` tardó 3 min 15 s, y casi la mitad es la cuenta de almacenamiento del sitio (1 min 21 s). Subir la Function tardó 21 s. No incluye la espera de aprobación.

## 3. Subir el código de la Function

No hay que hacer nada a mano: `deploy.yml` sube el código solo, justo después del `apply`.

- Usa la acción `Azure/functions-action@v1` con `sku: flexconsumption` y `remote-build: true` (las dependencias de Python se instalan en Azure, no en el runner).
- Entra a Azure con OIDC (`azure/login`) y usa permisos RBAC. No hay claves de publicación ni perfiles de publicación.
- El nombre de la Function sale de `tofu output function_app_name`.
- En el log se reconoce por: `Using RBAC for authentication` y `Successfully deployed web package to Function App`.

## 4. Verificar

```bash
cd infra/envs/dev
tofu init
tofu output
```

1. **Sitio:** abrir la dirección de `sitio`. Tiene que cargar por HTTPS y mostrar el contador.
2. **API:** cada visita suma una.

```bash
curl -s -X POST "<api_url>"
```

La respuesta tiene que ser `{"visitas": N}` y el número tiene que subir en cada llamada.

3. **Dashboard:** portal de Azure, Application Insights de la Function, **Libros**, "CloudCV - Contador de visitas". Muestra visitas, errores y latencia p95 de las últimas 24 horas.
4. **Sin acceso público al dato:** la tabla no tiene claves. Para la demo, mostrar que la cuenta de datos tiene las claves de acceso deshabilitadas.

## 5. Probar la alerta (para la demo)

La alerta se dispara cuando más del 5 % de las llamadas dan error 5xx en 5 minutos. Se evalúa cada 5 minutos, y los datos tardan en llegar a Application Insights, así que **cuenta con varios minutos de espera**. Probarlo en el ensayo y anotar el tiempo real: **(a completar)**.

Para provocar el error, se apunta la Function a una tabla que no existe, de forma temporal:

```bash
cd infra/envs/dev
FUNCION=$(tofu output -raw function_app_name)
az functionapp config appsettings list --name "$FUNCION" --resource-group rg-cloudcv-dev --query "[?name=='TABLE_NAME'].value" -o tsv
```

1. **Anotar el valor que muestra** (es el nombre real de la tabla).
2. Romperla a propósito:

```bash
az functionapp config appsettings set --name "$FUNCION" --resource-group rg-cloudcv-dev --settings TABLE_NAME=noexiste
```

3. Llamar a la API unas veinte veces: cada una tiene que responder `{"error": ...}` con código 500.

```bash
for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code}\n" -X POST "<api_url>"; done
```

4. Esperar el mail de la alerta (llega a las dos integrantes) y mostrarlo en la demo.
5. **Restaurar enseguida** el valor anotado:

```bash
az functionapp config appsettings set --name "$FUNCION" --resource-group rg-cloudcv-dev --settings TABLE_NAME=<valor anotado>
```

6. Comprobar que la API vuelve a responder 200 y que la alerta se cierra sola (aviso de resuelta).

Nota: este procedimiento no está probado todavía. Si el comando de configuración difiere, ajustarlo y dejar el definitivo acá.

## 6. Destruir

1. Pestaña **Actions**, workflow **destroy**, **Run workflow**, rama `main`.
2. En el campo, escribir `destruir`.
3. Aprobar en **Review deployments**.
4. Verificar que quedó vacío:

```bash
az resource list --resource-group rg-cloudcv-dev -o table
```

Qué queda a propósito, porque lo necesita el próximo despliegue y cuesta centavos: el state y la identidad del pipeline (`rg-cloudcv-tfstate`), el presupuesto y el resource group `rg-cloudcv-dev` vacío. Es posible que Azure deje un grupo de acción creado automáticamente por Application Insights: es gratis y se puede borrar a mano.

## 7. Checklist del día antes de la demo

- [ ] Desplegar el día anterior, verificar y ensayar la prueba de la alerta.
- [ ] Presupuesto activo y avisos llegando a las dos integrantes.
- [ ] Todos los recursos con las etiquetas `project`, `team`, `env` y `owner`.
- [ ] Sin recursos huérfanos: revisar la facturación y los resource groups.
- [ ] `destroy` probado al menos una vez.
- [ ] Después de la demo: ejecutar `destroy`, y guardar en `docs/evidencias/` la captura del grupo vacío y de la facturación del mes.

## 8. Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| `ExpiredAuthenticationToken` en `az` o `tofu` | La sesión dura poco | `az logout`, `az account clear` y `az login --use-device-code` |
| `AADSTS700213` en el pipeline | El subject de la credencial federada no coincide | Comparar con `az identity federated-credential list` |
| `403` al leer el state | Falta el rol sobre el contenedor | Esperar un par de minutos o revisar los roles |
| `Error acquiring the state lock` | Otro `apply` o `plan` en curso | Esperar a que termine. No forzar el desbloqueo sin estar segura |
| El `plan` falla al validar `alert_emails` | Falta el secret `ALERT_EMAILS` o no es una lista JSON | Revisar el secret |
| Un `apply` falla con `403` en una asignación de rol | El rol no está en la lista del bootstrap | Revisar la condición del rol RBAC Administrator |

## 9. Quién hace qué

**(a completar)** el reparto para la defensa.