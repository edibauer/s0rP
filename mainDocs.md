### CDL'S

| CDL | Descripción | Stage Table | Table |Esquema | 
| --- | ----------- | ----- | --- | --- |
| OGPT | Contiene la información personal de cada ente comisionale | CS_STAGEPARTICIPANT | CS_PARTICIPANT | TCMP|
| OGPO | Contiene la información de la estrucutura jerarquica a la que pertenence el ente comisionable | CS_STAGEPOSITION | CS_POSITION | TCMP |
| TXSTA | Contiene la información de ventas, transferencias, producción de cada una de la sucursales | CS_STAGESALESTRANSACTION | CS_SALESTRANSACTION | TCMP |
| TXTA | Contiene la información de ventas, transferencias, producción de cada una de la sucursales | CS_STAGESALESTRANSACTION | CS_SALESTRANSACTION | TCMP |
| ASTNC | Contiene la información de la fecha en la que asistió el emepleado de acuerdo a la sucursal en la que esta laborando  | TB_ASISTENCIA_ITX_TMP | TB_ASISTENCIA_ITX_HIS | EXT |
| VCINC | Contiene la información del rango de fechas en las que el empleado está de vacaciones o de incapacidad de acuerdo a la sucursal en la que está laborando | TB_VACACINCAP_ITX_TMP | TB_VACACINCAP_ITX_HIS | EXT |
| PRCPA | Contiene la relación de porcentajes de participación de acuerdo a las mesas de las sucursales y los puestos en ellas | TB_PORCPARTICIPACION_TMP | TB_PORCPARTICIPACION_WKF | EXT |
| SUCME | Contiene la relación de mesas, empleados y sucursales | TB_SUCMESAEMPL_TMP | TB_SUCMESAEMPL_WKF | EXT |
| PRDFC | Contiene la relación de los porductos que hay en cada mesa por sucursal junto con su factor | TB_PRODUCTOFACT_TMP | TB_PRODUCTOFACT_HIS | EXT |
| PRDPR | Contiene la información del precio de cada uno de los productos | TB_PRODUCTOPRECIO_TMP | TB_PRODUCTOPRECIO_HIS | EXT |
| CLPR | Contiene la información de todo el universo de productos | | CS_CLASSIFIER | TCMP |
| SUCACT | Contiene la información de las suscursales que se encuentran acitvas en ambiente Productivo para que sean inlcuídas en el archivo de pago | TB_SUCACT_PRD_TMP | TB_SUCACT_PRD | EXT |
| SUCRL | Contiene la información de todo el universo de sucursales | TB_SUCURSAL_TMP | TB_SUCURSAL_WKF | EXT |
| PRDCON | Contiene la relación de sucursales, mesas y productos que se considran congelados para las tiendas de City Club  | TB_PRODUCTOS_CONGE_TMP | TB_PRODUCTOS_CONGE_CITY | EXT |

### BALANCEOS
De acuerdo a los distintos escenarios en los cuales se tiene que repartir el porcentaje de participación (cargo duplicado, vacantes, inasistencias, apoyo adicional, complemento), el proceso de ejcución es el siguiente:

#### Reseteo de Porcentaje de Participación
Actualiza el campo PORCENTAJE_PARTICIPACION_EMPLEADO en la tabla TB_ASISTENCIA_WKF. El valor de este campo se obtiene del campo PORCENTAJE_PART_CARGO de la tabla TB_PORCPARTICIPACION_WKF. La actualización se realiza basándose en condiciones específicas que relacionan ambas tablas mediante claves comunes (ID_SUCURSAL, ID_MESA_REAL, ID_CVE_CARGO_REAL) y filtros adicionales como la fecha de asistencia, el ID de sucursal y el ID de mesa.

- PSEUDOCODIGO:
```
INICIO
    PARA CADA REGISTRO EN EXT.TB_ASISTENCIA_WKF
        SI EXT.TB_ASISTENCIA_WKF.FECHA_ASISTENCIA == :k
           Y EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL == :i
           Y EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL == :j
        ENTONCES
            BUSCAR REGISTRO EN EXT.TB_PORCPARTICIPACION_WKF
                DONDE EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL == EXT.TB_PORCPARTICIPACION_WKF.ID_SUCURSAL
                  Y EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL == EXT.TB_PORCPARTICIPACION_WKF.ID_MESA
                  Y EXT.TB_ASISTENCIA_WKF.ID_CVE_CARGO_REAL == EXT.TB_PORCPARTICIPACION_WKF.ID_CVE_CARGO
            
            SI SE ENCUENTRA UN REGISTRO CORRESPONDIENTE EN EXT.TB_PORCPARTICIPACION_WKF
            ENTONCES
                ACTUALIZAR EXT.TB_ASISTENCIA_WKF.PORCENTAJE_PARTICIPACION_EMPLEADO
                    CON EL VALOR DE EXT.TB_PORCPARTICIPACION_WKF.PORCENTAJE_PART_CARGO
            FIN SI
        FIN SI
    FIN PARA
FIN
```

#### Inasistencias
Realiza cálculos y actualizaciones en la tabla EXT.TB_ASISTENCIA_WKF. Este procedimiento ajusta el campo PORCENTAJE_PARTICIPACION_EMPLEADO para empleados que cumplen ciertas condiciones relacionadas con su asistencia. El propósito principal del procedimiento es redistribuir el porcentaje de participación entre empleados que están marcados como "asistentes" (ASISTENCIA_ITX = TRUE) basándose en los valores de participación de empleados que no asistieron (ASISTENCIA_ITX = FALSE). Además, incluye validaciones específicas para asegurarse de que solo se procesen datos de sucursales que no pertenezcan a "PAGINA CityClub".

- PSEUDOCODIGO:
```
INICIO
    -- VALIDACIÓN DE SUCURSAL
    CONTAR EL NÚMERO DE REGISTROS EN EXT.TB_SUCURSAL_WKF
        DONDE PAG_ORIGEN = 'PAGINA CityClub'
          Y ID_SUCURSAL = :i
    GUARDAR EL RESULTADO EN lv_VAL_CITY

    SI lv_VAL_CITY = 0
    ENTONCES
        -- CÁLCULO DEL NÚMERO MÁXIMO DE EMPLEADOS
        CONTAR EL NÚMERO DE REGISTROS EN EXT.TB_ASISTENCIA_WKF
            DONDE ASISTENCIA_ITX = FALSE
              Y ID_SUCURSAL = :i
              Y ID_MESA_REAL = :j
              Y ESTATUS_TRANS IN ('0', '2', '4')
              Y PORCENTAJE_PARTICIPACION_EMPLEADO != 0
              Y ID_EMPLEADO NOT LIKE '%C%'
              Y (DECORADO IS NULL OR DECORADO = FALSE)
              Y FECHA_ASISTENCIA = :k
            O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO IS NULL OR DECORADO = FALSE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :k AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
        GUARDAR EL RESULTADO EN lv_CONT_MAX

        SI lv_CONT_MAX != 0
        ENTONCES
            -- CÁLCULO DEL NÚMERO DE EMPLEADOS QUE ASISTIERON
            LLAMAR A LA FUNCIÓN F_NUMERO_EMPLEADOS_TRUE_EV(i, j, k)
            GUARDAR EL RESULTADO EN lv_NUM_EMPL_TRUE

            -- CÁLCULO DEL PORCENTAJE PROMEDIO DE EMPLEADOS QUE NO ASISTIERON
            CALCULAR SUM(PORCENTAJE_PARTICIPACION_EMPLEADO) / lv_NUM_EMPL_TRUE
                DONDE ID_SUCURSAL = :i
                  Y ID_MESA_REAL = :j
                  Y FECHA_ASISTENCIA = :k
                  Y ESTATUS_TRANS IN ('0', '2', '4')
                  Y ASISTENCIA_ITX = FALSE
                  Y (DECORADO IS NULL OR DECORADO = FALSE)
                  Y ID_EMPLEADO NOT LIKE '%C%'
                  Y PORCENTAJE_PARTICIPACION_EMPLEADO != 0
                O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO IS NULL OR DECORADO = FALSE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :k AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
            GUARDAR EL RESULTADO EN lv_PORC_PART_FALSE

            -- ACTUALIZACIÓN DE PORCENTAJES PARA EMPLEADOS QUE ASISTIERON
            ACTUALIZAR EXT.TB_ASISTENCIA_WKF
            SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO + lv_PORC_PART_FALSE, 10, 5)
            DONDE ID_SUCURSAL = :i
              Y ID_MESA_REAL = :j
              Y ASISTENCIA_ITX = TRUE
              Y ESTATUS_TRANS IN ('0', '2', '4')
              Y (DECORADO IS NULL OR DECORADO = FALSE)
              Y FECHA_ASISTENCIA = :k
            O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :k AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
        FIN SI
    FIN SI
FIN
```
- Colocar funciones

#### Vacantes
Ajusta el campo PORCENTAJE_PARTICIPACION_EMPLEADO en la tabla EXT.TB_ASISTENCIA_WKF. Este procedimiento se utiliza para redistribuir el porcentaje de participación entre empleados que están marcados como "asistentes" (ASISTENCIA_ITX = TRUE) cuando existen puestos vacantes (cargos sin asignación) en una sucursal y mesa específica.

El propósito principal del procedimiento es:

- Identificar puestos vacantes (cargos sin asignación) en una sucursal y mesa específica.
- Calcular el porcentaje de participación no asignado debido a estos puestos vacantes.
- Redistribuir este porcentaje entre los empleados que asistieron (ASISTENCIA_ITX = TRUE).

- PSEUDOCÓDIGO:
```
INICIO
    -- VALIDACIÓN DE SUCURSAL
    CONTAR EL NÚMERO DE REGISTROS EN EXT.TB_SUCURSAL_WKF
        DONDE PAG_ORIGEN = 'PAGINA CityClub'
          Y ID_SUCURSAL = :i
    GUARDAR EL RESULTADO EN lv_VAL_CITY

    SI lv_VAL_CITY = 0
    ENTONCES
        -- IDENTIFICACIÓN DE PUESTOS VACANTES
        SELECCIONAR CARGOS SIN ASIGNACIÓN
            (CARGOS EN EXT.TB_PORCPARTICIPACION_WKF QUE NO ESTÁN EN EXT.TB_ASISTENCIA_WKF)
        GUARDAR EL NÚMERO DE PUESTOS VACANTES EN lv_PUESTO

        SI lv_PUESTO != 0
        ENTONCES
            -- CÁLCULO DEL NÚMERO DE EMPLEADOS QUE ASISTIERON
            LLAMAR A LA FUNCIÓN F_NUMERO_EMPLEADOS_TRUE_EV(i, j, k)
            GUARDAR EL RESULTADO EN lv_NUM_EMPL_TRUE

            -- CÁLCULO DEL PORCENTAJE NO ASIGNADO
            CALCULAR 100 - SUM(PORCENTAJE_PARTICIPACION_EMPLEADO)
                DONDE ID_SUCURSAL = :i
                  Y ID_MESA_REAL = :j
                  Y ESTATUS_TRANS IN ('0', '2', '4')
                  Y (DECORADO IS NULL OR DECORADO = FALSE)
                  Y FECHA_ASISTENCIA = :k
                  Y ASISTENCIA_ITX = TRUE
                O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :k AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
            GUARDAR EL RESULTADO EN lv_PORC_PART_FALSE

            -- REDISTRIBUCIÓN DEL PORCENTAJE ENTRE EMPLEADOS ASISTENTES
            ACTUALIZAR EXT.TB_ASISTENCIA_WKF
            SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO + (lv_PORC_PART_FALSE / lv_NUM_EMPL_TRUE), 10, 5)
            DONDE ID_SUCURSAL = :i
              Y ID_MESA_REAL = :j
              Y ASISTENCIA_ITX = TRUE
              Y ESTATUS_TRANS IN ('0', '2', '4')
              Y (DECORADO IS NULL OR DECORADO = FALSE)
              Y FECHA_ASISTENCIA = :k
            O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :k AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
        FIN SI
    FIN SI
FIN
```

#### Apoyo Adicional
Se utiliza para manejar casos específicos relacionados con puestos duplicados (empleados asignados al mismo cargo) en una sucursal y mesa específica. Dependiendo de la cantidad de puestos duplicados identificados, el procedimiento realiza diferentes acciones:

- Si hay un puesto duplicado , redistribuye el porcentaje de participación entre los empleados que asistieron.
- Si hay dos puestos duplicados , actualiza los porcentajes de participación utilizando los valores definidos en la tabla EXT.TB_PORCPARTICIPACION_WKF.

- PSEUDOCODIGO:
```
INICIO
    -- VALIDACIÓN DE SUCURSAL
    CONTAR EL NÚMERO DE REGISTROS EN EXT.TB_SUCURSAL_WKF
        DONDE PAG_ORIGEN = 'PAGINA CityClub'
          Y ID_SUCURSAL = :i
    GUARDAR EL RESULTADO EN lv_VAL_CITY

    SI lv_VAL_CITY = 0
    ENTONCES
        -- IDENTIFICACIÓN DE PUESTOS DUPLICADOS
        CONTAR EL NÚMERO DE CARGOS DUPLICADOS
            (AGRUPAR POR ID_CVE_CARGO_REAL Y FILTRAR COUNT(*) > 1)
        GUARDAR EL RESULTADO EN lv_PUESTOS_DUP

        SI lv_PUESTOS_DUP = 1
        ENTONCES
            -- IDENTIFICAR EL PUESTO DUPLICADO
            SELECCIONAR ID_CVE_CARGO_REAL
            GUARDAR EL RESULTADO EN lv_PUESTO

            -- OBTENER EL PORCENTAJE DEL PUESTO DUPLICADO
            SELECCIONAR PORCENTAJE_PARTICIPACION_EMPLEADO
            GUARDAR EL RESULTADO EN lv_PORC_PUESTO_DUP

            -- CALCULAR EL NÚMERO DE EMPLEADOS QUE ASISTIERON
            LLAMAR A LA FUNCIÓN F_NUMERO_EMPLEADOS_TRUE_ADIC_EV(i, j, lv_FECHA)
            GUARDAR EL RESULTADO EN lv_NUM_EMPL_TRUE

            -- CALCULAR EL VALOR A RESTAR
            CALCULAR lv_PORC_PUESTO_DUP / lv_NUM_EMPL_TRUE
            GUARDAR EL RESULTADO EN lv_APORTE

            -- ACTUALIZAR EL PORCENTAJE DE PARTICIPACIÓN
            ACTUALIZAR EXT.TB_ASISTENCIA_WKF
            SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO - lv_APORTE, 10, 5)
            DONDE ID_SUCURSAL = :i
              Y ID_MESA_REAL = :j
              Y ASISTENCIA_ITX = TRUE
              Y (DECORADO IS NULL OR DECORADO = FALSE)
              Y FECHA_ASISTENCIA = :lv_FECHA
              O (ESTATUS_TRANS IN ('1','3') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :lv_FECHA AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)

        ELSEIF lv_PUESTOS_DUP = 2
        ENTONCES
            -- ACTUALIZAR PORCENTAJES UTILIZANDO EXT.TB_PORCPARTICIPACION_WKF
            ACTUALIZAR EXT.TB_ASISTENCIA_WKF
            SET PORCENTAJE_PARTICIPACION_EMPLEADO = EXT.TB_PORCPARTICIPACION_WKF.PORCENTAJE_PART_CARGO
            DESDE EXT.TB_ASISTENCIA_WKF, EXT.TB_PORCPARTICIPACION_WKF
            DONDE EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = EXT.TB_PORCPARTICIPACION_WKF.ID_SUCURSAL
              Y EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL = EXT.TB_PORCPARTICIPACION_WKF.ID_MESA
              Y EXT.TB_ASISTENCIA_WKF.ID_CVE_CARGO_REAL = EXT.TB_PORCPARTICIPACION_WKF.ID_CVE_CARGO
              Y EXT.TB_ASISTENCIA_WKF.FECHA_ASISTENCIA = :lv_FECHA
              Y EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = :i
              Y EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL = :j
        FIN SI
    FIN SI
FIN
```

#### Complemento
Se utiliza para corregir y redistribuir los porcentajes de participación de empleados en una sucursal y mesa específica, asegurando que la suma total de los porcentajes sea exactamente 100. Además, establece en cero el porcentaje de participación de empleados que no asistieron.

El propósito principal del procedimiento es:

- Verificar si la suma de los porcentajes de participación de los empleados que asistieron (ASISTENCIA_ITX = TRUE) es menor o mayor a 100.
- Si la suma es menor a 100, distribuir el porcentaje faltante entre los empleados que asistieron.
- Si la suma es mayor a 100, restar el exceso de los porcentajes de los empleados que asistieron.
- Establecer en cero el porcentaje de participación de empleados que no asistieron (ASISTENCIA_ITX = FALSE).

-PSEUDOCODIGO:
```
INICIO
    -- VALIDACIÓN DE SUCURSAL
    CONTAR EL NÚMERO DE REGISTROS EN EXT.TB_SUCURSAL_WKF
        DONDE PAG_ORIGEN = 'PAGINA CityClub'
          Y ID_SUCURSAL = :i
    GUARDAR EL RESULTADO EN lv_VAL_CITY

    SI lv_VAL_CITY = 0
    ENTONCES
        -- CALCULAR LA SUMA DE PORCENTAJES DE EMPLEADOS QUE ASISTIERON
        SELECCIONAR SUM(PORCENTAJE_PARTICIPACION_EMPLEADO)
        GUARDAR EL RESULTADO EN lv_SUMA_ASTNC

        SI lv_SUMA_ASTNC < 100
        ENTONCES
            -- CALCULAR EL PORCENTAJE FALTANTE
            CALCULAR 100 - lv_SUMA_ASTNC
            GUARDAR EL RESULTADO EN lv_SUMA_PORC

            -- OBTENER EL NÚMERO DE EMPLEADOS QUE ASISTIERON
            LLAMAR A LA FUNCIÓN F_NUMERO_EMPLEADOS_TRUE_EV(i, j, lv_FECHA)
            GUARDAR EL RESULTADO EN lv_NUM_EMPL_TRUE

            -- DISTRIBUIR EL PORCENTAJE FALTANTE ENTRE LOS EMPLEADOS
            ACTUALIZAR EXT.TB_ASISTENCIA_WKF
            SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO + (lv_SUMA_PORC / lv_NUM_EMPL_TRUE), 10, 5)
            DONDE ID_SUCURSAL = :i
              Y ID_MESA_REAL = :j
              Y ESTATUS_TRANS IN ('0', '2', '4')
              Y (DECORADO IS NULL OR DECORADO = FALSE)
              Y FECHA_ASISTENCIA = :lv_FECHA
              Y ASISTENCIA_ITX = TRUE
              O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :lv_FECHA AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)

        ELSEIF lv_SUMA_ASTNC > 100
        ENTONCES
            -- CALCULAR EL EXCESO DE PORCENTAJE
            CALCULAR lv_SUMA_ASTNC - 100
            GUARDAR EL RESULTADO EN lv_SUMA_PORC

            -- OBTENER EL NÚMERO DE EMPLEADOS QUE ASISTIERON
            LLAMAR A LA FUNCIÓN F_NUMERO_EMPLEADOS_TRUE_EV(i, j, lv_FECHA)
            GUARDAR EL RESULTADO EN lv_NUM_EMPL_TRUE

            -- RESTAR EL EXCESO DE PORCENTAJE ENTRE LOS EMPLEADOS
            ACTUALIZAR EXT.TB_ASISTENCIA_WKF
            SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO - (lv_SUMA_PORC / lv_NUM_EMPL_TRUE), 10, 5)
            DONDE ID_SUCURSAL = :i
              Y ID_MESA_REAL = :j
              Y ESTATUS_TRANS IN ('0', '2', '4')
              Y (DECORADO IS NULL OR DECORADO = FALSE)
              Y FECHA_ASISTENCIA = :lv_FECHA
              Y ASISTENCIA_ITX = TRUE
              O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :lv_FECHA AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
        FIN SI
    FIN SI

    -- ESTABLECER PORCENTAJES EN CERO PARA EMPLEADOS AUSENTES
    ACTUALIZAR EXT.TB_ASISTENCIA_WKF
    SET PORCENTAJE_PARTICIPACION_EMPLEADO = 0
    DONDE ID_SUCURSAL = :i
      Y ID_MESA_REAL = :j
      Y ASISTENCIA_ITX = FALSE
      Y ESTATUS_TRANS IN ('0', '1', '2', '3', '4')
      Y (DECORADO IS NULL OR DECORADO = FALSE)
      Y FECHA_ASISTENCIA = :lv_FECHA
      O (ESTATUS_TRANS IN ('1', '3') AND (DECORADO IS NULL OR DECORADO = FALSE) AND ASISTENCIA_ITX = FALSE AND FECHA_ASISTENCIA = :lv_FECHA AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
      O (ESTATUS_TRANS IN ('2', '4') AND (DECORADO = TRUE) AND ASISTENCIA_ITX = TRUE AND FECHA_ASISTENCIA = :lv_FECHA AND ID_MESA_REAL = :j AND ID_SUCURSAL = :i)
FIN
```

### Parámetros de entrada
Los parámetros de entrada a los SP de balanceo de asistencia son:
| Nombre | Tipo | Descripción |
| --- | --- | --- |
| i | NUMBER | ID_SUCURSAL |
| j | NUMBER | ID_MESA_REAL |
| lv_FECHA | DATE | FECHA_ASISTENCIA |

La lógica es exactamente la misma y se pueden crear procedimientos almacenados de acuerdo a los requerimientos, es decir, ejecutar por sucursal, mesa y fecha, rango defechas en especifico, etc.

El orden de ejecución es el presentado en la explicación de cada uno de los SP:
- Reseteo de Porcentaje de Participación
- Inasistencias
- Vacantes
- Apoyo Adicional
- Complemento

### StageHook
Se encarga de gestionar la asignación de transacciones de ventas, producción, transferencias y mermas en un sistema de compensación. El procedimiento realiza una serie de operaciones basadas en la fecha de compensación y el identificador de la ejecución del pipeline (pipelineRunSeq). Dependiendo de si la fecha de compensación está dentro de un período de evento o no, el procedimiento realiza diferentes operaciones de actualización, inserción y eliminación de datos en varias tablas.

- Parámetros de entrada:
    - **pipelineRunSeq (IN):** Un valor de tipo BIGINT que representa el identificador de la ejecución del pipeline.

- Variables declaradas:
    - **lv_period_seq**: Almacena el identificador del período asociado a la ejecución del pipeline.

    - **lv_start_date**: Almacena la fecha de inicio del período asociado a la ejecución del pipeline.

    - **lv_dtype_venta, lv_dtype_produ, lv_dtype_trans, lv_dtype_merma, lv_dtype_produE**: Almacenan los identificadores de los tipos de EVENT TYPE (ventas, producción, transferencias, mermas, etc.).

    - **lv_punit**: Almacena el identificador de la unidad de procesamiento.

    - **lv_min_evento, lv_max_evento**: Almacenan las fechas mínima y máxima del evento.

    - **lv_salestransactionseq**: Almacena el identificador de la transacción de ventas.

    - **lv_sorder**: Almacena el identificador de la orden de ventas.

    - **lv_utype**: Almacena el identificador del tipo de unidad.

- Flujo del Procedimiento:
1. Inicialización de Variables:

    - Se obtienen los valores de lv_period_seq y lv_start_date basados en el pipelineRunSeq.

    - Se obtienen los identificadores de los tipos de eventos (lv_dtype_venta, lv_dtype_produ, etc.) desde la tabla TCMP.CS_EVENTTYPE.

    - Se obtiene el identificador de la unidad de procesamiento (lv_punit) desde la tabla TCMP.CS_PROCESSINGUNIT.

    - Se obtienen las fechas mínima y máxima del evento (lv_min_evento, lv_max_evento) desde la tabla EXT.TB_EVENTO_WKF.

2. Actualización de Transacciones de Ventas:

    - Se actualiza la tabla TCMP.CS_SALESTRANSACTION con información de la tabla EXT.TB_PRODUCTOFACT_HIS para las transacciones de ventas y transferencias en cuanto a las mesas y factores de los productos

3. Limpieza de Datos:

    - Se eliminan las transacciones de ventas con valor 0 en la tabla TCMP.CS_SALESTRANSACTION.

4. Verificación de Evento:

    - Si la fecha de compensación (lv_start_date) está dentro del rango de fechas del evento (lv_min_evento y lv_max_evento), se ejecuta la lógica de asignación con evento.

    - Si no, se ejecuta la lógica de asignación sin evento.

5. Asignación con Evento:

    - Se inserta un registro en la tabla EXT.TB_EVENTO_ADMIN indicando que la fecha está dentro del período de evento.

    - Se eliminan las transacciones de producción por evento en la tabla TCMP.CS_SALESTRANSACTION.

    - Se insertan datos de evento en la tabla EXT.TB_DATOS_EVENTO.

    - Se actualizan las transacciones en la tabla TCMP.CS_SALESTRANSACTION con los datos del evento.

    - Se insertan nuevas transacciones en la tabla TCMP.CS_SALESTRANSACTION basadas en los datos del evento.

    - Se asignan las transacciones a los empleados en la tabla TCMP.CS_TRANSACTIONASSIGNMENT.

6. Asignación sin Evento:

    - Se inserta un registro en la tabla EXT.TB_EVENTO_ADMIN indicando que la fecha no está dentro del período de evento.

    - Se asignan las transacciones a los empleados en la tabla TCMP.CS_TRANSACTIONASSIGNMENT sin considerar el evento.

7. Commit:

    - Se confirman las transacciones realizadas.

- PSEUDOCODIGO:
```
PROCEDURE EXT.PROC_TXN_ASSIGN_STAGEHOOK (IN pipelineRunSeq BIGINT)
BEGIN
    -- Declaración de variables
    DECLARE lv_period_seq, lv_dtype_venta, lv_dtype_produ, lv_dtype_trans, lv_dtype_merma, lv_dtype_produE, lv_punit, lv_salestransactionseq, lv_sorder, lv_utype BIGINT;
    DECLARE lv_start_date, lv_min_evento, lv_max_evento DATE;

    -- Obtener valores iniciales
    lv_period_seq = SELECT PERIODSEQ FROM TCMP.CS_PlRUN WHERE PIPELINERUNSEQ = pipelineRunSeq;
    lv_start_date = SELECT STARTDATE FROM TCMP.CS_PERIOD PER INNER JOIN TCMP.CS_PIPELINERUN PL ON PER.PERIODSEQ = PL.PERIODSEQ WHERE PL.PIPELINERUNSEQ = pipelineRunSeq;

    -- Obtener tipos de eventos
    lv_dtype_venta = SELECT DATATYPESEQ FROM TCMP.CS_EVENTTYPE WHERE EVENTTYPEID = 'VENTA DIARIA';
    lv_dtype_produ = SELECT DATATYPESEQ FROM TCMP.CS_EVENTTYPE WHERE EVENTTYPEID = 'PRODUCCION DIARIA';
    lv_dtype_trans = SELECT DATATYPESEQ FROM TCMP.CS_EVENTTYPE WHERE EVENTTYPEID = 'TRANSFERENCIA DIARIA';
    lv_dtype_merma = SELECT DATATYPESEQ FROM TCMP.CS_EVENTTYPE WHERE EVENTTYPEID = 'MERMA';
    lv_dtype_produE = SELECT DATATYPESEQ FROM TCMP.CS_EVENTTYPE WHERE EVENTTYPEID = 'INDICADORES DE EVENTO';

    -- Obtener unidad de procesamiento
    lv_punit = SELECT PROCESSINGUNITSEQ FROM TCMP.CS_PROCESSINGUNIT WHERE NAME = 'PU_SORIANA_PANIFICADORA';

    -- Obtener fechas de evento
    lv_min_evento = SELECT MIN(FEC_INI_PRODUCCION) FROM EXT.TB_EVENTO_WKF;
    lv_max_evento = SELECT MAX(FEC_FIN_VENTA) FROM EXT.TB_EVENTO_WKF;

    -- Actualizar transacciones de ventas
    UPDATE TCMP.CS_SALESTRANSACTION SET ... FROM EXT.TB_PRODUCTOFACT_HIS WHERE ...;

    -- Limpiar datos
    DELETE FROM TCMP.CS_SALESTRANSACTION WHERE VALUE = 0;

    -- Verificar si la fecha está dentro del evento
    IF lv_start_date BETWEEN lv_min_evento AND lv_max_evento THEN
        -- Lógica con evento
        INSERT INTO EXT.TB_EVENTO_ADMIN VALUES (lv_start_date, 'LA FECHA ESTA DENTRO DE LOS PERIODOS DE EVENTO', CURRENT_TIMESTAMP);
        DELETE FROM TCMP.CS_SALESTRANSACTION WHERE EVENTTYPESEQ = lv_dtype_produE AND COMPENSATIONDATE = lv_start_date;
        -- Insertar y actualizar datos de evento
        INSERT INTO EXT.TB_DATOS_EVENTO SELECT ...;
        INSERT INTO TCMP.CS_SALESTRANSACTION SELECT ...;
        INSERT INTO TCMP.CS_TRANSACTIONASSIGNMENT SELECT ...;
    ELSE
        -- Lógica sin evento
        INSERT INTO EXT.TB_EVENTO_ADMIN VALUES (lv_start_date, 'LA FECHA NO ESTA DENTRO DE LOS PERIODOS DE EVENTO', CURRENT_TIMESTAMP);
        INSERT INTO TCMP.CS_TRANSACTIONASSIGNMENT SELECT ...;
    END IF;

    -- Commit
    COMMIT;
END;
```
#### Asignación de transacciones
Este fragmento de código forma parte de un procedimiento almacenado que maneja la asignación de transacciones (CS_TRANSACTIONASSIGNMENT) y actualizaciones en la tabla CS_SALESTRANSACTION. El objetivo principal es asignar transacciones a empleados basándose en diferentes tipos de EVENT TYPE (ventas, producción, transferencias, merma, etc.) y actualizar identificadores específicos para reflejar las operaciones realizadas. Este proceso se realiza dentro de un período específico y está diseño para trabajar con una unidad de procesamiento específica (PU_SORIANA_PANIFICADORA).


- Lógica del Procedimiento:
    1. **Asignación de Transacciones**:
Se insertan registros en la tabla TCMP.CS_TRANSACTIONASSIGNMENT para asignar transacciones a empleados basándose en diferentes tipos de EVENT TYPE:

    - Ventas, Producción y Transferencias : Se asignan transacciones a empleados que asistieron (ASISTENCIA_ITX = TRUE) y participaron en eventos de ventas, producción o transferencias.
    - Merma : Se asignan transacciones relacionadas con merma a empleados que asistieron durante el mes actual.
    - Express : Se asignan transacciones sin producto asociado (PRODUCTID IS NULL) a empleados que asistieron.
    - Sección de Precio : Se asignan transacciones relacionadas con un producto específico (9999999908026) y mesas específicas (1, 3, 4) a empleados que asistieron.

    2. **Venta No Repartida** :
    Se insertan registros adicionales en TCMP.CS_TRANSACTIONASSIGNMENT para manejar transacciones relacionadas con ventas no repartidas. Esto incluye:
    - Transacciones asociadas a productos que viven en múltiples mesas.
    - Transacciones relacionadas con la sección de precio (9999999908026) y mesas específicas (1, 3, 4).

    3. **Identificación de Ventas** :
    Se actualiza el campo GENERICBOOLEAN1 en la tabla TCMP.CS_SALESTRANSACTION para marcar transacciones relacionadas con ventas no repartidas. Esto se logra utilizando datos de las tablas EXT.TB_VENTANOREPARTIDA_WKF y EXT.TB_PRODUCTOFACT_HIS.

    4. **Identificación de Sección** :
    Se actualiza el campo GENERICBOOLEAN1 en la tabla TCMP.CS_SALESTRANSACTION para marcar transacciones relacionadas con la sección de precio (9999999908026) y mesas específicas (1, 3, 4).

    5. **Confirmación de Cambios** :
    Se confirman todas las operaciones realizadas mediante un COMMIT.

- PSEUDOCODIGO:
```
INICIO
    -- ASIGNACIÓN DE TRANSACCIONES
    INSERTAR EN TCMP.CS_TRANSACTIONASSIGNMENT
        -- VENTAS, PRODUCCIÓN Y TRANSFERENCIAS
        SELECCIONAR DISTINCTO ST.TENANTID, ST.SALESTRANSACTIONSEQ, SUBSTRING(ST.SALESTRANSACTIONSEQ,11,8)||AST.ID_EMPLEADO AS SETNUMBER, 
        ST.COMPENSATIONDATE, ST.SALESORDERSEQ, AST.ID_EMPLEADO, ST.PROCESSINGUNITSEQ
        DESDE TCMP.CS_SALESTRANSACTION ST
        INNER JOIN EXT.TB_PRODUCTOFACT_HIS PF
            ON ST.LINENUMBER = PF.ID_SUCURSAL AND ST.PRODUCTID = TO_VARCHAR(PF.ID_PRODUCTO)
        INNER JOIN EXT.TB_ASISTENCIA_WKF AST
            ON ST.LINENUMBER = AST.ID_SUCURSAL AND ST.COMPENSATIONDATE = AST.FECHA_ASISTENCIA AND PF.ID_MESA = AST.ID_MESA_REAL
        DONDE EVENTTYPESEQ IN (lv_dtype_venta, lv_dtype_produ, lv_dtype_trans)
          Y ST.COMPENSATIONDATE = lv_start_date
          Y AST.ASISTENCIA_ITX = TRUE
          Y ST.PROCESSINGUNITSEQ = :lv_punit
        UNION
        -- MERMA
        SELECCIONAR DISTINCTO ST.TENANTID, ST.SALESTRANSACTIONSEQ, SUBSTRING(ST.SALESTRANSACTIONSEQ,11,8)||AST.ID_EMPLEADO AS SETNUMBER, 
        ST.COMPENSATIONDATE, ST.SALESORDERSEQ, AST.ID_EMPLEADO, ST.PROCESSINGUNITSEQ
        DESDE TCMP.CS_SALESTRANSACTION ST
        INNER JOIN EXT.TB_ASISTENCIA_WKF AST
            ON ST.GENERICATTRIBUTE3 = TO_VARCHAR(AST.ID_SUCURSAL)
        DONDE ST.EVENTTYPESEQ = lv_dtype_merma
          Y ST.COMPENSATIONDATE BETWEEN ADD_DAYS(lv_start_date, -DAYOFMONTH(lv_start_date) + 1) AND LAST_DAY(lv_start_date)
          Y ST.COMPENSATIONDATE = lv_start_date
          Y AST.FECHA_ASISTENCIA = lv_start_date
          Y AST.ASISTENCIA_ITX = TRUE
          Y ST.PROCESSINGUNITSEQ = :lv_punit
        UNION
        -- EXPRESS
        SELECCIONAR DISTINCTO ST.TENANTID, ST.SALESTRANSACTIONSEQ, SUBSTRING(ST.SALESTRANSACTIONSEQ,11,8)||AST.ID_EMPLEADO AS SETNUMBER, 
        ST.COMPENSATIONDATE, ST.SALESORDERSEQ, AST.ID_EMPLEADO, ST.PROCESSINGUNITSEQ
        DESDE TCMP.CS_SALESTRANSACTION ST
        INNER JOIN EXT.TB_ASISTENCIA_WKF AST
            ON ST.LINENUMBER = AST.ID_SUCURSAL AND ST.COMPENSATIONDATE = AST.FECHA_ASISTENCIA
        DONDE ST.EVENTTYPESEQ = lv_dtype_venta
          Y PRODUCTID IS NULL
          Y ST.COMPENSATIONDATE = lv_start_date
          Y AST.ASISTENCIA_ITX = TRUE
          Y ST.PROCESSINGUNITSEQ = :lv_punit
        UNION
        -- SECCIÓN PRECIO
        SELECCIONAR DISTINCTO ST.TENANTID, ST.SALESTRANSACTIONSEQ, SUBSTRING(ST.SALESTRANSACTIONSEQ,11,8)||AST.ID_EMPLEADO AS SETNUMBER, 
        ST.COMPENSATIONDATE, ST.SALESORDERSEQ, AST.ID_EMPLEADO, ST.PROCESSINGUNITSEQ
        DESDE TCMP.CS_SALESTRANSACTION ST
        INNER JOIN EXT.TB_ASISTENCIA_WKF AST
            ON ST.LINENUMBER = AST.ID_SUCURSAL AND ST.COMPENSATIONDATE = AST.FECHA_ASISTENCIA
        DONDE EVENTTYPESEQ IN (lv_dtype_venta)
          Y ST.COMPENSATIONDATE = :lv_start_date
          Y ST.PRODUCTID = '9999999908026'
          Y ID_MESA_REAL IN (1, 3, 4)
          Y AST.ASISTENCIA_ITX = TRUE;

    -- VENTA NO REPARTIDA
    INSERTAR EN TCMP.CS_TRANSACTIONASSIGNMENT
        SELECCIONAR DISTINCTO ST.TENANTID, ST.SALESTRANSACTIONSEQ, SUBSTRING(ST.SALESTRANSACTIONSEQ,11,8)||AST.ID_EMPLEADO AS SETNUMBER, 
        ST.COMPENSATIONDATE, ST.SALESORDERSEQ, AST.ID_EMPLEADO, ST.PROCESSINGUNITSEQ
        DESDE TCMP.CS_SALESTRANSACTION ST
        INNER JOIN EXT.TB_PRODUCTOFACT_HIS PF
            ON ST.LINENUMBER = PF.ID_SUCURSAL AND ST.PRODUCTID = TO_VARCHAR(PF.ID_PRODUCTO)
        INNER JOIN EXT.TB_VENTANOREPARTIDA_WKF AST
            ON ST.LINENUMBER = AST.ID_SUCURSAL_DESTINO AND ST.COMPENSATIONDATE = AST.FECHA_ASISTENCIA AND PF.ID_MESA = AST.ID_MESA
        DONDE EVENTTYPESEQ IN (lv_dtype_venta, lv_dtype_produ, lv_dtype_trans)
          Y ST.COMPENSATIONDATE = lv_start_date
        UNION
        -- SECCIÓN PRECIO
        SELECCIONAR DISTINCTO ST.TENANTID, ST.SALESTRANSACTIONSEQ, SUBSTRING(ST.SALESTRANSACTIONSEQ,11,8)||AST.ID_EMPLEADO AS SETNUMBER, 
        ST.COMPENSATIONDATE, ST.SALESORDERSEQ, AST.ID_EMPLEADO, ST.PROCESSINGUNITSEQ
        DESDE TCMP.CS_SALESTRANSACTION ST
        INNER JOIN EXT.TB_VENTANOREPARTIDA_WKF AST
            ON ST.LINENUMBER = AST.ID_SUCURSAL_DESTINO AND ST.COMPENSATIONDATE = AST.FECHA_ASISTENCIA
        DONDE EVENTTYPESEQ IN (lv_dtype_venta)
          Y ST.COMPENSATIONDATE = :lv_start_date
          Y ST.PRODUCTID = '9999999908026'
          Y ID_MESA IN (1, 3, 4);

    -- IDENTIFICADOR VENTAS
    ACTUALIZAR TCMP.CS_SALESTRANSACTION
    SET GENERICBOOLEAN1 = 1
    DESDE TCMP.CS_SALESTRANSACTION, (
        SELECCIONAR VNR.ID_SUCURSAL_DESTINO, VNR.ID_MESA, PF.ID_PRODUCTO, VNR.FECHA_ASISTENCIA
        DESDE EXT.TB_VENTANOREPARTIDA_WKF VNR
        INNER JOIN EXT.TB_PRODUCTOFACT_HIS PF
            ON VNR.ID_SUCURSAL_DESTINO = PF.ID_SUCURSAL AND VNR.ID_MESA = PF.ID_MESA
    ) MAINVNR
    DONDE TCMP.CS_SALESTRANSACTION.LINENUMBER = MAINVNR.ID_SUCURSAL_DESTINO
      Y TCMP.CS_SALESTRANSACTION.PRODUCTID = MAINVNR.ID_PRODUCTO
      Y TCMP.CS_SALESTRANSACTION.COMPENSATIONDATE = :lv_start_date
      Y TCMP.CS_SALESTRANSACTION.EVENTTYPESEQ IN (:lv_dtype_venta, :lv_dtype_trans);

    -- IDENTIFICADOR SECCIÓN
    ACTUALIZAR TCMP.CS_SALESTRANSACTION
    SET GENERICBOOLEAN1 = 1
    DESDE TCMP.CS_SALESTRANSACTION, EXT.TB_VENTANOREPARTIDA_WKF
    DONDE TCMP.CS_SALESTRANSACTION.LINENUMBER = EXT.TB_VENTANOREPARTIDA_WKF.ID_SUCURSAL_DESTINO
      Y TCMP.CS_SALESTRANSACTION.PRODUCTID = '9999999908026'
      Y TCMP.CS_SALESTRANSACTION.COMPENSATIONDATE = :lv_start_date
      Y EXT.TB_VENTANOREPARTIDA_WKF.ID_MESA IN (1, 3, 4);

    CONFIRMAR CAMBIOS (COMMIT)
FIN
```
#### Creación y asignación de transacciones de EVENTO
1. Creación
Procesa y gestiona datos relacionados con EVENT TYPE's de producción, ventas y transacciones en un sistema complejo. El objetivo principal es insertar, actualizar y consolidar datos en tablas temporales (EXT.TB_DATOS_EVENTO y EXT.TB_DATOS_TXN) para reflejar información sobre la producción, ventas acumuladas y transacciones asociadas al evento de rosca de reyes. Además, se insertan registros en la tabla TCMP.CS_SALESTRANSACTION para registrar transacciones relacionadas.

- Pasos:
    1. **Insertar Datos de Eventos** : Consolidar información sobre la producción y ventas acumuladas en la tabla EXT.TB_DATOS_EVENTO de acuerdo a las sucursales activas en el periodo de evento, producción diaria, venta diaria y factores de los productos
    2. **Actualizar Datos de Transacciones** : Filtrar y actualizar los datos de transacciones en la tabla EXT.TB_DATOS_TXN basándose en fechas y rangos de eventos.
    3. **Actualizar Producción y Ventas** : Ajustar los valores de producción acumulada y ventas acumuladas en la tabla EXT.TB_DATOS_TXN de acuerdo a las fechas y rangos de eventos.
    4. **Insertar Transacciones** : Registrar nuevas transacciones en la tabla TCMP.CS_SALESTRANSACTION basándose en los datos consolidados en la tabla EXT.TB_DATOS_TXN.

- Lógica del Procedimiento:
    1. Inserción de Datos de Eventos :
    - Se eliminan todos los registros existentes en la tabla EXT.TB_DATOS_EVENTO.
    - Se insertan nuevos registros en EXT.TB_DATOS_EVENTO consolidando información sobre la producción y ventas acumuladas. Esto incluye:
        - Datos de producción diaria (EXT.TB_PRODUCCIONDIARIA_WKF).
        - Datos de ventas acumuladas (TCMP.CS_SALESTRANSACTION).
        - Factores de productos (EXT.TB_PRODUCTOFACT_HIS).
        - Clasificadores de productos (TCMP.CS_CLASSIFIER).
    2. Actualización de Datos de Transacciones :
    - Se eliminan todos los registros existentes en la tabla EXT.TB_DATOS_TXN.
    - Se insertan nuevos registros en EXT.TB_DATOS_TXN filtrando los datos de EXT.TB_DATOS_EVENTO basándose en:
        - Fechas de producción dentro del rango de eventos.
        - Sucursales activas durante el período de eventos.

    3. Actualización de Producción Acumulada :
    - Se actualizan los campos FECHA_PRODUCCION y ACUMULADO_PRODUCIDAS en la tabla EXT.TB_DATOS_TXN utilizando datos consolidados de EXT.TB_DATOS_EVENTO.

    4. Actualización de Ventas Acumuladas :
    - Se actualizan los campos UNIDADES_VENDIDAS y ACUMULADO_VENDIDAS en la tabla EXT.TB_DATOS_TXN utilizando datos de ventas acumuladas.

    5. Inserción de Transacciones :
    - Se insertan nuevos registros en la tabla TCMP.CS_SALESTRANSACTION para registrar transacciones relacionadas con eventos. Esto incluye:
        - Información básica de la transacción (fecha, producto, sucursal, etc.).
        - Valores acumulados de producción y ventas.
        - Identificadores genéricos y fechas relacionadas con el evento.

- PSEUDOCODIGO:
```
INICIO
    -- ELIMINAR DATOS EXISTENTES EN TB_DATOS_EVENTO
    ELIMINAR REGISTROS DE EXT.TB_DATOS_EVENTO;

    -- INSERTAR DATOS DE EVENTOS EN TB_DATOS_EVENTO
    INSERTAR EN EXT.TB_DATOS_EVENTO
        SELECCIONAR 
            A.ID_SUCURSAL,
            A.ID_CVE_CODIGO,
            A.ID_NUM_MESATRABAJO,
            A.ID_FEC_PRODUCCION,
            A.NAME,
            A.UNIDADES_PRODUCIDAS,
            A.ACUMULADO_PRODUCIDAS,
            IFNULL(B.UNIDADES_VENDIDAS, 0) UNIDADES_VENDIDAS,
            IFNULL(B.ACUMULADO_VENDIDAS, 0) ACUMULADO_VENDIDAS,
            A.FACTOR,
            A.FEC_INI_PRODUCCION,
            A.FEC_FIN_VENTA,
            A.ACUMULADO_PRODUCIDAS, -- ACUM_DIARIO
            A.ID_FEC_PRODUCCION -- COMPENSATION
        DESDE (
            CONSULTA PARA OBTENER DATOS DE PRODUCCIÓN Y FACTORES
        ) A
        FULL JOIN (
            CONSULTA PARA OBTENER DATOS DE VENTAS ACUMULADAS
        ) B
        ON A.ID_SUCURSAL = B.LINENUMBER
            AND A.ID_CVE_CODIGO = B.PRODUCTID
            AND A.ID_FEC_PRODUCCION = B.COMPENSATIONDATE
        ORDENAR POR B.COMPENSATIONDATE;

    -- ELIMINAR DATOS EXISTENTES EN TB_DATOS_TXN
    ELIMINAR REGISTROS DE EXT.TB_DATOS_TXN;

    -- INSERTAR DATOS FILTRADOS EN TB_DATOS_TXN
    INSERTAR EN EXT.TB_DATOS_TXN
        SELECCIONAR *
        DESDE EXT.TB_DATOS_EVENTO
        DONDE FECHA_PRODUCCION IS NOT NULL
          Y FECHA_PRODUCCION BETWEEN FECHA_PRODUCCION AND :lv_start_date
          Y ID_SUCURSAL IN (
              SELECCIONAR ID_SUCURSAL
              DESDE (
                  CONSULTA PARA OBTENER RANGOS DE EVENTOS POR SUCURSAL
              ) D
              DONDE D.INIE <= :lv_start_date
                Y :lv_start_date <= D.FINE
          );

    -- ACTUALIZAR PRODUCCIÓN ACUMULADA EN TB_DATOS_TXN
    ACTUALIZAR EXT.TB_DATOS_TXN DT
    SET DT.FECHA_PRODUCCION = :lv_start_date,
        DT.ACUMULADO_PRODUCIDAS = DE.ACUMULADO_PRODUCIDAS
    DESDE EXT.TB_DATOS_TXN DT
    INNER JOIN (
        CONSULTA PARA OBTENER MÁXIMOS DE PRODUCCIÓN ACUMULADA
    ) DE
    ON DT.ID_SUCURSAL = DE.ID_SUCURSAL
      AND DT.ID_PRODUCTO = DE.ID_PRODUCTO;

    -- ACTUALIZAR VENTAS ACUMULADAS EN TB_DATOS_TXN
    ACTUALIZAR EXT.TB_DATOS_TXN DT
    SET DT.UNIDADES_VENDIDAS = DE.UNIDADES_VENDIDAS,
        DT.ACUMULADO_VENDIDAS = DE.ACUMULADO_VENDIDAS
    DESDE EXT.TB_DATOS_TXN DT
    INNER JOIN (
        CONSULTA PARA OBTENER DATOS DE VENTAS ACUMULADAS
    ) DE
    ON DT.ID_SUCURSAL = DE.LINENUMBER
      AND DT.ID_PRODUCTO = DE.PRODUCTID;

    -- INSERTAR TRANSACCIONES EN CS_SALESTRANSACTION
    INSERTAR EN TCMP.CS_SALESTRANSACTION (
        TENANTID, SALESTRANSACTIONSEQ, SALESORDERSEQ, LINENUMBER, SUBLINENUMBER,
        EVENTTYPESEQ, ORIGINTYPEID, COMPENSATIONDATE, ISRUNNABLE, BUSINESSUNITMAP,
        PRODUCTID, PRODUCTNAME, PREADJUSTEDVALUE, UNITTYPEFORPREADJUSTEDVALUE,
        VALUE, UNITTYPEFORVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE3,
        GENERICNUMBER1, UNITTYPEFORGENERICNUMBER1, GENERICNUMBER2,
        UNITTYPEFORGENERICNUMBER2, GENERICNUMBER3, UNITTYPEFORGENERICNUMBER3,
        GENERICDATE1, GENERICDATE2, GENERICDATE3, PROCESSINGUNITSEQ,
        MODIFICATIONDATE, MODELSEQ
    )
        SELECCIONAR 
            'G0FA', -- TENANTID
            :lv_salestransactionseq + 10000000000000 + ROW_NUMBER() OVER (ORDER BY SO.SALESORDERSEQ),
            :lv_sorder, -- SALESORDERSEQ
            C.ID_PRODUCTO||EXTRACT_DAY(C.COMPENSATION), -- LINENUMBER
            TO_BIGINT(TO_VARCHAR(C.FECHA_PRODUCCION, 'YYYYMMDD')), -- SUBLINENUMBER
            :lv_dtype_produE, -- EVENTTYPESEQ
            'manual', -- ORIGINTYPEID
            TO_TIMESTAMP(C.FECHA_PRODUCCION), -- COMPENSATIONDATE
            1, -- ISRUNNABLE
            1, -- BUSINESSUNITMAP
            C.ID_PRODUCTO, -- PRODUCTID
            C.PRODUCTNAME, -- PRODUCTNAME
            C.UNIDADES_PRODUCIDAS, -- PREADJUSTEDVALUE
            :lv_utype, -- UNITTYPEFORPREADJUSTEDVALUE
            C.UNIDADES_PRODUCIDAS, -- VALUE
            :lv_utype, -- UNITTYPEFORVALUE
            C.ID_MESA, -- GENERICATTRIBUTE1
            C.ID_SUCURSAL, -- GENERICATTRIBUTE3
            C.ACUMULADO_PRODUCIDAS, -- GENERICNUMBER1
            :lv_utype, -- UNITTYPEFORGENERICNUMBER1
            C.ACUMULADO_VENDIDAS, -- GENERICNUMBER2
            :lv_utype, -- UNITTYPEFORGENERICNUMBER2
            C.FACTOR, -- GENERICNUMBER3
            :lv_utype, -- UNITTYPEFORGENERICNUMBER3
            C.FECHA_INI_EVENTO, -- GENERICDATE1
            C.FECHA_FIN_EVENTO, -- GENERICDATE2
            C.COMPENSATION, -- GENERICDATE3
            :lv_punit, -- PROCESSINGUNITSEQ
            CURRENT_TIMESTAMP, -- MODIFICATIONDATE
            0 -- MODELSEQ
        DESDE EXT.TB_DATOS_TXN C
        INNER JOIN TCMP.CS_SALESORDER SO
            ON C.ID_PRODUCTO = SO.ORDERID
            AND SO.REMOVEDATE = '2200-01-01'
            AND SO.PROCESSINGUNITSEQ = :lv_punit
            AND C.FECHA_PRODUCCION IS NOT NULL;
FIN
```
2. Asignación de Transacciones de Evento
Maneja la asignación de transacciones y actualizaciones en la tabla TCMP.CS_TRANSACTIONASSIGNMENT. El objetivo principal es insertar y actualizar registros relacionados con la participación de empleados en el periodo de evento, basándose en su asistencia (ASISTENCIA_ITX) y estatus de transferencia (ESTATUS_TRANS). Este proceso se realiza dentro de un período específico y está diseño para trabajar con una unidad de procesamiento específica (PU_SORIANA_PANIFICADORA). El propósito del script es:

    - Insertar registros en la tabla TCMP.CS_TRANSACTIONASSIGNMENT para asignar transacciones a empleados basándose en diferentes criterios:
        - Nativos : Empleados sin apoyo en eventos.
        - Con apoyo : Empleados con apoyo en eventos, clasificados por estatus de transacción (0, 1, 3 o 2, 4).
    - Actualizar campos específicos en la tabla TCMP.CS_TRANSACTIONASSIGNMENT para reflejar la participación de los empleados (PORCENTAJE_PARTICIPACION_EMPLEADO) y su asistencia (ASISTENCIA_ITX).
    - Asegurar que todas las operaciones realizadas se confirmen mediante un COMMIT.

- Lógica de Procedimiento
    1. **Inserción de Registros para Nativos** :
Se insertan registros en TCMP.CS_TRANSACTIONASSIGNMENT para empleados nativos (sin apoyo en eventos) que cumplen con los siguientes criterios:
    - Su estatus de transacción es 0.
    - No tienen decorado asociado (DECORADO IS NULL).
    - No están registrados en la tabla EXT.TB_ASISTENCIA_EVENTO_WKF para la fecha actual.
    - Pertenece a la unidad de procesamiento especificada.
    2. **Inserción de Registros para Empleados con Apoyo** :
Se insertan registros en TCMP.CS_TRANSACTIONASSIGNMENT para empleados con apoyo en eventos, clasificados por estatus de transacción:
    - Estatus 0, 1, 3 : Empleados que participan en eventos específicos y cumplen con ciertas condiciones (mesas reales 1, 3).
    - Estatus 2, 4 : Empleados que no requieren verificación adicional (SIN CHECK).
Pertenece a la unidad de procesamiento especificada (lv_punit).
    3. **Actualización de Participación y Asistencia** :
Se actualizan los campos GENERICNUMBER1 (porcentaje de participación) y GENERICNUMBER2 (asistencia) en la tabla TCMP.CS_TRANSACTIONASSIGNMENT basándose en datos de las tablas EXT.TB_ASISTENCIA_WKF y EXT.TB_ASISTENCIA_EVENTO_WKF.
Las actualizaciones se realizan para diferentes grupos de empleados:
    - Nativos : Empleados sin apoyo con estatus 0.
    - Con apoyo : Empleados con estatus 0, 1, 3 o 2, 4.
    4. **Confirmación de Cambios** :
Se confirman todas las operaciones realizadas mediante un COMMIT.

### Stored Procedures
| SP | Proceso a ejecutar | Herramienta |