//
//  GHApplicationMediator.m
//  GinhoorFramework
//
//  Created by JunhuaShao on 2019/3/4.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import "GHApplicationMediator.h"

@interface GHApplicationMediator()
@property (nonatomic, strong) NSMutableArray *applicationModuleDelegates;
@end

@implementation GHApplicationMediator

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

+ (void)addModuleDelegate:(id)moduleDelegate
{
    GHApplicationMediator *mediator = [GHApplicationMediator sharedInstance];
#if GHAPPLICATIONMEDIATOR_DEBUG_MODE
    [mediator.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSAssert(![obj isKindOfClass:[moduleDelegate class]], @"ERROR：重复添加的delegate：%@", [moduleDelegate class]);
    }];
#endif
    [mediator.applicationModuleDelegates addObject:moduleDelegate];
#if GHAPPLICATIONMEDIATOR_DEBUG_MODE
    NSLog(@"applicationModuleDelegates：\n%@",mediator.applicationModuleDelegates);
#endif
}

+ (BOOL)removeModuleDelegateByClass:(Class)moduleClass
{
    GHApplicationMediator *mediator = [GHApplicationMediator sharedInstance];
    __block BOOL result = NO;
    [mediator.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull delegate, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([delegate isMemberOfClass:moduleClass]) {
            [mediator.applicationModuleDelegates removeObject:delegate];
            result = YES;
            *stop = YES;
        }
    }];
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


#pragma mark- Private Method

- (BOOL)hasDelegateRespondsToSelector:(SEL)selector
{
    __block BOOL result = NO;
    
    [self.applicationModuleDelegates enumerateObjectsUsingBlock:^(id  _Nonnull delegate, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([delegate respondsToSelector:selector]) {
            result = YES;
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

