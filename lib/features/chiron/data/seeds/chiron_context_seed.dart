/// Seed/config for adaptive Chiron context selection.
///
/// Centralizing these values keeps heuristics and limits easy to tune
/// without scattering hardcoded strings across repository/helpers.
const int chironDefaultRecentExecutionsLimit = 10;
const int chironExtendedRecentExecutionsLimit = 30;
const int chironDefaultWorkoutsLimit = 10;
const int chironExtendedWorkoutsLimit = 25;

/// Regex fragments used to detect "big picture" requests.
/// They are combined in a single RegExp at runtime.
const List<String> chironExtendedContextRegexSeed = [
  r'evolu(cao|ção|ir|indo)',
  r'progresso',
  r'tend[eê]ncia',
  r'ultim[oa]s?\s+(semanas?|meses?)',
  r'hist[oó]rico(\s+completo)?',
  r'longo prazo',
  r'vis[aã]o geral',
  r'figura geral',
  r'overview',
  r'compar(ar|a[cç][aã]o|ativo)',
  r'desde\s+(janeiro|fevereiro|mar[cç]o|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)',
];
