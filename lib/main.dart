import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa a conexão com o Supabase
  await Supabase.initialize(
    url: 'https://tdekozirpwsudhcfohuh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkZWtvemlycHdzdWRoY2ZvaHVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NzczNDAsImV4cCI6MjEwNTA1MzM0MH0.OfcBokA3YuTrSDkbX_zOV1xp9zQOJfHqrm_bp8ypDTM',
  );
  // Executa o aplicativo Flutter
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WEBLISTA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        scaffoldBackgroundColor: Colors.grey.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(12),
            ),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const TelaListaCompras(),
    );
  }
}

class TelaListaCompras extends StatefulWidget {
  const TelaListaCompras({super.key});

  @override
  State<TelaListaCompras> createState() => _TelaListaComprasState();
}

class _TelaListaComprasState extends State<TelaListaCompras> {
  final txtNome = TextEditingController();
  final txtQuantidade = TextEditingController();

  String categoriaSelecionada = 'Outros';
  String listaSelecionada = 'Pendentes';

  final List<String> categorias = [
    'Hortifruti',
    'Carnes',
    'Laticínios',
    'Mercearia',
    'Limpeza',
    'Higiene',
    'Bebidas',
    'Outros',
  ];

  int? idItemEmEdicao;
  bool salvando = false;

  late final Stream<List<Map<String, dynamic>>> streamDosItens;

  @override
  void initState() {
    super.initState();

    // LER:
    // Cria um Stream para acompanhar os dados da tabela em tempo real.
    streamDosItens = supabase
        .from('itens_compra')
        .stream(primaryKey: ['id']).order('id', ascending: true);
  }

  @override
  void dispose() {
    txtNome.dispose();
    txtQuantidade.dispose();
    super.dispose();
  }

  // INSERIR E ATUALIZAR
  Future<void> salvarOuAtualizarItem() async {
    // Pega o nome digitado pelo usuário.
    final nome = txtNome.text.trim();

    // Converte a quantidade digitada para um número inteiro.
    final quantidade = int.tryParse(txtQuantidade.text.trim());

    // Verifica se o nome e a quantidade são válidos.
    if (nome.isEmpty || quantidade == null || quantidade <= 0) {
      mostrarMensagem('Digite um nome e uma quantidade válida.');
      return;
    }

    // Indica que uma operação está sendo realizada.
    setState(() {
      salvando = true;
    });

    try {
      // Quando não existe um ID, significa que será inserido um novo item.
      if (idItemEmEdicao == null) {
        // INSERIR:
        // Adiciona um novo registro na tabela itens_compra.
        await supabase.from('itens_compra').insert({
          'nome': nome,
          'quantidade': quantidade,
          'categoria': categoriaSelecionada,
          'comprado': false,
        });

        mostrarMensagem('Item adicionado com sucesso!');
      } else {
        // ATUALIZAR:
        // Modifica os dados do item que possui o ID informado.
        await supabase.from('itens_compra').update({
          'nome': nome,
          'quantidade': quantidade,
          'categoria': categoriaSelecionada,
        }).eq('id', idItemEmEdicao!);

        mostrarMensagem('Item atualizado com sucesso!');
      }

      // Limpa os campos depois da operação.
      limparCampos();
    } catch (e) {
      // Exibe uma mensagem caso ocorra algum erro.
      mostrarMensagem('Erro ao salvar item: $e');
    } finally {
      // Libera o botão após finalizar a operação.
      setState(() {
        salvando = false;
      });
    }
  }

  // ATUALIZAR STATUS DO ITEM
  Future<void> alternarComprado(Map<String, dynamic> item) async {
    // Verifica se o item está marcado como comprado.
    final compradoAtual = item['comprado'] == true;

    // ATUALIZAR:
    // Inverte o valor do campo comprado no registro selecionado.
    await supabase.from('itens_compra').update({
      'comprado': !compradoAtual,
    }).eq('id', item['id']);
  }

  // DELETAR
  Future<void> excluirItem(Map<String, dynamic> item) async {
    // Abre uma janela para confirmar a exclusão.
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir item'),
          content: Text(
            'Deseja realmente excluir "${item['nome']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    // Se o usuário cancelar, a função termina.
    if (confirmar != true) {
      return;
    }

    try {
      // DELETAR:
      // Remove da tabela o registro que possui o ID informado.
      await supabase.from('itens_compra').delete().eq('id', item['id']);

      // Se o item excluído estava em edição, limpa os campos.
      if (idItemEmEdicao == item['id']) {
        limparCampos();
      }

      mostrarMensagem('Item excluído com sucesso!');
    } catch (e) {
      // Exibe uma mensagem caso ocorra algum erro.
      mostrarMensagem('Erro ao excluir item: $e');
    }
  }

  // PREPARAR ATUALIZAÇÃO
  void prepararEdicao(Map<String, dynamic> item) {
    // Preenche o campo nome com o valor do item selecionado.
    txtNome.text = item['nome'];

    // Preenche o campo quantidade com o valor do item selecionado.
    txtQuantidade.text = item['quantidade'].toString();

    // Guarda o ID do item que será atualizado.
    idItemEmEdicao = item['id'];

    // Seleciona a categoria atual do item.
    categoriaSelecionada = item['categoria'];

    // Atualiza a tela.
    setState(() {});
  }

  void limparCampos() {
    txtNome.clear();
    txtQuantidade.clear();

    setState(() {
      idItemEmEdicao = null;
      categoriaSelecionada = 'Outros';
    });
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shopping_basket),
            SizedBox(width: 8),
            Text('WEBLISTA'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '⚡ Rápido e Fácil 🛒',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: txtNome,
              decoration: const InputDecoration(
                labelText: 'Nome do item',
                prefixIcon: Icon(Icons.shopping_cart_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: txtQuantidade,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categoriaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categorias.map((categoria) {
                return DropdownMenuItem<String>(
                  value: categoria,
                  child: Text(categoria),
                );
              }).toList(),
              onChanged: (valor) {
                setState(() {
                  categoriaSelecionada = valor!;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: salvando ? null : salvarOuAtualizarItem,
                    icon: Icon(
                      idItemEmEdicao == null ? Icons.add : Icons.edit,
                    ),
                    label: Text(
                      idItemEmEdicao == null ? 'Adicionar' : 'Atualizar',
                    ),
                  ),
                ),
                if (idItemEmEdicao != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: limparCampos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text('Cancelar'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        listaSelecionada = 'Pendentes';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: listaSelecionada == 'Pendentes'
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    child: const Text('A Comprar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        listaSelecionada = 'Comprados';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: listaSelecionada == 'Comprados'
                          ? Colors.green
                          : Colors.grey,
                    ),
                    child: const Text('No Carrinho'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: streamDosItens,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro ao carregar itens: ${snapshot.error}',
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final itens = snapshot.data!.where((item) {
                    final comprado = item['comprado'] == true;

                    if (listaSelecionada == 'Pendentes') {
                      return !comprado;
                    }

                    return comprado;
                  }).toList();

                  if (itens.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            listaSelecionada == 'Pendentes'
                                ? Icons.shopping_cart_outlined
                                : Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            listaSelecionada == 'Pendentes'
                                ? 'Nenhum item pendente'
                                : 'Nenhum item comprado',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      return _buildItemTile(itens[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final bool comprado = item['comprado'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ElevatedButton(
          onPressed: () async {
            await alternarComprado(item);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                comprado ? Colors.green.shade600 : Colors.orange.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(
            comprado ? Icons.check : Icons.shopping_cart_outlined,
            size: 24,
          ),
        ),
        title: Text(
          item['nome'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: comprado ? TextDecoration.lineThrough : null,
            color: comprado ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          'Quantidade: ${item['quantidade']} | Categoria: ${item['categoria']}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () {
                prepararEdicao(item);
              },
              icon: const Icon(Icons.edit_note),
              color: Colors.blue,
            ),
            IconButton(
              onPressed: () {
                excluirItem(item);
              },
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
