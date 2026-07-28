//
//  VCard21String.m
//  MutualInfectionApp
//
//  Created by apple on 2025/9/21.
//

#import "VCard21String.h"
#import "MutualInfectionApp-Swift.h"


@implementation VCard21String



// MARK: ios9之后的通讯录转Vcard(版本2.1)字符串
+(NSArray<NSString*>*)generateVCard21StringWithContacts:(NSArray<CNContact *> *)contacts {
    //NSInteger counter  = 0;
   
    NSMutableArray * arr = [NSMutableArray array];
 
    for(CFIndex i = 0; i < contacts.count; i++) {
        NSMutableString *vcard = [[NSMutableString alloc] init];
        CNContact *contact = contacts[i];
        NSString *firstName = contact.familyName;
        firstName = (firstName ?
                     firstName : @"");
        NSString *lastName = contact.givenName;
        lastName = (lastName ? lastName : @"");
        NSString *middleName = contact.middleName;
        NSString *prefix = contact.namePrefix;
        NSString *suffix = contact.nameSuffix;
        
        // 编码
        firstName = [NSString stringWithString:firstName];
        lastName = [NSString stringWithString:lastName];
        middleName = [NSString stringWithString:middleName];
        //middleName = [NSString stringAddEncodeWithString:middleName];
        
//        NSString *nickName = contact.nickname;
//        NSString *firstNamePhonetic = contact.phoneticGivenName;
//        NSString *lastNamePhonetic = contact.phoneticFamilyName;
//        NSString *organization = contact.organizationName;
//        NSString *jobTitle = contact.jobTitle;
//        NSString *department = contact.departmentName;
        
        NSString *compositeName = [NSString stringWithFormat:@"%@%@",firstName,lastName];
        //[NSString stringWithFormat:@""]
//        if(i > 0) {
//            vcard = [NSMutableString stringWithFormat:@"%@\n",vcard];
//        }
        
        vcard = [NSMutableString stringWithFormat:@"%@BEGIN:VCARD\nVERSION:2.1\nN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:%@;%@;%@;%@;%@\n",
                 vcard,
                 (firstName ?
                  firstName : @""),
                 (lastName ? lastName : @""),
                 (middleName ? middleName : @""),
                 (prefix ?
                  prefix : @""),
                 (suffix ? suffix : @"")
                 ];
        
        vcard = [NSMutableString stringWithFormat:@"%@FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:%@\n",vcard,compositeName];
        
        // Tel
        if(contact.phoneNumbers.count > 0) {
            for (int k = 0; k < contact.phoneNumbers.count; k++) {
                CNLabeledValue<CNPhoneNumber*>* phoneObject = contact.phoneNumbers[k];
                NSString *label = phoneObject.label;
                NSString *number = [phoneObject.value stringValue];
                NSString *labelLower = [label lowercaseString];
                labelLower = [labelLower stringByReplacingOccurrencesOfString:@"_$!<" withString:@""];
                labelLower = [labelLower stringByReplacingOccurrencesOfString:@">!$_" withString:@""];
                
                if ([labelLower isEqualToString:@"mobile"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;CELL:%@\n",vcard,number];
                else if ([labelLower isEqualToString:@"home"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;HOME:%@\n",vcard,number];
                else if ([labelLower isEqualToString:@"work"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;WORK:%@\n",vcard,number];
                else if ([labelLower isEqualToString:@"main"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;MAIN:%@\n",vcard,number];
                else if ([labelLower isEqualToString:@"homefax"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;HOME;type=FAX:%@\n",vcard,number];
                else if ([labelLower isEqualToString:@"workfax"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;WORK;FAX:%@\n",vcard,number];
                else if ([labelLower isEqualToString:@"pager"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;PAGER:%@\n",vcard,number];
                else if([labelLower isEqualToString:@"other"])
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;OTHER:%@\n",vcard,number];
                else { //类型解析不出来的
                    vcard = [NSMutableString stringWithFormat:@"%@TEL;OTHER:%@\n",vcard,number];
                   // counter++;
//                    vcard = [vcard stringByAppendingFormat:@"item%i.TEL:%@\nitem%i.X-ABLabel:%@\n",counter,number,counter,label];
                }
            }
        }
        
        // Mail
//        if(contact.emailAddresses.count > 0) {
//            for (int k = 0; k < contact.emailAddresses.count; k++) {
//                CNLabeledValue<NSString*>* emailObject = contact.emailAddresses[k];
//                NSString *label = emailObject.label;
//                NSString *email = emailObject.value;
//                NSString *labelLower = [label lowercaseString];
//                
//                vcard = [vcard stringByAppendingFormat:@"EMAIL;WORK:%@\n",email];
//                
//                if ([labelLower isEqualToString:@"home"]) vcard = [vcard stringByAppendingFormat:@"EMAIL;HOME:%@\n",email];
//                else if ([labelLower isEqualToString:@"work"]) vcard = [vcard stringByAppendingFormat:@"EMAIL;WORK:%@\n",email];
//                else {//类型解析不出来的
//                    counter++;
////                    vcard = [vcard stringByAppendingFormat:@"item%i.EMAIL;type=INTERNET:%@\nitem%i.X-ABLabel:%@\n",counter,email,counter,label];
//                }
//            }
//        }
        
        // Address
//        if(contact.postalAddresses.count > 0) {
//            for (int k = 0; k < contact.postalAddresses.count; k++) {
//                CNLabeledValue<CNPostalAddress*>* addressObject = contact.postalAddresses[k];
//                NSString *label = addressObject.label;
//                CNPostalAddress *address = addressObject.value;
//                NSString *labelLower = [label lowercaseString];
//                NSString* country = address.country;
//                NSString* city = address.city;
//                NSString* state = address.state;
//                NSString* street = address.street;
//                NSString* zip = address.postalCode;
////                NSString* countryCode = address.ISOCountryCode;
//                NSString *type = @"";
//                NSString *labelField = @"";
//                counter++;
//                
//                if([labelLower isEqualToString:@"work"]) type = @"WORK";
//                else if([labelLower isEqualToString:@"home"]) type = @"HOME";
//                else if(label && [label length] > 0)
//                {
//                    labelField = [NSString stringWithFormat:@"item%li.X-ABLabel:%@\n",(long)counter,label];
//                }
//                
//                vcard = [vcard stringByAppendingFormat:@"ADR;%@:;;%@;%@;%@;%@;%@\n",
//                         type,
//                         (street ? street : @""),
//                         (city ? city : @""),
//                         (state ? state : @""),
//                         (zip ? zip : @""),
//                         (country ? country : @"")];
//            }
//        }
        
        
        // 剩下的不经常使用，我就不写了，要是须要。自己补全
        // url
        // TODO:
        
        // IM
        // TODO:
        
        // Photo
        // TODO:
//        if (contact.imageDataAvailable) {
//            NSString *imageBase64Str = [contact.imageData base64EncodedStringWithOptions: NSDataBase64EncodingEndLineWithLineFeed];
//            vcard = [vcard stringByAppendingFormat:@"PHOTO;ENCODING=BASE64;JPEG:%@\n", imageBase64Str];
//        }
        
        vcard = [NSMutableString stringWithFormat:@"%@END:VCARD",vcard];
        
        
        [arr addObject:vcard];

        
    }
    
    return arr;
   
}
 
// 写字符串到文件中
+ (NSString *)writeStringToFile:(NSString *)writeStr andFileSuffix:(NSString *)fileType {
    // 获取带毫秒的时间戳
//    NSDate *datenow = [NSDate date];
//    NSString *timeSp = [NSString stringWithFormat:@"%ld", (long)([datenow timeIntervalSince1970]*1000)];
//    
//    NSString *writePath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"tmp/%@.%@", timeSp, fileType]];
//    
    
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    // 得到Document目录下的fileName文件的路径
//    NSString *filePath = [documentPath stringByAppendingPathComponent:@"234.vcf"];
    
    NSError *error;
    [writeStr writeToFile:documentPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"导出失败");
        return @"";
    }else {
        NSLog(@"导出成功");
        return documentPath;
    }
}

@end

