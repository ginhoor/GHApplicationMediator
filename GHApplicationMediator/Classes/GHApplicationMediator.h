//
//  GHApplicationMediator.h
//  GinhoorFramework
//
//  Created by JunhuaShao on 2019/3/4.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define GHAPPLICATIONMEDIATOR_DEBUG_MODE 0

NS_ASSUME_NONNULL_BEGIN

@interface GHApplicationMediator : UIResponder <UIApplicationDelegate>

+ (instancetype)sharedInstance;

+ (NSArray *)applicationModuleDelegates;

+ (void)registerAppilgationModuleDelegate:(id<UIApplicationDelegate>)moduleDelegate;
+ (BOOL)removeModuleDelegateByClass:(Class)moduleClass;

@end

NS_ASSUME_NONNULL_END

