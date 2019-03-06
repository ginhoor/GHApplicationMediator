# GHApplicationMediator

## 为什么AppDelegate不容易维护

AppDelegate控制着App的主要生命周期，比如App初始化完成后构建主视图，App接收到远程消息回调，Url-Scheme回调，第三方SDK初始化，数据库初始化等等。

基于这个原因，随着App的版本迭代，AppDelegate中的代码量会越来越大。当AppDelegate的代码量到达一定程度时，我们就该开始考虑将AppDelegate中的代码进行模块化封装。

## 1.0版本

在考虑这个方案的时候，我们的项目刚刚度过了原型期，使用的SDK并不多，业务需求也还没有起来。

在这个背景，我选择用Category封装AppDelegate的方案。

创建一个AppDelegate+XXX的Category，比如下面这个AppDelegate+CEReachability

```objc
#import "AppDelegate.h"

@interface AppDelegate (CEReachability)
- (void)setupReachability;
@end
    
@implementation AppDelegate (CEReachability)

- (void)setupReachability
{
    // Allocate a reachability object
    Reachability *reach = [Reachability reachabilityWithHostname:kServerBaseUrl];
    
    // Set the blocks
    reach.reachableBlock = ^(Reachability *reach) {
        
        if (reach.currentReachabilityStatus == ReachableViaWWAN) {
            BLYLogInfo(@"ReachabilityStatusChangeBlock--->蜂窝数据网");
            [CESettingsManager sharedInstance].needNoWifiAlert = YES;
        } else if (reach.currentReachabilityStatus == ReachableViaWiFi) {
            BLYLogInfo(@"ReachabilityStatusChangeBlock--->WiFi网络");
            [CESettingsManager sharedInstance].needNoWifiAlert = NO;
        }
    };
    
    reach.unreachableBlock = ^(Reachability *reach) {
        BLYLogInfo(@"ReachabilityStatusChangeBlock--->未知网络状态");
    };
    
    // Start the notifier, which will cause the reachability object to retain itself!
    [reach startNotifier];   
}
```



然后在AppDelegate中注册这个模块

```objc
#import "AppDelegate+CEReachability.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupReachability];
    return YES;
}
```



有同学可能会问，为什么不直接在Category中实现UIApplicationDelegate的方法。



同时import多个Category，并且多个Category都实现了同一个方法（例如 ：`- (void)applicationWillResignActive:(UIApplication *)application`），在调用该方法时选用哪个实现是由Category文件的编译顺序来决定（在Build Phases > Complie Sources中指定），最后一个编译的Category文件的方法实现将被使用。与import顺序无关，实际上，当有两个Category实现了同一个方法，无论你imprt的是那个Category，方法的实际实现永远是编译顺序在最后的Category文件的方法实现。



优点：

- 初步具备模块化，不同模块的注册方法由Category指定。

缺点：

- 各个Category之间是互斥关系，相同的方法不能在不同的Category中同时实现。
- 需要在AppDelegate中维护不同功能模块的实现逻辑。

## 2.0版本

随着业务需求的增加，第三方支付、IM、各种URL-Scheme配置逐渐增加，特别是Open Url和Push Notifications需要有依赖关系，方案一很快就不能满足需求了，各种奇怪的注册方式交织在一起。

迫于求生欲，我决定第二次重构。

这次重构初始动机是由于Category之间的互斥关系，有依赖流程的流程就必须写在AppDelegate中。（比如Open Url，第三方支付用到了，浏览器跳转也用到了）

于是，我增加了ApplicationMediator来管理AppDelegate与模块的通信，实现消息转发到模块的逻辑。

### ApplicationMediator

ApplicationMediator是一个单例，用于管理模块的注册与移除。

```objc
@interface CEApplicationMediator : UIResponder<UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property (nonatomic, strong) NSHashTable *applicationModuleDelegates;

+ (instancetype)sharedInstance;

+ (void)registerAppilgationModuleDelegate:(id<UIApplicationDelegate>)moduleDelegate;
+ (void)registerNotificationModuleDelegate:(id<UIApplicationDelegate,UNUserNotificationCenterDelegate>)moduleDelegate;
+ (BOOL)removeModuleDelegateByClass:(Class)moduleClass;

@property (nonatomic, assign) UNNotificationPresentationOptions defaultNotificationPresentationOptions;

@end
```



### Module

模块根据需要实现UIApplicationDelegate与UNUserNotificationCenterDelegate就可以加入到UIApplication的生命周期中。

```objc
@implementation CEAMWindowDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.backgroundColor = [UIColor whiteColor];
    // 需要将Window赋值给AppDelegate，有多时候会用全局AppDelegate去获取Window。
    [UIApplication sharedApplication].delegate.window = window;
    
    CELaunchPageViewController *launchVC = [[CELaunchPageViewController alloc] init];

    window.rootViewController = launchVC;
    [window makeKeyAndVisible];
    
    return YES;
}
@end
```



```objc
@implementation CEAMReachabilityDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Allocate a reachability object
  Reachability *reach = [Reachability reachabilityWithHostname:kServerBaseUrl];
  
  // Set the blocks
  reach.reachableBlock = ^(Reachability *reach) {
    
    if (reach.currentReachabilityStatus == ReachableViaWWAN) {
      BLYLogInfo(@"ReachabilityStatusChangeBlock--->蜂窝数据网");
    } else if (reach.currentReachabilityStatus == ReachableViaWiFi) {
      BLYLogInfo(@"ReachabilityStatusChangeBlock--->WiFi网络");
    }
  };
  
  reach.unreachableBlock = ^(Reachability *reach) {
    BLYLogInfo(@"ReachabilityStatusChangeBlock--->未知网络状态");
  };  
  [reach startNotifier];
  return YES;
}

@end
```



### 模块注册

当模块创建完成后，进行注册后即可生效。

```objc
@implementation AppDelegate
+ (void)load
{
//    CoreData
    [CEApplicationMediator registerAppilgationModuleDelegate:[[CEAMCoreDataDelegate alloc] init]];
// 		...
}
@end
```



这里有两种方式进行注册

- 在AppDelegate的+ (void)load中进行注册
- 在ApplicationMediator的+ (void)load中进行注册。

两种方式都可以，各有利弊

- 在AppDelegate中注册，delegate与AppDelegate耦合，但ApplicationMediator与delegate进行解耦，ApplicationMediator则可以作为组件抽离出来，作为中间件使用。
- 在ApplicationMediator中注册，则与上面正好相反，这样模块的维护就只需要围绕ApplicationMediator进行，代码比较集中。

我采用的是AppDelegate中注册的方式，主要是准备将ApplicationMediator作为组件使用。



### 消息转发

作为一个键盘侠，我的打字速度还是很快的，不出五分钟我已经写完了五个UIApplicationDelegate中主要生命周期函数的手动转发，但是当我打开UIApplicationDelegate头文件后，我就蒙蔽了，delegate的方法多到让我头皮发麻。

嗯，是的，所以消息转发机制就在这种时候排上了大用处。

#### AppDelegate

AppDelegate的所有方法都转由ApplicationMediator处理，模块转发逻辑后面介绍。

```objc
@implementation AppDelegate

+ (void)load
{
	//注册模块
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [[CEApplicationMediator sharedInstance] respondsToSelector:aSelector];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [[CEApplicationMediator sharedInstance] methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    [[CEApplicationMediator sharedInstance] forwardInvocation:anInvocation];
}
@end
```

这样AppDelegate就只需要处理注册模块就可以了。

#### ApplicationMediator

```objc
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
            return *retValue;
        }];
    } else {
        // 等同于[self doesNotRecognizeSelector:anInvocation.selector];
        [super forwardInvocation:anInvocation];
    }
}

- (BOOL)hasDelegateRespondsToSelector:(SEL)selector
{
    BOOL result = NO;
    NSEnumerator *enumerater = _applicationModuleDelegates.objectEnumerator;
    id delegate;
    while ((delegate = enumerater.nextObject)) {
        result = [delegate respondsToSelector:selector];
        if (result) {
            break;
        }
    }
    return result;
}

- (id)delegateRespondsToSelector:(SEL)selector
{
    id resultDelegate;
    NSEnumerator *enumerater = _applicationModuleDelegates.objectEnumerator;
    id delegate;
    while ((delegate = enumerater.nextObject)) {
        if ([delegate respondsToSelector:selector]) {
            resultDelegate = delegate;
            break;
        }
    }
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
    NSEnumerator *enumerater = _applicationModuleDelegates.objectEnumerator;
    
    id delegate;
    while ((delegate = enumerater.nextObject)) {
        if ([delegate respondsToSelector:selector]) {
            if (nofityHandler) {
                nofityHandler(delegate);
            }
        }
    }
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
    BOOL success = defaultReturnValue;
    if (_applicationModuleDelegates.count == 0) {
        return success;
    }
    NSEnumerator *enumerater = _applicationModuleDelegates.objectEnumerator;
    id delegate;
    while ((delegate = enumerater.nextObject)) {
        if ([delegate respondsToSelector:selector]) {
            if (nofityHandler) {
                success = nofityHandler(delegate);
                if (success) {
                    break;
                }
            }
        }
    }
    return success;
}
```



这里简单说一下消息转发的流程。

1. `- (BOOL)respondsToSelector:(SEL)aSelector`在调用协议方法前，会检测对象是否实现协议方法，如果响应则会调用对应的方法。
2. `- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`当调用的方法无法找到时，如果未实现此方法，系统就会调用NSObject的doesNotRecognizeSelector方法，即抛出异常并Crash。当实现了这个方法是，系统会要求返回selector的对应方法实现，这里就可以开启消息转发。
3. `- (void)forwardInvocation:(NSInvocation *)anInvocation`当方法完成转发设定后，会进入这个方法，由我们来控制方法的执行。

在步骤三里，实现了自定义的转发方案：

- 无返回值的delegate方法，以及`application:didFinishLaunchingWithOptions:`这种只返回YES的方法，转发的时候，进行轮询通知。
- BOOL返回值的delegate方法，先开启轮询通知，同时获取每次执行的结果，当结果为YES时，表示有模块完成了处理，则结束轮询。这里需要注意的是，轮询顺序与注册顺序有关，需要注意注册顺序。
- 有completionHandler的方法，主要是推送消息模块，由于competitionHandler只能调用一次，并且方法还没有BOOL返回值，所以这类方法只能实现在ApplicationMediator中，每个方法手动转发，具体实现请看源码。

## 还未开始的3.0版本

实现了2.0版本后，新增模块已经比较方便了，不过还有很多值得改进的地方。

- 比如在AppDelegate中注册模块是根据代码的编写顺序来决定模块之间的依赖关系的，只能是单项依赖。实际使用过程中还是出现过由于依赖模块关系，导致初始化混乱的问题。设计的时候为了减少类继承和协议继承，用的都是系统现有的方案，后续可能会按照责任链的设计思路将这个组件设计的更完善。
- AppDelegate有一个默认的UIWindow，大量的第三方库都通过`[UIApplication sharedApplication].delegate.window.bounds.size`来获取屏幕尺寸，所以在创建或更改Window的时候，需要牢记将Window赋值给AppDelegate。目前只通过了文档约束，后续还会进行改进。



