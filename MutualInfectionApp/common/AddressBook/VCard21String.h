//
//  VCard21String.h
//  MutualInfectionApp
//
//  Created by apple on 2025/9/21.
//

#import <Foundation/Foundation.h>
#import <Contacts/Contacts.h>
NS_ASSUME_NONNULL_BEGIN

@interface VCard21String : NSObject

+(NSArray<NSString*>*)generateVCard21StringWithContacts:(NSArray<CNContact *> *)contacts;
+ (NSString *)writeStringToFile:(NSString *)writeStr andFileSuffix:(NSString *)fileType;
@end

NS_ASSUME_NONNULL_END
