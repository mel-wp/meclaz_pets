import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CadastroAnimalPage extends StatefulWidget {
  final Uri endereco;

  const CadastroAnimalPage({
    super.key,
    required this.endereco,
  });

  @override
  State<CadastroAnimalPage> createState() => _CadastroAnimalPageState();
}

class _CadastroAnimalPageState extends State<CadastroAnimalPage> {
  final formulario = GlobalKey<FormState>();
  final nome = TextEditingController();
  final especie = TextEditingController();
  final idade = TextEditingController();

  bool salvando = false;
  String? mensagemErro;

  @override
  void dispose() {
    nome.dispose();
    especie.dispose();
    idade.dispose();
    super.dispose();
  }

  Future<void> salvarAnimal() async {
    if (salvando || !formulario.currentState!.validate()) return;

    setState(() {
      salvando = true;
      mensagemErro = null;
    });

    try {
      final resposta = await http.post(
        widget.endereco,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'nome': nome.text.trim(),
          'especie': especie.text.trim(),
          'idade_em_meses': int.parse(idade.text.trim()),
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 201) {
        // Avisa à primeira página que ela deve atualizar a lista.
        Navigator.pop(context, true);
        return;
      }

      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      setState(() {
        mensagemErro = dados['erro'] ?? 'Não foi possível salvar o animal.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        mensagemErro = 'A resposta demorou. Confira a lista de animais '
            'antes de repetir o cadastro.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        mensagemErro = 'Não foi possível confirmar o cadastro. '
            'Confira se a API está rodando.';
      });
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar animal'),
        backgroundColor: const Color(0xFFFFE1EB),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                color: const Color(0xFFFFF9F5),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nome,
                          enabled: !salvando,
                          maxLength: 100,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome do animal',
                            hintText: 'Ex.: Pipoca',
                            prefixIcon: Icon(Icons.pets),
                          ),
                          validator: (valor) {
                            if (valor == null || valor.trim().isEmpty) {
                              return 'Informe o nome do animal.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: especie,
                          enabled: !salvando,
                          maxLength: 50,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Espécie',
                            hintText: 'Ex.: Gato, cachorro ou coelho',
                          ),
                          validator: (valor) {
                            if (valor == null || valor.trim().isEmpty) {
                              return 'Informe a espécie.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: idade,
                          enabled: !salvando,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Idade em meses',
                            hintText: 'Ex.: 8',
                          ),
                          validator: (valor) {
                            final meses = int.tryParse(valor?.trim() ?? '');
                            if (meses == null || meses < 0) {
                              return 'Digite um número inteiro a partir de zero.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (mensagemErro != null) ...[
                          Text(
                            mensagemErro!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: salvando ? null : salvarAnimal,
                          icon: const Icon(Icons.pets),
                          label: Text(
                            salvando ? 'Salvando…' : 'Salvar animal',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}