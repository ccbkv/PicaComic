import 'db/db.dart' show openDb;

Future<void> main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  await openDb();
  // runApp(const App());
}
