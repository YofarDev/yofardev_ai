import 'dart:math' as math;
import 'dart:typed_data';

/// Channel 0 of a WAV file, decoded to normalised samples in [-1, 1].
///
/// Supports PCM 8-bit (unsigned), PCM 16-bit and IEEE float 32-bit, walks
/// the RIFF chunk tree (skipping unknown and odd-sized chunks) and tolerates
/// a truncated `data` chunk.
class WavPcm {
  const WavPcm({required this.sampleRate, required this.samples});

  final int sampleRate;

  /// Channel 0, normalised to [-1, 1].
  final Float32List samples;

  /// Length of the audio.
  Duration get duration => sampleRate <= 0
      ? Duration.zero
      : Duration(microseconds: samples.length * 1000000 ~/ sampleRate);

  /// Decodes [bytes]. Throws [FormatException] on an unsupported or corrupt
  /// file.
  static WavPcm decode(Uint8List bytes) {
    if (bytes.length < 12 ||
        _chunkId(bytes, 0) != 'RIFF' ||
        _chunkId(bytes, 8) != 'WAVE') {
      throw const FormatException('Not a RIFF/WAVE file');
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    Uint8List? dataBytes;

    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final String id = _chunkId(bytes, offset);
      final int declaredSize = ByteData.sublistView(
        bytes,
        offset + 4,
      ).getUint32(0, Endian.little);
      final int payloadStart = offset + 8;
      // A truncated `data` chunk uses the bytes actually present; every
      // other chunk is skipped (payload plus its pad byte when odd-sized).
      final int availableSize = math.min(
        declaredSize,
        bytes.length - payloadStart,
      );

      if (id == 'fmt ' && availableSize >= 16) {
        final ByteData fmt = ByteData.sublistView(bytes, payloadStart);
        audioFormat = fmt.getUint16(0, Endian.little);
        channels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        bitsPerSample = fmt.getUint16(14, Endian.little);
      } else if (id == 'data') {
        dataBytes = Uint8List.sublistView(
          bytes,
          payloadStart,
          payloadStart + availableSize,
        );
      }

      offset = payloadStart + declaredSize + (declaredSize.isOdd ? 1 : 0);
    }

    if (audioFormat == null || channels == null || sampleRate == null) {
      throw const FormatException('Missing or malformed fmt chunk');
    }
    if (dataBytes == null) {
      throw const FormatException('Missing data chunk');
    }
    final bool isPcm16 = audioFormat == 1 && bitsPerSample == 16;
    final bool isPcm8 = audioFormat == 1 && bitsPerSample == 8;
    final bool isFloat32 = audioFormat == 3 && bitsPerSample == 32;
    if (!isPcm16 && !isPcm8 && !isFloat32) {
      throw FormatException(
        'Unsupported WAV format: audioFormat=$audioFormat, '
        'bitsPerSample=$bitsPerSample',
      );
    }

    final int bytesPerSample = bitsPerSample! ~/ 8;
    final int frameBytes = channels * bytesPerSample;
    final int count = frameBytes == 0 ? 0 : dataBytes.length ~/ frameBytes;
    // One view over the whole data chunk, shared by every sample read (a view
    // per sample made decoding of long clips janky on the UI isolate).
    final ByteData view = ByteData.sublistView(dataBytes);
    final Float32List samples = Float32List(count);
    for (int i = 0; i < count; i++) {
      final int at = i * frameBytes;
      switch (bytesPerSample) {
        case 1:
          // 8-bit PCM is unsigned, centred on 128.
          samples[i] = (dataBytes[at] - 128) / 128;
        case 2:
          samples[i] = view.getInt16(at, Endian.little) / 32768;
        default:
          samples[i] = view.getFloat32(at, Endian.little);
      }
    }
    return WavPcm(sampleRate: sampleRate, samples: samples);
  }

  /// The samples as a mono 16-bit PCM WAV with the canonical 44-byte
  /// header, clamped to [-1, 1]; [decode] reads it back.
  Uint8List encodePcm16() {
    const int headerBytes = 44;
    final int dataBytes = samples.length * 2;
    final Uint8List bytes = Uint8List(headerBytes + dataBytes);
    final ByteData out = ByteData.sublistView(bytes);
    void writeId(int offset, String id) =>
        bytes.setRange(offset, offset + 4, id.codeUnits);

    writeId(0, 'RIFF');
    out.setUint32(4, 36 + dataBytes, Endian.little);
    writeId(8, 'WAVE');
    writeId(12, 'fmt ');
    out.setUint32(16, 16, Endian.little); // fmt payload size
    out.setUint16(20, 1, Endian.little); // PCM
    out.setUint16(22, 1, Endian.little); // mono
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    out.setUint16(32, 2, Endian.little); // block align
    out.setUint16(34, 16, Endian.little); // bits per sample
    writeId(36, 'data');
    out.setUint32(40, dataBytes, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      // × 32768 inverts decode's ÷ 32768; full-scale +1 clips to 32767.
      final int value = (samples[i].clamp(-1.0, 1.0) * 32768).round();
      out.setInt16(headerBytes + i * 2, math.min(value, 32767), Endian.little);
    }
    return bytes;
  }

  static String _chunkId(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes, offset, offset + 4);
}
