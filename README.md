# Bob’s Coffee — Sistema de Información para la Gestión

**ICN292 · Universidad Técnica Federico Santa María · Campus Vitacura · Segundo semestre de 2026**

Desarrollamos este proyecto para apoyar el control de inventario y la reposición de insumos de Bob’s Coffee. En la primera entrega levantamos el problema, definimos los requerimientos y modelamos los procesos. En la segunda implementamos la base de datos en MySQL, las consultas de negocio y un flujo de alertas con n8n.

Repositorio: https://github.com/Sergi9787/ICN292-Martinez-Sergio/

## 1. Contexto y problema

Bob’s Coffee es una cafetería y restaurante ubicada en Argomedo 279, Antofagasta. A partir del levantamiento realizado con su administrador, identificamos que las revisiones de inventario se hacían principalmente de forma visual y que parte del consumo de cocina no quedaba registrada.

Esto provocaba diferencias entre las existencias disponibles y la información utilizada para comprar. Cuando un insumo faltaba durante la jornada, era necesario conseguirlo en un comercio cercano, con mayor costo y tiempo de gestión.

Nuestro objetivo fue centralizar los registros de inventario y entregar información para decidir cuándo reponer y qué pedidos requieren seguimiento. Nos enfocamos en los insumos de uso habitual, especialmente café, huevos, pollo y pan.

## 2. Primera entrega: diagnóstico y propuesta

### Levantamiento y requerimientos

En esta etapa describimos la empresa, sus actores y el problema de negocio. Analizamos sus efectos en costos, tiempo, continuidad del servicio y exactitud del inventario.

Definimos las responsabilidades de los actores del proceso:

| Actor | Responsabilidad |
|---|---|
| Administrador | Revisar inventario e indicadores y definir criterios de reposición. |
| Compras y recepción | Gestionar proveedores y pedidos, inspeccionar entregas y registrar lo recibido. |
| Cocina | Registrar consumos y mermas y participar en los conteos físicos. |
| Proveedores | Responder las solicitudes y entregar los insumos. |

Priorizamos los requerimientos mediante MoSCoW. Consideramos la gestión de insumos y proveedores, compras y recepciones, consumos, mermas, conteos, historial de movimientos, alertas, sugerencias de reposición e indicadores. También definimos requisitos de integridad, seguridad, usabilidad, respaldo y ejecución local.

### Procesos AS-IS y TO-BE

Modelamos en Bizagi el proceso actual y el propuesto. En ambos casos trabajamos con un proceso principal de control y reposición y tres subprocesos: gestión de compras, recepción de insumos y preparación en cocina.

El AS-IS muestra la dependencia de revisiones humanas, las compras por faltantes y la posibilidad de consumir insumos sin registrarlos. En el TO-BE propusimos incorporar al SIG para apoyar el registro, comparar existencias con mínimos y generar alertas.

### Arquitectura y planificación

La propuesta inicial consideraba una interfaz web con HTML, CSS y JavaScript, Flask para la lógica, SQLite para almacenar los datos y Chart.js para mostrar indicadores. También elaboramos un plan de trabajo y analizamos riesgos como la falta de datos reales, la baja adopción del registro y el aumento del alcance.

Dejamos fuera pagos, facturación, contabilidad, remuneraciones, gestión de mesas, delivery e integración automática con Fudo. Tampoco incluimos el descuento de ingredientes por cada venta mediante un recetario dinámico.

## 3. Segunda entrega: implementación

En esta etapa pasamos del diseño a una implementación que podemos ejecutar y demostrar. Mantuvimos el caso y el objetivo de la primera entrega, pero ajustamos las tecnologías y el modelo de datos.

| Aspecto | Entrega 1 | Entrega 2 |
|---|---|---|
| Base de datos | SQLite como alternativa inicial. | MySQL 8.0. |
| Modelo de datos | Diseño inicial. | Once tablas con claves, restricciones y reglas de integridad. |
| Compras | Propuesta de registro. | Órdenes con estado, marca de urgencia y líneas de detalle. |
| Recepciones | Registro de entregas. | Recepciones parciales y cantidades recibidas y aceptadas por línea. |
| Inventario | Actualización propuesta en el proceso. | Saldo calculado desde los movimientos. |
| Indicadores | Definición de información necesaria. | Ocho consultas SQL con interpretación de resultados. |
| Alertas | Tarea propuesta en el BPMN. | Flujo de n8n conectado a MySQL y Gmail. |
| Interfaz y panel | Flask y Chart.js propuestos. | Pendientes para una siguiente etapa. |

Elegimos MySQL para trabajar con restricciones, disparadores y vistas y conectarlo directamente con n8n. Concentramos la implementación en datos, consultas y alertas; no desarrollamos la interfaz web ni el panel gráfico.

## 4. Modelo de datos

Organizamos el modelo en once tablas:

| Tabla | Información almacenada |
|---|---|
| `insumo` | Nombre, categoría, unidad base y stock mínimo. |
| `proveedor` | Identificación de proveedores. |
| `usuario` | Responsables y roles. |
| `insumo_proveedor` | Insumos que ofrece cada proveedor y su plazo de entrega. |
| `orden_compra` | Proveedor, fecha, estado y condición de urgencia. |
| `detalle_orden` | Insumos solicitados, cantidades y precios. |
| `recepcion` | Fecha de llegada y orden asociada. |
| `detalle_recepcion` | Cantidades recibidas y aceptadas por línea. |
| `conteo_fisico` | Fecha y responsable del conteo. |
| `detalle_conteo` | Cantidad física y cantidad teórica previa. |
| `movimiento_inventario` | Entradas, consumos, mermas, ajustes y saldos iniciales. |

Separamos las cabeceras de sus detalles para registrar varias líneas por documento y varias recepciones por orden. El plazo de entrega quedó asociado al par insumo-proveedor, porque puede variar según el producto suministrado.

La justificación de normalización y el diccionario se desarrollan en el informe. Conservamos algunos datos de respaldo histórico, como la cantidad teórica previa a un conteo, y aplicamos controles para mantener su coherencia.

### Cálculo del inventario

El stock no se guarda como un campo que deba actualizarse por separado. Lo calculamos sumando `variacion_cantidad_base` por insumo:

- `SALDO_INICIAL`: existencia al comenzar el registro.
- `ENTRADA`: cantidad aceptada en una recepción.
- `CONSUMO`: salida destinada a la operación de cocina.
- `MERMA`: salida por pérdida, daño, vencimiento o preparación.
- `AJUSTE`: diferencia entre el conteo físico y la cantidad teórica registrada.

La vista `v_stock_actual` calcula las existencias y `v_stock_bajo` selecciona los insumos cuyo saldo es menor o igual al mínimo.

### Controles implementados

Incorporamos restricciones de cantidades, claves foráneas, unicidad y ocho disparadores. Estos comprueban que una línea recibida pertenezca a la orden correspondiente, que las entradas coincidan con lo aceptado y que los ajustes coincidan con las diferencias de conteo. También protegen datos de origen que ya respaldan movimientos.

Los movimientos se insertan explícitamente mediante SQL. Los disparadores validan esos registros, pero no crean automáticamente las entradas o los ajustes ni actualizan los estados de las órdenes.

## 5. Archivos del proyecto

Las instrucciones de ejecución utilizan las siguientes rutas:

| Ruta | Contenido |
|---|---|
| `README.md` | Descripción del proyecto y pasos de ejecución. |
| `CHANGELOG.md` | Cambios realizados entre las entregas. |
| `docs/00-caso-pyme.md` | Contexto y problema. |
| `docs/01-requerimientos.md` | Actores, alcance y requisitos. |
| `docs/02-bpmn.md` | Explicación de los procesos. |
| `docs/03-modelo-datos.md` | Modelo E/R, normalización y diccionario. |
| `docs/04-sql-consultas.md` | Consultas e interpretación. |
| `docs/05-automatizacion-n8n.md` | Configuración y prueba de la automatización. |
| `docs/DECLARACION_IA.md` | Declaración de uso de IA. |
| `sql/schema.sql` | Base, tablas, restricciones, disparadores y vistas. |
| `sql/seed.sql` | Datos sintéticos de prueba. |
| `sql/consultas.sql` | Consultas de negocio. |
| `n8n/alerta_stock_minimo.json` | Flujo de n8n exportado. |
| `diagramas/` | BPMN, modelo E/R y arquitectura. |
| `evidencias/` | Capturas de las pruebas. |
| `informe/` | Informes y sus archivos editables. |
| `presentacion/` | Diapositivas de la defensa. |
| `ENLACE_GITHUB.txt` | Repositorio y versión entregada. |

Durante el desarrollo, el esquema se trabajó con el nombre `Bobs_Coffee_BD_MySQL.sql`. En estas instrucciones corresponde a `sql/schema.sql`. La exportación final de n8n se descargó como `Bob's Coffee - Alerta diaria de stock mínimo.json` y corresponde a `n8n/alerta_stock_minimo.json`.

## 6. Requisitos de ejecución

Para ejecutar el proyecto se necesita:

- Git para clonar el repositorio.
- MySQL Server compatible con el esquema, versión 8.0.29 o superior. En las pruebas utilizamos MySQL 8.0.46.
- El cliente de consola `mysql`. Workbench puede utilizarse para cargar datos y ejecutar consultas.
- Docker Desktop, con WSL 2 en Windows, para iniciar n8n.
- Un navegador y una cuenta de correo configurada para el envío SMTP. En nuestra prueba utilizamos Gmail con contraseña de aplicación.

El servicio MySQL y Docker deben estar funcionando durante la prueba. No se necesita instalar Flask, Chart.js ni dependencias de Python para ejecutar esta versión.

## 7. Crear la base y ejecutar las consultas

### 7.1 Descargar el proyecto

```bash
git clone https://github.com/Sergi9787/ICN292-Martinez-Sergio.git
cd ICN292-Martinez-Sergio
```

### 7.2 Abrir MySQL

Desde una terminal ubicada en la carpeta del proyecto:

```bash
mysql -u root -p
```

Ingresar la contraseña de una cuenta administradora del servidor local. Si Windows no reconoce el comando, se puede utilizar la ruta completa del ejecutable. En nuestro equipo fue:

```bat
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p
```

Si MySQL aparece desconectado, abrir `services.msc` y comprobar que el servicio esté iniciado.

### 7.3 Crear el esquema

Dentro de la consola, donde aparece `mysql>`, ejecutar:

```sql
SOURCE sql/schema.sql;
```

Si el cliente se abrió desde otra carpeta, utilizar la ruta completa del archivo con barras `/`.

Al finalizar, el control del esquema debe mostrar:

| Objeto | Cantidad |
|---|---:|
| Tablas | 11 |
| Vistas | 2 |
| Disparadores | 8 |

Usamos el cliente de consola para esta carga porque Workbench presentó errores al interpretar los bloques con `DELIMITER`. Los cierres de los ocho bloques se dejaron como `END$$`.

### 7.4 Cargar los datos

Sobre la base recién creada y vacía:

```sql
SOURCE sql/seed.sql;
```

El seed usa identificadores explícitos y debe cargarse una sola vez sobre una base sin datos. Los conteos esperados son:

| Tabla | Filas |
|---|---:|
| `insumo` | 8 |
| `orden_compra` | 76 |
| `detalle_orden` | 79 |
| `recepcion` | 79 |
| `detalle_recepcion` | 82 |
| `conteo_fisico` | 6 |
| `detalle_conteo` | 48 |
| `movimiento_inventario` | 495 |

Trabajamos con datos sintéticos del 1 de octubre al 14 de noviembre de 2026. Estos permiten probar la solución sin presentarlos como registros reales de la empresa.

### 7.5 Consultar los resultados

```sql
SELECT * FROM bobs_coffee_final.v_stock_bajo;
SOURCE sql/consultas.sql;
```

La consulta a `v_stock_bajo` devuelve pechuga de pollo con **3056 g** de stock y un mínimo de **4000 g**.

Para ejecutar los archivos desde Workbench, abrirlos mediante **File → Open SQL Script**, seleccionar el código y pulsar **Run**. Esto se utilizó para el seed y las consultas.

### Consultas de negocio

| Consulta | Objetivo |
|---|---|
| C1 | Revisar existencias y priorizar insumos por su relación stock/mínimo. |
| C2 | Calcular una sugerencia de reposición según consumo, plazo y tránsito. |
| C3 | Medir compras urgentes y sobrecosto. |
| C4 | Analizar diferencias entre inventario físico y teórico. |
| C5 | Valorizar mermas por insumo y motivo. |
| C6 | Revisar cumplimiento de proveedores. |
| C7 | Reconstruir el historial de movimientos de un insumo. |
| C8 | Identificar órdenes abiertas atrasadas. |

C1 muestra todos los insumos ordenados por su relación stock/mínimo; la vista `v_stock_bajo` aplica el filtro de alerta. Las interpretaciones se desarrollan en el informe.

El archivo de consultas utiliza el corte `2026-11-14`. Para reproducir los resultados se debe usar el seed sin agregar movimientos posteriores, ya que las vistas de stock calculan el saldo de todos los movimientos cargados.

## 8. Automatización con n8n

Relacionamos el flujo con la tarea del BPMN **“Generar alerta y sugerencia de reposición”**. Su función es detectar insumos bajo mínimo y órdenes atrasadas, reunir esa información y enviar un correo cuando existen alertas.

### 8.1 Iniciar n8n

Con Docker Desktop abierto, ejecutar este comando en una sola línea desde CMD o PowerShell:

```bash
docker run -d --name n8n-bobs -p 127.0.0.1:5678:5678 -e GENERIC_TIMEZONE=America/Santiago -e TZ=America/Santiago -v n8n_bobs_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

Abrir http://localhost:5678 y crear la cuenta local si se solicita. El volumen `n8n_bobs_data` conserva los datos de n8n entre reinicios.

Si el contenedor ya existe, se inicia con:

```bash
docker start n8n-bobs
```

Para detenerlo:

```bash
docker stop n8n-bobs
```

La versión instalada se puede consultar con:

```bash
docker exec n8n-bobs n8n --version
```

### 8.2 Importar el flujo

En el editor de n8n, crear un flujo y seleccionar **Import from File** desde el menú de tres puntos. Abrir `n8n/alerta_stock_minimo.json`.

Las credenciales se configuran en cada instalación. El JSON conserva referencias a las credenciales utilizadas, pero no contiene sus contraseñas.

### 8.3 Conexión con MySQL

Crear una credencial y seleccionarla en los nodos **Stock bajo mínimo** y **OC atrasadas**:

| Campo | Valor para la instalación local utilizada |
|---|---|
| Host | `host.docker.internal` |
| Database | `bobs_coffee_final` |
| User | Usuario autorizado a consultar la base. |
| Password | Contraseña de ese usuario. |
| Port | `3306` |
| SSL y SSH | Desactivados para la prueba local. |

Usamos `host.docker.internal` porque n8n corre dentro de Docker y MySQL está instalado en Windows. El usuario debe tener autorización para conectarse desde Docker. Para las consultas de la automatización bastan permisos de lectura sobre las tablas y vistas utilizadas.

Durante la puesta en marcha creamos el usuario `sig_bobs` desde una sesión administradora. Para reproducir la prueba se puede utilizar una cuenta propia del servidor.

### 8.4 Envío mediante Gmail

Crear una credencial SMTP con una cuenta que permita generar contraseñas de aplicación:

| Campo | Valor |
|---|---|
| Host | `smtp.gmail.com` |
| Port | `465` |
| SSL/TLS | Activado. |
| User | Dirección Gmail completa. |
| Password | Contraseña de aplicación de Google, sin espacios. |

En el nodo de correo se configuran el remitente y el destinatario de la prueba. Utilizamos una cuenta personal para enviar y recibir el mensaje; el envío no se dirigió a cuentas operativas de la empresa.

El asunto y el cuerpo se toman de la salida del nodo anterior:

```text
Asunto: {{ $json.asunto }}
Texto:  {{ $json.cuerpo }}
```

El formato utilizado es **Text**. Las contraseñas se guardan en las credenciales de n8n y no se incorporan al repositorio.

### 8.5 Nodos del flujo

| Nodo | Función |
|---|---|
| Ciclo diario 07:00 (lun-sáb) | Define el horario mediante `0 7 * * 1-6`. |
| Stock bajo mínimo | Consulta los insumos críticos y sus cantidades en tránsito. |
| OC atrasadas | Busca órdenes abiertas que superan la fecha comprometida. |
| Armar mensaje | Genera el asunto, el cuerpo y el indicador `hay_alertas`. |
| ¿Hay alertas? | Decide si corresponde enviar el correo. |
| Enviar alerta a Administrador y Compras | Envía el mensaje por SMTP. |
| Sin reposición requerida | Finaliza sin envío cuando no existen alertas. |

El correo entrega una orientación para actuar. La sugerencia cuantitativa se calcula mediante C2 y no se ejecuta dentro del flujo. Tampoco se generan órdenes de compra ni pagos automáticamente.

### 8.6 Prueba realizada

Ejecutamos los nodos individualmente y después el flujo completo. Comprobamos los siguientes resultados con fecha de corte **14-11-2026**:

| Resultado | Valor |
|---|---|
| Insumo bajo mínimo | Pechuga de pollo. |
| Stock | 3056 g. |
| Stock mínimo | 4000 g. |
| Cantidad en tránsito | 16743 g. |
| Orden atrasada de pollo | OC 68, un día. |
| Orden atrasada de queso | OC 70, un día. |
| Condición de envío | `hay_alertas = true`. |
| Resultado del flujo | Ejecución completa y destinatario aceptado por el servidor SMTP. |

La existencia de pollo en tránsito permite advertir que hay un pedido pendiente que requiere seguimiento antes de emitir otra compra. Esa cantidad no garantiza por sí sola una entrega oportuna; la decisión sigue dependiendo del encargado.

Para repetir la prueba, con MySQL y Docker activos, se ejecuta el flujo desde el editor, se revisa la rama verdadera y se comprueba el envío y su recepción en Gmail. Las capturas del flujo y del correo sirven como respaldo de la ejecución.

El JSON final mantiene la fecha fija en la consulta de atrasos y en el mensaje. Conservamos el flujo inactivo para el horario programado y realizamos la demostración manualmente. La rama sin alertas y la ejecución automática diaria quedaron pendientes de validación.

## 9. Dificultades durante la implementación

Durante la puesta en marcha resolvimos problemas de conexión y configuración:

- Iniciamos el servicio MySQL cuando Workbench aparecía desconectado.
- Ejecutamos el esquema desde la consola para resolver la interpretación de los delimitadores de los disparadores.
- Creamos un usuario del proyecto aprovechando una sesión administradora abierta, sin restablecer la contraseña de root.
- Habilitamos temporalmente la configuración de creación de disparadores al recibir el error 1419.
- Instalamos WSL para iniciar Docker Desktop.
- Corregimos la consulta de fechas del nodo de órdenes atrasadas.
- Ajustamos las credenciales SMTP hasta lograr la aceptación del envío.

### Error 1419 en una nueva instalación

Si el servidor bloquea la creación de disparadores por la configuración del registro binario, una cuenta administradora puede consultar el valor actual:

```sql
SELECT @@GLOBAL.log_bin_trust_function_creators;
```

En un entorno local de prueba, habilitar temporalmente:

```sql
SET GLOBAL log_bin_trust_function_creators = 1;
```

Luego ejecutar el esquema, comprobar que se hayan creado los ocho disparadores y restaurar el valor original. Si era cero:

```sql
SET GLOBAL log_bin_trust_function_creators = 0;
```

No es necesario asignar privilegios globales SUPER al usuario de n8n.

## 10. Limitaciones y próximos pasos

La implementación demuestra el funcionamiento del modelo y de la alerta con datos sintéticos. No contamos con una medición del impacto real sobre las compras urgentes o los quiebres de stock del local.

Quedaron pendientes la interfaz web, el panel gráfico y el control de acceso por rol desde una aplicación. Aunque guardamos responsables en movimientos y conteos, las órdenes y recepciones no registran directamente al usuario que las realiza.

El estado de las órdenes se mantiene manualmente. Una orden parcial que no se cierre puede seguir contando como cantidad en tránsito, por lo que falta incorporar un cierre por faltante definitivo. La sugerencia de reposición utiliza consumo promedio y una cobertura fija, sin considerar toda la variabilidad de la demanda.

La preparación automática desde recetas y el respaldo de pagos no forman parte de las funciones implementadas. El trabajo se concentra en movimientos de inventario, compras, recepciones, conteos, consultas y alertas.

Para utilizar el flujo diariamente será necesario trabajar con datos actualizados, sustituir la fecha fija por una fecha operativa, revisar la zona horaria y habilitar el horario. El computador, MySQL y Docker deberán permanecer disponibles durante la ejecución.

## Referencias

- [Importación y exportación de flujos n8n](https://docs.n8n.io/workflows/export-import/)
- [Credenciales MySQL en n8n](https://docs.n8n.io/integrations/builtin/credentials/mysql/)
- [Credenciales Gmail para SMTP](https://docs.n8n.io/integrations/builtin/credentials/sendemail/gmail/)
- [Docker Desktop para Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
- [Disparadores en MySQL 8.0](https://dev.mysql.com/doc/refman/8.0/en/trigger-syntax.html)
- [Instalación de WSL](https://learn.microsoft.com/windows/wsl/install)
