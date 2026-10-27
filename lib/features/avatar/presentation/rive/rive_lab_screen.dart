// ignore-l10n: debug — /rive-lab is a debug-only screen (route registered
// behind kDebugMode), so its strings are intentionally hardcoded.
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../../../../core/design/rive/rive_vm_binding.dart';
import 'avatar_rive_contract.dart';

/// Debug-only playground for the Rive avatar and scene files.
///
/// Shows `avatar.riv` layered over a chosen scene, exposes a control for every
/// contract property and trigger, logs the Rive events it receives, and can
/// overlay the Flutter performance graph. Reach it at `/rive-lab`; the route
/// only exists in debug builds.
class RiveLabScreen extends StatefulWidget {
  const RiveLabScreen({super.key});

  @override
  State<RiveLabScreen> createState() => _RiveLabScreenState();
}

class _RiveLabScreenState extends State<RiveLabScreen> {
  File? _avatarFile;
  RiveWidgetController? _avatarController;
  RiveVmBinding? _avatarBinding;

  File? _sceneFile;
  RiveWidgetController? _sceneController;
  RiveVmBinding? _sceneBinding;
  String _sceneId = AvatarRiveContract.defaultSceneId;

  final List<String> _eventLog = <String>[];
  bool _showPerfOverlay = false;
  double _mouthValue = AvatarRiveContract.mouthMin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadScene(AvatarRiveContract.defaultSceneId);
  }

  @override
  void dispose() {
    _disposeScene();
    _avatarBinding?.dispose();
    _avatarController?.stateMachine.removeEventListener(_onAvatarEvent);
    _avatarController?.dispose();
    _avatarFile?.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    try {
      final File? file = await File.asset(
        AvatarRiveContract.avatarAssetPath,
        riveFactory: Factory.rive,
      );
      if (file == null) {
        if (mounted) {
          setState(() => _error = 'avatar.riv could not be decoded');
        }
        return;
      }
      final RiveWidgetController controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.avatarArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.avatarStateMachine,
        ),
      );
      controller.stateMachine.addEventListener(_onAvatarEvent);
      if (!mounted) {
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _avatarFile = file;
        _avatarController = controller;
        _avatarBinding = RiveVmBinding(controller);
      });
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = 'avatar.riv failed to load: $e');
      }
    }
  }

  Future<void> _loadScene(String sceneId) async {
    try {
      final File? file = await File.asset(
        AvatarRiveContract.sceneAssetPath(sceneId),
        riveFactory: Factory.rive,
      );
      if (file == null) {
        if (mounted) {
          setState(() => _error = '$sceneId.riv could not be decoded');
        }
        return;
      }
      final RiveWidgetController controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.sceneArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.sceneStateMachine,
        ),
      );
      controller.stateMachine.addEventListener(_onSceneEvent);
      if (!mounted) {
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _disposeScene();
        _sceneFile = file;
        _sceneController = controller;
        _sceneBinding = RiveVmBinding(controller);
        _sceneId = sceneId;
      });
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = '$sceneId.riv failed to load: $e');
      }
    }
  }

  void _disposeScene() {
    _sceneBinding?.dispose();
    _sceneController?.stateMachine.removeEventListener(_onSceneEvent);
    _sceneController?.dispose();
    _sceneFile?.dispose();
    _sceneController = null;
    _sceneBinding = null;
    _sceneFile = null;
  }

  void _onAvatarEvent(Event event) {
    _appendLog(
      '${AvatarRiveContract.avatarArtboard}: ${event.name} '
      '${_eventProperties(event)}',
    );
  }

  void _onSceneEvent(Event event) {
    _appendLog('$_sceneId: ${event.name} ${_eventProperties(event)}');
  }

  String _eventProperties(Event event) {
    final String? propId = event
        .stringProperty(AvatarRiveContract.sceneEventPropIdProperty)
        ?.value;
    final String? zone = event
        .stringProperty(AvatarRiveContract.avatarEventZoneProperty)
        ?.value;
    final String? gestureId = event
        .stringProperty(AvatarRiveContract.avatarEventGestureIdProperty)
        ?.value;
    final String? presence = event
        .stringProperty(AvatarRiveContract.avatarEventPresenceProperty)
        ?.value;
    return <String>[
      if (propId != null) 'propId=$propId',
      if (zone != null) 'zone=$zone',
      if (gestureId != null) 'gestureId=$gestureId',
      if (presence != null) 'presence=$presence',
    ].join(' ');
  }

  void _appendLog(String line) {
    if (!mounted) {
      return;
    }
    setState(() {
      _eventLog.insert(0, line);
      if (_eventLog.length > 100) {
        _eventLog.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rive Lab'),
        actions: <Widget>[
          Row(
            children: <Widget>[
              const Text('Perf overlay'),
              Switch(
                value: _showPerfOverlay,
                onChanged: (bool value) =>
                    setState(() => _showPerfOverlay = value),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_error != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                title: const Text('Rive load error'),
                subtitle: Text(_error!),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _buildStage()),
                SizedBox(
                  width: 320,
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: <Widget>[
                        const TabBar(
                          tabs: <Tab>[
                            Tab(text: 'Controls'),
                            Tab(text: 'Events'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              _buildControls(),
                              _buildEventLog(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showPerfOverlay)
            SizedBox(height: 120, child: PerformanceOverlay.allEnabled()),
        ],
      ),
    );
  }

  Widget _buildStage() {
    final RiveWidgetController? sceneController = _sceneController;
    final RiveWidgetController? avatarController = _avatarController;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (sceneController != null)
          RiveWidget(controller: sceneController, fit: Fit.cover)
        else
          const ColoredBox(color: Color(0xFF202020)),
        if (avatarController != null)
          RiveWidget(controller: avatarController, fit: Fit.contain)
        else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildControls() {
    final RiveVmBinding? avatarBinding = _avatarBinding;
    if (avatarBinding == null) {
      return const Center(child: Text('avatar.riv not loaded'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _buildEnumDropdown(
          label: AvatarRiveContract.propMood,
          values: AvatarRiveContract.moodValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propMood,
            AvatarRiveContract.moodValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propPhase,
          values: AvatarRiveContract.phaseValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propPhase,
            AvatarRiveContract.phaseValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propGestureId,
          values: AvatarRiveContract.gestureIdValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propGestureId,
            AvatarRiveContract.gestureIdValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propHat,
          values: AvatarRiveContract.hatValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propHat,
            AvatarRiveContract.hatValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propTop,
          values: AvatarRiveContract.topValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propTop,
            AvatarRiveContract.topValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propGlasses,
          values: AvatarRiveContract.glassesValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propGlasses,
            AvatarRiveContract.glassesValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propCostume,
          values: AvatarRiveContract.costumeValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propCostume,
            AvatarRiveContract.costumeValues,
            value,
          ),
        ),
        _buildEnumDropdown(
          label: AvatarRiveContract.propPresence,
          values: AvatarRiveContract.presenceValues,
          onSelected: (String value) => avatarBinding.setEnum(
            AvatarRiveContract.propPresence,
            AvatarRiveContract.presenceValues,
            value,
          ),
        ),
        // `mouth`: number 0-4.
        ListBody(
          children: <Widget>[
            Text(AvatarRiveContract.propMouth),
            Slider(
              value: _mouthValue,
              min: AvatarRiveContract.mouthMin,
              max: AvatarRiveContract.mouthMax,
              divisions: 4,
              label: _mouthValue.toStringAsFixed(0),
              onChanged: (double value) {
                setState(() => _mouthValue = value);
                avatarBinding.setNumber(AvatarRiveContract.propMouth, value);
              },
            ),
          ],
        ),
        ElevatedButton(
          onPressed: () =>
              avatarBinding.fireTrigger(AvatarRiveContract.propGestureTrigger),
          child: const Text('gesture (trigger)'),
        ),
        const Divider(),
        DropdownButton<String>(
          value: _sceneId,
          items: AvatarRiveContract.sceneIds
              .map(
                (String id) => DropdownMenuItem<String>(
                  value: id,
                  child: Text('scene: $id'),
                ),
              )
              .toList(),
          onChanged: (String? id) {
            if (id != null && id != _sceneId) {
              _loadScene(id);
            }
          },
        ),
        ...AvatarRiveContract.sceneEvents[_sceneId]!.map(
          (String eventId) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ElevatedButton(
              onPressed: _sceneBinding == null
                  ? null
                  : () {
                      _sceneBinding!.setEnum(
                        AvatarRiveContract.scenePropEventId,
                        AvatarRiveContract.sceneEvents[_sceneId]!,
                        eventId,
                      );
                      _sceneBinding!.fireTrigger(
                        AvatarRiveContract.scenePropEventTrigger,
                      );
                    },
              child: Text('event: $eventId'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnumDropdown({
    required String label,
    required List<String> values,
    required ValueChanged<String> onSelected,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      initialValue: values.first,
      items: values
          .map(
            (String value) =>
                DropdownMenuItem<String>(value: value, child: Text(value)),
          )
          .toList(),
      onChanged: (String? value) {
        if (value != null) {
          onSelected(value);
        }
      },
    );
  }

  Widget _buildEventLog() {
    if (_eventLog.isEmpty) {
      return const Center(child: Text('No Rive events yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _eventLog.length,
      itemBuilder: (BuildContext context, int index) =>
          Text(_eventLog[index], style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
