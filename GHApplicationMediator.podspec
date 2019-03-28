Pod::Spec.new do |s|
    # 组件库名称
    s.name             = 'GHApplicationMediator'
    # 组件库当前版本，也就是tag指定的
    s.version          = '0.1.1'
    # 简介
    s.summary          = 'make AppDelegate lighter.'
    # 详细描述
    s.description      = <<-DESC
    manage appDelegate modules easier
    DESC
    # 组件库首页
    s.homepage         = 'https://github.com/ginhoor/GHApplicationMediator'
    # 组件库开源协议
    s.license          = { :type => 'Apache License', :file => 'LICENSE' }
    # 作者
    s.author           = { 'ginhoor' => 'ginhoor@gmail.com' }
    # Git仓库地址
    s.source           = { :git => 'https://github.com/ginhoor/GHApplicationMediator.git', :tag => s.version.to_s }
    # 依赖的iOS版本
    s.ios.deployment_target = '10.0'
    # 源文件地址
    s.source_files = 'GHApplicationMediator/Classes/**/*'
    # 依赖资源地址
    # s.resource_bundles = {
    #   'GHApplicationMediator' => ['GHApplicationMediator/Assets/*.png']
    # }
    # 头文件地址
    # s.public_header_files = 'Pod/Classes/**/*.h'
    # 依赖系统库
    # s.frameworks = 'UIKit', 'MapKit'
    # 依赖的第三方库
    # s.dependency 'AFNetworking', '~> 2.3'

end
