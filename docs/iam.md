# Matriz IAM

Quién puede hacer qué en el proyecto, sobre qué recurso y por qué. El criterio es el menor privilegio. Los IDs que aparecen en el repo son identificadores, no credenciales.

## 1. Identidad del pipeline (GitHub Actions)

Identidad: `id-cloudcv-github` (identidad administrada, en `rg-cloudcv-tfstate`). No tiene contraseña ni claves: GitHub presenta un token OIDC que dura minutos, y Azure lo acepta solo si coincide con una de estas credenciales federadas (emisor `https://token.actions.githubusercontent.com`, audiencia `api://AzureADTokenExchange`). El subject incluye los IDs numéricos del dueño y del repo, así que si el repo se borra y se crea otro con el mismo nombre, no puede usar la identidad.

| Credencial | Cuándo la usa GitHub | Para qué |
| --- | --- | --- |
| `github-main` | Rama `main` | Despliegue desde `main` |
| `github-pull-request` | Pull requests | `plan` en cada PR |
| `github-environment-dev` | Environment `dev` | `apply` con aprobación manual |

| Rol | Recurso | Justificación | Cómo se asigna |
| --- | --- | --- | --- |
| Storage Blob Data Contributor | Contenedor `tfstate` | Leer y escribir el state y bloquearlo mientras alguien aplica | Código (bootstrap) |
| Contributor | `rg-cloudcv-dev` | Crear y modificar los recursos del proyecto | Código (bootstrap) |
| Role Based Access Control Administrator, con condición | `rg-cloudcv-dev` | Contributor no puede crear asignaciones de rol, y hacen falta para que la Function reciba su permiso sobre la tabla y para subir archivos al sitio | Código (bootstrap) |

La condición del tercer rol permite crear y borrar asignaciones solo de dos roles: Storage Table Data Contributor (`0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3`) y Storage Blob Data Contributor (`ba92f5b4-2d11-453d-a403-e96b0029c9fe`).

Lo que el pipeline no puede hacer: nada a nivel suscripción (no registra proveedores ni crea presupuestos), nada fuera de `rg-cloudcv-dev` y del contenedor del state, y no puede darse a sí mismo Owner ni ningún otro rol que no esté en la lista.

## 2. Personas

| Persona | Rol | Recurso | Justificación | Cómo se asigna |
| --- | --- | --- | --- | --- |
| Juliana | Contributor | Suscripción | Crear recursos y el presupuesto | Heredado de la suscripción |
| Juliana | Role Based Access Control Administrator | `rg-cloudcv-tfstate` y `rg-cloudcv-dev` | Aplicar el bootstrap, que crea asignaciones de rol | Manual (portal), fuera del código |
| Juliana | Storage Blob Data Contributor | Contenedor `tfstate` | Correr `tofu plan` desde su computadora | Código (`state_users`) |
| Macarena | Owner | Suscripción | Titular: administra la suscripción | Propio de la suscripción |
| Macarena | Storage Blob Data Contributor | Contenedor `tfstate` | Correr `tofu plan` desde su computadora | Código (`state_users`) |

## 3. Identidades de la aplicación

| Identidad | Rol | Recurso | Justificación |
| --- | --- | --- | --- |
| Function `func-cloudcv-*` (identidad del sistema) | Storage Table Data Contributor | Tabla `visitas` | Leer y escribir la fila del contador. Solo esa tabla, nada más de la cuenta |
| Quien corre OpenTofu (pipeline o integrante) | Storage Blob Data Contributor | Cuenta de Storage del sitio | Subir los archivos a `$web` con Azure AD, sin claves de la cuenta |

## 4. Accesos anónimos y claves (excepciones justificadas)

| Recurso | Acceso | Justificación | Controles |
| --- | --- | --- | --- |
| Sitio estático (`$web`) | Lectura pública por HTTPS | Es un CV público | Ningún otro contenedor es público |
| Function `/api/visitas` | Anónimo | Un navegador no puede guardar una clave | CORS al origen del sitio (limita a los navegadores, no es autenticación), tope de instancias, tope diario de logs y presupuesto |
| Cuenta del state | Sin claves | Solo entra Azure AD | Versionado y borrado suave de 7 días |
| Cuenta de datos (tabla) | Sin claves | Solo entra la identidad de la Function | Borrado suave de 7 días |
| Cuenta interna de la Function | Con clave (connection string) | El provider tiene un error conocido con identidades en Flex Consumption | La clave vive solo en Azure y en el state, nunca en el repo. No guarda datos del CV |
| Cuenta del sitio | Sin claves | Solo entra Azure AD; el único acceso público es la lectura de `$web` | Las subidas usan Azure AD |

## 5. Controles en GitHub

- El environment `dev` exige la aprobación de una de las dos integrantes antes del `apply`.
- Las variables del repo (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) son identificadores, no secretos. No hay secretos de larga duración.
- Los workflows de colaboradores externos requieren aprobación, y el job `plan` no corre en PR de forks.
- Pendiente: protección de la rama `main`.

## 6. Limitaciones conocidas y mejoras

1. **Una sola identidad para `plan` y `apply`.** La credencial de pull request tiene los mismos permisos que la del `apply`. Quien tenga permiso de escritura en el repo podría modificar un workflow en un PR y ejecutar cambios sin pasar por la aprobación. Hoy lo mitigan: solo dos colaboradoras y aprobación de workflows externos. Mejora: una segunda identidad de solo lectura para los PR.
2. **Credenciales atadas a los IDs del repo.** Si el repo se recrea o se transfiere, hay que actualizarlas en el bootstrap.
3. **Un permiso manual.** El de Juliana sobre los dos resource groups no está en el código.
4. **El rol Owner de la titular aparece dos veces en el listado.** No se modifica: si se borrara la asignación equivocada, la titular quedaría sin acceso de dueña a la suscripción.

## 7. Limpieza realizada

- Se eliminó una asignación huérfana (Contributor sobre la suscripción, con un principal que ya no existía) de una prueba manual.
- Se redujo de 4 a 2 la lista de roles que el pipeline puede asignar: se sacaron Blob Data Owner y Queue Data Contributor, que ningún módulo usa.
- Se apagaron las claves de la cuenta del sitio, que antes estaban habilitadas.

## 8. Cómo verificar

```bash
az role assignment list --assignee-object-id $(az identity show --name id-cloudcv-github --resource-group rg-cloudcv-tfstate --query principalId -o tsv) --all -o table
az identity federated-credential list --identity-name id-cloudcv-github --resource-group rg-cloudcv-tfstate --query "[].{nombre:name, subject:subject}" -o table
```