# Forja Infinita: Robots Kids v1.6.0

Edición infantil independiente para Godot 4.4.1, Android ARM64 y PC. Usa un identificador Android diferente, por lo que puede instalarse junto a la edición normal.

## Modo fácil

El modo principal está diseñado en tres pasos grandes y claros:

1. Elegir uno de cuatro robots preparados.
2. Conocer al rival y comparar vida, fuerza y rapidez con puntos visuales.
3. Jugar una partida automática usando un único botón grande de **Superpoder**.

## Robots preparados

- **Estrella:** equilibrado y fácil de usar.
- **Rayito:** rápido y con muchos movimientos.
- **Fortachón:** mucha vida y resistencia a empujones.
- **Inventor:** buenas herramientas, energía y alcance.

## Diseño infantil

- Robot grande durante la elección, sin menús encima del modelo.
- Selección directa: toca cabeza, torso, brazos, piernas o manos sobre el propio robot para abrir esa categoría.
- Puedes volver a tocar cualquier zona y cambiarla todas las veces que quieras antes de comenzar.
- El modo Kids ofrece solo cuatro piezas claras por zona; el Taller avanzado conserva las veinte.
- Botón aleatorio grande y visible flotando justo encima del robot.
- Botones táctiles grandes, textos cortos y colores diferentes para cada robot.
- Rival presentado antes de cada partida con solo tres comparaciones importantes.
- CPU inicial más fácil y dificultad progresiva.
- Un solo control durante el juego: **Superpoder**.
- Destellos de cinco colores en los impactos.
- Las piezas nunca se desprenden y los robots no muestran deterioro visual.
- Un aro de luz suave sigue al robot de cada jugador dentro del ring; los rivales controlados por la CPU no lo tienen.
- Al terminar, el robot que pierde simplemente se toma un descanso.
- Victoria entrega tres estrellas y cada intento entrega una estrella.
- Si el jugador no gana, **Ayúdame a elegir** recomienda automáticamente el robot preparado con mayor posibilidad contra ese rival.
- Mensajes positivos, nombres amistosos y explicación integrada en pantalla.

## Opciones adicionales

La edición conserva el taller completo de 160 piezas, dos jugadores en un dispositivo y LAN de 2 a 4 teléfonos. Todos usan la presentación amistosa sin desprendimiento de piezas.

## Ejecutar en PC

Abre `project.godot` con Godot 4.4.1 y ejecuta el proyecto. También puedes usar `COMPILAR_EN_PC.bat` si Godot está configurado en el PATH.

## Compilar Android desde Termux

Dentro de la carpeta extraída ejecuta:

```bash
bash SUBIR_Y_COMPILAR_TERMUX.sh
```

El flujo de GitHub valida el catálogo, ejecuta la prueba interna y exporta `ForjaInfinitaKids-debug.apk`. El paquete Android es `com.leonardo.forjainfinita.kids`.

Todo el arte, las miniaturas, la música y los efectos se generan dentro del proyecto. No necesita descargar recursos externos.
