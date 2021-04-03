//
// Created by yangbin on 2021/3/28.
//

#ifndef MEDIA_PLAYER_FFMPEG_DEMUXER_H_
#define MEDIA_PLAYER_FFMPEG_DEMUXER_H_

#include <memory>

extern "C" {
#include "libavformat/avformat.h"
};

#include "base/message_loop.h"

#include "pipeline_status.h"
#include "decoder_buffer.h"
#include "data_source.h"

#include "audio_decoder_config.h"
#include "video_decoder_config.h"

#include "ffmpeg_glue.h"

namespace media {

class DemuxerHost : public DataSourceHost {
 public:
  /**
   * Set the duration of media.
   * Duration may be kInfiniteDuration() if the duration is not known.
   */
  virtual void SetDuration(chrono::microseconds duration) = 0;

  /**
   * Stops execution of the pipeline due to a fatal error.
   * Do not call this method with PipelineStatus::OK.
   */
  virtual void OnDemuxerError(PipelineStatus error) = 0;

 protected:

  virtual ~DemuxerHost();

};

class FFmpegDemuxer;

class FFmpegDemuxerStream {
 public:
  enum Type {
    UNKNOWN,
    AUDIO,
    VIDEO,
    NUM_TYPES,  // Always keep this entry as the last one!
  };

  FFmpegDemuxerStream(FFmpegDemuxer *demuxer, AVStream *stream);

  /**
   * @return The Type of stream.
   */
  Type type();

  /**
   * Returns the duration of this stream.
   */
  chrono::microseconds duration();

  /**
   * Returns elapsed time based on the already queued packets.
   * Used to determine stream duration when it's not known ahead of time.
   */
  TimeDelta GetElapsedTime() const;

 protected:
 public:
  virtual ~FFmpegDemuxerStream();

 private:

  enum Status {
    kOk,
    kAborted,
    kConfigChanged,
  };

  // Request a buffer to returned via the provided callback.
  //
  // The first parameter indicates the status of the read.
  // The second parameter is non-NULL and contains media data
  // or the end of the stream if the first parameter is kOk. NULL otherwise.
  typedef std::function<void(Status,
                             const std::shared_ptr<DecoderBuffer> &)> ReadCB;

  void Read(const ReadCB &read_cb);

  // Carries out enqueuing a pending read on the demuxer thread.
  void ReadTask(const ReadCB &read_cb);

  // Attempts to fulfill a single pending read by dequeueing a buffer and read
  // callback pair and executing the callback. The calling function must
  // acquire `lock_` before calling this function.
  void FulfillPendingRead();

  // Convert an FFmpeg stream timestamp in to a chrono::microseconds.
  static chrono::microseconds ConvertStreamTimestamp(const AVRational &time_base, int64 timestamp);

  FFmpegDemuxer *demuxer_;
  AVStream *stream_;

  AudioDecoderConfig audio_config_;
  VideoDecoderConfig video_config_;

  Type type_;
  chrono::microseconds duration_;
  bool stopped_;

  typedef std::deque<std::shared_ptr<DecoderBuffer>> BufferQueue;
  BufferQueue buffer_queue_;

  typedef std::deque<ReadCB> ReadQueue;
  ReadQueue read_queue_;

  // mutex to synchronize access to `buffer_queue_`, `read_queue_`, and `stopped_`
  mutable std::mutex mutex_;

  DISALLOW_COPY_AND_ASSIGN(FFmpegDemuxerStream);

};

class FFmpegDemuxer : public FFmpegUrlProtocol {

 public:
  FFmpegDemuxer(std::shared_ptr<base::MessageLoop> message_loop, std::shared_ptr<DataSource> data_source);

  std::shared_ptr<base::MessageLoop> message_loop() { return message_loop_; }

  void Initialize(DemuxerHost *host, const PipelineStatusCB &status_cb);

  /**
   * Post a task to perform additional demuxing.
   */
  void PostDemuxTask();

 private:

  // Carries out initialization on the demuxer thread.
  void InitializeTask(DemuxerHost *host, const PipelineStatusCB &status_cb);

  // Carries out demuxing and satisfying stream reads on the demuxer thread.
  void DemuxTask();

  // Return ture if any of the streams have pending reads.
  // Since we lazily post a `DemuxTask()` for every read, we use
  // this method to quickly terminate the tasks if there is
  // no work to do.
  //
  // Must to called on the demuxer thread.
  bool StreamHavePendingReads();

  DemuxerHost *host_;

  std::shared_ptr<base::MessageLoop> message_loop_;
  std::shared_ptr<DataSource> data_source_;

  // FFmpeg context handle.
  AVFormatContext *format_context_;

  // |streams_| mirrors the AVStream array in |format_context_|. It contains
  // FFmpegDemuxerStreams encapsluating AVStream objects at the same index.
  //
  // Since we only support a single audio and video stream, |streams_| will
  // contain NULL entries for additional audio/video streams as well as for
  // stream types that we do not currently support.
  //
  // Once initialized, operations on FFmpegDemuxerStreams should be carried out
  // on the demuxer thread.
  typedef std::vector<std::shared_ptr<FFmpegDemuxerStream>> StreamVector;
  StreamVector streams_;

  // Derived bitrate after initialization has completed.
  int bitrate_;

  // The first timestamp of the opened media file. This is used to set the
  // starting clock value to match the timestamps in the media file. Default
  // is 0.
  chrono::microseconds start_time_;

  // Set if we know duration of the audio stream. Used when processing end of
  // stream -- at this moment we definitely know duration.
  bool duration_known_;

  DISALLOW_COPY_AND_ASSIGN(FFmpegDemuxer);

  void StreamHasEnded();
};

}

#endif //MEDIA_PLAYER_FFMPEG_DEMUXER_H_
