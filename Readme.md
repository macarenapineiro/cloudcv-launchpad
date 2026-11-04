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

### Como desplegar y destruir