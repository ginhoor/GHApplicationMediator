//
//  GHApplicationMediator.m
//  CommercialVehiclePlatform
//
//  Created by JunhuaShao on 2019/3/4.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import "GHApplicationMediator.h"

@interface GHApplicationMediator()

@property (nonatomic, strong) NSMutableArray *applicationModuleDelegates;

@end

@implementation GHApplicationMediator

- (void)setupDefaultValues
{
    // 根据APP需要，判断是否要提示用户Badge、Sound、Alert
    self.defaultNotificationPresentationOptions = UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionAlert;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (NSArray *)applicationModuleDelegates
{
    return [GHApplicationMediator sharedInstance].applicationModuleDelegates;
}

+ (void)registerAppilgationModuleDelegate:(id<UIApplicationDelegate>)moduleDelegate
{
    NSAssert(moduleDelegate, @"ERROR：添加的AppDelegate为空", [moduleDelegate class]);
    NSAssert([moduleDelegate conformsToProtocol:@protocol(UIApplicationDelegate)], @"ERROR：添加的AppDelegate未实现<UIApplicationDelegate>", [moduleDelegate class]);
    [self addModuleDelegate:moduleDelegate];
}

+ (void)registerNotificationModuleDelegate:(id<UIApplicationDelegate, UNUserNotificationCenterDelegate>)moduleDelegate
{
    NSAssert(moduleDelegate, @"ERROR：添加的AppDelegate为空", [moduleDelegate class]);
    NSAssert([moduleDelegate conformsToProtocol:@protocol(UIApplicationDelegate)], @"ERROR：添加的AppDelegate未实现<UIApplicationDelegate>", [moduleDelegate class]);
    NSAssert([moduleDelegate conformsToProtocol:@protocol(UNUserNotificationCenterDelegate)], @"ERROR：添加的AppDelegate未实现<UNUserNotificationCenterDelegate>", [moduleDelegate class]);
    
    [self addModuleDelegate:moduleDelegate];
}

+ (void)addModuleDelegate:(id)moduleDelegate
{
    GHApplicationMediator *mediator = [GHApplicationMediator sharedInstance];
#ifdef DEBUG
    
    [mediator.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSAssert(![obj isKindOfClass:[moduleDelegate class]], @"ERROR：重复添加的delegate：%@", [moduleDelegate class]);
    }];
#endif
    [mediator.applicationModuleDelegates addObject:moduleDelegate];
#ifdef DEBUG
    NSLog(@"applicationModuleDelegates：\n%@",mediator.applicationModuleDelegates);
#endif
}

+ (BOOL)removeModuleDelegateByClass:(Class)moduleClass
{
    GHApplicationMediator *mediator = [GHApplicationMediator sharedInstance];
    
    BOOL result = NO;
    NSInteger i = 0;
    NSInteger count = mediator.applicationModuleDelegates.count;
    while (i < count) {
        id delegate = mediator.applicationModuleDelegates[i];
        if ([delegate isKindOfClass:moduleClass]) {
            [mediator.applicationModuleDelegates removeObject:delegate];
            count--;
            result = YES;
            break;
        }
        i++;
    }
    
    return result;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    _applicationModuleDelegates = [NSMutableArray array];
    [self setupDefaultValues];
}

#pragma mark- Handle Method
/**
 无法通过[super respondsToSelector:aSelector]来检测对象是否从super继承了方法。
 因此调用[super respondsToSelector:aSelector]，相当于调用了[self respondsToSelector:aSelector]
 **/
- (BOOL)respondsToSelector:(SEL)aSelector
{
    BOOL result = [super respondsToSelector:aSelector];
    if (!result) {
        result = [self hasDelegateRespondsToSelector:aSelector];
    }
    return result;
}

/**
 此方法还被用于当NSInvocation被创建的时候，比如在消息传递的时候。
 如果当前Classf可以处理未被直接实现的方法，则必须覆写此方法。
 */
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    id delegate = [self delegateRespondsToSelector:aSelector];
    if (delegate) {
        return [delegate methodSignatureForSelector:aSelector];
    }
    return [super methodSignatureForSelector:aSelector];
}

/**
 无法识别的消息处理
 */
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    __block BOOL isExec = NO;
    
    NSMethodSignature *methodSignature = anInvocation.methodSignature;
    const char *returnType = methodSignature.methodReturnType;
    // 没有返回值，或者默认返回YES
    if (0 == strcmp(returnType, @encode(void)) ||
        anInvocation.selector == @selector(application:didFinishLaunchingWithOptions:)) {
        [self notifySelectorOfAllDelegates:anInvocation.selector nofityHandler:^(id delegate) {
            [anInvocation invokeWithTarget:delegate];
            isExec = YES;
        }];
    } else if (0 == strcmp(returnType, @encode(BOOL))) {
        // 返回值为BOOL
        [self notifySelectorOfAllDelegateUntilSuccessed:anInvocation.selector defaultReturnValue:NO nofityHandler:^BOOL(id delegate) {
            
            [anInvocation invokeWithTarget:delegate];
            // 获得返回值
            NSUInteger returnValueLenth = anInvocation.methodSignature.methodReturnLength;
            BOOL *retValue = (BOOL *)malloc(returnValueLenth);
            [anInvocation getReturnValue:retValue];
            
            BOOL result = *retValue;
            return result;
        }];
    } else {
        // 等同于[self doesNotRecognizeSelector:anInvocation.selector];
        [super forwardInvocation:anInvocation];
    }
}

#pragma mark- Delegate

#pragma mark iOS10以下 收到推送消息
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNewData;
    [self notifySelectorOfAllDelegates:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:) nofityHandler:^(id<UIApplicationDelegate> delegate) {
        [delegate application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
            //接受最后一个delegate的result，最后统一回调完成
            fetchResult = result;
        }];
    }];
    completionHandler(fetchResult);
}

#pragma mark iOS10以上 收到推送消息 <UserNotifications/UserNotifications.h>

//  App在前台获取到通知
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
#ifdef DEBUG
    NSLog(@"willPresentNotification：%@", notification.request.content.userInfo);
#endif
    __block UNNotificationPresentationOptions completionOptions = self.defaultNotificationPresentationOptions;
    [self notifySelectorOfAllDelegates:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:) nofityHandler:^(id delegate) {
        [delegate userNotificationCenter:center willPresentNotification:notification withCompletionHandler:^(UNNotificationPresentationOptions options) {
            //接受最后一个delegate设置的options，且options不为空。
            if (options != 0) {
                completionOptions = options;
            }
        }];
    }];
    completionHandler(completionOptions);
}

// 应用在前台点击通知进入App时触发
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
    [self notifySelectorOfAllDelegates:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:) nofityHandler:^(id delegate) {
        [delegate userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:^{
            //不执行任何回调，统一最后回调完成。
        }];
    }];
    completionHandler();
}

#pragma mark- Private Method

- (BOOL)hasDelegateRespondsToSelector:(SEL)selector
{
    __block BOOL result = NO;
    
    [self.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull delegate, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([delegate respondsToSelector:selector]) {
            *stop = YES;
        }
    }];
    return result;
}

- (id)delegateRespondsToSelector:(SEL)selector
{
    __block id resultDelegate;
    [self.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull delegate, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([delegate respondsToSelector:selector]) {
            resultDelegate = delegate;
            *stop = YES;
        }
    }];
    return resultDelegate;
}

/**
 通知所有delegate响应方法
 
 @param selector 响应方法
 @param nofityHandler delegated处理调用事件
 */
- (void)notifySelectorOfAllDelegates:(SEL)selector nofityHandler:(void(^)(id delegate))nofityHandler
{
    if (_applicationModuleDelegates.count == 0) {
        return;
    }
    
    [self.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull delegate, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([delegate respondsToSelector:selector]) {
            if (nofityHandler) {
                nofityHandler(delegate);
            }
        }
    }];
}

/**
 通知所有的delegate，当有delegate响应为成功后，中断通知。
 
 @param selector 响应方法
 @param defaultReturnValue 默认返回值（当设置为YES时，即使没有响应对象也会返回YES。）
 @param nofityHandler delegate处理调用事件
 @return delegate处理结果
 */
- (BOOL)notifySelectorOfAllDelegateUntilSuccessed:(SEL)selector defaultReturnValue:(BOOL)defaultReturnValue nofityHandler:(BOOL(^)(id delegate))nofityHandler
{
    __block BOOL success = defaultReturnValue;
    if (_applicationModuleDelegates.count == 0) {
        return success;
    }
    [self.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull delegate, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([delegate respondsToSelector:selector]) {
            if (nofityHandler) {
                success = nofityHandler(delegate);
                if (success) {
                    *stop = YES;
                }
            }
        }
    }];
    return success;
}

@end

