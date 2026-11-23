# Identidad Ruta RD

ruta_rd.png es una copia sin modificaciones de 1.png proporcionado por el usuario.
La pantalla de inicio recorta únicamente márgenes blancos mediante layout Flutter;
conserva el símbolo y los textos completos. El original también se conserva en
la raíz del repositorio.

ruta_symbol.png es la adaptación transparente para el icono preparada con la
habilidad imagegen y la herramienta incorporada image_gen, sin API/CLI externo.
Las densidades Android derivan de ese símbolo mediante tools/prepare_brand.ps1.
El icono adaptativo añade margen para las máscaras de Android; los recursos
monocromos se restringen a Android 13+ y los PNG sirven para Android 7/8.

Prompt utilizado:

> Use case: background-extraction. Edit target is the supplied RUTA RD OFFLINE logo.
> Extract ONLY the existing turquoise map pin plus folded map symbol from above
> the lettering. Remove ALL text and white background. Preserve the exact original
> symbol's silhouette, lines, proportions and flat #009688 color. Do not redesign
> or add elements. Center the complete symbol on a square transparent canvas with
> roughly 15% transparent margin all around, suitable as an Android app icon
> foreground. Output an actual transparent PNG.

La adaptación generada puede variar ligeramente respecto del original; el PNG
completo usado en inicio no depende de esa recreación. No eliminar los assets
sin cambiar sus referencias Flutter y Android.
