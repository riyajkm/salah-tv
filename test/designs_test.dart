import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/designs/designs.dart';
import 'package:salah_lk/models/app_settings.dart';

void main() {
  test('design ids are unique and non-empty', () {
    final ids = kDesigns.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((i) => i.isNotEmpty), isTrue);
  });

  test('the original two ids are kept (they are stored in saved settings)', () {
    expect(kDesigns.map((d) => d.id), containsAll(['classic', 'all']));
  });

  test('the default design exists, and is what new installs use', () {
    expect(kDesigns.any((d) => d.id == kDefaultDesignId), isTrue);
    expect(const AppSettings().design, kDefaultDesignId);
  });

  test('an unknown id falls back to the default instead of failing', () {
    expect(designById('does-not-exist').id, kDefaultDesignId);
    expect(designById('all').id, 'all');
  });
}
