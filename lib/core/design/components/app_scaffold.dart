import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../context_ext.dart';
import '../tokens/app_spacing.dart';
import 'app_icon_button.dart';

/// Page frame for pushed screens: a header (back button, title, actions) over
/// the app's `background → surface` diagonal gradient, with [body] below.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    required this.body,
  });

  final String title;
  final List<Widget> actions;
  final Widget body;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String backLabel = AppLocalizations.of(context).commonBack;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[context.tokens.background, context.colors.surface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                child: Row(
                  children: <Widget>[
                    AppIconButton(
                      onPressed: () => _back(context),
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticLabel: backLabel,
                      tooltip: backLabel,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineSmall,
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
