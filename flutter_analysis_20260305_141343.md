# Flutter Pre-Analysis — 2026-03-05
_Project: `/Users/yofardev/development/Projects/Flutter/yofardev_ai`_

## File tree
_Features: avatar chat demo home settings sound talking_

```
│   +-- [1] injection.dart  (20 lines)
│   +-- [2] service_locator.dart  (164 lines)
│   +-- [3] answer.dart  (16 lines)
│   +-- [4] avatar_config.dart  (287 lines)
│   +-- [5] function_info.dart  (35 lines)
│   +-- [6] llm_config.dart  (75 lines)
│   +-- [7] llm_message.dart  (17 lines)
│   +-- [8] llm_task_type.dart  (11 lines)
│   +-- [9] sound_effects.dart  (59 lines)
│   +-- [10] task_llm_config.dart  (22 lines)
│   +-- [11] app_colors.dart  (41 lines)
│   +-- [12] app_constants.dart  (37 lines)
│   +-- [13] app_theme.dart  (259 lines)
│   +-- [14] app_router.dart  (109 lines)
│   +-- [15] route_constants.dart  (20 lines)
│   │   +-- [16] agent_tool.dart  (26 lines)
│   │   +-- [17] alarm_service.dart  (43 lines)
│   │   +-- [18] alarm_tool.dart  (36 lines)
│   │   +-- [19] calculator_tool.dart  (43 lines)
│   │   +-- [20] character_counter_tool.dart  (40 lines)
│   │   +-- [21] google_search_service.dart  (67 lines)
│   │   +-- [22] google_search_tool.dart  (30 lines)
│   │   +-- [23] news_service.dart  (34 lines)
│   │   +-- [24] news_tool.dart  (22 lines)
│   │   +-- [25] tool_registry.dart  (39 lines)
│   │   +-- [26] weather_service.dart  (90 lines)
│   │   +-- [27] weather_tool.dart  (27 lines)
│   │   +-- [28] web_reader_tool.dart  (54 lines)
│   │   +-- [29] yofardev_agent.dart  (239 lines)
│   │   +-- [30] audio_amplitude_service.dart  (35 lines)
│   │   +-- [31] tts_service.dart  (39 lines)
│   +-- [32] demo_controller.dart  (53 lines)
│   │   +-- [33] fake_llm_service.dart  (239 lines)
│   │   +-- [34] llm_config_manager.dart  (159 lines)
│   │   +-- [35] llm_exceptions.dart  (8 lines)
│   │   +-- [36] llm_service.dart  (415 lines) (!)
│   │   +-- [37] llm_service_interface.dart  (75 lines)
│   │   +-- [38] llm_stream_chunk.dart  (23 lines)
│   │   +-- [39] json_stream_extractor.dart  (75 lines)
│   │   +-- [40] sentence_chunk.dart  (27 lines)
│   │   +-- [41] sentence_splitter.dart  (64 lines)
│   │   +-- [42] stream_processor_service.dart  (126 lines)
│   +-- [43] app_utils.dart  (25 lines)
│   +-- [44] extensions.dart  (94 lines)
│   +-- [45] logger.dart  (199 lines)
│   +-- [46] platform_utils.dart  (27 lines)
│   +-- [47] app_icon_button.dart  (120 lines)
│   +-- [48] constrained_width.dart  (21 lines)
│   +-- [49] current_prompt_text.dart  (28 lines)
│   +-- [50] function_calling_button.dart  (32 lines)
│   │   +-- [51] animated_icon_button.dart  (94 lines)
│   │   +-- [52] glassmorphic_text_field.dart  (269 lines)
│   +-- [53] picker_buttons.dart  (79 lines)
│   │   +-- [54] avatar_cubit.dart  (129 lines)
│   │   +-- [55] avatar_state.dart  (33 lines)
│   │   │   +-- [56] avatar_cache_datasource.dart  (38 lines)
│   │   │   +-- [57] avatar_local_datasource.dart  (65 lines)
│   │   │   +-- [58] avatar_repository_impl.dart  (31 lines)
│   │   │   +-- [59] avatar_repository.dart  (8 lines)
│   │   +-- [60] avatar_widgets.dart  (133 lines)
│   │   +-- [61] background_avatar.dart  (24 lines)
│   │   +-- [62] base_avatar.dart  (66 lines)
│   │   +-- [63] blinking_eyes.dart  (73 lines)
│   │   +-- [64] clothes.dart  (61 lines)
│   │   │   +-- [65] costume_widget.dart  (42 lines)
│   │   │   +-- [66] robocop_animated_eyes.dart  (65 lines)
│   │   │   +-- [67] singularity_costume.dart  (154 lines)
│   │   │   +-- [68] soubrette_feather_duster.dart  (70 lines)
│   │   +-- [69] glowing_laser.dart  (32 lines)
│   │   +-- [70] loading_avatar_widget.dart  (20 lines)
│   │   +-- [71] scaled_avatar_item.dart  (84 lines)
│   │   +-- [72] talking_mouth.dart  (62 lines)
│   │   +-- [73] thinking_animation.dart  (30 lines)
│   │   +-- [74] chat_list_cubit.dart  (206 lines)
│   │   +-- [75] chat_list_state.dart  (26 lines)
│   │   +-- [76] chat_message_cubit.dart  (405 lines) (!)
│   │   +-- [77] chat_message_state.dart  (21 lines)
│   │   +-- [78] chat_title_cubit.dart  (142 lines)
│   │   +-- [79] chat_title_state.dart  (21 lines)
│   │   +-- [80] chats_cubit.dart  (807 lines) (!)
│   │   +-- [81] chats_state.dart  (50 lines)
│   │   │   +-- [82] chat_local_datasource.dart  (182 lines)
│   │   │   +-- [83] yofardev_repository_impl.dart  (144 lines)
│   │   │   +-- [84] chat.dart  (104 lines)
│   │   │   +-- [85] chat_entry.dart  (112 lines)
│   │   │   +-- [86] chat_repository.dart  (24 lines)
│   │   +-- [87] chat_details_screen.dart  (223 lines)
│   │   +-- [88] chats_list_screen.dart  (133 lines)
│   │   +-- [89] image_full_screen.dart  (22 lines)
│   │   │   +-- [90] ai_text_input.dart  (300 lines)
│   │   +-- [91] chat_app_bar.dart  (62 lines)
│   │   +-- [92] chat_avatar.dart  (46 lines)
│   │   +-- [93] chat_conversation_list.dart  (101 lines)
│   │   +-- [94] chat_details_actions.dart  (46 lines)
│   │   +-- [95] chat_details_background.dart  (59 lines)
│   │   +-- [96] chat_list_container.dart  (132 lines)
│   │   +-- [97] chat_list_empty_state.dart  (60 lines)
│   │   +-- [98] chat_list_item.dart  (198 lines)
│   │   +-- [99] chat_message_item.dart  (222 lines)
│   │   +-- [100] function_calling_widget.dart  (53 lines)
│   │   +-- [101] message_bubble.dart  (234 lines)
│   │   +-- [102] message_list.dart  (84 lines)
│   │   +-- [103] modern_chat_bubble.dart  (179 lines)
│   │   +-- [104] demo_cubit.dart  (49 lines)
│   │   +-- [105] demo_state.dart  (23 lines)
│   │   │   +-- [106] demo_controller.dart  (87 lines)
│   │   │   +-- [107] demo_repository_impl.dart  (96 lines)
│   │   │   +-- [108] demo_script.dart  (124 lines)
│   │   │   +-- [109] demo_repository.dart  (91 lines)
│   │   +-- [110] demo_page.dart  (119 lines)
│   │   +-- [111] demo_controls_widget.dart  (146 lines)
│   │   +-- [112] demo_countdown_overlay.dart  (57 lines)
│   │   +-- [113] demo_status_indicator.dart  (61 lines)
│   │   +-- [114] home_cubit.dart  (81 lines)
│   │   +-- [115] home_state.dart  (12 lines)
│   │   │   +-- [116] prompt_datasource.dart  (80 lines)
│   │   +-- [117] home_screen.dart  (81 lines)
│   │   +-- [118] home_bloc_listeners.dart  (95 lines)
│   │   +-- [119] home_buttons.dart  (82 lines)
│   │   +-- [120] home_content_stack.dart  (67 lines)
│   │   +-- [121] settings_cubit.dart  (71 lines)
│   │   +-- [122] settings_state.dart  (17 lines)
│   │   │   +-- [123] settings_local_datasource.dart  (148 lines)
│   │   │   +-- [124] settings_repository_impl.dart  (131 lines)
│   │   │   +-- [125] settings_repository.dart  (24 lines)
│   │   │   +-- [126] llm_config_page.dart  (180 lines)
│   │   │   +-- [127] llm_selection_page.dart  (163 lines)
│   │   │   +-- [128] task_llm_config_page.dart  (515 lines) (!)
│   │   │   │   +-- [129] task_llm_app_bar.dart  (60 lines)
│   │   │   │   +-- [130] task_llm_background_layers.dart  (60 lines)
│   │   +-- [131] settings_screen.dart  (216 lines)
│   │   +-- [132] api_key_field.dart  (47 lines)
│   │   +-- [133] persona_dropdown.dart  (90 lines)
│   │   +-- [134] settings_app_bar.dart  (68 lines)
│   │   +-- [135] sound_effects_toggle.dart  (75 lines)
│   │   +-- [136] username_field.dart  (56 lines)
│   │   +-- [137] sound_cubit.dart  (33 lines)
│   │   +-- [138] sound_state.dart  (12 lines)
│   │   │   +-- [139] tts_datasource.dart  (186 lines)
│   │   │   +-- [140] sound_repository_impl.dart  (45 lines)
│   │   │   +-- [141] sound_repository.dart  (7 lines)
│   │   +-- [142] tts_queue_item.dart  (23 lines)
│   │   +-- [143] tts_queue_manager.dart  (180 lines)
│   │   +-- [144] talking_cubit.dart  (59 lines)
│   │   +-- [145] talking_state.dart  (60 lines)
+-- [146] app_localization_delegate.dart  (30 lines)
+-- [147] language_en.dart  (70 lines)
+-- [148] language_fr.dart  (73 lines)
+-- [149] languages.dart  (40 lines)
+-- [150] localization_manager.dart  (44 lines)
+-- [151] main.dart  (106 lines)
```

## Feature map
- **avatar**: data domain 
- **chat**: data domain 
- **demo**: data domain 
- **home**: data 
- **settings**: data domain 
- **sound**: data domain 
- **talking**: ⚠️ no standard layers

## Core layout
✅ core/di
✅ core/router
✅ core/models
✅ core/services
✅ core/utils
✅ core/widgets

## File size violations
_Limits: general ≤300 · service/repo/api ≤400_
- `lib/core/services/llm/llm_service.dart` — 415 lines (limit 400)
- `lib/features/settings/screens/llm/task_llm_config_page.dart` — 515 lines (limit 300)
- `lib/features/chat/bloc/chats_cubit.dart` — 807 lines (limit 300)
- `lib/features/chat/bloc/chat_message_cubit.dart` — 405 lines (limit 300)

## Cross-feature imports
✅ None

## Anti-pattern scan

**Hardcoded colors (use colorScheme)**
- `lib/core/res/app_theme.dart`
- `lib/core/res/app_colors.dart`
- `lib/core/widgets/current_prompt_text.dart`
- `lib/core/widgets/constrained_width.dart`
- `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart`
- `lib/core/widgets/glassmorphic/animated_icon_button.dart`
- `lib/core/widgets/app_icon_button.dart`
- `lib/features/demo/screens/demo_page.dart`
- `lib/features/demo/widgets/demo_status_indicator.dart`
- `lib/features/demo/widgets/demo_countdown_overlay.dart`
- `lib/features/settings/screens/llm/task_llm_config_page.dart`
- `lib/features/settings/screens/llm/llm_selection_page.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_app_bar.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_background_layers.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/settings/widgets/username_field.dart`
- `lib/features/settings/widgets/sound_effects_toggle.dart`
- `lib/features/settings/widgets/api_key_field.dart`
- `lib/features/settings/widgets/persona_dropdown.dart`
- `lib/features/settings/widgets/settings_app_bar.dart`
- `lib/features/home/screens/home_screen.dart`
- `lib/features/chat/screens/chats_list_screen.dart`
- `lib/features/chat/screens/image_full_screen.dart`
- `lib/features/chat/widgets/chat_list_empty_state.dart`
- `lib/features/chat/widgets/message_bubble.dart`
- `lib/features/chat/widgets/modern_chat_bubble.dart`
- `lib/features/chat/widgets/chat_list_item.dart`
- `lib/features/chat/widgets/message_list.dart`
- `lib/features/chat/widgets/chat_conversation_list.dart`
- `lib/features/chat/widgets/chat_details_background.dart`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart`
- `lib/features/chat/widgets/chat_avatar.dart`
- `lib/features/chat/widgets/chat_list_container.dart`
- `lib/features/chat/widgets/chat_message_item.dart`
- `lib/features/chat/widgets/function_calling_widget.dart`
- `lib/features/avatar/widgets/costumes/singularity_costume.dart`
- `lib/features/avatar/widgets/glowing_laser.dart`
- `lib/features/avatar/widgets/loading_avatar_widget.dart`

**print / debugPrint (use AppLogger)**
- `lib/core/services/audio/tts_service.dart`

**BuildContext in cubits/blocs**
- `lib/l10n/languages.dart`
- `lib/core/widgets/current_prompt_text.dart`
- `lib/core/widgets/picker_buttons.dart`
- `lib/core/widgets/function_calling_button.dart`
- `lib/core/widgets/constrained_width.dart`
- `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart`
- `lib/core/widgets/glassmorphic/animated_icon_button.dart`
- `lib/core/widgets/app_icon_button.dart`
- `lib/core/router/app_router.dart`
- `lib/features/demo/screens/demo_page.dart`
- `lib/features/demo/domain/repositories/demo_repository.dart`
- `lib/features/demo/widgets/demo_status_indicator.dart`
- `lib/features/demo/widgets/demo_controls_widget.dart`
- `lib/features/demo/widgets/demo_countdown_overlay.dart`
- `lib/features/settings/screens/llm/llm_config_page.dart`
- `lib/features/settings/screens/llm/task_llm_config_page.dart`
- `lib/features/settings/screens/llm/llm_selection_page.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_app_bar.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_background_layers.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/settings/widgets/username_field.dart`
- `lib/features/settings/widgets/sound_effects_toggle.dart`
- `lib/features/settings/widgets/api_key_field.dart`
- `lib/features/settings/widgets/persona_dropdown.dart`
- `lib/features/settings/widgets/settings_app_bar.dart`
- `lib/features/home/screens/home_screen.dart`
- `lib/features/home/widgets/home_content_stack.dart`
- `lib/features/home/widgets/home_buttons.dart`
- `lib/features/home/widgets/home_bloc_listeners.dart`
- `lib/features/chat/screens/chat_details_screen.dart`
- `lib/features/chat/screens/chats_list_screen.dart`
- `lib/features/chat/screens/image_full_screen.dart`
- `lib/features/chat/widgets/chat_list_empty_state.dart`
- `lib/features/chat/widgets/chat_app_bar.dart`
- `lib/features/chat/widgets/message_bubble.dart`
- `lib/features/chat/widgets/modern_chat_bubble.dart`
- `lib/features/chat/widgets/chat_list_item.dart`
- `lib/features/chat/widgets/message_list.dart`
- `lib/features/chat/widgets/chat_conversation_list.dart`
- `lib/features/chat/widgets/chat_details_actions.dart`
- `lib/features/chat/widgets/chat_details_background.dart`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart`
- `lib/features/chat/widgets/chat_avatar.dart`
- `lib/features/chat/widgets/chat_list_container.dart`
- `lib/features/chat/widgets/chat_message_item.dart`
- `lib/features/chat/widgets/function_calling_widget.dart`
- `lib/features/avatar/widgets/scaled_avatar_item.dart`
- `lib/features/avatar/widgets/background_avatar.dart`
- `lib/features/avatar/widgets/talking_mouth.dart`
- `lib/features/avatar/widgets/base_avatar.dart`
- `lib/features/avatar/widgets/clothes.dart`
- `lib/features/avatar/widgets/costumes/robocop_animated_eyes.dart`
- `lib/features/avatar/widgets/costumes/singularity_costume.dart`
- `lib/features/avatar/widgets/costumes/costume_widget.dart`
- `lib/features/avatar/widgets/costumes/soubrette_feather_duster.dart`
- `lib/features/avatar/widgets/blinking_eyes.dart`
- `lib/features/avatar/widgets/avatar_widgets.dart`
- `lib/features/avatar/widgets/thinking_animation.dart`
- `lib/features/avatar/widgets/loading_avatar_widget.dart`
- `lib/main.dart`

**return null on failure (use Either)**
- `lib/core/res/app_theme.dart:96:            return null;`
- `lib/core/res/app_theme.dart:115:            return null;`
- `lib/core/utils/extensions.dart:68:      return null;`
- `lib/core/utils/logger.dart:197:    return null;`
- `lib/core/models/avatar_config.dart:197:    if (json == null) return null;`
- `lib/core/models/sound_effects.dart:39:      return null;`
- `lib/core/services/llm/llm_config_manager.dart:46:      return null;`
- `lib/core/services/llm/llm_config_manager.dart:52:      return null;`
- `lib/core/services/llm/llm_service.dart:132:        return null;`
- `lib/core/services/llm/llm_service.dart:136:      return null;`
- `lib/core/services/llm/llm_service.dart:387:        return null;`
- `lib/core/services/llm/fake_llm_service.dart:61:    if (!_isActive || !hasMore) return null;`
- `lib/core/services/llm/fake_llm_service.dart:79:    if (!_isActive || !hasMore) return null;`
- `lib/core/services/llm/fake_llm_service.dart:106:    return null;`
- `lib/core/services/agent/tool_registry.dart:31:      return null;`
- `lib/core/services/stream_processor/json_stream_extractor.dart:60:    return null;`
- `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart:265:    if (icons.isEmpty) return null;`
- `lib/features/demo/domain/models/demo_script.dart:121:      return null;`
- `lib/features/chat/data/datasources/chat_local_datasource.dart:49:    if (chatJson == null) return null;`
- `lib/features/chat/bloc/chats_cubit.dart:355:          return null;`
- `lib/features/chat/bloc/chats_cubit.dart:387:      return null;`
- `lib/features/chat/bloc/chats_cubit.dart:516:        return null;`
- `lib/features/chat/bloc/chat_title_cubit.dart:124:      return null;`
- `lib/features/chat/bloc/chat_message_cubit.dart:70:    return null;`
- `lib/features/chat/bloc/chat_message_cubit.dart:147:          return null;`
- `lib/features/chat/bloc/chat_message_cubit.dart:172:      return null;`
- `lib/features/chat/bloc/chat_list_cubit.dart:185:      return null;`
- `lib/features/chat/bloc/chat_list_cubit.dart:195:      return null;`
- `lib/features/chat/bloc/chat_list_cubit.dart:203:      return null;`
- `lib/features/avatar/data/datasources/avatar_local_datasource.dart:21:      if (chatJson == null) return null;`
- `lib/features/avatar/data/datasources/avatar_local_datasource.dart:32:      return null;`
- `lib/features/avatar/data/datasources/avatar_cache_datasource.dart:13:    if (list == null) return null;`

**Widget helper methods (extract to class)**
- `lib/features/settings/screens/llm/task_llm_config_page.dart:162:  Widget _buildSectionTitle(String title, Animation<double> animation) {`
- `lib/features/settings/screens/llm/task_llm_config_page.dart:184:  Widget _buildInfoCard(Animation<double> animation) {`
- `lib/features/settings/screens/llm/task_llm_config_page.dart:246:  Widget _buildTaskDropdown({`
- `lib/features/settings/screens/settings_screen.dart:86:  Widget _buildTaskLlmConfigTile(BuildContext context) {`
- `lib/features/chat/screens/chats_list_screen.dart:78:  Widget _buildAppBar(BuildContext context) {`
- `lib/features/chat/widgets/chat_list_item.dart:39:  Widget _buildDismissibleChatTile(BuildContext context) {`
- `lib/features/chat/widgets/chat_list_item.dart:57:  Widget _buildDismissableBackground() {`
- `lib/features/chat/widgets/chat_list_item.dart:87:  Widget _buildChatCard(BuildContext context) {`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart:175:  Widget _buildTextField({`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart:241:  Widget _buildPickedImage(String path) => Padding(`
- `lib/features/avatar/widgets/avatar_widgets.dart:110:  Widget _buildAnimatedAvatar(AvatarState state) {`

## State design
**States missing @freezed:**
- `lib/core/widgets/current_prompt_text.dart`
- `lib/core/widgets/picker_buttons.dart`
- `lib/core/widgets/function_calling_button.dart`
- `lib/core/widgets/constrained_width.dart`
- `lib/core/widgets/glassmorphic/glassmorphic_text_field.dart`
- `lib/core/widgets/glassmorphic/animated_icon_button.dart`
- `lib/core/widgets/app_icon_button.dart`
- `lib/features/demo/screens/demo_page.dart`
- `lib/features/demo/widgets/demo_status_indicator.dart`
- `lib/features/demo/widgets/demo_controls_widget.dart`
- `lib/features/demo/widgets/demo_countdown_overlay.dart`
- `lib/features/demo/bloc/demo_cubit.dart`
- `lib/features/settings/screens/llm/llm_config_page.dart`
- `lib/features/settings/screens/llm/task_llm_config_page.dart`
- `lib/features/settings/screens/llm/llm_selection_page.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_app_bar.dart`
- `lib/features/settings/screens/llm/widgets/task_llm_background_layers.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/settings/widgets/username_field.dart`
- `lib/features/settings/widgets/sound_effects_toggle.dart`
- `lib/features/settings/widgets/api_key_field.dart`
- `lib/features/settings/widgets/persona_dropdown.dart`
- `lib/features/settings/widgets/settings_app_bar.dart`
- `lib/features/settings/bloc/settings_cubit.dart`
- `lib/features/home/screens/home_screen.dart`
- `lib/features/home/widgets/home_content_stack.dart`
- `lib/features/home/widgets/home_buttons.dart`
- `lib/features/home/widgets/home_bloc_listeners.dart`
- `lib/features/home/bloc/home_cubit.dart`
- `lib/features/talking/bloc/talking_cubit.dart`
- `lib/features/chat/screens/chat_details_screen.dart`
- `lib/features/chat/screens/chats_list_screen.dart`
- `lib/features/chat/screens/image_full_screen.dart`
- `lib/features/chat/widgets/chat_list_empty_state.dart`
- `lib/features/chat/widgets/chat_app_bar.dart`
- `lib/features/chat/widgets/message_bubble.dart`
- `lib/features/chat/widgets/modern_chat_bubble.dart`
- `lib/features/chat/widgets/chat_list_item.dart`
- `lib/features/chat/widgets/message_list.dart`
- `lib/features/chat/widgets/chat_conversation_list.dart`
- `lib/features/chat/widgets/chat_details_actions.dart`
- `lib/features/chat/widgets/chat_details_background.dart`
- `lib/features/chat/widgets/ai_text_input/ai_text_input.dart`
- `lib/features/chat/widgets/chat_avatar.dart`
- `lib/features/chat/widgets/chat_list_container.dart`
- `lib/features/chat/widgets/chat_message_item.dart`
- `lib/features/chat/widgets/function_calling_widget.dart`
- `lib/features/chat/bloc/chats_cubit.dart`
- `lib/features/chat/bloc/chat_title_cubit.dart`
- `lib/features/chat/bloc/chat_message_cubit.dart`
- `lib/features/chat/bloc/chat_list_cubit.dart`
- `lib/features/avatar/widgets/scaled_avatar_item.dart`
- `lib/features/avatar/widgets/background_avatar.dart`
- `lib/features/avatar/widgets/talking_mouth.dart`
- `lib/features/avatar/widgets/base_avatar.dart`
- `lib/features/avatar/widgets/clothes.dart`
- `lib/features/avatar/widgets/costumes/robocop_animated_eyes.dart`
- `lib/features/avatar/widgets/costumes/singularity_costume.dart`
- `lib/features/avatar/widgets/costumes/costume_widget.dart`
- `lib/features/avatar/widgets/costumes/soubrette_feather_duster.dart`
- `lib/features/avatar/widgets/blinking_eyes.dart`
- `lib/features/avatar/widgets/avatar_widgets.dart`
- `lib/features/avatar/widgets/thinking_animation.dart`
- `lib/features/avatar/widgets/loading_avatar_widget.dart`
- `lib/features/avatar/bloc/avatar_cubit.dart`
- `lib/features/sound/bloc/sound_cubit.dart`
- `lib/main.dart`

## Dependency injection
✅ `lib/core/di/injection.dart` — 1 singleton(s), 1 factory/factories
**getIt used outside injection.dart:**
- `lib/core/di/service_locator.dart`
- `lib/core/router/app_router.dart`
- `lib/features/demo/screens/demo_page.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/avatar/bloc/avatar_cubit.dart`
- `lib/main.dart`

## Routing
✅ `lib/core/router/app_router.dart` — 8 route(s)
path: RouteConstants.home, path: RouteConstants.chats, path: ':id', path: RouteConstants.settings, path: 'llm', path: 'config', path: 'task-llm', path: RouteConstants.imageFullScreen, 

## Test coverage
Total: 17  |  BLoC/Cubit: 3  |  Widget/Screen: 0  |  Repo: 0

- ✅ avatar (3 file(s))
- ✅ chat (4 file(s))
- ❌ demo (no tests)
- ❌ home (no tests)
- ❌ settings (no tests)
- ✅ sound (3 file(s))
- ✅ talking (2 file(s))
