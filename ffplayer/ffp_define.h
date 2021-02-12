//
// Created by boyan on 2021/2/12.
//

#ifndef FFPLAYER_FFP_DEFINE_H
#define FFPLAYER_FFP_DEFINE_H

#include <memory>

template<typename T>
using unique_ptr_d = std::unique_ptr<T, void (*)(T *ptr)>;

#define CHECK_VALUE_WITH_RETURN(VALUE, RETURN)\
if(!(VALUE)) {\
    av_log(nullptr, AV_LOG_ERROR, "check value failed\n");\
    return RETURN;\
}\

#define CHECK_VALUE(VALUE)\
if(!(VALUE)) {\
    av_log(nullptr, AV_LOG_ERROR, "check value failed\n");\
    return;\
}\

#endif //FFPLAYER_FFP_DEFINE_H
