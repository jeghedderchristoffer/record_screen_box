#import "RecordScreenBoxPlugin.h"
#if __has_include(<record_screen_box/record_screen_box-Swift.h>)
#import <record_screen_box/record_screen_box-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "record_screen_box-Swift.h"
#endif

@implementation RecordScreenBoxPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRecordScreenBoxPlugin registerWithRegistrar:registrar];
}
@end
