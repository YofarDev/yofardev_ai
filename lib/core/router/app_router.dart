import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/screens/chat_details_screen.dart';
import '../../features/chat/screens/chats_list_screen.dart';
import '../../features/chat/screens/image_full_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/settings/screens/function_calling_config_screen.dart';
import '../../features/settings/screens/llm/llm_config_page.dart';
import '../../features/settings/screens/llm/llm_selection_page.dart';
import '../../features/settings/screens/llm/task_llm_config_page.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../core/models/llm_config.dart';
import '../../core/widgets/constrained_width.dart';
import 'route_constants.dart';

/// Application router configuration using go_router.
///
/// Provides declarative routing with deep linking support
/// and type-safe navigation.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    routes: <RouteBase>[
      GoRoute(
        path: RouteConstants.home,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            MaterialPage<void>(
              key: state.pageKey,
              child: const ConstrainedWidth(child: HomeScreen()),
            ),
      ),
      GoRoute(
        path: RouteConstants.chats,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            MaterialPage<void>(
              key: state.pageKey,
              child: const ConstrainedWidth(child: ChatsListPage()),
            ),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return MaterialPage<void>(
                key: state.pageKey,
                child: const ConstrainedWidth(child: ChatDetailsPage()),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteConstants.settings,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            MaterialPage<void>(
              key: state.pageKey,
              child: const ConstrainedWidth(child: SettingsPage()),
            ),
        routes: <RouteBase>[
          GoRoute(
            path: 'llm',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                MaterialPage<void>(
                  key: state.pageKey,
                  child: const ConstrainedWidth(child: LlmSelectionPage()),
                ),
            routes: <RouteBase>[
              GoRoute(
                path: 'config',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    MaterialPage<void>(
                      key: state.pageKey,
                      child: ConstrainedWidth(
                        child: LlmConfigPage(config: state.extra as LlmConfig?),
                      ),
                    ),
              ),
              GoRoute(
                path: 'task-llm',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return MaterialPage<void>(
                    key: state.pageKey,
                    child: const ConstrainedWidth(child: TaskLlmConfigPage()),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'function-calling',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return MaterialPage<void>(
                key: state.pageKey,
                child: const ConstrainedWidth(
                  child: FunctionCallingConfigScreen(),
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteConstants.imageFullScreen,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String? path = state.pathParameters['path'];
          return MaterialPage<void>(
            key: state.pageKey,
            child: ImageFullScreen(imagePath: path ?? ''),
          );
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const Scaffold(body: Center(child: Text('Page not found'))),
  );
}
