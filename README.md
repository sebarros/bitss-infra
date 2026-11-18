# bitss-infra

Infraestructura AWS para BITSS. Los siete microservicios se mantienen en repositorios GitHub independientes y se despliegan en tres instancias EC2 de aplicaciones. Una cuarta instancia EC2 aloja MySQL.

## Distribución de instancias

| Instancia | Microservicios | Puertos |
|---|---|---|
| EC2 1 | Usuario, Catálogo y Carro | 8081, 8082, 8083 |
| EC2 2 | Gestión, Pagos y Colección | 8084, 8085, 8086 |
| EC2 3 | Notificaciones | 8087 |
| EC2 4 (BD) | MySQL 8.4 con siete bases independientes | 3306 |

El proyecto contiene siete microservicios. Por eso la distribución real es 3 + 3 + 1, no tres servicios en cada una de las tres instancias. No se agregan servicios ficticios para completar el tercer grupo.

Las cuatro instancias deben estar en la misma VPC. Usa IP privadas fijas o reservas adecuadas para que las variables de entorno no cambien al reiniciar las instancias.

## Cómo se comunican los componentes

Hay dos tipos de comunicación diferentes:

1. **Comunicación interna entre microservicios:** los servicios se llaman directamente usando las IP privadas de las instancias EC2 y los puertos de cada microservicio. Estas direcciones se configuran mediante variables de entorno.
2. **Acceso externo a la plataforma:** API Gateway recibe las solicitudes de clientes y las enruta al microservicio correspondiente. API Gateway no reemplaza las llamadas privadas entre microservicios.

Las variables de comunicación usadas por el código son:

| Servicio consumidor | Variable | Destino |
|---|---|---|
| Carro | `USUARIO_SERVICE_URL` | Usuario, EC2 1:8081 |
| Carro | `CATALOGO_SERVICE_URL` | Catálogo, EC2 1:8082 |
| Gestión | `USUARIO_SERVICE_URL` | Usuario, EC2 1:8081 |
| Gestión | `CARRO_SERVICE_URL` | Carro, EC2 1:8083 |
| Gestión | `PAGOS_SERVICE_URL` | Pagos, EC2 2:8085 |
| Gestión | `COLECCION_SERVICE_URL` | Colección, EC2 2:8086 |
| Colección | `USUARIO_SERVICE_URL` | Usuario, EC2 1:8081 |
| Notificaciones | `USUARIO_SERVICE_URL` | Usuario, EC2 1:8081 |
| Notificaciones | `GESTION_SERVICE_URL` | Gestión, EC2 2:8084 |
| Notificaciones | `CATALOGO_SERVICE_URL` | Catálogo, EC2 1:8082 |

Los archivos `config/*.env.example` ya contienen estas variables. Reemplaza los marcadores por las IP privadas reales antes de desplegar. No uses IP públicas para estas llamadas internas.

## Security Groups

Configura las reglas de entrada de esta forma:

| Security Group destino | Puerto | Origen permitido |
|---|---:|---|
| EC2 1 | 8081-8083 | SG de EC2 1, EC2 2 y EC2 3 |
| EC2 2 | 8084-8086 | SG de EC2 2 y EC2 3 |
| EC2 3 | 8087 | Solo el origen requerido por el acceso externo |
| EC2 4 (BD) | 3306 | SG de EC2 1, EC2 2 y EC2 3 |

No expongas el puerto 3306 públicamente. Las instancias de aplicaciones deben conectarse a MySQL por su IP privada.

## Preparación de la instancia de base de datos

1. Crea la instancia EC2 4 en la misma VPC.
2. Copia `mysql/init.sql` a `/opt/bitss/init.sql`.
3. Ejecuta desde el directorio `ec2`:

   ```bash
   sudo MYSQL_ROOT_PASSWORD='CLAVE_ROOT' MYSQL_APP_PASSWORD='CLAVE_APP' bash setup-db.sh
   ```

4. Comprueba que MySQL esté disponible en el puerto 3306.
5. Configura el Security Group de la BD para permitir TCP 3306 desde los Security Groups de las tres instancias de aplicaciones.

El volumen `bitss-mysql-data` conserva los datos al recrear el contenedor. Usa una contraseña de aplicación larga y evita comillas simples en `MYSQL_APP_PASSWORD`, ya que el script la incorpora a una instrucción SQL.

## Preparación de las instancias de aplicaciones

Ejecuta en cada una de las tres instancias de aplicaciones:

```bash
sudo AWS_REGION=us-east-1 bash setup-app.sh
```

Ajusta la región si corresponde. Cada instancia necesita un rol IAM con `AmazonSSMManagedInstanceCore` y `AmazonEC2ContainerRegistryReadOnly`.

Crea `/opt/bitss/<servicio>.env` para cada microservicio que se ejecutará en esa instancia, usando el archivo correspondiente de `config/` como plantilla. Completa:

- IP privada de EC2 4 en `SPRING_DATASOURCE_URL`.
- Usuario y contraseña de MySQL.
- Secreto JWT compartido por todos los microservicios.
- IP privadas de los servicios remotos en las variables `*_SERVICE_URL`.

Asigna permisos `chmod 600` a cada archivo. No subas archivos `.env` con credenciales a GitHub.

El script `setup-app.sh` instala Docker y crea `/opt/bitss/deploy-service.sh`. El despliegue espera a que el puerto de la aplicación responda antes de informar éxito.

## Repositorios GitHub y ECR

Cada carpeta `bitss-*` corresponde a un repositorio GitHub independiente:

- `bitss-usuario`
- `bitss-catalogo`
- `bitss-carro`
- `bitss-gestion`
- `bitss-pagos`
- `bitss-coleccion`
- `bitss-notificaciones`

Crea un repositorio ECR por microservicio, con el mismo nombre. En cada repositorio GitHub configura estos secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `INSTANCE_ID`
- `AWS_SESSION_TOKEN`, solamente si utilizas credenciales temporales.

Asigna `INSTANCE_ID` según la distribución inicial: EC2 1 para usuario/catálogo/carro, EC2 2 para gestión/pagos/colección y EC2 3 para notificaciones.

Cada workflow se ejecuta al hacer push a `master`, ejecuta `mvn verify`, publica la imagen propia en ECR y despliega únicamente ese contenedor mediante SSM. El rol IAM utilizado por GitHub Actions necesita permisos para autenticarse en ECR, publicar imágenes y ejecutar/consultar comandos SSM.

## API Gateway

La plantilla `cloudformation/api-gateway.yaml` crea una HTTP API y enruta las rutas de la aplicación:

| Rutas | Destino |
|---|---|
| `/usuarios` y sus subrutas | EC2 1:8081 |
| `/videojuegos` y sus subrutas | EC2 1:8082 |
| `/carrito` y sus subrutas | EC2 1:8083 |
| `/pedidos` y sus subrutas | EC2 2:8084 |
| `/pagos` y sus subrutas | EC2 2:8085 |
| `/coleccion` y sus subrutas | EC2 2:8086 |
| `/notificaciones` y sus subrutas | EC2 3:8087 |

La integración conserva la ruta solicitada al reenviarla al microservicio. El workflow de API Gateway se ejecuta desde la rama `master`, igual que los workflows de los microservicios.

Para desplegarlo, configura en el repositorio `bitss-infra` los secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `EC2_1_PUBLIC_HOST`, `EC2_2_PUBLIC_HOST` y `EC2_3_PUBLIC_HOST`. Añade `AWS_SESSION_TOKEN` solamente si utilizas credenciales temporales.

**Importante sobre seguridad:** esta plantilla utiliza integración HTTP hacia hosts públicos de EC2. Para que funcione, las instancias necesitan direcciones públicas estables y los puertos publicados deben aceptar el tráfico de API Gateway. Esta modalidad sirve como configuración inicial, pero no es la opción recomendada para producción. Para un despliegue privado, utiliza API Gateway HTTP API con VPC Link y un Network Load Balancer privado; así no necesitas exponer directamente los puertos de los microservicios a Internet.

## Comprobación de conectividad

Desde una instancia de aplicaciones, ejecuta el script con la IP privada de la BD y las URLs privadas de los servicios que esa instancia consume. Por ejemplo, desde EC2 2:

```bash
bash check-connectivity.sh 10.0.1.40 \\
  http://10.0.1.20:8081/usuarios \\
  http://10.0.1.20:8083/carrito \\
  http://10.0.1.30:8085/pagos \\
  http://10.0.1.30:8086/coleccion
```

El script comprueba el puerto TCP de MySQL y que cada URL responda por HTTP. Los estados HTTP 4xx, como 401 o 403 por falta de autenticación, indican que el servidor respondió; no demuestran que una operación de negocio autenticada haya terminado correctamente.

Después de desplegar, revisa:

```bash
docker ps
docker logs usuario
```

Sustituye `usuario` por el nombre del contenedor correspondiente. Para validar las operaciones entre servicios, realiza además solicitudes reales con un token JWT válido y datos de prueba.

## Desarrollo local

El archivo `docker-compose.yml` construye los siete servicios y MySQL usando los nombres de servicio de Docker como destinos internos. Para usarlo, clona los siete repositorios de microservicios y `bitss-infra` en carpetas hermanas, de modo que las rutas `../bitss-usuario`, `../bitss-catalogo`, etc. existan. Luego copia `.env.example` a `.env`, completa las variables y ejecuta:

```bash
docker compose up --build
```

El Compose local utiliza una única instancia MySQL con siete bases independientes. En AWS, en cambio, las bases se alojan en la instancia EC2 4.
