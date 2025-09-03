import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'pokemon.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: PokedexPage(
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
  }
}

class PokedexPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const PokedexPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<PokedexPage> createState() => _PokedexPageState();
}

class _PokedexPageState extends State<PokedexPage>
    with SingleTickerProviderStateMixin {
  final Dio _dio = Dio();
  final List<Pokemon> _pokemons = [];
  final Set<String> _favorites = {};
  bool _isLoading = false;
  String _search = '';

  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final limit = 1000;
      final resp = await _dio.get(
        'https://pokeapi.co/api/v2/pokemon?limit=$limit&offset=0',
      );
      final results = (resp.data['results'] as List)
          .cast<Map<String, dynamic>>();
      final futures = <Future<Pokemon>>[];
      for (final r in results) {
        futures.add(_fetchDetailsByUrl(r['url'] as String));
      }
      final list = await Future.wait(futures);
      list.sort(
        (a, b) =>
            int.parse(a.numeroPokedex).compareTo(int.parse(b.numeroPokedex)),
      );
      setState(() {
        _pokemons.clear();
        _pokemons.addAll(list);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(': $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Pokemon> _fetchDetailsByUrl(String url) async {
    final res = await _dio.get(url);
    return Pokemon.fromJson(res.data);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _pokemons
        .where((p) => p.nome.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final favList = filtered
        .where((p) => _favorites.contains(p.numeroPokedex))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokédex'),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'Modo claro' : 'Modo escuro',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todos', icon: Icon(Icons.catching_pokemon)),
            Tab(text: 'Favoritos', icon: Icon(Icons.favorite)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar pokémon pelo nome...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildGrid(filtered), _buildGrid(favList)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Pokemon> list) {
    if (_isLoading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return const Center(child: Text('Não achei nada com esse filtro.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final isFav = _favorites.contains(p.numeroPokedex);
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PokemonDetailPage(
                  id: p.numeroPokedex,
                  nome: p.nome,
                  imagem: p.urlImagem,
                  isFav: isFav,
                  onToggleFav: () {
                    _toggleFavorite(p.numeroPokedex);
                  },
                ),
              ),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.network(
                      p.urlImagem,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported, size: 48),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '#${p.numeroPokedex}  ${_capitalize(p.nome)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _toggleFavorite(p.numeroPokedex),
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class PokemonDetailPage extends StatefulWidget {
  final String id;
  final String nome;
  final String imagem;
  final bool isFav;
  final VoidCallback onToggleFav;
  const PokemonDetailPage({
    super.key,
    required this.id,
    required this.nome,
    required this.imagem,
    required this.isFav,
    required this.onToggleFav,
  });

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  final Dio _dio = Dio();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get(
        'https://pokeapi.co/api/v2/pokemon/${widget.id}',
      );
      setState(() {
        _data = res.data as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = 'erro: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_capitalize(widget.nome)),
        actions: [
          IconButton(
            onPressed: () {
              widget.onToggleFav();
              setState(() {});
            },
            icon: Icon(widget.isFav ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final types = ((_data?['types'] ?? []) as List)
        .map((e) => e['type']['name'] as String)
        .toList();
    final stats = ((_data?['stats'] ?? []) as List)
        .map<Map<String, dynamic>>(
          (e) => {'name': e['stat']['name'], 'value': e['base_stat']},
        )
        .toList();
    final height = (_data?['height'] ?? 0).toString();
    final weight = (_data?['weight'] ?? 0).toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.network(
              widget.imagem,
              height: 160,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, size: 80),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: -8,
            alignment: WrapAlignment.center,
            children: types
                .map((t) => Chip(label: Text(_capitalize(t))))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InfoBox(title: 'Altura', value: '$height dm'),
              _InfoBox(title: 'Peso', value: '$weight hg'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Status Base',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...stats.map(
            (s) => _StatBar(
              name: _capitalize(s['name']),
              value: (s['value'] as num).toDouble(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatBar extends StatelessWidget {
  final String name;
  final double value;
  const _StatBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final max = 255.0;
    final pct = ((value / max).clamp(0.0, 1.0)).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(name)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: pct),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(value.toInt().toString(), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  const _InfoBox({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
