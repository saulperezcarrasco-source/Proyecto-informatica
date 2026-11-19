import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_rd/main.dart';

void main() {
  testWidgets('muestra el nombre de la aplicación', (tester) async {
    await tester.pumpWidget(const RutaRdApp());
    expect(find.text('Ruta RD Offline'), findsOneWidget);
  });
}
