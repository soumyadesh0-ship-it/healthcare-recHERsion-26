import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/supabase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await createAuthService();
  runApp(AuracareApp(authService: authService));
}
