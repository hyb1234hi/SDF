//
//  Logger.m
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "Log.h"

static LOG_LV _level = LOG_LV_ALL;

void _log_set_level(LOG_LV level)
{
    _level = level;
}

void _log(LOG_LV level, NSString* format, ...)
{
    if (!(_level & level)) {
        return;
    }

    NSString* ls = nil;
    if (level & LOG_LV_INFO) {
        ls = @"[INFO]";
    }
    else if (level & LOG_LV_DEBUG) {
        ls = @"[DEBUG]";
    }
    else if (level & LOG_LV_WARN) {
        ls = @"[WARNING]";
    }
    else if (level & LOG_LV_ERR) {
        ls = @"[ERROR]";
    }

    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:SSSS";
    NSString* ds = [df stringFromDate:[NSDate date]];
    format = [NSString stringWithFormat:@"%@ %@ %@\n", ds, ls, format];

    va_list args;
    va_start(args, format);
    NSString* formattedString = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [[NSFileHandle fileHandleWithStandardOutput] writeData:[formattedString dataUsingEncoding:NSUTF8StringEncoding]];
}
