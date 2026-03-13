# Flutter Pre-Analysis — 2026-03-13
_Project: `/Users/yofardev/development/Projects/Flutter/yofardev_ai`_

## File tree
_Features: avatar chat demo home settings sound talking_

```
│   +-- [1] service_locator.dart  (283 lines)
│   │   +-- [2] app_localizations.dart  (662 lines) (!)
│   │   +-- [3] app_localizations_en.dart  (304 lines) (!)
│   │   +-- [4] app_localizations_fr.dart  (311 lines) (!)
│   +-- [5] answer.dart  (16 lines)
│   +-- [6] avatar_config.dart  (287 lines)
│   +-- [7] chat.dart  (103 lines)
│   +-- [8] chat_entry.dart  (124 lines)
│   +-- [9] demo_script.dart  (124 lines)
│   +-- [10] function_info.dart  (34 lines)
│   +-- [11] llm_config.dart  (75 lines)
│   +-- [12] llm_message.dart  (17 lines)
│   +-- [13] llm_task_type.dart  (11 lines)
│   +-- [14] sound_effects.dart  (59 lines)
│   +-- [15] task_llm_config.dart  (22 lines)
│   +-- [16] voice_effect.dart  (17 lines)
│   +-- [17] avatar_repository.dart  (8 lines)
│   +-- [18] locale_repository.dart  (10 lines)
│   +-- [19] locale_repository_impl.dart  (32 lines)
│   +-- [20] settings_repository.dart  (44 lines)
│   +-- [21] app_colors.dart  (41 lines)
│   +-- [22] app_constants.dart  (35 lines)
│   +-- [23] app_theme.dart  (259 lines)
│   +-- [24] app_router.dart  (155 lines)
│   +-- [25] route_constants.dart  (21 lines)
│   │   +-- [26] agent_tool.dart  (49 lines)
│   │   +-- [27] alarm_service.dart  (43 lines)
│   │   +-- [28] alarm_tool.dart  (42 lines)
│   │   +-- [29] calculator_tool.dart  (49 lines)
│   │   +-- [30] character_counter_tool.dart  (46 lines)
│   │   +-- [31] google_search_service.dart  (74 lines)
│   │   +-- [32] google_search_tool.dart  (55 lines)
│   │   +-- [33] news_service.dart  (35 lines)
│   │   +-- [34] news_tool.dart  (39 lines)
│   │   +-- [35] tool_registry.dart  (180 lines)
│   │   +-- [36] weather_service.dart  (95 lines)
│   │   +-- [37] weather_tool.dart  (46 lines)
│   │   +-- [38] web_reader_tool.dart  (60 lines)
│   │   +-- [39] yofardev_agent.dart  (266 lines)
│   +-- [40] app_lifecycle_service.dart  (257 lines)
│   │   +-- [41] audio_amplitude_service.dart  (35 lines)
│   │   +-- [42] audio_player_service.dart  (137 lines)
│   │   +-- [43] interruption_service.dart  (47 lines)
│   │   +-- [44] tts_queue_service.dart  (207 lines)
│   +-- [45] avatar_animation_service.dart  (55 lines)
│   │   +-- [46] chat_streaming_service.dart  (329 lines)
│   +-- [47] demo_controller.dart  (81 lines)
│   │   +-- [48] fake_llm_service.dart  (233 lines)
│   │   +-- [49] llm_config_manager.dart  (163 lines)
│   │   +-- [50] llm_service.dart  (416 lines) (!)
│   │   +-- [51] llm_service_interface.dart  (79 lines)
│   │   +-- [52] llm_stream_chunk.dart  (23 lines)
│   │   +-- [53] llm_streaming_service.dart  (145 lines)
│   │   +-- [54] llm_streaming_service_interface.dart  (30 lines)
│   +-- [55] prompt_datasource.dart  (83 lines)
│   +-- [56] settings_local_datasource.dart  (211 lines)
│   │   +-- [57] json_stream_extractor.dart  (224 lines)
│   │   +-- [58] sentence_chunk.dart  (27 lines)
│   │   +-- [59] sentence_splitter.dart  (62 lines)
│   │   +-- [60] stream_processor_service.dart  (127 lines)
│   +-- [61] app_utils.dart  (25 lines)
│   +-- [62] extensions.dart  (94 lines)
│   +-- [63] logger.dart  (199 lines)
│   +-- [64] platform_utils.dart  (32 lines)
│   +-- [65] volume_fader.dart  (88 lines)
│   +-- [66] app_icon_button.dart  (120 lines)
│   +-- [67] constrained_width.dart  (27 lines)
│   +-- [68] current_prompt_text.dart  (30 lines)
│   +-- [69] function_calling_button.dart  (32 lines)
│   │   +-- [70] animated_icon_button.dart  (94 lines)
│   │   +-- [71] glassmorphic_text_field.dart  (269 lines)
│   +-- [72] picker_buttons.dart  (79 lines)
│   │   │   +-- [73] avatar_local_datasource.dart  (65 lines)
│   │   │   +-- [74] avatar_repository_impl.dart  (34 lines)
│   │   │   +-- [75] avatar_animation.dart  (34 lines)
│   │   │   +-- [76] avatar_cubit.dart  (250 lines)
│   │   │   +-- [77] avatar_state.dart  (37 lines)
│   │   +-- [78] animated_avatar.dart  (63 lines)
│   │   +-- [79] animated_background_avatar.dart  (48 lines)
│   │   +-- [80] avatar_widgets.dart  (143 lines)
│   │   +-- [81] background_avatar.dart  (42 lines)
│   │   +-- [82] base_avatar.dart  (66 lines)
│   │   +-- [83] blinking_eyes.dart  (73 lines)
│   │   +-- [84] clothes.dart  (61 lines)
│   │   │   +-- [85] costume_widget.dart  (45 lines)
│   │   │   +-- [86] robocop_animated_eyes.dart  (65 lines)
│   │   │   +-- [87] singularity_costume.dart  (144 lines)
│   │   │   +-- [88] soubrette_feather_duster.dart  (70 lines)
│   │   +-- [89] glowing_laser.dart  (34 lines)
│   │   +-- [90] loading_avatar_widget.dart  (19 lines)
│   │   +-- [91] scaled_avatar_item.dart  (94 lines)
│   │   +-- [92] talking_mouth.dart  (31 lines)
│   │   +-- [93] thinking_animation.dart  (30 lines)
│   │   │   +-- [94] chat_local_datasource.dart  (193 lines)
│   │   │   +-- [95] yofardev_repository_impl.dart  (159 lines)
│   │   │   +-- [96] chat_repository.dart  (24 lines)
│   │   │   +-- [97] chat_entry_service.dart  (43 lines)
│   │   │   +-- [98] chat_title_service.dart  (155 lines)
│   │   │   +-- [99] waiting_sentences_cache_datasource.dart  (38 lines)
│   │   │   +-- [100] chat_cubit.dart  (444 lines) (!)
│   │   │   +-- [101] chat_state.dart  (73 lines)
│   │   │   +-- [102] chat_tts_cubit.dart  (276 lines)
│   │   │   +-- [103] chat_tts_state.dart  (17 lines)
│   │   +-- [104] chat_details_screen.dart  (232 lines)
│   │   +-- [105] chats_list_screen.dart  (89 lines)
│   │   +-- [106] image_full_screen.dart  (23 lines)
│   │   │   +-- [107] ai_text_input.dart  (321 lines) (!)
│   │   │   +-- [108] picked_image_preview.dart  (26 lines)
│   │   +-- [109] chat_avatar.dart  (46 lines)
│   │   +-- [110] chat_card.dart  (168 lines)
│   │   +-- [111] chat_conversation_list.dart  (101 lines)
│   │   +-- [112] chat_details_actions.dart  (46 lines)
│   │   +-- [113] chat_details_background.dart  (59 lines)
│   │   +-- [114] chat_dismissible_background.dart  (39 lines)
│   │   +-- [115] chat_list_container.dart  (131 lines)
│   │   +-- [116] chat_list_empty_state.dart  (60 lines)
│   │   +-- [117] chat_list_item.dart  (58 lines)
│   │   +-- [118] chat_list_shimmer_loading.dart  (149 lines)
│   │   +-- [119] chat_message_item.dart  (226 lines)
│   │   +-- [120] chats_list_app_bar.dart  (69 lines)
│   │   +-- [121] floating_stop_button.dart  (63 lines)
│   │   +-- [122] function_calling_widget.dart  (54 lines)
│   │   +-- [123] modern_chat_bubble.dart  (169 lines)
│   │   │   +-- [124] demo_repository_impl.dart  (90 lines)
│   │   │   +-- [125] demo_repository.dart  (91 lines)
│   │   │   +-- [126] demo_cubit.dart  (49 lines)
│   │   │   +-- [127] demo_state.dart  (23 lines)
│   │   │   +-- [128] home_repository_impl.dart  (98 lines)
│   │   │   +-- [129] home_repository.dart  (25 lines)
│   │   │   +-- [130] home_cubit.dart  (56 lines)
│   │   │   +-- [131] home_state.dart  (12 lines)
│   │   +-- [132] home_screen.dart  (119 lines)
│   │   +-- [133] home_bloc_listeners.dart  (122 lines)
│   │   +-- [134] home_buttons.dart  (82 lines)
│   │   +-- [135] home_content_stack.dart  (72 lines)
│   │   │   +-- [136] settings_repository_impl.dart  (269 lines)
│   │   │   +-- [137] settings_cubit.dart  (348 lines) (!)
│   │   │   +-- [138] settings_state.dart  (34 lines)
│   │   +-- [139] function_calling_config_screen.dart  (246 lines)
│   │   │   +-- [140] llm_config_page.dart  (212 lines)
│   │   │   +-- [141] llm_selection_page.dart  (168 lines)
│   │   │   +-- [142] task_llm_config_page.dart  (177 lines)
│   │   │   │   +-- [143] styled_dropdown.dart  (173 lines)
│   │   │   │   +-- [144] task_dropdown.dart  (126 lines)
│   │   │   │   +-- [145] task_info_card.dart  (72 lines)
│   │   │   │   +-- [146] task_llm_app_bar.dart  (60 lines)
│   │   │   │   +-- [147] task_llm_background_layers.dart  (60 lines)
│   │   │   │   +-- [148] task_section_title.dart  (37 lines)
│   │   +-- [149] settings_screen.dart  (146 lines)
│   │   +-- [150] api_key_field.dart  (48 lines)
│   │   +-- [151] function_calling_config_tile.dart  (75 lines)
│   │   +-- [152] function_calling_section.dart  (78 lines)
│   │   +-- [153] persona_dropdown.dart  (120 lines)
│   │   +-- [154] settings_app_bar.dart  (68 lines)
│   │   +-- [155] sound_effects_toggle.dart  (75 lines)
│   │   +-- [156] task_llm_config_tile.dart  (72 lines)
│   │   +-- [157] username_field.dart  (56 lines)
│   │   │   +-- [158] tts_datasource.dart  (180 lines)
│   │   │   +-- [159] sound_repository_impl.dart  (48 lines)
│   │   │   +-- [160] sound_repository.dart  (7 lines)
│   │   +-- [161] tts_queue_item.dart  (23 lines)
│   │   │   +-- [162] sound_cubit.dart  (33 lines)
│   │   │   +-- [163] sound_state.dart  (12 lines)
│   │   │   +-- [164] talking_repository_impl.dart  (24 lines)
│   │   │   +-- [165] talking_repository.dart  (14 lines)
│   │   │   +-- [166] tts_playback_service.dart  (117 lines)
│   │   │   +-- [167] talking_cubit.dart  (177 lines)
│   │   │   +-- [168] talking_state.dart  (74 lines)
+-- [169] main.dart  (123 lines)
```

## Feature map
- **avatar**: data domain presentation
- **chat**: data domain presentation
- **demo**: data domain presentation
- **home**: data domain presentation
- **settings**: data domain presentation
- **sound**: data domain presentation
- **talking**: data domain presentation

## Core layout
⚠️  core/agent (missing — recommended for solid agent architecture)
⚠️  core/audio (missing — recommended for solid agent architecture)
⚠️  core/avatar (missing — recommended for solid agent architecture)
✅ core/di
⚠️  core/llm (missing — recommended for solid agent architecture)
✅ core/router
✅ core/models
✅ core/services
✅ core/utils
✅ core/widgets

## File size violations
_Limits: general ≤300 · service/repo/api ≤400_
- `lib/core/l10n/generated/app_localizations_fr.dart` — 311 lines (limit 300)
- `lib/core/l10n/generated/app_localizations.dart` — 662 lines (limit 300)
- `lib/core/l10n/generated/app_localizations_en.dart` — 304 lines (limit 300)
- `lib/core/services/llm/llm_service.dart` — 416 lines (limit 400)
- `lib/features/settings/presentation/bloc/settings_cubit.dart` — 348 lines (limit 300)
- `lib/features/chat/presentation/bloc/chat_cubit.dart` — 444 lines (limit 300)
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart` — 321 lines (limit 300)

## Cross-feature imports
✅ None

## Anti-pattern scan

**Hardcoded colors (use colorScheme)**
- `lib/core/res/app_theme.dart`
- `lib/core/res/app_colors.dart`
- `lib/core/widgets/current_prompt_text.dart`
- `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart`
- `lib/core/widgets/glassmorphic/animated_icon_button.dart`
- `lib/core/widgets/app_icon_button.dart`
- `lib/features/settings/screens/llm/task_llm_config_page.dart`
- `lib/features/settings/screens/llm/llm_selection_page.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_app_bar.dart`
- `lib/features/settings/screens/llm/widgets/task_info_card.dart`
- `lib/features/settings/screens/llm/widgets/task_dropdown.dart`
- `lib/features/settings/screens/llm/widgets/styled_dropdown.dart`
- `lib/features/settings/screens/llm/widgets/task_section_title.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_background_layers.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/settings/screens/function_calling_config_screen.dart`
- `lib/features/settings/widgets/username_field.dart`
- `lib/features/settings/widgets/sound_effects_toggle.dart`
- `lib/features/settings/widgets/api_key_field.dart`
- `lib/features/settings/widgets/function_calling_config_tile.dart`
- `lib/features/settings/widgets/persona_dropdown.dart`
- `lib/features/settings/widgets/task_llm_config_tile.dart`
- `lib/features/settings/widgets/settings_app_bar.dart`
- `lib/features/home/screens/home_screen.dart`
- `lib/features/chat/screens/chats_list_screen.dart`
- `lib/features/chat/widgets/chat_list_empty_state.dart`
- `lib/features/chat/widgets/chats_list_app_bar.dart`
- `lib/features/chat/widgets/chat_list_shimmer_loading.dart`
- `lib/features/chat/widgets/modern_chat_bubble.dart`
- `lib/features/chat/widgets/chat_list_item.dart`
- `lib/features/chat/widgets/chat_card.dart`
- `lib/features/chat/widgets/chat_conversation_list.dart`
- `lib/features/chat/widgets/chat_details_background.dart`
- `lib/features/chat/widgets/chat_avatar.dart`
- `lib/features/chat/widgets/chat_list_container.dart`
- `lib/features/chat/widgets/chat_dismissible_background.dart`
- `lib/features/chat/widgets/chat_message_item.dart`
- `lib/features/avatar/widgets/costumes/singularity_costume.dart`
- `lib/features/avatar/widgets/glowing_laser.dart`

**Widget helper methods (extract to class)**
- `lib/features/settings/screens/function_calling_config_screen.dart:229:  Widget _buildTextField({`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart:195:  Widget _buildTextField({`
- `lib/features/avatar/widgets/avatar_widgets.dart:117:  Widget _buildAnimatedAvatar(AvatarState state, TalkingState talkingState) {`

## DI wiring integrity
✅ `lib/core/di/service_locator.dart` — 45 registration(s)
✅ No dual wiring detected

## Cubit coupling analysis
**Cubit count per feature** (>2 warrants review):
- ✅ avatar: 1
- ✅ chat: 2
- ✅ demo: 1
- ✅ home: 1
- ✅ settings: 1
- ✅ sound: 1
- ✅ talking: 1

**Cubit-to-cubit dependencies** (should be 0 — use domain services instead):
✅ None detected

## Routing
✅ `lib/core/router/app_router.dart` — 9 route(s)
path: RouteConstants.home, path: RouteConstants.chats, path: ':id', path: RouteConstants.settings, path: 'llm', path: 'config/:id', path: 'task-llm', path: 'function-calling', path: RouteConstants.imageFullScreen, 

## Test coverage
Total: 37  |  BLoC/Cubit: 6  |  Widget/Screen: 3  |  Repo: 1

- ✅ avatar (10 file(s))
- ✅ chat (70 file(s))
- ❌ demo (no tests)
- ❌ home (no tests)
- ✅ settings (3 file(s))
- ✅ sound (3 file(s))
- ✅ talking (2 file(s))
