import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'api_keys.dart';

const String kPlacesApiKey = String.fromEnvironment(
  'PLACES_API_KEY',
  defaultValue: kPlacesApiKeyLocal,
);

class LugarSalvo {
  const LugarSalvo({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.posicao,
    required this.icone,
  });

  final String id;
  final String nome;
  final String endereco;
  final LatLng posicao;
  final IconData icone;
}

class Categoria {
  const Categoria({
    required this.nome,
    required this.icone,
    required this.tipoPlaces,
    required this.corMarcador,
  });

  final String nome;
  final IconData icone;

  final String tipoPlaces;

  final double corMarcador;
}

const List<Categoria> kCategorias = <Categoria>[
  Categoria(
    nome: 'Bares',
    icone: Icons.sports_bar,
    tipoPlaces: 'bar',
    corMarcador: BitmapDescriptor.hueViolet,
  ),
  Categoria(
    nome: 'Restaurantes',
    icone: Icons.restaurant,
    tipoPlaces: 'restaurant',
    corMarcador: BitmapDescriptor.hueRed,
  ),
  Categoria(
    nome: 'Cafeterias',
    icone: Icons.local_cafe,
    tipoPlaces: 'cafe',
    corMarcador: BitmapDescriptor.hueOrange,
  ),
  Categoria(
    nome: 'Postos de Gasolina',
    icone: Icons.local_gas_station,
    tipoPlaces: 'gas_station',
    corMarcador: BitmapDescriptor.hueBlue,
  ),
  Categoria(
    nome: 'Fast-Foods',
    icone: Icons.fastfood,
    tipoPlaces: 'fast_food_restaurant',
    corMarcador: BitmapDescriptor.hueYellow,
  ),
  Categoria(
    nome: 'Supermercados',
    icone: Icons.local_grocery_store,
    tipoPlaces: 'supermarket',
    corMarcador: BitmapDescriptor.hueGreen,
  ),
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aula Maps Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MyHomePage(title: 'Aula Maps Flutter'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  Set<Marker> _marcadores = {};

  Set<Marker> _marcadoresBusca = {};
  bool _buscando = false;

  Future<void> _localizacaoAtual() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    print('Localização atual: ${position.latitude}, ${position.longitude}');

    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17.0,
        ),
      ),
    );
  }

  void _carregarMarcadores() {
    Set<Marker> marcadoresLocal = {};
    marcadoresLocal.add(
      Marker(
        markerId: MarkerId('ifpi'),
        position: LatLng(-5.088544, -42.8112380),
        infoWindow: InfoWindow(
          title: 'IFPI Central',
          snippet: 'Campus Central',
        ),
      ),
    );

    marcadoresLocal.add(
      Marker(
        markerId: MarkerId('ifpi-sul'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueMagenta,
        ),
        position: LatLng(-5.101723, -42.813114),
        infoWindow: InfoWindow(title: 'IFPI Sul', snippet: 'Campus Sul'),
      ),
    );
    setState(() {
      _marcadores = marcadoresLocal;
    });
  }

  Future<void> _irParaIfpi() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_ifpiPosition),
    );
  }

  void _limparMarcadores() {
    setState(() {
      _marcadoresBusca = {};
    });
  }

  Future<Position?> _obterPosicao() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<Set<Marker>> _buscarLocaisProximos(
    Categoria categoria,
    LatLng centro,
  ) async {
    final resposta = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': kPlacesApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode({
        'includedTypes': [categoria.tipoPlaces],
        'maxResultCount': 20,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': centro.latitude,
              'longitude': centro.longitude,
            },
            'radius': 3000.0,
          },
        },
      }),
    );

    if (resposta.statusCode != 200) {
      throw Exception('Erro ${resposta.statusCode}: ${resposta.body}');
    }

    final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
    final locais = (dados['places'] as List<dynamic>?) ?? <dynamic>[];

    return locais.map((dynamic item) {
      final local = item as Map<String, dynamic>;
      final loc = local['location'] as Map<String, dynamic>;
      final nome =
          (local['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
          categoria.nome;
      return Marker(
        markerId: MarkerId('places-${local['id']}'),
        position: LatLng(
          (loc['latitude'] as num).toDouble(),
          (loc['longitude'] as num).toDouble(),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(categoria.corMarcador),
        infoWindow: InfoWindow(
          title: nome,
          snippet: local['formattedAddress'] as String?,
        ),
      );
    }).toSet();
  }

  Future<void> _onCategoriaSelecionada(Categoria categoria) async {
    final messenger = ScaffoldMessenger.of(context);

    if (kPlacesApiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Defina a chave: --dart-define=PLACES_API_KEY=SUA_CHAVE',
          ),
        ),
      );
      return;
    }

    _onItemTapped(1);
    setState(() => _buscando = true);

    try {
      final posicao = await _obterPosicao();
      if (posicao == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada.')),
        );
        return;
      }
      final atual = LatLng(posicao.latitude, posicao.longitude);
      final novos = await _buscarLocaisProximos(categoria, atual);

      if (!mounted) return;
      setState(() => _marcadoresBusca = novos);

      messenger.showSnackBar(
        SnackBar(
          content: Text('${novos.length} ${categoria.nome} encontrados.'),
        ),
      );

      await _ajustarCamera(atual, novos);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Falha na busca: $e')));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _ajustarCamera(LatLng atual, Set<Marker> marcadores) async {
    final GoogleMapController controller = await _controller.future;

    if (marcadores.isEmpty) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(atual, 15));
      return;
    }

    double minLat = atual.latitude, maxLat = atual.latitude;
    double minLng = atual.longitude, maxLng = atual.longitude;
    for (final m in marcadores) {
      final p = m.position;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await WidgetsBinding.instance.endOfFrame;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  static const List<LugarSalvo> _lugaresSalvos = <LugarSalvo>[
    LugarSalvo(
      id: 'salvo-sao-benedito',
      nome: 'Paróquia de São Benedito',
      endereco: 'Av. Frei Serafim - Centro, Teresina - PI',
      posicao: LatLng(-5.090185067161575, -42.81081064620233),
      icone: Icons.church,
    ),
    LugarSalvo(
      id: 'ifpi',
      nome: 'IFPI Centro',
      endereco: 'Praça da Liberdade, 1597 - Centro, Teresina - PI',
      posicao: LatLng(-5.089067693894284, -42.81115391791998),
      icone: Icons.school,
    ),
    LugarSalvo(
      id: 'ifpi-sul',
      nome: 'IFPI Sul',
      endereco: 'Av. Pedro Freitas, 1020 - São Pedro, Teresina - PI',
      posicao: LatLng(-5.102310464743262, -42.81304860636553),
      icone: Icons.school,
    ),
  ];

  Future<void> _abrirLugarSalvo(LugarSalvo lugar) async {
    final markerId = MarkerId(lugar.id);
    final jaExiste = {..._marcadores, ..._marcadoresBusca}
        .any((m) => m.markerId == markerId);

    setState(() {
      _selectedIndex = 1;
      if (!jaExiste) {
        _marcadoresBusca = {
          ..._marcadoresBusca,
          Marker(
            markerId: markerId,
            position: lugar.posicao,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(title: lugar.nome, snippet: lugar.endereco),
          ),
        };
      }
    });

    final GoogleMapController controller = await _controller.future;
    await WidgetsBinding.instance.endOfFrame;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: lugar.posicao, zoom: 18),
      ),
    );
    await controller.showMarkerInfoWindow(markerId);
  }

  Widget _buildSalvos() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _lugaresSalvos.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lugar = _lugaresSalvos[index];
        return ListTile(
          leading: CircleAvatar(child: Icon(lugar.icone)),
          title: Text(lugar.nome),
          subtitle: Text(lugar.endereco),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _abrirLugarSalvo(lugar),
        );
      },
    );
  }

  Widget _buildHome() {
    const double espaco = 12;
    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraCard = (constraints.maxWidth - espaco * 3) / 2;
        final alturaCard = (constraints.maxHeight - espaco * 4) / 3;
        return GridView.count(
          padding: const EdgeInsets.all(espaco),
          crossAxisCount: 2,
          mainAxisSpacing: espaco,
          crossAxisSpacing: espaco,
          childAspectRatio: larguraCard / alturaCard,
          children: kCategorias.map(_buildCardCategoria).toList(),
        );
      },
    );
  }

  Widget _buildCardCategoria(Categoria categoria) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onCategoriaSelecionada(categoria),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(categoria.icone, size: 56, color: cores.primary),
              const SizedBox(height: 12),
              Text(
                categoria.nome,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final CameraPosition _startMap = CameraPosition(
    target: LatLng(-5.0892, -42.8019),
    zoom: 14.4746,
  );

  static final CameraPosition _ifpiPosition = CameraPosition(
    target: LatLng(-5.089070, -42.811150),
    zoom: 19.151926040649414,
  );
  @override
  void initState() {
    super.initState();
    //_carregarMarcadores();
    _localizacaoAtual();
  }

  int _selectedIndex = 0;

  bool _notificacoes = true;
  bool _modoEscuro = false;
  bool _localizacaoSegundoPlano = false;

  Widget _tituloSecao(String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildConfiguracoes() {
    return ListView(
      children: [
        _tituloSecao('Geral'),
        SwitchListTile(
          secondary: const Icon(Icons.notifications),
          title: const Text('Notificações'),
          subtitle: const Text('Receber alertas de lugares próximos'),
          value: _notificacoes,
          onChanged: (v) => setState(() => _notificacoes = v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode),
          title: const Text('Modo escuro'),
          value: _modoEscuro,
          onChanged: (v) => setState(() => _modoEscuro = v),
        ),
        const ListTile(
          leading: Icon(Icons.language),
          title: Text('Idioma'),
          subtitle: Text('Português (Brasil)'),
          trailing: Icon(Icons.chevron_right),
        ),
        _tituloSecao('Mapa'),
        const ListTile(
          leading: Icon(Icons.layers),
          title: Text('Tipo de mapa'),
          subtitle: Text('Normal'),
          trailing: Icon(Icons.chevron_right),
        ),
        const ListTile(
          leading: Icon(Icons.radar),
          title: Text('Raio de busca'),
          subtitle: Text('3 km'),
          trailing: Icon(Icons.chevron_right),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.my_location),
          title: const Text('Localização em segundo plano'),
          value: _localizacaoSegundoPlano,
          onChanged: (v) => setState(() => _localizacaoSegundoPlano = v),
        ),
        _tituloSecao('Sobre'),
        const ListTile(
          leading: Icon(Icons.privacy_tip),
          title: Text('Política de privacidade'),
          trailing: Icon(Icons.chevron_right),
        ),
        const ListTile(
          leading: Icon(Icons.info),
          title: Text('Versão do app'),
          subtitle: Text('1.0.0'),
        ),
      ],
    );
  }

  Widget _buildPerfil() {
    final cores = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: cores.primaryContainer,
            child: Icon(Icons.person, size: 56, color: cores.primary),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Kiro Marcell',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const Center(child: Text('teste@email.com')),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            _EstatisticaPerfil(valor: '3', rotulo: 'Salvos'),
            _EstatisticaPerfil(valor: '12', rotulo: 'Buscas'),
            _EstatisticaPerfil(valor: '5', rotulo: 'Avaliações'),
          ],
        ),
        const Divider(height: 32),
        const ListTile(
          leading: Icon(Icons.location_city),
          title: Text('Cidade'),
          subtitle: Text('Teresina - PI'),
        ),
        const ListTile(
          leading: Icon(Icons.phone),
          title: Text('Telefone'),
          subtitle: Text('(86) 99999-0000'),
        ),
        const ListTile(
          leading: Icon(Icons.edit),
          title: Text('Editar perfil'),
          trailing: Icon(Icons.chevron_right),
        ),
        const ListTile(
          leading: Icon(Icons.logout, color: Colors.red),
          title: Text('Sair', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildMapa() {
    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: _startMap,
          myLocationEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
          },
          markers: {..._marcadores, ..._marcadoresBusca},
        ),
        if (_buscando)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> paginas = <Widget>[
      _buildHome(),
      _buildMapa(),
      _buildSalvos(),
      _buildConfiguracoes(),
      _buildPerfil(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: IndexedStack(index: _selectedIndex, children: paginas),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _selectedIndex == 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'btn_limpar',
                  onPressed: _limparMarcadores,
                  label: const Text('Limpar marcadores'),
                  icon: const Icon(Icons.layers_clear),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'btn_ifpi',
                  onPressed: _irParaIfpi,
                  label: const Text('Ir para o IFPI'),
                  icon: const Icon(Icons.location_pin),
                ),
              ],
            )
          : null,
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Salvos'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configurações',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
      ),
    );
  }
}


class _EstatisticaPerfil extends StatelessWidget {
  const _EstatisticaPerfil({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(rotulo, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
