import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';

import '../../../core/di/service_locator.dart';
import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/presentation/bloc/avatar_state.dart';
import '../../features/chat/screens/chat_details_screen.dart';
import '../../features/chat/screens/chats_list_screen.dart';
import '../../features/chat/screens/image_full_screen.dart';
import '../../features/demo/presentation/bloc/demo_cubit.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/settings/screens/function_calling_config_screen.dart';
import '../../features/settings/screens/llm/llm_config_page.dart';
import '../../features/settings/screens/llm/llm_selection_page.dart';
import '../../features/settings/screens/llm/task_llm_config_page.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../core/res/app_constants.dart';
import '../../core/widgets/constrained_width.dart';
import '../../core/l10n/generated/app_localizations.dart';
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
              child: BlocBuilder<AvatarCubit, AvatarState>(
                builder: (BuildContext context, AvatarState avatarState) {
                  final double computedWidth =
                      avatarState.status == AvatarStatus.initial
                      ? AppConstants.avatarWidth
                      : avatarState.baseOriginalWidth * avatarState.scaleFactor;
                  final double avatarWidth =
                      computedWidth.isFinite && computedWidth > 0
                      ? computedWidth
                      : AppConstants.avatarWidth;
                  return ConstrainedWidth(
                    avatarWidth: avatarWidth,
                    child: MultiBlocProvider(
                      providers: <SingleChildWidget>[
                        BlocProvider<DemoCubit>(
                          create: (BuildContext context) => getIt<DemoCubit>(),
                        ),
                        BlocProvider<HomeCubit>(
                          create: (BuildContext context) =>
                              getIt<HomeCubit>()..initialize(),
                        ),
                      ],
                      child: const HomeScreen(),
                    ),
                  );
                },
              ),
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
                path: 'config/:id',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  final String? configId = state.pathParameters['id'];
                  return MaterialPage<void>(
                    key: state.pageKey,
                    child: ConstrainedWidth(
                      child: LlmConfigPage(configId: configId),
                    ),
                  );
                },
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
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).pageNotFound)),
    ),
  );
}
