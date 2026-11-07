import 'dart:io';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  stdout.write('Digite a senha do PostgreSQL: ');

  // Esconde a senha enquanto você digita no terminal.
  stdin.echoMode = false;
  String? senha;

  try {
    senha = stdin.readLineSync();
  } finally {
    stdin.echoMode = true;
    stdout.writeln();
  }

  final conexao = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'meclaz_pets',
      username: 'postgres',
      password: senha,
    ),
    // Configuração para o banco local deste exercício.
    settings: ConnectionSettings(
      sslMode: SslMode.disable,
    ),
  );

  try {
    print('Conectado ao PostgreSQL!');

    final resultado = await conexao.execute(
      'SELECT * FROM animais ORDER BY id',
    );

    for (final linha in resultado) {
      final animal = linha.toColumnMap();

      print(
        '${animal['id']} - ${animal['nome']} '
        '(${animal['especie']})',
      );
    }
  } finally {
    await conexao.close();
  }
}