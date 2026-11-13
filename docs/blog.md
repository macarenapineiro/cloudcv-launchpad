# Blog - Juliana Hernandez y Macarena Piñeiro

Para el proyecto de Cloud elegimos CloudCV Launchpad, el cual consiste en publicar un CV como página web, con un contador que muestra cuántas veces se visitó. Lo interesante es que todo se crea con código, que avisa si algo deja de funcionar y que cueste lo menos posible.

## Cómo está armado

![Diagrama de arquitectura](arquitectura.png)

Hay dos caminos en el diagrama. Arriba está lo que pasa cuando alguien entra al CV y abajo, lo que pasa cuando cambiamos el código.

Cuando alguien entra:

1. El navegador carga la página desde una cuenta de Storage de Azure, que la publica como sitio web con HTTPS.
2. El JavaScript de la página llama a una Azure Function con un `POST /api/visitas`.
3. La Function suma 1 en una tabla y devuelve el número, que se muestra al pie del CV.

Todo está en Azure, en la región `canadacentral`, y todo se crea con OpenTofu. 

## Decisiones al crear el sitio web

Como primera opción tratamos de usar Static Web Apps, pero la suscripción de estudiantes en Azure solo nos deja crear recursos en cinco regiones, y la opción de Static Web Apps no estaba disponible en ninguna de ellas.

Decidimos buscar otra alternativa la cual fue el static website de una cuenta de Storage, en donde subimos el HTML, el CSS y el JS a un contenedor y Azure lo publica en una dirección con HTTPS. 

## El contador

El contador es una Function en Python, en donde escala a cero si nadie visita el CV y no hay nada encendido. Pero en el momento en que haya una primera visita tarda alrededor de un segundo en responder, ya que la Function tiene que "despertarse".

El número se guarda en Table Storage, es una sola fila y un solo número, por lo que no había razones para usar una base de datos más grande.

En cuanto a la seguridad de la tabla, la cuenta de Storage normalmente tiene dos claves que dan acceso a todo. Nosotras las apagamos, por lo que la única forma de entrar es con una identidad de Azure que tenga el permiso justo. La Function tiene su propia identidad y el rol *Storage Table Data Contributor*, el cual le deja leer y escribir filas solo en la tabla `visitas`. Si alguien encontrara la dirección de la tabla no podría entrar. 

Un detalle del código es que si dos personas entran al mismo tiempo, las dos podrían leer "10" y guardar "11", por lo que se perdería una visita. Para evitarlo, al guardar le pedimos a la tabla que guarde el dato si nadie cambió el número desde que se leyó, en el caso de que alguien lo haya cambiado, se vuelve a leer y se prueba de nuevo.

## Quién puede llamar a la Function

La Function tiene que ser pública, porque la llama el navegador de cualquier visitante. Pero le pusimos reglas:

- **Solo HTTPS.** Si alguien la llama por HTTP, responde con una redirección a HTTPS.
- **CORS limitado al sitio.** El navegador solo deja usarla desde la página del CV: si otra página intenta llamarla, el navegador lo bloquea. El CORS no frena a alguien que la llame directo, por ejemplo con `curl`. Pero lo peor que puede hacer es sumar visitas, porque la API no devuelve ningún otro dato.

## Saber si algo se rompe

La Function manda datos a Application Insights cada vez que la llaman, guardando cuánto tardó y si salió bien. Con eso armamos dos cosas:

- **Un dashboard** con las visitas, los errores y la latencia p95 (el 95 % de las visitas tardó menos que ese valor). Usamos el p95 y no el promedio porque una visita muy lenta casi no mueve el promedio, pero en el p95 se nota.
- **Una alerta** que cada 5 minutos revisa si más del 5 % de las llamadas fallaron, y si es así nos manda un mail.

Para probar la alerta, rompimos la Function a propósito: le cambiamos a mano el nombre de la tabla por uno que no existe. Empezó a responder con error 500, el dashboard mostró el pico y a los pocos minutos la alerta se disparó. Después corrimos `tofu apply`, que detectó el cambio hecho a mano y volvió a dejar el nombre correcto, y la alerta se cerró sola.

## El pipeline: de un Pull Request a Azure sin contraseñas

Queríamos que nadie desplegara a mano y que no hubiera ninguna clave guardada en el repositorio, que además es público. Todo pasa por GitHub Actions.

**Qué corre en cada Pull Request.** Apenas abrimos un PR, un primer workflow revisa el formato y la validez del código (`fmt` y `validate`), pasa un linter (`tflint`), un escáner de seguridad (Checkov) y los tests de la Function. Checkov nos marcó 25 puntos que decidimos aceptar, cada uno con un comentario en el código que explica por qué. Un segundo workflow corre `tofu plan` y deja el resultado como comentario en el PR, así la otra persona ve qué va a cambiar antes de aprobar.

**El deploy con aprobación.** Cuando el PR se une a `main`, arranca el deploy, pero se frena en el environment `dev` hasta que alguien lo aprueba a mano. Después crea los recursos y sube el código de la Function en el mismo workflow. El primer despliegue creó 36 recursos en unos 4 minutos. Para destruir hay otro workflow manual, y para que no se dispare sin querer hay que escribir la palabra `destruir`. Nos tropezamos con una cosa tonta: un paso del deploy tenía mal la sangría del YAML (12 espacios en vez de 6), así que el archivo no era válido. Lo encontramos al revisar el Pull Request, antes de unirlo, y por eso el primer deploy salió bien de una.

**Cómo entra a Azure sin claves.** GitHub Actions le pide a GitHub un token temporal (OIDC) y Azure lo acepta porque configuramos que confíe en nuestro repositorio, en tres casos concretos: un Pull Request, la rama `main` y el environment `dev`. No hay contraseña que robar ni que rotar: el token dura minutos. Nuestro primer intento falló porque Azure compara un texto que identifica al repositorio y el nuestro no coincidía. Lo arreglamos usando los números de identificación del dueño y del repo en vez de los nombres.

**El estado remoto.** OpenTofu guarda lo que creó en un archivo de estado, dentro de un contenedor de Storage aparte, y se accede con permisos de Azure, sin claves de acceso. Ese Storage y la identidad del pipeline se crean una sola vez con el código de `infra/bootstrap`, que corremos desde la compu y no se destruyen con el resto.

**Qué puede hacer la identidad del pipeline.** Tiene Contributor solo sobre el grupo `rg-cloudcv-dev`, no sobre toda la suscripción. Además puede asignar permisos, pero con una condición: solo dos roles (Table Data Contributor y Blob Data Contributor). Así, aunque alguien se quedara con el acceso del pipeline, no podría darse permisos de administrador. El detalle está en `docs/iam.md`.

**Lo que cuidamos por ser un repo público.** Los mails de las alertas están en un secreto de GitHub y se tapan con `***@***` en los logs. El environment `dev` solo acepta la rama `main`.

**Lo que dejamos pendiente, a propósito.** Usamos una sola identidad para el plan y para el apply. Lo ideal sería una de solo lectura para los Pull Request. Está anotado como limitación conocida.

## Cuánto cuesta

Durante las pruebas, cada vez que levantamos todo lo tuvimos menos de una hora, y el costo estimado fue de menos de USD 0,05 por prueba. Casi todo entra en lo que Azure regala por mes.

Hicimos también una proyección: con un millón de visitas por mes, el proyecto costaría entre USD 15 y 54, según la memoria de la Function. Por eso la bajamos de 2 GB a 512 MB, que para un contador alcanza de sobra. Todos los números y las medidas de ahorro están en el [informe FinOps](finops.md).

## Qué aprendimos

- **Hacerlo seguro no lo hizo más caro.** Apagar las claves de las cuentas de Storage no cuesta nada. Lo que hicimos para ahorrar también lo hizo más seguro. Por ejemplo,  la Function se apaga sola cuando nadie entra al CV, por lo que hay menos cosas encendidas que alguien pueda atacar.
- **Conviene crear y borrar todo varias veces.** Si hubiéramos creado el entorno una sola vez, no habríamos encontrado algunos problemas. Por ejemplo, Azure crea solo un recurso extra cuando se crea Application Insights, y ese recurso hacía que el borrado se trabara. Lo descubrimos recién al destruir todo y volver a crearlo.
