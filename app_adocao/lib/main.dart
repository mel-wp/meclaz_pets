import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Para o emulador com adb reverse, use API_HOST=127.0.0.1.
const apiHost = String.fromEnvironment('API_HOST', defaultValue: '10.0.2.2');

final apiBase = Uri(scheme: 'http', host: apiHost, port: 8080);

const rosa = Color(0xFFD85B9A);
const rosaClaro = Color(0xFFFFE5F0);
const texto = Color(0xFF492B31);
const fundo = Color(0xFFFFF5F8);

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
          seedColor: rosa,
          primary: rosa,
          secondary: const Color(0xFFAC3563),
        ),
        scaffoldBackgroundColor: fundo,
        appBarTheme: const AppBarTheme(
          backgroundColor: fundo,
          foregroundColor: texto,
        ),
      ),
      home: const AppPrincipal(),
    );
  }
}

class AppPrincipal extends StatefulWidget {
  const AppPrincipal({super.key});

  @override
  State<AppPrincipal> createState() => _AppPrincipalState();
}

class _AppPrincipalState extends State<AppPrincipal> {
  int abaSelecionada = 0;
  String? token;
  String? nomeAdmin;
  int atualizacaoAnimais = 0;

  void entrar(String novoToken, String nome) {
    setState(() {
      token = novoToken;
      nomeAdmin = nome;
    });
  }

  void sair() {
    setState(() {
      token = null;
      nomeAdmin = null;
    });
  }

  void atualizarAnimais() {
    setState(() => atualizacaoAnimais++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: abaSelecionada,
          children: [
            AnimaisPage(chaveAtualizacao: atualizacaoAnimais),
            AdministracaoPage(
              token: token,
              nomeAdmin: nomeAdmin,
              onLogin: entrar,
              onLogout: sair,
              onAnimalCadastrado: atualizarAnimais,
            ),
            const DocumentacaoApiPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: abaSelecionada,
        onDestinationSelected: (indice) {
          setState(() => abaSelecionada = indice);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Animais',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Administração',
          ),
          NavigationDestination(icon: Icon(Icons.code), label: 'API'),
        ],
      ),
    );
  }
}

// ---------------- ANIMAIS ----------------

class AnimaisPage extends StatefulWidget {
  const AnimaisPage({super.key, required this.chaveAtualizacao});

  final int chaveAtualizacao;

  @override
  State<AnimaisPage> createState() => _AnimaisPageState();
}

class _AnimaisPageState extends State<AnimaisPage> {
  late Future<List<Map<String, dynamic>>> consulta;

  @override
  void initState() {
    super.initState();
    consulta = buscarAnimais();
  }

  @override
  void didUpdateWidget(covariant AnimaisPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chaveAtualizacao != widget.chaveAtualizacao) {
      atualizarLista();
    }
  }

  Future<List<Map<String, dynamic>>> buscarAnimais() async {
    final resposta = await http
        .get(
          apiBase.replace(
            path: '/animais',
            queryParameters: {'disponivel': 'true'},
          ),
        )
        .timeout(const Duration(seconds: 10));

    if (resposta.statusCode != 200) {
      throw Exception('Erro ${resposta.statusCode} ao buscar animais.');
    }

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));

    if (dados is! List) {
      throw const FormatException('Resposta inválida da API.');
    }

    return dados.cast<Map<String, dynamic>>();
  }

  void atualizarLista() {
    setState(() => consulta = buscarAnimais());
  }

  Future<void> solicitarAdocao(Map<String, dynamic> animal) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => SolicitacaoDialog(animal: animal),
    );

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido enviado com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets, color: rosa),
              const SizedBox(width: 8),
              const Text(
                'Meclaz Pets',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: texto,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: atualizarLista,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'Encontre seu novo amigo!',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: texto,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Animais disponíveis para adoção 🐾',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: consulta,
              builder: (context, resultado) {
                if (resultado.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (resultado.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 42),
                        const SizedBox(height: 10),
                        const Text(
                          'Não foi possível carregar os animais.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
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
                    child: Text('Nenhum animal disponível no momento.'),
                  );
                }

                return ListView.separated(
                  itemCount: animais.length,
                  padding: const EdgeInsets.only(bottom: 20),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, indice) {
                    final animal = animais[indice];
                    final idade = animal['idade_em_meses'];
                    final unidade = idade == 1 ? 'mês' : 'meses';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: indice.isEven
                            ? rosaClaro
                            : const Color(0xFFFFEAF1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.pets, color: rosa),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${animal['nome']}',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: texto,
                                  ),
                                ),
                                Text(
                                  '${animal['especie']} • $idade $unidade',
                                  style: const TextStyle(color: texto),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => solicitarAdocao(animal),
                            child: const Text('Adotar'),
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
    );
  }
}

// ---------------- SOLICITAÇÃO DE ADOÇÃO ----------------

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
        throw Exception(
          corpo is Map ? corpo['erro'] : 'Erro ao enviar solicitação.',
        );
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar: $erro')),
        );
        setState(() => enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quero adotar ${widget.animal['nome']}'),
      content: Form(
        key: formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Seu nome'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: contato,
              decoration: const InputDecoration(
                labelText: 'E-mail ou telefone',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe um contato.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: enviando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: enviando ? null : enviar,
          child: enviando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar pedido'),
        ),
      ],
    );
  }
}

// ---------------- ADMINISTRAÇÃO ----------------

class AdministracaoPage extends StatelessWidget {
  const AdministracaoPage({
    super.key,
    required this.token,
    required this.nomeAdmin,
    required this.onLogin,
    required this.onLogout,
    required this.onAnimalCadastrado,
  });

  final String? token;
  final String? nomeAdmin;
  final Function(String, String) onLogin;
  final VoidCallback onLogout;
  final VoidCallback onAnimalCadastrado;

  @override
  Widget build(BuildContext context) {
    if (token == null) {
      return LoginPage(onLogin: onLogin);
    }

    return CadastroAnimalPage(
      token: token!,
      nomeAdmin: nomeAdmin ?? 'Administrador',
      onLogout: onLogout,
      onAnimalCadastrado: onAnimalCadastrado,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final Function(String, String) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final senha = TextEditingController();
  bool carregando = false;
  bool mostrarSenha = false;

  @override
  void dispose() {
    email.dispose();
    senha.dispose();
    super.dispose();
  }

  Future<void> fazerLogin() async {
    if (email.text.trim().isEmpty || senha.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu e-mail e sua senha.')),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      final resposta = await http
          .post(
            apiBase.replace(path: '/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.text.trim(), 'senha': senha.text}),
          )
          .timeout(const Duration(seconds: 10));

      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));

      if (resposta.statusCode == 200) {
        final usuario = dados['usuario'];

        widget.onLogin(dados['token'], usuario['nome']);
      } else {
        throw Exception(
          dados is Map ? dados['erro'] : 'Não foi possível entrar.',
        );
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha no login: $erro')));
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const Icon(Icons.admin_panel_settings, size: 65, color: rosa),
              const SizedBox(height: 14),
              const Text(
                'Área administrativa',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: texto,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entre com sua conta de administrador.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: senha,
                obscureText: !mostrarSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => mostrarSenha = !mostrarSenha);
                    },
                    icon: Icon(
                      mostrarSenha ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                onSubmitted: (_) => fazerLogin(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: carregando ? null : fazerLogin,
                  child: carregando
                      ? const CircularProgressIndicator()
                      : const Text('Entrar'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Acesso exclusivo para administradores cadastrados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- CADASTRO DE ANIMAIS ----------------

class CadastroAnimalPage extends StatefulWidget {
  const CadastroAnimalPage({
    super.key,
    required this.token,
    required this.nomeAdmin,
    required this.onLogout,
    required this.onAnimalCadastrado,
  });

  final String token;
  final String nomeAdmin;
  final VoidCallback onLogout;
  final VoidCallback onAnimalCadastrado;

  @override
  State<CadastroAnimalPage> createState() => _CadastroAnimalPageState();
}

class _CadastroAnimalPageState extends State<CadastroAnimalPage> {
  final nome = TextEditingController();
  final especie = TextEditingController();
  final idade = TextEditingController();
  final formulario = GlobalKey<FormState>();
  bool carregando = false;

  @override
  void dispose() {
    nome.dispose();
    especie.dispose();
    idade.dispose();
    super.dispose();
  }

  Future<void> cadastrar() async {
    if (!formulario.currentState!.validate()) return;

    setState(() => carregando = true);

    try {
      final resposta = await http
          .post(
            apiBase.replace(path: '/animais'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.token}',
            },
            body: jsonEncode({
              'nome': nome.text.trim(),
              'especie': especie.text.trim(),
              'idade_em_meses': int.parse(idade.text.trim()),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));

      if (resposta.statusCode == 201) {
        nome.clear();
        especie.clear();
        idade.clear();
        widget.onAnimalCadastrado();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Animal cadastrado com sucesso!')),
          );
        }
      } else {
        throw Exception(
          dados is Map ? dados['erro'] : 'Erro ao cadastrar animal.',
        );
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível cadastrar: $erro')),
        );
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Painel administrativo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: texto,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sair',
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                Text('Olá, ${widget.nomeAdmin}!'),
                const SizedBox(height: 25),
                const Icon(Icons.add_circle_outline, size: 55, color: rosa),
                const SizedBox(height: 12),
                const Text(
                  'Cadastrar novo animal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: texto,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome do animal',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: especie,
                  decoration: const InputDecoration(
                    labelText: 'Espécie',
                    hintText: 'Ex.: Cachorro, Gato...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a espécie.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: idade,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Idade em meses',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final valor = int.tryParse(v ?? '');
                    if (valor == null || valor < 0) {
                      return 'Informe uma idade válida em meses.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: carregando ? null : cadastrar,
                  icon: const Icon(Icons.pets),
                  label: carregando
                      ? const CircularProgressIndicator()
                      : const Text('Cadastrar animal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- DOCUMENTAÇÃO DA API ----------------

class DocumentacaoApiPage extends StatelessWidget {
  const DocumentacaoApiPage({super.key});

  Widget endpoint(String metodo, String rota, String descricao) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: rosaClaro,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    metodo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: texto,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    rota,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(descricao),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.code, size: 55, color: rosa),
        const SizedBox(height: 10),
        const Text(
          'Documentação da API',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Utilize a API do Meclaz Pets para integrar funcionalidades '
          'de adoção de animais em outros aplicativos.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const Text(
          'Endereço base (ambiente local)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SelectableText('http://127.0.0.1:8080'),
        const SizedBox(height: 18),
        const Text(
          'Endpoints disponíveis',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: texto,
          ),
        ),
        endpoint('GET', '/animais', 'Retorna todos os animais cadastrados.'),
        endpoint(
          'GET',
          '/animais?disponivel=true',
          'Retorna somente os animais disponíveis para adoção.',
        ),
        endpoint(
          'POST',
          '/login',
          'Recebe email e senha do administrador. Retorna um token '
              'de autenticação válido por 8 horas.',
        ),
        endpoint(
          'POST',
          '/animais',
          'Cadastra um animal. Exige token de administrador no '
              'cabeçalho Authorization: Bearer.',
        ),
        endpoint(
          'POST',
          '/solicitacoes',
          'Registra uma solicitação de adoção. Recebe animal_id, '
              'nome_interessado e contato.',
        ),
        const SizedBox(height: 15),
        const Text(
          'Exemplo de cadastro de animal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: rosaClaro,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SelectableText(
            '{\n'
            '  "nome": "Bob",\n'
            '  "especie": "Cachorro",\n'
            '  "idade_em_meses": 24\n'
            '}',
            style: TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Autenticação',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Para cadastrar animais, primeiro realize o login. '
          'Utilize o token recebido no cabeçalho Authorization. '
          'As rotas de consulta e solicitação de adoção são públicas.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Observação: o endereço apresentado é para testes locais. '
          'Para outros desenvolvedores acessarem a API pela internet, '
          'será necessário publicar o serviço em um servidor online.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}
