# ce1copy — Data Warehouse propio en Snowflake

Proyecto dbt que construye un DW desde 7 fuentes heterogéneas (MySQL, PostgreSQL, MariaDB, SQL Server, CSV, JSON) hasta un modelo dimensional listo para Power BI.

## Arquitectura

```
CBRONZE (32 tablas, Airbyte)
    │
    ▼
CSILVER ── staging (32 vistas)     ← solo tipado y limpieza
    │
    ▼
CSILVER ── intermediate (11 tablas) ← conformación e integración
    │
    ▼
CGOLD ── dimensions (15 tablas)     ← dimensiones
    └── facts (7 tablas)            ← hechos
```

## Las 8 operaciones del negocio

| # | Operación | Hecho | Fuentes |
|---|---|---|---|
| 1 | Originación de crédito | fact_solicitudes, fact_prestamos | F1 |
| 2 | Cobranza | fact_pagos | F1 |
| 3 | Riesgo de crédito | fact_riesgo_cliente | F2+F3+F4 |
| 4 | Garantías | fact_garantias | F1 |
| 5 | Derechos reales | fact_derechos_reales | F5 |
| 6 | Gravámenes | int_gravamen | F5+F1 |
| 7 | Deuda externa | fact_deuda_externa | F3 |
| 8 | Redes sociales | int_social | F7 |

## Reglas de negocio centrales

### Identidad canónica
- 9 dígitos: 8 de base + 1 verificador.
- Se normaliza con `REGEXP_REPLACE(col, '[^0-9]', '')` (nunca `\D`, que en Snowflake es un no-op).
- Se valida con `RLIKE '^[1-9][0-9]{8}$'`.
- Mínimo 2 fuentes independientes para confirmar.

### Score de morosidad
- Escala ASFI 350-950: más alto = más riesgo.
- La categoría del proveedor es independiente del score y se respeta.
- Los cortes del score (450/650/800) son de la escala ASFI, no de 0-100.

### Mora
- 5 buckets: Al día, Leve (1-30), Moderada (31-60), Severa (61-90), Crítica (>90).
- El umbral de mora vigente es 90 días.
- Los cortes viven en `dbt_project.yml`, no en el SQL.

### Garantías
- LTV = saldo / avaluo. Un LTV alto significa que el bien respalda poco.
- Un avaluo de más de 3 años no se usa para decidir cobertura hoy.

## Estructura de carpetas

```
models/
  sources.yml              ← 32 fuentes Bronze
  schema.yml               ← tests de staging, intermedios y Gold
  silver/
    staging/               ← 32 vistas (solo tipado y limpieza)
    intermediate/          ← 11 tablas (conformación e integración)
  gold/
    dimensions/            ← 15 dimensiones
    facts/                 ← 7 hechos
macros/
  normalizar_identidad.sql ← identidad canónica de 9 dígitos
  bucket_mora.sql          ← mora, riesgo, LTV, capacidad de pago
  fechas.sql               ← fechas y dimensión tiempo
  hash_pii.sql             ← enmascarado de datos sensibles
  calidades.sql            ← validación de calidad
  generate_schema_name.sql ← override para respetar CSILVER/CGOLD
tests/
  identidad_canonica_valida.sql
  score_en_escala_asfi.sql
  categoria_riesgo_estandar.sql
  bucket_mora_consistente.sql
  ltv_en_rango.sql
seeds/
  fecha_corte.csv          ← fecha de corte del DW
```

## Comandos

```powershell
# validar intermedios y Gold en CE1COPY_TEST
python "%TEMP%\opencode\validar_intermedios.py"

# chequear una columna concreta (correr DESPUÉS del validador)
python "%TEMP%\opencode\verificar_columnas.py" --par STG_F3__DEUDA_CR fecha_originacion
```

## Limitaciones conocidas

- **F4-F1:** solo 1 de 25,400 accionistas cruza con F1 por identidad. Se resolvió uniendo participantes por `empresa_id`.
- **F7 no se une con el núcleo de clientes:** no hay llave entre un usuario de red social y un `cliente_id`. `int_social` es autónomo.
- **F6 cubre 60% de los clientes:** 33,840 de 56,400. El 40% restante no tiene historial financiero externo.
