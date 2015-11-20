//
//  Batchinstaller.h
//  batchinstaller
//
//  Created by MiaoGuangfa on 11/19/15.
//  Copyright © 2015 MiaoGuangfa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Batchinstaller : NSObject

+ (Batchinstaller *)sharedInstance;
- (void) start:(const char *[]) argv argumentsNumber:(int) argc;
@end
