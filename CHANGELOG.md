# Registro de cambios — Bob’s Coffee

## Entrega 2 — Noviembre de 2026

### Continuidad del proyecto
- Se mantuvieron el caso de Bob’s Coffee, el problema de control de inventario y el objetivo de apoyar la reposición de insumos.
- Se conservó la estructura del proceso: control y reposición, gestión de compras, recepción de insumos y consumo en cocina.

### Cambios tecnológicos y de alcance
- Se reemplazó SQLite, propuesto inicialmente como motor tentativo, por MySQL 8.0.
- La implementación de esta entrega se concentró en la base de datos, las consultas de negocio y la automatización con n8n.
- La interfaz web con Flask y el panel gráfico con Chart.js quedaron como trabajo futuro.
- Los pagos y la facturación se mantuvieron fuera del alcance del SIG.

### Modelo de datos
- Se concretó el modelo de datos en once tablas, con su justificación de normalización y diccionario de datos.
- Se separaron las órdenes de compra, recepciones y conteos físicos de sus respectivas líneas de detalle.
- Se permitió registrar varias recepciones para una misma orden de compra.
- Se distinguieron las cantidades recibidas de las cantidades aceptadas.
- Se incorporó la relación entre insumos y proveedores, con un plazo de entrega por combinación.
- Se incorporaron el estado de la orden y la identificación de compras urgentes.
- Se registró la cantidad teórica previa a cada conteo físico para respaldar las diferencias y los ajustes.

### Implementación SQL
- Se implementaron claves primarias, claves foráneas y restricciones de integridad.
- Se crearon ocho disparadores para validar la correspondencia entre recepciones, conteos y movimientos de inventario, y proteger sus documentos de origen.
- Se implementaron las vistas v_stock_actual y v_stock_bajo.
- Las existencias se calcularon como la suma de los movimientos de inventario.
- Se distinguieron movimientos de saldo inicial, entrada, consumo, merma y ajuste.
- Se cargaron datos sintéticos del período comprendido entre el 1 de octubre y el 14 de noviembre de 2026.
- Se verificó la existencia de once tablas, dos vistas y ocho disparadores.
- La carga de prueba incluyó ocho insumos, 76 órdenes de compra, 79 recepciones y 495 movimientos de inventario.

### Consultas de negocio
- Se elaboraron ocho consultas para analizar:
  1. Existencias y stock mínimo.
  2. Sugerencias de reposición.
  3. Compras urgentes y sobrecostos.
  4. Diferencias entre inventario físico y teórico.
  5. Mermas valorizadas.
  6. Cumplimiento de proveedores.
  7. Historial de movimientos por insumo.
  8. Órdenes abiertas atrasadas.
- Se incorporaron resultados e interpretaciones en el informe.
- Se utilizó una fecha de corte fija para reproducir la demostración.

### Automatización con n8n
- Se implementó el flujo asociado a la tarea BPMN “Generar alerta y sugerencia de reposición”.
- Se ejecutó n8n localmente mediante Docker Desktop.
- Se conectaron los nodos MySQL con la base bobs_coffee_final.
- Se integraron las consultas de stock bajo mínimo y órdenes atrasadas en un único mensaje.
- Se consideraron las cantidades en tránsito al formular la acción sugerida.
- Se configuró una condición para enviar el correo únicamente cuando existen alertas.
- Se configuró el envío mediante Gmail y una credencial SMTP.
- Se fijó el 14 de noviembre de 2026 como fecha de corte de la demostración.
- Se verificó la ejecución manual completa del flujo y la aceptación del envío por el servidor SMTP.
- Se exportó el JSON actualizado y se obtuvo una captura de la ejecución completa.
- El flujo se mantuvo inactivo para ejecuciones programadas; la prueba realizada fue manual.

### Ajustes durante la puesta en marcha
- Se ajustó el cierre de los bloques de disparadores a la forma END$$.
- La creación del esquema se completó mediante el cliente de consola de MySQL, tras encontrar errores de ejecución en el editor de Workbench.
- Se creó un usuario del proyecto para acceder a la base sin modificar la contraseña de root.
- Se habilitó temporalmente la configuración necesaria para crear disparadores con el usuario del proyecto.
- Se corrigió la función de fecha de la consulta de órdenes atrasadas.
- Se ajustó el código que construye el asunto y el cuerpo del correo.
- Se configuraron las credenciales y direcciones reales de prueba en sustitución de los marcadores del flujo inicial.

### Limitaciones identificadas
- Los datos utilizados son sintéticos; los resultados no representan un impacto medido en la operación real del local.
- No se implementaron la interfaz web ni el control de acceso operativo por roles.
- Las órdenes de compra y recepciones no registran directamente al usuario responsable.
- El estado de las órdenes se mantiene manualmente.
- La sugerencia de reposición utiliza una regla simple de consumo promedio, plazo de entrega y cantidades en tránsito.
- La ejecución automática según horario no fue validada en esta demostración.
