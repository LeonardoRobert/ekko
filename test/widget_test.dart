// Teste padrao do `flutter create` (contador) removido -- nao se aplica
// a esse app. Sem suite de teste de widget de verdade ainda (mesma
// situacao do awake_app, que tambem nao tem hoje); um smoke test real
// pumping o EkkoApp precisa de Supabase.initialize() rodado antes, o que
// nao acontece nesse ambiente de teste isolado.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
