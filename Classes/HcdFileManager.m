//
//  HcdFileManager.m
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/5.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import "HcdFileManager.h"

@implementation HcdFileManager

+ (NSURL *)DocumentURL {
    
    return [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
}

+ (NSURL *)LibraryURL {
    
    return [[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
}

+ (NSURL *)MovURL {
    return [[HcdFileManager LibraryURL] URLByAppendingPathComponent:@"MOV" isDirectory:YES];
}

@end
