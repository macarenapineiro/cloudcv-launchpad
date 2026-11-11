# CloudCV Launchad
Proyecto de Cloud Computing, realizado por Juliana Hernandez y Macarena Piñeiro.

### ¿Qué es?  
Es un CV publicado como página web, con un contador que muestra cuántas veces se visitó. Realizado con Azure y Terraform.

### ¿Cómo funciona?   
1. La página del CV está guardada en una cuenta de Storage de Azure, que la publica como sitio web con HTTPS.
2. Cuando alguien entra, el JS de la página llama a una Azure Functtion (un pedazo de código que solo corre cuand lo llaman).
3. La función suma 1 al contador, que está guardado en una tabla y devuele el número para mostrarlo en la página.
4. Cada vez que subimos cambios a GitHub, GitHub Actions revisa el código y lo despliega en Azure. Para entrar a Azure no usa contraseñas guardadas en el repo, sino un permiso que Azure le da a nuestro repo.

### ¿Por qué lo hicimos así?
* La página está en Storage y no en Static Web Apps, ya que nuestra suscripción de estudiantes solo deja crear cosas en algunas regiones, y Static Wrb App no está en ninguna de ellas.
* Usamos Table Storage para el contador, debido a que solo guardamos un número, así que no hace falta una base de datos más grande.
La página es pública: es un CV, la idea es que cualquiera lo pueda ver.

### Reglas que seguimos
**Región:** `canadacentral`. Es una de las que permite la suscripción y es más barata que Brasil.
**Nombres:** todo empieza con `cloudcv`, sin guiones, porque Storage no los acepta.
**Etiquetas en todos los recursos:** `project`, `team`, `env` y `owner`, para saber de quién es cada cosa y cuánto cuesta.
**Cambios:** todo entra por Pull Request y lo revisa la otra antes de unirlo a `main`.

### ¿Qué hay en cada carpeta?
* `app/site/`: la página del CV
* `app/function/`: el código del contador
* `infra/`: el código de Terradorm
* `docs/`: diagrama y documentación
* `.github/workflows/`: los pasos automáticos de GitHub Actions

### Cómo desplegar y destruir
El paso a paso completo está en [docs/runbook.md](docs/runbook.md). Resumen:

**Desplegar**
1. Abrir un Pull Request: el plan de OpenTofu aparece como comentario.
2. Cuando la otra persona lo aprueba y se une a `main`, arranca el workflow `deploy`.
3. El job espera aprobación del entorno `dev`: **Review deployments**, marcar `dev` y **Approve and deploy**.
4. Crea la infraestructura (36 recursos, unos 4 minutos la primera vez) y sube el código de la Function. Al final imprime la dirección del sitio y de la API.
5. Verificar: abrir el sitio y comprobar que el contador sube.

**Destruir**
1. Pestaña **Actions**, workflow **destroy**, **Run workflow**, rama `main`, y escribir `destruir` en el campo.
2. Aprobar en **Review deployments**.
3. Comprobar que quedó vacío: `az resource list --resource-group rg-cloudcv-dev -o table`.

Lo que no se destruye, a propósito: el estado remoto y la identidad del pipeline (`rg-cloudcv-tfstate`) y el presupuesto. Cuestan centavos y el próximo despliegue los necesita.

**Seguridad:** el repo es público, así que no hay mails ni claves en el código. Los mails de las alertas están en el secreto `ALERT_EMAILS` de GitHub y el pipeline entra a Azure con OIDC, sin contraseñas. Más detalle en [docs/iam.md](docs/iam.md).
