//
//  HcdFileManager.h
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/5.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HcdFileManager : NSObject

+ (NSURL *)DocumentURL;

+ (NSURL *)LibraryURL;

+ (NSURL *)MovURL;

@end

NS_ASSUME_NONNULL_END
