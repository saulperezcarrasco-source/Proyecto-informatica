# Ruta RD Offline — v1.0.0-demo

APK de demostración **release x64**, firmado con la clave de desarrollo Android.
Destino probado: Pixel_10a, Android 17 API 37 en emulador. No es una entrega
para Google Play ni un APK ARM para teléfonos. Los resultados de GPS y
rendimiento corresponden al emulador; el GPS de prueba usa posición inyectada.

El paquete incluye APK, código fuente, manifiesto con versión/commit/hashes,
verificación de firma, licencias, guion y video de respaldo. Para verificar el
APK en Windows:

```powershell
Get-FileHash .\ruta-rd-v1.0.0-demo-android-x64.apk -Algorithm SHA256
```

Comparar con manifest.json o SHA256SUMS.txt. No cambiar el APK después de
comparar los hashes. Instalar exactamente ese archivo con el emulador abierto:

```powershell
adb -s emulator-5554 install -r .\ruta-rd-v1.0.0-demo-android-x64.apk
adb -s emulator-5554 shell am start -S -W -f 0x10008000 -n com.example.ruta_rd/.MainActivity
```

Para repetir la primera apertura limpia, **se borran los favoritos y ajustes
solo de Ruta RD Offline**:

```powershell
adb -s emulator-5554 shell pm clear com.example.ruta_rd
adb -s emulator-5554 shell am force-stop com.example.ruta_rd
adb -s emulator-5554 shell cmd connectivity airplane-mode enable
adb -s emulator-5554 shell svc wifi disable
adb -s emulator-5554 shell svc data disable
adb -s emulator-5554 shell am start -S -W -f 0x10008000 -n com.example.ruta_rd/.MainActivity
```

Esperar la carga local del mapa. Buscar `cafe`, guardar dos estrellas, elegir
origen y destino: la ruta azul se calcula automáticamente. Favoritos permite
volver a elegir lugares guardados. Quitar una estrella conserva el recorrido.
Probar también dos toques directos en el mapa de RD. El botón Ver toda RD vuelve
a la vista nacional. El modo oscuro se conserva al cerrar y reabrir.

Mi ubicación solicita permiso solo al pulsarlo. Si se rechaza o no hay posición,
elegir puntos manualmente o mediante los lugares buscados. No se debe presentar
una posición del emulador como GPS físico. Consultar DATOS-Y-LICENCIAS.md.

Después de probar, restaurar la conectividad del emulador:

```powershell
adb -s emulator-5554 shell cmd connectivity airplane-mode disable
adb -s emulator-5554 shell svc wifi enable
adb -s emulator-5554 shell svc data enable
```

## Reproducir desde las fuentes

Descomprimir fuentes-v1.0.0-demo.zip y entrar en `ruta_rd`. Flutter y Android
SDK deben estar configurados; las versiones usadas están en manifest.json.
Los datos ya están incluidos: no hace falta regenerarlos ni descargar mapas
durante la ejecución. Con conexión solo para preparar dependencias:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-x64
```

El APK de esa compilación se encuentra en build/app/outputs/flutter-apk.
Los hashes identifican los archivos entregados; una recompilación puede generar
otros hashes.
El empaquetado del repositorio original se realiza después de guardar cambios
en un commit: `tools/build_demo.ps1` construye e instala; `tools/package_demo.ps1`
verifica firma, versión y hash, copia el APK y genera el ZIP del commit registrado.
No ejecutar pruebas/pub en paralelo con la compilación final. La firma propia
para publicación y sus credenciales quedan fuera de esta demo y del repositorio.
