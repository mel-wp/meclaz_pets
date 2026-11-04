import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('API de adoção rodando em http://127.0.0.1:8080');

  final animais = [
    {
      'id': 1,
      'nome': 'Luna',
      'especie': 'Gato',
      'idade_em_meses': 8,
      'disponivel': true,
    },
    {
      'id': 2,
      'nome': 'Thor',
      'especie': 'Cachorro',
      'idade_em_meses': 24,
      'disponivel': false,
    },
  ];

  await for (final requisicao in servidor) {
    final resposta = requisicao.response;
    resposta.headers.contentType = ContentType.json;

    if (requisicao.method == 'GET' && requisicao.uri.path == '/animais') {
      final apenasDisponiveis =
          requisicao.uri.queryParameters['disponivel'] == 'true';

      final resultado = apenasDisponiveis
          ? animais.where((animal) => animal['disponivel'] == true).toList()
          : animais;

      resposta.write(jsonEncode(resultado));
    } else {
      resposta.statusCode = HttpStatus.notFound;
      resposta.write(jsonEncode({'erro': 'Rota não encontrada'}));
    }

    await resposta.close();
  }
}