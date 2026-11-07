import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


const ipDoComputador = '127.0.0.1';
//192.168.3.13
//esse é o ip do meu not, pra rodar no teu precisa trocar dai


const corDoTexto = Color(0xFF492B31);
const corDoTextoSecundario = Color(0xFF704D55);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meclaz Pets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD85B32),
          primary: const Color(0xFFAA4022),
          secondary: const Color(0xFFAC3563),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF5F5),
      ),
      home: const AnimaisDisponiveisPage(),
    );
  }
}

class AnimaisDisponiveisPage extends StatefulWidget {
  const AnimaisDisponiveisPage({super.key});

  @override
  State<AnimaisDisponiveisPage> createState() =>
      _AnimaisDisponiveisPageState();
}

class _AnimaisDisponiveisPageState extends State<AnimaisDisponiveisPage> {
  late Future<List<Map<String, dynamic>>> consulta;

  @override
  void initState() {
    super.initState();
    consulta = buscarAnimais();
  }

  Future<List<Map<String, dynamic>>> buscarAnimais() async {
    final endereco = Uri.http(
      '$ipDoComputador:8080',
      '/animais',
      {'disponivel': 'true'},
    );

    final resposta = await http.get(endereco).timeout(
      const Duration(seconds: 10),
    );

    if (resposta.statusCode != 200) {
      throw Exception('A API retornou o código ${resposta.statusCode}.');
    }

    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.cast<Map<String, dynamic>>();
  }

  void atualizarLista() {
    setState(() {
      consulta = buscarAnimais();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pets_rounded,
                        color: Color(0xFFBD492D),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Meclaz Pets',
                          style: TextStyle(
                            color: corDoTexto,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Atualizar lista',
                        onPressed: atualizarLista,
                        icon: const Icon(Icons.refresh_rounded),
                        color: corDoTexto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Animais disponíveis',
                    style: TextStyle(
                      color: corDoTexto,
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: consulta,
                      builder: (context, resultado) {
                        if (resultado.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (resultado.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Não foi possível carregar os animais. '
                                  'Confira se a API está rodando.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: corDoTexto),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: atualizarLista,
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          );
                        }

                        final animais = resultado.data ?? [];

                        if (animais.isEmpty) {
                          return const Center(
                            child: Text(
                              'Nenhum animal disponível no momento.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: animais.length,
                          separatorBuilder: (context, indice) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, indice) {
                            final animal = animais[indice];
                            final idade = animal['idade_em_meses'];
                            final unidade = idade == 1 ? 'mês' : 'meses';
                            final usarPessego = indice.isEven;

                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: usarPessego
                                    ? const Color(0xFFFFE6D7)
                                    : const Color(0xFFFFE1EB),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: usarPessego
                                        ? const Color(0xFFFFCCAC)
                                        : const Color(0xFFFFBFD4),
                                    child: Icon(
                                      Icons.pets_rounded,
                                      color: usarPessego
                                          ? const Color(0xFFAB4121)
                                          : const Color(0xFFA02956),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          animal['nome'],
                                          style: const TextStyle(
                                            color: corDoTexto,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${animal['especie']} • '
                                          '$idade $unidade',
                                          style: const TextStyle(
                                            color: corDoTextoSecundario,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}