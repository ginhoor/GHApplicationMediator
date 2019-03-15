//
//  GHAppDelegate.m
//  GHApplicationMediator
//
//  Created by ginhoor on 03/15/2019.
//  Copyright (c) 2019 ginhoor. All rights reserved.
//

#import "GHAppDelegate.h"
#import "GHApplicationMediator.h"
#import "ModuleA.h"
#import "ModuleB.h"

@implementation GHAppDelegate

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
