# Forja Infinita: Robots

Juego 3D original para Godot 4.4.1, Android y PC. Fue reconstruido usando la base técnica liviana de **Sendas del Alba v0.28.1**, pero no conserva su mundo, personajes, enemigos ni lógica de aventura.

## La idea

Construyes un robot sobre un pedestal y después lo ves pelear automáticamente en un ring. Puedes jugar una arena infinita contra la CPU o un versus local para dos personas usando el mismo dispositivo.

## Contenido terminado

- 8 espacios independientes: cabeza, torso, brazo izquierdo, brazo derecho, pierna izquierda, pierna derecha y un arma para cada mano.
- 20 opciones en cada espacio: 160 elecciones catalogadas y 25.600.000.000 combinaciones posibles.
- Piezas originales inspiradas en grandes arquetipos de robots, ciencia ficción y superhéroes, sin copiar personajes existentes.
- El robot se actualiza y sus piezas vuelan hacia el pedestal al seleccionarlas.
- Estadísticas reales de vida, potencia, blindaje, velocidad, alcance y energía.
- Sinergias: familias de piezas, armas gemelas, piernas sincronizadas y brazos sincronizados.
- Tiempos de construcción de 30 segundos, 1 minuto, 2 minutos o sin límite.
- Arena CPU infinita: empieza fácil, desbloquea más variedad y aumenta su potencia sin límite.
- Multijugador local por turnos para 2 personas.
- Combate automático con persecución, distancia táctica, ataques cuerpo a cuerpo y a distancia, críticos, sobrecargas, retroceso y límite de tiempo.
- Ring 3D con plataforma, esquinas, postes, tres cuerdas por lado, luces y colores de cada equipo.
- Guardado del nivel CPU, récord, victorias y último robot.
- Interfaz táctil; no necesita teclado para jugar.
- Modo x2 durante los combates.
- Todo el arte 3D se genera con geometría propia: no necesita descargar recursos externos.

## Ejecutar en PC

1. Instala Godot 4.4.1.
2. Abre `project.godot`.
3. Presiona F6/F5 o el botón **Ejecutar proyecto**.

También puedes ejecutar `COMPILAR_EN_PC.bat` en Windows si Godot está en el PATH.

## Crear el APK en GitHub

1. Sube **el contenido de esta carpeta** a un repositorio de GitHub. `project.godot` debe quedar en la raíz.
2. Entra a **Actions**.
3. Abre **Compilar Forja Infinita para Android**.
4. Pulsa **Run workflow**.
5. Cuando termine en verde, descarga el artefacto **ForjaInfinita-Android-debug**.

El flujo valida el proyecto, ejecuta una prueba interna del catálogo y del montaje, exporta ARM64 y comprueba que el APK exista.

## Estructura limpia

- `scripts/main.gd`: estados, taller, UI, ring, modos, progreso y flujo completo.
- `scripts/robot_catalog.gd`: las 20 opciones por espacio, estadísticas y sinergias.
- `scripts/robot_model.gd`: construcción visual procedural y animaciones.
- `scripts/fighter.gd`: inteligencia de combate automático.
- `scenes/main.tscn`: escena de arranque mínima.
- `.github/workflows/build-android.yml`: compilación automática del APK.

No se incluyeron archivos de Sendas del Alba que este juego no utiliza.

