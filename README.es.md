# Wanbo Dali 1: limpieza

[English](README.md)

Deja el proyector Wanbo Dali 1 listo para streaming: saca el bloatware de fábrica, cambia el
launcher con publicidad y hace que YouTube vuelva a funcionar. Todo se hace por ADB de red, sin
flashear, sin firmware modificado y sin escribir en `/system`. Cada cambio es reversible.

Probado en un equipo en octubre de 2026. Si tu firmware es distinto, revisa el paso de inventario
antes de correr nada.

## El equipo

| | |
|---|---|
| Modelo | Wanbo Dali 1 (350 lúmenes ANSI, 720p nativo). Modelo interno `WPD11` |
| Firmware | `wanbo-WPD11-KCHE-V1.0.7-20241021`, Android 9, `ro.build.type=user` |
| Chip | HiSilicon Hi3751V350 (`bigfish`), ARM de 32 bits (`armeabi-v7a`) |
| RAM / almacenamiento | 1 GB (más ~310 MB de zram) / 8 GB, de los que ~2,8 GB son `/data` |
| Launcher | `com.zeasn.launcher` (Zeasn, armado por Kystar), con una fila de publicidad |
| Google | Trae Play Store y los servicios de Google |

## Hallazgos

- **`adb shell` entra como root** (`uid=0`, contexto SELinux `u:r:su:s0`) con el firmware de
  fábrica, y existe `/system/xbin/su`. Por ADB se tiene acceso total sin rootear nada.
  `ro.adb.secure=1`, así que un PC nuevo *debería* pedir autorización. No se pudo verificar si se
  cumple: el aviso nunca apareció en pantalla durante las pruebas y aun así la conexión funcionó
  después de un `adb kill-server`.
- **YouTube está bloqueado desde el servidor.** La app oficial, incluso actualizada de la 3.04 a la
  5.30, dice "YouTube no es compatible con este dispositivo". El firmware se identifica con la
  huella de otra placa (`Mstar/CVTE_MSD338_512M/...:4.4.4`), así que YouTube no lo considera un
  equipo certificado. [SmartTube](https://github.com/yuliskov/SmartTube) funciona bien y es lo que
  instala `apply.sh`. Además se salta la publicidad, cosa que va contra las condiciones de YouTube.
  Tú decides.
- **Algunas apps de fábrica vuelven a arrancar aunque estén desactivadas.** `com.sdt.factorytest`,
  `com.kystar.middleware.track` y `com.zeasn.deviceportal.asdprovider.kystar_hisi352` tienen la
  marca `PERSISTENT` y este firmware las arranca incluso con `enabled=3` (desactivadas).
  `pm uninstall -k --user 0` las detiene de forma definitiva y deja el APK en `/system`.
- **`com.kystar.middleware.track` es un servicio de accesibilidad** (`TopAppTrackingService`) que
  registra qué app está en pantalla. Viene activado de fábrica.
- **Play Store vuelve a activar YouTube al reiniciar** si solo está desactivado. Con `pm hide`
  queda fijo.
- **No hay codificador de video por hardware**, solo `OMX.google.h264.encoder`, que funciona por
  software. Ver la pantalla con scrcpy funciona, pero solo con resolución y FPS bajos (ver más
  abajo).
- Netflix, Disney+, Prime Video y Max funcionan (Widevine L1). Netflix viene en su versión de
  celular (`com.netflix.mediaclient`), no en la de TV.

Incluso después de la limpieza, 1 GB de RAM es el verdadero límite. Si te sigue pareciendo lento,
un stick de streaming por HDMI rinde más que cualquier ajuste.

## Inicio rápido

Necesitas `adb`, `curl` y `python3` en un computador conectado a la misma red.

1. En el proyector: **Ajustes → Acerca de** → presiona 7 veces **Número de compilación**. Después,
   en **Opciones de desarrollador**, activa **Depuración USB** y **Depuración por red**. Anota la IP
   que aparece en **Ajustes → Red**.
2. Conéctate y revisa el equipo antes de cambiar nada:
   ```bash
   adb connect <ip>:5555
   adb devices                                   # tiene que decir "device", no "unauthorized"
   adb shell getprop ro.build.display.id         # compáralo con el firmware de arriba
   adb shell pm list packages -s | sort          # compáralo con packages/stock-system.txt
   ```
   Si queda `unauthorized` y no aparece ningún aviso, corre `adb kill-server` y vuelve a conectar.
3. Corre el script:
   ```bash
   ./apply.sh <ip>
   ```
   La primera vez abre Projectivy Launcher en Play Store. Instálalo, completa su bienvenida con el
   control y vuelve a correr `./apply.sh <ip>`. La segunda corrida deja Projectivy como pantalla de
   inicio y desactiva el launcher de Wanbo.
4. `adb reboot`.

## Sin el script (Windows, macOS, Linux)

`apply.sh` necesita bash. Sin él, los mismos pasos se hacen con comandos `adb` sueltos en
cualquier sistema operativo. En Windows, `adb` viene en
[Platform Tools](https://developer.android.com/tools/releases/platform-tools) o en la carpeta de
scrcpy.

1. **Conectar:** `adb connect <ip>:5555`
2. **Instalar Projectivy Launcher:**
   `adb shell am start -a android.intent.action.VIEW -d market://details?id=com.spocky.projengmenu`,
   presionar Instalar en el proyector y completar la bienvenida con el control. Después:
   `adb shell cmd package set-home-activity com.spocky.projengmenu/.ui.home.MainActivity`.
   Confirma que el botón Home abre Projectivy **antes** de desactivar el launcher de Wanbo.
3. **Instalar SmartTube:** bajar `SmartTube_stable_<versión>_armeabi-v7a.apk` desde
   [sus versiones](https://github.com/yuliskov/SmartTube/releases/latest) y correr `adb install <apk>`.
4. **Desactivar** cada paquete de [packages/disabled.txt](packages/disabled.txt), salvo los que
   uses: `adb shell pm disable-user --user 0 <paquete>`
5. **Detener las 3 apps que arrancan igual:** `adb shell pm uninstall -k --user 0 <paquete>` para
   `com.sdt.factorytest`, `com.kystar.middleware.track` y
   `com.zeasn.deviceportal.asdprovider.kystar_hisi352`.
6. **Ocultar el YouTube oficial:** `adb shell pm hide com.google.android.youtube.tv`
7. **Quitar el rastreador, apagar las animaciones y vaciar la caché:**
   `adb shell settings delete secure enabled_accessibility_services`, luego
   `adb shell settings put global <clave> 0` para `window_animation_scale`,
   `transition_animation_scale` y `animator_duration_scale`, y por último
   `adb shell pm trim-caches 999G` y `adb reboot`.

Qué se cambia, cómo revertirlo, cómo ver la pantalla con scrcpy y cómo resolver problemas está en
el [README en inglés](README.md); los comandos son los mismos. Si usas duplicar pantalla, el
reproductor de pendrive o el modo parlante, saca esas líneas de `packages/disabled.txt` antes de
correr el script.

## Aviso

No tiene relación con Wanbo. Funcionó en un equipo con el firmware de arriba. Úsalo bajo tu propia
responsabilidad.
