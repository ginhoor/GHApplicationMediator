//
//  GHApplicationMediator.h
//  CommercialVehiclePlatform
//
//  Created by JunhuaShao on 2019/3/4.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface GHApplicationMediator : UIResponder<UIApplicationDelegate, UNUserNotificationCenterDelegate>


+ (instancetype)sharedInstance;

+ (NSArray *)applicationModuleDelegates;

+ (void)registerAppilgationModuleDelegate:(id<UIApplicationDelegate>)moduleDelegate;
+ (void)registerNotificationModuleDelegate:(id<UIApplicationDelegate, UNUserNotificationCenterDelegate>)moduleDelegate;
+ (BOOL)removeModuleDelegateByClass:(Class)moduleClass;

@property (nonatomic, assign) UNNotificationPresentationOptions defaultNotificationPresentationOptions;

@end

NS_ASSUME_NONNULL_END

