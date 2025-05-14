import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// Enum para fases do jogo
enum GamePhase {
  iniciante(0, 'Iniciante', Colors.blue),
  aprendiz(80, 'Aprendiz', Colors.green),
  intermediario(200, 'Intermediário', Colors.amber),
  avancado(300, 'Avançado', Colors.orange),
  expert(450, 'Expert', Colors.red),
  mestre(600, 'Mestre', Colors.purple),
  lenda(800, 'Lenda das Palavras', Colors.deepPurple);

  final int requiredScore;
  final String title;
  final Color color;

  const GamePhase(this.requiredScore, this.title, this.color);
}

// Modelo de estado do jogo
class GameState {
  List<String> foundWords = [];
  int score = 0;
  String feedbackMessage = '';
  bool isLoading = false;
  String currentPrefix = '';
  int secondsRemaining = 60;
  bool gameOver = false;
  int currentRound = 1;
  final int maxRounds = 3;
  List<String> prefixes = [];
  GamePhase _currentPhase = GamePhase.iniciante;
  bool _canLevelUp = false;

  GamePhase get currentPhase => _currentPhase;
  bool get canLevelUp => _canLevelUp;

  void checkPhaseUpdate(bool roundCompleted) {
    if (roundCompleted) {
      _canLevelUp = true;
    }

    if (_canLevelUp) {
      final nextPhaseIndex = GamePhase.values.indexOf(_currentPhase) + 1;
      if (nextPhaseIndex < GamePhase.values.length &&
          score >= GamePhase.values[nextPhaseIndex].requiredScore) {
        _currentPhase = GamePhase.values[nextPhaseIndex];
        _canLevelUp = false;
        feedbackMessage = 'Parabéns! Você alcançou a fase ${_currentPhase.title}!';
      }
    }
  }

  void reset() {
    foundWords.clear();
    score = 0;
    feedbackMessage = '';
    isLoading = false;
    secondsRemaining = 60;
    gameOver = false;
    currentRound = 1;
    _currentPhase = GamePhase.iniciante;
    _canLevelUp = false;
  }
}

// Widget principal do aplicativo
void main() {
  runApp(const WordGameApp());
}

class WordGameApp extends StatelessWidget {
  const WordGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jogo de Palavras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
          headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            shadowColor: Colors.blue.withOpacity(0.4),
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Colors.blueGrey.shade600),
        ),
        cardTheme: CardTheme(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shadowColor: Colors.blueGrey.withOpacity(0.3),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade900,
          elevation: 0,
          titleTextStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

// Tela principal do jogo
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _wordController = TextEditingController();
  final GameState _gameState = GameState();
  Timer? _timer;
  bool _isLoadingPrefixes = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadPrefixes().then((_) {
      setState(() {
        _isLoadingPrefixes = false;
      });
      if (_gameState.prefixes.isNotEmpty) {
        _startNewRound();
      }
    });
  }

  Future<void> _loadPrefixes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedPrefixes = prefs.getStringList('prefixes');

    if (cachedPrefixes != null && cachedPrefixes.isNotEmpty) {
      setState(() {
        _gameState.prefixes = cachedPrefixes;
      });
    } else {
      await _loadDynamicPrefixes();
      await prefs.setStringList('prefixes', _gameState.prefixes);
    }
  }

  Future<void> _loadDynamicPrefixes() async {
    const initialPrefixes = [
      'pre', 'com', 'ver', 'mar', 'luz', 'por', 'des', 'bro', 'sol', 'cas',
      'sub', 'pro', 'con', 'dis', 'mis', 'tri', 'uni', 'bio', 'geo', 'hid',
      'arte', 'tech', 'sust', 'ambi', 'cult'
    ];
    Set<String> dynamicPrefixes = {};

    final futures = initialPrefixes.map((prefix) async {
      try {
        final response = await http
            .get(Uri.parse('/api/prefix/$prefix'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final dynamic decodedData = jsonDecode(utf8.decode(response.bodyBytes));
          List<dynamic> data = decodedData is List ? decodedData : decodedData['results'] ?? [];

          for (var entry in data) {
            if (entry['word'] != null) {
              String word = entry['word'].toString().toLowerCase();
              if (word.length >= 3) {
                String newPrefix = word.substring(0, 3);
                dynamicPrefixes.add(newPrefix);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading prefix $prefix: $e');
      }
    }).toList();

    await Future.wait(futures);

    if (dynamicPrefixes.length < 50) {
      dynamicPrefixes.addAll(initialPrefixes);
    }

    setState(() {
      _gameState.prefixes = dynamicPrefixes.toList();
      if (_gameState.prefixes.isEmpty) {
        _gameState.feedbackMessage = 'Erro ao carregar prefixos. Verifique sua conexão.';
        _gameState.gameOver = true;
      }
    });
  }

  void _startNewRound() {
    setState(() {
      _gameState.foundWords.clear();
      _gameState.feedbackMessage = '';
      _gameState.secondsRemaining = 60;
      _gameState.currentPrefix = _gameState.prefixes[Random().nextInt(_gameState.prefixes.length)];
      _wordController.clear();
    });
    _startTimer();
  }

  void _startNewGame() {
    setState(() {
      _gameState.reset();
      _gameState.currentPrefix = _gameState.prefixes[Random().nextInt(_gameState.prefixes.length)];
      _wordController.clear();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_gameState.secondsRemaining > 0) {
          _gameState.secondsRemaining--;
        } else {
          timer.cancel();
          if (_gameState.currentRound < _gameState.maxRounds) {
            _gameState.currentRound++;
            _gameState.feedbackMessage = 'Rodada ${_gameState.currentRound}/${_gameState.maxRounds} começando!';
            _animationController.forward(from: 0);
            _startNewRound();
          } else {
            _gameState.checkPhaseUpdate(true);
            _gameState.gameOver = true;

            String phaseMessage = '';
            final nextPhaseIndex = GamePhase.values.indexOf(_gameState.currentPhase) + 1;
            if (_gameState.canLevelUp &&
                nextPhaseIndex < GamePhase.values.length &&
                _gameState.score < GamePhase.values[nextPhaseIndex].requiredScore) {
              phaseMessage = ' Complete ${GamePhase.values[nextPhaseIndex].requiredScore - _gameState.score} pontos para próxima fase!';
            }

            _gameState.feedbackMessage = 'Fim do jogo! Placar final: ${_gameState.score}.$phaseMessage';
            _animationController.forward(from: 0);
          }
        }
      });
    });
  }

  Future<bool> _checkWord(String prefix, String word) async {
    try {
      final response = await http
          .get(Uri.parse('/api/prefix/$prefix'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> data = decodedData is List ? decodedData : decodedData['results'] ?? [];

        return data.any((entry) =>
            entry['word']?.toString().toLowerCase() == word.toLowerCase());
      }
    } catch (e) {
      debugPrint('Error checking word: $e');
    }
    return false;
  }

  void _verifyWord() async {
    if (_gameState.gameOver) return;

    final input = _wordController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _gameState.feedbackMessage = 'Por favor, complete a palavra.';
        _animationController.forward(from: 0);
      });
      return;
    }

    final word = _gameState.currentPrefix + input;
    final previousPhase = _gameState.currentPhase;

    setState(() {
      _gameState.isLoading = true;
      _gameState.feedbackMessage = '';
    });

    final isValid = await _checkWord(_gameState.currentPrefix, word);

    setState(() {
      _gameState.isLoading = false;
      if (isValid && !_gameState.foundWords.contains(word.toLowerCase())) {
        _gameState.foundWords.add(word.toLowerCase());
        _gameState.score += word.length;

        _gameState.feedbackMessage = 'Palavra válida! 🎉 +${word.length} pontos';
      } else if (_gameState.foundWords.contains(word.toLowerCase())) {
        _gameState.feedbackMessage = 'Palavra já encontrada!';
      } else {
        _gameState.feedbackMessage = 'Palavra inválida ou não encontrada.';
      }
      _wordController.clear();
      _animationController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefixes) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue.shade700),
              const SizedBox(height: 16),
              Text(
                'Carregando prefixos...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_gameState.prefixes.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Jogo de Palavras'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade600),
              const SizedBox(height: 16),
              Text(
                _gameState.feedbackMessage,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoadingPrefixes = true;
                    _gameState.feedbackMessage = '';
                    _gameState.gameOver = false;
                  });
                  _loadPrefixes().then((_) {
                    setState(() {
                      _isLoadingPrefixes = false;
                      if (_gameState.prefixes.isNotEmpty) {
                        _startNewRound();
                      }
                    });
                  });
                },
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_showTutorial) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bem-vindo ao Jogo de Palavras!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete palavras começando com o prefixo mostrado.\n'
                    'Cada palavra válida adiciona pontos com base em seu tamanho.\n'
                    'Você tem 60 segundos por rodada, com 3 rodadas no total!\n\n'
                    'Fases do jogo (avança após completar 3 rodadas):\n'
                    '- Iniciante: 0 pts\n'
                    '- Aprendiz: 80 pts\n'
                    '- Intermediário: 200 pts\n'
                    '- Avançado: 300 pts\n'
                    '- Expert: 450 pts\n'
                    '- Mestre: 600 pts\n'
                    '- Lenda: 800 pts',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showTutorial = false;
                      });
                    },
                    child: const Text('Começar o Jogo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jogo de Palavras'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              setState(() {
                _showTutorial = true;
              });
            },
            tooltip: 'Como Jogar',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RoundInfo(
                        currentRound: _gameState.currentRound,
                        maxRounds: _gameState.maxRounds,
                      ),
                      const SizedBox(height: 16),
                      PrefixDisplay(prefix: _gameState.currentPrefix),
                      const SizedBox(height: 12),
                      TimerDisplay(secondsRemaining: _gameState.secondsRemaining),
                      const SizedBox(height: 12),
                      ScoreDisplay(score: _gameState.score),
                      const SizedBox(height: 8),
                      PhaseDisplay(
                        phase: _gameState.currentPhase,
                        score: _gameState.score,
                        canLevelUp: _gameState.canLevelUp,
                        roundsCompleted: _gameState.currentRound - 1,
                      ),
                      const SizedBox(height: 12),
                      if (!_gameState.gameOver)
                        WordInput(
                          controller: _wordController,
                          isLoading: _gameState.isLoading,
                          onVerify: _verifyWord,
                          prefix: _gameState.currentPrefix,
                        ),
                      if (_gameState.gameOver)
                        ElevatedButton.icon(
                          onPressed: _startNewGame,
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text('Jogar Novamente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                          ),
                        ).animate().fadeIn(duration: 600.ms),
                      const SizedBox(height: 20),
                      FeedbackMessage(
                        message: _gameState.feedbackMessage,
                        animation: _fadeAnimation,
                      ),
                      const SizedBox(height: 20),
                      WordList(words: _gameState.foundWords),
                      const SizedBox(height: 8),
                      Text(
                        'Prefixos disponíveis: ${_gameState.prefixes.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Widget para exibir mensagens de feedback
class FeedbackMessage extends StatelessWidget {
  final String message;
  final Animation<double> animation;

  const FeedbackMessage({super.key, required this.message, required this.animation});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        padding: message.isNotEmpty ? const EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: message.contains('válida') || message.contains('Parabéns')
              ? Colors.green.shade100
              : message.contains('Erro') || message.contains('inválida') || message.contains('já encontrada')
                  ? Colors.red.shade100
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: message.contains('válida') || message.contains('Parabéns')
                ? Colors.green.shade800
                : Colors.red.shade800,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Widget para exibir a fase do jogo
class PhaseDisplay extends StatelessWidget {
  final GamePhase phase;
  final int score;
  final bool canLevelUp;
  final int roundsCompleted;

  const PhaseDisplay({
    super.key,
    required this.phase,
    required this.score,
    required this.canLevelUp,
    required this.roundsCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final nextPhaseIndex = GamePhase.values.indexOf(phase) + 1;
    final hasNextPhase = nextPhaseIndex < GamePhase.values.length;
    final nextPhase = hasNextPhase ? GamePhase.values[nextPhaseIndex] : null;

    double progress = 0;
    String progressText = '';

    if (hasNextPhase) {
      if (canLevelUp) {
        progress = score / nextPhase!.requiredScore;
        progressText = 'Faltam ${nextPhase.requiredScore - score} pontos para ${nextPhase.title}';
      } else {
        progress = roundsCompleted / 3;
        progressText = '${3 - roundsCompleted} rodadas restantes para desbloquear progresso';
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: phase.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: phase.color, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: phase.color),
              const SizedBox(width: 8),
              Text(
                'Fase: ${phase.title}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: phase.color,
                ),
              ),
              if (phase != GamePhase.iniciante) ...[
                const SizedBox(width: 8),
                Text(
                  '(${phase.requiredScore}+ pts)',
                  style: TextStyle(
                    fontSize: 14,
                    color: phase.color.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasNextPhase) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            color: phase.color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            progressText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            'Fase máxima alcançada!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// Widget para exibir o prefixo
class PrefixDisplay extends StatelessWidget {
  final String prefix;

  const PrefixDisplay({super.key, required this.prefix});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade400.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Prefixo: $prefix',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().scale(duration: 400.ms);
  }
}

// Widget para exibir informações da rodada
class RoundInfo extends StatelessWidget {
  final int currentRound;
  final int maxRounds;

  const RoundInfo({super.key, required this.currentRound, required this.maxRounds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Rodada: $currentRound/$maxRounds',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().slideY(duration: 400.ms);
  }
}

// Widget para exibir o placar
class ScoreDisplay extends StatelessWidget {
  final int score;

  const ScoreDisplay({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade300.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'Placar: $score',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// Widget para exibir o temporizador
class TimerDisplay extends StatelessWidget {
  final int secondsRemaining;

  const TimerDisplay({super.key, required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer, color: Colors.red.shade700, size: 28),
        const SizedBox(width: 8),
        Text(
          '$secondsRemaining segundos',
          style: TextStyle(
            fontSize: 20,
            color: Colors.red.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// Widget para entrada de palavras
class WordInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onVerify;
  final String prefix;

  const WordInput({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onVerify,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Complete a palavra',
            prefix: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prefix,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: Colors.blueGrey.shade400),
              onPressed: () => controller.clear(),
            ),
          ),
          onSubmitted: (_) => onVerify(),
          enabled: !isLoading,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onVerify,
          icon: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 24),
          label: const Text('Verificar Palavra'),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
}

// Widget para exibir a lista de palavras encontradas
class WordList extends StatelessWidget {
  final List<String> words;

  const WordList({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.3,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, size: 40, color: Colors.blueGrey.shade300),
              const SizedBox(height: 8),
              Text(
                'Nenhuma palavra encontrada ainda.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green.shade600),
            title: Text(
              words[index],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Text(
              '+${words[index].length}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ).animate().slideX(duration: 400.ms, delay: (index * 100).ms);
      },
    );
  }
}
