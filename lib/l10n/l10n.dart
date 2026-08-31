import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `context.l10n.someKey` — terse access with the non-null getter
/// guaranteed by `nullable-getter: false` in l10n.yaml.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
