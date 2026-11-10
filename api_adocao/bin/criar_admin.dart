import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  stdout.write('Senha do PostgreSQL: ');

  stdin.echoMode = false;
  final senhaBanco = stdin.readLineSync();
  stdin.echoMode = true;
  stdout.writeln();

  if (senhaBanco == null || senhaBanco.isEmpty) {
    print('Senha do PostgreSQL não informada.');
    return;
  }

  final conexao = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'meclaz_pets',
      username: 'postgres',
      password: senhaBanco,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    stdout.write('Nome do administrador: ');
    final nome = stdin.readLineSync()?.trim() ?? '';

    stdout.write('E-mail: ');
    final email = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    stdout.write('Senha da conta: ');
    stdin.echoMode = false;
    final senha = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    stdout.writeln();

    if (nome.isEmpty || email.isEmpty || senha.length < 8) {
      print('Preencha os dados. A senha deve ter pelo menos 8 caracteres.');
      return;
    }

    final senhaHash = BCrypt.hashpw(senha, BCrypt.gensalt());

    await conexao.execute(
      Sql.named('''
        INSERT INTO usuarios (nome, email, senha_hash, tipo, ativo)
        VALUES (@nome, @email, @senha, 'admin', TRUE)
      '''),
      parameters: {'nome': nome, 'email': email, 'senha': senhaHash},
    );

    print('Administrador cadastrado com sucesso!');
  } catch (erro) {
    print('Não foi possível cadastrar: $erro');
  } finally {
    await conexao.close();
  }
}
