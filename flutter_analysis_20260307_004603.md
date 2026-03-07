# Flutter Pre-Analysis — 2026-03-07
_Project: `/home/yofardev/Dev/yofardev_ai`_

## File tree
_Features: avatar chat demo home settings sound talking_

```
│   +-- [1] service_locator.dart  (212 lines)
│   +-- [2] answer.dart  (16 lines)
│   +-- [3] avatar_config.dart  (287 lines)
│   +-- [4] chat.dart  (11 lines)
│   +-- [5] function_info.dart  (35 lines)
│   +-- [6] llm_config.dart  (75 lines)
│   +-- [7] llm_message.dart  (17 lines)
│   +-- [8] llm_task_type.dart  (11 lines)
│   +-- [9] sound_effects.dart  (59 lines)
│   +-- [10] task_llm_config.dart  (22 lines)
│   +-- [11] voice_effect.dart  (17 lines)
│   +-- [12] app_colors.dart  (41 lines)
│   +-- [13] app_constants.dart  (37 lines)
│   +-- [14] app_theme.dart  (259 lines)
│   +-- [15] app_router.dart  (103 lines)
│   +-- [16] route_constants.dart  (20 lines)
│   │   +-- [17] agent_tool.dart  (26 lines)
│   │   +-- [18] alarm_service.dart  (43 lines)
│   │   +-- [19] alarm_tool.dart  (36 lines)
│   │   +-- [20] calculator_tool.dart  (43 lines)
│   │   +-- [21] character_counter_tool.dart  (40 lines)
│   │   +-- [22] google_search_service.dart  (67 lines)
│   │   +-- [23] google_search_tool.dart  (30 lines)
│   │   +-- [24] news_service.dart  (34 lines)
│   │   +-- [25] news_tool.dart  (22 lines)
│   │   +-- [26] tool_registry.dart  (39 lines)
│   │   +-- [27] weather_service.dart  (90 lines)
│   │   +-- [28] weather_tool.dart  (27 lines)
│   │   +-- [29] web_reader_tool.dart  (54 lines)
│   │   +-- [30] yofardev_agent.dart  (251 lines)
│   │   +-- [31] audio_amplitude_service.dart  (35 lines)
│   │   +-- [32] audio_player_service.dart  (63 lines)
│   │   +-- [33] interruption_service.dart  (47 lines)
│   │   +-- [34] tts_service.dart  (33 lines)
│   +-- [35] demo_controller.dart  (81 lines)
│   │   +-- [36] fake_llm_service.dart  (215 lines)
│   │   +-- [37] llm_config_manager.dart  (159 lines)
│   │   +-- [38] llm_service.dart  (483 lines) (!)
│   │   +-- [39] llm_service_interface.dart  (79 lines)
│   │   +-- [40] llm_stream_chunk.dart  (23 lines)
│   +-- [41] prompt_datasource.dart  (80 lines)
│   +-- [42] settings_local_datasource.dart  (148 lines)
│   │   +-- [43] json_stream_extractor.dart  (98 lines)
│   │   +-- [44] sentence_chunk.dart  (27 lines)
│   │   +-- [45] sentence_splitter.dart  (64 lines)
│   │   +-- [46] stream_processor_service.dart  (127 lines)
│   +-- [47] app_utils.dart  (25 lines)
│   +-- [48] extensions.dart  (94 lines)
│   +-- [49] logger.dart  (199 lines)
│   +-- [50] platform_utils.dart  (27 lines)
│   +-- [51] app_icon_button.dart  (120 lines)
│   +-- [52] constrained_width.dart  (22 lines)
│   +-- [53] current_prompt_text.dart  (30 lines)
│   +-- [54] function_calling_button.dart  (32 lines)
│   │   +-- [55] animated_icon_button.dart  (94 lines)
│   │   +-- [56] glassmorphic_text_field.dart  (269 lines)
│   +-- [57] picker_buttons.dart  (79 lines)
│   │   +-- [58] avatar_cubit.dart  (128 lines)
│   │   +-- [59] avatar_state.dart  (33 lines)
│   │   │   +-- [60] avatar_cache_datasource.dart  (38 lines)
│   │   │   +-- [61] avatar_local_datasource.dart  (65 lines)
│   │   │   +-- [62] avatar_repository_impl.dart  (31 lines)
│   │   │   +-- [63] avatar_repository.dart  (8 lines)
│   │   +-- [64] animated_avatar.dart  (38 lines)
│   │   +-- [65] avatar_widgets.dart  (120 lines)
│   │   +-- [66] background_avatar.dart  (24 lines)
│   │   +-- [67] base_avatar.dart  (66 lines)
│   │   +-- [68] blinking_eyes.dart  (73 lines)
│   │   +-- [69] clothes.dart  (61 lines)
│   │   │   +-- [70] costume_widget.dart  (42 lines)
│   │   │   +-- [71] robocop_animated_eyes.dart  (65 lines)
│   │   │   +-- [72] singularity_costume.dart  (155 lines)
│   │   │   +-- [73] soubrette_feather_duster.dart  (70 lines)
│   │   +-- [74] glowing_laser.dart  (34 lines)
│   │   +-- [75] loading_avatar_widget.dart  (19 lines)
│   │   +-- [76] scaled_avatar_item.dart  (84 lines)
│   │   +-- [77] talking_mouth.dart  (33 lines)
│   │   +-- [78] thinking_animation.dart  (30 lines)
│   │   +-- [79] chat_list_cubit.dart  (206 lines)
│   │   +-- [80] chat_list_state.dart  (26 lines)
│   │   +-- [81] chat_message_cubit.dart  (398 lines) (!)
│   │   +-- [82] chat_message_state.dart  (29 lines)
│   │   +-- [83] chats_cubit.dart  (315 lines) (!)
│   │   +-- [84] chats_state.dart  (50 lines)
│   │   +-- [85] chat_title_cubit.dart  (146 lines)
│   │   +-- [86] chat_title_state.dart  (21 lines)
│   │   +-- [87] chat_tts_cubit.dart  (186 lines)
│   │   +-- [88] chat_tts_state.dart  (16 lines)
│   │   │   +-- [89] chat_local_datasource.dart  (182 lines)
│   │   │   +-- [90] yofardev_repository_impl.dart  (144 lines)
│   │   │   +-- [91] chat.dart  (97 lines)
│   │   │   +-- [92] chat_entry.dart  (124 lines)
│   │   │   +-- [93] chat_repository.dart  (24 lines)
│   │   +-- [94] chat_details_screen.dart  (242 lines)
│   │   +-- [95] chats_list_screen.dart  (76 lines)
│   │   +-- [96] image_full_screen.dart  (23 lines)
│   │   │   +-- [97] ai_text_input.dart  (303 lines) (!)
│   │   │   +-- [98] picked_image_preview.dart  (29 lines)
│   │   +-- [99] chat_avatar.dart  (46 lines)
│   │   +-- [100] chat_card.dart  (168 lines)
│   │   +-- [101] chat_conversation_list.dart  (101 lines)
│   │   +-- [102] chat_details_actions.dart  (46 lines)
│   │   +-- [103] chat_details_background.dart  (59 lines)
│   │   +-- [104] chat_dismissible_background.dart  (39 lines)
│   │   +-- [105] chat_list_container.dart  (132 lines)
│   │   +-- [106] chat_list_empty_state.dart  (60 lines)
│   │   +-- [107] chat_list_item.dart  (58 lines)
│   │   +-- [108] chat_message_item.dart  (223 lines)
│   │   +-- [109] chats_list_app_bar.dart  (69 lines)
│   │   +-- [110] floating_stop_button.dart  (41 lines)
│   │   +-- [111] function_calling_widget.dart  (54 lines)
│   │   +-- [112] modern_chat_bubble.dart  (179 lines)
│   │   +-- [113] demo_cubit.dart  (49 lines)
│   │   +-- [114] demo_state.dart  (23 lines)
│   │   │   +-- [115] demo_repository_impl.dart  (96 lines)
│   │   │   +-- [116] demo_script.dart  (124 lines)
│   │   │   +-- [117] demo_repository.dart  (91 lines)
│   │   │   +-- [118] home_repository_impl.dart  (80 lines)
│   │   │   +-- [119] home_repository.dart  (19 lines)
│   │   │   +-- [120] home_cubit.dart  (55 lines)
│   │   │   +-- [121] home_state.dart  (12 lines)
│   │   +-- [122] home_screen.dart  (80 lines)
│   │   +-- [123] home_bloc_listeners.dart  (106 lines)
│   │   +-- [124] home_buttons.dart  (82 lines)
│   │   +-- [125] home_content_stack.dart  (60 lines)
│   │   +-- [126] settings_cubit.dart  (115 lines)
│   │   +-- [127] settings_state.dart  (17 lines)
│   │   │   +-- [128] settings_repository_impl.dart  (131 lines)
│   │   │   +-- [129] settings_repository.dart  (24 lines)
│   │   │   +-- [130] llm_config_page.dart  (181 lines)
│   │   │   +-- [131] llm_selection_page.dart  (164 lines)
│   │   │   +-- [132] task_llm_config_page.dart  (167 lines)
│   │   │   │   +-- [133] styled_dropdown.dart  (173 lines)
│   │   │   │   +-- [134] task_dropdown.dart  (126 lines)
│   │   │   │   +-- [135] task_info_card.dart  (72 lines)
│   │   │   │   +-- [136] task_llm_app_bar.dart  (60 lines)
│   │   │   │   +-- [137] task_llm_background_layers.dart  (60 lines)
│   │   │   │   +-- [138] task_section_title.dart  (37 lines)
│   │   +-- [139] settings_screen.dart  (135 lines)
│   │   +-- [140] api_key_field.dart  (47 lines)
│   │   +-- [141] persona_dropdown.dart  (90 lines)
│   │   +-- [142] settings_app_bar.dart  (68 lines)
│   │   +-- [143] sound_effects_toggle.dart  (75 lines)
│   │   +-- [144] task_llm_config_tile.dart  (71 lines)
│   │   +-- [145] username_field.dart  (56 lines)
│   │   +-- [146] sound_cubit.dart  (33 lines)
│   │   +-- [147] sound_state.dart  (12 lines)
│   │   │   +-- [148] tts_datasource.dart  (180 lines)
│   │   │   +-- [149] sound_repository_impl.dart  (45 lines)
│   │   │   +-- [150] sound_repository.dart  (7 lines)
│   │   +-- [151] tts_queue_item.dart  (23 lines)
│   │   +-- [152] tts_queue_manager.dart  (205 lines)
│   │   │   +-- [153] talking_repository_impl.dart  (24 lines)
│   │   │   +-- [154] talking_repository.dart  (14 lines)
│   │   │   +-- [155] talking_cubit.dart  (208 lines)
│   │   │   +-- [156] talking_state.dart  (74 lines)
+-- [157] app_localization_delegate.dart  (30 lines)
+-- [158] language_en.dart  (78 lines)
+-- [159] language_fr.dart  (81 lines)
+-- [160] languages.dart  (44 lines)
+-- [161] localization_manager.dart  (44 lines)
+-- [162] main.dart  (124 lines)
```

## Feature map
- **avatar**: data domain 
- **chat**: data domain 
- **demo**: data domain 
- **home**: data domain presentation
- **settings**: data domain 
- **sound**: data domain 
- **talking**: data domain presentation

## Core layout
✅ core/di
✅ core/router
✅ core/models
✅ core/services
✅ core/utils
✅ core/widgets

## File size violations
_Limits: general ≤300 · service/repo/api ≤400_
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart` — 303 lines (limit 300)
- `lib/features/chat/bloc/chats_cubit.dart` — 315 lines (limit 300)
- `lib/features/chat/bloc/chat_message_cubit.dart` — 398 lines (limit 300)
- `lib/core/services/llm/llm_service.dart` — 483 lines (limit 400)

## Cross-feature imports
✅ None

## Anti-pattern scan

**Hardcoded colors (use colorScheme)**
- `lib/features/chat/widgets/chat_avatar.dart`
- `lib/features/chat/widgets/chat_list_item.dart`
- `lib/features/chat/widgets/chats_list_app_bar.dart`
- `lib/features/chat/widgets/chat_card.dart`
- `lib/features/chat/widgets/chat_list_container.dart`
- `lib/features/chat/widgets/modern_chat_bubble.dart`
- `lib/features/chat/widgets/chat_message_item.dart`
- `lib/features/chat/widgets/chat_list_empty_state.dart`
- `lib/features/chat/widgets/chat_dismissible_background.dart`
- `lib/features/chat/widgets/chat_details_background.dart`
- `lib/features/chat/widgets/chat_conversation_list.dart`
- `lib/features/chat/screens/chats_list_screen.dart`
- `lib/features/home/screens/home_screen.dart`
- `lib/features/avatar/widgets/costumes/singularity_costume.dart`
- `lib/features/avatar/widgets/glowing_laser.dart`
- `lib/features/settings/widgets/api_key_field.dart`
- `lib/features/settings/widgets/username_field.dart`
- `lib/features/settings/widgets/sound_effects_toggle.dart`
- `lib/features/settings/widgets/task_llm_config_tile.dart`
- `lib/features/settings/widgets/persona_dropdown.dart`
- `lib/features/settings/widgets/settings_app_bar.dart`
- `lib/features/settings/screens/llm/task_llm_config_page.dart`
- `lib/features/settings/screens/llm/widgets/task_info_card.dart`
- `lib/features/settings/screens/llm/widgets/styled_dropdown.dart`
- `lib/features/settings/screens/llm/widgets/task_section_title.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_app_bar.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_background_layers.dart`
- `lib/features/settings/screens/llm/widgets/task_dropdown.dart`
- `lib/features/settings/screens/llm/llm_selection_page.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/core/widgets/constrained_width.dart`
- `lib/core/widgets/glassmorphic/animated_icon_button.dart`
- `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart`
- `lib/core/widgets/app_icon_button.dart`
- `lib/core/widgets/current_prompt_text.dart`
- `lib/core/res/app_colors.dart`
- `lib/core/res/app_theme.dart`

**Widget helper methods (extract to class)**
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart:179:  Widget _buildTextField({`
- `lib/features/avatar/widgets/avatar_widgets.dart:105:  Widget _buildAnimatedAvatar(AvatarState state) {`

## Routing
✅ `lib/core/router/app_router.dart` — 8 route(s)
path: RouteConstants.home, path: RouteConstants.chats, path: ':id', path: RouteConstants.settings, path: 'llm', path: 'config', path: 'task-llm', path: RouteConstants.imageFullScreen, 

## Test coverage
Total: 25  |  BLoC/Cubit: 8  |  Widget/Screen: 1  |  Repo: 0

- ✅ avatar (3 file(s))
- ✅ chat (8 file(s))
- ❌ demo (no tests)
- ❌ home (no tests)
- ✅ settings (2 file(s))
- ✅ sound (3 file(s))
- ✅ talking (3 file(s))
