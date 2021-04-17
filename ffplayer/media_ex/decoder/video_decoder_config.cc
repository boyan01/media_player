//
// Created by yangbin on 2021/3/28.
//

#include "base/logging.h"
#include "video_decoder_config.h"

namespace media {

VideoDecoderConfig::VideoDecoderConfig()
    : codec_id_(AV_CODEC_ID_NONE),
      format_(AV_PIX_FMT_NONE),
      extra_data_size_(0),
      is_encrypted_(false),
      extra_data_(nullptr) {

}

VideoDecoderConfig::VideoDecoderConfig(
    AVCodecID codec_id,
    AVPixelFormat format,
    const base::Size &coded_size,
    const base::Rect &visible_rect,
    const base::Size &natural_size,
    const uint8 *extra_data,
    size_t extra_data_size,
    bool is_encrypted) {
  Initialize(codec_id, format, coded_size, visible_rect,
             natural_size, extra_data, extra_data_size, is_encrypted, true);
}

void VideoDecoderConfig::Initialize(AVCodecID codec_id,
                                    AVPixelFormat format,
                                    const base::Size &coded_size,
                                    const base::Rect &visible_rect,
                                    const base::Size &natural_size,
                                    const uint8 *extra_data,
                                    size_t extra_data_size,
                                    bool is_encrypted,
                                    bool record_stats) {
  CHECK((extra_data_size != 0) == (extra_data != nullptr));

  if (record_stats) {
//    UMA_HISTOGRAM_ENUMERATION("Media.VideoCodec", CodecId, kVideoCodecMax + 1);
//    // Drop UNKNOWN because U_H_E() uses one bucket for all values less than 1.
//    if (profile >= 0) {
//      UMA_HISTOGRAM_ENUMERATION("Media.VideoCodecProfile", profile,
//                                VIDEO_CODEC_PROFILE_MAX + 1);
//    }
//    UMA_HISTOGRAM_COUNTS_10000("Media.VideoCodedWidth", coded_size.width());
//    UmaHistogramAspectRatio("Media.VideoCodedAspectRatio", coded_size);
//    UMA_HISTOGRAM_COUNTS_10000("Media.VideoVisibleWidth", visible_rect.width());
//    UmaHistogramAspectRatio("Media.VideoVisibleAspectRatio", visible_rect);
  }

  codec_id_ = codec_id;
  format_ = format;
  coded_size_ = coded_size;
  visible_rect_ = visible_rect;
  natural_size_ = natural_size;
  extra_data_size_ = extra_data_size;

  if (extra_data_size_ > 0) {
    extra_data_ = new uint8[extra_data_size_];
    memcpy(extra_data_, extra_data, extra_data_size_);
  } else {
    extra_data_ = nullptr;
  }

  is_encrypted_ = is_encrypted;
}

VideoDecoderConfig::~VideoDecoderConfig() {
  delete[] extra_data_;
}

void VideoDecoderConfig::CopyFrom(const VideoDecoderConfig &video_config) {
  Initialize(video_config.CodecId(),
             video_config.format(),
             video_config.coded_size(),
             video_config.visible_rect(),
             video_config.natural_size(),
             video_config.extra_data(),
             video_config.extra_data_size(),
             video_config.is_encrypted(),
             false);
}

bool VideoDecoderConfig::IsValidConfig() const {
  return codec_id_ != AV_CODEC_ID_NONE &&
      natural_size_.width() > 0 &&
      natural_size_.height() > 0 &&
      format_ != AV_PIX_FMT_NONE;
}

bool VideoDecoderConfig::Matches(const VideoDecoderConfig &config) const {
  return ((CodecId() == config.CodecId()) &&
      (format() == config.format()) &&
      (coded_size() == config.coded_size()) &&
      (visible_rect() == config.visible_rect()) &&
      (natural_size() == config.natural_size()) &&
      (extra_data_size() == config.extra_data_size()) &&
      (!extra_data() || !memcmp(extra_data(), config.extra_data(),
                                extra_data_size())) &&
      (is_encrypted() == config.is_encrypted()));
}

std::string VideoDecoderConfig::AsHumanReadableString() const {
  std::ostringstream s;
  s << "CodecId: " << CodecId()
    << " format: " << format()
    << " coded size: [" << coded_size().width()
    << "," << coded_size().height() << "]"
    << " visible rect: [" << visible_rect().x()
    << "," << visible_rect().y()
    << "," << visible_rect().width()
    << "," << visible_rect().height() << "]"
    << " natural size: [" << natural_size().width()
    << "," << natural_size().height() << "]"
    << " encryption: [" << (is_encrypted() ? "true" : "false") << "]";
  return s.str();
}

AVCodecID VideoDecoderConfig::CodecId() const {
  return codec_id_;
}

AVPixelFormat VideoDecoderConfig::format() const {
  return format_;
}

base::Size VideoDecoderConfig::coded_size() const {
  return coded_size_;
}

base::Rect VideoDecoderConfig::visible_rect() const {
  return visible_rect_;
}

base::Size VideoDecoderConfig::natural_size() const {
  return natural_size_;
}

uint8 *VideoDecoderConfig::extra_data() const {
  return extra_data_;
}

size_t VideoDecoderConfig::extra_data_size() const {
  return extra_data_size_;
}

bool VideoDecoderConfig::is_encrypted() const {
  return is_encrypted_;
}

}