import 'package:flutter/widgets.dart';

/// [style] at [weight], on the font's own weight axis as well.
///
/// The reading face, Source Serif 4, is a variable font, and its styles pin
/// the `wght` axis (`FontVariation('wght', ...)`) so the dark theme's lighter
/// weights apply. A bare `copyWith(fontWeight: ...)` leaves that pin in
/// place, and the pin wins: in dark mode, where regular is 350 and not the
/// axis default of 400, bold text then stays regular. Every bold, semibold
/// or medium run of reading text goes through here, so the weight and the
/// axis always agree. Other axes, such as `opsz`, are kept.
TextStyle withFontWeight(TextStyle style, FontWeight weight) => style.copyWith(
  fontWeight: weight,
  fontVariations: [
    FontVariation('wght', weight.value.toDouble()),
    for (final variation in style.fontVariations ?? const <FontVariation>[])
      if (variation.axis != 'wght') variation,
  ],
);
