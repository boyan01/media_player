//
// Created by yangbin on 2021/4/5.
//

#ifndef MEDIA_PLAYER_DEMUXER_DEMUXER_H_
#define MEDIA_PLAYER_DEMUXER_DEMUXER_H_

#include "memory"

#include "base/message_loop.h"

#include "demuxer_stream.h"
#include "media_tracks.h"

namespace media {

constexpr double kNoTimestamp() {
  return 0;
}

typedef int PipelineStatus;
typedef std::function<void(bool)> PipelineStatusCB;

class DemuxerHost {
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

  virtual ~DemuxerHost() = default;

};

class Demuxer : std::enable_shared_from_this<Demuxer> {

 public:

  // Notifies demuxer clients that media track configuration has been updated
// (e.g. the initial stream metadata has been parsed successfully, or a new
// init segment has been parsed successfully in MSE case).
  using MediaTracksUpdatedCB = std::function<void(std::unique_ptr<MediaTracks>)>;

  Demuxer(std::shared_ptr<base::MessageLoop> message_loop,
          DataSource *data_source,
          MediaTracksUpdatedCB media_tracks_updated_cb);

  std::shared_ptr<base::MessageLoop> message_loop() { return task_runner_; }

  void Initialize(DemuxerHost *host, PipelineStatusCB status_cb);

  /**
   * Post a task to perform additional demuxing.
   */
  void PostDemuxTask();

  // Allow DemuxerStream to notify us when there is updated information
  // about what buffered data is available.
  void NotifyBufferingChanged();

  // The pipeline is being stopped either as a result of an error or because
  // the client called Stop().
  virtual void Stop(const std::function<void(void)> &callback);

  DemuxerStream *GetFirstStream(DemuxerStream::Type type);

  std::vector<DemuxerStream *> GetAllStreams();

 protected:

  virtual std::string GetDisplayName() const;

 private:

  // Carries out demuxing and satisfying stream reads on the demuxer thread.
  void DemuxTask();

  // Return ture if any of the streams have pending reads.
  // Since we lazily post a `DemuxTask()` for every read, we use
  // this method to quickly terminate the tasks if there is
  // no work to do.
  //
  // Must to called on the demuxer thread.
  bool StreamsHavePendingReads();

  // Signal all DemuxerStream that the stream has ended.
  //
  // Must be called on the demuxer thread.
  void StreamHasEnded();

  // Returns the stream from |streams_| that matches |type| as an
  // DemuxerStream.
  std::shared_ptr<DemuxerStream> GetFFmpegStream(DemuxerStream::Type type) const;

  // Carries out stopping the demuxer streams on the demuxer thread.
  void StopTask(const std::function<void(void)> &callback);

  // Signal the blocked thread that the read has completed, with |size| bytes
  // read or kReadError in case of error.
  virtual void SignalReadCompleted(int size);

  void OnOpenContextDone(bool result, PipelineStatusCB status_cb);

  DemuxerHost *host_;

  std::unique_ptr<BlockingUrlProtocol> url_protocol_;

  std::shared_ptr<base::MessageLoop> task_runner_;
  DataSource *data_source_;
  double duration_ = kNoTimestamp();

  // FFmpeg context handle.
  AVFormatContext *format_context_;

  // |streams_| mirrors the AVStream array in |format_context_|. It contains
  // DemuxerStreams encapsluating AVStream objects at the same index.
  //
  // Since we only support a single audio and video stream, |streams_| will
  // contain NULL entries for additional audio/video streams as well as for
  // stream types that we do not currently support.
  //
  // Once initialized, operations on DemuxerStreams should be carried out
  // on the demuxer thread.
  typedef std::vector<std::shared_ptr<DemuxerStream>> StreamVector;
  StreamVector streams_;

  std::map<MediaTrack::Id, DemuxerStream *> track_id_to_demux_stream_map_;

  // Flag to indicate if read has ever failed. Once set to true, it will
  // never be reset. This flag is set true and accessed in Read().
  bool read_has_failed_;

  bool stopped_ = false;

  int last_read_bytes_;
  int64 read_position_;

  // Derived bitrate after initialization has completed.
  int bitrate_;

  // The first timestamp of the opened media file. This is used to set the
  // starting clock value to match the timestamps in the media file. Default
  // is 0.
  double start_time_;

  MediaTracksUpdatedCB media_tracks_updated_cb_;

  // Whether audio has been disabled for this demuxer (in which case this class
  // drops packets destined for AUDIO demuxer streams on the floor).
  bool audio_disabled_;

  // Set if we know duration of the audio stream. Used when processing end of
  // stream -- at this moment we definitely know duration.
  bool duration_known_;

  bool is_local_file_;

  std::unique_ptr<FFmpegGlue> glue_;

  DISALLOW_COPY_AND_ASSIGN(Demuxer);

};

} // namespace media
#endif //MEDIA_PLAYER_DEMUXER_DEMUXER_H_