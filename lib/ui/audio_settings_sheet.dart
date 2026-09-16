import 'package:flutter/material.dart';
import '../game/audio_cues.dart';
import 'theme.dart';

class AudioSettingsSheet extends StatefulWidget {
  const AudioSettingsSheet({super.key, required this.enabled, required this.mix,
      required this.onEnabled, required this.onBus, required this.paused,
      required this.haptics, required this.onHaptics});
  final bool enabled, paused, haptics;
  final AudioMix mix;
  final ValueChanged<bool> onEnabled, onHaptics;
  final void Function(AudioBus, bool) onBus;

  @override
  State<AudioSettingsSheet> createState() => _AudioSettingsSheetState();
}

class _AudioSettingsSheetState extends State<AudioSettingsSheet> {
  late bool _enabled = widget.enabled;
  late bool _haptics = widget.haptics;
  late AudioMix _mix = widget.mix;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('AUDIO MIX', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w900, letterSpacing: 1.5,
            fontFamily: StrikerFonts.display, color: StrikerColors.text)),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('audio_master'),
          title: const Text('Sound'),
          subtitle: const Text('Turn all game audio on or off'),
          value: _enabled,
          onChanged: (value) {
            setState(() => _enabled = value);
            widget.onEnabled(value);
          },
        ),
        SwitchListTile(
          title: const Text('Vibration'),
          subtitle: const Text('Kick and result haptics'),
          value: _haptics,
          onChanged: (value) {
            setState(() => _haptics = value);
            widget.onHaptics(value);
          },
        ),
        const Divider(),
        _channel(AudioBus.music, 'Music', 'Menu theme and last-chance suspense'),
        _channel(AudioBus.effects, 'Shot effects', 'Kicks, saves, blocks, posts and whistles'),
        _channel(AudioBus.crowd, 'Crowd', 'Stadium ambience, goal cheers and near misses'),
        Padding(padding: const EdgeInsets.all(12), child: Text(
            !_enabled ? 'Sound is muted. Your mix stays saved.'
                : widget.paused ? 'Your match stays paused. Resume to hear your mix.'
                    : 'Your mix is saved. On iPhone, Silent Mode also mutes game audio.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: StrikerColors.muted))),
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('DONE')),
      ]),
    ),
  );

  Widget _channel(AudioBus bus, String title, String subtitle) => SwitchListTile(
    key: ValueKey('audio_${bus.name}'),
    title: Text(title),
    subtitle: Text(subtitle),
    value: _mix.allows(bus),
    onChanged: (value) {
      setState(() => _mix = _mix.withBus(bus, value));
      widget.onBus(bus, value);
    },
  );
}
