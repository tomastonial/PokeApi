class Pokemon {
  final String nome;
  final String numeroPokedex;
  final String urlImagem;

  const Pokemon({
    required this.nome,
    required this.numeroPokedex,
    required this.urlImagem,
  });

  static Pokemon fromJson(Map<String, dynamic> json) {
    return Pokemon(
      nome: json['name'],
      numeroPokedex: json['id'].toString(),
      urlImagem: json['sprites']['front_default'],
    );
  }
}
