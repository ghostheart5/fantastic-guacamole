import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ChronoSparkLocalizations {
  const ChronoSparkLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<ChronoSparkLocalizations> delegate =
      _ChronoSparkLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  static ChronoSparkLocalizations of(BuildContext context) =>
      Localizations.of<ChronoSparkLocalizations>(
        context,
        ChronoSparkLocalizations,
      ) ??
      const ChronoSparkLocalizations(Locale('en'));

  bool get isSpanish => locale.languageCode.toLowerCase() == 'es';

  String text(ChronoSparkString key) =>
      (isSpanish ? _es : _en)[key] ?? _en[key] ?? key.name;

  static const Map<ChronoSparkString, String> _en = <ChronoSparkString, String>{
    ChronoSparkString.nexus: 'Nexus',
    ChronoSparkString.smartPlanner: 'Smart Planner',
    ChronoSparkString.creator: 'Creator',
    ChronoSparkString.siConsole: 'SI Console',
    ChronoSparkString.timeline: 'Timeline',
    ChronoSparkString.trajectoryEngine: 'Trajectory Engine',
    ChronoSparkString.progression: 'Progression',
    ChronoSparkString.preparingSummary: 'Preparing your summary',
    ChronoSparkString.retryNexus: 'Retry Nexus',
    ChronoSparkString.whatMattersNext: 'What matters next',
    ChronoSparkString.topRisk: 'Top risk',
    ChronoSparkString.whatChanged: 'What changed',
    ChronoSparkString.openCreator: 'Open Creator',
    ChronoSparkString.startInCreator: 'Start in Creator',
  };

  static const Map<ChronoSparkString, String> _es = <ChronoSparkString, String>{
    ChronoSparkString.nexus: 'Nexus',
    ChronoSparkString.smartPlanner: 'Planificador Inteligente',
    ChronoSparkString.creator: 'Creador',
    ChronoSparkString.siConsole: 'Consola SI',
    ChronoSparkString.timeline: 'Línea de Tiempo',
    ChronoSparkString.trajectoryEngine: 'Motor de Trayectoria',
    ChronoSparkString.progression: 'Progresión',
    ChronoSparkString.preparingSummary: 'Preparando tu resumen',
    ChronoSparkString.retryNexus: 'Reintentar Nexus',
    ChronoSparkString.whatMattersNext: 'Lo más importante ahora',
    ChronoSparkString.topRisk: 'Riesgo principal',
    ChronoSparkString.whatChanged: 'Qué cambió',
    ChronoSparkString.openCreator: 'Abrir Creador',
    ChronoSparkString.startInCreator: 'Comienza en Creador',
  };
}

enum ChronoSparkString {
  nexus,
  smartPlanner,
  creator,
  siConsole,
  timeline,
  trajectoryEngine,
  progression,
  preparingSummary,
  retryNexus,
  whatMattersNext,
  topRisk,
  whatChanged,
  openCreator,
  startInCreator,
}

class _ChronoSparkLocalizationsDelegate
    extends LocalizationsDelegate<ChronoSparkLocalizations> {
  const _ChronoSparkLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ChronoSparkLocalizations.supportedLocales
      .any((Locale supported) => supported.languageCode == locale.languageCode);

  @override
  Future<ChronoSparkLocalizations> load(Locale locale) =>
      SynchronousFuture<ChronoSparkLocalizations>(
        ChronoSparkLocalizations(locale),
      );

  @override
  bool shouldReload(_ChronoSparkLocalizationsDelegate old) => false;
}
