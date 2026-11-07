import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

// Lê o JSON enviado pelo aplicativo ou pelo PowerShell.
Future<Map<String, dynamic>> lerDados(HttpRequest requisicao) async {
  final texto = await utf8.decoder.bind(requisicao).join();
  final dados = jsonDecode(texto);

  if (dados is! Map<String, dynamic>) {
    throw const FormatException('Envie um objeto JSON.');
  }

  return dados;
}

// Confere se um campo de texto foi preenchido.
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

Future<void> main() async {
  stdout.write('Digite a senha do PostgreSQL: ');

  stdin.echoMode = false;
  String? senha;

  try {
    senha = stdin.readLineSync();
  } finally {
    stdin.echoMode = true;
    stdout.writeln();
  }

  // Conecta ao PostgreSQL instalado neste computador.
  final conexao = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'meclaz_pets',
      username: 'postgres',
      password: senha,
    ),
    settings: ConnectionSettings(
      sslMode: SslMode.disable,
    ),
  );

  try {
    final servidor = await HttpServer.bind(
  InternetAddress.anyIPv4,
  8080,
);

    print('Conectado ao PostgreSQL!');
    print('API rodando em http://127.0.0.1:8080/animais');

    await for (final requisicao in servidor) {
      final resposta = requisicao.response;
      resposta.headers.contentType = ContentType.json;

      try {
        final caminho = requisicao.uri.path;
        final metodo = requisicao.method;

        if (caminho == '/animais' && metodo == 'GET') {
          // Consulta todos os animais ou somente os disponíveis.
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
        } else if (caminho == '/animais' && metodo == 'POST') {
          final dados = await lerDados(requisicao);

          final nome = validarTexto(dados, 'nome', 100);
          final especie = validarTexto(dados, 'especie', 50);
          final idade = dados['idade_em_meses'];

          if (idade is! int || idade < 0 || idade > 2147483647) {
            throw const FormatException(
              'Informe uma idade em meses válida, inteira e não negativa.',
            );
          }

          // O banco gera o ID e devolve o animal cadastrado.
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
            parameters: {
              'nome': nome,
              'especie': especie,
              'idade': idade,
            },
          );

          resposta.statusCode = HttpStatus.created;
          resposta.write(
            jsonEncode(resultado.first.toColumnMap()),
          );
        } else if (caminho == '/solicitacoes' && metodo == 'POST') {
          final dados = await lerDados(requisicao);

          final animalId = dados['animal_id'];
          final nome = validarTexto(dados, 'nome_interessado', 100);
          final contato = validarTexto(dados, 'contato', 150);

          if (animalId is! int ||
              animalId <= 0 ||
              animalId > 2147483647) {
            throw const FormatException('Informe um ID de animal válido.');
          }

          // Registra o pedido apenas se o animal estiver disponível.
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
          resposta.write(
            jsonEncode(resultado.first.toColumnMap()),
          );
        } else if (caminho == '/animais' ||
            caminho == '/solicitacoes') {
          resposta.statusCode = HttpStatus.methodNotAllowed;
          resposta.headers.set(
            'Allow',
            caminho == '/animais' ? 'GET, POST' : 'POST',
          );

          resposta.write(
            jsonEncode({'erro': 'Método não permitido nesta rota.'}),
          );
        } else {
          resposta.statusCode = HttpStatus.notFound;
          resposta.write(
            jsonEncode({'erro': 'Rota não encontrada.'}),
          );
        }
      } on FormatException catch (erro) {
        resposta.statusCode = HttpStatus.badRequest;
        resposta.write(jsonEncode({'erro': erro.message}));
      } catch (erro) {
        // Exibe os detalhes no terminal para ajudar no diagnóstico.
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