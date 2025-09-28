/* Tdarr Plugin: Ultimate All-In-One Media Optimizer
 * Author: Custom Implementation
 * Version: 5.3.0
 *
 * Roku-optimized single-pass media processing with archival quality
 * MP4 output with fast streaming, intelligent chapters
 *
 * Video: HEVC 10-bit for archival quality + modern compression
 * Audio: Smart conversion to E-AC3/AAC for Roku compatibility + quality preservation
 *
 * Fixed: Width OR height resolution detection, simplified size logic, ASS subtitles, smart audio
 */

const details = () => ({
  id: "Tdarr_Plugin_Ultimate_All_In_One",
  Stage: "Pre-processing",
  Name: "Ultimate All-In-One Media Optimizer",
  Type: "Video",
  Operation: "Transcode",
  Description: `Roku-optimized archival: HEVC 10-bit, smart E-AC3/AAC audio, fast streaming.`,
  Version: "5.3.0",
  Tags: "pre-processing,ffmpeg,video,audio,subtitle,h265,roku,mp4",
  Inputs: [
    {
      name: "size_tolerance",
      type: "number",
      defaultValue: 30,
      inputUI: { type: "text" },
      tooltip: "Tolerance % for target size (e.g., 30 = ±30%)"
    },
    {
      name: "target_4k_gb",
      type: "number",
      defaultValue: 9,
      inputUI: { type: "text" },
      tooltip: "Target size in GB for 120min 4K film"
    },
    {
      name: "target_1080p_gb",
      type: "number",
      defaultValue: 4,
      inputUI: { type: "text" },
      tooltip: "Target size in GB for 120min 1080p film"
    },
    {
      name: "target_720p_gb",
      type: "number",
      defaultValue: 2,
      inputUI: { type: "text" },
      tooltip: "Target size in GB for 120min 720p film"
    },
    {
      name: "target_sd_mb",
      type: "number",
      defaultValue: 300,
      inputUI: { type: "text" },
      tooltip: "Target size in MB for 120min SD film"
    },
    {
      name: "generate_chapters",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "dropdown", options: ["false", "true"] },
      tooltip: "Generate chapters if missing"
    },
    {
      name: "container",
      type: "string",
      defaultValue: "mp4",
      inputUI: {
        type: "dropdown",
        options: [
          { value: "mp4", text: "MP4 (Roku streaming)" },
          { value: "mkv", text: "MKV (archival)" }
        ]
      },
      tooltip: "Output container (MP4 recommended for Roku)"
    }
  ],
});

const plugin = (file, librarySettings, inputs, otherArguments) => {
  const response = {
    processFile: false,
    preset: "",
    container: `.${inputs.container || "mp4"}`,
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: "",
  };

  // Detect if we're in post-processing (checking a transcoded file)
  const isTranscodedFile = file._id.includes("TdarrCacheFile") ||
                          file.file.includes("/temp/") ||
                          file.file.includes("/cache/") ||
                          file.file.includes("tdarr-workDir");

  // Check if file is video
  if (file.fileMedium !== "video") {
    response.infoLog += "☒ Not a video file\n";
    return response;
  }

  const streams = file.ffProbeData.streams;
  // Filter out attached pictures and thumbnails - only get actual video streams
  const videoStreams = streams.filter(s =>
    s.codec_type === "video" &&
    s.disposition?.attached_pic !== 1 &&
    s.disposition?.timed_thumbnails !== 1
  );
  const audioStreams = streams.filter(s => s.codec_type === "audio");
  const subStreams = streams.filter(s => s.codec_type === "subtitle");

  if (!videoStreams.length) {
    response.infoLog += "☒ No video stream found\n";
    return response;
  }

  const videoStream = videoStreams[0];
  // Store the actual stream index for mapping
  const videoStreamIndex = streams.indexOf(videoStream);
  const args = [];
  let needsProcessing = false;

  // Get file duration in minutes - try multiple sources
  let durationSeconds = 0;

  // Helper function to parse duration strings like "02:04:15.163000000" to seconds
  function parseDurationString(durationStr) {
    if (!durationStr) return 0;

    // If it's already a number, return it
    if (!isNaN(parseFloat(durationStr)) && !durationStr.includes(':')) {
      return parseFloat(durationStr);
    }

    // Parse HH:MM:SS.mmm format
    const parts = durationStr.split(':');
    if (parts.length === 3) {
      const hours = parseInt(parts[0]) || 0;
      const minutes = parseInt(parts[1]) || 0;
      const seconds = parseFloat(parts[2]) || 0;
      return hours * 3600 + minutes * 60 + seconds;
    } else if (parts.length === 2) {
      // MM:SS format
      const minutes = parseInt(parts[0]) || 0;
      const seconds = parseFloat(parts[1]) || 0;
      return minutes * 60 + seconds;
    }

    // Fallback to parseFloat
    return parseFloat(durationStr) || 0;
  }

  // Try ffProbeData format duration first (most reliable)
  if (file.ffProbeData?.format?.duration && !isNaN(parseFloat(file.ffProbeData.format.duration))) {
    durationSeconds = parseFloat(file.ffProbeData.format.duration);
  }
  // Try file metadata duration (may be in HH:MM:SS format)
  else if (file.meta?.Duration) {
    durationSeconds = parseDurationString(file.meta.Duration);
  }
  // Try video stream duration
  else if (videoStream.duration && !isNaN(parseFloat(videoStream.duration))) {
    durationSeconds = parseFloat(videoStream.duration);
  }
  // Try container duration
  else if (file.container_duration && !isNaN(parseFloat(file.container_duration))) {
    durationSeconds = parseFloat(file.container_duration);
  }
  // Fallback - but log a warning
  else {
    response.infoLog += "⚠️ WARNING: Could not determine file duration, using 2 hour fallback\n";
    durationSeconds = 7200; // 2 hours fallback
  }

  // Validate duration is reasonable (between 1 second and 24 hours)
  if (durationSeconds < 1 || durationSeconds > 86400) {
    response.infoLog += `⚠️ WARNING: Unusual duration detected: ${durationSeconds} seconds\n`;
    if (durationSeconds < 1) {
      response.infoLog += "  → Using 2 hour fallback for safety\n";
      durationSeconds = 7200;
    }
  }

  const durationMinutes = durationSeconds / 60;
  // file.file_size is in MB from Tdarr, need to convert to GB
  const currentFileSizeGB = file.file_size / 1024;

  response.infoLog += "🔍 Analyzing file...\n";
  response.infoLog += `  Video: ${videoStream.codec_name} ${videoStream.width}x${videoStream.height}`;
  if (videoStream.profile) response.infoLog += ` (${videoStream.profile})`;
  response.infoLog += `\n  File Size: ${currentFileSizeGB.toFixed(2)}GB\n`;
  response.infoLog += `  Duration: ${durationMinutes.toFixed(0)} minutes\n`;
  response.infoLog += `  Audio: ${audioStreams.length} tracks\n`;
  response.infoLog += `  Subtitles: ${subStreams.length} tracks\n`;

  // Check for existing chapters - look in multiple places
  // MP4 files may have chapters as a data stream (bin_data/text) rather than in the chapters array
  const hasChapters = file.meta?.chapterCount > 0 ||
                      file.ffProbeData?.chapters?.length > 0 ||
                      file.ffProbeData?.format?.nb_chapters > 0 ||
                      // Check for chapter data stream (how FFmpeg adds chapters to MP4)
                      file.ffProbeData?.streams?.some(s => s.codec_name === 'bin_data' && s.codec_tag_string === 'text');

  const chapterCount = file.ffProbeData?.chapters?.length ||
                       file.ffProbeData?.format?.nb_chapters ||
                       (file.ffProbeData?.streams?.some(s => s.codec_name === 'bin_data' && s.codec_tag_string === 'text') ? 'Present' : 0) ||
                       file.meta?.chapterCount || 0;

  response.infoLog += `  Chapters: ${hasChapters ? chapterCount : 'None'}\n\n`;

  // Safety check: Don't process files with invalid duration
  if (durationMinutes <= 0 || isNaN(durationMinutes)) {
    response.infoLog += "❌ ERROR: Cannot process file with invalid or zero duration\n";
    response.infoLog += "  → File duration could not be determined\n";
    response.infoLog += "  → Please check file integrity\n";
    response.processFile = false;
    return response;
  }

  // ========================================
  // VIDEO PROCESSING DECISION - SIZE AWARE
  // ========================================
  const width = videoStream.width;
  const height = videoStream.height;

  // Extract current video bitrate - with safety check for duration
  let currentVideoBitrate = 0;
  if (durationMinutes > 0) {
    currentVideoBitrate = videoStream.bit_rate ?
      parseInt(videoStream.bit_rate) / 1000 :
      (currentFileSizeGB * 8 * 1024 * 1024) / (durationMinutes * 60);
  } else {
    // Can't calculate bitrate without duration
    currentVideoBitrate = 5000; // Assume 5Mbps as fallback
    response.infoLog += "  ⚠️ Cannot calculate bitrate without duration, assuming 5Mbps\n";
  }

  // Determine resolution category by width OR height (handles both letterboxing and 4:3 content)
  // Use slightly lower thresholds to catch encoding artifacts and slight resolution variations
  let resCategory, targetSizeGB, targetBitrate;
  if (width >= 3800 || height >= 2100) { // 4K (allowing for slight variations)
    resCategory = "4K";
    targetSizeGB = (inputs.target_4k_gb || 9) * (durationMinutes / 120);
    targetBitrate = (targetSizeGB * 8 * 1024 * 1024) / (durationMinutes * 60); // kbps
  } else if (width >= 2500 || height >= 1400) { // 1440p
    resCategory = "1440p";
    targetSizeGB = 6 * (durationMinutes / 120); // Between 1080p and 4K
    targetBitrate = (targetSizeGB * 8 * 1024 * 1024) / (durationMinutes * 60);
  } else if (width >= 1900 || height >= 1000) { // 1080p (includes letterboxed like 1918x800)
    resCategory = "1080p";
    targetSizeGB = (inputs.target_1080p_gb || 4) * (durationMinutes / 120);
    targetBitrate = (targetSizeGB * 8 * 1024 * 1024) / (durationMinutes * 60);
  } else if (width >= 1200 || height >= 700) { // 720p
    resCategory = "720p";
    targetSizeGB = (inputs.target_720p_gb || 2) * (durationMinutes / 120);
    targetBitrate = (targetSizeGB * 8 * 1024 * 1024) / (durationMinutes * 60);
  } else { // SD
    resCategory = "SD";
    targetSizeGB = ((inputs.target_sd_mb || 300) / 1024) * (durationMinutes / 120);
    targetBitrate = (targetSizeGB * 8 * 1024 * 1024) / (durationMinutes * 60);
  }

  const tolerance = inputs.size_tolerance || 30;
  // Only check maximum size - files smaller than target are already good
  const maxSize = targetSizeGB * (1 + tolerance / 100);

  // Adaptive HEVC efficiency calculation
  function getAdaptiveHEVCEfficiency(bitrate, resolution) {
    let hevcEfficiency;

    if (bitrate > 10000) {
      // Very high bitrate (>10Mbps) - Often has redundancy
      hevcEfficiency = 0.55; // 45% reduction
    } else if (bitrate > 6000) {
      // High bitrate (6-10Mbps) - Typical Blu-ray rips
      hevcEfficiency = 0.60; // 40% reduction
    } else if (bitrate > 3500) {
      // Medium bitrate (3.5-6Mbps) - Good quality streaming
      hevcEfficiency = 0.65; // 35% reduction
    } else if (bitrate > 2000) {
      // Lower bitrate (2-3.5Mbps) - Standard streaming
      hevcEfficiency = 0.70; // 30% reduction
    } else if (bitrate > 1000) {
      // Low bitrate (1-2Mbps) - Already compressed
      hevcEfficiency = 0.75; // 25% reduction
    } else {
      // Very low bitrate (<1Mbps) - Heavily compressed
      hevcEfficiency = 0.85; // 15% reduction
    }

    // Apply 10-bit encoding bonus (5% more efficient)
    hevcEfficiency *= 0.95;

    // Resolution-based adjustment
    if (resolution === '4K') {
      hevcEfficiency *= 0.95; // 4K can be compressed more
    } else if (resolution === 'SD') {
      hevcEfficiency *= 1.05; // SD needs more bits per pixel
    }

    return hevcEfficiency;
  }

  // Check if video needs processing
  const isHEVC = videoStream.codec_name === "hevc" || videoStream.codec_name === "h265";
  const is10Bit = videoStream.profile?.includes("Main 10") ||
                   videoStream.pix_fmt?.includes("10") ||
                   videoStream.bit_depth === 10;
  const tooBig = currentFileSizeGB > maxSize;

  response.infoLog += `📊 Video Analysis:\n`;
  response.infoLog += `  Resolution: ${resCategory}\n`;
  response.infoLog += `  Current Bitrate: ${Math.round(currentVideoBitrate)}kbps\n`;
  response.infoLog += `  Current Size: ${currentFileSizeGB.toFixed(2)}GB\n`;
  response.infoLog += `  Reference Target: ${targetSizeGB.toFixed(2)}GB (±${tolerance}%)\n`;
  response.infoLog += `  Maximum Acceptable Size: ${maxSize.toFixed(2)}GB\n`;
  response.infoLog += `  Current Codec: ${videoStream.codec_name}${is10Bit ? ' 10-bit' : ' 8-bit'}\n`;
  response.infoLog += `  Size Status: ${tooBig ? '❌ Too Large' : '✅ Acceptable'}\n`;

  let processVideo = false;
  let skipVideoReason = "";
  let finalVideoBitrate = targetBitrate;

  // Smart video processing decision
  if (!isHEVC || !is10Bit) {
    // Need to convert to HEVC 10-bit
    processVideo = true;

    // Special case: 8-bit HEVC → 10-bit (leverage 10-bit efficiency)
    if (isHEVC && !is10Bit && !tooBig) {
      // Already HEVC 8-bit, just upgrading to 10-bit
      // 10-bit is ~10% more efficient at same quality
      finalVideoBitrate = currentVideoBitrate * 0.9;
      response.infoLog += `  ✅ 8-bit HEVC → 10-bit: 10% efficiency gain\n`;
    } else {
      // h264→HEVC or oversized files: use adaptive efficiency
      const hevcEfficiency = getAdaptiveHEVCEfficiency(currentVideoBitrate, resCategory);
      const hevcCalculatedBitrate = currentVideoBitrate * hevcEfficiency;

      response.infoLog += `  📈 HEVC Efficiency: ${((1 - hevcEfficiency) * 100).toFixed(0)}% reduction expected\n`;

      if (tooBig) {
        // File too large - use target bitrate to ensure size reduction
        finalVideoBitrate = Math.min(hevcCalculatedBitrate, targetBitrate);
        response.infoLog += `  ⚠ File too large: Reducing to meet size target\n`;
      } else {
        // File size acceptable - use HEVC efficiency for codec standardization
        finalVideoBitrate = hevcCalculatedBitrate;
        response.infoLog += `  ✅ Size acceptable: Converting for codec standardization\n`;
      }
    }

    // Apply quality floor to prevent excessive compression
    const minBitrates = {
      '4K': 3000,
      '1440p': 2000,
      '1080p': 900,
      '720p': 600,
      'SD': 350
    };

    if (finalVideoBitrate < minBitrates[resCategory]) {
      finalVideoBitrate = minBitrates[resCategory];
      response.infoLog += `  📊 Applied quality floor: ${minBitrates[resCategory]}kbps\n`;
    }

    if (!isHEVC && processVideo) {
      response.infoLog += `  ⚠ Converting h264 to HEVC 10-bit\n`;
      const expectedSizeGB = (finalVideoBitrate * durationMinutes * 60) / (8 * 1024 * 1024);
      const reduction = ((currentFileSizeGB - expectedSizeGB) / currentFileSizeGB * 100).toFixed(0);
      response.infoLog += `  📦 Expected size after encoding: ${expectedSizeGB.toFixed(2)}GB (${reduction}% reduction)\n`;
    } else if (!is10Bit && processVideo) {
      response.infoLog += `  ⚠ Converting to 10-bit\n`;
      const expectedSizeGB = (finalVideoBitrate * durationMinutes * 60) / (8 * 1024 * 1024);
      response.infoLog += `  📦 Expected size after encoding: ${expectedSizeGB.toFixed(2)}GB\n`;
    }

  } else if (isHEVC && is10Bit && tooBig) {
    // Already HEVC 10-bit but too large
    processVideo = true;
    finalVideoBitrate = targetBitrate;
    response.infoLog += `  ⚠ HEVC 10-bit but too large - re-encoding to reduce size\n`;
    const expectedSizeGB = (finalVideoBitrate * durationMinutes * 60) / (8 * 1024 * 1024);
    response.infoLog += `  📦 Target after re-encoding: ${expectedSizeGB.toFixed(2)}GB\n`;
  } else if (isHEVC && is10Bit && !tooBig) {
    // Already optimal
    processVideo = false;
    response.infoLog += `  ✅ Already HEVC 10-bit and size acceptable - keeping as-is\n`;
    response.infoLog += `  📦 Expected output: ~${currentFileSizeGB.toFixed(2)}GB (video stream will be copied)\n`;
  }

  // Also process if we need chapters or container conversion
  const outputContainer = inputs.container || "mp4";
  const needsChapters = inputs.generate_chapters && !hasChapters && durationMinutes > 10;
  // Normalize container names - remove any leading dots for comparison
  const currentContainer = file.container.toLowerCase().replace(/^\./, '');
  const targetContainer = outputContainer.toLowerCase().replace(/^\./, '');
  const needsContainerChange = currentContainer !== targetContainer;

  // Check if we need to process for chapters or container even if video is optimal
  if (!processVideo && (needsChapters || needsContainerChange)) {
    // Process for container change or chapter needs (both are important for user experience)
    if (needsContainerChange || needsChapters) {
      needsProcessing = true;
      if (needsContainerChange) {
        response.infoLog += `  ⚠ Container conversion needed (${currentContainer} → ${targetContainer})\n`;
      }
      if (needsChapters) {
        response.infoLog += `  ⚠ Chapters missing - would benefit from generation\n`;
      }
    }
  }

  if (processVideo) {
    needsProcessing = true;

    // Use the adaptive bitrate we calculated earlier
    const finalTargetSizeGB = (finalVideoBitrate * durationMinutes * 60) / (8 * 1024 * 1024);

    response.infoLog += `☑ Video will be transcoded to HEVC 10-bit @ ${Math.round(finalVideoBitrate)}kbps\n`;
    response.infoLog += `  Expected size: ${finalTargetSizeGB.toFixed(2)}GB (${((1 - finalTargetSizeGB/currentFileSizeGB) * 100).toFixed(1)}% reduction)\n\n`;

    // Video encoding args - optimized for Roku streaming
    args.push("-c:v hevc_nvenc");
    args.push("-preset p4");
    args.push("-profile:v main10");
    args.push("-pix_fmt yuv420p10le");
    args.push("-level:v 5.0");  // Level 150 = 5.0 for 4K compatibility
    args.push(`-b:v ${Math.round(finalVideoBitrate)}k`);
    args.push(`-maxrate ${Math.round(finalVideoBitrate * 1.5)}k`);
    args.push(`-bufsize ${Math.round(finalVideoBitrate * 2)}k`);
    args.push("-rc vbr");
    args.push("-rc-lookahead 32");
    args.push("-spatial_aq 1");
    args.push("-temporal_aq 1");
    args.push("-nonref_p 1");
    args.push("-strict_gop 1");
    args.push("-aq-strength 8");
    args.push("-refs 1");  // Match the working example

    const fps = eval(videoStream.r_frame_rate) || 24;
    args.push(`-g ${Math.round(fps * 2)}`);
    args.push("-bf 2");  // B-frames set to 2 like working example

    // HDR handling
    const hasHDR = videoStream.color_transfer === "smpte2084" ||
                   videoStream.color_primaries === "bt2020";
    if (hasHDR) {
      args.push("-color_range tv");
      args.push("-colorspace bt2020nc");
      args.push("-color_trc smpte2084");
      args.push("-color_primaries bt2020");
      response.infoLog += "  ☑ Preserving HDR metadata\n";
    } else {
      args.push("-color_range tv");
      args.push("-colorspace bt709");
      args.push("-color_trc bt709");
      args.push("-color_primaries bt709");
    }
  } else {
    // Video is not being processed - either copy or check if we need to process at all
    if (skipVideoReason) {
      response.infoLog += `\n☑ Video stream: ${skipVideoReason}\n`;
    } else {
      response.infoLog += "\n☑ Video already optimal (HEVC 10-bit, size in range)\n";
    }
    args.push("-c:v copy");
    response.infoLog += "  → Copying video stream without re-encoding\n\n";
  }

  // ========================================
  // AUDIO PROCESSING - ROKU OPTIMIZED
  // ========================================
  response.infoLog += "🎵 Audio Track Analysis:\n";

  // Categorize audio tracks
  const englishMain = [];
  const englishCommentary = [];
  const otherLang = [];

  audioStreams.forEach((stream, idx) => {
    const lang = stream.tags?.language?.toLowerCase() || "";
    const title = (stream.tags?.title || "").toLowerCase();
    const isEnglish = lang === "eng" || lang === "en" || lang === "english";
    const isCommentary = title.includes("comment") || title.includes("director") ||
                         title.includes("cast") || title.includes("producer");

    if (isEnglish && isCommentary) {
      englishCommentary.push(stream);
      response.infoLog += `  Track ${idx}: English Commentary - ${stream.codec_name}\n`;
    } else if (isEnglish) {
      englishMain.push(stream);
      response.infoLog += `  Track ${idx}: English Main - ${stream.codec_name}\n`;
    } else {
      otherLang.push(stream);
      response.infoLog += `  Track ${idx}: ${lang || 'Unknown'} - ${stream.codec_name}\n`;
    }
  });

  // Determine track order: English main, English commentary, others (if no English)
  const orderedAudio = [];
  if (englishMain.length > 0 || englishCommentary.length > 0) {
    orderedAudio.push(...englishMain);
    orderedAudio.push(...englishCommentary);
  } else {
    // No English found, keep first as default and rest
    if (audioStreams.length > 0) {
      orderedAudio.push(...audioStreams);
      response.infoLog += "  ⚠ No English audio found, keeping all tracks\n";
    }
  }

  if (orderedAudio.length !== audioStreams.length ||
      orderedAudio.some((s, i) => audioStreams[i] !== s)) {
    needsProcessing = true;
    response.infoLog += `☑ Audio needs reordering/optimization\n`;
  }

  // Map the actual video stream by its index (not cover art or thumbnails)
  args.push(`-map 0:${videoStreamIndex}`);

  // Map and process audio in correct order
  orderedAudio.forEach((stream, newIndex) => {
    const originalIndex = audioStreams.indexOf(stream);
    args.push(`-map 0:a:${originalIndex}`);

    const bitrate = parseInt(stream.bit_rate) / 1000 || 0;
    const isCommentary = englishCommentary.includes(stream);

    // Roku compatibility check - prefer E-AC3 for main tracks
    const isRokuCompatible = stream.codec_name === "ac3" || stream.codec_name === "eac3";

    if (isCommentary) {
      // Always compress commentary to 128k stereo AAC
      args.push(`-c:a:${newIndex} aac`);
      args.push(`-b:a:${newIndex} 128k`);
      args.push(`-ac:${newIndex} 2`);
      response.infoLog += `  Audio ${newIndex}: Commentary → AAC 128k stereo\n`;
      needsProcessing = true;
    } else if (isRokuCompatible && !isCommentary) {
      // Keep AC3/E-AC3 for Roku compatibility (but check bitrate)
      if (stream.codec_name === "eac3" || bitrate <= 640) {
        args.push(`-c:a:${newIndex} copy`);
        response.infoLog += `  Audio ${newIndex}: Keeping ${stream.codec_name} (Roku compatible)\n`;
      } else {
        // AC3 640k+ could benefit from E-AC3's efficiency
        args.push(`-c:a:${newIndex} eac3`);
        args.push(`-b:a:${newIndex} 640k`);
        response.infoLog += `  Audio ${newIndex}: AC3 ${bitrate}k → E-AC3 640k (better efficiency)\n`;
        needsProcessing = true;
      }
    } else if (stream.codec_name === "aac") {
      // Always keep AAC - it's already efficient and Roku-compatible
      args.push(`-c:a:${newIndex} copy`);
      response.infoLog += `  Audio ${newIndex}: Keeping AAC (efficient & compatible)\n`;
    } else if (stream.codec_name === "dts" || stream.codec_name === "dts_hd") {
      // Smart DTS conversion based on channels and bitrate
      if (stream.channels <= 2) {
        // DTS stereo → AAC (more efficient than E-AC3 for stereo)
        const targetBitrate = Math.min(256, Math.max(192, bitrate * 0.5));
        args.push(`-c:a:${newIndex} aac`);
        args.push(`-b:a:${newIndex} ${Math.round(targetBitrate)}k`);
        response.infoLog += `  Audio ${newIndex}: DTS stereo → AAC ${Math.round(targetBitrate)}k\n`;
      } else if (bitrate > 1536 || stream.profile?.includes("MA")) {
        // High bitrate/lossless DTS → E-AC3 640k (Dolby's recommended rate for quality)
        args.push(`-c:a:${newIndex} eac3`);
        args.push(`-b:a:${newIndex} 640k`);
        args.push(`-ac:${newIndex} 6`);
        response.infoLog += `  Audio ${newIndex}: DTS-HD/MA → E-AC3 640k (archival quality)\n`;
      } else {
        // Standard DTS 768-1536k → E-AC3 with appropriate bitrate
        const targetBitrate = bitrate <= 768 ? 448 : 640;
        args.push(`-c:a:${newIndex} eac3`);
        args.push(`-b:a:${newIndex} ${targetBitrate}k`);
        args.push(`-ac:${newIndex} 6`);
        response.infoLog += `  Audio ${newIndex}: DTS ${bitrate}k → E-AC3 ${targetBitrate}k\n`;
      }
      needsProcessing = true;
    } else if (stream.codec_name === "truehd") {
      // TrueHD → E-AC3 640k (often has Atmos, preserve quality)
      args.push(`-c:a:${newIndex} eac3`);
      args.push(`-b:a:${newIndex} 640k`);
      if (stream.channels > 6) {
        args.push(`-ac:${newIndex} 6`);  // Downmix 7.1 to 5.1
        response.infoLog += `  Audio ${newIndex}: TrueHD 7.1 → E-AC3 640k 5.1\n`;
      } else {
        response.infoLog += `  Audio ${newIndex}: TrueHD → E-AC3 640k (archival quality)\n`;
      }
      needsProcessing = true;
    } else if (stream.codec_name === "flac" || stream.codec_name.includes("pcm")) {
      // Lossless audio conversion based on channels
      if (stream.channels <= 2) {
        // Lossless stereo → AAC (transparent at 256k)
        args.push(`-c:a:${newIndex} aac`);
        args.push(`-b:a:${newIndex} 256k`);
        response.infoLog += `  Audio ${newIndex}: ${stream.codec_name} stereo → AAC 256k\n`;
      } else {
        // Lossless multichannel → E-AC3 640k
        args.push(`-c:a:${newIndex} eac3`);
        args.push(`-b:a:${newIndex} 640k`);
        args.push(`-ac:${newIndex} 6`);
        response.infoLog += `  Audio ${newIndex}: ${stream.codec_name} ${stream.channels}ch → E-AC3 640k\n`;
      }
      needsProcessing = true;
    } else if (stream.channels > 2) {
      // Other multi-channel formats → E-AC3 with smart bitrate
      const targetBitrate = bitrate > 448 ? 640 : 448;
      args.push(`-c:a:${newIndex} eac3`);
      args.push(`-b:a:${newIndex} ${targetBitrate}k`);
      args.push(`-ac:${newIndex} 6`);
      response.infoLog += `  Audio ${newIndex}: ${stream.codec_name} → E-AC3 ${targetBitrate}k\n`;
      needsProcessing = true;
    } else {
      // Other stereo formats → AAC
      const targetBitrate = Math.min(256, Math.max(192, bitrate * 0.7));
      args.push(`-c:a:${newIndex} aac`);
      args.push(`-b:a:${newIndex} ${Math.round(targetBitrate)}k`);
      response.infoLog += `  Audio ${newIndex}: ${stream.codec_name} → AAC ${Math.round(targetBitrate)}k\n`;
      needsProcessing = true;
    }

    // Set language and disposition
    args.push(`-metadata:s:a:${newIndex} language=eng`);
    if (newIndex === 0) {
      args.push(`-disposition:a:${newIndex} default`);
      response.infoLog += `    ↳ Set as DEFAULT\n`;
    } else {
      args.push(`-disposition:a:${newIndex} 0`);
    }
  });

  response.infoLog += "\n";

  // ========================================
  // SUBTITLE PROCESSING - ENGLISH PRIORITY
  // ========================================
  response.infoLog += "📝 Subtitle Analysis:\n";

  // Categorize subtitles
  const englishForced = [];
  const englishSDH = [];
  const englishRegular = [];
  const nonEnglish = [];

  subStreams.forEach((stream, idx) => {
    const lang = stream.tags?.language?.toLowerCase() || "";
    const title = (stream.tags?.title || "").toLowerCase();
    const isEnglish = lang === "eng" || lang === "en" || lang === "english" ||
                      (!lang && title.includes("english"));
    const isForced = stream.disposition?.forced === 1 || title.includes("forced") ||
                     title.includes("foreign");
    const isSDH = title.includes("sdh") || title.includes("cc") ||
                  stream.disposition?.hearing_impaired === 1;

    if (isEnglish && isForced) {
      englishForced.push(stream);
      response.infoLog += `  Track ${idx}: English Forced\n`;
    } else if (isEnglish && isSDH) {
      englishSDH.push(stream);
      response.infoLog += `  Track ${idx}: English SDH/CC\n`;
    } else if (isEnglish) {
      englishRegular.push(stream);
      response.infoLog += `  Track ${idx}: English\n`;
    } else {
      nonEnglish.push(stream);
      response.infoLog += `  Track ${idx}: ${lang || 'Unknown'}\n`;
    }
  });

  // Build ordered subtitle list
  const orderedSubs = [];
  orderedSubs.push(...englishForced);
  orderedSubs.push(...englishSDH);
  orderedSubs.push(...englishRegular);

  // If no English found, keep all
  if (orderedSubs.length === 0 && subStreams.length > 0) {
    orderedSubs.push(...subStreams);
    response.infoLog += "  ⚠ No English subtitles identified, keeping all\n";
  }

  if (orderedSubs.length !== subStreams.length ||
      orderedSubs.some((s, i) => subStreams[i] !== s)) {
    needsProcessing = true;
    response.infoLog += `☑ Subtitles need optimization (${orderedSubs.length}/${subStreams.length} tracks)\n`;
  }

  // Check for subtitle compatibility with MP4
  let subsToMap = orderedSubs;
  if (outputContainer === "mp4") {
    // Filter out incompatible subtitle formats for MP4
    const incompatibleFormats = ['ass', 'ssa', 'hdmv_pgs_subtitle', 'pgssub', 'dvd_subtitle', 'dvdsub'];
    const compatibleSubs = orderedSubs.filter(sub =>
      !incompatibleFormats.includes(sub.codec_name?.toLowerCase())
    );

    if (compatibleSubs.length < orderedSubs.length) {
      response.infoLog += `  ⚠ Removing ${orderedSubs.length - compatibleSubs.length} incompatible subtitle tracks for MP4\n`;
      if (compatibleSubs.length === 0) {
        response.infoLog += `    → No MP4-compatible subtitles found, skipping all subtitle tracks\n`;
      }
    }
    subsToMap = compatibleSubs;
  }

  // Map subtitles
  subsToMap.forEach((stream, newIndex) => {
    const originalIndex = subStreams.indexOf(stream);
    args.push(`-map 0:s:${originalIndex}`);

    // Set metadata
    args.push(`-metadata:s:s:${newIndex} language=eng`);

    // Set forced subtitle as default
    if (englishForced.includes(stream) && newIndex === 0) {
      args.push(`-disposition:s:${newIndex} default+forced`);
      response.infoLog += `    ↳ Set English Forced as DEFAULT\n`;
    } else if (englishForced.includes(stream)) {
      args.push(`-disposition:s:${newIndex} forced`);
    } else {
      args.push(`-disposition:s:${newIndex} 0`);
    }
  });

  // Container-specific subtitle handling
  if (outputContainer === "mp4" && subsToMap.length > 0) {
    args.push("-c:s mov_text");
  } else if (subsToMap.length > 0) {
    args.push("-c:s copy");
  }

  response.infoLog += "\n";

  // ========================================
  // CHAPTER HANDLING
  // ========================================
  if (hasChapters) {
    args.push("-map_chapters 0");
    response.infoLog += "📖 Preserving existing chapters\n";
  } else if (needsChapters && !isTranscodedFile) {
    // Only generate chapters for source files, not for post-processing checks
    // Calculate optimal chapter count with smooth scaling
    let targetInterval;
    if (durationMinutes <= 15) {
      targetInterval = 5;  // Very short content: 5 min chapters
    } else if (durationMinutes <= 45) {
      // TV episodes: smoothly scale from 5 to 8 minutes
      targetInterval = 5 + (durationMinutes - 15) * 0.1;
    } else if (durationMinutes <= 90) {
      // Short movies: smoothly scale from 8 to 10 minutes
      targetInterval = 8 + (durationMinutes - 45) * 0.044;
    } else {
      // Long movies: 10-12 minutes, capped at 15
      targetInterval = Math.min(15, 10 + (durationMinutes - 90) * 0.02);
    }

    // Calculate number of chapters
    let numChapters = Math.round(durationMinutes / targetInterval);

    // Apply sensible minimums based on content length
    const minChapters = durationMinutes <= 20 ? 2 :
                        durationMinutes <= 45 ? 4 :
                        durationMinutes <= 90 ? 6 : 8;
    numChapters = Math.max(minChapters, numChapters);

    // Ensure no chapter exceeds 15 minutes
    const actualInterval = durationMinutes / numChapters;
    if (actualInterval > 15) {
      numChapters = Math.ceil(durationMinutes / 15);
    }

    const finalInterval = durationMinutes / numChapters;

    response.infoLog += `📖 Generating ${numChapters} chapters (every ${finalInterval.toFixed(1)} minutes)\n`;

    // Generate chapter metadata in FFmpeg format
    let chapterMetadata = ';FFMETADATA1\n';
    const intervalSeconds = finalInterval * 60;

    for (let i = 0; i < numChapters; i++) {
      const startTime = Math.floor(i * intervalSeconds * 1000); // in milliseconds
      const endTime = Math.floor((i + 1) * intervalSeconds * 1000);

      chapterMetadata += '\n[CHAPTER]\n';
      chapterMetadata += `TIMEBASE=1/1000\n`;
      chapterMetadata += `START=${startTime}\n`;
      chapterMetadata += `END=${Math.min(endTime, durationSeconds * 1000)}\n`; // Don't exceed file duration
      chapterMetadata += `title=Chapter ${i + 1}\n`;
    }

    // Write metadata to a temporary file
    const fs = require('fs');
    const path = require('path');

    // Clean up any old chapter files (older than 1 hour) to prevent accumulation
    try {
      const tempDir = '/temp';
      const files = fs.readdirSync(tempDir);
      const now = Date.now();
      const maxAge = 5 * 60 * 60 * 1000; // 5 hours in milliseconds

      files.filter(f => f.startsWith('chapters_') && f.endsWith('.txt')).forEach(file => {
        const filePath = path.join(tempDir, file);
        try {
          const stats = fs.statSync(filePath);
          if (now - stats.mtimeMs > maxAge) {
            fs.unlinkSync(filePath);
          }
        } catch (e) {
          // Ignore errors for individual files
        }
      });
    } catch (e) {
      // Ignore cleanup errors - not critical
    }

    // Create new chapter file with unique name
    const chapterFile = path.join('/temp', `chapters_${Date.now()}_${Math.random().toString(36).substr(2, 9)}.txt`);

    try {
      fs.writeFileSync(chapterFile, chapterMetadata);
      // Add the metadata file as an input and map only chapters from it
      args.unshift(`-i "${chapterFile}"`);
      // Map metadata from original file (0) and chapters from the chapter file (1)
      args.push("-map_metadata 0");
      args.push("-map_chapters 1");
      response.infoLog += `  ✅ Chapter metadata file created: ${chapterFile}\n`;
    } catch (err) {
      response.infoLog += `  ⚠️ Could not create chapter file: ${err.message}\n`;
    }
  }

  // Additional MP4 container settings for Roku streaming
  if (outputContainer === "mp4") {
    args.push("-movflags +faststart");  // CRITICAL for streaming
    args.push("-tag:v hvc1");  // Proper HEVC tagging for compatibility
    args.push("-brand mp41");  // Set brand for compatibility
  }

  response.infoLog += "\n";

  // Check if we actually need to process
  if (!needsProcessing) {
    // We already detected if this is a transcoded file at the beginning
    if (isTranscodedFile) {
      // This is a transcoded file that's now optimal - let Tdarr move it
      response.infoLog += "✅ Transcoded file is optimal - ready for output\n";

      // Try to clean up chapter files from this transcoding job
      if (needsChapters) {
        const fs = require('fs');
        const path = require('path');
        try {
          const tempDir = '/temp';
          const files = fs.readdirSync(tempDir);
          // Clean up recent chapter files (created in last 30 minutes)
          const now = Date.now();
          const recentAge = 30 * 60 * 1000; // 30 minutes

          files.filter(f => f.startsWith('chapters_') && f.endsWith('.txt')).forEach(file => {
            const filePath = path.join(tempDir, file);
            try {
              const stats = fs.statSync(filePath);
              // Clean up recent files that were likely from this job
              if (now - stats.mtimeMs < recentAge) {
                fs.unlinkSync(filePath);
                response.infoLog += `  🧹 Cleaned up chapter file: ${file}\n`;
              }
            } catch (e) {
              // Ignore errors
            }
          });
        } catch (e) {
          // Ignore cleanup errors
        }
      }

      // Return with processFile: false but also indicate this is complete
      response.processFile = false;
      response.reQueueAfter = false;
    } else {
      // This is a source file that's already optimal - no action needed
      response.infoLog += "✅ Source file already optimal, no processing needed\n";
    }
    return response;
  }

  // Build final command
  response.preset = `<io>${args.join(" ")}`;
  response.processFile = true;
  response.container = `.${outputContainer}`;
  response.infoLog += "☑ Processing file with single optimized pass\n";
  response.infoLog += "🚀 Optimized for Roku streaming with fast start and seeking\n";

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;