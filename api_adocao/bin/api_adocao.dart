import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

Future<Map<String, dynamic>> lerDados(HttpRequest requisicao) async {
  final texto = await utf8.decoder.bind(requisicao).join();
  final dados = jsonDecode(texto);

  if (dados is! Map<String, dynamic>) {
    throw const FormatException('Envie um objeto JSON.');
  }

  return dados;
}

String validarTexto(
  Map<String, dynamic> dados,
  String campo,
  int tamanhoMaximo,
) {
  final valor = dados[campo];

  if (valor is! String || valor.trim().isEmpty) {
    throw FormatException('Preencha o campo $campo.');
  }

  if (valor.trim().length > tamanhoMaximo) {
    throw FormatException(
      'O campo $campo aceita até $tamanhoMaximo caracteres.',
    );
  }

  return valor.trim();
}

// Verifica se o token pertence a um administrador ativo.
Future<bool> ehAdministrador(
  HttpRequest requisicao,
  Connection conexao,
  String segredo,
) async {
  try {
    final autorizacao = requisicao.headers.value(
      HttpHeaders.authorizationHeader,
    );

    if (autorizacao == null || !autorizacao.startsWith('Bearer ')) {
      return false;
    }

    final token = autorizacao.substring(7);
    final jwt = JWT.verify(token, SecretKey(segredo));
    final payload = jwt.payload;

    if (payload is! Map || payload['id'] is! num) {
      return false;
    }

    final resultado = await conexao.execute(
      Sql.named('''
        SELECT id
        FROM usuarios
        WHERE id = @id
          AND tipo = 'admin'
          AND ativo = TRUE
      '''),
      parameters: {'id': (payload['id'] as num).toInt()},
    );

    return resultado.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  final segredo = Platform.environment['JWT_SECRET'];

  if (segredo == null || segredo.length < 32) {
    print('Configure a variável JWT_SECRET com pelo menos 32 caracteres.');
    return;
  }

  stdout.write('Digite a senha do PostgreSQL: ');

  stdin.echoMode = false;
  String? senhaBanco;

  try {
    senhaBanco = stdin.readLineSync();
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
      password: senhaBanco,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    final servidor = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

    print('Conectado ao PostgreSQL!');
    print('API rodando em http://127.0.0.1:8080');

    await for (final requisicao in servidor) {
      final resposta = requisicao.response;
      resposta.headers.contentType = ContentType.json;

      try {
        final caminho = requisicao.uri.path;
        final metodo = requisicao.method;

        // LOGIN DOS ADMINISTRADORES
        if (caminho == '/login' && metodo == 'POST') {
          final dados = await lerDados(requisicao);

          final email = validarTexto(dados, 'email', 150).toLowerCase();
          final senha = validarTexto(dados, 'senha', 100);

          final resultado = await conexao.execute(
            Sql.named('''
              SELECT id, nome, email, senha_hash
              FROM usuarios
              WHERE email = @email
                AND tipo = 'admin'
                AND ativo = TRUE
            '''),
            parameters: {'email': email},
          );

          if (resultado.isEmpty) {
            resposta.statusCode = HttpStatus.unauthorized;
            resposta.write(jsonEncode({'erro': 'E-mail ou senha incorretos.'}));
          } else {
            final usuario = resultado.first.toColumnMap();
            final senhaCorreta = BCrypt.checkpw(
              senha,
              usuario['senha_hash'] as String,
            );

            if (!senhaCorreta) {
              resposta.statusCode = HttpStatus.unauthorized;
              resposta.write(
                jsonEncode({'erro': 'E-mail ou senha incorretos.'}),
              );
            } else {
              final agora = DateTime.now().toUtc();
              final expiracao = agora.add(const Duration(hours: 8));

              final token = JWT({
                'id': usuario['id'],
                'email': usuario['email'],
                'exp': expiracao.millisecondsSinceEpoch ~/ 1000,
              }).sign(SecretKey(segredo));

              resposta.write(
                jsonEncode({
                  'mensagem': 'Login realizado com sucesso!',
                  'token': token,
                  'usuario': {
                    'id': usuario['id'],
                    'nome': usuario['nome'],
                    'email': usuario['email'],
                  },
                }),
              );
            }
          }
        }
        // CONSULTAR ANIMAIS
        else if (caminho == '/animais' && metodo == 'GET') {
          final apenasDisponiveis =
              requisicao.uri.queryParameters['disponivel'] == 'true';

          final consulta = apenasDisponiveis
              ? 'SELECT * FROM animais WHERE disponivel = TRUE ORDER BY id'
              : 'SELECT * FROM animais ORDER BY id';

          final resultado = await conexao.execute(consulta);

          final animais = resultado
              .map((linha) => linha.toColumnMap())
              .toList();

          resposta.write(jsonEncode(animais));
        }
        // CADASTRAR ANIMAL - SOMENTE ADMINISTRADOR
        else if (caminho == '/animais' && metodo == 'POST') {
          final autorizado = await ehAdministrador(
            requisicao,
            conexao,
            segredo,
          );

          if (!autorizado) {
            resposta.statusCode = HttpStatus.forbidden;
            resposta.write(
              jsonEncode({
                'erro': 'Acesso negado. Faça login como administrador.',
              }),
            );
          } else {
            final dados = await lerDados(requisicao);

            final nome = validarTexto(dados, 'nome', 100);
            final especie = validarTexto(dados, 'especie', 50);
            final idade = dados['idade_em_meses'];

            if (idade is! int || idade < 0) {
              throw const FormatException('Informe uma idade em meses válida.');
            }

            final resultado = await conexao.execute(
              Sql.named('''
                INSERT INTO animais (
                  nome,
                  especie,
                  idade_em_meses,
                  disponivel
                )
                VALUES (@nome, @especie, @idade, TRUE)
                RETURNING *
              '''),
              parameters: {'nome': nome, 'especie': especie, 'idade': idade},
            );

            resposta.statusCode = HttpStatus.created;
            resposta.write(jsonEncode(resultado.first.toColumnMap()));
          }
        }
        // SOLICITAR ADOÇÃO
        else if (caminho == '/solicitacoes' && metodo == 'POST') {
          final dados = await lerDados(requisicao);

          final animalId = dados['animal_id'];
          final nome = validarTexto(dados, 'nome_interessado', 100);
          final contato = validarTexto(dados, 'contato', 150);

          if (animalId is! int || animalId <= 0) {
            throw const FormatException('Informe um ID de animal válido.');
          }

          final resultado = await conexao.execute(
            Sql.named('''
              INSERT INTO solicitacoes (
                animal_id,
                nome_interessado,
                contato,
                status
              )
              SELECT id, @nome, @contato, 'pendente'
              FROM animais
              WHERE id = @animalId AND disponivel = TRUE
              RETURNING *
            '''),
            parameters: {
              'animalId': animalId,
              'nome': nome,
              'contato': contato,
            },
          );

          if (resultado.isEmpty) {
            throw const FormatException(
              'O animal não existe ou não está disponível para adoção.',
            );
          }

          resposta.statusCode = HttpStatus.created;
          resposta.write(jsonEncode(resultado.first.toColumnMap()));
        }
        // ROTAS OU MÉTODOS NÃO EXISTENTES
        else {
          resposta.statusCode = HttpStatus.notFound;
          resposta.write(
            jsonEncode({
              'erro': 'Rota não encontrada ou método não permitido.',
            }),
          );
        }
      } on FormatException catch (erro) {
        resposta.statusCode = HttpStatus.badRequest;
        resposta.write(jsonEncode({'erro': erro.message}));
      } catch (erro) {
        stderr.writeln('Erro ao atender requisição: $erro');

        resposta.statusCode = HttpStatus.internalServerError;
        resposta.write(
          jsonEncode({'erro': 'Não foi possível concluir a operação.'}),
        );
      } finally {
        await resposta.close();
      }
    }
  } finally {
    await conexao.close();
  }
}
