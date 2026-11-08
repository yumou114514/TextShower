class ReaderPref {
  const ReaderPref({
    this.auto = true,
    this.manualSize = 32,
  });

  final bool auto;
  final double manualSize;

  ReaderPref copyWith({bool? auto, double? manualSize}) => ReaderPref(
        auto: auto ?? this.auto,
        manualSize: manualSize ?? this.manualSize,
      );
}
