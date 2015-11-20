//
//  Batchinstaller.m
//  batchinstaller
//
//  Created by MiaoGuangfa on 11/19/15.
//  Copyright © 2015 MiaoGuangfa. All rights reserved.
//

#import "Batchinstaller.h"

@interface Batchinstaller ()

@property (nonatomic, strong) NSTask *idevicelistTask;
@property (nonatomic, copy) NSString *listStream;
@property (nonatomic, copy) NSString *installStream;
@property (nonatomic, copy) NSString *uninstallStream;
@property (nonatomic, copy) NSString *packagePath;
@property (nonatomic, assign) NSUInteger index;
@property (nonatomic, assign) NSUInteger deviceCount;
@property (nonatomic, copy) NSString *packageName;
@property (nonatomic, assign) BOOL isInstall;
@property (nonatomic, assign) BOOL isUnInstall;
@end

//batchinstaller -p /your/path/xx.ipa
//batchinstaller -u com.app.demo

static Batchinstaller *_instance = NULL;

@implementation Batchinstaller


+ (Batchinstaller *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[[self class]alloc]init];
    });
    return _instance;
}

- (void)start:(const char *[])argv argumentsNumber:(int)argc
{
    if (argc == 3) {
        NSString * _option = [NSString stringWithUTF8String:argv[1]];
        if ([_option isEqualToString:@"-p"]) {
            _packagePath = [NSString stringWithUTF8String:argv[2]];
            if ([[NSFileManager defaultManager]fileExistsAtPath:_packagePath]) {
                _isInstall = YES;
                [self _listDevice];
            }else{
                NSLog(@"[Error]: No package found in this path.");
                exit(0);
            }
            
        }else if ([_option isEqualToString:@"-u"]) {
            _packageName = [NSString stringWithUTF8String:argv[2]];
            if (_packageName == nil || [_packageName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
                NSLog(@"[Error]: No package name is passed");
                exit(0);
            }else {
                _isUnInstall = YES;
                [self _listDevice];
            }
        }else{
            NSLog(@"[Error]: Option '-p' or '-u' is missed. Your should to do like this: batchinstaller -p /your/path/xxx.ipa, or batchinstaller -u com.app.demo");
            exit(0);
        }
    }else{
        NSLog(@"[Error]: Options are missed. Your should to do like this: batchinstaller -p /your/path/xxx.ipa, or batchinstaller -u com.app.demo");
        exit(0);
    }
}
- (void)_listDevice {
    NSLog(@"Preparing to get devices status......");
    _idevicelistTask = [[NSTask alloc] init];
    [_idevicelistTask setLaunchPath:@"/usr/bin/idevice_id"];
    [_idevicelistTask setArguments:[NSArray arrayWithObjects:@"-l", nil]];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkVerificationProcess:) userInfo:nil repeats:TRUE];
    
    NSPipe *pipe=[NSPipe pipe];
    [_idevicelistTask setStandardOutput:pipe];
    [_idevicelistTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [_idevicelistTask launch];
    
    [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:)
                             toTarget:self withObject:handle];
}

- (void)watchVerificationProcess:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        _listStream = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}
- (void)checkVerificationProcess:(NSTimer *)timer {
    if ([_idevicelistTask isRunning] == 0) {
        [timer invalidate];
        _idevicelistTask = nil;
    }
    NSLog(@"Connected devices: %@", _listStream);
    if (_isInstall) {
        [self _install];
    }
    
    if (_isUnInstall) {
        [self _uninstall];
    }
}

- (void) _install {
    
    if (_listStream) {
        NSLog(@"Start to install, waiting......");
        NSArray *UUIDs = [_listStream componentsSeparatedByString:@"\n"];
        
        dispatch_queue_t queue = dispatch_queue_create("install.sub.queue", DISPATCH_QUEUE_CONCURRENT);
        
        _deviceCount = [UUIDs count] -1;
        
        for (NSUInteger i=0; i<_deviceCount; i++) {
            NSString *_uuid = [UUIDs objectAtIndex:i];
            dispatch_async(queue, ^{
                
                [self installTask:_uuid];
                
            });
        }
    }else {
        NSLog(@"[Error]: No UUIDs are got, make sure there is one device is connected with PC");
    }
}

- (void) installTask:(NSString *)UUID {
    
    NSTask *_ideviceinstallerTask = [[NSTask alloc] init];
    [_ideviceinstallerTask setLaunchPath:@"/usr/bin/ideviceinstaller"];
    [_ideviceinstallerTask setArguments:[NSArray arrayWithObjects:@"-u", UUID, @"-i",_packagePath, nil]];
    
    
    NSPipe *pipe=[NSPipe pipe];
    [_ideviceinstallerTask setStandardOutput:pipe];
    [_ideviceinstallerTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [_ideviceinstallerTask launch];

    [self watchinstallProcess:handle withUUID:UUID];
}

- (void)watchinstallProcess:(NSFileHandle*)streamHandle withUUID:(NSString *)UUID{
    @autoreleasepool {
        _installStream = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        NSLog(@"Installing to %@: %@", UUID, _installStream);
        _index ++;
        if (_index == _deviceCount) {
            NSLog(@"----------------- Finished ---------------");
            exit(0);
        }
    }
}

- (void) _uninstall {
    if (_listStream) {
        NSLog(@"Start to uninstall, waiting......");
        NSArray *UUIDs = [_listStream componentsSeparatedByString:@"\n"];
        
        dispatch_queue_t queue = dispatch_queue_create("uninstall.sub.queue", DISPATCH_QUEUE_CONCURRENT);
        
        _deviceCount = [UUIDs count] -1;
        
        for (NSUInteger i=0; i<_deviceCount; i++) {
            NSString *_uuid = [UUIDs objectAtIndex:i];
            dispatch_async(queue, ^{
                
                [self uninstallTask:_uuid];
                
            });
        }
    }else {
        NSLog(@"[Error]: No UUIDs are got, make sure there is one device is connected with PC");
    }
}

- (void) uninstallTask:(NSString *)UUID {
    
    NSTask *_ideviceinstallerTask = [[NSTask alloc] init];
    [_ideviceinstallerTask setLaunchPath:@"/usr/bin/ideviceinstaller"];
    [_ideviceinstallerTask setArguments:[NSArray arrayWithObjects:@"-u", UUID, @"-U",_packageName, nil]];
    
    
    NSPipe *pipe=[NSPipe pipe];
    [_ideviceinstallerTask setStandardOutput:pipe];
    [_ideviceinstallerTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [_ideviceinstallerTask launch];
    
    [self watchuninstallProcess:handle withUUID:UUID];
}

- (void)watchuninstallProcess:(NSFileHandle*)streamHandle withUUID:(NSString *)UUID{
    @autoreleasepool {
        _uninstallStream = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        NSLog(@"UnInstalling for %@: %@", UUID, _uninstallStream);
        _index ++;
        if (_index == _deviceCount) {
            NSLog(@"----------------- Finished ---------------");
            exit(0);
        }
    }
}
@end
