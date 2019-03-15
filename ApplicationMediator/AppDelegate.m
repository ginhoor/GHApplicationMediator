//
//  AppDelegate.m
//  ApplicationMediator
//
//  Created by JunhuaShao on 2019/3/6.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import "AppDelegate.h"
#import "GHApplicationMediator.h"
#import "ModuleA.h"
#import "ModuleB.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

+ (void)load
{
    [GHApplicationMediator registerAppilgationModuleDelegate:[[ModuleA alloc] init]];
   
    [GHApplicationMediator registerAppilgationModuleDelegate:[[ModuleB alloc] init]];
    
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [[GHApplicationMediator sharedInstance] respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [[GHApplicationMediator sharedInstance] methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    [[GHApplicationMediator sharedInstance] forwardInvocation:anInvocation];
}

@end
