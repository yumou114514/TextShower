import 'dart:math' as math;

enum DocKind { plain, tst }

String newDocId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final rnd = math.Random().nextInt(1 << 31);
  return '${ts}_$rnd';
}

class HideGroup {
  const HideGroup({required this.name, this.defaultHidden = false});

  final String name;
  final bool defaultHidden;

  HideGroup copyWith({String? name, bool? defaultHidden}) => HideGroup(
        name: name ?? this.name,
        defaultHidden: defaultHidden ?? this.defaultHidden,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'defaultHidden': defaultHidden,
      };

  factory HideGroup.fromJson(Map<dynamic, dynamic> json) => HideGroup(
        name: (json['name'] ?? '默认').toString(),
        defaultHidden: json['defaultHidden'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is HideGroup &&
      other.name == name &&
      other.defaultHidden == defaultHidden;

  @override
  int get hashCode => Object.hash(name, defaultHidden);
}

class DocConfig {
  const DocConfig({
    this.columns = 2,
    this.groups = const <HideGroup>[],
    this.defaultGroup,
  });

  const DocConfig.plain()
      : columns = 1,
        groups = const <HideGroup>[],
        defaultGroup = null;

  factory DocConfig.tstDefault() => const DocConfig(
        columns: 2,
        groups: <HideGroup>[HideGroup(name: '默认')],
        defaultGroup: '默认',
      );

  final int columns;
  final List<HideGroup> groups;
  final String? defaultGroup;

  int get safeColumns => columns == 1 ? 1 : 2;

  DocConfig copyWith({
    int? columns,
    List<HideGroup>? groups,
    String? defaultGroup,
    bool clearDefaultGroup = false,
  }) =>
      DocConfig(
        columns: columns ?? this.columns,
        groups: groups ?? this.groups,
        defaultGroup:
            clearDefaultGroup ? null : (defaultGroup ?? this.defaultGroup),
      );

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'groups': groups.map((g) => g.toJson()).toList(),
        if (defaultGroup != null) 'defaultGroup': defaultGroup,
      };

  factory DocConfig.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const DocConfig.plain();
    final groups = <HideGroup>[];
    final rawGroups = json['groups'];
    if (rawGroups is List) {
      for (final item in rawGroups) {
        if (item is Map) groups.add(HideGroup.fromJson(item));
      }
    }
    final rawColumns = json['columns'];
    final columns = rawColumns is int
        ? rawColumns
        : int.tryParse('$rawColumns') ?? 2;
    return DocConfig(
      columns: columns,
      groups: groups,
      defaultGroup: json['defaultGroup']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DocConfig &&
      other.columns == columns &&
      other.defaultGroup == defaultGroup &&
      _groupsEqual(other.groups, groups);

  @override
  int get hashCode => Object.hash(columns, defaultGroup, Object.hashAll(groups));

  static bool _groupsEqual(List<HideGroup> a, List<HideGroup> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class TextDoc {
  TextDoc({
    required this.id,
    required this.title,
    required this.kind,
    required this.body,
    this.config = const DocConfig.plain(),
    this.sourcePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final DocKind kind;
  final String body;
  final DocConfig config;
  final String? sourcePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTst => kind == DocKind.tst;

  TextDoc copyWith({
    String? id,
    String? title,
    DocKind? kind,
    String? body,
    DocConfig? config,
    String? sourcePath,
    bool clearSourcePath = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TextDoc(
        id: id ?? this.id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        body: body ?? this.body,
        config: config ?? this.config,
        sourcePath: clearSourcePath ? null : (sourcePath ?? this.sourcePath),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'body': body,
        'config': config.toJson(),
        if (sourcePath != null) 'sourcePath': sourcePath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TextDoc.fromJson(Map<dynamic, dynamic> json) {
    final rawKind = json['kind']?.toString();
    final kind = DocKind.values.firstWhere(
      (k) => k.name == rawKind,
      orElse: () => DocKind.plain,
    );
    final rawConfig = json['config'];
    return TextDoc(
      id: json['id']?.toString() ?? newDocId(),
      title: json['title']?.toString() ?? '未命名',
      kind: kind,
      body: json['body']?.toString() ?? '',
      config: rawConfig is Map ? DocConfig.fromJson(rawConfig) : const DocConfig.plain(),
      sourcePath: json['sourcePath']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
