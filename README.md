# Forja Infinita: Robots Kids v2.1.0

## Robots retro amigables

- Nuevo estilo 3D de juguete inspirado en ilustraciones clásicas de robots simpáticos, con diseños originales.
- Cabezas más grandes, placas faciales claras, ojos expresivos y antenas de distintos tamaños.
- Torsos redondeados con paneles circulares, luces y botones de colores.
- Brazos más delgados con articulaciones visibles, anillos mecánicos y manos redondas o tipo pinza.
- Piernas más cortas con rodillas grandes y botas exageradas, redondeadas y estables.
- Materiales con menos brillo metálico y colores más vivos para que todos los modos compartan el nuevo aspecto.

## Nuevo hangar táctico

- Menú de selección reorganizado como laboratorio de mecas: diagnóstico a la izquierda, robot grande al centro y banco de piezas a la derecha.
- Tarjetas cuadradas de 132 × 132 con ilustraciones técnicas grandes, retícula y estados bloqueados muy visibles.
- Clasificación automática del robot en Explorador, Vanguardia, Asalto o Coloso según su peso final.
- Panel independiente para diez estadísticas, afinidad, potencia, créditos, sinergia y armas equipadas.
- Piezas avanzadas rediseñadas con cabinas, sensores, hombreras, blindaje modular, pistones y puntos de montaje.
- Estética inspirada en hangares de robots militares modernos, usando diseños y nombres originales de Forja Infinita.

Edición infantil independiente para Godot 4.4.1, Android ARM64 y PC. Usa un identificador Android diferente, por lo que puede instalarse junto a la edición normal.

## Modo fácil

El modo principal está diseñado en cuatro pasos grandes y claros:

1. Elegir uno de cuatro robots preparados y cambiar sus piezas tocando el modelo.
2. Escoger una expresión facial divertida.
3. Conocer al rival y comparar vida, fuerza y rapidez con puntos visuales.
4. Jugar una partida automática usando un único botón grande de **Superpoder**.

## Robots preparados

- **Estrella:** equilibrado y fácil de usar.
- **Rayito:** rápido y con muchos movimientos.
- **Fortachón:** mucha vida y resistencia a empujones.
- **Inventor:** buenas herramientas, energía y alcance.

## Diseño infantil

- Robot todavía más grande durante la elección, completamente visible y sin paneles encima del modelo.
- El robot permanece siempre a la izquierda y los dos talleres colocan toda la selección a la derecha.
- Tarjetas cuadradas con miniaturas grandes de cada pieza: menos texto, cuatro opciones visibles en Kids y veinte en el avanzado.
- Las categorías del taller avanzado también son botones cuadrados ilustrados con la pieza equipada.
- El panel derecho puede desplazarse, por lo que las imágenes mantienen un tamaño cómodo sin tapar el robot.
- Selección directa invisible: toca cabeza, torso, brazos, piernas o manos sobre el propio robot para abrir esa categoría sin taparlo.
- Puedes volver a tocar cualquier zona y cambiarla todas las veces que quieras antes de comenzar.
- El modo Kids ofrece solo cuatro piezas claras por zona; el Taller avanzado conserva las veinte.
- Botón aleatorio grande y visible flotando justo encima del robot.
- Selector de ocho expresiones faciales 3D: alegre, enojado, sorpresa, travieso, decidido, dormido, confundido y fiesta.
- La expresión se guarda con la configuración y continúa visible dentro del ring.
- Estadísticas trasladadas al panel lateral para dejar libre toda la vista del robot.
- Botones táctiles grandes, textos cortos y colores diferentes para cada robot.
- Rival presentado antes de cada partida con solo tres comparaciones importantes.
- CPU inicial más fácil y dificultad progresiva.
- Un solo control durante el juego: **Superpoder**.
- Destellos de cinco colores en los impactos.
- IA de combate compartida por Kids y adulto con rodeos, fintas, retiradas, cargas, bloqueos y esquivas laterales.
- Los robots se separan después de atacar y cambian de distancia en lugar de permanecer pegados frente a frente.
- Ataques con giro de torso, tres variantes de movimiento, impulso y recuperación.
- Los robots ahora pueden saltar para entrar, esquivar o cambiar el ángulo de ataque.
- IA ampliada de seis a nueve tácticas: salto ofensivo, flanqueo y contraataque se suman a rodeo, presión, retirada, finta, carga y defensa.
- En historia avanzada la CPU decide y reacciona más rápido a medida que sube el nivel.
- Los golpes críticos muestran anuncios arcade compactos, destello de pantalla, sonido especial y una sacudida más intensa.
- En críticos y golpes de herramienta pueden desprenderse de forma mecánica cabezas, brazos o armas; vuelan con cables y chispas, sin efectos gráficos violentos.
- Los desarmes cambian de verdad el combate: perder un brazo reduce fuerza y velocidad de ataque; perder la cabeza reduce puntería y energía.
- Música original de combate industrial a 156 BPM, con percusión metálica, bajo y sintetizadores propios.
- Al cambiar una pieza, una mano robótica la transporta, la instala y termina con destellos de soldadura y sonido mecánico.
- Un aro de luz suave sigue al robot de cada jugador dentro del ring; los rivales controlados por la CPU no lo tienen.
- Al terminar, el robot que pierde simplemente se toma un descanso.
- Victoria entrega tres estrellas y cada intento entrega una estrella.
- Si el jugador no gana, **Ayúdame a elegir** recomienda automáticamente el robot preparado con mayor posibilidad contra ese rival.
- Mensajes positivos, nombres amistosos y explicación integrada en pantalla.

## Opciones adicionales

La edición conserva el taller completo de 160 piezas, dos jugadores en un dispositivo y LAN de 2 a 4 teléfonos. Todos comparten la misma IA, los críticos arcade y los desprendimientos mecánicos. El combate avanzado agrega botones de **Saltar**, **Defensa** e **Impulso** además del arma principal.

## Ejecutar en PC

Abre `project.godot` con Godot 4.4.1 y ejecuta el proyecto. También puedes usar `COMPILAR_EN_PC.bat` si Godot está configurado en el PATH.

## Compilar Android desde Termux

Dentro de la carpeta extraída ejecuta:

```bash
bash SUBIR_Y_COMPILAR_TERMUX.sh
```

El flujo de GitHub valida el catálogo, ejecuta la prueba interna y exporta `ForjaInfinitaKids-debug.apk`. El paquete Android es `com.leonardo.forjainfinita.kids`.

Todo el arte, las miniaturas, la música y los efectos se generan dentro del proyecto. No necesita descargar recursos externos.
