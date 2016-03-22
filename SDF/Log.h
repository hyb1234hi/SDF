//
//  Logger.h
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(UInt8, LOG_LV) {
    LOG_LV_NONE = 0,
    LOG_LV_INFO = 1 << 0,
    LOG_LV_WARN = 1 << 1,
    LOG_LV_ERR = 1 << 2,
    LOG_LV_DEBUG = 1 << 3,
    LOG_LV_ALL = 0xFF
};

void _log_set_level(LOG_LV level);
void _log(LOG_LV level, NSString* format, ...);

#define LOG(lv, ft, ...) (_log(lv, ft, ##__VA_ARGS__))
#define LOG_LV(lv) (_log_set_level(lv))

#define LOGINFO(ft, ...) (_log(LOG_LV_INFO, ft, ##__VA_ARGS__))
#define LOGWARN(ft, ...) (_log(LOG_LV_WARN, ft, ##__VA_ARGS__))
#define LOGDEBUG(ft, ...) (_log(LOG_LV_DEBUG, ft, ##__VA_ARGS__))
#define LOGERR(ft, ...) (_log(LOG_LV_ERR, ft, ##__VA_ARGS__))
