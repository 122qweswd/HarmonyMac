//
//  TelModel.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/3.
//

import Foundation
import Contacts
import UIKit

class AddressBookModel: NSObject {

//    var namePrefix:String?
//    var givenName: String?
//    var middleName: String?
//    var familyName: String?
    //var contact: CNContact?
    var isSelect:Bool = false
    
    /// 联系人姓名
    public var name: String = ""
    
    /// 联系人电话数组,一个联系人可能存储多个号码
    public var mobileArray: [String] = []
    
    /// 联系人头像
    public var headerImage: UIImage?
    
    public var totalSize = 0
    public var contact:CNContact?
    
    
//    open var contactType: CNContactType
//
//    open var namePrefix: String
//
//    open var givenName: String
//
//    open var middleName: String
//
//    open var familyName: String
//
//    open var previousFamilyName: String
//
//    open var nameSuffix: String
//
//    open var nickname: String
//
//    open var organizationName: String
//
//    open var departmentName: String
//
//    open var jobTitle: String
//
//    open var phoneticGivenName: String
//
//    open var phoneticMiddleName: String
//
//    open var phoneticFamilyName: String
//
//    open var phoneticOrganizationName: String
//
//    open var note: String
//
//    open var imageData: Data?
//
//    open var phoneNumbers: [CNLabeledValue<CNPhoneNumber>]
//
//    open var emailAddresses: [CNLabeledValue<NSString>]
//
//    open var postalAddresses: [CNLabeledValue<CNPostalAddress>]
//
//    open var urlAddresses: [CNLabeledValue<NSString>]
//
//    open var contactRelations: [CNLabeledValue<CNContactRelation>]
//
//    open var socialProfiles: [CNLabeledValue<CNSocialProfile>]
//
//    open var instantMessageAddresses: [CNLabeledValue<CNInstantMessageAddress>]
//
//    /** @abstract The Gregorian birthday.
//     *
//     *  @description Only uses day, month and year components. Needs to have at least a day and a month.
//     */
//    open var birthday: DateComponents?
//
//    /** @abstract The alternate birthday (Lunisolar).
//     *
//     *  @description Only uses day, month, year and calendar components. Needs to have at least a day and a month. Calendar must be Chinese, Hebrew or Islamic.
//     */
//    open var nonGregorianBirthday: DateComponents?
//
//    /** @abstract Other Gregorian dates (anniversaries, etc).
//     *
//     *  @description Only uses day, month and year components. Needs to have at least a day and a month.
//     */
//    open var dates: [CNLabeledValue<NSDateComponents>]
}
