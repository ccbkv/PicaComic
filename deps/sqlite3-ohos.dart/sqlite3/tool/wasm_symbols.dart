import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/dart/ast/ast.dart';

/// Writes flags for clang that will `-Wl,--export` all symbols used by the
/// `sqlite3` Dart package.
void main(List<String> args) {
  final file = File('lib/src/wasm/wasm_interop.dart');
  final ast = parseString(content: file.readAsStringSync(), path: file.path);

  final finder = _FindUsedSymbols();
  ast.unit.accept(finder);

  final output = File(args[0]);
  output.writeAsStringSync(
      finder.symbols.map((e) => '-Wl,--export=$e').join(' '));
}

class _FindUsedSymbols extends RecursiveAstVisitor<void> {
  final List<String> symbols = [];
  bool _inInitializer = false;

  _FindUsedSymbols();

  @override
  void visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    _inInitializer = true;
    super.visitConstructorFieldInitializer(node);
    _inInitializer = false;
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (_inInitializer) {
      symbols.add(node.value);
    }
  }
}
