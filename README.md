# BITSS — Infraestructura Cloud Native

<p align="center">
  **Backend de videojuegos basado en microservicios, desplegado en AWS mediante contenedores Docker y pipelines CI/CD automatizados.**
</p>

<p align="center">
  ![Java](https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white)
  ![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.x-6DB33F?logo=springboot&logoColor=white)
  ![Docker](https://img.shields.io/badge/Docker-Containers-2496ED?logo=docker&logoColor=white)
  ![MySQL](https://img.shields.io/badge/MySQL-8.4-4479A1?logo=mysql&logoColor=white)
  ![AWS](https://img.shields.io/badge/AWS-Cloud-232F3E?logo=amazonaws&logoColor=white)
  ![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=githubactions&logoColor=white)
</p>

<p align="center">
  ![Estado](https://img.shields.io/badge/Estado-Desplegado-0D9488)
  ![Arquitectura](https://img.shields.io/badge/Arquitectura-Microservicios-1D4ED8)
  ![Región](https://img.shields.io/badge/AWS%20Region-us--east--1-64748B)
</p>

---

## Descripción

**BITSS** es una plataforma backend orientada a la gestión de una tienda digital de videojuegos. Su arquitectura está compuesta por siete microservicios independientes que distribuyen las responsabilidades del sistema y permiten gestionar usuarios, catálogo, carritos de compra, pedidos, pagos, colecciones y notificaciones.

El proyecto utiliza una arquitectura de microservicios desarrollada con Java y Spring Boot, donde cada servicio mantiene su propia base de datos y expone endpoints REST para comunicarse con los demás componentes.

La infraestructura se despliega en **Amazon Web Services (AWS)** mediante instancias EC2, contenedores Docker, Amazon Elastic Container Registry (ECR) y Amazon API Gateway. La integración y el despliegue continuo se automatizan mediante GitHub Actions, utilizando AWS Systems Manager para ejecutar las actualizaciones remotamente.

Este repositorio centraliza los archivos de infraestructura, configuración, conectividad y documentación necesarios para preparar y mantener el entorno de BITSS. Los siete microservicios se encuentran en repositorios GitHub independientes.

## Microservicios

La solución se divide en siete servicios:

| Microservicio | Responsabilidad | Puerto | Base de datos |
|---|---|---:|---|
| Usuario | Registro, autenticación y gestión de usuarios. | 8081 | `usuario_db` |
| Catálogo | Administración y consulta de videojuegos. | 8082 | `catalogo_db` |
| Carrito | Gestión de carritos y productos seleccionados. | 8083 | `carro_db` |
| Gestión | Creación y coordinación de pedidos. | 8084 | `gestion_db` |
| Pagos | Registro y gestión de pagos asociados a pedidos. | 8085 | `pagos_db` |
| Colección | Administración de videojuegos adquiridos por usuarios. | 8086 | `coleccion_db` |
| Notificaciones | Gestión de notificaciones relacionadas con las operaciones. | 8087 | `notificaciones_db` |

Cada microservicio cuenta con su propio repositorio, `Dockerfile`, configuración Spring Boot y workflow de GitHub Actions.

## Arquitectura de infraestructura

BITSS utiliza una infraestructura distribuida en cuatro instancias EC2. Tres instancias ejecutan los microservicios y una instancia independiente aloja MySQL.

### Distribución de instancias

| Instancia | Componentes | Puertos |
|---|---|---|
| `BITSS-MS-01` | Usuario, Catálogo y Carrito | 8081–8083 |
| `BITSS-MS-02` | Gestión, Pagos y Colección | 8084–8086 |
| `BITSS-MS-03` | Notificaciones | 8087 |
| `BITSS-DB-01` | MySQL 8.4 | 3306 |

Las instancias de aplicación y base de datos se encuentran dentro de la misma VPC, permitiendo la comunicación interna mediante direcciones IP privadas.

### Punto de entrada: Amazon API Gateway

Se utiliza una única API HTTP como puerta de entrada para las solicitudes externas.

La API Gateway distribuye las solicitudes según la ruta solicitada:

| Ruta | Microservicio de destino |
|---|---|
| `/usuarios` | Usuario |
| `/videojuegos` | Catálogo |
| `/carrito` | Carrito |
| `/pedidos` | Gestión |
| `/pagos` | Pagos |
| `/coleccion` | Colección |
| `/notificaciones` | Notificaciones |

**URL de API Gateway:**

`https://dl1q2dpaf1.execute-api.us-east-1.amazonaws.com`

Las comunicaciones internas entre microservicios utilizan las direcciones privadas de las instancias EC2, evitando utilizar API Gateway para las llamadas entre servicios.

### Conectividad y seguridad

La infraestructura utiliza dos grupos de seguridad:

| Grupo de seguridad | Aplicación | Regla principal |
|---|---|---|
| `SG-BITSS-APP` | Instancias de microservicios | TCP 8081–8087 |
| `SG-BITSS-DB` | Instancia MySQL | TCP 3306 desde `SG-BITSS-APP` |

La base de datos no requiere exposición directa a Internet. Las credenciales de conexión se entregan mediante variables de entorno y archivos de configuración protegidos.

## Comunicación entre microservicios

Los servicios se comunican mediante solicitudes HTTP REST. Las direcciones de destino se configuran mediante variables de entorno, lo que permite modificar la ubicación de los servicios sin cambiar el código fuente.

| Servicio consumidor | Servicio consultado | Variable |
|---|---|---|
| Carrito | Usuario | `USUARIO_SERVICE_URL` |
| Carrito | Catálogo | `CATALOGO_SERVICE_URL` |
| Gestión | Usuario | `USUARIO_SERVICE_URL` |
| Gestión | Carrito | `CARRO_SERVICE_URL` |
| Gestión | Pagos | `PAGOS_SERVICE_URL` |
| Gestión | Colección | `COLECCION_SERVICE_URL` |
| Colección | Usuario | `USUARIO_SERVICE_URL` |
| Notificaciones | Usuario | `USUARIO_SERVICE_URL` |
| Notificaciones | Gestión | `GESTION_SERVICE_URL` |
| Notificaciones | Catálogo | `CATALOGO_SERVICE_URL` |

Las direcciones de estas variables deben corresponder a las IP privadas y puertos de las instancias EC2.

## Base de datos y persistencia

La infraestructura utiliza **MySQL 8.4** como motor de base de datos.

Se dispone de una instancia EC2 independiente que ejecuta un contenedor MySQL y mantiene siete bases de datos, una por microservicio:

- `usuario_db`
- `catalogo_db`
- `carro_db`
- `gestion_db`
- `pagos_db`
- `coleccion_db`
- `notificaciones_db`

La persistencia se implementa mediante un volumen Docker:

`bitss-mysql-data`

Esto permite conservar los datos aunque el contenedor MySQL sea detenido o recreado.

Las aplicaciones utilizan un usuario específico de MySQL (`bitss_app`) para conectarse a sus respectivas bases de datos.

## Contenedorización

Cada microservicio dispone de su propio `Dockerfile`, que permite construir una imagen independiente de la aplicación.

Las imágenes se publican en repositorios privados de Amazon ECR:

- `bitss-usuario`
- `bitss-catalogo`
- `bitss-carro`
- `bitss-gestion`
- `bitss-pagos`
- `bitss-coleccion`
- `bitss-notificaciones`

Para el entorno local se dispone de `docker-compose.yml`, que permite levantar los siete microservicios y MySQL de manera conjunta.

```bash
docker compose up --build
```

En el entorno AWS, los contenedores de aplicación se actualizan mediante scripts de despliegue remoto ejecutados por AWS Systems Manager. Actualmente, el script `deploy-service.sh` utiliza `docker run` para crear y reiniciar los contenedores.

## Integración y despliegue continuo (CI/CD)

BITSS utiliza **GitHub Actions** para automatizar la integración, construcción y despliegue de los microservicios.

Cada repositorio independiente cuenta con un workflow ubicado en:

```text
.github/workflows/ci-cd.yml
```

### Etapas del pipeline

1. **Integración:** GitHub Actions detecta cambios mediante eventos `push` y `pull_request` hacia `master`.
2. **Pruebas:** se configura Java 21 y se ejecuta `mvn verify`.
3. **Construcción:** se genera la imagen Docker del microservicio.
4. **Publicación:** la imagen se etiqueta y publica en el repositorio ECR correspondiente.
5. **Despliegue:** AWS Systems Manager ejecuta remotamente el script de actualización en la instancia EC2 asignada.
6. **Verificación:** el script comprueba que el contenedor esté activo y que el puerto de la aplicación responda.

Los workflows utilizan AWS Academy mediante credenciales temporales configuradas como GitHub Secrets.

### Distribución de despliegues

| Repositorios | Instancia EC2 |
|---|---|
| `bitss-usuario`, `bitss-catalogo`, `bitss-carro` | `BITSS-MS-01` |
| `bitss-gestion`, `bitss-pagos`, `bitss-coleccion` | `BITSS-MS-02` |
| `bitss-notificaciones` | `BITSS-MS-03` |

## Variables de entorno y configuración

Los microservicios utilizan variables de entorno para configurar las conexiones a bases de datos, autenticación y comunicación entre servicios.

Cada instancia de aplicaciones mantiene los archivos de configuración correspondientes en:

```text
/opt/bitss/
```

Ejemplo de configuración:

```properties
SPRING_DATASOURCE_URL=jdbc:mysql://<DB_PRIVATE_IP>:3306/usuario_db
SPRING_DATASOURCE_USERNAME=bitss_app
SPRING_DATASOURCE_PASSWORD=<MYSQL_APP_PASSWORD>
BITSS_JWT_SECRET=<BITSS_JWT_SECRET>
```

Las plantillas de configuración se encuentran en:

```text
config/
├── usuario.env.example
├── catalogo.env.example
├── carro.env.example
├── gestion.env.example
├── pagos.env.example
├── coleccion.env.example
└── notificaciones.env.example
```

Los valores reales deben configurarse directamente en las instancias y nunca deben subirse al repositorio.

### GitHub Secrets

Cada repositorio de microservicio requiere los siguientes secretos:

| Secret | Descripción |
|---|---|
| `AWS_ACCESS_KEY_ID` | Identificador de la credencial temporal de AWS. |
| `AWS_SECRET_ACCESS_KEY` | Clave secreta de AWS. |
| `AWS_SESSION_TOKEN` | Token de sesión temporal de AWS Academy. |
| `AWS_REGION` | Región de despliegue: `us-east-1`. |
| `INSTANCE_ID` | Identificador de la instancia EC2 correspondiente. |

Las credenciales temporales deben actualizarse cuando expire la sesión de AWS Academy.

### Componentes principales

| Archivo o carpeta | Responsabilidad |
|---|---|
| `cloudformation/` | Plantillas para definir recursos de AWS. |
| `.github/workflows/` | Automatización relacionada con la infraestructura. |
| `config/` | Plantillas de variables de entorno para cada microservicio. |
| `ec2/setup-app.sh` | Preparación de las instancias de aplicaciones. |
| `ec2/setup-db.sh` | Instalación y configuración del contenedor MySQL. |
| `ec2/check-connectivity.sh` | Comprobación de conectividad entre servicios y base de datos. |
| `mysql/init.sql` | Inicialización de las bases de datos y estructura de usuarios. |
| `docker-compose.yml` | Ejecución local conjunta de los microservicios y MySQL. |
| `.env.example` | Plantilla de variables para el entorno local. |

## Tecnologías y servicios

| Tecnología / servicio | Uso en el proyecto |
|---|---|
| Java 21 | Lenguaje de desarrollo de los microservicios. |
| Spring Boot | Desarrollo de servicios backend REST. |
| Spring Data JPA | Persistencia y acceso a datos. |
| MySQL 8.4 | Motor de base de datos relacional. |
| Maven | Gestión de dependencias y construcción. |
| Docker | Contenedorización de aplicaciones y base de datos. |
| Docker Compose | Orquestación del entorno local. |
| Amazon EC2 | Ejecución de los microservicios y MySQL. |
| Amazon ECR | Almacenamiento de imágenes Docker. |
| Amazon API Gateway | Punto de entrada para las solicitudes externas. |
| AWS Systems Manager | Ejecución remota de comandos en EC2. |
| AWS CloudFormation | Definición de infraestructura mediante plantillas. |
| GitHub Actions | Integración y despliegue continuo. |
| GitHub Secrets | Almacenamiento de credenciales utilizadas por los workflows. |

## Requisitos y ejecución local

Para ejecutar el entorno local se necesita:

- Java 21.
- Maven.
- Docker.
- Docker Compose.
- Git.

### Preparación

1. Clonar los siete repositorios de microservicios.
2. Clonar este repositorio de infraestructura.
3. Mantener las carpetas `bitss-*` y `bitss-infra` como directorios hermanos.
4. Copiar `.env.example` a `.env`.
5. Configurar las contraseñas y el secreto JWT.

Estructura esperada:

```text
BITSS/
├── bitss-usuario/
├── bitss-catalogo/
├── bitss-carro/
├── bitss-gestion/
├── bitss-pagos/
├── bitss-coleccion/
├── bitss-notificaciones/
└── bitss-infra/
```

### Levantar el entorno

Desde la carpeta `bitss-infra`, ejecutar:

```bash
docker compose up --build
```

Para revisar los contenedores:

```bash
docker compose ps
```

Para detener los servicios:

```bash
docker compose down
```

Para detener los servicios sin eliminar los datos persistidos de MySQL:

```bash
docker compose down
```

El volumen de MySQL se conserva mientras no se elimine explícitamente.

## Despliegue en AWS

La preparación de infraestructura se realiza en AWS Academy, utilizando la región `us-east-1`.

El procedimiento general considera:

1. Crear y configurar las cuatro instancias EC2.
2. Asociar los grupos de seguridad correspondientes.
3. Preparar la instancia de base de datos y ejecutar `setup-db.sh`.
4. Preparar las tres instancias de aplicaciones mediante `setup-app.sh`.
5. Crear los archivos `.env` de cada microservicio en `/opt/bitss/`.
6. Crear los repositorios ECR correspondientes.
7. Asociar los roles y permisos necesarios para ECR y Systems Manager.
8. Configurar los GitHub Secrets de cada repositorio.
9. Ejecutar los workflows para publicar y desplegar las imágenes.
10. Configurar y comprobar las rutas de API Gateway.

Los procedimientos detallados y comandos de preparación se encuentran en los scripts de `ec2/` y en sus respectivas instrucciones de configuración.

## Consideraciones y limitaciones

- **Repositorios independientes:** cada microservicio mantiene su propio código, configuración y workflow.
- **Credenciales temporales:** AWS Academy utiliza credenciales con vencimiento, por lo que deben renovarse en GitHub Secrets.
- **Bases de datos independientes:** cada microservicio utiliza su propio esquema MySQL.
- **Comunicación interna:** las llamadas entre servicios se realizan mediante IP privadas y puertos definidos.
- **Persistencia:** los datos de MySQL se mantienen en un volumen Docker.
- **Disponibilidad:** la ejecución depende del estado de las instancias EC2 y de los contenedores.
- **Docker Compose:** actualmente se utiliza para el entorno local; el despliegue remoto de aplicaciones utiliza Docker y AWS Systems Manager.
- **Seguridad:** las contraseñas y claves JWT no deben almacenarse en el repositorio. Para producción se recomienda utilizar AWS Secrets Manager o Systems Manager Parameter Store.
- **Escalabilidad:** la distribución actual utiliza instancias EC2 dedicadas; una evolución futura puede incorporar balanceadores, integración privada y mecanismos de escalado.

## Estado del proyecto

BITSS cuenta con una infraestructura desplegada en AWS, siete microservicios contenedorizados y pipelines CI/CD independientes.

Se han realizado comprobaciones de conectividad mediante API Gateway, autenticación JWT y operaciones entre microservicios, incluyendo la creación de videojuegos y su incorporación a carritos de usuarios.

La arquitectura permite mantener los servicios independientes y automatizar su actualización desde GitHub hacia AWS.

---

<p align="center">
  **BITSS — Backend de tienda digital de videojuegos**
  
  Arquitectura de microservicios · Contenedores Docker · AWS · CI/CD
</p>
