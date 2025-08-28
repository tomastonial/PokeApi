import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      home: const PokedexPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Pokemon {
  final String nome; // ex.: "bulbasaur"
  final int id; // número na Pokédex
  final String imageUrl; // url da imagem

  Pokemon({required this.nome, required this.id, required this.imageUrl});

  // monta a partir do item da LISTA: { name, url }
  factory Pokemon.fromListItem(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final detailUrl = json['url'] as String; // .../pokemon/1/
    // pega o ID do final da URL
    final id = int.parse(detailUrl.split('/').where((s) => s.isNotEmpty).last);

    // imagem maior "official-artwork"; se falhar, dá pra trocar pra /sprites/pokemon/$id.png
    final img =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

    return Pokemon(nome: name, id: id, imageUrl: img);
  }

  String get nomeCap =>
      nome.isEmpty ? nome : '${nome[0].toUpperCase()}${nome.substring(1)}';
}

class PokedexPage extends StatefulWidget {
  const PokedexPage({super.key});

  @override
  State<PokedexPage> createState() => _PokedexPageState();
}

class _PokedexPageState extends State<PokedexPage> {
  final _dio = Dio();
  final _searchCtrl = TextEditingController();

  List<Pokemon> _all = [];
  List<Pokemon> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      _applyFilter(_searchCtrl.text);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get(
        'https://pokeapi.co/api/v2/pokemon',
        queryParameters: {'limit': 151, 'offset': 0},
      );

      final results = List<Map<String, dynamic>>.from(res.data['results']);
      final pokes = results.map((e) => Pokemon.fromListItem(e)).toList();

      setState(() {
        _all = pokes;
        _filtered = pokes;
        _loading = false;
      });
    } catch (e) {
      setState(() {});
    }
  }

  void _applyFilter(String text) {
    final q = text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all
            .where((p) => p.nome.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pokédex do Guri'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar pokémon por nome',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: (_searchCtrl.text.isEmpty)
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter('');
                          FocusScope.of(context).unfocus();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum resultado para: "${_searchCtrl.text}".',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        return ListTile(
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.network(
                              p.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_not_supported),
                            ),
                          ),
                          title: Text(p.nomeCap),
                          subtitle: Text('#${p.id}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // só um "detalhezinho" rápido
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(p.nomeCap),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(p.imageUrl, height: 120),
                                    const SizedBox(height: 12),
                                    Text('Número na Pokédex: #${p.id}'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
