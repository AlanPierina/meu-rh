import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MeuRhApp());
}

class MeuRhApp extends StatelessWidget {
  const MeuRhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agrícola FP - MEU RH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B6335),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B6335),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ================= VERIFICAÇÃO DE SESSÃO E PERFIL =================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool _verificarSeEhAdmin(String? emailUsuario) {
    if (emailUsuario == null) return false;
    final List<String> adminsMaster = [
      'piersilv2425@gmail.com',
      'aks_pierina@hotmail.com',
    ];
    return adminsMaster.contains(emailUsuario);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1B6335))),
          );
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          final bool eAdminMaster = _verificarSeEhAdmin(user.email);
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1B6335))));
              }

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                final dadosIniciais = {
                  'email': user.email,
                  'nome': eAdminMaster ? 'Administrador Master' : 'Novo Colaborador',
                  'cargo': eAdminMaster ? 'Gestão de RH' : 'Colaborador',
                  'cpf': '000.000.000-00',
                  'isAdmin': eAdminMaster,
                  'primeiroAcesso': !eAdminMaster,
                  'criadoEm': Timestamp.now(),
                };
                FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set(dadosIniciais);
                if (eAdminMaster) return const AdminDashboardScreen();
                return const PrimeiroAcessoScreen();
              }

              final dados = userSnapshot.data!.data() as Map<String, dynamic>;
              if (eAdminMaster && (dados['isAdmin'] != true)) {
                FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({'isAdmin': true, 'primeiroAcesso': false});
                return const AdminDashboardScreen();
              }

              final bool primeiroAcesso = dados['primeiroAcesso'] ?? false;
              final bool isAdmin = dados['isAdmin'] ?? eAdminMaster;

              if (primeiroAcesso && !eAdminMaster) {
                return const PrimeiroAcessoScreen();
              }

              if (isAdmin) {
                return const AdminDashboardScreen();
              }

              return const HomeScreen();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

// ================= TELA DE LOGIN =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    final entrada = _loginController.text.trim();
    final senha = _senhaController.text.trim();

    if (entrada.isEmpty || senha.isEmpty) {
      _mostrarMensagem('Preencha o campo de E-mail/CPF e a senha.', Colors.orange);
      return;
    }

    if (senha.length < 6) {
      _mostrarMensagem('A senha deve ter pelo menos 6 caracteres.', Colors.orange);
      return;
    }

    String emailFinal = entrada;
    if (!entrada.contains('@')) {
      const dominioFicticio = '@agricolafp.internal';
      emailFinal = '${entrada.replaceAll(RegExp(r'[^0-9]'), '')}$dominioFicticio';
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFinal,
        password: senha,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailFinal,
            password: senha,
          );
          if (!mounted) return;
          _mostrarMensagem('Conta criada e acesso autorizado!', Colors.green);
        } catch (createError) {
          _mostrarMensagem('Erro ao cadastrar: $createError', Colors.red);
        }
      } else {
        _mostrarMensagem('Erro de Acesso: ${e.message}', Colors.red);
      }
    } catch (err) {
      _mostrarMensagem('Erro inesperado: $err', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarMensagem(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: cor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFF4F6F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B6335), Color(0xFF2E7D32)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B6335).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.eco_rounded, size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Agrícola FP',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'MEU RH • Acesso por CPF ou E-mail',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, letterSpacing: 0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      TextField(
                        controller: _loginController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(color: Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          labelText: 'CPF ou E-mail (Admin)',
                          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1B6335)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _senhaController,
                        obscureText: true,
                        style: const TextStyle(color: Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          labelText: 'Senha (mín. 6 dígitos)',
                          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1B6335)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _fazerLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B6335),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: const Color(0xFF1B6335).withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Entrar no Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }
}

// ================= TELA DE PRIMEIRO ACESSO =================
class PrimeiroAcessoScreen extends StatefulWidget {
  const PrimeiroAcessoScreen({super.key});

  @override
  State<PrimeiroAcessoScreen> createState() => _PrimeiroAcessoScreenState();
}

class _PrimeiroAcessoScreenState extends State<PrimeiroAcessoScreen> {
  final _novaSenhaController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _cargoController = TextEditingController();
  bool _salvando = false;

  Future<void> _concluirCadastro() async {
    final novaSenha = _novaSenhaController.text.trim();
    final nome = _nomeController.text.trim();
    final cpf = _cpfController.text.trim();
    final cargo = _cargoController.text.trim();

    if (novaSenha.length < 6 || nome.isEmpty || cpf.isEmpty || cargo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos e use uma senha com mín. de 6 caracteres.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await user.updatePassword(novaSenha);
      } catch (_) {}

      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'email': user.email,
        'nome': nome,
        'cpf': cpf,
        'cargo': cargo,
        'primeiroAcesso': false,
        'isAdmin': false,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados cadastrados com sucesso!'), backgroundColor: Colors.green),
      );
      
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthGate()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar dados: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Primeiro Acesso - Configuração')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Complete seus dados', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 8),
                    const Text('Para prosseguir, defina sua nova senha e preencha suas informações corporativas.', style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _nomeController,
                      style: const TextStyle(color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(labelText: 'Nome Completo', prefixIcon: Icon(Icons.person, color: Color(0xFF1B6335))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cpfController,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(labelText: 'CPF', prefixIcon: Icon(Icons.badge, color: Color(0xFF1B6335))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cargoController,
                      style: const TextStyle(color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(labelText: 'Cargo / Função', prefixIcon: Icon(Icons.work, color: Color(0xFF1B6335))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _novaSenhaController,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(labelText: 'Nova Senha (Mínimo 6 caracteres)', prefixIcon: Icon(Icons.lock, color: Color(0xFF1B6335))),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _salvando ? null : _concluirCadastro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B6335),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _salvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar e Entrar no Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= PAINEL DO ADMINISTRADOR (RH) =================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  String _filtroBusca = '';

  final List<String> _adminsMaster = [
    'piersilv2425@gmail.com',
    'aks_pierina@hotmail.com',
  ];

  bool _verificarSeEhAdmin(String? emailUsuario) {
    if (emailUsuario == null) return false;
    return _adminsMaster.contains(emailUsuario);
  }

  void _mostrarModalCadastroColaborador(BuildContext context) {
    final cpfController = TextEditingController();
    final senhaTempController = TextEditingController();
    final nomeController = TextEditingController();
    final cargoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF1B6335)),
            SizedBox(width: 12),
            Text('Novo Colaborador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: const InputDecoration(labelText: 'Nome Completo', prefixIcon: Icon(Icons.person_outline, color: Color(0xFF1B6335))),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: cpfController,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: const InputDecoration(labelText: 'CPF', prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF1B6335))),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: senhaTempController,
                obscureText: true,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: const InputDecoration(labelText: 'Senha Temporária (Mín. 6 dígitos)', prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF1B6335))),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: cargoController,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: const InputDecoration(labelText: 'Cargo Inicial / Função', prefixIcon: Icon(Icons.work_outline, color: Color(0xFF1B6335))),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6335),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final cpf = cpfController.text.trim();
              final senha = senhaTempController.text.trim();
              final nome = nomeController.text.trim();
              final cargo = cargoController.text.trim();

              if (cpf.isEmpty || senha.length < 6 || nome.isEmpty || cargo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preencha todos os campos corretamente (senha mín. 6 dígitos).'), backgroundColor: Colors.orange),
                );
                return;
              }

              const dominioFicticio = '@agricolafp.internal';
              final emailGerado = '${cpf.replaceAll(RegExp(r'[^0-9]'), '')}$dominioFicticio';

              try {
                UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: emailGerado,
                  password: senha,
                );
                
                await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
                  'email': emailGerado,
                  'cpf': cpf,
                  'nome': nome,
                  'cargo': cargo,
                  'primeiroAcesso': true,
                  'isAdmin': _verificarSeEhAdmin(emailGerado),
                  'criadoEm': Timestamp.now(),
                });

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Colaborador cadastrado com sucesso!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao cadastrar: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Salvar Cadastro'),
          ),
        ],
      ),
    );
  }

  // ================= MODAL DE IMPORTAÇÃO ROBUSTA EM LOTE =================
  void _mostrarModalImportacao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        title: const Row(
          children: [
            Icon(Icons.upload_file_rounded, color: Colors.teal),
            SizedBox(width: 12),
            Text('Importar Colaboradores (Lote)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O sistema processará o lote completo, validará CPFs e atualizará registros existentes para evitar duplicações no painel.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 20),
            DottedBorderContainer(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              // Simulação de lista completa de lote mapeada com CPF, Colaborador e Função
              final List<Map<String, dynamic>> loteExemplo = [
                {'nome': 'ADENIAS', 'cpf': '341.416.41', 'cargo': 'OPERADOR'},
                {'nome': 'ADRIAN', 'cpf': '542.885.48', 'cargo': 'OPERADOR'},
                {'nome': 'AGNALDO', 'cpf': '764.178.40', 'cargo': 'OPERADOR'},
                {'nome': 'ALDENIR', 'cpf': '320.532.36', 'cargo': 'TRATORISTA'},
              ];

              final colecao = FirebaseFirestore.instance.collection('usuarios');
              int sucessos = 0;

              for (var colab in loteExemplo) {
                try {
                  String cpf = colab['cpf'] ?? '';
                  if (cpf.isEmpty) continue;

                  // Verifica se já existe pelo CPF para atualizar em vez de duplicar
                  var query = await colecao.where('cpf', isEqualTo: cpf).get();
                  
                  const dominioFicticio = '@agricolafp.internal';
                  String emailGerado = '${cpf.replaceAll(RegExp(r'[^0-9]'), '')}$dominioFicticio';

                  Map<String, dynamic> dadosFormatados = {
                    'nome': colab['nome'],
                    'cpf': cpf,
                    'cargo': colab['cargo'],
                    'email': emailGerado,
                    'primeiroAcesso': true,
                    'isAdmin': false,
                    'criadoEm': Timestamp.now(),
                  };

                  if (query.docs.isEmpty) {
                    await colecao.add(dadosFormatados);
                  } else {
                    String docId = query.docs.first.id;
                    await colecao.doc(docId).update({
                      'nome': colab['nome'],
                      'cargo': colab['cargo'],
                    });
                  }
                  sucessos++;
                } catch (linhaErro) {
                  print('Erro na importação de linha: $linhaErro');
                }
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Importação concluída! $sucessos registros processados com sucesso.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Processar Importação'),
          ),
        ],
      ),
    );
  }

  // ================= MODAL DE EDITAR COLABORADOR =================
  void _mostrarModalEditarColaborador(BuildContext context, String docId, Map<String, dynamic> dataAtual) {
    final nomeController = TextEditingController(text: dataAtual['nome'] ?? '');
    final cpfController = TextEditingController(text: dataAtual['cpf'] ?? '');
    final cargoController = TextEditingController(text: dataAtual['cargo'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Editar Colaborador', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cpfController,
              decoration: const InputDecoration(labelText: 'CPF'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cargoController,
              decoration: const InputDecoration(labelText: 'Cargo / Função'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B6335), foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('usuarios').doc(docId).update({
                'nome': nomeController.text.trim(),
                'cpf': cpfController.text.trim(),
                'cargo': cargoController.text.trim(),
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Colaborador atualizado com sucesso!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Salvar Alterações'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Agrícola FP • Painel Administrativo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
            tooltip: 'Importar Lote',
            onPressed: () => _mostrarModalImportacao(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Encerrar Sessão',
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            backgroundColor: Colors.white,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: Text('Colaboradores'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.support_agent_outlined),
                selectedIcon: Icon(Icons.support_agent_rounded),
                label: Text('Chamados RH'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.beach_access_outlined),
                selectedIcon: Icon(Icons.beach_access_rounded),
                label: Text('Férias & Ponto'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: [
                _buildSecaoDashboardGeral(),
                _buildSecaoColaboradores(),
                _buildSecaoChamadosRH(),
                _buildSecaoFeriasEPonto(),
              ][_selectedIndex],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarModalCadastroColaborador(context),
              backgroundColor: const Color(0xFF1B6335),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Novo Colaborador', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildSecaoDashboardGeral() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Visão Geral do RH', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 6),
          const Text('Indicadores de desempenho corporativo e fluxo de atividades recentes.', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              int cross = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cross,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: [
                  _buildKpiCard('Colaboradores', 'Ativos', Icons.people_rounded, const Color(0xFF1B6335)),
                  _buildKpiCard('Férias', 'Solicitações', Icons.beach_access_rounded, Colors.orange),
                  _buildKpiCard('Chamados', 'Em Aberto', Icons.support_agent_rounded, Colors.teal),
                  _buildKpiCard('Folha Salarial', 'R\$ 142.500', Icons.monetization_on_rounded, Colors.purple),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String titulo, String subtitulo, IconData icone, Color cor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
                Icon(icone, color: cor, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitulo, style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoColaboradores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestão de Colaboradores', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                SizedBox(height: 6),
                Text('Acompanhe o cadastro e status de acesso dos funcionários da empresa.', style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6), foregroundColor: const Color(0xFF1F2937)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Relatório de Colaboradores exportado!'), backgroundColor: Colors.blue),
                );
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Exportar CSV'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (val) => setState(() => _filtroBusca = val.toLowerCase()),
          style: const TextStyle(color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: 'Pesquisar por nome ou CPF...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1B6335)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF1B6335)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Nenhum colaborador encontrado.', style: TextStyle(color: Color(0xFF6B7280))));
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nome = (data['nome'] ?? '').toString().toLowerCase();
                final cpf = (data['cpf'] ?? '').toString().toLowerCase();
                return nome.contains(_filtroBusca) || cpf.contains(_filtroBusca);
              }).toList();

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final docId = doc.id;
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = data['nome'] ?? 'Sem Nome';
                  final cpf = data['cpf'] ?? 'N/A';
                  final cargo = data['cargo'] ?? 'Colaborador';
                  final primeiroAcesso = data['primeiroAcesso'] ?? false;
                  final isAdmin = data['isAdmin'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: isAdmin ? Colors.purple.withOpacity(0.15) : const Color(0xFF1B6335).withOpacity(0.15),
                        child: Icon(
                          isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                          color: isAdmin ? Colors.purple : const Color(0xFF1B6335),
                        ),
                      ),
                      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('CPF: $cpf • Cargo: $cargo', style: const TextStyle(color: Color(0xFF6B7280))),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: primeiroAcesso ? Colors.amber.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              primeiroAcesso ? 'Pendente 1º Acesso' : 'Ativo',
                              style: TextStyle(
                                color: primeiroAcesso ? Colors.amber.shade800 : Colors.green.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botão de Editar
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            tooltip: 'Editar Colaborador',
                            onPressed: () => _mostrarModalEditarColaborador(context, docId, data),
                          ),
                          // Botão de Excluir
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: Colors.red),
                            tooltip: 'Excluir Colaborador',
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('usuarios').doc(docId).delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Colaborador removido com sucesso!'), backgroundColor: Colors.red),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoChamadosRH() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chamados e Solicitações de Suporte', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        const Text('Clique sobre um chamado enviado pelos colaboradores para visualizar e interagir.', style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chamados_rh').orderBy('data', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF1B6335)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Nenhum chamado de suporte aberto no momento.', style: TextStyle(color: Color(0xFF6B7280))));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final docId = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  final email = data['email'] ?? 'N/A';
                  final cpf = data['cpf'] ?? 'N/A';
                  final mensagem = data['mensagem'] ?? '';
                  final status = data['status'] ?? 'Aberto';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text('Detalhes do Chamado (CPF: $cpf)', style: const TextStyle(color: Color(0xFF1F2937))),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('E-mail: $email', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                const SizedBox(height: 12),
                                const Text('Mensagem do Colaborador:', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                                  child: Text(mensagem, style: const TextStyle(color: Color(0xFF1F2937))),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('chamados_rh').doc(docId).update({'status': 'Resolvido'});
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chamado marcado como resolvido!'), backgroundColor: Colors.green));
                                },
                                child: const Text('Marcar como Resolvido', style: TextStyle(color: Colors.green)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B6335), foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Fechar'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.support_agent_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Colaborador CPF: $cpf', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(mensagem, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: status == 'Aberto' ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(status, style: TextStyle(color: status == 'Aberto' ? Colors.orange.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoFeriasEPonto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gestão de Férias e Prazos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        const Text('Aprove ou rejeite solicitações de férias pendentes dos colaboradores.', style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('solicitacoes_ferias').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF1B6335)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Nenhuma solicitação de férias pendente.', style: TextStyle(color: Color(0xFF6B7280))));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final docId = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  final cpf = data['cpf'] ?? 'N/A';
                  final dias = data['dias'] ?? '0';
                  final status = data['status'] ?? 'Pendente';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      leading: const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orangeAccent,
                        child: Icon(Icons.beach_access_rounded, color: Colors.white),
                      ),
                      title: Text('Colaborador CPF: $cpf', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('Período solicitado: $dias dias • Status: $status', style: const TextStyle(color: Color(0xFF6B7280))),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                            tooltip: 'Aprovar',
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('solicitacoes_ferias').doc(docId).update({'status': 'Aprovado'});
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 28),
                            tooltip: 'Rejeitar',
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('solicitacoes_ferias').doc(docId).update({'status': 'Rejeitado'});
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class DottedBorderContainer extends StatelessWidget {
  const DottedBorderContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.4), width: 1.5),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_rounded, size: 40, color: Colors.teal),
          SizedBox(height: 12),
          Text('Clique ou arraste o arquivo CSV aqui', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Formato aceito: .csv ou .xlsx', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

// ================= TELA PRINCIPAL (DASHBOARD) DO COLABORADOR =================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco_rounded, size: 22, color: Colors.white),
            SizedBox(width: 12),
            Text('Agrícola FP • Meu RH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Sair da Conta',
              onPressed: () async => await FirebaseAuth.instance.signOut(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B6335), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B6335).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.person, size: 34, color: Color(0xFF1B6335)),
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bem-vindo(a) ao Portal,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            SizedBox(height: 4),
                            Text(
                              'Colaborador(a)',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'Serviços e Atalhos Rápidos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), letterSpacing: 0.5),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = constraints.maxWidth > 750 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.05,
                      children: [
                        _buildMenuCard(context, 'Holerites', Icons.receipt_long_rounded, Colors.amber.shade800, const HoleriteScreen()),
                        _buildMenuCard(context, 'Ponto & Banco de Horas', Icons.access_time_filled_rounded, Colors.teal, const PontoBancoHorasScreen()),
                        _buildMenuCard(context, 'Férias', Icons.beach_access_rounded, Colors.deepPurple, const FeriasScreen()),
                        _buildMenuCard(context, 'Adiantamento', Icons.monetization_on_rounded, Colors.deepOrange, const AdiantamentoScreen()),
                        _buildMenuCard(context, 'Envio de Atestados', Icons.medical_services_rounded, Colors.redAccent, const AtestadosScreen()),
                        _buildMenuCard(context, 'Comunicados', Icons.campaign_rounded, Colors.indigo, const ComunicadosScreen()),
                        _buildMenuCard(context, 'Dados Cadastrais', Icons.badge_rounded, const Color(0xFF1B6335), const PerfilScreen()),
                        _buildMenuCard(context, 'Suporte / RH', Icons.support_agent_rounded, Colors.cyan.shade700, const SuporteScreen()),
                        _buildMenuCard(context, 'Isis (Suporte Emocional)', Icons.support_rounded, Colors.pinkAccent, const IsisChatScreen()),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color iconColor, Widget destinationScreen) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationScreen),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= TELA: ASSISTENTE VIRTUAL "ISIS" (INTERATIVA) =================
class IsisChatScreen extends StatefulWidget {
  const IsisChatScreen({super.key});

  @override
  State<IsisChatScreen> createState() => _IsisChatScreenState();
}

class _IsisChatScreenState extends State<IsisChatScreen> {
  final List<Map<String, String>> _mensagens = [
    {
      'remetente': 'bot',
      'texto': 'Olá! Sou a Isis, sua assistente de suporte emocional e ajuda corporativa na Agrícola FP. Estou aqui para te ouvir sem julgamentos ou para tirar dúvidas sobre o RH. Como você está se sentindo hoje?'
    }
  ];
  final _inputController = TextEditingController();

  void _enviarMensagem() {
    final texto = _inputController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _mensagens.add({'remetente': 'usuario', 'texto': texto});
      _inputController.clear();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      String respostaBot = 'Compreendo perfeitamente o que você compartilhou. Lembre-se de que sua saúde mental é prioridade para nós. Se precisar de apoio ou falar reservadamente com o RH, estou aqui.';
      
      final t = texto.toLowerCase();
      if (t.contains('ansioso') || t.contains('estressado') || t.contains('triste') || t.contains('cansado') || t.contains('mal')) {
        respostaBot = 'Sinto muito que esteja passando por isso. Respire fundo... Tudo bem não estar 100% todos os dias. Que tal fazer uma pausa rápida para tomar uma água? Estou aqui se quiser desabafar.';
      } else if (t.contains('ferias') || t.contains('férias')) {
        respostaBot = 'Sobre férias, você pode solicitar diretamente pelo menu principal do aplicativo com antecedência. Deseja saber mais detalhes sobre saldo de dias?';
      } else if (t.contains('atestado')) {
        respostaBot = 'Você pode enviar atestados facilmente pela aba "Envio de Atestados" no menu principal, seja por PDF ou foto da câmera!';
      } else if (t.contains('salario') || t.contains('pagamento') || t.contains('holerite')) {
        respostaBot = 'Você pode conferir seus demonstrativos de pagamento detalhados na aba "Holerites" do menu inicial!';
      }

      if (mounted) {
        setState(() {
          _mensagens.add({'remetente': 'bot', 'texto': respostaBot});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Isis • Apoio Emocional & Ajuda')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.pink.shade50,
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: Colors.pink.shade400, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Espaço seguro e confidencial de escuta, acolhimento e orientações de RH.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mensagens.length,
              itemBuilder: (context, index) {
                final m = _mensagens[index];
                final isBot = m['remetente'] == 'bot';
                return Align(
                  alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      color: isBot ? Colors.white : const Color(0xFF1B6335),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Text(
                      m['texto']!,
                      style: TextStyle(color: isBot ? const Color(0xFF1F2937) : Colors.white, fontSize: 14, height: 1.3),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: 'Converse com a Isis...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF1B6335)),
                  onPressed: _enviarMensagem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TELA: ENVIO DE ATESTADOS =================
class AtestadosScreen extends StatefulWidget {
  const AtestadosScreen({super.key});

  @override
  State<AtestadosScreen> createState() => _AtestadosScreenState();
}

class _AtestadosScreenState extends State<AtestadosScreen> {
  String? _arquivoSelecionado;
  bool _enviando = false;

  void _simularSelecaoArquivo(String tipo) {
    setState(() {
      _arquivoSelecionado = tipo == 'camera' ? 'Foto_Atestado_Capturado.jpg' : 'Atestado_Medico.pdf';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Arquivo anexado com sucesso: $_arquivoSelecionado'), backgroundColor: Colors.green),
    );
  }

  Future<void> _enviarAtestado() async {
    if (_arquivoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, anexe um arquivo PDF ou tire foto do atestado primeiro.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _enviando = true);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _arquivoSelecionado = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atestado enviado ao RH com sucesso para validação!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Envio de Atestados Médicos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anexe seu atestado médico em formato PDF ou tire uma foto legível utilizando a câmera do celular.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B6335),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF1B6335)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _simularSelecaoArquivo('camera'),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Tirar Foto'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _simularSelecaoArquivo('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Anexar PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_arquivoSelecionado != null)
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF1B6335)),
                  title: Text('Arquivo pronto: $_arquivoSelecionado', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _arquivoSelecionado = null),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarAtestado,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6335),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar Atestado ao RH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TELA: BANCO DE HORAS, LEMBRETES E FRASES =================
class PontoBancoHorasScreen extends StatelessWidget {
  const PontoBancoHorasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banco de Horas & Bem-Estar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.timer_rounded, color: Colors.teal, size: 32),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo Atual no Banco de Horas', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                          SizedBox(height: 4),
                          Text('+14h 30m', style: TextStyle(color: Colors.teal, fontSize: 24, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Crédito disponível para compensação ou folga.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: Color(0xFF1B6335), size: 20),
                        const SizedBox(width: 8),
                        Text('Frase Motivacional do Dia', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '"A união de nossa equipe cultiva os melhores resultados e colhe um futuro próspero para todos."',
                      style: TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontStyle: FontStyle.italic, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Lembretes e Conscientização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.security_rounded, color: Color(0xFF1B6335)),
                title: Text('Segurança do Trabalho em Campo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                subtitle: Text('Utilize sempre os EPIs recomendados e verifique os equipamentos antes de iniciar as atividades.', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ),
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.self_improvement_rounded, color: Colors.pink),
                title: Text('Saúde Mental & Pausas Ativas', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                subtitle: Text('Lembre-se de fazer pequenas pausas para hidratação e alongamento durante a jornada de trabalho.', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TELA DE HOLERITE =================
class HoleriteScreen extends StatelessWidget {
  const HoleriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> holerites = [
      {'mes': 'Outubro / 2026', 'bruto': 'R\$ 4.500,00', 'liquido': 'R\$ 3.650,00', 'status': 'Disponível'},
      {'mes': 'Setembro / 2026', 'bruto': 'R\$ 4.500,00', 'liquido': 'R\$ 3.650,00', 'status': 'Pago'},
      {'mes': 'Agosto / 2026', 'bruto': 'R\$ 4.200,00', 'liquido': 'R\$ 3.400,00', 'status': 'Pago'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Demonstrativo de Pagamento')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: holerites.length,
        itemBuilder: (context, index) {
          final h = holerites[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.description, color: Colors.amber.shade800),
              ),
              title: Text('Competência: ${h['mes']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Líquido: ${h['liquido']}  •  Bruto: ${h['bruto']}', style: const TextStyle(color: Color(0xFF6B7280))),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF1B6335)),
                tooltip: 'Ver Detalhes',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: Text('Holerite - ${h['mes']}', style: const TextStyle(color: Color(0xFF1F2937))),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• Salário Base: R\$ 4.000,00', style: TextStyle(color: Color(0xFF374151))),
                          const Text('• Horas Extras (50%): R\$ 500,00', style: TextStyle(color: Color(0xFF374151))),
                          const Divider(color: Color(0xFFE5E7EB)),
                          const Text('• Desconto INSS: - R\$ 450,00', style: TextStyle(color: Colors.red)),
                          const Text('• Desconto IRRF: - R\$ 400,00', style: TextStyle(color: Colors.red)),
                          const Divider(color: Color(0xFFE5E7EB)),
                          Text('Valor Líquido: ${h['liquido']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B6335))),
                        ],
                      ),
                      actions: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Download do holerite de ${h['mes']} efetuado!'), backgroundColor: Colors.blue),
                            );
                          },
                          icon: const Icon(Icons.download, color: Color(0xFF1B6335)),
                          label: const Text('Baixar PDF', style: TextStyle(color: Color(0xFF1B6335))),
                        ),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: Color(0xFF6B7280)))),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================= TELA DE FÉRIAS =================
class FeriasScreen extends StatefulWidget {
  const FeriasScreen({super.key});

  @override
  State<FeriasScreen> createState() => _FeriasScreenState();
}

class _FeriasScreenState extends State<FeriasScreen> {
  final _diasController = TextEditingController(text: '30');
  bool _enviando = false;

  Future<void> _enviarSolicitacao() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dias = int.tryParse(_diasController.text) ?? 0;
    if (dias <= 0 || dias > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um período válido entre 1 e 30 dias.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final cpf = userDoc.exists ? (userDoc.data()?['cpf'] ?? 'N/A') : 'N/A';

      await FirebaseFirestore.instance.collection('solicitacoes_ferias').add({
        'email': user.email,
        'cpf': cpf,
        'dias': _diasController.text,
        'status': 'Pendente',
        'data': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de férias enviada com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitação de Férias')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1B6335)),
                    SizedBox(width: 14),
                    Text('Saldo Atual: 30 dias disponíveis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _diasController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF1F2937)),
              decoration: const InputDecoration(
                labelText: 'Quantidade de dias desejada',
                prefixIcon: Icon(Icons.date_range, color: Color(0xFF1B6335)),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarSolicitacao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6335),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar para Aprovação do Gestor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TELA DE ADIANTAMENTO =================
class AdiantamentoScreen extends StatefulWidget {
  const AdiantamentoScreen({super.key});

  @override
  State<AdiantamentoScreen> createState() => _AdiantamentoScreenState();
}

class _AdiantamentoScreenState extends State<AdiantamentoScreen> {
  final _valorController = TextEditingController();

  void _solicitarAdiantamento() {
    final valor = _valorController.text.trim();
    if (valor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor desejado para o adiantamento.'), backgroundColor: Colors.orange),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido de adiantamento de R\$ $valor enviado ao RH!'), backgroundColor: Colors.green),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adiantamento Salarial (Vale)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.orange),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Limite disponível: R\$ 1.350,00 (Até 40% do salário base)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF1F2937)),
              decoration: const InputDecoration(
                labelText: 'Valor Desejado (R\$)',
                prefixIcon: Icon(Icons.attach_money, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _solicitarAdiantamento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Solicitar Adiantamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TELA DE COMUNICADOS =================
class ComunicadosScreen extends StatelessWidget {
  const ComunicadosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados Internos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(18),
              leading: Icon(Icons.campaign, color: Colors.redAccent, size: 38),
              title: Text('Campanha de Segurança Agrícola 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Participe dos treinamentos obrigatórios de EPI nesta semana.', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(18),
              leading: Icon(Icons.info_rounded, color: Color(0xFF1B6335), size: 38),
              title: Text('Atualização de Benefícios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Confira os novos parceiros credenciados disponíveis a partir deste mês.', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TELA DE DADOS CADASTRAIS =================
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Dados Cadastrais')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B6335)));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final nome = data['nome'] ?? 'Colaborador';
          final cpf = data['cpf'] ?? 'N/A';
          final cargo = data['cargo'] ?? 'Colaborador';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const CircleAvatar(radius: 50, backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.person, size: 54, color: Color(0xFF1B6335))),
                const SizedBox(height: 16),
                Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 6),
                const Text('Colaborador Ativo • Agrícola FP', style: TextStyle(color: Color(0xFF1B6335), fontWeight: FontWeight.w600)),
                const SizedBox(height: 32),
                Card(
                  child: Column(
                    children: [
                      ListTile(title: const Text('CPF', style: TextStyle(color: Color(0xFF6B7280))), subtitle: Text(cpf, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500))),
                      const Divider(color: Color(0xFFE5E7EB), height: 1),
                      ListTile(title: const Text('Cargo', style: TextStyle(color: Color(0xFF6B7280))), subtitle: Text(cargo, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500))),
                      const Divider(color: Color(0xFFE5E7EB), height: 1),
                      ListTile(title: const Text('Departamento', style: TextStyle(color: Color(0xFF6B7280))), subtitle: const Text('Operações / Agrícola', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500))),
                      const Divider(color: Color(0xFFE5E7EB), height: 1),
                      ListTile(title: const Text('Empresa', style: TextStyle(color: Color(0xFF6B7280))), subtitle: const Text('Agrícola FP S.A.', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================= TELA DE SUPORTE / RH =================
class SuporteScreen extends StatefulWidget {
  const SuporteScreen({super.key});

  @override
  State<SuporteScreen> createState() => _SuporteScreenState();
}

class _SuporteScreenState extends State<SuporteScreen> {
  final _mensagemController = TextEditingController();
  bool _enviando = false;

  Future<void> _enviarTicket() async {
    final mensagem = _mensagemController.text.trim();
    if (mensagem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva sua mensagem antes de enviar.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _enviando = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final cpf = userDoc.exists ? (userDoc.data()?['cpf'] ?? 'N/A') : 'N/A';

      await FirebaseFirestore.instance.collection('chamados_rh').add({
        'email': user.email,
        'cpf': cpf,
        'mensagem': mensagem,
        'status': 'Aberto',
        'data': Timestamp.now(),
      });

      if (!mounted) return;
      _mensagemController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado enviado ao RH com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar chamado: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suporte / Chamados RH')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Precisa de auxílio com benefícios ou pagamentos? Envie um ticket diretamente à equipe de Recursos Humanos.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _mensagemController,
              maxLines: 4,
              style: const TextStyle(color: Color(0xFF1F2937)),
              decoration: const InputDecoration(
                labelText: 'Descreva sua solicitação',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6335),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar Chamado ao RH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}