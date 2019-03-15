//
//  ModuleA.m
//  ApplicationMediator
//
//  Created by JunhuaShao on 2019/3/6.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import "ModuleA.h"

@implementation ModuleA

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"%@--->%s",self.class,__FUNCTION__);
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"%@--->%s",self.class,__FUNCTION__);
}


@end
