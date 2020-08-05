#import <dlfcn.h>
#import <substrate.h>
#import <IOKit/IOKitLib.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>

@interface NSData()
+ (NSData *)dataWith16HexString:(NSString *)str;
+ (NSString *)tenTo16Hex:(long long int)tmpid;
@end

%hook NSData
%new
+ (NSData *)dataWith16HexString:(NSString *)str {
    if (!str || [str length] == 0) return nil;
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range = NSMakeRange(0, ([str length]%2==0) ? 2:1);
    for (NSInteger i = range.location; i < [str length]; i += 2) {
        unsigned int anInt;
        NSScanner *scanner = [[NSScanner alloc] initWithString:[str substringWithRange:range]];
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        range.location += range.length;
        range.length = 2;
    }
    return (NSData *)hexData;
}

%new
+(NSString *)tenTo16Hex:(long long int)tmpid{
    NSString *str =@""; int ttmpig = 0;
    for (int i = 0; i<16; i++) {
        ttmpig=tmpid%16; tmpid=tmpid/16;
        if (ttmpig>=10) { str = [[NSString stringWithFormat:@"%c", (char)55+ttmpig] stringByAppendingString:str];}
        else{ str = [[NSString stringWithFormat:@"%i", ttmpig] stringByAppendingString:str];}
        if (tmpid==0)break;
    }
    NSString *chip_id = @"";
    for (int i=0; i<16; i++) {
        chip_id = [ (i<16-str.length) ? @"0":[str substringWithRange:NSMakeRange(i-16+(int)str.length, 1)] stringByAppendingString:chip_id];
    }
    return chip_id;
}

%end

@interface NSDictionary()
- (Boolean)hasKey:(NSString *)str;
@end

%hook NSDictionary
%new
- (Boolean)hasKey:(NSString *)key{
    for (NSString *key_in in self.allKeys) {
        if ([key_in isEqualToString:key]){
            return YES;
        }
    }
    return NO;
}
%end

static CFPropertyListRef (*orig_MGCopyAnswer_internal)(CFStringRef prop, uint32_t* outTypeCode);
CFPropertyListRef new_MGCopyAnswer_internal(CFStringRef prop, uint32_t* outTypeCode) {
    NSDictionary *fkdeviceDict = [NSDictionary dictionaryWithContentsOfFile:@"/private/var/mobile/fkdevice.plist"];  
    CFPropertyListRef pvalue = orig_MGCopyAnswer_internal(prop, outTypeCode);
    NSString *propName = (__bridge NSString *)prop;

    if ([fkdeviceDict hasKey:propName]){
        NSString *value = [fkdeviceDict valueForKey:propName];
        if (([value stringByReplacingOccurrencesOfString:@" " withString:@""].length>0) ){
            NSLog(@"xxxxxxxxxx-hook[%@-orig:%@-hook:%@]", propName, pvalue, value);
            return (__bridge CFPropertyListRef)[value retain];;
        }
        value = nil;
    }
    fkdeviceDict = nil; propName = nil;
    NSLog(@"xxxxxxxxxx-unhook[prop:%@ value:%@]", prop, pvalue);
    return orig_MGCopyAnswer_internal(prop, outTypeCode);
}


CFTypeRef (*org_IORegistryEntryCreateCFProperty)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);
CFTypeRef my_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    NSDictionary *fkdeviceDict = [NSDictionary  dictionaryWithContentsOfFile:@"/private/var/mobile/fkdevice.plist"];

    CFTypeRef obj = org_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
    if (kCFCompareEqualTo == CFStringCompare(key, CFSTR("mac-address-wifi0"), 0)) {
        if ([fkdeviceDict hasKey:@"mac-address-wifi"]){
            NSString *mac_addr = [fkdeviceDict valueForKey:@"mac-address-wifi"];
            mac_addr = [[mac_addr stringByReplacingOccurrencesOfString:@":" withString:@""] uppercaseString];
            NSData *hexData = [NSData dataWith16HexString:mac_addr];
            NSData *mac_nsdata = (__bridge NSData*)((CFDataRef)obj);
            NSLog(@"xxxxxxxxxx-io-hook[prop:%@-value:%@ hook:%@]", key, mac_nsdata, hexData);
            mac_addr = nil; mac_nsdata = nil;
            return (__bridge CFDataRef)hexData;
        }
    }else if (kCFCompareEqualTo == CFStringCompare(key, CFSTR("mac-address-bluetooth0"), 0)){
        if ([fkdeviceDict hasKey:@"mac-address-bluetooth"]){
            NSString *mac_addr = [fkdeviceDict valueForKey:@"mac-address-bluetooth"];
            mac_addr = [[mac_addr stringByReplacingOccurrencesOfString:@":" withString:@""] uppercaseString];
            NSData *hexData = [NSData dataWith16HexString:mac_addr];
            NSData *mac_nsdata = (__bridge NSData*)((CFDataRef)obj);
            NSLog(@"xxxxxxxxxx-io-hook[prop:%@-value:%@ hook:%@]", key, mac_nsdata, hexData);
            mac_addr = nil; mac_nsdata = nil;
            return (__bridge CFDataRef)hexData;
        }
    }else if (kCFCompareEqualTo == CFStringCompare(key, CFSTR("unique-chip-id"), 0)){
        if ([fkdeviceDict hasKey:@"unique-chip-id"]){
            NSString *hexString = [fkdeviceDict valueForKey:@"unique-chip-id"];
            NSData *hexData = [NSData dataWith16HexString:hexString];
            NSData *mac_nsdata = (__bridge NSData*)((CFDataRef)obj);
            NSLog(@"xxxxxxxxxx-io-hook[prop:%@-value:%@ hook:%@]", key, mac_nsdata, hexData);
            hexString = nil; mac_nsdata = nil;
            return (__bridge CFDataRef)hexData;
        }
    }else{
        NSLog(@"xxxxxxxxxx-io-unhook[prop:%@ value:%@]", key, obj);
    }
    fkdeviceDict = nil;
    return obj;
}
 
%ctor {
    NSDictionary *fkdeviceDict = [NSDictionary  dictionaryWithContentsOfFile:@"/private/var/mobile/fkdevice.plist"];
    NSString *hookProcess = [fkdeviceDict valueForKey:@"hook"];
    NSString *processName = [[NSProcessInfo processInfo] processName];
    BOOL isHook = [hookProcess containsString:processName];
    if ([hookProcess containsString:@"hookall"]){ isHook = YES; }
    isHook = YES;
    if (isHook){
        MSImageRef image = MSGetImageByName("/usr/lib/libMobileGestalt.dylib");
        const uint8_t* MGCopyAnswer_ptr = (const uint8_t*)MSFindSymbol(image, "_MGCopyAnswer");
        MSHookFunction((void*)(MGCopyAnswer_ptr+8), (void*)new_MGCopyAnswer_internal, (void**)&orig_MGCopyAnswer_internal);
        MSHookFunction((void*)(IORegistryEntryCreateCFProperty), (void*)my_IORegistryEntryCreateCFProperty, (void**)&org_IORegistryEntryCreateCFProperty);
    }
    fkdeviceDict = nil; hookProcess = nil; processName = nil;
}














