import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'db/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(CestovniApp(db: db));
}
