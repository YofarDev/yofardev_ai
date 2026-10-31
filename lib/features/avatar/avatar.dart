/// Public API of the avatar feature.
library;

export 'presentation/bloc/avatar_cubit.dart';
export 'presentation/bloc/avatar_state.dart';
export 'presentation/rive/avatar_rive_contract.dart';
export 'presentation/rive/mouth_anchor_source.dart';
export 'presentation/rive/stage_framing.dart';
export 'presentation/widgets/rive/rive_avatar_view.dart';
export 'presentation/widgets/stage_camera.dart';
export 'presentation/widgets/rive/journey_layer.dart';
export 'presentation/widgets/rive/rive_scene_view.dart';
export 'domain/services/avatar_animation_service.dart';
export 'domain/models/face_frame.dart';
export 'domain/models/npc_intent.dart';
export 'domain/models/performance_intent.dart';
export 'domain/services/avatar_cue_service.dart';
export 'domain/services/auto_acting_rules.dart';
export 'domain/services/camera_director.dart';
export 'domain/services/camera_feed.dart';
export 'domain/services/face_performer.dart';
export 'domain/services/idle_ladder.dart';
export 'domain/services/npc_director.dart';
export 'domain/services/npc_feed.dart';
export 'domain/services/performance_director.dart';
export 'domain/services/prop_reaction_service.dart';
export 'domain/repositories/avatar_repository.dart';
