import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Para emulador Android use 10.0.2.2. Em celular físico, informe o IP
// local do computador com --dart-define=API_HOST=192.168.x.x.
const apiHost = String.fromEnvironment('API_HOST', defaultValue: '10.0.2.2');
final apiBase = Uri(scheme: 'http', host: apiHost, port: 8080);

const corDoTexto = Color(0xFF492B31);
const corDoTextoSecundario = Color(0xFF704D55);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
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
    final resposta = await http
        .get(apiBase.replace(path: '/animais', queryParameters: {
          'disponivel': 'true',
        }))
        .timeout(const Duration(seconds: 10));
    if (resposta.statusCode != 200) {
      throw Exception('A API retornou o código ${resposta.statusCode}.');
    }
    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    if (dados is! List) throw const FormatException('Resposta inválida da API.');
    return dados.cast<Map<String, dynamic>>();
  }

  void atualizarLista() => setState(() => consulta = buscarAnimais());

  Future<void> solicitarAdocao(Map<String, dynamic> animal) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => SolicitacaoDialog(animal: animal),
    );
    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido enviado! A ONG entrará em contato.')),
      );
      atualizarLista();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.pets_rounded, color: Color(0xFFBD492D)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Meclaz Pets', style: TextStyle(
                        color: corDoTexto, fontSize: 19, fontWeight: FontWeight.w700,
                      ))),
                      IconButton(
                        tooltip: 'Atualizar lista',
                        onPressed: atualizarLista,
                        icon: const Icon(Icons.refresh_rounded),
                        color: corDoTexto,
                      ),
                    ]),
                    const SizedBox(height: 22),
                    const Text('Encontre seu novo amigo', style: TextStyle(
                      color: corDoTexto, fontSize: 28, height: 1.15,
                      fontWeight: FontWeight.w800,
                    )),
                    const SizedBox(height: 7),
                    const Text('Animais disponíveis para adoção', style: TextStyle(
                      color: corDoTextoSecundario, fontSize: 15,
                    )),
                    const SizedBox(height: 18),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: consulta,
                        builder: (context, resultado) {
                          if (resultado.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (resultado.hasError) {
                            return Center(child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 42, color: corDoTextoSecundario),
                                const SizedBox(height: 10),
                                const Text('Não foi possível carregar os animais. Confira se o banco e a API estão rodando.', textAlign: TextAlign.center, style: TextStyle(color: corDoTexto)),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: atualizarLista, child: const Text('Tentar novamente')),
                              ],
                            ));
                          }
                          final animais = resultado.data ?? [];
                          if (animais.isEmpty) {
                            return const Center(child: Text('Nenhum animal disponível no momento.', textAlign: TextAlign.center));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: animais.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, indice) {
                              final animal = animais[indice];
                              final idade = animal['idade_em_meses'];
                              final unidade = idade == 1 ? 'mês' : 'meses';
                              final pessego = indice.isEven;
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: pessego ? const Color(0xFFFFE6D7) : const Color(0xFFFFE1EB),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: pessego ? const Color(0xFFFFCCAC) : const Color(0xFFFFBFD4),
                                    child: Icon(Icons.pets_rounded, color: pessego ? const Color(0xFFAB4121) : const Color(0xFFA02956)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${animal['nome']}', style: const TextStyle(color: corDoTexto, fontSize: 20, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text('${animal['especie']} • $idade $unidade', style: const TextStyle(color: corDoTextoSecundario)),
                                    ],
                                  )),
                                  const SizedBox(width: 6),
                                  FilledButton.tonal(
                                    onPressed: () => solicitarAdocao(animal),
                                    child: const Text('Adotar'),
                                  ),
                                ]),
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

class SolicitacaoDialog extends StatefulWidget {
  const SolicitacaoDialog({super.key, required this.animal});
  final Map<String, dynamic> animal;

  @override
  State<SolicitacaoDialog> createState() => _SolicitacaoDialogState();
}

class _SolicitacaoDialogState extends State<SolicitacaoDialog> {
  final formulario = GlobalKey<FormState>();
  final nome = TextEditingController();
  final contato = TextEditingController();
  bool enviando = false;

  @override
  void dispose() {
    nome.dispose();
    contato.dispose();
    super.dispose();
  }

  Future<void> enviar() async {
    if (!formulario.currentState!.validate()) return;
    setState(() => enviando = true);
    try {
      final resposta = await http
          .post(
            apiBase.replace(path: '/solicitacoes'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'animal_id': widget.animal['id'],
              'nome_interessado': nome.text.trim(),
              'contato': contato.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (resposta.statusCode == 201 && mounted) {
        Navigator.of(context).pop(true);
      } else {
        final mensagem = corpo is Map ? corpo['erro'] : null;
        throw Exception(mensagem ?? 'A API retornou o código ${resposta.statusCode}.');
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível enviar: $erro')));
        setState(() => enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Quero adotar ${widget.animal['nome']}'),
        content: Form(
          key: formulario,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Seu nome'),
              validator: (valor) => valor == null || valor.trim().isEmpty ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: contato,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail ou telefone'),
              validator: (valor) => valor == null || valor.trim().isEmpty ? 'Informe um contato.' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: enviando ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: enviando ? null : enviar, child: enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar pedido')),
        ],
      );
}
