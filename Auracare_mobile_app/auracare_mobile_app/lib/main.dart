import 'package:flutter/material.dart';

import 'app/auth_root.dart';
import 'data/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = await initializeAuthentication();
  runApp(AuthenticationRoot(auth: auth));
}
