//
//  main.m
//  batchinstaller
//
//  Created by MiaoGuangfa on 11/19/15.
//  Copyright © 2015 MiaoGuangfa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Batchinstaller.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [[Batchinstaller sharedInstance]start:argv argumentsNumber:argc];
    }
    
    [[NSRunLoop currentRunLoop] run];
    
    return 0;
}
