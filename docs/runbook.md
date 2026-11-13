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

La alerta se dispara cuando más del 5 % de las llamadas dan error 5xx en 5 minutos. Se evalúa cada 5 minutos, y los datos tardan en llegar a Application Insights.

Tiempo medido en el ensayo del 10/11/2026 (dev): se rompió la Function a las 21:07:41 y la alerta se disparó a las 21:10, unos **3 minutos** después, y activó el grupo de acciones. Contar con **entre 3 y 10 minutos** de espera. El mail de "alerta disparada" no se pudo medir: en ese ensayo no llegó porque los receptores estaban sin verificar (ver el final de esta sección). El mail de **"Resuelta"** sí llegó, ya con el mail verificado, a las 22:01 (hora de Uruguay): unos 30 minutos después de la última llamada con error (21:30) y 21 minutos después de restaurar la Function (21:40). Por eso, no esperar que la alerta se cierre rápido. El tiempo del mail de "disparada" se mide en el ensayo del día antes (24 de noviembre).

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

3. Llamar a la API **de forma sostenida durante unos 5 minutos**. Una ráfaga corta no alcanza: si la alerta evalúa antes de que los datos lleguen a Application Insights, esos errores no los ve. Cada llamada tiene que responder `{"error": ...}` con código 500.

```bash
for i in $(seq 1 100); do curl -s -o /dev/null -w "%{http_code} " -X POST "<api_url>"; sleep 3; done
```

4. Mostrar la alerta en el portal (Monitor, Alertas, Historial). El mail llega a Juliana, pero no se cuenta con él en la demo (ver el final de esta sección).
5. **Restaurar enseguida** el valor anotado:

```bash
az functionapp config appsettings set --name "$FUNCION" --resource-group rg-cloudcv-dev --settings TABLE_NAME=<valor anotado>
```

6. Comprobar que la API vuelve a responder 200 y que la alerta se cierra sola (aviso de resuelta).

**Antes de ensayar, comprobar que los mails estén verificados.** Azure pide confirmar cada dirección nueva con un código de un solo uso (OTP) que vence a los 30 minutos ([documentación de Microsoft](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups)). Mientras figura como **Pendiente**, ese receptor no recibe las alertas. La verificación queda guardada para todo el tenant, así que una dirección ya verificada no se vuelve a pedir en los grupos de acciones que se creen después. Se revisa en el portal: Monitor, Grupos de acciones, `ag-cloudcv-equipo`, columna de verificación. Si alguno dice Pendiente: **Reenviar** e ingresar el código.

En el ensayo, el mail llegó a la bandeja de Juliana pero no a la de Macarena. Probablemente sea un filtro de la UCU, por eso en la demo se muestra la alerta en el portal y no el mail.

Probado el 10/11/2026: el procedimiento funciona. Al cambiar el ajuste la Function se reinicia, así que esperar un minuto antes de llamar a la API, y también después de restaurar el valor.

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

- [ ] Desplegar el día anterior (la entrega es el 18 de noviembre y la defensa el 25, así que desplegar el 24), verificar y ensayar la prueba de la alerta.
- [ ] Revisar que los dos mails del grupo de acciones digan Suscrito (o Verificado); si alguno dice Pendiente, **Reenviar** e ingresar el código (vence a los 30 minutos).
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
| Falla el paso "subir el código de la Function" (`Failed to deploy web package`) justo después de crear todo | Algo pasajero con la Function recién creada (no confirmamos la causa exacta) | Usar **Re-run failed jobs** en la ejecución y aprobar `dev` de nuevo. En el redeploy del 12/11 salió bien en el segundo intento |
| El mail de la alerta no llega | El receptor figura "Pendiente" en el grupo de acciones: no confirmó el código | En Monitor, Grupos de acciones, `ag-cloudcv-equipo`, **Reenviar** e ingresar el código. Revisar también spam y la cuarentena de la UCU |

Tiempos medidos el 12/11/2026 en `dev`: el `destroy` tardó **1 min 33 s**. El redeploy necesitó dos intentos: el primero creó todo (4 min 3 s) y falló al subir la Function; el segundo, que solo reintenta el job, terminó bien en 1 min 30 s. Después de destruir, el contador arranca de cero y las direcciones del sitio y de la API son nuevas.

## 9. Quién hace qué

Defensa del 25 de noviembre, unos 12 minutos. Antes se despliega todo el día 24 (ver sección 3).

| Minutos | Quién | Qué muestra |
|---|---|---|
| 0 a 4 | Macarena | La arquitectura y el CV funcionando con su contador |
| ~4 | Macarena | Rompe la Function a propósito (curl con errores desde otra terminal) |
| 4 a 9 | Juliana | Pipeline de un PR a Azure (checks, plan, aprobación, deploy), OIDC sin contraseñas, permisos de la identidad y Checkov |
| 9 a 11 | Macarena | Dashboard con el pico de errores y la alerta disparada en el portal (Monitor, Alertas, Historial) |
| 11 a 12 | Juliana | Restaura la Function y muestra la captura de la alerta "Resuelta" (tarda 20 a 30 minutos en cerrarse, no se espera en vivo) |
| Cierre | Macarena | Costos reales (FinOps) y preguntas |

El mail de la alerta le llega a Juliana (el de Macarena no se pudo verificar), por eso la alerta se muestra en el portal.

Preguntas que Juliana debe poder responder: por qué OIDC, qué pasa si roban la identidad del pipeline, por qué hay 25 skips de Checkov, quién aprueba el deploy, y por qué el run `deploy #1` de la rama `feature/deploy` salió en rojo (YAML mal indentado, corregido antes de unir a `main`).