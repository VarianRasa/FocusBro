import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/voice_recording_service.dart';
import 'package:record/record.dart';

void main() {
  test('voice recording settings produce the requested native config', () {
    final config = buildVoiceRecordConfig(
      audioFormat: 'wav',
      sampleRate: 48000,
      bitRate: 256000,
      enableNoiseReduction: true,
    );

    expect(config.encoder, AudioEncoder.wav);
    expect(config.sampleRate, 48000);
    expect(config.bitRate, 256000);
    expect(config.noiseSuppress, isTrue);
  });

  test('AAC recording uses the matching M4A container extension', () {
    expect(normalizeVoiceAudioFormat('aac'), 'm4a');
    expect(normalizeVoiceAudioFormat('m4a'), 'm4a');
  });
}
